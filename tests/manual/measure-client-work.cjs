'use strict';
// Instrumented diagnostic, separate from measure-user-performance.cjs baseline.
// The only global hook measures the exact document-wide translation selector.
// Its duration excludes the caller's translation loop and observer callbacks.
// Flow mutations are observed only inside the existing trade SVG during one pan.
const {chromium} = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')));
for (const key of ['TEMP', 'TMP', 'TMPDIR']) {
  assert.equal(path.resolve(process.env[key]), path.resolve(campaign, 'scratch'));
}
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || 38134);
const output = path.join(campaign, 'results', 'client-work.json');
const result = {
  method: {
    instrumented: true,
    baseline: false,
    repetitions: 1,
    viewport: {width: 1440, height: 1000},
    locale: 'pt-BR',
    quietWindowMs: 300,
    network: 'unthrottled loopback',
    cpu: 'unthrottled',
    selector: "Document.querySelectorAll('[data-wlv-label]')",
    selectorDuration: 'Only the original selector call, excluding translation iteration and MutationObserver callbacks.',
    phaseDuration: 'Wall time through the stated readiness checks; instrumentation overhead is included.',
    flowObserver: 'childList on #trade-map svg.wlv-trade-flow-overlay only; one Leaflet panBy([30, 0], {animate:false}).',
    interpretation: 'Counts describe work performed. They do not establish an achievable performance gain.'
  },
  phases: [],
  errors: [],
  completed: false
};

async function settle(page) {
  await page.evaluate(() => { window.clientWorkQuiet = 0; });
  await page.waitForFunction(() => {
    if (document.documentElement.classList.contains('shiny-busy')) {
      window.clientWorkQuiet = 0;
      return false;
    }
    if (!window.clientWorkQuiet) window.clientWorkQuiet = performance.now();
    return performance.now() - window.clientWorkQuiet >= 300;
  });
}

async function ready(page, tab) {
  await page.waitForFunction(tab => window.Shiny?.shinyapp?.$inputValues.main_nav === tab, tab);
  if (tab === 'about') {
    await page.locator('[data-wlv-label="about2.title"]').waitFor({state: 'visible'});
  }
  if (tab === 'map') {
    await page.waitForFunction(() => window.WLVMap?.stats('map')?.layers > 0 &&
      document.getElementById('map')?.getAttribute('aria-busy') === 'false');
  }
  if (tab === 'country') {
    await page.waitForFunction(() => document.getElementById('wlv-country-entry')?.dataset.state === 'ready');
  }
  if (tab === 'trade') {
    await page.waitForFunction(() => document.getElementById('trade-app')?.dataset.ready === 'true');
  }
  await settle(page);
}

async function nav(page, tab) {
  await page.locator('#main_nav a[data-value="' + tab + '"]').click();
  await ready(page, tab);
}

