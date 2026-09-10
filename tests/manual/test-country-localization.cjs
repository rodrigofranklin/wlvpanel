// An isolated DOM test: no app/server/network and no screenshots are required.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {chromium} = require('playwright');
const api = require('../../www/wlv-country-localization.js');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')));

const first = {id: 'A-BRA', color: 'red', label: 'Brasil'};
const second = {id: 'A-CHN', color: 'amber', label: 'China'};
let state = api.mergeMapDelta(null, {instance: 1, reset: true, layers: [first, second]});
state = api.mergeMapDelta(state, {instance: 1, layers: [{...first, label: 'Brésil'}]});
state = api.mergeMapDelta(state, {instance: 1, layers: [{...second, color: 'black'}]});
assert.deepEqual(Array.from(state.layers.values()), [{...first, label: 'Brésil'}, {...second, color: 'black'}]);
state = api.mergeMapDelta(state, {instance: 2, reset: true, layers: [first]});
assert.deepEqual(Array.from(state.layers.values()), [first], 'A new widget must not reuse the old layer snapshot');

(async () => {
  const browser = await chromium.launch({headless: true});
  const result = {status: 'running'};
  try {
    const page = await browser.newPage();
    await page.setContent(`<!doctype html><html lang="pt-BR"><body>
      <div id="map_indicator_list"><ul><li class="wlv-map-indicator-group">
        <button class="wlv-map-group-header" aria-expanded="true"><span data-wlv-label="group.test">Grupo</span></button>
        <span class="wlv-map-indicator-label" data-wlv-label="test">Indicador</span>
        <button id="help" data-indicator-info="test" aria-label="Sobre Indicador">?</button>
      </li></ul></div>
      <div id="co_entry_labour_chart"><div class="wlv-country-landing-chart" data-wlv-chart-id="v1">
        <div class="wlv-country-chart-frame" style="--wlv-chart-y-chars:1;">
          <svg viewBox="0 0 500 230"><title>Título</title><desc>Descrição</desc>
            <path id="curve" d="M 0 10 C 20 30 40 50 80 90" stroke="#8D2028"></path>
            <rect class="wlv-country-chart-observation" data-year="2000" tabindex="0" role="img" aria-label="Valor 0"><title>Valor 0</title></rect>
          </svg><span class="wlv-country-chart-tick-y">0</span>
        </div>
        <span class="wlv-country-chart-legend-item"><span aria-hidden="true" style="background:red"></span> Jornada </span>
        <p class="wlv-country-chart-note">Ausente</p>
      </div></div>
      <div id="co_entry_trade_chart"><div class="wlv-country-landing-chart wlv-country-chart-empty" data-wlv-chart-id="empty1" role="status">Sem dados</div></div>
      </body></html>`);
    await page.evaluate(() => {
      window.handlers = {};
      window.Shiny = {addCustomMessageHandler: (name, handler) => { window.handlers[name] = handler; }};
      window.language = 'pt';
      window.wlvI18n = {
        label: key => ({pt: {'group.test': 'Grupo', test: 'Indicador'}, fr: {'group.test': 'Groupe', test: 'Indicateur'}})[window.language][key],
        text: (pt, en) => window.language === 'pt' ? pt : en === 'About' ? 'À propos' : en
      };
      window.mapMessages = [];
      window.WLVMap = {receive: message => window.mapMessages.push(message)};
      window.originalCurve = document.querySelector('#curve');
      window.originalObservation = document.querySelector('rect');
      window.originalSwatch = document.querySelector('.wlv-country-chart-legend-item > span');
      window.originalGroup = document.querySelector('.wlv-map-indicator-group');
      window.originalObservation.focus();
      window.message = {lang: 'fr', charts: [
        {output: 'co_entry_labour_chart', id: 'v1', title: 'Titre', description: 'Description', ticks: ['1,25'], y_chars: 4,
          observations: [{year: '2000', text: 'Valeur 1,25'}], legend: ['Journée'], note: 'Indisponible'},
        {output: 'co_entry_trade_chart', id: 'empty1', empty: 'Aucune donnée'}
      ]};
    });
    await page.addScriptTag({path: path.resolve('www/wlv-country-localization.js')});
    await page.evaluate(() => window.handlers['wlv-country-chart-text'](window.message));
    assert.equal(await page.locator('svg > title').textContent(), 'Título', 'A future language waits for its dictionary');
    await page.evaluate(() => { window.language = 'fr'; document.documentElement.lang = 'fr'; });
    await page.waitForFunction(() => document.querySelector('svg > title').textContent === 'Titre');
    const translated = await page.evaluate(() => ({
      title: document.querySelector('svg > title').textContent,
      tick: document.querySelector('.wlv-country-chart-tick-y').textContent,
      legend: document.querySelector('.wlv-country-chart-legend-item').textContent.trim(),
      empty: document.querySelector('.wlv-country-chart-empty').textContent,
      help: document.getElementById('help').getAttribute('aria-label'),
      focused: document.activeElement === window.originalObservation,
      sameCurve: document.querySelector('#curve') === window.originalCurve,
      sameObservation: document.querySelector('rect') === window.originalObservation,
      sameSwatch: document.querySelector('.wlv-country-chart-legend-item > span') === window.originalSwatch,
      sameGroup: document.querySelector('.wlv-map-indicator-group') === window.originalGroup,
      expanded: document.querySelector('.wlv-map-group-header').getAttribute('aria-expanded'),
      path: document.querySelector('#curve').getAttribute('d'),
      annotation: document.querySelector('rect').getAttribute('aria-label'),
      chars: document.querySelector('.wlv-country-chart-frame').style.getPropertyValue('--wlv-chart-y-chars')
    }));
    assert.deepEqual(translated, {title: 'Titre', tick: '1,25', legend: 'Journée', empty: 'Aucune donnée',
      help: 'À propos Indicateur', focused: true, sameCurve: true, sameObservation: true, sameSwatch: true,
      sameGroup: true, expanded: 'true', path: 'M 0 10 C 20 30 40 50 80 90', annotation: 'Valeur 1,25', chars: '4'});
    // A replacement from a country change must consume only its own queued text.
    await page.evaluate(() => {
      const next = structuredClone(window.message); next.charts = [next.charts[0]];
      next.charts[0].id = 'v2'; next.charts[0].title = 'Nouveau pays';
      window.handlers['wlv-country-chart-text'](next);
    });
    assert.equal(await page.locator('svg > title').textContent(), 'Titre');
    await page.evaluate(() => {
      const container = document.getElementById('co_entry_labour_chart');
      const next = container.firstElementChild.cloneNode(true);
      next.setAttribute('data-wlv-chart-id', 'v2');
      container.replaceChildren(next);
    });
    await page.waitForFunction(() => document.querySelector('svg > title').textContent === 'Nouveau pays');
    await page.evaluate(() => {
      window.handlers['wlv-map-delta']({id: 'map', instance: 1, reset: true, layers: [{id: 'A', color: 'red', label: 'A'}, {id: 'B', color: 'blue', label: 'B'}]});
      window.handlers['wlv-map-delta']({id: 'map', instance: 1, layers: [{id: 'A', color: 'red', label: 'A2'}]});
      window.handlers['wlv-map-delta']({id: 'map', instance: 1, layers: [{id: 'B', color: 'blue', label: 'B2'}]});
    });
    assert.deepEqual(await page.evaluate(() => window.mapMessages.at(-1)),
      {id: 'map', layers: [{id: 'A', color: 'red', label: 'A2'}, {id: 'B', color: 'blue', label: 'B2'}]});
    result.status = 'passed';
    result.preserved = ['SVG geometry', 'keyboard focus', 'observation nodes', 'legend swatches', 'group state', 'queued language', 'queued geometry', 'queued map layers'];
  } catch (error) {
    result.status = 'failed'; result.error = String(error); process.exitCode = 1;
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(campaign, 'results', 'country-localization-dom.json'), JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result));
  }
})();
