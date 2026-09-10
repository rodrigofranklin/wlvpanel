'use strict';
// Exercise brand controls in a real Shiny session; keep evidence in the campaign.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const campaign = process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign && fs.existsSync(path.join(campaign, '.campaign.json')));
for (const key of ['TEMP','TMP','TMPDIR']) assert.equal(path.resolve(process.env[key]), path.resolve(campaign, 'scratch'));
const url = 'http://127.0.0.1:' + (process.env.WLVPANEL_PORT || '38132');
const evidence = [];
const idle = page => page.waitForFunction(() => window.Shiny?.shinyapp?.$inputValues.main_nav && !document.documentElement.classList.contains('shiny-busy'), null, {timeout:60000});
async function nav(page, value) {
  if (await page.locator('.navbar-toggle').isVisible() && !await page.locator('.navbar-collapse').evaluate(n=>n.classList.contains('in'))) await page.locator('.navbar-toggle').click();
  await page.locator('#main_nav a[data-value="'+value+'"]').click();
  await page.waitForFunction(v=>Shiny.shinyapp.$inputValues.main_nav===v, value);
  if (await page.locator('.navbar-toggle').isVisible()) await page.locator('.navbar-collapse').waitFor({state:'hidden'});
  await idle(page);
}
async function dropdown(page, id, value) {
  await page.waitForFunction(id=>!!document.getElementById(id)?.selectize, id);
  await page.locator('#'+id).evaluate(n=>n.selectize.open());
  const options = page.locator('#'+id+' ~ .selectize-control .selectize-dropdown');
  await options.waitFor({state:'visible'});
  const option = options.locator('[data-value="'+value+'"]');
  await option.hover();
  const colors = await option.evaluate(n=>({background:getComputedStyle(n).backgroundColor,color:getComputedStyle(n).color,userSelect:getComputedStyle(n).userSelect}));
  assert.equal(colors.background,'rgb(246, 174, 45)', id+' active option');
  assert.equal(colors.color,'rgb(141, 32, 40)', id+' active text');
  assert.equal(colors.userSelect,'none');
  await option.click();
  await page.waitForFunction(({id,value})=>Shiny.shinyapp.$inputValues[id]===value,{id,value});
  await idle(page);
  return colors;
}
(async()=>{
  const browser = await chromium.launch({headless:true});
  try {
    for (const width of [1440,390]) {
      const context = await browser.newContext({locale: 'pt-BR', viewport:{width,height:960}});
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(url); await idle(page);
      const selection = await page.evaluate(()=>({
        nav:getComputedStyle(document.querySelector('#main_nav a')).userSelect,
        button:getComputedStyle(document.querySelector('#language_toggle')).userSelect,
        reading:getComputedStyle(document.querySelector('.wlv-about p')).userSelect
      }));
      assert.equal(selection.nav,'none'); assert.equal(selection.button,'none'); assert.notEqual(selection.reading,'none');
      await nav(page,'publications');
      await page.locator('.wlv-publication').first().waitFor();
      const allPublications = await page.locator('.wlv-publication').count();
      const authorColors = await dropdown(page,'publications-author','borges');
      await page.waitForFunction(count=>document.querySelectorAll('.wlv-publication').length<count,allPublications);
      assert.ok(await page.locator('.wlv-publication').count() < allPublications);
      await dropdown(page,'publications-author','');
      await page.waitForFunction(count=>document.querySelectorAll('.wlv-publication').length===count,allPublications);
      assert.equal(await page.locator('.wlv-publication').count(),allPublications);
      const inputSelection = await page.locator('#publications-search').evaluate(n=>getComputedStyle(n).userSelect);
      assert.equal(inputSelection,'text');
      await page.locator('#publications-search').fill('capital');
      await page.locator('#publications-search').press('Control+A');
      assert.equal(await page.locator('#publications-search').evaluate(n=>n.selectionEnd-n.selectionStart),7);
      await page.locator('#publications-search').fill('');
      await nav(page,'download');
      const methodColors = await dropdown(page,'dl_method','WIOD13');
      await nav(page,'trade');
      const tradeFilters = page.locator('.wlv-trade-filter-group').first();
      await tradeFilters.waitFor();
      if (!await tradeFilters.evaluate(n=>n.open)) await tradeFilters.locator('summary').click();
      await page.locator('#trade-country ~ .selectize-control').waitFor();
      await page.waitForFunction(()=>!!document.querySelector('#trade-country')?.selectize?.options?.BRA);
      const countryColors = await dropdown(page,'trade-country','BRA');
      const checks = await page.locator('.wlv-trade input[type="radio"],.wlv-trade input[type="checkbox"]').evaluateAll(nodes=>nodes.map(n=>({type:n.type,color:getComputedStyle(n).accentColor})));
      assert.ok(checks.some(n=>n.type==='radio')); assert.ok(checks.some(n=>n.type==='checkbox'));
      for (const item of checks) assert.equal(item.color,'rgb(141, 32, 40)');
      await page.screenshot({path:path.join(campaign,'results','controls-'+width+'.png')});
      const state = await page.evaluate(()=>({overflow:document.documentElement.scrollWidth-innerWidth,errors:[...document.querySelectorAll('.shiny-output-error')].filter(n=>n.offsetWidth&&n.offsetHeight).map(n=>n.textContent)}));
      assert.ok(state.overflow<=1); assert.deepEqual(state.errors,[]); assert.deepEqual(errors,[]);
      evidence.push({width,selection,inputSelection,authorColors,methodColors,countryColors,checks,allPublications,status:'passed'});
      await context.close();
    }
    fs.writeFileSync(path.join(campaign,'results','interface-polish.json'),JSON.stringify(evidence,null,2));
    console.log(JSON.stringify(evidence));
  } finally { await browser.close(); }
})().catch(error=>{console.error(error);process.exitCode=1;});
