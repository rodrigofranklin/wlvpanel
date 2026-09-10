// Real Shiny/WebSocket, pointer events and layouts. Outputs stay in the campaign.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')));
const results = path.join(campaign, 'results');
const evidence = [];
const widths = (process.env.WLV_BROWSER_WIDTHS || '1440,320,360,390').split(',').map(Number);
const viewportHeight = Number(process.env.WLV_BROWSER_HEIGHT || 900);
const port = process.env.WLVPANEL_PORT || '38129';
const idle = async p => {
  await p.waitForFunction(()=>!document.documentElement.classList.contains('shiny-busy') && document.querySelector('#map[aria-busy="false"]'));
  await p.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
};
const activate = (p, locator) => p.viewportSize().width < 768 ? locator.tap() : locator.click();
async function noMobileGap(page) {
  const edges = await page.evaluate(() => {
    const rect = selector => document.querySelector(selector).getBoundingClientRect();
    return {selectorBottom:rect('.wlv-map-indicator-toggle').bottom,mapTop:rect('#map').top,
      mapBottom:rect('#map').bottom,toolbarTop:rect('.wlv-map-bottom-bar').top};
  });
  assert.equal(edges.selectorBottom,edges.mapTop,'No gap below indicator selector');
  assert.equal(edges.mapBottom,edges.toolbarTop,'No gap above mobile toolbar');
}
function methods(payload) {
  const list = [];
  function walk(v) {
    if (typeof v === 'string' && /^[\[{]/.test(v)) { try { walk(JSON.parse(v)); } catch {} }
    else if (v && typeof v === 'object') {
      if (v.method) list.push(v.method);
      Object.values(v).forEach(walk);
    }
  }
  try { walk(JSON.parse(String(payload))); } catch {}
  return list;
}
const noGeometry = frames => assert.deepEqual(frames.flat().filter(m=>['addPolygons','addGeoJSON','clearShapes','clearGroup'].includes(m)), []);
async function snapshot(p, save=false) {
  return p.evaluate(save=>{
    const map=HTMLWidgets.find('#map').getMap();
    const layer=map.layerManager.getLayer('shape','WIOD13.BRA');
    if(save) window.mapReference={map,layer,coords:layer.getLatLngs()};
    return {same:map===mapReference.map&&layer===mapReference.layer&&layer.getLatLngs()===mapReference.coords,
      center:{lat:map.getCenter().lat,lng:map.getCenter().lng},zoom:map.getZoom(),
      label:layer.getTooltip().getContent(),color:layer.options.fillColor,crs:map.options.crs.code};
  },save);
}
async function polygonFrame(page, source = 'WIOD13') {
  const frame = await page.evaluate(() => {
    const map = HTMLWidgets.find('#map').getMap();
    const points = [], background = [], thematicIds = [];
    function visit(values, target) {
      if (typeof values?.lat === 'number') target.push(map.latLngToContainerPoint(values));
      else if (Array.isArray(values)) values.forEach(v => visit(v, target));
    }
    map.eachLayer(layer => {
      if (layer instanceof L.Polygon && map.hasLayer(layer)) {
        if (layer.options.pane === 'polygons') {
          visit(layer.getLatLngs(), points);
          thematicIds.push(layer.options.layerId);
        } else if (layer.options.pane === 'base') visit(layer.getLatLngs(), background);
      }
    });
    const size = map.getSize();
    return {count:points.length, backgroundCount:background.length,
      backgroundBottom:Math.max(...background.map(p=>p.y)), thematicIds,
      width:size.x, height:size.y,
      left:Math.min(...points.map(p=>p.x)), right:Math.max(...points.map(p=>p.x)),
      top:Math.min(...points.map(p=>p.y)), bottom:Math.max(...points.map(p=>p.y))};
  });
  assert.ok(frame.count > 100, 'Frame is measured from real thematic polygon vertices');
  assert.ok(frame.thematicIds.length > 10 && frame.thematicIds.every(id => id.startsWith(source + '.')),
    'Only the active source contributes thematic geometry');
  assert.ok(frame.backgroundCount > 100 && frame.backgroundBottom > frame.bottom + 10,
    'Antarctic background extends beyond the thematic frame and cannot control its bounds');
  assert.ok(frame.left >= -2 && frame.top >= -2 && frame.right <= frame.width+2 &&
    frame.bottom <= frame.height+2, 'All polygon vertices fit: '+JSON.stringify(frame));
  assert.ok(Math.min(Math.abs(frame.right-frame.left-frame.width),
    Math.abs(frame.bottom-frame.top-frame.height)) <= 2,
  'Polygons fill the limiting dimension with no extra world padding: '+JSON.stringify(frame));
  assert.ok(Math.abs((frame.left+frame.right)/2-frame.width/2) <= 2 &&
    Math.abs((frame.top+frame.bottom)/2-frame.height/2) <= 2,
  'The projected polygon extent is centered');
  return frame;
}
(async()=>{
  const browser=await chromium.launch({headless:true});
  try {
    for(const width of widths) {
      const mobile=width<768;
      const context=await browser.newContext({locale: 'pt-BR', viewport:{width,height:viewportHeight},isMobile:mobile,hasTouch:mobile});
      const page=await context.newPage();
      const errors=[],external=[],frames=[];
      page.on('pageerror',e=>errors.push(String(e)));
      page.on('request',r=>{if(!r.url().startsWith('http://127.0.0.1:')&&!r.url().startsWith('data:'))external.push(r.url());});
      page.on('websocket',ws=>ws.on('framereceived',frame=>frames.push(methods(frame.payload))));
      try {
        await page.goto('http://127.0.0.1:'+port);
        await page.waitForFunction(()=>window.Shiny?.shinyapp?.$inputValues.main_nav);
        if (mobile && !await page.locator('.navbar-collapse').evaluate(el=>el.classList.contains('in'))) await page.locator('.navbar-toggle').click();
        await page.locator('#main_nav a[data-value="map"]').click();
        await page.waitForFunction(()=>Shiny.shinyapp.$inputValues.main_nav==='map');
        await page.waitForFunction(()=>window.WLVMap?.stats('map')?.layers>0);
        await idle(page);
        assert.equal(await page.locator('html').getAttribute('lang'),'pt-BR');
        assert.equal(await page.locator('.wlv-map-layout #co_select_country').count(),0);
        assert.equal(await page.locator('#map-indicator-search').count(),0,'No legacy indicator search');
        const initial=await snapshot(page,true);
        assert.equal(initial.crs,'WLV:EqualEarthSphere');
        const initialFrame=await polygonFrame(page);
        assert.ok(frames.flat().includes('addPolygons'));
        const size=await page.evaluate(()=>{
          const nav=document.querySelector('.navbar').getBoundingClientRect();
          const layout=document.querySelector('.wlv-map-layout').getBoundingClientRect();
          const canvas=document.querySelector('.wlv-map-canvas');
          const rect=canvas.getBoundingClientRect(),style=getComputedStyle(canvas);
          return {width:innerWidth,contentWidth:nav.right,scroll:document.documentElement.scrollWidth,height:innerHeight,scrollHeight:document.documentElement.scrollHeight,top:layout.top,navBottom:nav.bottom,bottom:layout.bottom,right:rect.right,border:style.borderWidth,radius:style.borderRadius};
        });
        assert.ok(size.scroll<=width+1 && size.scrollHeight<=size.height+1,JSON.stringify(size));
        assert.ok(Math.abs(size.top-size.navBottom)<1 && Math.abs(size.bottom-size.height)<1);
        assert.equal(size.right,size.contentWidth); assert.equal(size.border,'0px'); assert.equal(size.radius,'0px');
        if (mobile) await noMobileGap(page);
        assert.equal(await page.locator('#map .wlv-map-legend').evaluate(n=>n.open),false,
          'Legend starts collapsed');
        if (!mobile) {
          const controls = await page.evaluate(() => {
            const rect=selector=>document.querySelector(selector).getBoundingClientRect().toJSON();
            return {sidebar:rect('.wlv-map-controls'),canvas:rect('.wlv-map-canvas'),
              filters:rect('.wlv-map-filter-panel'),legend:rect('#map .wlv-map-legend'),
              world:rect('#map .wlv-map-world'),
              background:getComputedStyle(document.querySelector('.wlv-map-filter-panel')).backgroundColor,
              baseAndYear:!!document.querySelector('.wlv-map-filter-panel #map-base-panel') &&
                !!document.querySelector('.wlv-map-filter-panel #map-year-panel')};
          });
          assert.equal(controls.sidebar.width,290);
          assert.ok(controls.baseAndYear && controls.background.startsWith('rgba('));
          assert.ok(Math.abs(controls.filters.top-controls.canvas.top)<1);
          assert.ok(controls.filters.right>size.contentWidth-30 && controls.legend.x<controls.canvas.x+40);
          assert.ok(controls.legend.bottom>viewportHeight-50 && controls.world.bottom>viewportHeight-50 && controls.world.right>size.contentWidth-50);
          await page.locator('#map .wlv-map-legend > summary').click();
          await page.waitForFunction(()=>document.querySelector('#map .wlv-map-legend').open);
          const legendOverflow = await page.locator('#map .wlv-map-legend-content').evaluate(el => ({scrollHeight:el.scrollHeight,height:el.clientHeight,scrollWidth:el.scrollWidth,width:el.clientWidth}));
          assert.ok(legendOverflow.scrollHeight <= legendOverflow.height + 1 && legendOverflow.scrollWidth <= legendOverflow.width + 1,'Expanded desktop legend has no scrollbar or hidden labels');
          await page.locator('#map .wlv-map-legend-close').click();
          await page.waitForFunction(()=>!document.querySelector('#map .wlv-map-legend').open);
        }
        await activate(page,page.locator('#settings_toggle'));
        assert.equal(await page.locator('#wlv-settings').evaluate(n=>n.open),true);
        assert.ok(await page.locator('#bases + .selectize-control').isVisible());
        await page.keyboard.press('Escape');
        assert.equal(await page.locator('#wlv-settings').evaluate(n=>n.open),false);
        if(mobile) {
          assert.equal(await page.locator('.wlv-map-bottom-bar button:visible').count(),4);
          for(const sheet of ['legend','year','base']) {
            await activate(page,page.locator('.wlv-map-tool[data-map-sheet="'+sheet+'"]'));
            await page.locator('#map-'+sheet+'-panel').waitFor({state:'visible'});
            const box=await page.locator('#map-'+sheet+'-panel').boundingBox();
            assert.ok(box.x>=0&&box.x+box.width<=width+1);
          }
        }
        frames.length=0;
        await page.locator('#co_map_method').evaluate(node=>node.selectize.setValue('WIOD16'));
        await page.waitForFunction(()=>document.getElementById('co_select_year') && window.jQuery('#co_select_year').data('ionRangeSlider').options.max>2007);
        await idle(page);
        const range=await page.locator('#co_select_year').evaluate(n=>{const x=window.jQuery(n).data('ionRangeSlider'); return {min:x.options.min,max:x.options.max};});
        assert.equal(range.max,2014);
        const sourceChanged=await snapshot(page);
        assert.deepEqual(sourceChanged.center,initial.center);
        assert.equal(sourceChanged.zoom,initial.zoom,'Changing source preserves the view');
        await activate(page,page.locator(mobile?'#map-world-button':'#map .wlv-map-world'));
        await polygonFrame(page,'WIOD16');
        const sourceWorld=await snapshot(page);
        await page.locator('#co_select_year').evaluate(n=>{window.jQuery(n).data('ionRangeSlider').update({from:2014});window.jQuery(n).trigger('change');});
        await page.waitForFunction(()=>Shiny.shinyapp.$inputValues.co_select_year===2014);
        if(mobile) await activate(page,page.locator('.wlv-map-tool[data-map-sheet="base"]'));
        await page.locator('#co_map_method').evaluate(node=>node.selectize.setValue('WIOD13'));
        await page.waitForFunction(()=>document.getElementById('co_select_year').value==='2007');
        await idle(page);
        const sourceRestored=await snapshot(page);
        assert.deepEqual(sourceRestored.center,sourceWorld.center);
        assert.equal(sourceRestored.zoom,sourceWorld.zoom,'Restoring source waits for an explicit World action');
        assert.equal(await page.locator('#co_select_year').evaluate(n=>window.jQuery(n).data('ionRangeSlider').options.max),2007);
        if(!mobile) {
          await page.locator('#co_select_year').evaluate(n=>{window.jQuery(n).data('ionRangeSlider').update({from:2005});window.jQuery(n).trigger('change');});
          await page.waitForFunction(()=>Shiny.shinyapp.$inputValues.co_select_year===2005);await idle(page);
          await page.locator('#map-year-panel .slider-animate-button').click();
          await page.waitForFunction(()=>Shiny.shinyapp.$inputValues.co_select_year===2006);
          await page.waitForFunction(()=>Shiny.shinyapp.$inputValues.co_select_year===2007);
          await page.waitForFunction(color=>HTMLWidgets.find('#map').getMap().layerManager.getLayer('shape','WIOD13.BRA').options.fillColor===color&&!window.jQuery('#co_select_year').data('animTimer'),initial.color);
          await idle(page);
        }
        noGeometry(frames); assert.ok((await snapshot(page)).same);
        if(mobile) await activate(page,page.locator('#map-world-button'));
        // Free pan at world zoom used to be undone by a moveend clamp.
        await page.evaluate(()=>{const m=HTMLWidgets.find('#map').getMap();m.panBy([40,0],{animate:false});});
        const panned=await snapshot(page);
        assert.ok(Math.abs(panned.center.lng)>1,'Pan at world zoom remains displaced');
        await activate(page,page.locator('#language_toggle'));
        await page.waitForFunction(()=>document.documentElement.lang==='en'&&HTMLWidgets.find('#map').getMap().layerManager.getLayer('shape','WIOD13.BRA').getTooltip().getContent().includes('Brazil'));
        await idle(page);
        const english=await snapshot(page);
        assert.deepEqual(english.center,panned.center); assert.equal(english.zoom,panned.zoom); assert.equal(english.color,panned.color); assert.ok(english.same);
        assert.equal(await page.locator('#settings_toggle').getAttribute('aria-label'),'Settings');
        noGeometry(frames);
        if(!mobile) {
          await page.setViewportSize({width:1024,height:viewportHeight}); await idle(page);
          const resized=await snapshot(page); assert.deepEqual(resized.center,panned.center); assert.equal(resized.zoom,panned.zoom);
          // Leaflet mantém estilos inline ao cruzar o breakpoint; testar só
          // uma sessão que já nasce pequena não detecta o espaço duplicado.
          for (const viewport of [{width:560,height:424},{width:390,height:900},{width:767,height:900}]) {
            await page.setViewportSize(viewport); await idle(page);
            await noMobileGap(page);
          }
          await page.setViewportSize({width,height:viewportHeight}); await idle(page);
          await activate(page,page.locator('#map .leaflet-control-zoom-in'));
          await page.waitForFunction(z=>HTMLWidgets.find('#map').getMap().getZoom()>z,panned.zoom);
          await page.locator('#map').focus(); await page.keyboard.press('ArrowRight');
          await page.waitForFunction(()=>!HTMLWidgets.find('#map').getMap()._panAnim?._inProgress);
          const rectangle=await page.evaluate(()=>{
            const m=HTMLWidgets.find('#map').getMap(),r=document.getElementById('map').getBoundingClientRect();
            const a=L.point(r.width*.30,r.height*.30),b=L.point(r.width*.70,r.height*.65);
            const view=WLVEqualEarth.boxView(m,a,b);
            return {a:{x:r.x+a.x,y:r.y+a.y},b:{x:r.x+b.x,y:r.y+b.y},center:{lat:view.center.lat,lng:view.center.lng},zoom:view.zoom};
          });
          await page.keyboard.down('Shift');await page.mouse.move(rectangle.a.x,rectangle.a.y);await page.mouse.down();
          await page.mouse.move(rectangle.b.x,rectangle.b.y,{steps:8});await page.mouse.up();await page.keyboard.up('Shift');
          await page.waitForFunction(z=>Math.abs(HTMLWidgets.find('#map').getMap().getZoom()-z)<0.02,rectangle.zoom);
          const boxError=await page.evaluate(c=>{const m=HTMLWidgets.find('#map').getMap();return m.project(m.getCenter()).distanceTo(m.project(c));},rectangle.center);
          assert.ok(boxError<1.5,'Box zoom uses projected rectangle center');
        } else {
          const box=await page.locator('#map').boundingBox();
          const cdp=await context.newCDPSession(page);
          await cdp.send('Input.synthesizeScrollGesture',{x:Math.round(box.x+box.width/2),y:Math.round(box.y+box.height/2),xDistance:30,yDistance:0,gestureSourceType:'touch',preventFling:true,speed:220});
          await cdp.send('Input.synthesizePinchGesture',{x:Math.round(box.x+box.width/2),y:Math.round(box.y+box.height/2),scaleFactor:1.3,relativeSpeed:200,gestureSourceType:'touch'});
          await cdp.detach();
        }
        await activate(page,page.locator(mobile?'#map-world-button':'#map .wlv-map-world'));
        const world=await snapshot(page);
        const worldFrame=await polygonFrame(page);
        assert.deepEqual(world.center,initial.center);
        assert.equal(world.zoom,initial.zoom);
        // Real hit testing keeps the map a thematic view and the independent country intact.
        await page.locator('#co_select_country').evaluate(n=>n.selectize.setValue('AUS'));
        await page.waitForFunction(()=>Shiny.shinyapp.$inputValues.co_select_country==='AUS');
        const point=await page.evaluate(()=>{const m=HTMLWidgets.find('#map').getMap(),p=m.latLngToContainerPoint([-12,-53]),r=document.getElementById('map').getBoundingClientRect();return {x:r.x+p.x,y:r.y+p.y};});
        if(mobile) await page.touchscreen.tap(point.x,point.y); else {await page.mouse.move(point.x,point.y);await page.mouse.click(point.x,point.y);}
        await page.locator('#map .leaflet-tooltip').filter({hasText:'Brazil'}).waitFor({state:'visible'});
        assert.equal(await page.locator('#co_select_country').inputValue(),'AUS');
        assert.equal(await page.locator('#wlv-country-overlay').count(),0);
        assert.equal(await page.locator('body').getAttribute('data-wlv-tab'),'map');
        const tooltip=await page.locator('#map .leaflet-tooltip').filter({hasText:'Brazil'}).boundingBox();
        assert.ok(tooltip.width>=100&&tooltip.width<=width);
        if(mobile) await activate(page,page.locator('.wlv-map-indicator-toggle'));
        const group=page.locator('.wlv-map-group-header').first();
        if (await group.getAttribute('aria-expanded') !== 'true') await activate(page,group);
        const expanded=page.locator('.wlv-map-group-body[data-expanded="true"]');
        await expanded.evaluate(async n=>{await Promise.all(n.getAnimations().map(a=>a.finished));});
        const rows=await expanded.locator('.wlv-map-indicator-row').evaluateAll(nodes=>nodes.map(n=>{
          const r=n.getBoundingClientRect(); return {top:r.top,bottom:r.bottom,height:r.height};
        }));
        rows.forEach((row,index)=>{
          assert.ok(row.height>=32,'Indicator row keeps its content height');
          if(index) assert.ok(row.top>=rows[index-1].bottom-1,'Indicator rows never overlap');
        });
        const beforeHelp=await page.locator('#co_select_indicator').inputValue();
        await activate(page,expanded.locator('[data-indicator-info]').first());
        await page.locator('#shiny-modal .modal-title').waitFor({state:'visible'});
        assert.equal(await page.locator('#shiny-modal .wlv-map-info-label').count(),4);
        assert.ok((await page.locator('#shiny-modal .wlv-map-indicator-unit .wlv-map-info-value').innerText()).trim());
        assert.ok((await page.locator('#shiny-modal .wlv-map-indicator-description .wlv-map-info-value').innerText()).trim());
        await page.screenshot({path:path.join(results,'map-indicator-info-'+width+'.png'),fullPage:true});
        assert.equal(await page.locator('#co_select_indicator').inputValue(),beforeHelp);
        await page.locator('#shiny-modal .modal-footer button').click();
        await page.locator('#shiny-modal').waitFor({state:'hidden'});
        const option=expanded.locator('.wlv-map-indicator-option[aria-pressed="false"]').first();
        const code=await option.getAttribute('data-indicator');
        await activate(page,option);
        await page.waitForFunction(code=>Shiny.shinyapp.$inputValues.co_select_indicator===code,code);
        await idle(page); noGeometry(frames); assert.ok((await snapshot(page)).same);
        await page.screenshot({path:path.join(results,'map-interface-'+width+'.png'),fullPage:true});
        assert.deepEqual(errors,[]); assert.deepEqual(external,[]);
        evidence.push({width,status:'passed',equalEarth:true,initialFrame,worldFrame,freePan:true,manualReframe:true,incremental:true,perSourceYears:range,language:true,independentCountry:true,mobileControls:mobile});
      } catch(error) {
        await page.screenshot({path:path.join(results,'map-interface-failure-'+width+'.png'),fullPage:true});
        console.error('STATE',await page.evaluate(()=>({inputs:Shiny.shinyapp.$inputValues.co_map_method,year:document.getElementById('co_select_year').value,errors:[...document.querySelectorAll('.shiny-output-error')].map(n=>n.textContent)})),errors);
        throw error;
      } finally {await context.close();}
    }
  } finally {await browser.close();fs.writeFileSync(path.join(results,'map-interface.json'),JSON.stringify(evidence,null,2));}
  console.log(JSON.stringify(evidence,null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
