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
  if (await page.locator('.navbar-toggle').isVisible()) await page.locator('.navbar-collapse').waitFor({ state: 'hidden' });
  await settle(page);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    for (const width of [1920, 1440, 390, 320]) {
      const context = await browser.newContext({ viewport: { width, height: width > 768 ? 1000 : 844 }, hasTouch: width < 768 });
      const page = await context.newPage();
      page.on('pageerror', error => evidence.errors.push(String(error)));
      await page.goto(url, { waitUntil: 'domcontentloaded' });
      await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.main_nav, null, { timeout: 45000 });
      await nav(page, 'country');
      await page.locator('#wlv-country-catalogue').waitFor({ state: 'visible' });
      await page.locator('[data-wlv-country="BRA"]').waitFor();
      assert.equal(await page.locator('#co_select_country').inputValue(), '', 'Country opens on the catalogue');
      assert.ok(await page.locator('.wlv-country-catalogue-group').count() >= 5, 'Countries are grouped geographically');
      const countryCodes = await page.locator('[data-wlv-country]').evaluateAll(nodes => nodes.map(node => node.dataset.wlvCountry));
      assert.ok(countryCodes.includes('ROW') && countryCodes.includes('WWW'), 'Aggregate observations are retained');
      assert.equal((await page.locator('[data-wlv-country="TWN"]').textContent()).trim(), 'Taiwan, China', 'Country catalogue uses the requested name');
      assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 2), 'Catalogue fits the viewport');
      await page.screenshot({ path: path.join(campaign, 'results', 'country-catalogue-' + width + '.png') });
      await page.locator('#co_catalogue_region').selectOption('Europe');
      await page.waitForFunction(() => document.querySelectorAll('.wlv-country-catalogue-group').length === 1 && !document.querySelector('[data-wlv-country="BRA"]'));
      assert.equal(await page.locator('[data-wlv-country="GBR"]').count(), 1, 'Continent filter retains the matching countries');
      await page.locator('#co_catalogue_region').selectOption('');
      await page.locator('#co_catalogue_search').fill('mex');
      await page.waitForFunction(() => document.querySelectorAll('[data-wlv-country]').length === 1);
      assert.equal(await page.locator('[data-wlv-country="MEX"] mark').count(), 1, 'Search is accent-insensitive and highlighted');
      assert.match(await page.locator('.wlv-country-catalogue-group h2').textContent(), /Norte/);
      await page.locator('#co_catalogue_search').fill('');
      await page.locator('[data-wlv-country="BRA"]').click();
      await page.waitForFunction(() => document.getElementById('co_panel_title')?.textContent === 'Brasil');
      await page.waitForFunction(() => document.querySelectorAll('.wlv-country-chart-slot .js-plotly-plot').length > 0);
      await settle(page);
      assert.equal(await page.locator('#co_select_country').count(), 1, 'Country input occurs once');
      assert.equal(await page.locator('#wlv-country-overlay, #close_country_panel').count(), 0, 'Country is an ordinary page');
      assert.equal(await page.locator('.wlv-country-sector-jump, .wlv-country-sector-subtitle, #country_page_description').count(), 0, 'Redundant copy is removed');
      const profile = await page.locator('#co_panel_profile').textContent();
      assert.ok(profile.includes('WIOD13') && profile.includes('WIOD16'), 'Country comparisons remain available');
      await page.waitForFunction(() => document.querySelector('#co_panel_sector_WIOD13 tbody tr'));
      const layout = await page.evaluate(() => ({
        width: innerWidth, scrollWidth: document.documentElement.scrollWidth,
        pageScroll: (() => { const node = document.querySelector('.wlv-page-scroll') || document.querySelector('body > .container-fluid'); return node ? { width: node.clientWidth, scrollWidth: node.scrollWidth } : null; })(),
        plots: document.querySelectorAll('.wlv-country-chart-slot .js-plotly-plot').length,
        chartColumns: getComputedStyle(document.querySelector('.wlv-country-chart-grid')).gridTemplateColumns.split(' ').length,
        overviewColumns: getComputedStyle(document.querySelector('.wlv-country-overview')).gridTemplateColumns.split(' ').length,
        sectors: (() => { const x = document.getElementById('wlv-country-sectors').getBoundingClientRect(); return { x: x.x, y: x.y }; })(),
        profile: (() => { const x = document.querySelector('.wlv-country-profile').getBoundingClientRect(); return { right: x.right, y: x.y }; })(),
        errors: Array.from(document.querySelectorAll('.shiny-output-error')).filter(node => node.getClientRects().length).map(node => node.textContent)
      }));
      assert.ok(layout.scrollWidth <= width + 2, 'No horizontal page overflow: ' + JSON.stringify(layout));
      if (layout.pageScroll) assert.ok(layout.pageScroll.scrollWidth <= layout.pageScroll.width + 2, 'Country content fits its scroll container');
      assert.deepEqual(layout.errors, []);
      assert.ok(layout.chartColumns <= 2, 'There are never more than two chart columns');
      if (width > 1180) {
        assert.equal(layout.chartColumns, 2, 'Desktop charts use two columns');
        assert.equal(layout.overviewColumns, 2, 'Profile and downloads share their own first row');
        assert.ok(layout.sectors.x > layout.profile.right && Math.abs(layout.sectors.y - layout.profile.y) < 2, 'Sector panel starts alongside the profile in the right column');
        const divisions = await page.evaluate(() => ({
          overview: document.querySelector('.wlv-country-downloads').getBoundingClientRect().x,
          charts: document.querySelector('.wlv-country-chart-slot:nth-child(2)').getBoundingClientRect().x
        }));
        assert.ok(Math.abs(divisions.overview - divisions.charts) > 15, 'Overview division is independent of the chart grid');
      }
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
      await page.waitForFunction(() => Shiny.shinyapp.$inputValues.co_panel_year === 2008);
      await page.evaluate(() => (document.querySelector('.wlv-page-scroll') || document.scrollingElement).scrollTo(0, 0));
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
      await page.locator('#co_catalogue_back').click();
      await page.locator('#wlv-country-catalogue').waitFor({ state: 'visible' });
      assert.equal((await page.locator('[data-wlv-country="TWN"]').textContent()).trim(), 'Taiwan, China', 'Country name stays the same in English');
      await page.locator('#wlv-country-detail').waitFor({ state: 'hidden' });
      await page.locator('[data-wlv-country="AUS"]').click();
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
