// Headless integration checks against the local app. Keep generated evidence
// inside the active campaign and use NODE_PATH for the bundled Playwright.
'use strict';
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')), 'Use an existing campaign');
for (const name of ['TEMP', 'TMP', 'TMPDIR']) {
  assert.equal(path.resolve(process.env[name] || ''), path.resolve(campaign, 'scratch'), name + ' uses campaign scratch');
}
const results = path.join(campaign, 'results');
const widths = (process.env.WLV_BROWSER_WIDTHS || '1440,390,320').split(',').map(Number);
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38129');
const evidence = {status:'running', url, viewports:[], errors:[]};
const rankingPalette = ['#8D2028','#CC858A','#F2DCDD','#FCE7C0','#F6AE2D'];

async function select(page, id, value) {
  await page.locator('#' + id).evaluate((node, selection) => {
    if (node.selectize) node.selectize.setValue(selection);
    else { node.value = selection; jQuery(node).trigger('change'); }
  }, value);
}

async function idle(page) {
  await page.waitForFunction(() => window.Shiny?.shinyapp && !document.documentElement.classList.contains('shiny-busy'));
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

async function ready(page) {
  await page.waitForFunction(() => {
    const chart = document.getElementById('indicators-ranking');
    return chart?._fullLayout && chart._wlvRanking?.payload?.rows?.length && !chart.classList.contains('recalculating') && chart.querySelector('.main-svg');
  }, null, {timeout:60000});
  // Mobile places the comparison selectors above the chart. Reveal the view
  // before waiting for translated outputs which Shiny may suspend offscreen.
  await page.locator('.wlv-indicators-views').scrollIntoViewIfNeeded();
  await page.waitForFunction(() => ['ranking_title','ranking_context','ranking_high','ranking_low','ranking_colors']
    .every(name => document.getElementById('indicators-' + name)?.textContent.trim()) &&
    document.querySelector('.wlv-ranking-toolbar label')?.textContent.trim() &&
    document.getElementById('indicators-ranking_method')?.value);
  await idle(page);
}

async function selectedCountries(page) {
  return page.locator('#indicators-countries').evaluate(node => [].concat(node.selectize.getValue()).sort());
}

async function assertLayout(page) {
  const state = await page.evaluate(() => {
    const chart = document.getElementById('indicators-ranking');
    let scrollport = chart.parentElement;
    while (scrollport && !['auto','scroll'].includes(getComputedStyle(scrollport).overflowX)) scrollport = scrollport.parentElement;
    const bounds = scrollport?.getBoundingClientRect();
    return {width:innerWidth, scroll:document.documentElement.scrollWidth,
      scrollport:bounds ? {left:bounds.left, right:bounds.right, clientWidth:scrollport.clientWidth, scrollWidth:scrollport.scrollWidth} : null,
      errors:[...document.querySelectorAll('.shiny-output-error')].filter(node => node.offsetHeight).map(node => node.textContent)};
  });
  assert.ok(state.scroll <= state.width + 2, 'No horizontal viewport overflow: ' + JSON.stringify(state));
  if (state.scrollport) {
    assert.ok(state.scrollport.left >= -1 && state.scrollport.right <= state.width + 1, 'Ranking scroller remains within the viewport');
  }
  assert.deepEqual(state.errors, [], 'No visible Shiny error');
  return state;
}

// Added when the chart is attached: browser checks use the public chart payload
// and real pointer movement, never call the highlighting handler directly.
async function rankingState(page) {
  return page.locator('#indicators-ranking').evaluate(chart => ({
    meta:chart.layout?.meta || {},
    payload:chart._wlvRanking?.payload,
    hoverCountry:chart.dataset.rankingHoverCountry || '',
    traces:chart.data.map((trace,index) => ({name:trace.name, meta:trace.meta, x:trace.x, y:trace.y, z:trace.z, text:trace.text,
      customdata:trace.customdata, line:trace.line, visible:trace.visible, opacity:trace.opacity, colorscale:trace.colorscale,
      ygap:chart._fullData[index]?.ygap ?? trace.ygap})),
    yaxis:chart._fullLayout.yaxis.range,
    nativeGrid:{x:chart._fullLayout.xaxis.showgrid,y:chart._fullLayout.yaxis.showgrid},
    shapes:chart.layout?.shapes?.length || 0,
    shapeDetails:chart.layout?.shapes || [],
    annotations:chart.layout?.annotations || []
  }));
}

async function assertRankingGrid(page, state, phase) {
  const background = state.traces.find(trace => trace.meta?.role === 'ranking-background');
  assert.equal(background.ygap, 0, phase + ': heatmap rows have no horizontal gaps');
  assert.equal(state.nativeGrid.y, false, phase + ': there is no native horizontal grid');
  assert.equal(state.nativeGrid.x, false, phase + ': the native vertical grid cannot duplicate the custom grid');
  const grid = state.shapeDetails.filter(shape => String(shape.name || '').startsWith('wlv-ranking-grid-'));
  const years = [].concat(state.payload.years || []);
  assert.deepEqual(grid.map(shape => shape.name).sort(), years.map(year => 'wlv-ranking-grid-' + year).sort(),
    phase + ': every year has exactly one vertical grid line');
  grid.forEach(shape => {
    assert.equal(shape.type, 'line', phase + ': grid uses lines');
    assert.equal(Number(shape.x0), Number(shape.x1), phase + ': grid lines are vertical');
    assert.notEqual(Number(shape.y0), Number(shape.y1), phase + ': grid lines have vertical extent');
    assert.equal(shape.layer, 'above', phase + ': grid is drawn above the heatmap');
    assert.equal(shape.line.dash, 'dash', phase + ': grid is dashed');
    assert.ok(shape.line.width > 0, phase + ': grid stroke is visible');
  });
  const rendered = await page.locator('#indicators-ranking').evaluate(chart => {
    const paths = [...chart.querySelectorAll('.shapelayer path')].map(node => {
      const index = Number(node.getAttribute('data-index') ?? node.closest('[data-index]')?.getAttribute('data-index'));
      const shape = chart._fullLayout.shapes[index];
      if (!String(shape?.name || '').startsWith('wlv-ranking-grid-')) return null;
      const style = getComputedStyle(node), box = node.getBoundingClientRect();
      return {name:shape.name,dash:style.strokeDasharray,stroke:style.stroke,width:parseFloat(style.strokeWidth),
        opacity:parseFloat(style.opacity),display:style.display,height:box.height,above:!!node.closest('.layer-above')};
    }).filter(Boolean);
    return {paths,nativePaths:chart.querySelectorAll('path.xgrid,path.ygrid').length};
  });
  assert.equal(rendered.nativePaths, 0, phase + ': the SVG has no native grid paths');
  assert.deepEqual(rendered.paths.map(item => item.name).sort(), grid.map(shape => shape.name).sort(),
    phase + ': every custom grid line is present in the SVG');
  rendered.paths.forEach(item => {
    assert.ok(item.dash !== 'none' && /[1-9]/.test(item.dash), phase + ': SVG stroke-dasharray is visible');
    assert.ok(item.width > 0 && item.opacity > 0 && item.height > 0 && item.display !== 'none' && item.stroke !== 'none',
      phase + ': SVG grid stroke is drawn');
    assert.ok(item.above, phase + ': SVG grid is in the upper layer');
  });
  return {years:years.length,svgPaths:rendered.paths.length,dash:rendered.paths[0]?.dash,above:true};
}

async function visibleTarget(page, excluded = [], country = null) {
  return page.locator('#indicators-ranking').evaluate((chart, options) => {
    const box = chart.getBoundingClientRect(), size = chart._fullLayout._size;
    let scrollport = chart.parentElement;
    while (scrollport && !['auto','scroll'].includes(getComputedStyle(scrollport).overflowX)) scrollport = scrollport.parentElement;
    const viewport = scrollport?.getBoundingClientRect() || box;
    const left = Math.max(0, viewport.left), right = Math.min(innerWidth, viewport.right);
    const top = Math.max(0, box.top + size.t), bottom = Math.min(innerHeight, box.top + size.t + size.h);
    const rows = chart._wlvRanking.payload.rows;
    return rows.filter(row => !options.excluded.includes(row.country) && (!options.country || row.country === options.country) &&
      rows.filter(other => other.year === row.year && other.rank === row.rank).length === 1).map(row => ({
      ...row, chartBox:{left:box.left,top:box.top,width:box.width,height:box.height},
      axisOffsets:{x:chart._fullLayout.xaxis._offset,y:chart._fullLayout.yaxis._offset},
      x:box.left + size.l + chart._fullLayout.xaxis.l2p(row.year),
      y:box.top + size.t + chart._fullLayout.yaxis.l2p(row.rank)
    })).filter(row => row.x > left + 10 && row.x < right - 10 && row.y > top + 15 && row.y < bottom - 15)
      .sort((a,b) => Math.abs(a.y - (top + bottom) / 2) - Math.abs(b.y - (top + bottom) / 2))[0];
  }, {excluded,country});
}

async function assertResting(page) {
  await page.mouse.move(0,0);
  await page.waitForFunction(() => {
    const chart = document.getElementById('indicators-ranking');
    const background = chart?.data?.find(trace => trace.meta?.role === 'ranking-background');
    return chart && !chart.dataset.rankingHoverCountry && (background?.opacity ?? 1) === 1;
  });
  await page.waitForFunction(() => {
    const chart = document.getElementById('indicators-ranking'), payload = chart._wlvRanking.payload;
    return [].concat(payload.selected || []).every(country => !payload.rows.some(row => row.country === country) ||
      chart.layout.annotations?.some(annotation => annotation.name === 'wlv-ranking-endpoint-' + country));
  });
  const state = await rankingState(page);
  const background = state.traces.find(trace => trace.meta?.role === 'ranking-background');
  assert.deepEqual(state.payload.palette, rankingPalette, 'Ranking uses the WLV palette');
  assert.equal(background.opacity ?? 1, 1, 'Selected countries do not fade the resting background');
  assert.equal((await page.locator('.wlv-ranking-readout').textContent()).trim(), '', 'Readout is empty outside hover');
  for (const country of [].concat(state.payload.selected || [])) {
    if (!state.payload.rows.some(row => row.country === country)) continue;
    assert.ok(state.traces.some(trace => trace.meta?.role === 'ranking-selected-line' && trace.meta.country === country && trace.y.some(Number.isFinite)), 'A selected country keeps its trajectory at rest');
    assert.ok(state.shapeDetails.some(shape => String(shape.name || '').startsWith('wlv-ranking-cell-' + country + '-')), 'A selected country keeps its cell outlines at rest');
  }
  const instructions = await page.locator('.wlv-ranking-hint').allTextContents();
  assert.ok(instructions.every(text => !text.trim()), 'The redundant instruction above the chart is removed');
  const scale = background.colorscale;
  for (const shape of state.shapeDetails.filter(shape => String(shape.name || '').startsWith('wlv-ranking-cell-'))) {
    const transparent = shape.fillcolor === 'transparent' || /^rgba\([^)]*,\s*0(?:[.]0+)?\)$/.test(shape.fillcolor);
    if (transparent) {
      assert.equal(shape.layer, 'above', 'Transparent selected outlines remain visible above the full-strength background');
      assert.ok(shape.line?.width > 0, 'Selected cell outlines remain visible');
      continue;
    }
    const rank = Math.round((shape.y0 + shape.y1) / 2), year = (shape.x0 + shape.x1) / 2;
    const value = background.z[background.y.indexOf(rank)][background.x.indexOf(year)];
    let color = scale[scale.length - 1][1];
    for (let index = 0; index < scale.length - 1; index++) {
      if (value < scale[index + 1][0]) { color = scale[index][1]; break; }
    }
    assert.equal(shape.fillcolor.toLowerCase(), color.toLowerCase(), 'Selected cells keep the same color as their background');
    assert.equal(shape.opacity ?? 1, 1, 'Selected cells retain normal opacity');
  }
  return state;
}

