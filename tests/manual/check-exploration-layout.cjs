// Shared exploration layout and country disclosure behavior against a local Shiny app.
// Run with WLV_CAMPAIGN_ROOT, TEMP/TMP/TMPDIR and an optional WLVPANEL_PORT.
// WLVPANEL_VIEWPORTS can resume selected widths, e.g. 1440,390,320, in a separate report.
// WLVPANEL_DISCLOSURES_ONLY=1 limits the run to country groups and their controls.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')), 'An active campaign is required');
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38129');
const catalogue = JSON.parse(fs.readFileSync(path.join(__dirname, '../../config/publications.json'), 'utf8'));
const evidence = { viewports: [], disclosures: [], errors: [] };
const tabs = ['country', 'indicators', 'trade', 'download', 'publications'];
const disclosuresOnly = process.env.WLVPANEL_DISCLOSURES_ONLY === '1';
const widths = process.env.WLVPANEL_VIEWPORTS ? process.env.WLVPANEL_VIEWPORTS.split(',').map(Number) : [1920, 1440, 768, 390, 320];
assert.ok(widths.length > 0 && widths.every(width => Number.isInteger(width) && width >= 320), 'Valid viewport widths are required');
const evidenceName = (disclosuresOnly ? 'country-disclosures-check' : 'exploration-layout-check') +
  (process.env.WLVPANEL_VIEWPORTS ? '-' + widths.join('-') : '') + '.json';

async function ready(page) {
  await page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.main_nav &&
    !document.documentElement.classList.contains('shiny-busy'), null, { timeout: 45000 });
}

async function navigate(page, value) {
  const menu = page.locator('.navbar-collapse');
  if (await page.locator('.navbar-toggle').isVisible() && !await menu.isVisible()) {
    await page.locator('.navbar-toggle').click();
  }
  await page.locator('#main_nav a[data-value="' + value + '"]').click();
  await page.waitForFunction(value => Shiny.shinyapp.$inputValues.main_nav === value, value);
  if (await page.locator('.navbar-toggle').isVisible()) await menu.waitFor({ state: 'hidden' });
  await ready(page);
  await page.locator('.tab-pane.active .wlv-explore-heading h1').waitFor();
  await page.evaluate(() => {
    document.querySelector('.wlv-page-scroll')?.scrollTo(0, 0);
    document.scrollingElement.scrollTo(0, 0);
  });
  await page.waitForFunction(() => !document.querySelector('.wlv-page-scroll')?.scrollTop &&
    document.scrollingElement.scrollTop === 0);
}

async function geometry(page) {
  return page.evaluate(() => {
    const active = document.querySelector(document.querySelector('#main_nav li.active > a').getAttribute('href'));
    const root = active.querySelector('.wlv-explore-page');
    const content = root.querySelector('.wlv-explore-content');
    const heading = content.querySelector('.wlv-explore-heading');
    const title = heading.querySelector('h1');
    const rect = node => {
      const { x, y, width, height, right, bottom } = node.getBoundingClientRect();
      return { x, y, width, height, right, bottom };
    };
    const style = getComputedStyle(content);
    const titleStyle = getComputedStyle(title);
    const navbar = document.querySelector('.navbar');
    const scroll = document.querySelector('.wlv-page-scroll');
    return {
      tab: Shiny.shinyapp.$inputValues.main_nav, width: innerWidth,
      page: rect(root), content: rect(content), heading: rect(heading), title: rect(title),
      titleText: title.textContent.trim(), headingChildren: [...heading.children].map(node => node.tagName),
      menuGap: rect(title).y - rect(navbar).bottom,
      contentPadding: [style.paddingTop, style.paddingRight, style.paddingBottom, style.paddingLeft],
      headingMargin: getComputedStyle(heading).marginBottom,
      titleStyle: { fontSize: titleStyle.fontSize, lineHeight: titleStyle.lineHeight, color: titleStyle.color },
      background: getComputedStyle(document.body).backgroundImage,
      band: getComputedStyle(root, '::before').backgroundImage,
      documentWidth: document.documentElement.scrollWidth,
      contentScrollWidth: content.scrollWidth,
      scroll: scroll ? { width: scroll.clientWidth, scrollWidth: scroll.scrollWidth } : null,
      errors: [...active.querySelectorAll('.shiny-output-error')]
        .filter(node => node.getClientRects().length).map(node => node.textContent)
    };
  });
}

