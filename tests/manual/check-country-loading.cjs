'use strict';
// Run against the real Shiny app in an active campaign. Only the delivery time
// of genuine WebSocket responses changes; no output values are fabricated.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')),
  'Use a campaign created by scripts/manage-campaigns.ps1');
for (const name of ['TEMP', 'TMP', 'TMPDIR']) {
  assert.ok(process.env[name], name + ' must point to campaign scratch');
  assert.equal(path.resolve(process.env[name]), path.resolve(campaign, 'scratch'));
}
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38131');
const results = path.join(campaign, 'results');
assert.ok(fs.existsSync(results), 'The campaign results directory must exist');
const evidence = { status: 'running', cases: [], errors: [] };
const pause = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));
async function until(predicate, description, timeout = 45000) {
  const end = Date.now() + timeout;
  while (!predicate()) {
    if (Date.now() >= end) throw new Error('Timed out: ' + description);
    await pause(30);
  }
}

function installFrameAudit() {
  const labels = ['co_entry_labour_title', 'co_entry_labour_unit',
    'co_entry_trade_title', 'co_entry_trade_unit', 'co_entry_globe_title',
    'co_entry_formulas_label', 'co_entry_catalogue_label'];
  const text = id => Boolean(document.getElementById(id)?.textContent.trim());
  const visible = node => Boolean(node && node.getClientRects().length &&
    getComputedStyle(node).visibility !== 'hidden' && getComputedStyle(node).display !== 'none' &&
    Number(getComputedStyle(node).opacity) > 0);
  window.countryLoadingSnapshot = () => {
    const entry = document.getElementById('wlv-country-entry');
    const content = entry?.querySelector('.wlv-entry-content');
    const loader = entry?.querySelector('.wlv-entry-loading');
    const country = document.getElementById('co_select_country');
    const method = document.getElementById('co_entry_method');
    const globe = document.getElementById('wlv-country-globe');
    const readiness = {
      country: Boolean(country?.value && country.options.length),
      method: Boolean(method?.value && method.options.length),
      description: text('co_entry_description'), facts: text('co_entry_facts'),
      source: text('co_entry_source'), labels: labels.every(text),
      labour: Boolean(document.querySelector('#co_entry_labour_chart svg')),
      trade: Boolean(document.querySelector('#co_entry_trade_chart svg')),
      globe: ['true', 'error'].includes(globe?.dataset.ready) && globe?.dataset.received === 'true' &&
        globe?.dataset.selected === country?.value
    };
    return {
      time: performance.now(), state: entry?.dataset.state || null,
      busy: content?.getAttribute('aria-busy') || null,
      contentExists: Boolean(content), loaderExists: Boolean(loader),
      contentVisibility: content ? getComputedStyle(content).visibility : null,
      contentInert: content?.inert ?? null,
      contentAriaHidden: content?.getAttribute('aria-hidden') ?? null,
      loaderVisible: visible(loader), contentVisible: visible(content),
      loaderInsideBusyRegion: Boolean(loader?.closest('[aria-busy="true"]')),
      modalVisible: visible(document.getElementById('wlv-country-info')),
      activeTab: document.querySelector('#main_nav li.active > a')?.dataset.value,
      readiness, complete: Object.values(readiness).every(Boolean),
      globeReady: globe?.dataset.ready || null,
      globeReceived: globe?.dataset.received || null,
      country: country?.value || '', method: method?.value || ''
    };
  };
  const audit = window.countryLoadingAudit = {
    frames: 0, loadingFrames: 0, readyFrames: 0, violations: [], first: null, firstReady: null
  };
  function record(reason, frame) {
    if (audit.violations.length < 12) audit.violations.push({ reason, frame });
  }
  function sample() {
    const frame = window.countryLoadingSnapshot();
    if (frame.modalVisible) record('The information modal appeared during startup', frame);
    if (frame.contentExists && frame.loaderExists) {
      audit.frames++;
      if (!audit.first) audit.first = frame;
      if (frame.state === 'loading') {
        audit.loadingFrames++;
        if (frame.contentVisibility !== 'hidden' || !frame.contentInert ||
            frame.contentAriaHidden !== 'true' || frame.busy !== 'true') {
          record('A loading frame exposed interactive or visible partial content', frame);
        }
      } else if (frame.state === 'ready') {
        audit.readyFrames++;
        if (!audit.firstReady) audit.firstReady = frame;
        if (!frame.complete) record('The entry became ready before all required content arrived', frame);
      } else record('The entry has no loading/ready state', frame);
    }
    requestAnimationFrame(sample);
  }
  requestAnimationFrame(sample);
}

