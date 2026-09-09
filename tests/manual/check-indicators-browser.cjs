// Headless verification against the local app, with all output in an active
// campaign. NODE_PATH can point to the bundled Playwright runtime.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')));
for (const key of ['TEMP', 'TMP', 'TMPDIR']) assert.equal(path.resolve(process.env[key] || ''), path.resolve(campaign, 'scratch'));
const results = path.join(campaign, 'results');
const widths = (process.env.WLV_BROWSER_WIDTHS || '1440,320,390').split(',').map(Number);
const evidence = {status:'running', viewports:[], errors:[]};

async function select(page, id, value) {
  await page.locator('#' + id).evaluate((node, value) => {
    if (node.selectize) node.selectize.setValue(value);
    else if (jQuery(node).data('ionRangeSlider')) {
      jQuery(node).data('ionRangeSlider').update({from:Number(value)});
      jQuery(node).trigger('change');
    }
    else {node.value = value; jQuery(node).trigger('change');}
  }, value);
}
async function idle(page) {
  await page.waitForFunction(() => window.Shiny?.shinyapp && !document.documentElement.classList.contains('shiny-busy'));
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}
async function layout(page) {
  const state = await page.evaluate(() => ({width:innerWidth, scroll:document.documentElement.scrollWidth,
    errors:[...document.querySelectorAll('.shiny-output-error')].filter(el => el.offsetHeight).map(el => el.textContent)}));
  assert.ok(state.scroll <= state.width + 2, 'No horizontal viewport overflow: ' + JSON.stringify(state));
  assert.deepEqual(state.errors, []);
}
function frame(payload) {
  const result = {geometry:[], incremental:false, at:Date.now(), countryInputs:[]};
  function walk(value) {
    if (typeof value === 'string') {if (/^[\[{]/.test(value)) {try {walk(JSON.parse(value));} catch {}} return;}
    if (!value || typeof value !== 'object') return;
    if (['addPolygons','addGeoJSON','clearShapes','clearGroup'].includes(value.method)) result.geometry.push(value.method);
    if (Object.hasOwn(value, 'wlvIndicatorsMap')) result.incremental = true;
    if (Array.isArray(value.inputMessages)) result.countryInputs.push(...value.inputMessages.filter(message => message.id === 'indicators-countries'));
    Object.values(value).forEach(walk);
  }
  try {walk(JSON.parse(Buffer.isBuffer(payload) ? payload.toString('utf8') : payload));} catch {}
  return result;
}

(async () => {
  const browser = await chromium.launch({headless:true});
  let active, activeJournal;
  try {
    for (const width of widths) {
      const mobile = width < 768;
      const context = await browser.newContext({viewport:{width,height:900}, hasTouch:mobile, acceptDownloads:true});
      const page = await context.newPage(); active = page;
      const journal = []; activeJournal = journal;
      page.on('pageerror', error => evidence.errors.push(error.message));
      page.on('websocket', socket => socket.on('framereceived', event => journal.push(frame(event.payload))));
      await page.goto('http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38129'));
      await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.main_nav, null, {timeout:60000});
      if (mobile && !await page.locator('.navbar-collapse').evaluate(el => el.classList.contains('in'))) await page.locator('.navbar-toggle').click();
      await page.locator('#main_nav a[data-value="indicators"]').click();
      await page.locator('#indicators-catalogue a').first().waitFor();
      await page.locator('#indicators-search').fill('capital');
      await page.waitForFunction(() => document.querySelector('#indicators-catalogue mark')?.textContent.toLowerCase().includes('capital'));
      await idle(page);
      assert.ok(await page.locator('#indicators-catalogue mark').count(), 'Search highlights matching labels');
      assert.equal(await page.locator('#indicators-intro,#indicators-catalogue_title,#indicators-catalogue_intro').count(),0);
      await select(page, 'indicators-group', 'Capital');
      await page.waitForFunction(() => {
        const el = document.getElementById('indicators-subgroup');
        const values = el.selectize ? Object.keys(el.selectize.options) : [...el.options].map(option => option.value);
        return values.includes('capital_stock') && !values.includes('imports');
      });
      await select(page, 'indicators-subgroup', 'capital_stock');
      await page.waitForFunction(() => [...document.querySelectorAll('#indicators-catalogue a')].every(el => el.id.includes('capital_stock.')));
      assert.ok(await page.locator('#indicators-catalogue a').count());
      await layout(page);
      await page.screenshot({path:path.join(results,'indicators-catalogue-' + width + '.png')});
      await page.locator('#indicators-search').fill('');
      await select(page, 'indicators-group', '');
      await page.waitForFunction(() => [...document.getElementById('indicators-subgroup').options].some(option => option.value === 'imports'));
      await select(page, 'indicators-subgroup', '');
      await page.locator('[id="indicators-catalogue_surplus_value.empe_p.r.pc"]').waitFor();
      await page.locator('[id="indicators-catalogue_surplus_value.empe_p.r.pc"]').click();
      await page.locator('#indicators-all tbody tr').first().waitFor();
      await idle(page);
      const controls = await page.locator('.wlv-indicators-controls').boundingBox();
      const content = await page.locator('.wlv-indicators-main').boundingBox();
      if (mobile) assert.ok(controls.y < content.y, 'Mobile selectors precede detail');
      else assert.ok(content.x + content.width <= controls.x, 'Desktop selectors are on the right');
      assert.equal(await page.locator('.wlv-indicators-controls #indicators-year,.wlv-indicators-controls #indicators-map_method').count(),0);
      assert.equal(await page.locator('.wlv-indicators-table-panel>.panel-heading').count(),2);
      assert.ok(await page.locator('.wlv-indicators-views').evaluate(el => parseFloat(getComputedStyle(el).borderTopWidth) > 0));
      const dt = await page.locator('#indicators-all').evaluate(el => {
        const table = jQuery(el).find('table').DataTable(), settings = table.settings()[0];
        return {paging:settings.oFeatures.bPaginate, rows:table.rows().count(), total:table.page.info().recordsDisplay};
      });
      assert.equal(dt.paging,false); assert.equal(dt.rows,dt.total); assert.ok(dt.rows > 10);
      await page.locator('#indicators-view a[data-value="map"]').click();
      await page.waitForFunction(() => window.wlvIndicatorMaps?.['indicators-map']?.layerManager?.getLayer('shape','BRA')?.getTooltip());
      const initialFit = await page.evaluate(() => {
        const map = HTMLWidgets.find('#indicators-map').getMap(), element = map.getContainer();
        const bounds = WLVEqualEarth.polygonBounds(map,L,'wlv-indicator-polygons');
        const expected = WLVEqualEarth.boundsView(bounds,element.clientWidth,element.clientHeight);
        return {actual:{zoom:map.getZoom(),center:map.getCenter()},expected};
      });
      assert.ok(initialFit.expected,'Thematic bounds exist');
      assert.ok(Math.abs(initialFit.actual.zoom - initialFit.expected.zoom) < 1e-6,'Initial view fits the thematic polygons');
      assert.ok(Math.abs(initialFit.actual.center.lat - initialFit.expected.center.lat) < 1e-6);
      assert.ok(Math.abs(initialFit.actual.center.lng - initialFit.expected.center.lng) < 1e-6);
      await page.evaluate(() => HTMLWidgets.find('#indicators-map').getMap().setView([-12,-55],3,{animate:false}));
      await page.locator('#indicators-map .wlv-map-world').click();
      assert.ok(Math.abs(await page.evaluate(() => HTMLWidgets.find('#indicators-map').getMap().getZoom()) - initialFit.expected.zoom) < 1e-6,'World button restores polygon fit');
      const mapBox = await page.locator('#indicators-map').boundingBox();
      const yearBox = await page.locator('.wlv-indicators-map-year').boundingBox();
      assert.ok(yearBox.y >= mapBox.y + mapBox.height,'Year slider is below the map');
      await select(page,'indicators-map_method','WIOD16'); await idle(page);
      await page.waitForFunction(() => WLVIndicators.pending('indicators-map').length === 0 &&
        HTMLWidgets.find('#indicators-map').getMap().layerManager.getLayer('shape','BRA').getTooltip().getContent().includes('WIOD16'));
      const legend = page.locator('#indicators-map .wlv-indicator-legend');
      await legend.waitFor();
      assert.equal(await legend.evaluate(el => el.open),false,'Legend starts collapsed');
      await legend.locator('summary').focus();
      await page.keyboard.press('Enter');
      assert.equal(await legend.evaluate(el => el.open),true,'Legend opens with keyboard');
      await legend.locator('summary').click();
      assert.equal(await legend.evaluate(el => el.open),false,'Legend closes with pointer');
      const original = await page.evaluate(() => {
        const map = HTMLWidgets.find('#indicators-map').getMap(), layer = map.layerManager.getLayer('shape','BRA');
        window._indicatorTest = {map,layer,geometry:layer.getLatLngs()};
        return {crs:map.options.crs.code, label:layer.getTooltip().getContent()};
      });
      assert.equal(await page.locator('#indicators-map').getAttribute('data-wlv-projection'),'Equal Earth');
      assert.match(original.crs,/EqualEarth/i);
      await page.mouse.move(0,0);
      await page.evaluate(() => {
        const map = HTMLWidgets.find('#indicators-map').getMap();
        map.eachLayer(layer => { if (layer.closeTooltip) layer.closeTooltip(); });
        map.layerManager.getLayer('shape','BRA').openTooltip([-10,-55]);
      });
      const tooltip = page.locator('#indicators-map .wlv-indicator-tooltip').filter({has:page.locator('.wlv-indicator-tooltip-country',{hasText:'Brasil'})});
      await tooltip.waitFor();
      assert.match(await tooltip.textContent(),/Brasil/);
      assert.equal(await tooltip.locator('.wlv-indicator-tooltip-country').count(),1);
      const tooltipBox = await tooltip.boundingBox(), fittedMapBox = await page.locator('#indicators-map').boundingBox();
      assert.ok(tooltipBox.width >= 150 && tooltipBox.height < 200,'Tooltip text has a readable width and height');
      assert.ok(tooltipBox.x >= fittedMapBox.x && tooltipBox.x + tooltipBox.width <= fittedMapBox.x + fittedMapBox.width + 1,'Tooltip stays within map width');
      await page.screenshot({path:path.join(results,'indicators-map-tooltip-' + width + '.png')});
      await page.evaluate(() => HTMLWidgets.find('#indicators-map').getMap().closeTooltip());
      const next = await page.locator('#indicators-year').evaluate(el => {
        const slider = jQuery(el).data('ionRangeSlider'), current = Number(el.value);
        return String(current < slider.options.max ? current + 1 : current - 1);
      });
      let checkpoint = journal.length;
      await select(page,'indicators-year',next);
      await page.waitForFunction(year => Number(Shiny.shinyapp.$inputValues['indicators-year']) === Number(year) &&
        HTMLWidgets.find('#indicators-map').getMap().layerManager.getLayer('shape','BRA').getTooltip().getContent().includes(' · ' + year), next);
      await idle(page);
      assert.ok(journal.slice(checkpoint).some(item => item.incremental));
      assert.deepEqual(journal.slice(checkpoint).flatMap(item => item.geometry),[],'Year does not resend geometry');
      checkpoint = journal.length;
      await page.locator('#language_toggle').click();
      await page.waitForFunction(() => document.documentElement.lang === 'en' &&
        HTMLWidgets.find('#indicators-map').getMap().layerManager.getLayer('shape','BRA').getTooltip().getContent().includes('Brazil') &&
        document.getElementById('indicators-countries').selectize.options.BRA?.[document.getElementById('indicators-countries').selectize.settings.labelField] === 'Brazil');
      await page.waitForFunction(() => document.querySelector('#indicators-all thead')?.textContent.includes('Country') &&
        document.querySelector('#indicators-selected tbody')?.textContent.includes('Brazil') &&
        [...document.querySelectorAll('.wlv-indicators .dataTables_processing')].every(el => getComputedStyle(el).display === 'none'));
      await idle(page);
      assert.deepEqual(journal.slice(checkpoint).flatMap(item => item.geometry),[],'Language does not resend geometry');
      assert.equal((await legend.locator('summary').textContent()).trim(),'Legend');
      assert.equal(await page.locator('#indicators-year').inputValue(),next);
      assert.ok(await page.evaluate(() => {
        const map = HTMLWidgets.find('#indicators-map').getMap(), layer = map.layerManager.getLayer('shape','BRA'), saved = window._indicatorTest;
        return map === saved.map && layer === saved.layer && layer.getLatLngs() === saved.geometry;
      }));
      evidence.clearStarted = Date.now();
      await page.locator('#indicators-countries').evaluate(node => { node.selectize.clear(); });
      await page.waitForFunction(() => document.querySelector('#indicators-selected tbody')?.textContent.includes('No observations') &&
        [...document.querySelectorAll('#indicators-selected .dataTables_processing')].every(el => getComputedStyle(el).display === 'none'));
      await idle(page);
      await page.locator('#indicators-map').scrollIntoViewIfNeeded();
      const point = await page.evaluate(() => {
        const map = HTMLWidgets.find('#indicators-map').getMap(), point = map.latLngToContainerPoint([-10,-55]), box = map.getContainer().getBoundingClientRect();
        return {x:box.x + point.x,y:box.y + point.y};
      });
      if (mobile) await page.touchscreen.tap(point.x,point.y); else await page.mouse.click(point.x,point.y);
      await page.waitForFunction(() => document.getElementById('indicators-countries').selectize.getValue().includes('BRA'));
      await page.waitForFunction(() => document.querySelector('#indicators-selected tbody')?.textContent.includes('Brazil') &&
        jQuery('#indicators-all table').DataTable().rows().count() > 10 &&
        [...document.querySelectorAll('.wlv-indicators .dataTables_processing')].every(el => getComputedStyle(el).display === 'none'));
      await page.locator('#indicators-selected tbody tr').filter({hasText:'Brazil'}).click();
      await page.waitForFunction(() => !document.getElementById('indicators-countries').selectize.getValue().includes('BRA'));
      await page.locator('#indicators-all tbody tr').filter({hasText:'Brazil'}).click();
      await page.waitForFunction(() => document.getElementById('indicators-countries').selectize.getValue().includes('BRA'));
      await page.waitForFunction(() => document.querySelector('#indicators-selected tbody')?.textContent.includes('Brazil'));
      const download = page.waitForEvent('download');
      await page.locator('#indicators-download').click();
      const csv = path.join(results,'indicators-selected-' + width + '.csv');
      await (await download).saveAs(csv);
      assert.match(fs.readFileSync(csv,'utf8'),/Brazil/);
      const downloadStyle = await page.locator('#indicators-download').evaluate(el => {
        const style = getComputedStyle(el); return {background:style.backgroundColor,color:style.color};
      });
      assert.equal(downloadStyle.color,'rgb(141, 32, 40)');
      assert.notEqual(downloadStyle.background,'rgb(55, 58, 60)','Focused download keeps a light background');
      await layout(page);
      await page.evaluate(() => {
        const scrollport = document.querySelector('.wlv-page-scroll');
        if (scrollport) scrollport.scrollTo(0,0); else window.scrollTo(0,0);
      });
      await page.screenshot({path:path.join(results,'indicators-detail-' + width + '.png')});
      await page.locator('#indicators-view a[data-value="series"]').click();
      await page.waitForFunction(() => document.querySelector('#indicators-series .main-svg') &&
        !document.getElementById('indicators-series').classList.contains('recalculating'));
      await idle(page);
      const legendText = await page.locator('#indicators-series').evaluate(el => {
        const clip = el.querySelector('.legend .bg').getBoundingClientRect();
        return [...el.querySelectorAll('.legendtext')].map(text => {
          const box = text.getBoundingClientRect();
          return {text:text.textContent,family:getComputedStyle(text).fontFamily,left:box.left,right:box.right,clipLeft:clip.left,clipRight:clip.right};
        });
      });
      assert.ok(legendText.some(item => item.text.includes('WIOD16')));
      legendText.forEach(item => {
        assert.match(item.family,/Source Sans 3/,'Plotly renders the configured family');
        assert.ok(item.left >= item.clipLeft - 1 && item.right <= item.clipRight + 1,'Legend text fits its clipping region: ' + JSON.stringify(item));
      });
      await page.locator('.wlv-indicators-views').screenshot({path:path.join(results,'indicators-series-' + width + '.png')});
      await page.locator('#indicators-back').click();
      await page.locator('#indicators-search').waitFor();
      await idle(page);
      assert.ok(await page.locator('#indicators-catalogue a').count());
      assert.ok((await page.locator('#indicators-countries').evaluate(el => el.selectize.getValue())).includes('BRA'));
      evidence.viewports.push({width,catalogue:true,groupSubgroupSearch:true,highlight:true,controlsOnRight:!mobile,unpaginatedRows:dt.rows,equalEarth:true,initialFit:true,worldButton:true,yearBelowMap:true,tooltip:true,collapsibleLegend:true,incremental:true,countryClick:true,countryRemoval:true,language:true,csv:true});
      console.log('PASS Indicators ' + width);
      await context.close();
    }
    assert.deepEqual(evidence.errors,[]); delete evidence.clearStarted; evidence.status = 'passed';
  } catch (error) {
    evidence.status = 'failed'; evidence.failure = error.stack;
    if (active && !active.isClosed()) {
      evidence.failureState = await active.evaluate(() => ({inputs:Shiny?.shinyapp?.$inputValues,
        title:document.getElementById('indicators-title')?.textContent,
        tooltip:window.wlvIndicatorMaps?.['indicators-map']?.layerManager?.getLayer('shape','BRA')?.getTooltip()?.getContent(),
        countryOption:document.getElementById('indicators-countries')?.selectize?.options.BRA,
        scrollTop:document.querySelector('.wlv-page-scroll')?.scrollTop})).catch(() => ({}));
      evidence.countryMessages = activeJournal.filter(item => item.countryInputs.length);
      await active.screenshot({path:path.join(results,'indicators-failure.png'),fullPage:true}).catch(() => {});
    }
    process.exitCode = 1;
  } finally {
    fs.writeFileSync(path.join(results,'indicators-browser.json'),JSON.stringify(evidence,null,2) + '\n','utf8');
    await browser.close();
  }
})();
