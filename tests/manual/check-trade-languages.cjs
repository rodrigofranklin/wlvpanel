// Real translated Trade/Download UI and downloadable XLSX files in one session.
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
const url='http://127.0.0.1:'+(process.env.WLVPANEL_PORT||38132);
async function nav(page,id){
  await page.locator('#main_nav a[data-value="'+id+'"]').click();
  await page.waitForFunction(id=>window.Shiny?.shinyapp?.$inputValues.main_nav===id,id,{timeout:60000});
}
async function select(page,id,value){
  await page.waitForFunction(({id,value})=>document.getElementById(id)?.selectize?.options[value],{id,value},{timeout:60000});
  await page.locator('#'+id).evaluate((node,value)=>node.selectize.setValue(value),value);
  await page.waitForFunction(({id,value})=>Shiny.shinyapp.$inputValues[id]===value,{id,value},{timeout:60000});
}
async function download(page,id,name){
  await page.locator('#'+id).waitFor({timeout:60000});
  const pending=page.waitForEvent('download',{timeout:60000});
  await page.locator('#'+id).click();const result=await pending;
  assert.equal(await result.failure(),null);
  await result.saveAs(path.join(campaign,'results',name));
}
(async()=>{const browser=await chromium.launch({headless:true});try{
  const context=await browser.newContext({viewport:{width:1440,height:1000},locale:'es-ES'});
  const page=await context.newPage(),errors=[],evidence=[];
  page.setDefaultTimeout(60000);page.on('pageerror',error=>errors.push(error.message));
  await page.goto(url);await page.waitForFunction(()=>window.wlvI18n?.code()==='es');
  for(const lang of ['es','zh']){
    if(lang==='zh'){
      await page.locator('#language_menu_toggle').click();
      await page.locator('#language_menu [data-language="中文"]').click();
      await page.waitForFunction(()=>window.wlvI18n.code()==='zh');
    }
    await nav(page,'trade');
    await page.waitForFunction(()=>document.getElementById('trade-app')?.dataset.ready==='true'&&document.querySelector('#trade-rank .main-svg'));
    await page.waitForFunction(expected=>document.getElementById('trade-title')?.textContent===expected,lang==='es'?'Comercio':'贸易');
    await page.locator('#trade-view a[data-value="map"]').click();
    await page.waitForFunction(expected=>document.getElementById('trade-map')?.getAttribute('aria-label')?.startsWith(expected),lang==='es'?'Mapa de socios comerciales':'Equal Earth投影贸易伙伴地图');
    await download(page,'trade-download','trade-'+lang+'.xlsx');
    const trade=await page.evaluate(()=>({title:document.getElementById('trade-title').textContent,
      lang:document.getElementById('trade-app').dataset.tradeLang,
      country:document.getElementById('trade-country').selectize.$control.text(),
      map:document.getElementById('trade-map').getAttribute('aria-label')}));
    await page.screenshot({path:path.join(campaign,'results','trade-'+lang+'.png')});
    await nav(page,'download');
    await select(page,'dl_method','WIOD16');await select(page,'dl_country','BRA');
    await download(page,'dl_file','download-'+lang+'.xlsx');
    const state=await page.evaluate(()=>({lang:window.wlvI18n.code(),scroll:document.documentElement.scrollWidth,
      errors:[...document.querySelectorAll('.shiny-output-error')].filter(node=>node.getClientRects().length).map(node=>node.textContent),
      country:document.getElementById('dl_country').selectize.$control.text()}));
    assert.equal(state.lang,lang);assert.equal(trade.lang,lang);
    assert.ok(state.scroll<=1441);assert.deepEqual(state.errors,[]);
    evidence.push({lang,trade,download:state});
  }
  assert.deepEqual(errors,[]);console.log(JSON.stringify(evidence));
  fs.writeFileSync(path.join(campaign,'results','trade-languages.json'),JSON.stringify(evidence,null,2),'utf8');
}finally{await browser.close();}})().catch(error=>{console.error(error.stack);process.exitCode=1;});