async function interceptResponses(page, delayChart) {
  const transport = {
    received: 0, forwarded: 0, chartMessages: 0,
    initial: [], charts: [], initialClosed: true, chartClosed: delayChart,
    disposed: false, tail: Promise.resolve(), errors: []
  };
  function send(route, message) {
    transport.tail = transport.tail.then(async () => {
      // Expose intermediate real payloads to the browser for multiple frames.
      await pause(45);
      if (transport.disposed) return;
      try { route.send(message); transport.forwarded++; }
      catch (error) { transport.errors.push(String(error)); }
    });
  }
  function forward(route, message) {
    let payload;
    try { payload = JSON.parse(Buffer.isBuffer(message) ? message.toString('utf8') : message); }
    catch (_) { send(route, message); return; }
    if (transport.chartClosed && payload?.values &&
        Object.prototype.hasOwnProperty.call(payload.values, 'co_entry_trade_chart')) {
      transport.chartMessages++;
      // Shiny can batch every output in one message. Hold just this genuine
      // value and let all other original fields reach the client immediately.
      transport.charts.push({ route, message: JSON.stringify({ values: {
        co_entry_trade_chart: payload.values.co_entry_trade_chart
      } }) });
      delete payload.values.co_entry_trade_chart;
      send(route, JSON.stringify(payload));
    } else send(route, message);
  }
  await page.routeWebSocket('**/*', route => {
    const server = route.connectToServer();
    server.onMessage(message => {
      transport.received++;
      if (transport.initialClosed) transport.initial.push({ route, message });
      else forward(route, message);
    });
  });
  transport.releaseInitial = () => {
    transport.initialClosed = false;
    transport.initial.splice(0).forEach(item => forward(item.route, item.message));
  };
  transport.releaseChart = () => {
    transport.chartClosed = false;
    transport.charts.splice(0).forEach(item => send(item.route, item.message));
  };
  return transport;
}

