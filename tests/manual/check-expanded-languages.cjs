'use strict';
// Real Shiny navigation, dynamic charts and downloads for every added locale.
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
for(const key of ['TEMP','TMP','TMPDIR'])assert.equal(path.resolve(process.env[key]),path.resolve(campaign,'scratch'));
const root=path.resolve(__dirname,'../..');
const registry=JSON.parse(fs.readFileSync(path.join(root,'config/languages.json'),'utf8'));
const locales=registry.filter(entry=>!['pt','en','es','zh'].includes(entry.key));
const url='http://127.0.0.1:'+(process.env.WLVPANEL_PORT||38133);
const evidence={views:[],downloads:[],errors:[]};
async function idle(page){
 await page.evaluate(()=>{window.localeQuiet=0;});
 await page.waitForFunction(()=>{
  if(document.documentElement.classList.contains('shiny-busy')){window.localeQuiet=0;return false;}
  if(!window.localeQuiet)window.localeQuiet=performance.now();
  return performance.now()-window.localeQuiet>300;
 },null,{timeout:90000});
}
async function language(page,entry){
 await page.locator('#language_menu_toggle').click();
 await page.locator('#language_menu [data-language="'+entry.value+'"]').click();
 await page.waitForFunction(entry=>window.wlvI18n?.code()===entry.key&&window.Shiny?.shinyapp?.$inputValues.l===entry.value&&document.documentElement.lang===entry.code,entry,{timeout:90000});
 await idle(page);
}
async function nav(page,tab){
 const toggle=page.locator('.navbar-toggle');
 if(await toggle.isVisible()&&!await page.locator('#main_nav a[data-value="'+tab+'"]').isVisible())await toggle.click();
 await page.locator('#main_nav a[data-value="'+tab+'"]').click();
 await page.waitForFunction(tab=>Shiny.shinyapp.$inputValues.main_nav===tab,tab);
 if(await toggle.isVisible())await page.locator('.navbar-collapse').waitFor({state:'hidden'});
 await idle(page);
}
async function layout(page,entry,tab,width){
 const geometry=await page.evaluate(()=>({scroll:document.documentElement.scrollWidth,viewport:innerWidth,
  contentWidth:document.querySelector('body > .container-fluid')?.clientWidth, contentScroll:document.querySelector('body > .container-fluid')?.scrollWidth,
  errors:[...document.querySelectorAll('.shiny-output-error')].filter(node=>node.getClientRects().length).map(node=>node.textContent)}));
 assert.ok(geometry.scroll<=width+2,JSON.stringify({code:entry.key,tab,...geometry}));
 assert.ok(geometry.contentScroll<=geometry.contentWidth+2,JSON.stringify({code:entry.key,tab,...geometry}));
 assert.deepEqual(geometry.errors,[]);
 evidence.views.push({code:entry.key,tab,width});
}
async function download(page,selector,file){
 const pending=page.waitForEvent('download',{timeout:90000});
 await page.locator(selector).first().click();
 const result=await pending;assert.equal(await result.failure(),null);
 await result.saveAs(path.join(campaign,'results',file));
 evidence.downloads.push(file);
}
(async()=>{const browser=await chromium.launch({headless:true});try{
 for(const width of [1440,390]){
  const context=await browser.newContext({viewport:{width,height:1000},locale:'pt-BR',acceptDownloads:true});
  const page=await context.newPage();page.setDefaultTimeout(90000);
  page.on('pageerror',error=>evidence.errors.push(error.message));
  await page.goto(url);await page.waitForFunction(()=>window.Shiny?.shinyapp?.$inputValues.l);
  for(const entry of locales){
   const catalog=JSON.parse(fs.readFileSync(path.join(root,'config/locales',entry.key+'.json'),'utf8'));
   await language(page,entry);
   await nav(page,'about');
   assert.equal(await page.locator('[data-wlv-label="about2.title"]').textContent(),catalog.labels['about2.title']);
   await layout(page,entry,'about',width);
   await nav(page,'map');
   await page.locator('#map').waitFor({state:'visible'});
   await page.waitForFunction(()=>window.WLVMap?.stats('map')?.layers>0&&
    document.getElementById('map')?.getAttribute('aria-busy')==='false');
   const mapIndicator=await page.evaluate(()=>Shiny.shinyapp.$inputValues.co_select_indicator);
   assert.ok(catalog.labels[mapIndicator],'Translated map indicator exists: '+mapIndicator);
   await page.waitForFunction(expected=>document.getElementById('map-current-indicator')?.textContent===expected,
    catalog.labels[mapIndicator]);
   assert.equal(await page.locator('#map-world-button [data-wlv-label="map.world"]').textContent(),catalog.labels['map.world']);
   await layout(page,entry,'map',width);
   await nav(page,'country');
   await page.waitForFunction(()=>document.querySelector('#wlv-country-entry')?.dataset.state==='ready');
   assert.ok((await page.locator('#co_entry_description').textContent()).includes(catalog.phrases['A portrait of labour, its compensation and exchanges of value with the world.']));
   assert.ok((await page.locator('#co_entry_labour_chart').textContent()).includes(catalog.phrases['Surplus value']));
   await layout(page,entry,'country',width);
   if(['de','ru','el','ja','ko','hi','bn','id','th'].includes(entry.key))await page.screenshot({path:path.join(campaign,'results','country-'+entry.key+'-'+width+'.png')});
   await nav(page,'indicators');
   if(!(await page.locator('#indicators-indicator_title').textContent()).trim()){
    await page.locator('[id^="indicators-catalogue_"]').first().waitFor({state:'visible'});
    await page.locator('[id^="indicators-catalogue_"]').first().click();
   }
   await page.waitForFunction(()=>document.querySelector('#indicators-indicator_title')?.textContent.trim());
   await page.waitForFunction(()=>Object.keys(document.getElementById('indicators-methods')?.selectize?.options||{}).length);
   await page.locator('#indicators-methods').evaluate(node=>node.selectize.setValue(Object.keys(node.selectize.options).filter(Boolean)));
   await idle(page);
   await layout(page,entry,'indicators',width);
   if(['hi','bn'].includes(entry.key)){
    await page.waitForFunction(code=>document.getElementById('indicators-series')?._context?.locale===code,entry.key);
    const tooltips=await page.locator('#indicators-series .modebar-btn').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('data-title')));
    assert.ok(tooltips.includes(entry.key==='hi'?'ज़ूम':'জুম'),'Plotly controls translated: '+entry.key);
   }
   if(width===1440)await download(page,'[id^="indicators-workbook_"]','indicator-'+entry.key+'.xlsx');
   await nav(page,'trade');
   await page.waitForFunction(()=>document.getElementById('trade-app')?.dataset.ready==='true');
   assert.equal(await page.locator('#trade-title').textContent(),catalog.phrases.Trade);
   await layout(page,entry,'trade',width);
   if(width===1440)await download(page,'#trade-download','trade-'+entry.key+'.xlsx');
   await nav(page,'download');
   await layout(page,entry,'download',width);
   await nav(page,'publications');
   await page.locator('.wlv-publication').first().waitFor();
   assert.ok((await page.locator('.wlv-publications-count').textContent()).includes(catalog.phrases['references found']));
   await layout(page,entry,'publications',width);
   console.log('LANGUAGE_UI_OK',entry.key,width);
  }
  await context.close();
 }
 // A long native name must fit the smallest supported width and survive reload.
 const page=await browser.newPage({locale:'id-ID',viewport:{width:320,height:800}});
 await page.goto(url);await page.waitForFunction(()=>window.wlvI18n?.code()==='id');
 await language(page,registry.find(entry=>entry.key==='id'));
 await page.reload();await page.waitForFunction(()=>window.wlvI18n?.code()==='id');
 await page.locator('#language_menu_toggle').click();
 await page.keyboard.press('End');
 assert.equal(await page.locator('#language_menu [data-language="ไทย"]').evaluate(node=>node===document.activeElement),true);
 const menuBounds=await page.locator('#language_menu').boundingBox();
 assert.ok(menuBounds.x>=0&&menuBounds.x+menuBounds.width<=320&&menuBounds.y+menuBounds.height<=800);
 assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=320));
 await page.screenshot({path:path.join(campaign,'results','languages-menu-320.png')});
 assert.deepEqual(evidence.errors,[]);console.log('EXPANDED_LANGUAGES_OK',evidence.views.length,evidence.downloads.length);
}finally{fs.writeFileSync(path.join(campaign,'results','expanded-languages.json'),JSON.stringify(evidence,null,2),'utf8');await browser.close();}})().catch(error=>{console.error(error.stack);process.exitCode=1;});
