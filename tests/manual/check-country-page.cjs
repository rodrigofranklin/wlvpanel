// Dedicated Country page regression check. Use an active campaign and local app.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const campaign = process.env.WLV_CAMPAIGN_ROOT;
if (!campaign) throw new Error('WLV_CAMPAIGN_ROOT is required');
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38129');
const evidence = { viewports: [], errors: [] };

async function settle(page) {
  await page.waitForFunction(() => !document.documentElement.classList.contains('shiny-busy'));
}
async function select(page, id, value) {
  await page.locator('#' + id).evaluate((node, value) => node.selectize.setValue(value), value);
}
async function nav(page, value) {
  if (await page.locator('.navbar-toggle').isVisible() &&
      !(await page.locator('.navbar-collapse').isVisible())) await page.locator('.navbar-toggle').click();
  await page.locator('#main_nav a[data-value="' + value + '"]').click();
  await page.waitForFunction(value => Shiny.shinyapp.$inputValues.main_nav === value, value);
  await settle(page);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    for (const width of [1440, 390, 320]) {
      const context = await browser.newContext({ viewport: { width, height: width > 768 ? 1000 : 844 }, hasTouch: width < 768 });
      const page = await context.newPage();
      page.on('pageerror', error => evidence.errors.push(String(error)));
      await page.goto(url, { waitUntil: 'domcontentloaded' });
      await page.waitForFunction(() => window.WLVMap && WLVMap.stats('map')?.layers > 0, null, { timeout: 45000 });
      await nav(page, 'country');
      await select(page, 'co_select_country', 'BRA');
      await page.waitForFunction(() => document.getElementById('co_panel_title')?.textContent === 'Brasil');
      await page.waitForFunction(() => document.querySelectorAll('.wlv-country-chart-slot .js-plotly-plot').length > 0);
      await settle(page);
      assert.equal(await page.locator('#co_select_country').count(), 1, 'Country input occurs once');
      assert.equal(await page.locator('#wlv-country-overlay, #close_country_panel').count(), 0, 'Country is an ordinary page');
      assert.equal(await page.locator('#wlv-country-page').evaluate(node => getComputedStyle(node).position), 'static');
      const profile = await page.locator('#co_panel_profile').textContent();
      assert.ok(profile.includes('WIOD13') && profile.includes('WIOD16'), 'Country comparisons remain available');
      await page.waitForFunction(() => document.querySelector('#co_panel_sector_WIOD13 tbody tr'));
      const layout = await page.evaluate(() => ({
        width: innerWidth, scrollWidth: document.documentElement.scrollWidth,
        plots: document.querySelectorAll('.wlv-country-chart-slot .js-plotly-plot').length,
        errors: Array.from(document.querySelectorAll('.shiny-output-error')).filter(node => node.getClientRects().length).map(node => node.textContent)
      }));
      assert.ok(layout.scrollWidth <= width + 2, 'No horizontal page overflow: ' + JSON.stringify(layout));
      assert.deepEqual(layout.errors, []);
      await page.screenshot({ path: path.join(campaign, 'results', 'country-page-' + width + '.png') });

      const info = page.locator('.wlv-country-chart-info').first();
      await info.click();
      await page.locator('#wlv-country-info').waitFor({ state: 'visible' });
      await page.waitForFunction(() => document.activeElement?.id === 'info_close_button');
      await page.keyboard.press('Escape');
      await page.locator('#wlv-country-info').waitFor({ state: 'hidden' });
      assert.equal(await info.evaluate(node => document.activeElement === node), true, 'Information dialog returns focus');

      if (width === 1440) {
        for (const id of ['co_country_file_WIOD13', 'co_sector_file_WIOD13']) {
          const link = page.locator('#' + id);
          await page.waitForFunction(id => document.getElementById(id)?.getAttribute('href')?.includes('/download/'), id);
          const [download] = await Promise.all([page.waitForEvent('download'), link.click()]);
          assert.match(download.suggestedFilename(), /\.xlsx$/);
          const file = path.join(campaign, 'results', id + '.xlsx');
          await download.saveAs(file);
          assert.ok(fs.statSync(file).size > 1000, 'Country XLSX download contains a workbook');
        }
      }

      await select(page, 'co_panel_sector_select', 'gdp.s.mv');
      await page.evaluate(() => {
        const year = window.jQuery('#co_panel_year');
        year.data('ionRangeSlider').update({ from: 2008 });
        year.trigger('change');
      });
      await page.waitForFunction(() => document.getElementById('co_panel_year_text')?.textContent === '2008');
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.locator('#language_toggle').click();
      await page.waitForFunction(() => document.documentElement.lang === 'en' && document.getElementById('co_panel_title')?.textContent === 'Brazil');
      await settle(page);
      assert.equal(await page.locator('#co_select_country').inputValue(), 'BRA');
      assert.equal(await page.locator('#co_panel_year').inputValue(), '2008');
      assert.equal(await page.locator('#co_panel_sector_select').inputValue(), 'gdp.s.mv');
      assert.equal((await page.locator('#country_page_title').textContent()).trim(), 'Country');

      await nav(page, 'map');
      await nav(page, 'country');
      assert.equal(await page.locator('#co_select_country').inputValue(), 'BRA', 'Navigation preserves country');
      assert.equal(await page.locator('#co_panel_year').inputValue(), '2008', 'Navigation preserves year');
      await select(page, 'co_select_country', '');
      await page.locator('.wlv-country-empty').waitFor({ state: 'visible' });
      await page.waitForFunction(() => document.getElementById('country_page_empty')?.textContent.startsWith('Select a country'));
      assert.match(await page.locator('.wlv-country-empty').textContent(), /Select a country/);
      await page.locator('#wlv-country-detail').waitFor({ state: 'hidden' });
      await select(page, 'co_select_country', 'AUS');
      await page.waitForFunction(() => document.getElementById('co_panel_title')?.textContent === 'Australia');
      await page.locator('#wlv-country-detail').waitFor({ state: 'visible' });
      await settle(page);
      evidence.viewports.push({ ...layout, country: 'AUS', status: 'passed' });
      await context.close();
    }
    assert.deepEqual(evidence.errors, []);
    evidence.status = 'passed';
    console.log('COUNTRY_PAGE_BROWSER_OK');
  } catch (error) {
    evidence.status = 'failed';
    evidence.failure = String(error);
    process.exitCode = 1;
    console.error(error);
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(campaign, 'results', 'country-page-check.json'), JSON.stringify(evidence, null, 2));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
