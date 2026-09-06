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
      await page.waitForFunction(() => document.getElementById('indicators-catalogue').textContent.toLowerCase().includes('capital'));
      await idle(page);
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
      await page.screenshot({path:path.join(results,'indicators-catalogue-' + width + '.png'),fullPage:true});
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
      else assert.ok(controls.x >= content.x + content.width, 'Desktop selectors are on the right');
      const dt = await page.locator('#indicators-all').evaluate(el => {
        const table = jQuery(el).find('table').DataTable(), settings = table.settings()[0];
        return {paging:settings.oFeatures.bPaginate, rows:table.rows().count(), total:table.page.info().recordsDisplay};
      });
      assert.equal(dt.paging,false); assert.equal(dt.rows,dt.total); assert.ok(dt.rows > 10);
      await page.locator('#indicators-view a[data-value="map"]').click();
      await page.waitForFunction(() => window.wlvIndicatorMaps?.['indicators-map']?.layerManager?.getLayer('shape','BRA')?.getTooltip());
      await select(page,'indicators-map_method','WIOD16'); await idle(page);
      await page.waitForFunction(() => WLVIndicators.pending('indicators-map').length === 0);
      const original = await page.evaluate(() => {
        const map = HTMLWidgets.find('#indicators-map').getMap(), layer = map.layerManager.getLayer('shape','BRA');
        window._indicatorTest = {map,layer,geometry:layer.getLatLngs()};
        return {crs:map.options.crs.code, label:layer.getTooltip().getContent()};
      });
      assert.equal(await page.locator('#indicators-map').getAttribute('data-wlv-projection'),'Equal Earth');
      assert.match(original.crs,/EqualEarth/i);
      const next = await page.locator('#indicators-year').evaluate(el => {
        const values = el.selectize ? Object.keys(el.selectize.options) : [...el.options].map(option => option.value);
        return values.find(value => Number(value) === Number(el.value) + 1) || values.find(value => value !== el.value);
      });
      let checkpoint = journal.length;
      await select(page,'indicators-year',next);
      await page.waitForFunction(label => HTMLWidgets.find('#indicators-map').getMap().layerManager.getLayer('shape','BRA').getTooltip().getContent() !== label, original.label);
      await idle(page);
      assert.ok(journal.slice(checkpoint).some(item => item.incremental));
      assert.deepEqual(journal.slice(checkpoint).flatMap(item => item.geometry),[],'Year does not resend geometry');
      checkpoint = journal.length;
      await page.locator('#language_toggle').click();
      await page.waitForFunction(() => document.getElementById('indicators-title').textContent === 'Indicators' &&
        HTMLWidgets.find('#indicators-map').getMap().layerManager.getLayer('shape','BRA').getTooltip().getContent().includes('Brazil') &&
        document.getElementById('indicators-countries').selectize.options.BRA?.[document.getElementById('indicators-countries').selectize.settings.labelField] === 'Brazil');
      await page.waitForFunction(() => document.querySelector('#indicators-all thead')?.textContent.includes('Country') &&
        document.querySelector('#indicators-selected tbody')?.textContent.includes('Brazil') &&
        [...document.querySelectorAll('.wlv-indicators .dataTables_processing')].every(el => getComputedStyle(el).display === 'none'));
      await idle(page);
      assert.deepEqual(journal.slice(checkpoint).flatMap(item => item.geometry),[],'Language does not resend geometry');
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
      const download = page.waitForEvent('download');
      await page.locator('#indicators-download').click();
      const csv = path.join(results,'indicators-selected-' + width + '.csv');
      await (await download).saveAs(csv);
      assert.match(fs.readFileSync(csv,'utf8'),/Brazil/);
      await layout(page);
      await page.evaluate(() => window.scrollTo(0,0));
      await page.screenshot({path:path.join(results,'indicators-detail-' + width + '.png'),fullPage:true});
      await page.locator('#indicators-back').click();
      await page.locator('#indicators-search').waitFor();
      await page.waitForFunction(() => document.getElementById('indicators-catalogue_title').textContent === 'Indicator catalogue');
      await idle(page);
      assert.equal((await page.locator('#indicators-catalogue_title').textContent()).trim(),'Indicator catalogue');
      assert.ok(await page.locator('#indicators-catalogue a').count());
      assert.ok((await page.locator('#indicators-countries').evaluate(el => el.selectize.getValue())).includes('BRA'));
      evidence.viewports.push({width,catalogue:true,groupSubgroupSearch:true,controlsOnRight:!mobile,unpaginatedRows:dt.rows,equalEarth:true,incremental:true,countryClick:true,language:true,csv:true});
      console.log('PASS Indicators ' + width);
      await context.close();
    }
    assert.deepEqual(evidence.errors,[]); delete evidence.clearStarted; evidence.status = 'passed';
  } catch (error) {
    evidence.status = 'failed'; evidence.failure = error.stack;
    if (active && !active.isClosed()) {
      evidence.failureState = await active.evaluate(() => ({inputs:Shiny?.shinyapp?.$inputValues})).catch(() => ({}));
      evidence.countryMessages = activeJournal.filter(item => item.countryInputs.length);
      await active.screenshot({path:path.join(results,'indicators-failure.png'),fullPage:true}).catch(() => {});
    }
    process.exitCode = 1;
  } finally {
    fs.writeFileSync(path.join(results,'indicators-browser.json'),JSON.stringify(evidence,null,2) + '\n','utf8');
    await browser.close();
  }
})();
