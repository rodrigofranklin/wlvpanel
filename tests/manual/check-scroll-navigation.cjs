// Main navigation persistence and scrollbars below the header, using real Shiny.
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
const url='http://127.0.0.1:'+(process.env.WLVPANEL_PORT||38129);
const evidence=[];
const catalogue=JSON.parse(fs.readFileSync(path.join(__dirname,'../../config/publications.json'),'utf8'));
async function ready(page,value){
 await page.waitForFunction(value=>window.Shiny?.shinyapp?.$inputValues.main_nav===value&&document.body.dataset.wlvTab===value&&!document.documentElement.classList.contains('shiny-busy'),value);
}
async function nav(page,value){
 if(page.viewportSize().width<768&&!await page.locator('.navbar-collapse').evaluate(n=>n.classList.contains('in')))await page.locator('.navbar-toggle').click();
 await page.locator('#main_nav a[data-value="'+value+'"]').click();
 if(page.viewportSize().width<768)await page.locator('.navbar-collapse').waitFor({state:'hidden'});
 await ready(page,value);
}
(async()=>{
 const browser=await chromium.launch({headless:true});
 try{
  for(const width of [1440,1024,390,320]){
   const context=await browser.newContext({viewport:{width,height:900}});
   const page=await context.newPage(),errors=[];
   page.on('pageerror',e=>errors.push(e.stack||e.message));
   await page.goto(url);
   await ready(page,'about');
   const initial=await page.evaluate(()=>{
    const area=document.getElementById('wlv-page-scroll'),nav=document.querySelector('.navbar'),bar=document.querySelector('.wlv-topbar');
    return {top:area.getBoundingClientRect().top,bottom:area.getBoundingClientRect().bottom,
     navBottom:nav.getBoundingClientRect().bottom,headerWidth:bar.getBoundingClientRect().width,
     client:area.clientHeight,scroll:area.scrollHeight,gutter:getComputedStyle(document.documentElement).scrollbarGutter,
     overflow:getComputedStyle(area).overflowY,bodyOverflow:getComputedStyle(document.body).overflowY};
   });
   assert.equal(initial.headerWidth,width);
   assert.equal(initial.top,initial.navBottom);
   assert.equal(initial.bottom,900);
   assert.equal(initial.gutter,'auto');
   assert.equal(initial.overflow,'auto');
   assert.equal(initial.bodyOverflow,'hidden');
   assert.ok(initial.scroll>initial.client);
   const navBefore=await page.locator('.navbar').boundingBox();
   await page.locator('#wlv-page-scroll').evaluate(n=>n.scrollTop=n.scrollHeight);
   assert.equal(await page.evaluate(()=>window.scrollY),0);
   assert.deepEqual(await page.locator('.navbar').boundingBox(),navBefore);
   await page.locator('.wlv-about-person img[src="people/rodrigo-borges.gif"]').scrollIntoViewIfNeeded();
   const portrait=await page.locator('.wlv-about-person img[src="people/rodrigo-borges.gif"]').evaluate(n=>({decoded:n.complete&&n.naturalWidth>0,background:getComputedStyle(n).backgroundColor}));
   assert.deepEqual(portrait,{decoded:true,background:'rgb(255, 255, 255)'});
   await page.locator('.wlv-about-person:has(img[src="people/rodrigo-borges.gif"])').screenshot({path:path.join(campaign,'results','borges-white-'+width+'.png')});
   await nav(page,'map');
   await page.waitForFunction(()=>window.WLVMap?.stats('map')?.layers>0&&document.querySelector('#map[aria-busy="false"]'));
   const mapScroll=await page.locator('#wlv-page-scroll').evaluate(n=>({height:n.clientHeight,scroll:n.scrollHeight,width:n.clientWidth,outer:n.offsetWidth,top:n.scrollTop}));
   assert.ok(mapScroll.scroll<=mapScroll.height+1,JSON.stringify(mapScroll));
   assert.equal(mapScroll.width,mapScroll.outer,'No empty gutter when map has no scrollbar');
   assert.equal(mapScroll.top,0);
   assert.equal(await page.locator('.wlv-topbar').evaluate(n=>n.getBoundingClientRect().width),width);
   await page.screenshot({path:path.join(campaign,'results','scroll-map-'+width+'.png')});
   await nav(page,'country');
   await page.reload();
   await ready(page,'country');
   const cookie=(await context.cookies(url)).find(c=>c.name==='wlv_last_tab');
   assert.equal(cookie.value,'country');
   assert.equal(cookie.sameSite,'Lax');
   assert.ok(cookie.expires>Date.now()/1000+300*86400);
   await nav(page,'publications');
   await page.locator('.wlv-publication').first().waitFor();
   assert.equal(await page.locator('.wlv-publication').count(),catalogue.entries.length);
   assert.equal(await page.getByText('Fonte verificada',{exact:true}).count(),0);
   assert.ok(await page.locator('.wlv-publication a[href="https://www.edufes.ufes.br/items/show/777"]').count());
   await nav(page,'indicators');
   await page.locator('[id="indicators-catalogue_surplus_value.empe_p.r.pc"]').click();
   await page.locator('#indicators-view a[data-value="map"]').click();
   assert.equal((await context.cookies(url)).find(c=>c.name==='wlv_last_tab').value,'indicators','Nested map tab does not overwrite main navigation');
   const saved=await context.cookies(url);
   await context.close();
   const restored=await browser.newContext({viewport:{width,height:900}});
   await restored.addCookies(saved);
   const returnPage=await restored.newPage();
   returnPage.on('pageerror',e=>errors.push(e.stack||e.message));
   await returnPage.goto(url);
   await ready(returnPage,'indicators');
   await returnPage.goto('about:blank');
   await restored.addCookies([{name:'wlv_last_tab',value:'cite',url}]);
   await returnPage.goto(url);
   await ready(returnPage,'about');
   await returnPage.goto('about:blank');
   await restored.addCookies([{name:'wlv_last_tab',value:'%E0%A4%A',url}]);
   await returnPage.goto(url);
   await ready(returnPage,'about');
   assert.deepEqual(errors,[]);
   await restored.close();
   evidence.push({width,status:'passed',initial,mapScroll,firstVisit:'about',restoredTabs:['country','indicators'],invalidCookieFallback:'about',portrait,publications:catalogue.entries.length});
  }
  const blocked=await browser.newContext({viewport:{width:1440,height:900}});
  await blocked.addInitScript(()=>Object.defineProperty(Document.prototype,'cookie',{configurable:true,get(){throw new Error('Cookies blocked');},set(){throw new Error('Cookies blocked');}}));
  const page=await blocked.newPage();
  await page.goto(url);await ready(page,'about');await nav(page,'download');await page.reload();await ready(page,'about');
  await blocked.close();
  console.log('SCROLL_NAVIGATION_OK: 1440,1024,390,320; reload, new session, invalid and blocked cookies.');
 }finally{
  await browser.close();
  fs.writeFileSync(path.join(campaign,'results','scroll-navigation.json'),JSON.stringify(evidence,null,2));
 }
})().catch(e=>{console.error(e);process.exitCode=1;});
