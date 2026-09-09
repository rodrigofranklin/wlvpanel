// All coauthor filters and branding against a real Shiny session, in both languages.
const {chromium}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const catalogue=JSON.parse(fs.readFileSync(path.join(__dirname,'../../config/publications.json'),'utf8'));
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
const url='http://127.0.0.1:'+(process.env.WLVPANEL_PORT||38129);
const evidence=[];
async function ready(p){
  await p.waitForFunction(()=>window.Shiny?.shinyapp?.$inputValues.main_nav&&!document.documentElement.classList.contains('shiny-busy'));
}
async function publications(p){
  if(p.viewportSize().width<768)await p.locator('.navbar-toggle').click();
  await p.locator('#main_nav a[data-value="publications"]').click();
  await p.locator('.wlv-publication').first().waitFor();
}
async function expectRecords(p,ids){
  await p.waitForFunction(expected=>JSON.stringify([...document.querySelectorAll('.wlv-publication')].map(n=>n.dataset.publicationId).sort())===JSON.stringify(expected),[...ids].sort());
}
(async()=>{
  const browser=await chromium.launch({headless:true});
  try{
    for(const width of [1440,390]){
      const context=await browser.newContext({viewport:{width,height:900}});
      const p=await context.newPage(),errors=[];
      p.on('pageerror',e=>errors.push(String(e)));
      await p.goto(url);await ready(p);
      await publications(p);
      await expectRecords(p,catalogue.entries.map(e=>e.id));
      const options=await p.locator('#publications-author option').evaluateAll(nodes=>nodes.filter(n=>n.value).map(n=>({id:n.value,name:n.textContent})));
      assert.deepEqual(options.map(o=>o.id).sort(),catalogue.members.map(m=>m.id).sort());
      for(const option of options)assert.equal(option.name,catalogue.members.find(m=>m.id===option.id).name);
      for(const lang of ['pt','en']){
        if(lang==='en'){
          await p.locator('#language_toggle').click();
          await p.waitForFunction(()=>document.documentElement.lang==='en'&&document.querySelector('.wlv-publications h1')?.textContent==='Publications');
        }
        for(const member of catalogue.members){
          await p.locator('#publications-author').selectOption(member.id);
          await expectRecords(p,catalogue.entries.filter(e=>e.members.includes(member.id)).map(e=>e.id));
        }
        await p.locator('#publications-author').selectOption('sanchez');
        await p.locator('#publications-year').selectOption('2022');
        await p.locator('#publications-search').fill('fixed capital');
        await expectRecords(p,['borges-2022-fixed-capital']);
        await p.locator('#publications-search').fill('');
        await p.locator('#publications-year').selectOption('');
        await p.locator('#publications-author').selectOption('');
        await expectRecords(p,catalogue.entries.map(e=>e.id));
        for(const entry of catalogue.entries.filter(e=>e.url_status==='unavailable')){
          const item=p.locator('[data-publication-id="'+entry.id+'"]');
          assert.equal(await item.locator('a').count(),0);
          assert.match(await item.innerText(),lang==='pt'?/Texto online temporariamente indisponível/:/Online text temporarily unavailable/);
        }
        const state=await p.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,
          oldTerm:/mais[ -]valia/i.test(document.querySelector('.tab-pane.active')?.innerText||''),
          errors:[...document.querySelectorAll('.shiny-output-error')].filter(n=>n.offsetWidth&&n.offsetHeight).map(n=>n.textContent)}));
        assert.ok(state.scroll<=width+1);assert.equal(state.oldTerm,false);assert.deepEqual(state.errors,[]);
        if(lang==='pt')await p.screenshot({path:path.join(campaign,'results','publications-authors-'+width+'.png')});
      }
      assert.equal(await p.locator('a.wlv-brand').getAttribute('href'),'https://worldlabourvalues.org/');
      // Intercept the external destination so these real clicks do not depend on its uptime.
      await context.route('https://worldlabourvalues.org/',route=>route.fulfill({status:200,contentType:'text/html',body:'<title>WLVD destination</title>'}));
      for(const selector of ['.wlv-brand img','.wlv-brand-name','a.wlv-brand']){
        if(!p.url().startsWith(url)){await p.goto(url);await ready(p);}
        if(selector==='a.wlv-brand'){await p.locator(selector).focus();await p.keyboard.press('Enter');}
        else await p.locator(selector).click();
        await p.waitForURL('https://worldlabourvalues.org/');
      }
      assert.deepEqual(errors,[]);
      evidence.push({width,status:'passed',authors:options,publications:catalogue.entries.length,languages:['pt','en'],brand:['image','name','keyboard']});
      await context.close();
    }
    fs.writeFileSync(path.join(campaign,'results','publications-authors.json'),JSON.stringify(evidence,null,2));
    console.log(JSON.stringify(evidence));
  }finally{await browser.close();}
})().catch(e=>{console.error(e.stack||e);process.exitCode=1;});
