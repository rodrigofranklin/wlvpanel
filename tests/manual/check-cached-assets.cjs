// Simulate a returning browser reusing module CSS/JS from before the redesign.
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
const url=process.env.WLVPANEL_URL||'http://127.0.0.1:'+(process.env.WLVPANEL_PORT||38129);
const label=process.env.WLV_CHECK_LABEL||'cached-assets';
const evidence={url,cases:[],errors:[]};
(async()=>{
 const browser=await chromium.launch({headless:true});
 try{
  for(const width of [1440,390]){
   const context=await browser.newContext({viewport:{width,height:1000}}),p=await context.newPage(),staleRequests=[],assetRequests=[];
   p.on('request',request=>{if(request.url().includes('wlv-'))assetRequests.push(request.url());});
   p.on('pageerror',e=>evidence.errors.push(String(e)));
   await context.route(/\/wlv-(country|indicators|publications|download)\.(css|js)(\?.*)?$/,async route=>{
    staleRequests.push(route.request().url());
    // The former country stylesheet hid the illustration and had no catalogue grid/button rules.
    const css='.wlv-country-page{min-width:0;background:#f4f7fa}.wlv-country-page-heading{display:flex;padding:24px;background:#fff}.wlv-country-header{display:flex;padding:16px 24px;background:#fff}';
    const asset=new URL(route.request().url()).pathname;
    await route.fulfill({contentType:asset.endsWith('.css')?'text/css':'application/javascript',body:asset.endsWith('wlv-country.css')?css:'/* cached prior module asset */'});
   });
   await p.goto(url,{waitUntil:'domcontentloaded'});
   await p.waitForFunction(()=>window.Shiny?.shinyapp?.$inputValues.main_nav);
   if(width<768)await p.locator('.navbar-toggle').click();
   await p.locator('#main_nav a[data-value="country"]').click();
   await p.locator('[data-wlv-country="BRA"]').waitFor();
   await p.evaluate(()=>document.fonts.ready);
   const state=await p.evaluate(()=>{
    const grid=document.querySelector('.wlv-country-catalogue-groups'),button=document.querySelector('[data-wlv-country="BRA"]'),page=document.querySelector('.wlv-country-page');
    return {display:getComputedStyle(grid).display,columns:getComputedStyle(grid).gridTemplateColumns.split(' ').length,
     background:getComputedStyle(page).backgroundColor,bodyImage:getComputedStyle(document.body).backgroundImage,
     buttonDisplay:getComputedStyle(button).display,buttonBackground:getComputedStyle(button).backgroundColor,
     width:innerWidth,scroll:document.documentElement.scrollWidth};
   });
   evidence.cases.push({width,staleRequests,assetRequests,state});
   await p.screenshot({path:path.join(campaign,'results',label+'-'+width+'.png')});
   assert.equal(state.display,'grid','Continent panels retain their layout with old assets cached');
   assert.equal(state.columns,width<768?1:3);
   assert.equal(state.background,'rgba(0, 0, 0, 0)','Old CSS must not cover the background illustration');
   assert.match(state.bodyImage,/wlv-work-world\.png/);
   assert.equal(state.buttonDisplay,'block');
   assert.equal(state.buttonBackground,'rgba(0, 0, 0, 0)');
   assert.ok(state.scroll<=width+1);
   await p.locator('[data-wlv-country="BRA"]').click();
   await p.locator('#wlv-country-detail').waitFor({state:'visible'});
   await p.waitForFunction(()=>document.getElementById('co_panel_title')?.textContent==='Brasil');
   assert.deepEqual(staleRequests,[],'Reusing the old unversioned assets must be unnecessary');
   await context.close();
  }
  assert.deepEqual(evidence.errors,[]);evidence.status='passed';
 }catch(error){evidence.status='failed';evidence.failure=String(error);process.exitCode=1;}
 finally{await browser.close();fs.writeFileSync(path.join(campaign,'results',label+'.json'),JSON.stringify(evidence,null,2));console.log(JSON.stringify(evidence));}
})();
