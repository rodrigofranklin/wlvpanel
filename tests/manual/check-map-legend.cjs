// Expanded legends must retain their complete source, title, unit and scale.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign,'.campaign.json')));
for (const name of ['TEMP','TMP','TMPDIR']) assert.equal(path.resolve(process.env[name] || ''),path.resolve(campaign,'scratch'));
const viewports = [{width:1440,height:900},{width:1366,height:768},{width:1024,height:600},{width:390,height:844},{width:320,height:568}];
const codes = ['trade_transfers.p.m.pc','abstract_labour.empe.m.mv','complex_labour_multiplier.empe.r.un'];
const report = {status:'running',viewports:[],errors:[]};
const results = path.join(campaign,'results');

async function selectMap(page,mobile) {
  await page.waitForFunction(()=>window.Shiny?.shinyapp?.$inputValues.main_nav);
  if (mobile && !await page.locator('.navbar-collapse').evaluate(el=>el.classList.contains('in'))) await page.locator('.navbar-toggle').click();
  await page.locator('#main_nav a[data-value="map"]').click();
  await page.waitForFunction(()=>Shiny.shinyapp.$inputValues.main_nav==='map' && document.querySelector('#map[aria-busy="false"]'));
  await page.evaluate(()=>document.fonts.ready);
}

(async()=>{
 const browser = await chromium.launch({headless:true});
 let active;
 try {
  for (const viewport of viewports) {
   const mobile=viewport.width<768;
   const context=await browser.newContext({viewport,hasTouch:mobile});
   const page=await context.newPage(); active=page;
   page.on('pageerror',error=>report.errors.push(error.message));
   await page.goto('http://127.0.0.1:'+(process.env.WLVPANEL_PORT || '38129'));
   await selectMap(page,mobile);
   const checks=[];
   for (const lang of ['pt-BR','en']) {
    if (await page.locator('html').getAttribute('lang')!==lang) {
      await page.locator('#language_toggle').click();
      await page.waitForFunction(lang=>document.documentElement.lang===lang,lang);
      await page.waitForFunction(()=>{
        const select=document.getElementById('co_select_indicator').selectize;
        return !select.options['trade_transfers.p.m.pc'][select.settings.labelField].includes('Transferência');
      });
    }
    for (const code of codes) {
     const label=await page.locator('#co_select_indicator').evaluate((el,code)=>{
       const select=el.selectize;
       select.setValue(code);
       return select.options[code][select.settings.labelField];
     },code);
     await page.waitForFunction(({code,label})=>Shiny.shinyapp.$inputValues.co_select_indicator===code &&
       document.querySelector('#map[aria-busy="false"]') && document.querySelector('#map .wlv-map-legend-content')?.textContent.includes(label),{code,label});
     const details=page.locator('#map .wlv-map-legend');
     if (mobile) {
       if (await page.locator('.wlv-map-layout').getAttribute('data-sheet')!=='legend') await page.locator('.wlv-map-tool[data-map-sheet="legend"]').tap();
     } else if (!await details.evaluate(el=>el.open)) await details.locator('summary').click();
     await page.waitForFunction(()=>document.querySelector('#map .wlv-map-legend').open);
     const state=await page.locator('#map .wlv-map-legend-content').evaluate(el=>{
       const box=el.getBoundingClientRect(),map=document.getElementById('map').getBoundingClientRect();
       const style=getComputedStyle(el),title=el.querySelector('strong');
       return {text:el.textContent,title:title?.textContent,box:{top:box.top,bottom:box.bottom,left:box.left,right:box.right,height:box.height},
        map:{top:map.top,bottom:map.bottom,left:map.left,right:map.right},overflow:style.overflowY,
        height:el.clientHeight,scrollHeight:el.scrollHeight,width:el.clientWidth,scrollWidth:el.scrollWidth,
        scaleLabels:[...el.querySelectorAll('svg text')].map(node=>{
          const label=node.getBoundingClientRect(),svg=node.ownerSVGElement.getBoundingClientRect();
          return {text:node.textContent,left:label.left,right:label.right,top:label.top,bottom:label.bottom,svg:{left:svg.left,right:svg.right,top:svg.top,bottom:svg.bottom}};
        })};
     });
     assert.ok(state.text.includes(label),'Complete indicator label is retained');
     assert.ok(state.text.includes('WIOD13'),'Source is retained');
     assert.ok(state.scaleLabels.length>=2,'Numeric scale labels are present');
     if (!mobile) state.scaleLabels.forEach(label=>assert.ok(label.left>=state.box.left-1 && label.right<=state.box.right+1 && label.top>=state.box.top-1 && label.bottom<=state.box.bottom+1,'Complete scale label stays inside legend content: '+JSON.stringify(label)));
     assert.ok(state.scrollWidth<=state.width+1,'Legend has no horizontal clipping');
     assert.ok(state.box.left>=state.map.left-1 && state.box.right<=state.map.right+1,'Legend stays inside map width');
     assert.ok(state.box.top>=state.map.top-1 && state.box.bottom<=state.map.bottom+1,'Legend stays inside map height: '+JSON.stringify(state));
     if (!mobile) {
       assert.equal(state.overflow,'visible');
       assert.ok(state.scrollHeight<=state.height+1,'Desktop legend has no vertical scrollbar');
     } else {
       assert.ok(state.height<=230,'Mobile legend retains its bounded sheet');
       await page.locator('#map .wlv-map-legend-content').evaluate(el=>{el.scrollTop=el.scrollHeight;});
       assert.ok(await page.locator('#map .wlv-map-legend-content').evaluate(el=>el.scrollTop+el.clientHeight>=el.scrollHeight-1),'Mobile scale can be reached by scrolling');
     }
     checks.push({code,lang,label,height:state.height,scrollHeight:state.scrollHeight});
     if(code===codes[0]) await page.screenshot({path:path.join(results,`map-legend-${viewport.width}x${viewport.height}-${lang}.png`)});
    }
   }
   report.viewports.push({...viewport,checks});
   await context.close();
   console.log(`PASS Map legend ${viewport.width}x${viewport.height}`);
  }
  assert.deepEqual(report.errors,[]);report.status='passed';
 } catch(error) {
  report.status='failed';report.failure=error.stack;process.exitCode=1;
  if(active&&!active.isClosed()) await active.screenshot({path:path.join(results,'map-legend-failure.png')}).catch(()=>{});
 } finally {
  fs.writeFileSync(path.join(results,'map-legend.json'),JSON.stringify(report,null,2));
  await browser.close();
 }
})();
