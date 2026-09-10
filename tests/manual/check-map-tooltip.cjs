// Focused regression for readable, contained Leaflet tooltips at narrow widths.
// Use an active campaign and its scratch path for TEMP/TMP/TMPDIR. Playwright
// must be installed; WLVPANEL_PORT defaults to 38129.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')), 'Active campaign required');
for (const name of ['TEMP', 'TMP', 'TMPDIR']) {
  assert.equal(path.resolve(process.env[name] || ''), path.resolve(campaign, 'scratch'), name + ' must use campaign scratch');
}
const results = path.join(campaign, 'results');
const widths = (process.env.WLV_BROWSER_WIDTHS || '1440,320').split(',').map(Number);
const evidence = {status:'running', viewports:[], errors:[]};

async function bounds(page, name) {
  const tooltip = page.locator('#map .leaflet-tooltip').filter({hasText:name});
  await tooltip.waitFor({state:'visible'});
  const box = await tooltip.boundingBox(), map = await page.locator('#map').boundingBox();
  assert.ok(box.width >= 100, 'Tooltip must remain readable, not collapse to one letter per line');
  assert.ok(box.x >= map.x - 1 && box.x + box.width <= map.x + map.width + 1 &&
    box.y >= map.y - 1 && box.y + box.height <= map.y + map.height + 1,
  'Complete tooltip must fit the map: ' + JSON.stringify({box,map}));
  return {box, map, text:await tooltip.innerText()};
}

(async () => {
  const browser = await chromium.launch({headless:true});
  let activePage;
  try {
    for (const width of widths) {
      const mobile = width < 768;
      const context = await browser.newContext({locale: 'pt-BR', viewport:{width,height:mobile ? 844 : 1000},
        isMobile:mobile, hasTouch:mobile, reducedMotion:'reduce'});
      const page = await context.newPage();
      activePage = page;
      page.setDefaultTimeout(30000);
      page.on('pageerror', error => evidence.errors.push(error.stack || error.message));
      await page.goto('http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38129'));
      await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.main_nav);
      if (mobile) await page.locator('.navbar-toggle').click();
      await page.locator('#main_nav a[data-value="map"]').click();
      if (mobile) await page.locator('.navbar-collapse').waitFor({state:'hidden'});
      await page.waitForFunction(() => window.WLVMap?.stats('map')?.layers > 0 &&
        document.getElementById('map').getAttribute('aria-busy') === 'false');
      await page.locator('#map').evaluate(node => node.scrollIntoView({block:'center',behavior:'instant'}));
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const point = await page.evaluate(() => {
        const map = HTMLWidgets.find('#map').getMap(), layer = map.layerManager.getLayer('shape','WIOD13.BRA');
        window._wlvTooltipBaseline = {map, layer, coordinates:layer.getLatLngs(), color:layer.options.fillColor};
        const box = map.getContainer().getBoundingClientRect(), point = map.latLngToContainerPoint([-12,-52]);
        return {x:box.x+point.x, y:box.y+point.y};
      });
      if (mobile) {
        // Pure layout proof, isolated from real touch gestures covered by
        // check-equal-earth-browser.cjs; no artificial mouse hover on mobile.
        await page.evaluate(() => window._wlvTooltipBaseline.layer.openTooltip(L.latLng(-12,-52)));
      } else await page.mouse.move(point.x,point.y);
      const portuguese = await bounds(page, 'Brasil');
      await page.locator('#map').screenshot({path:path.join(results,'equal-earth-tooltip-'+width+'.png')});

      // Activate the real button's click handler without moving the pointer
      // away from the country, so translation must update the OPEN tooltip.
      await page.locator('#language_toggle').evaluate(node => node.click());
      await page.waitForFunction(() => document.documentElement.lang === 'en' &&
        window._wlvTooltipBaseline.layer.getTooltip().getContent().includes('Brazil') &&
        document.getElementById('map').getAttribute('aria-busy') === 'false');
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const english = await bounds(page, 'Brazil');
      const preserved = await page.evaluate(() => {
        const baseline = window._wlvTooltipBaseline, map = HTMLWidgets.find('#map').getMap();
        const layer = map.layerManager.getLayer('shape','WIOD13.BRA');
        return {map:map === baseline.map, layer:layer === baseline.layer,
          coordinates:layer.getLatLngs() === baseline.coordinates, color:layer.options.fillColor === baseline.color,
          open:layer.isTooltipOpen()};
      });
      assert.ok(Object.values(preserved).every(Boolean), 'Language updates open tooltip without replacing geometry or colors');
      await page.locator('#map').screenshot({path:path.join(results,'equal-earth-tooltip-'+width+'-en.png')});
      evidence.viewports.push({width, portuguese, english, preserved});
      await context.close();
    }
    assert.deepEqual(evidence.errors, []);
    evidence.status = 'passed';
    console.log(JSON.stringify(evidence,null,2));
  } catch (error) {
    evidence.status = 'failed';
    evidence.failure = error.stack || error.message;
    if (activePage && !activePage.isClosed()) {
      await activePage.screenshot({path:path.join(results,'map-tooltip-failure.png'),fullPage:true});
      evidence.diagnostic = await activePage.evaluate(() => {
        const map = HTMLWidgets.find('#map').getMap(), tooltip = window._wlvTooltipBaseline?.layer.getTooltip();
        if (!tooltip) return null;
        const node = tooltip.getElement();
        const read = () => ({clamped:node.getAttribute('data-wlv-clamped'),
          transform:getComputedStyle(node).transform, marginLeft:getComputedStyle(node).marginLeft,
          marginRight:getComputedStyle(node).marginRight, display:getComputedStyle(node).display,
          visibility:getComputedStyle(node).visibility, position:L.DomUtil.getPosition(node),
          tooltipRect:node.getBoundingClientRect().toJSON(), mapRect:map.getContainer().getBoundingClientRect().toJSON(),
          paneTransform:map._mapPane.style.transform, positionSource:tooltip._setPosition.toString().slice(0,120)});
        const before = read();
        tooltip.update();
        return {before, afterUpdate:read()};
      });
      console.log('TOOLTIP_DIAGNOSTIC', JSON.stringify(evidence.diagnostic));
    }
    throw error;
  } finally {
    fs.writeFileSync(path.join(results,'map-tooltip-check.json'),JSON.stringify(evidence,null,2),'utf8');
    await browser.close();
  }
})().catch(error => {console.error(error);process.exitCode=1;});