async function verifyHover(page, journal) {
  await page.locator('.wlv-indicators-views').scrollIntoViewIfNeeded();
  const before = await assertResting(page);
  await idle(page);
  const restingGrid = await assertRankingGrid(page, before, 'Resting');
  const selected = await selectedCountries(page);
  await page.screenshot({path:path.join(results,'indicators-ranking-resting-' + page.viewportSize().width + '.png')});
  const target = await visibleTarget(page, selected);
  assert.ok(target, 'An unselected country has a visible heatmap cell');
  const checkpoint = journal.length;
  const started = Date.now();
  await page.evaluate(target => { window._rankingQaTarget = target; }, target);
  await page.mouse.move(target.x, target.y);
  await page.waitForFunction(country => document.getElementById('indicators-ranking')?.dataset.rankingHoverCountry === country, target.country);
  await page.waitForFunction(() => document.getElementById('indicators-ranking').data.find(trace => trace.meta?.role === 'ranking-hover-rank')?.y?.some(Number.isFinite));
  await page.waitForFunction(country => document.getElementById('indicators-ranking').layout.annotations?.some(annotation => annotation.name === 'wlv-ranking-endpoint-' + country), target.country);
  await page.waitForFunction(() => document.getElementById('indicators-ranking').data.find(trace => trace.meta?.role === 'ranking-background')?.opacity === 0.3);
  const hoverLatencyMs = Date.now() - started;
  const hoveredBounds = await page.locator('#indicators-ranking').boundingBox();
  assert.ok(Math.abs(hoveredBounds.y - target.chartBox.top) < 1 && Math.abs(hoveredBounds.height - target.chartBox.height) < 1,
    'Hover readout never moves or resizes the chart under the pointer: ' + JSON.stringify({before:target.chartBox,after:hoveredBounds}));
  const hovered = await rankingState(page);
  const hoverGrid = await assertRankingGrid(page, hovered, 'Hover');
  const gridShapes = state => state.shapeDetails.filter(shape => String(shape.name || '').startsWith('wlv-ranking-grid-'));
  assert.deepEqual(gridShapes(hovered), gridShapes(before), 'Hover preserves the vertical grid');
  assert.equal(hovered.hoverCountry, target.country, 'Pointer over a cell reveals its country');
  assert.equal(hovered.traces.find(trace => trace.meta?.role === 'ranking-background').opacity, 0.3, 'Only hover fades the background');
  assert.ok((await page.locator('.wlv-ranking-readout').textContent()).includes(target.label), 'Hover shows a dynamic country readout');
  const selectedTraces = state => state.traces.filter(trace => trace.meta?.role?.startsWith('ranking-selected'));
  assert.deepEqual(selectedTraces(hovered), selectedTraces(before), 'Pinned trajectories remain while hovering another country');
  const hoverTraces = hovered.traces.filter(trace => trace.meta?.role?.startsWith('ranking-hover'));
  assert.equal(hoverTraces.length, 3, 'Hover has a complete trajectory, ranks and values');
  const line = hoverTraces.find(trace => trace.meta.role === 'ranking-hover-line');
  const rankLabels = hoverTraces.find(trace => trace.meta.role === 'ranking-hover-rank');
  const valueLabels = hoverTraces.find(trace => trace.meta.role === 'ranking-hover-value');
  const rows = hovered.payload.rows.filter(row => row.country === target.country).sort((a,b) => a.year - b.year);
  assert.ok(line.x.filter(Number.isFinite).length >= rows.length, 'Hover includes the full country trajectory');
  rows.forEach(row => {
    const index = line.x.indexOf(row.year);
    assert.ok(index >= 0 && Math.abs(line.y[index] - (row.rank - 0.45)) < 1e-8, 'Trajectory outlines the ranked cell for ' + row.year);
    assert.equal(rankLabels.y[index], row.rank - 0.5, 'Rank label sits above the cell for ' + row.year);
    assert.equal(valueLabels.y[index], row.rank + 0.5, 'Value label sits below the cell for ' + row.year);
    assert.equal(String(rankLabels.text[index]), String(row.rank), 'Rank label is present for ' + row.year);
    assert.equal(valueLabels.text[index], row.valueLabel, 'Formatted value is present for ' + row.year);
  });
  for (const role of ['ranking-hover-rank','ranking-hover-value']) {
    assert.ok(hoverTraces.find(trace => trace.meta.role === role)?.x?.filter(Number.isFinite).length >= rows.length,
      role + ' labels each observed year');
  }
  assert.deepEqual(await selectedCountries(page), selected, 'Hover does not pin a country');
  await page.screenshot({path:path.join(results,'indicators-ranking-hover-' + page.viewportSize().width + '.png')});
  await page.mouse.move(0,0);
  await page.waitForFunction(() => !document.getElementById('indicators-ranking')?.dataset.rankingHoverCountry);
  await page.waitForFunction(() => !document.getElementById('indicators-ranking').data.find(trace => trace.meta?.role === 'ranking-hover-rank')?.y?.some(Number.isFinite));
  const after = await assertResting(page);
  await assertRankingGrid(page, after, 'Pointer exit');
  assert.deepEqual(gridShapes(after), gridShapes(before), 'Pointer exit preserves the vertical grid');
  const restoredBounds = await page.locator('#indicators-ranking').boundingBox();
  assert.ok(Math.abs(restoredBounds.y - target.chartBox.top) < 1 && Math.abs(restoredBounds.height - target.chartBox.height) < 1,
    'Clearing hover preserves chart geometry');
  assert.deepEqual(selectedTraces(after), selectedTraces(before), 'Pointer exit restores the selected trajectories');
  assert.ok(after.traces.filter(trace => trace.meta?.role?.startsWith('ranking-hover')).every(trace =>
    !trace.y?.some(Number.isFinite) || trace.visible === false), 'Pointer exit clears the temporary trajectory');
  const inputs = journal.slice(checkpoint).filter(item => /plotly_(hover|unhover|relayout|restyle|afterplot)|ranking_(hover|country)/.test(item.payload));
  await page.locator('#indicators-ranking').focus();
  await page.keyboard.press('ArrowDown');
  await page.waitForFunction(() => !!document.getElementById('indicators-ranking')?.dataset.rankingHoverCountry);
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => !document.getElementById('indicators-ranking')?.dataset.rankingHoverCountry);
  assert.deepEqual(await selectedCountries(page), selected, 'Keyboard exploration does not pin a country');
  return {country:target.country, year:target.year, observations:rows.length, hoverLatencyMs, shinyHoverInputs:inputs,
    localOnly:inputs.length === 0, pinnedPreserved:true, keyboard:true,grid:{resting:restingGrid,hover:hoverGrid}};
}

