// Regression: language refreshes must not restore stale Download selections.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
if (!campaign) throw new Error('WLV_CAMPAIGN_ROOT is required');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const evidence = [];
  try {
    for (const width of [1440, 390]) {
      const page = await browser.newPage({ viewport: { width, height: 900 }, acceptDownloads: true });
      const errors = [], indicatorRequests = [];
      page.on('pageerror', error => errors.push(String(error)));
      page.on('request', request => {
        if (request.url().includes('/dataobj/dl_indicator')) indicatorRequests.push(request.url());
      });
      try {
        await page.goto('http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38129'));
        await page.waitForFunction(() => window.WLVMap?.stats('map')?.layers > 0);
        if (width < 768) await page.locator('.navbar-toggle').click();
        await page.locator('#main_nav a[data-value="download"]').click();
        const choose = async (id, value) => {
          await page.locator('#' + id).evaluate((node, value) => node.selectize.setValue(value), value);
          await page.waitForFunction(({ id, value }) => Shiny.shinyapp.$inputValues[id] === value, { id, value });
        };
        const ready = async id => page.waitForFunction(id => document.getElementById(id)?.getAttribute('href')?.includes('/download/'), id);
        await choose('dl_method', 'WIOD13');
        await page.waitForFunction(() => document.getElementById('dl_country').selectize.options.BRA);
        await choose('dl_country', 'BRA');
        await choose('dl_indicator', 'surplus_value.empe_p.r.pc');
        await ready('dl_file');
        await choose('dl_ml_method', 'WIOD13');
        await page.waitForFunction(() => document.getElementById('dl_ml_country').selectize.options.BRA);
        await choose('dl_ml_country', 'BRA');
        await page.waitForFunction(() => document.getElementById('dl_ml_partner').selectize.options.USA);
        await choose('dl_ml_partner', 'USA');
        await ready('dl_ml_file');

        // Change values as soon as the page acknowledges the language, while
        // translated option updates may still be in flight.
        await page.locator('#language_toggle').click();
        await page.waitForFunction(() => document.documentElement.lang === 'en');
        await choose('dl_ml_partner', '');
        await choose('dl_indicator', 'gdp.s.mv');
        await page.waitForFunction(() => {
          const select = document.getElementById('dl_country').selectize;
          return select.options.BRA?.[select.settings.labelField] === 'Brazil';
        });
        await page.locator('#dl_ml_download button[disabled]').waitFor({ state: 'visible' });
        await page.waitForFunction(() => !document.documentElement.classList.contains('shiny-busy'));
        assert.equal(await page.locator('#dl_ml_partner').inputValue(), '');
        assert.equal(await page.locator('#dl_indicator').inputValue(), 'gdp.s.mv');

        await choose('dl_ml_ind_cat', 'CX.');
        await choose('dl_ml_ind_scope', 'T.');
        await choose('dl_ml_ind_un', 'MP');
        await ready('dl_ml_file');
        const [download] = await Promise.all([page.waitForEvent('download'), page.locator('#dl_ml_file').click()]);
        assert.equal(download.suggestedFilename(), 'BRA.CX.T.MP.WIOD13.xlsx');
        const output = path.join(campaign, 'results', 'download-race-' + width + '.xlsx');
        await download.saveAs(output);
        assert.ok(fs.statSync(output).size > 1000);
        assert.deepEqual(indicatorRequests, [], 'Small indicator options stay local through language changes');
        assert.deepEqual(errors, []);
        evidence.push({ width, status: 'passed', filename: download.suggestedFilename(), errors });
      } finally {
        await page.close();
      }
    }
    console.log('DOWNLOAD_RACE_BROWSER_OK');
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(campaign, 'results', 'download-races.json'), JSON.stringify(evidence, null, 2));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
