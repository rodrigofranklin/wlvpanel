// Navigation, source settings, valid downloads and publication catalogue.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
const results=path.join(campaign,'results');
const records=[];
async function choose(p,id,value){
  if(value) await p.waitForFunction(({id,value})=>{
    const n=document.getElementById(id);
    return n?.selectize ? !!n.selectize.options[value] : [...(n?.options||[])].some(o=>o.value===value);
  },{id,value});
  await p.locator('#'+id).evaluate((n,v)=>{if(n.selectize)n.selectize.setValue(v);else{n.value=v;window.jQuery(n).trigger('change');}},value);
  await p.waitForFunction(({id,value})=>Shiny.shinyapp.$inputValues[id]===value,{id,value});
}
async function idle(p){await p.waitForFunction(()=>!document.documentElement.classList.contains('shiny-busy'));}
async function nav(p,value){
  if(p.viewportSize().width<768&&!await p.locator('.navbar-collapse').evaluate(n=>n.classList.contains('in')))await p.locator('.navbar-toggle').click();
  await p.locator('#main_nav a[data-value="'+value+'"]').click();
  await p.waitForFunction(v=>Shiny.shinyapp.$inputValues.main_nav===v,value);
  if(p.viewportSize().width<768)await p.locator('.navbar-collapse').waitFor({state:'hidden'});
  await idle(p);
}
async function layout(p,label){
  const state=await p.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,errors:[...document.querySelectorAll('.shiny-output-error')].filter(n=>n.offsetWidth&&n.offsetHeight).map(n=>n.textContent)}));
  assert.ok(state.scroll<=state.width+1,label+JSON.stringify(state));assert.deepEqual(state.errors,[]);
}
async function download(p,id,file){
  await p.locator('#'+id).waitFor({state:'visible'});
  await p.waitForFunction(id=>!!document.getElementById(id)?.getAttribute('href')&&!document.getElementById(id).classList.contains('disabled'),id);
  const event=p.waitForEvent('download');await p.locator('#'+id).click();const d=await event;
  const target=path.join(results,file);await d.saveAs(target);
  const content=fs.readFileSync(target);assert.ok(content.length>1000);assert.equal(content.subarray(0,2).toString(),'PK');
  return {name:d.suggestedFilename(),bytes:content.length};
}
(async()=>{
  const browser=await chromium.launch({headless:true});
  try{
    for(const width of [1440,1024,768,390,320]){
      const p=await browser.newPage({viewport:{width,height:900},acceptDownloads:true});
      const errors=[];p.on('pageerror',e=>errors.push(String(e)));
      try{
        await p.goto('http://127.0.0.1:'+(process.env.WLVPANEL_PORT||'38129'));
        await p.waitForFunction(()=>window.WLVMap?.stats('map')?.layers>0);
        assert.deepEqual((await p.locator('#main_nav a').allTextContents()).map(s=>s.trim()),['Sobre','Mapa','País','Indicadores','Download','Publicações','Como citar']);
        await layout(p,'map');
        for(const value of ['about','country','indicators','download','publications','cite']){
          await nav(p,value);await layout(p,value);
        }
        await nav(p,'download');
        await choose(p,'dl_method','');
        await p.locator('#dl_download button[disabled]').waitFor({state:'visible'});
        await choose(p,'dl_method','WIOD13');
        await p.waitForFunction(()=>document.getElementById('dl_country').selectize.options.BRA);
        await choose(p,'dl_country','BRA');
        await choose(p,'dl_indicator','surplus_value.empe_p.r.pc');
        const aggregate=await download(p,'dl_file','download-aggregate-'+width+'.xlsx');
        await choose(p,'dl_ml_method','WIOD13');
        await p.waitForFunction(()=>document.getElementById('dl_ml_country').selectize.options.BRA);
        await choose(p,'dl_ml_country','BRA');
        await p.waitForFunction(()=>document.getElementById('dl_ml_partner').selectize.options.USA&&!document.getElementById('dl_ml_partner').selectize.options.BRA);
        await choose(p,'dl_ml_partner','USA');
        const bilateral=await download(p,'dl_ml_file','download-bilateral-'+width+'.xlsx');
        await p.locator('#language_toggle').click();
        await p.waitForFunction(()=>{
          const countries=document.getElementById('dl_country').selectize;
          const partners=document.getElementById('dl_ml_partner').selectize;
          return document.documentElement.lang==='en'&&document.getElementById('dl_file')?.textContent.includes('Download file')&&
            countries.options.BRA?.[countries.settings.labelField]==='Brazil'&&
            partners.options.USA?.[partners.settings.labelField]?.includes('United');
        });
        await idle(p);
        assert.equal(await p.locator('#dl_country').inputValue(),'BRA');
        assert.equal(await p.locator('#dl_ml_partner').inputValue(),'USA');
        await choose(p,'dl_ml_partner','');
        await p.locator('#dl_ml_download button[disabled]').waitFor({state:'visible'});
        await p.waitForFunction(()=>document.getElementById('dl_ml_ind_cat').selectize.options['CX.']);
        await choose(p,'dl_ml_ind_cat','CX.');
        await p.waitForFunction(()=>Shiny.shinyapp.$inputValues.dl_ml_ind_cat==='CX.');await idle(p);
        await choose(p,'dl_ml_ind_scope','T.');
        await p.waitForFunction(()=>Shiny.shinyapp.$inputValues.dl_ml_ind_scope==='T.');await idle(p);
        await choose(p,'dl_ml_ind_un','MP');
        const multilateral=await download(p,'dl_ml_file','download-multilateral-'+width+'.xlsx');
        await nav(p,'publications');
        await p.locator('.wlv-publication').first().waitFor();
        const total=await p.locator('.wlv-publication').count();assert.ok(total>0);
        const authors=await p.locator('#publications-author').evaluate(n=>n.selectize?Object.keys(n.selectize.options).filter(Boolean):[...n.options].map(o=>o.value).filter(Boolean));
        assert.equal(authors.length,2);
        await choose(p,'publications-author',authors[0]);await idle(p);
        assert.ok(await p.locator('.wlv-publication').count()>0);
        await choose(p,'publications-author','');await idle(p);
        await p.locator('#publications-search').fill('zz-no-publication-zz');
        await p.waitForFunction(()=>document.querySelectorAll('.wlv-publication').length===0);
        await p.locator('#publications-search').fill('');
        await p.waitForFunction(n=>document.querySelectorAll('.wlv-publication').length===n,total);
        await p.locator('#language_toggle').click();
        await p.waitForFunction(()=>document.documentElement.lang==='pt-BR'&&document.querySelector('.wlv-publications h1')?.textContent==='Publicações');
        await layout(p,'publications');
        await p.screenshot({path:path.join(results,'publications-'+width+'.png'),fullPage:true});
        assert.deepEqual(errors,[]);
        records.push({width,status:'passed',tabs:7,aggregate,bilateral,multilateral,publications:total});
      }catch(error){await p.screenshot({path:path.join(results,'panel-failure-'+width+'.png'),fullPage:true});console.error('ERRORS',errors,await p.evaluate(()=>Object.fromEntries(Object.entries(Shiny.shinyapp.$inputValues).filter(([key])=>key.startsWith('dl_')))));throw error;}
      finally{await p.close();}
    }
  }finally{await browser.close();fs.writeFileSync(path.join(results,'panel-interface.json'),JSON.stringify(records,null,2));}
  console.log(JSON.stringify(records,null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