async function verifySelection(page) {
  const before = await selectedCountries(page);
  const initialPopulation = population(await rankingState(page));
  const added = [];
  for (const gesture of ['click','Enter','Space']) {
    await page.locator('#indicators-ranking').focus();
    const selected = await selectedCountries(page);
    const target = await visibleTarget(page, selected);
    assert.ok(target, 'An unselected cell is available for ' + gesture);
    await page.mouse.move(target.x,target.y);
    await page.waitForFunction(country => document.getElementById('indicators-ranking').dataset.rankingHoverCountry === country, target.country);
    if (gesture === 'click') await page.mouse.click(target.x,target.y,{button:'left'});
    else await page.keyboard.press(gesture);
    const expected = [...selected,target.country].sort();
    await page.waitForFunction(countries => JSON.stringify([].concat(document.getElementById('indicators-countries').selectize.getValue()).sort()) === JSON.stringify(countries), expected);
    await page.waitForFunction(country => [].concat(document.getElementById('indicators-ranking')._wlvRanking?.payload.selected || []).includes(country), target.country);
    await ready(page);
    await assertResting(page);
    assert.deepEqual(await selectedCountries(page), expected, gesture + ' adds the country without removing earlier selections');
    assert.deepEqual(population(await rankingState(page)), initialPopulation, gesture + ' preserves population ranks');
    added.push({gesture,country:target.country});
    if (gesture === 'click') {
      const duplicate = await visibleTarget(page, [], target.country);
      assert.ok(duplicate, 'The clicked country remains visible');
      await page.mouse.click(duplicate.x,duplicate.y,{button:'left'});
      await idle(page);
      await assertResting(page);
      assert.deepEqual(await selectedCountries(page), expected, 'Clicking a selected country does not duplicate or remove it');
    }
  }
  return {before,added,selected:await selectedCountries(page)};
}

