'use strict';
// Run against a local app started with WLVPANEL_COUNTRY_HEADER=CF-IPCountry.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
for(const key of ['TEMP','TMP','TMPDIR'])assert.equal(path.resolve(process.env[key]),path.resolve(campaign,'scratch'));
const url='http://127.0.0.1:'+(process.env.WLVPANEL_PORT||'38132');
const evidence=[];
const registry=JSON.parse(fs.readFileSync(path.join(__dirname,'../../config/languages.json'),'utf8'));
async function language(page,code){
  await page.waitForFunction(code=>window.Shiny?.shinyapp?.$inputValues.l&&window.wlvI18n.code(Shiny.shinyapp.$inputValues.l)===code&&window.wlvI18n.code()===code,code,{timeout:60000});
}
(async()=>{
  const browser=await chromium.launch({headless:true});
  try{
    const cases=[
      {locale:'es-MX',code:'es',source:'browser'},
      {locale:'en-US',country:'BR',code:'pt',source:'country'},
      {locale:'en-US',country:'CN',code:'zh',source:'country'},
      {locale:'en-US',country:'CN',saved:'es',code:'es',source:'saved'},
      {locale:'en-US',country:'CN',saved:'es',query:'?lang=pt',code:'pt',source:'url'},
      {locale:'zh-TW',country:'XX',code:'zh',source:'browser'},
      {locale:'fr-CA',code:'fr',source:'browser'},
      {locale:'uk-UA',code:'uk',source:'browser'},
      {locale:'hi-IN',code:'hi',source:'browser'},
      {locale:'bn-BD',code:'bn',source:'browser'},
      {locale:'en-US',country:'JP',code:'ja',source:'country'},
      {locale:'en-US',country:'DE',code:'de',source:'country'}
    ];
    for(const item of cases){
      console.log('Initial language scenario',JSON.stringify(item));
      const context=await browser.newContext({locale:item.locale,extraHTTPHeaders:item.country?{'CF-IPCountry':item.country}:{},viewport:{width:1440,height:1000}});
      if(item.saved)await context.addCookies([{name:'wlv_language',value:item.saved,url}]);
      const page=await context.newPage(),errors=[];
      page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(url+(item.query||''));
      await language(page,item.code);
      assert.equal(await page.evaluate(()=>window.wlvInitialLanguage.source),item.source);
      assert.equal(await page.evaluate(()=>document.documentElement.lang),registry.find(entry=>entry.key===item.code).code);
      assert.deepEqual(errors,[]);
      if(item.query){
        await page.locator('#language_menu_toggle').click();
        await page.locator('#language_menu [data-language="Castellano"]').click();
        await language(page,'es');
        assert.equal(new URL(page.url()).searchParams.get('lang'),'es');
        await page.reload(); await language(page,'es');
      }
      evidence.push({...item,status:'passed'});
      await context.close();
    }
    fs.writeFileSync(path.join(campaign,'results','initial-language.json'),JSON.stringify(evidence,null,2));
    console.log(JSON.stringify(evidence));
  }finally{await browser.close();}
})().catch(error=>{console.error(error);process.exitCode=1;});