function assertLoading(snapshot, reason) {
  assert.equal(snapshot.state, 'loading', reason);
  assert.equal(snapshot.busy, 'true', reason + ': aria-busy');
  assert.equal(snapshot.contentVisibility, 'hidden', reason + ': hidden content');
  assert.equal(snapshot.contentInert, true, reason + ': inert content');
  assert.equal(snapshot.contentAriaHidden, 'true', reason + ': aria-hidden');
  assert.equal(snapshot.loaderVisible, true, reason + ': visible loading state');
  assert.equal(snapshot.loaderInsideBusyRegion, false, reason + ': loading status can be announced immediately');
  assert.equal(snapshot.modalVisible, false, reason + ': information modal stays closed');
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    for (const width of [1440, 390]) {
      for (const geographyError of [false, true]) {
        const name = 'country-loading-' + width + (geographyError ? '-globe-error' : '-delayed-chart');
        const entry = { name, width, geographyError, reducedMotion: width === 390, status: 'running' };
        evidence.cases.push(entry);
        const context = await browser.newContext({
          locale: 'pt-BR', viewport: { width, height: width === 1440 ? 1000 : 844 },
          hasTouch: width === 390, reducedMotion: width === 390 ? 'reduce' : 'no-preference'
        });
        let page, transport;
        try {
          await context.addCookies([{ name: 'wlv_last_tab', value: 'country', url }]);
          await context.addInitScript(installFrameAudit);
          if (geographyError) await context.route('**/wlv-countries-110m.geojson*', route => route.abort('failed'));
          page = await context.newPage();
          page.on('pageerror', error => evidence.errors.push({ name, error: String(error) }));
          transport = await interceptResponses(page, !geographyError);
          await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 60000 });
          await page.locator('#wlv-country-entry').waitFor({ state: 'visible' });
          await until(() => transport.received > 0, 'at least one real server response was intercepted');
          await page.waitForFunction(() => window.countryLoadingAudit?.loadingFrames >= 3);
          entry.initial = await page.evaluate(() => window.countryLoadingSnapshot());
          assert.equal(entry.initial.activeTab, 'country', 'The saved country tab opens before server data arrives');
          assert.equal(transport.forwarded, 0, 'The initial screenshot precedes the first server payload');
          assertLoading(entry.initial, name + ': before the first response');
          await page.screenshot({ path: path.join(results, name + '-initial.png') });

          transport.releaseInitial();
          if (!geographyError) {
            await until(() => transport.chartMessages > 0, 'the actual trade chart output was withheld');
            await page.waitForFunction(() => {
              const r = window.countryLoadingSnapshot().readiness;
              return r.country && r.method && r.description && r.facts && r.source && r.labels && r.labour && r.globe;
            }, null, { timeout: 60000 });
            // Hold the final required output over several animation frames.
            await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() =>
              requestAnimationFrame(() => requestAnimationFrame(resolve)))));
            entry.partial = await page.evaluate(() => window.countryLoadingSnapshot());
            assert.equal(entry.partial.readiness.trade, false, 'The retained chart has not reached the page');
            assertLoading(entry.partial, name + ': other outputs arrived but trade chart is missing');
            await page.screenshot({ path: path.join(results, name + '-partial.png') });
            transport.releaseChart();
          }
          await page.waitForFunction(() => document.getElementById('wlv-country-entry')?.dataset.state === 'ready',
            null, { timeout: 60000 });
          await page.waitForFunction(() => window.countryLoadingAudit.readyFrames >= 3);
          entry.ready = await page.evaluate(() => window.countryLoadingSnapshot());
          assert.equal(entry.ready.complete, true, 'Ready means every required output and the globe arrived');
          assert.equal(entry.ready.busy, 'false');
          assert.equal(entry.ready.contentVisibility, 'visible');
          assert.equal(entry.ready.contentInert, false);
          assert.notEqual(entry.ready.contentAriaHidden, 'true');
          assert.equal(entry.ready.loaderVisible, false);
          assert.equal(entry.ready.modalVisible, false);
          assert.equal(entry.ready.globeReceived, 'true');
          assert.equal(entry.ready.globeReady, geographyError ? 'error' : 'true',
            'A failed geography request leaves a usable country profile');
          if (entry.reducedMotion) {
            entry.motion = await page.locator('.wlv-entry-content').evaluate(node => {
              const style = getComputedStyle(node);
              return { transition: style.transitionDuration, animation: style.animationDuration,
                animationDelay: style.animationDelay, opacity: style.opacity };
            });
            const seconds = value => value.split(',').map(part => parseFloat(part) * (part.trim().endsWith('ms') ? 0.001 : 1));
            for (const key of ['transition', 'animation', 'animationDelay']) {
              assert.ok(seconds(entry.motion[key]).every(value => Math.abs(value) <= 0.001),
                'Reduced motion disables the content fade: ' + JSON.stringify(entry.motion));
            }
            assert.equal(Number(entry.motion.opacity), 1, 'Reduced motion reveals the content immediately');
          }
          entry.audit = await page.evaluate(() => window.countryLoadingAudit);
          assert.deepEqual(entry.audit.violations, [], 'No frame displays a modal or a partial ready state');
          assert.ok(entry.audit.loadingFrames >= 3 && entry.audit.readyFrames >= 3);
          assert.deepEqual(transport.errors, []);
          entry.transport = { received: transport.received, forwarded: transport.forwarded,
            chartMessages: transport.chartMessages };
          await page.screenshot({ path: path.join(results, name + '-ready.png') });
          entry.status = 'passed';
        } catch (error) {
          entry.status = 'failed';
          entry.failure = String(error);
          if (page) {
            entry.audit = await page.evaluate(() => window.countryLoadingAudit).catch(() => null);
            await page.screenshot({ path: path.join(results, name + '-failure.png') }).catch(() => {});
          }
          throw error;
        } finally {
          if (transport) { transport.disposed = true; await transport.tail; }
          await context.close();
        }
      }
    }
    assert.deepEqual(evidence.errors, []);
    evidence.status = 'passed';
    console.log('COUNTRY_LOADING_BROWSER_OK');
  } catch (error) {
    evidence.status = 'failed';
    evidence.failure = String(error);
    process.exitCode = 1;
    console.error(error);
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(results, 'country-loading-check.json'), JSON.stringify(evidence, null, 2), 'utf8');
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