(async () => {
  let browser;
  try {
    browser = await chromium.launch({headless: true});
    const context = await browser.newContext({viewport: result.method.viewport, locale: result.method.locale});
    const page = await context.newPage();
    page.setDefaultTimeout(90000);
    page.on('pageerror', error => result.errors.push(error.message));
    await page.addInitScript(() => {
      const original = Document.prototype.querySelectorAll;
      const counters = Object.create(null);
      let phase = 'opening_about';
      function record() {
        return counters[phase] || (counters[phase] = {calls: 0, totalQueryMs: 0, maxQueryMs: 0, totalMatches: 0});
      }
      Document.prototype.querySelectorAll = function (selector) {
        if (selector !== '[data-wlv-label]') return original.apply(this, arguments);
        const start = performance.now();
        const nodes = original.apply(this, arguments);
        const duration = performance.now() - start;
        const entry = record();
        entry.calls += 1;
        entry.totalQueryMs += duration;
        entry.maxQueryMs = Math.max(entry.maxQueryMs, duration);
        entry.totalMatches += nodes.length;
        return nodes;
      };
      window.clientWorkAudit = {
        begin(name) { phase = name; record(); },
        snapshot() { return {phase, ...record()}; }
      };
    });

    async function measure(name, action, initial = false) {
      if (!initial) await page.evaluate(name => window.clientWorkAudit.begin(name), name);
      const start = Date.now();
      const details = await action();
      const elapsedMs = Date.now() - start;
      const snapshot = await page.evaluate(() => ({
        ...window.clientWorkAudit.snapshot(),
        tab: document.body.dataset.wlvTab,
        language: document.documentElement.lang,
        visibleErrors: [...document.querySelectorAll('.shiny-output-error')]
          .filter(node => node.getClientRects().length).map(node => node.textContent)
      }));
      assert.deepEqual(snapshot.visibleErrors, []);
      result.phases.push({name, elapsedMs, ...snapshot, ...(details || {})});
      fs.writeFileSync(output, JSON.stringify(result, null, 2), 'utf8');
      console.log('CLIENT_WORK', name, snapshot.calls, snapshot.totalQueryMs.toFixed(3));
    }

    await measure('opening_about', async () => {
      await page.goto(url, {waitUntil: 'load'});
      await ready(page, 'about');
    }, true);
    await measure('open_map', () => nav(page, 'map'));
    await measure('open_country', () => nav(page, 'country'));
    await measure('return_about', () => nav(page, 'about'));
    await measure('language_french', async () => {
      await page.locator('#language_menu_toggle').click();
      await page.locator('#language_menu [lang="fr"]').click();
      await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.l === 'Fran\u00e7ais' &&
        document.documentElement.lang === 'fr');
      await settle(page);
    });
    await measure('idle_about', async () => { await page.waitForTimeout(2000); });
    await measure('open_trade_map', async () => {
      await nav(page, 'trade');
      await page.locator('#trade-view a[data-value="map"]').click();
      await page.locator('#trade-map').waitFor({state: 'visible'});
      await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues['trade-view'] === 'map' &&
        window.wlvTradeMaps?.['trade-map'] && window.WLVTrade?.flows('trade-map')?.count > 0 &&
        document.querySelector('#trade-map svg.wlv-trade-flow-overlay > g.wlv-trade-flow'));
      await settle(page);
    });
    await measure('trade_pan', async () => {
      const flows = await page.evaluate(async () => {
        const map = window.wlvTradeMaps['trade-map'];
        const svg = document.querySelector('#trade-map svg.wlv-trade-flow-overlay');
        const first = svg.querySelector('g.wlv-trade-flow');
        const before = [...svg.querySelectorAll('g.wlv-trade-flow')];
        const beforeCenter = map.getCenter();
        const beforePath = first.querySelector('path').getAttribute('d');
        const count = {records: 0, addedGroups: 0, removedGroups: 0};
        const consume = mutations => {
          for (const mutation of mutations) {
            count.records += 1;
            count.addedGroups += [...mutation.addedNodes]
              .filter(node => node.nodeType === 1 && node.matches('g.wlv-trade-flow')).length;
            count.removedGroups += [...mutation.removedNodes]
              .filter(node => node.nodeType === 1 && node.matches('g.wlv-trade-flow')).length;
          }
        };
        const observer = new MutationObserver(consume);
        observer.observe(svg, {childList: true});
        try {
          await new Promise(resolve => {
            map.once('moveend', resolve);
            map.panBy([30, 0], {animate: false});
          });
          // Drawing is scheduled through requestAnimationFrame. Two completed
          // frames allow its childList records to reach this local observer.
          await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
          consume(observer.takeRecords());
          const after = [...svg.querySelectorAll('g.wlv-trade-flow')];
          const afterCenter = map.getCenter();
          return {
            ...count,
            beforeCount: before.length,
            afterCount: after.length,
            firstGroupRetained: first === after[0],
            originalGroupsStillConnected: before.filter(node => node.isConnected).length,
            firstPathChanged: beforePath !== after[0]?.querySelector('path')?.getAttribute('d'),
            beforeCenter: {lat: beforeCenter.lat, lng: beforeCenter.lng},
            afterCenter: {lat: afterCenter.lat, lng: afterCenter.lng},
            observedFrames: 2
          };
        } finally {
          observer.disconnect();
        }
      });
      await settle(page);
      return {flows};
    });
    assert.deepEqual(result.errors, []);
    result.completed = true;
    await context.close();
  } catch (error) {
    result.failure = {message: error.message, stack: error.stack};
    throw error;
  } finally {
    fs.writeFileSync(output, JSON.stringify(result, null, 2), 'utf8');
    if (browser) await browser.close();
  }
})().catch(error => {
  console.error(error.stack);
  process.exitCode = 1;
});