function population(state) {
  return state.payload.rows.map(({country,year,rank,count,value}) => ({country,year,rank,count,value}));
}

(async () => {
  const browser = await chromium.launch({headless:true});
  let active;
  try {
    for (const width of widths) {
      const context = await browser.newContext({locale: 'pt-BR', viewport:{width,height:1000}, hasTouch:width < 768});
      const page = await context.newPage();
      active = page;
      const journal = [];
      page.on('pageerror', error => evidence.errors.push({width,message:error.message}));
      page.on('websocket', socket => socket.on('framesent', event => journal.push({at:Date.now(),payload:String(event.payload)})));
      await page.goto(url);
      await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.main_nav, null, {timeout:60000});
      if (width < 768 && !await page.locator('.navbar-collapse').evaluate(node => node.classList.contains('in'))) {
        await page.locator('.navbar-toggle').click();
      }
      await page.locator('#main_nav a[data-value="indicators"]').click();
      await page.locator('[id="indicators-catalogue_surplus_value.empe_p.r.pc"]').click();
      await page.locator('#indicators-all tbody tr').first().waitFor();
      await idle(page);
      assert.equal(await page.locator('#indicators-view a[data-value="ranking"]').count(), 1, 'Ranking is a single third view');
      assert.equal(await page.locator('#indicators-view a[data-value]').count(), 3, 'All three indicator views exist');
      await page.locator('#indicators-view a[data-value="ranking"]').click();
      await ready(page);
      const initial = await rankingState(page);
      assert.ok(initial.traces.length > 2, 'Ranking includes the complete population');
      assert.ok(initial.yaxis[0] > initial.yaxis[1], 'Rank 1 is at the top');
      assert.ok(initial.traces.some(trace => ['hv','vh','hvh'].includes(trace.line?.shape)), 'Trajectories use steps');
      const startCountries = await selectedCountries(page);
      assert.ok(startCountries.includes('BRA'), 'Default country is Brazil');
      const hover = await verifyHover(page, journal);
      assert.deepEqual(await selectedCountries(page), startCountries, 'Hover never changes selected countries');
      const interaction = await verifySelection(page);
      const persistentCountries = interaction.selected;

      const otherCountry = initial.payload.rows.find(row => !persistentCountries.includes(row.country)).country;
      await select(page, 'indicators-countries', [...persistentCountries, otherCountry]);
      await page.waitForFunction(country => document.getElementById('indicators-ranking')._wlvRanking?.payload.selected?.includes(country), otherCountry);
      await ready(page);
      assert.deepEqual(population(await rankingState(page)), population(initial), 'Adding a comparison country never recomputes population ranks');
      await select(page, 'indicators-countries', []);
      await page.waitForFunction(() => [].concat(document.getElementById('indicators-ranking')._wlvRanking?.payload.selected || []).length === 0);
      await ready(page);
      assert.deepEqual(population(await rankingState(page)), population(initial), 'Empty selection still shows the whole ranking');
      await select(page, 'indicators-countries', persistentCountries);
      await page.waitForFunction(countries => JSON.stringify([].concat(document.getElementById('indicators-ranking')._wlvRanking?.payload.selected || []).sort()) === JSON.stringify(countries), persistentCountries);
      await ready(page);
      await assertResting(page);
      const layout = await assertLayout(page);
      await page.screenshot({path:path.join(results,'indicators-ranking-' + width + '.png')});

      const method = await page.locator('#indicators-ranking_method').inputValue();
      const methods = await page.locator('#indicators-ranking_method').evaluate(node => node.selectize ? Object.keys(node.selectize.options) : [...node.options].map(option => option.value));
      const alternative = methods.find(value => value !== method);
      assert.ok(alternative, 'Fixture has at least two ranking databases');
      await select(page, 'indicators-ranking_method', alternative);
      await page.waitForFunction(value => Shiny.shinyapp.$inputValues['indicators-ranking_method'] === value, alternative);
      await page.waitForFunction(method => document.getElementById('indicators-ranking')._wlvRanking?.payload.method === method, alternative);
      await page.waitForFunction(rows => JSON.stringify(document.getElementById('indicators-ranking')._wlvRanking?.payload?.rows) !== JSON.stringify(rows), initial.payload.rows);
      await ready(page);
      const changed = await rankingState(page);
      assert.notDeepEqual(changed, initial, 'Changing the ranking database updates the chart');
      assert.deepEqual(await selectedCountries(page), persistentCountries, 'Changing the database preserves countries selected through the chart');
      await assertRankingGrid(page, await assertResting(page), 'Database change');

      await page.locator('#language_toggle').click();
      await page.waitForFunction(() => document.documentElement.lang === 'en' &&
        document.getElementById('indicators-countries').selectize.options.BRA?.[document.getElementById('indicators-countries').selectize.settings.labelField] === 'Brazil');
      await ready(page);
      assert.equal(await page.locator('#indicators-ranking_method').inputValue(), alternative, 'Language preserves the ranking database');
      assert.deepEqual(await selectedCountries(page), persistentCountries, 'Language preserves countries selected through the chart');
      assert.equal(await page.locator('#indicators-view li.active a').getAttribute('data-value'), 'ranking', 'Language preserves the active view');
      assert.match(await page.locator('.wlv-ranking-toolbar label').textContent(), /database/i, 'Ranking database label is translated');
      await assertResting(page);
      await assertLayout(page);
      await page.screenshot({path:path.join(results,'indicators-ranking-en-' + width + '.png')});
      if (width < 768) {
        const scroller = page.locator('.wlv-indicators-ranking-scroll');
        const end = await scroller.evaluate(node => {
          node.scrollLeft = node.scrollWidth;
          return {left:node.scrollLeft, max:node.scrollWidth - node.clientWidth};
        });
        assert.ok(end.max > 0 && Math.abs(end.left - end.max) < 2, 'Mobile can scroll to the latest years and endpoint labels');
        await page.screenshot({path:path.join(results,'indicators-ranking-last-years-' + width + '.png')});
        await scroller.evaluate(node => { node.scrollLeft = 0; });
      }

      for (const value of ['series','map','ranking']) {
        const tab = page.locator('#indicators-view a[data-value="' + value + '"]');
        await tab.focus();
        await page.keyboard.press('Enter');
        await page.waitForFunction(value => document.querySelector('#indicators-view li.active a')?.dataset.value === value, value);
        await idle(page);
      }
      await ready(page);
      await page.locator('#language_menu_toggle').click();
      await page.locator('#language_menu [lang="pt-BR"]').click();
      await page.waitForFunction(() => document.documentElement.lang.toLowerCase().startsWith('pt'));
      await ready(page);
      assert.deepEqual(await selectedCountries(page), persistentCountries, 'Round trip to Portuguese preserves countries selected through the chart');
      assert.equal(await page.locator('#indicators-ranking_method').inputValue(), alternative, 'Round trip preserves database');
      await assertResting(page);
      evidence.viewports.push({width, hover, interaction, layout, method, alternative, translated:true, keyboardTabs:true});
      console.log('CHECKED Indicator ranking ' + width);
      await context.close();
    }
    assert.deepEqual(evidence.errors, []);
    assert.deepEqual(evidence.viewports.flatMap(viewport => viewport.hover.shinyHoverInputs), [], 'Pointer interactions do not send Shiny hover inputs');
    evidence.status = 'passed';
  } catch (error) {
    evidence.status = 'failed';
    evidence.failure = error.stack;
    if (active && !active.isClosed()) {
      evidence.failureState = await active.evaluate(() => ({inputs:Object.fromEntries(Object.entries(window.Shiny?.shinyapp?.$inputValues || {})
        .filter(([key]) => /^(indicators-(countries|methods|indicator|ranking_method|view)|l)$/.test(key))),
        ranking:document.getElementById('indicators-ranking')?.data?.map(trace => ({name:trace.name,meta:trace.meta})),
        activeView:document.querySelector('#indicators-view li.active a')?.dataset.value, lang:document.documentElement.lang,
        pointerTarget:window._rankingQaTarget, hoverCountry:document.getElementById('indicators-ranking')?.dataset.rankingHoverCountry,
        chartBox:document.getElementById('indicators-ranking')?.getBoundingClientRect().toJSON(),
        readout:document.querySelector('.wlv-ranking-readout')?.textContent})).catch(() => ({}));
      await active.screenshot({path:path.join(results,'indicators-ranking-failure.png'),fullPage:true}).catch(() => {});
    }
    process.exitCode = 1;
  } finally {
    fs.writeFileSync(path.join(results,'indicators-ranking-browser.json'),JSON.stringify(evidence,null,2) + '\n','utf8');
    await browser.close();
  }
})();