function assertLayout(record, baseline) {
  const prefix = record.tab + ' at ' + record.width + 'px: ';
  assert.deepEqual(record.errors, [], prefix + 'no visible output errors');
  assert.ok(record.documentWidth <= record.width + 2, prefix + 'document has no horizontal overflow');
  assert.ok(record.contentScrollWidth <= record.content.width + 2, prefix + 'content fits its container');
  if (record.scroll) assert.ok(record.scroll.scrollWidth <= record.scroll.width + 2,
    prefix + 'scroll container has no horizontal overflow');
  assert.deepEqual(record.headingChildren, ['H1'], prefix + 'page heading contains only its title');
  assert.deepEqual(record.contentPadding, ['0px', '0px', '0px', '0px'], prefix + 'no extra inner inset');
  assert.equal(record.headingMargin, '24px', prefix + 'consistent heading spacing');
  assert.ok(record.content.width <= 1680 + 1, prefix + 'readable maximum content width');
  assert.ok(record.content.x >= (record.width < 768 ? 16 : 28) - 1, prefix + 'page side gutter');
  if (!baseline) return;
  for (const key of ['x', 'width']) assert.ok(Math.abs(record.content[key] - baseline.content[key]) <= 1,
    prefix + 'content ' + key + ' matches Country: ' + JSON.stringify({ record, baseline }));
  for (const key of ['x', 'y', 'height']) assert.ok(Math.abs(record.title[key] - baseline.title[key]) <= 1,
    prefix + 'title ' + key + ' matches Country');
  assert.ok(Math.abs(record.menuGap - baseline.menuGap) <= 1, prefix + 'same title distance from menu');
  assert.deepEqual(record.titleStyle, baseline.titleStyle, prefix + 'same title typography');
  assert.equal(record.background, baseline.background, prefix + 'same page background');
  assert.equal(record.band, baseline.band, prefix + 'same title background band');
}

async function expectPublications(page, entries) {
  await page.waitForFunction(ids => JSON.stringify([...document.querySelectorAll('.wlv-publication')]
    .map(node => node.dataset.publicationId).sort()) === JSON.stringify(ids), entries.map(entry => entry.id).sort());
}

async function publications(page) {
  await expectPublications(page, catalogue.entries);
  await page.locator('#publications-search').fill('zz-no-publication-zz');
  await expectPublications(page, []);
  await page.locator('#publications-search').fill('fixed capital');
  await page.locator('#publications-author').evaluate(node => node.selectize.setValue('sanchez'));
  await page.locator('#publications-year').evaluate(node => node.selectize.setValue('2022'));
  await expectPublications(page, [{ id: 'borges-2022-fixed-capital' }]);
  await page.locator('#language_toggle').click();
  await page.waitForFunction(() => document.documentElement.lang === 'en' &&
    document.querySelector('.wlv-publications h1')?.textContent === 'Publications');
  await ready(page);
  assert.equal(await page.locator('#publications-search').inputValue(), 'fixed capital');
  assert.equal(await page.locator('#publications-author').inputValue(), 'sanchez');
  assert.equal(await page.locator('#publications-year').inputValue(), '2022');
  await expectPublications(page, [{ id: 'borges-2022-fixed-capital' }]);
  assertLayout(await geometry(page));
  await page.locator('#publications-search').fill('');
  await page.locator('#publications-author').evaluate(node => node.selectize.setValue(''));
  await page.locator('#publications-year').evaluate(node => node.selectize.setValue(''));
  await expectPublications(page, catalogue.entries);
  assert.equal(await page.locator('.wlv-publications-sources a[href^="https://"]').count(), 2,
    'Project and team sources remain available');
}

