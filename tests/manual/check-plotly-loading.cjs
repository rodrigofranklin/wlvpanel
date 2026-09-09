// Focused cold-browser check: open a country before visiting Indicators.
// Run inside an active campaign with a local Shiny server already running.
// Delays the Plotly bundle once to check normal asynchronous dependency loading.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const campaign = process.env.WLV_CAMPAIGN_ROOT;
if (!campaign) throw new Error('WLV_CAMPAIGN_ROOT is required');
const delay = Number(process.env.WLV_PLOTLY_DELAY || 7000);
if (!Number.isFinite(delay) || delay < 0 || delay > 15000) throw new Error('Invalid WLV_PLOTLY_DELAY');
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38128');
const evidence = { delayMs: delay, bundleRequests: [], errors: [] };

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    await page.route(/plotly-main[^?]*\.js(?:\?.*)?$/, async route => {
      evidence.bundleRequests.push(route.request().url());
      await new Promise(resolve => setTimeout(resolve, delay));
      await route.continue();
    });
    page.on('pageerror', error => evidence.errors.push(error.stack || error.message));
    page.on('console', message => {
      if (message.type() === 'error' && message.text().includes('[shiny]')) evidence.errors.push(message.text());
    });
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.main_nav, null, { timeout: 45000 });
    for (const english of [true, false]) {
      await page.locator('#language_toggle').click();
      await page.waitForFunction(en => {
        const select = document.getElementById('co_select_country').selectize;
        return document.documentElement.lang === (en ? 'en' : 'pt-BR') &&
          select.options.BRA?.[select.settings.labelField] === (en ? 'Brazil' : 'Brasil');
      }, english);
      await page.waitForFunction(() => !document.documentElement.classList.contains('shiny-busy'));
    }
    await page.locator('.navbar-nav a[data-value="country"]').click();
    await page.locator('#co_select_country').evaluate(node => node.selectize.setValue('BRA'));
    await page.locator('#wlv-country-detail').waitFor({ state: 'visible' });
    await page.waitForFunction(() => document.querySelectorAll('.wlv-country-chart-slot .js-plotly-plot').length > 0, null, { timeout: 30000 });
    await page.waitForFunction(() => !document.documentElement.classList.contains('shiny-busy'));
    evidence.renderedPlots = await page.locator('.wlv-country-chart-slot .js-plotly-plot').count();
    assert.equal(evidence.bundleRequests.length, 1, 'The Plotly core must load only once');
    assert.deepEqual(evidence.errors, []);
    evidence.status = 'passed';
    console.log('PLOTLY_LOADING_CHECK_OK');
  } catch (error) {
    evidence.status = 'failed';
    evidence.failure = String(error);
    process.exitCode = 1;
    console.error(error);
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(campaign, 'results', 'plotly-loading-check.json'), JSON.stringify(evidence, null, 2));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
