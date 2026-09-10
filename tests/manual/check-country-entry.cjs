'use strict';
// Headless regression checks. Generated evidence belongs to the active campaign.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')));
for (const key of ['TEMP', 'TMP', 'TMPDIR']) assert.equal(path.resolve(process.env[key]), path.resolve(campaign, 'scratch'));
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38131');
const evidence = { errors: [], views: [] };
const select = (page, id, value) => page.locator('#' + id).evaluate((node, value) => {
  if (node.selectize) node.selectize.setValue(value);
  else { node.value = value; jQuery(node).trigger('change'); }
}, value);
async function idle(page) {
  await page.waitForFunction(() => window.Shiny?.shinyapp && !document.documentElement.classList.contains('shiny-busy'));
}
async function countryReady(page, name) {
  await page.waitForFunction(name => document.querySelector('#co_entry_description')?.textContent.includes(name) &&
    document.querySelectorAll('.wlv-country-landing-chart svg').length === 2, name);
  await idle(page);
}
async function globeStill(page) {
  await page.waitForFunction(() => document.querySelector('#wlv-country-globe')?.dataset.animating === 'false');
}
(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    for (const width of [1440, 390, 320]) {
      const context = await browser.newContext({ locale: 'pt-BR', viewport: { width, height: width > 700 ? 1000 : 844 }, hasTouch: width < 700 });
      const page = await context.newPage();
      page.on('pageerror', error => evidence.errors.push(String(error)));
      await page.goto(url, { waitUntil: 'domcontentloaded' });
      await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.main_nav, null, { timeout: 60000 });
      if (await page.locator('.navbar-toggle').isVisible()) await page.locator('.navbar-toggle').click();
      await page.locator('#main_nav a[data-value="country"]').click();
      await countryReady(page, 'Brasil');
      await page.locator('#wlv-country-globe[data-ready="true"] canvas').waitFor({ timeout: 30000 });
      assert.equal(await page.locator('#co_select_country').inputValue(), 'BRA');
      assert.equal(await page.locator('#co_select_country').count(), 1);
      assert.equal(await page.locator('#co_entry_eyebrow').count(), 0, 'The country eyebrow has been removed');
      assert.equal(await page.locator('#wlv-country-content').isVisible(), false);
      assert.ok(await page.locator('.wlv-country-chart-labour .wlv-country-chart-gap').count() > 0);
      assert.ok(await page.locator('.wlv-country-chart-trade .wlv-country-chart-gap-sent').count() > 0);
      for (const kind of ['labour', 'trade']) {
        for (const [series, color] of [['first', '#8d2028'], ['second', '#f6ae2d']]) {
          const line = page.locator('.wlv-country-chart-' + kind + ' [data-series="' + series + '"]');
          assert.equal(await line.getAttribute('stroke-dasharray'), null, 'Both curves are continuous');
          assert.equal((await line.getAttribute('stroke')).toLowerCase(), color);
          assert.match(await line.getAttribute('d'), /C/, 'The curve is smooth');
        }
        assert.equal(await page.locator('.wlv-country-chart-' + kind + ' pattern').count(), 0, 'Fills are solid');
      }
      assert.equal(await page.locator('.wlv-country-chart-labour .wlv-country-chart-legend-item').count(), 3, 'Two series and one surplus-value legend');
      assert.ok((await page.locator('#co_entry_labour_unit').textContent()).includes('anuais'));
      const layout = await page.evaluate(() => {
        const content = document.querySelector('body > .container-fluid');
        return { width: innerWidth, scrollWidth: document.documentElement.scrollWidth,
          contentWidth: content.clientWidth, contentScrollWidth: content.scrollWidth,
          errors: Array.from(document.querySelectorAll('.shiny-output-error')).filter(node => node.getClientRects().length).map(node => node.textContent) };
      });
      assert.ok(layout.scrollWidth <= width + 2, JSON.stringify(layout));
      assert.ok(layout.contentScrollWidth <= layout.contentWidth + 2, JSON.stringify(layout));
      assert.deepEqual(layout.errors, []);
      await page.screenshot({ path: path.join(campaign, 'results', 'country-entry-' + width + '.png') });
      if (width === 1440) {
        const globe = page.locator('#wlv-country-globe');
        const canvas = globe.locator('canvas');
        await globeStill(page);
        assert.equal(await canvas.getAttribute('tabindex'), null, 'The globe has no keyboard navigation');
        assert.equal(await canvas.getAttribute('aria-keyshortcuts'), null);
        const originalLongitude = await globe.getAttribute('data-longitude');
        await globe.locator('[data-direction="east"]').click();
        await page.waitForFunction(longitude => document.querySelector('#wlv-country-globe').dataset.longitude !== longitude, originalLongitude);
        await globe.locator('[data-direction="reset"]').click();
        await globeStill(page);
        await page.waitForFunction(longitude => document.querySelector('#wlv-country-globe').dataset.longitude === longitude, originalLongitude);
        const bounds = await canvas.boundingBox();
        await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2);
        await page.mouse.down();
        await page.mouse.move(bounds.x + bounds.width * 0.7, bounds.y + bounds.height / 2, { steps: 8 });
        await page.mouse.up();
        await page.waitForFunction(longitude => document.querySelector('#wlv-country-globe').dataset.longitude !== longitude, originalLongitude);
        assert.equal(await page.locator('#co_select_country').inputValue(), 'BRA', 'Dragging does not select another country');
        const draggedLongitude = await globe.getAttribute('data-longitude');
        await canvas.evaluate(node => node.dispatchEvent(new KeyboardEvent('keydown', {key:'ArrowLeft', bubbles:true})));
        assert.equal(await globe.getAttribute('data-longitude'), draggedLongitude);
        assert.doesNotMatch(await globe.locator('.wlv-globe-status').textContent(), /No centro|At the center/);
        assert.doesNotMatch(await globe.locator('.wlv-globe-instructions').textContent(), /teclado|keyboard|Enter/);
        await globe.locator('[data-direction="reset"]').click();
        await globeStill(page);
        await page.waitForFunction(longitude => document.querySelector('#wlv-country-globe').dataset.longitude === longitude, originalLongitude);
        const facts = await page.locator('#co_entry_facts').textContent();
        assert.match(facts, /210,6%/);
        assert.match(facts, /−1,94/);
        await select(page, 'co_entry_method', 'WIOD13');
        await page.waitForFunction(() => document.querySelector('#co_entry_source')?.textContent.includes('WIOD13'));
        await idle(page);
        assert.match(await page.locator('#co_entry_description').textContent(), /2007/);
        await select(page, 'co_entry_method', 'WIOD16');
        await page.waitForFunction(() => document.querySelector('#co_entry_description')?.textContent.includes('2014'));
        await select(page, 'co_select_country', 'USA');
        await countryReady(page, 'Estados Unidos');
        await globeStill(page);
        assert.ok(await page.locator('.wlv-country-chart-trade .wlv-country-chart-gap-received').count() > 0);
        await page.screenshot({ path: path.join(campaign, 'results', 'country-entry-usa.png') });
        // Click actual Canadian geography in the hemisphere centered on the USA.
        const canada = await page.evaluate(() => {
          const host = document.querySelector('#wlv-country-globe');
          const canvas = host.querySelector('canvas'); const b = canvas.getBoundingClientRect();
          const projection = WLVCountryGeo.geoOrthographic().rotate([-Number(host.dataset.longitude), -Number(host.dataset.latitude), 0])
            .translate([b.width / 2, b.width / 2]).scale(b.width * 0.455);
          const point = projection([-106, 56]); return { x: b.x + point[0], y: b.y + point[1] };
        });
        await canvas.evaluate(node => {
          window.countryGlobeFrames = [];
          node.addEventListener('pointerup', () => {
            const end = performance.now() + 1100;
            function sample() {
              const host = document.querySelector('#wlv-country-globe');
              window.countryGlobeFrames.push([host.dataset.longitude, host.dataset.latitude, host.dataset.animating]);
              if (performance.now() < end) requestAnimationFrame(sample);
            }
            requestAnimationFrame(sample);
          }, {once:true});
        });
        await page.mouse.click(canada.x, canada.y);
        await countryReady(page, 'Canadá');
        await globeStill(page);
        assert.equal(await page.locator('#co_select_country').inputValue(), 'CAN', 'A globe click updates the selector and country data');
        const frames = await page.evaluate(() => window.countryGlobeFrames);
        assert.ok(new Set(frames.map(frame => frame.slice(0, 2).join(','))).size > 4, 'Centering interpolates across multiple frames');
        assert.ok(frames.some(frame => frame[2] === 'true'), 'A country click starts the centering animation');
        await select(page, 'co_select_country', 'WWW');
        await page.waitForFunction(() => document.querySelector('.wlv-country-chart-empty'));
        assert.ok((await page.locator('#co_entry_description').textContent()).includes('não está disponível'));
        await select(page, 'co_select_country', 'BRA');
        await countryReady(page, 'Brasil');
      }
      if (width === 1440) await page.locator('#co_entry_more').evaluate(node => {
        window.countryScrollFrames = [];
        node.addEventListener('click', () => {
          const end = performance.now() + 1800;
          function sample() {
            window.countryScrollFrames.push(document.querySelector('body > .container-fluid').scrollTop);
            if (performance.now() < end) requestAnimationFrame(sample);
          }
          requestAnimationFrame(sample);
        }, {once:true});
      });
      await page.locator('#co_entry_more').click();
      await page.locator('#wlv-country-content').waitFor({ state: 'visible' });
      await page.waitForFunction(() => document.querySelector('#co_panel_profile')?.textContent.includes('WIOD16'));
      if (width === 1440) {
        await page.waitForFunction(() => {
          const detail = document.querySelector('#wlv-country-detail').getBoundingClientRect();
          const container = document.querySelector('body > .container-fluid').getBoundingClientRect();
          return Math.abs(detail.top - container.top) < 3;
        }, null, {timeout:5000}).catch(async error => {
          const scroll = await page.evaluate(() => {
            const detail = document.querySelector('#wlv-country-detail').getBoundingClientRect();
            const container = document.querySelector('body > .container-fluid');
            return {detailTop:detail.top, containerTop:container.getBoundingClientRect().top,
              top:container.scrollTop, height:container.clientHeight, full:container.scrollHeight,
              samples:window.countryScrollFrames};
          });
          throw new Error(error.message + ' ' + JSON.stringify(scroll));
        });
        assert.ok(await page.evaluate(() => new Set(window.countryScrollFrames.map(Math.round)).size > 4), 'Show me more scrolls smoothly to the details');
      }
      await page.locator('.wlv-country-group-toggle').first().click();
      await page.locator('.wlv-country-group-content.in .js-plotly-plot').first().waitFor();
      await page.locator('#co_catalogue_back').click();
      await page.locator('#wlv-country-content').waitFor({ state: 'hidden' });
      assert.equal(await page.locator('#co_select_country').inputValue(), 'BRA');
      // Close the selectize dropdown opened when focus returns to the overview.
      await page.keyboard.press('Escape');
      await page.locator('#language_toggle').click();
      await countryReady(page, 'Brazil');
      assert.match(await page.locator('#co_entry_more').textContent(), /Show me more/);
      assert.match(await page.locator('#co_entry_facts').textContent(), /210\.6%/);
      evidence.views.push({ ...layout, status: 'passed' });
      await context.close();
    }
    assert.deepEqual(evidence.errors, []);
    evidence.status = 'passed';
    console.log('COUNTRY_ENTRY_BROWSER_OK');
  } catch (error) {
    evidence.status = 'failed'; evidence.failure = String(error); process.exitCode = 1; console.error(error);
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(campaign, 'results', 'country-entry-check.json'), JSON.stringify(evidence, null, 2));
  }
})();