async function disclosures(page, width) {
  await navigate(page, 'country');
  await page.locator('[data-wlv-country="BRA"]').click();
  await ready(page);
  const buttons = page.locator('.wlv-country-group-toggle');
  await buttons.first().waitFor();
  const count = await buttons.count();
  assert.ok(count > 1, 'Chart groups expose individual disclosure controls');
  const initialStates = await buttons.evaluateAll(nodes => nodes.map(node => {
    const content = document.getElementById(node.getAttribute('aria-controls'));
    return { expanded: node.getAttribute('aria-expanded'), collapsed: node.classList.contains('collapsed'),
      open: content.classList.contains('in'), hidden: content.getAttribute('aria-hidden'), inert: content.inert };
  }));
  for (const state of initialStates) assert.deepEqual(state,
    { expanded: 'false', collapsed: true, open: false, hidden: 'true', inert: true },
    'Every country chart group starts collapsed and inaccessible until opened');
  const button = buttons.first();
  const details = await button.evaluate(node => ({ tag: node.tagName, type: node.type,
    controls: node.getAttribute('aria-controls'), expanded: node.getAttribute('aria-expanded'),
    target: node.getAttribute('data-target'), toggle: node.dataset.toggle, text: node.textContent.trim() }));
  assert.equal(details.tag, 'BUTTON');
  assert.equal(details.type, 'button');
  assert.equal(details.expanded, 'false', 'Chart groups start collapsed');
  assert.equal(details.toggle, 'collapse', 'Disclosure uses Bootstrap collapse');
  assert.equal(details.target, '#' + details.controls);
  assert.ok(details.text, 'Disclosure has a visible label');
  const group = page.locator('#' + details.controls);
  const chevron = button.locator('.wlv-country-group-chevron');
  await group.waitFor({ state: 'hidden' });
  const collapsedTransform = await chevron.evaluate(node => getComputedStyle(node).transform);
  assert.ok(await chevron.evaluate(node => getComputedStyle(node).transitionDuration.split(',')
    .some(duration => parseFloat(duration) > 0)), 'Chevron animates with normal motion');
  await button.click();
  await page.waitForFunction(id => document.getElementById(id).classList.contains('in') &&
    !document.getElementById(id).classList.contains('collapsing'), details.controls);
  await page.waitForFunction(id => document.querySelector('#' + id + ' .js-plotly-plot')?._fullLayout, details.controls);
  await ready(page);
  assert.equal(await button.getAttribute('aria-expanded'), 'true', 'Click opens a collapsed group');
  assert.equal(await group.getAttribute('aria-hidden'), 'false');
  assert.equal(await group.evaluate(node => node.inert), false);
  const expandedTransform = await chevron.evaluate(node => getComputedStyle(node).transform);
  assert.notEqual(expandedTransform, collapsedTransform, 'Chevron communicates open and closed states');
  const originalPlots = await group.locator('.js-plotly-plot').count();
  await button.click();
  await group.waitFor({ state: 'hidden' });
  await page.waitForFunction(id => !document.getElementById(id).classList.contains('collapsing'), details.controls);
  assert.equal(await button.getAttribute('aria-expanded'), 'false');
  assert.equal(await group.getAttribute('aria-hidden'), 'true', 'Collapsed content is hidden from assistive technology');
  assert.equal(await group.evaluate(node => node.inert), true, 'Collapsed content cannot receive keyboard focus');
  assert.equal(await buttons.nth(1).getAttribute('aria-expanded'), 'false', 'Other groups stay collapsed');
  assert.equal(await group.locator('.js-plotly-plot').count(), originalPlots, 'Collapsing preserves rendered plots');
  assert.equal(await chevron.evaluate(node => getComputedStyle(node).transform), collapsedTransform,
    'Closing returns the chevron to its initial direction');
  await button.locator('xpath=ancestor::section[1]').screenshot({
    path: path.join(campaign, 'results', 'layout-country-group-collapsed-' + width + '.png')
  });

  // Resizing while hidden exposes stale Plotly dimensions that ordinary clicks miss.
  const originalViewport = page.viewportSize();
  if (width === 1440) await page.setViewportSize({ width: 768, height: originalViewport.height });
  await button.focus();
  await page.keyboard.press('Enter');
  await page.waitForFunction(id => document.getElementById(id).classList.contains('in') &&
    !document.getElementById(id).classList.contains('collapsing'), details.controls);
  await group.waitFor({ state: 'visible' });
  await page.waitForFunction(id => [...document.querySelectorAll('#' + id + ' .js-plotly-plot')]
    .every(node => node._fullLayout && Math.abs(node._fullLayout.width - node.clientWidth) <= 3), details.controls);
  assert.equal(await button.getAttribute('aria-expanded'), 'true');
  assert.equal(await group.evaluate(node => node.inert), false, 'Reopened content is interactive');
  assert.equal(await button.evaluate(node => document.activeElement === node), true, 'Keyboard focus stays on the disclosure');
  await button.locator('xpath=ancestor::section[1]').screenshot({
    path: path.join(campaign, 'results', 'layout-country-group-expanded-' + width + '.png')
  });

  await group.locator('.wlv-country-chart-select').first().focus();
  await group.evaluate(node => window.jQuery(node).collapse('hide'));
  await page.waitForFunction(id => !document.getElementById(id).classList.contains('collapsing') &&
    !document.getElementById(id).classList.contains('in'), details.controls);
  assert.equal(await button.evaluate(node => document.activeElement === node), true,
    'Closing a group containing focus returns focus to its disclosure');
  await page.keyboard.press('Enter');
  await page.waitForFunction(id => document.getElementById(id).classList.contains('in'), details.controls);

  await page.emulateMedia({ reducedMotion: 'reduce' });
  // The shared theme uses an imperceptible 0.01ms duration with !important.
  assert.ok(await chevron.evaluate(node => getComputedStyle(node).transitionDuration.split(',')
    .every(duration => parseFloat(duration) <= 0.000011)), 'Reduced motion disables perceptible chevron animation');
  await page.keyboard.press('Space');
  await group.waitFor({ state: 'hidden' });
  await page.waitForFunction(id => !document.getElementById(id).classList.contains('collapsing'), details.controls);
  assert.equal(await button.getAttribute('aria-expanded'), 'false', 'Space closes the native button');
  await page.keyboard.press('Space');
  await group.waitFor({ state: 'visible' });
  await page.waitForFunction(id => document.getElementById(id).classList.contains('in'), details.controls);
  assert.equal(await button.getAttribute('aria-expanded'), 'true');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.setViewportSize(originalViewport);

  const downloads = await page.locator('.wlv-country-downloads').evaluate(node => {
    const rect = node.getBoundingClientRect();
    const heading = node.querySelector('.panel-heading').getBoundingClientRect();
    const first = node.querySelector('.wlv-country-download-block').getBoundingClientRect();
    return { width: rect.width, scrollWidth: node.scrollWidth, firstGap: first.top - heading.bottom,
      links: [...node.querySelectorAll('a')].map(link => link.id) };
  });
  assert.ok(downloads.scrollWidth <= downloads.width + 2, 'Country downloads fit their panel');
  assert.ok(downloads.firstGap >= -1 && downloads.firstGap <= 24, 'Download sections sit directly below the panel heading');
  for (const id of ['co_country_file_WIOD13', 'co_sector_file_WIOD13']) assert.ok(downloads.links.includes(id), id + ' remains available');
  await page.locator('.wlv-country-downloads').screenshot({
    path: path.join(campaign, 'results', 'layout-country-downloads-' + width + '.png')
  });
  await page.evaluate(() => document.querySelector('.wlv-page-scroll')?.scrollTo(0, 0));
  await page.screenshot({ path: path.join(campaign, 'results', 'layout-country-detail-' + width + '.png') });
  evidence.disclosures.push({ width, groups: count, initialStates, plots: originalPlots,
    resizedWhileHidden: width === 1440, downloads });
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  let page;
  try {
    for (const width of widths) {
      const context = await browser.newContext({ locale: 'pt-BR', viewport: { width, height: 1000 }, hasTouch: width < 768 });
      page = await context.newPage();
      page.on('pageerror', error => evidence.errors.push(String(error)));
      await page.goto(url, { waitUntil: 'domcontentloaded' });
      await ready(page);
      const records = [];
      for (const tab of disclosuresOnly ? [] : tabs) {
        await navigate(page, tab);
        const record = await geometry(page);
        await page.screenshot({ path: path.join(campaign, 'results', 'layout-' + tab + '-' + width + '.png') });
        assertLayout(record, records[0]);
        records.push(record);
      }
      if (!disclosuresOnly) await publications(page);
      if (disclosuresOnly || [1440, 390, 320].includes(width)) await disclosures(page, width);
      evidence.viewports.push({ width, status: 'passed', tabs: records });
      console.log('EXPLORATION_LAYOUT_VIEWPORT_OK ' + width);
      await context.close();
      page = null;
    }
    assert.deepEqual(evidence.errors, []);
    evidence.status = 'passed';
    console.log('EXPLORATION_LAYOUT_BROWSER_OK');
  } catch (error) {
    evidence.status = 'failed';
    evidence.failure = String(error.stack || error);
    if (page) await page.screenshot({ path: path.join(campaign, 'results', 'exploration-layout-failure.png') });
    console.error(error);
    process.exitCode = 1;
  } finally {
    await browser.close();
    fs.writeFileSync(path.join(campaign, 'results', evidenceName), JSON.stringify(evidence, null, 2), 'utf8');
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
