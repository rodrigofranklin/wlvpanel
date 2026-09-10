'use strict';
// Capture visible content and real exports before/after internal optimizations.
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
for(const key of ['TEMP','TMP','TMPDIR'])assert.equal(path.resolve(process.env[key]),path.resolve(campaign,'scratch'));
const url='http://127.0.0.1:'+(process.env.WLVPANEL_PORT||38134);
const evidence={views:[],downloads:[],errors:[]};
async function settle(page){await page.evaluate(()=>window.efficiencyQuiet=0);await page.waitForFunction(()=>{if(document.documentElement.classList.contains('shiny-busy')){window.efficiencyQuiet=0;return false;}if(!window.efficiencyQuiet)window.efficiencyQuiet=performance.now();return performance.now()-window.efficiencyQuiet>350;},null,{timeout:90000});}
async function nav(page,tab){const toggle=page.locator('.navbar-toggle'),link=page.locator('#main_nav a[data-value="'+tab+'"]');if(await toggle.isVisible()&&!await link.isVisible())await toggle.click();await link.click();await page.waitForFunction(tab=>Shiny.shinyapp.$inputValues.main_nav===tab,tab);if(await toggle.isVisible())await page.locator('.navbar-collapse').waitFor({state:'hidden'});await settle(page);}
async function choose(page,id,value){await page.locator('#'+id).evaluate((node,value)=>{if(node.selectize)node.selectize.setValue(value);else{node.value=value;jQuery(node).trigger('change');}},value);await page.waitForFunction(({id,value})=>Shiny.shinyapp.$inputValues[id]===value,{id,value});await settle(page);}
async function download(page,id,name){await page.locator('#'+id).waitFor({state:'visible'});const pending=page.waitForEvent('download');await page.locator('#'+id).click();const file=await pending;assert.equal(await file.failure(),null);await file.saveAs(path.join(campaign,'results',name));evidence.downloads.push(name);}
async function capture(page,code,width,tab,selector){
 await settle(page);
 const snapshot=await page.locator(selector).first().evaluate(node=>{
  const visible=n=>n.getClientRects().length&&getComputedStyle(n).visibility!=='hidden';
  const texts=[...node.querySelectorAll('[data-wlv-label],.shiny-text-output,svg text')].filter(visible).map(n=>({key:n.dataset.wlvLabel||n.id||n.tagName,text:n.textContent.trim()}));
  const svg=[...node.querySelectorAll('.wlv-country-landing-chart svg path,.wlv-country-landing-chart svg polygon')].map(n=>Object.fromEntries(['class','d','points','stroke','fill','stroke-width'].map(k=>[k,n.getAttribute(k)])));
  const controls=[...node.querySelectorAll('select,input:not([type="hidden"])')].filter(n=>!n.id.startsWith('wlv_language_')).map(n=>({id:n.id,value:n.value,checked:n.checked}));
  return {texts,svg,controls};
 });
 const errors=await page.locator('.shiny-output-error').evaluateAll(nodes=>nodes.filter(n=>n.getClientRects().length).map(n=>n.textContent));assert.deepEqual(errors,[]);
 evidence.views.push({code,width,tab,...snapshot});
 await page.screenshot({path:path.join(campaign,'results','equivalence-'+code+'-'+width+'-'+tab+'.png')});
}
(async()=>{const browser=await chromium.launch({headless:true});try{
 for(const width of [1440,390]){
  const context=await browser.newContext({locale:'pt-BR',viewport:{width,height:1000},acceptDownloads:true});
  const page=await context.newPage();page.setDefaultTimeout(90000);page.on('pageerror',error=>evidence.errors.push(error.message));
  await page.goto(url);await page.waitForFunction(()=>window.Shiny?.shinyapp?.$inputValues.l);await settle(page);
  for(const code of ['pt','fr','bn']){
   await nav(page,'about');await page.locator('#language_menu_toggle').click();await page.locator('#language_menu [lang="'+({pt:'pt-BR',fr:'fr',bn:'bn'}[code])+'"]').click();await page.waitForFunction(code=>window.wlvI18n?.code()===code,code);await settle(page);
   await capture(page,code,width,'about','.wlv-about-hero');
   await nav(page,'map');await page.waitForFunction(()=>WLVMap.stats('map')?.layers>0&&document.getElementById('map')?.getAttribute('aria-busy')==='false');await capture(page,code,width,'map','[data-value="map"].tab-pane');
   await nav(page,'country');await page.waitForFunction(()=>document.getElementById('wlv-country-entry')?.dataset.state==='ready');await page.waitForFunction(()=>document.getElementById('wlv-country-globe')?.dataset.animating==='false');await capture(page,code,width,'country','#wlv-country-entry');
   if(width===1440){
    await page.locator('#co_entry_more').click();await page.locator('#wlv-country-content').waitFor({state:'visible'});await settle(page);
    await download(page,'co_country_file_WIOD13','equivalence-country-'+code+'.xlsx');
    await download(page,'co_sector_file_WIOD13','equivalence-sector-'+code+'.xlsx');
    await page.locator('#co_catalogue_back').click();await settle(page);
   }
   await nav(page,'indicators');
   if(!(await page.locator('#indicators-indicator_title').textContent()).trim()){await page.locator('[id^="indicators-catalogue_"]').first().waitFor({state:'visible'});await page.locator('[id^="indicators-catalogue_"]').first().click();}
   await page.waitForFunction(()=>document.getElementById('indicators-series')?._fullLayout);await settle(page);
   if(width===1440)await download(page,'indicators-workbook_WIOD13','equivalence-indicator-'+code+'.xlsx');
   await nav(page,'trade');await page.waitForFunction(()=>document.getElementById('trade-app')?.dataset.ready==='true');
   await page.locator('#trade-view a[data-value="map"]').click();await page.waitForFunction(()=>window.WLVTrade?.flows('trade-map')?.count>0);await capture(page,code,width,'trade','#trade-app');
   await nav(page,'download');await choose(page,'dl_method','WIOD13');await choose(page,'dl_country','BRA');await choose(page,'dl_indicator','gdp.s.mv');
   if(width===1440){
    await download(page,'dl_file','equivalence-aggregate-'+code+'.xlsx');
    await choose(page,'dl_ml_method','WIOD13');await choose(page,'dl_ml_country','BRA');await choose(page,'dl_ml_partner','USA');await download(page,'dl_ml_file','equivalence-multilateral-'+code+'.xlsx');
   }
   console.log('EQUIVALENCE_CAPTURED',code,width);
  }
  await context.close();
 }
 assert.deepEqual(evidence.errors,[]);
}finally{await browser.close();fs.writeFileSync(path.join(campaign,'results/efficiency-equivalence.json'),JSON.stringify(evidence,null,2),'utf8');}})().catch(error=>{console.error(error.stack);process.exitCode=1;});
