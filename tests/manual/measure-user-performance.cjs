'use strict';
// Read-only baseline: real navigation, browser timing, transfer bytes and downloads.
// All generated files must be inside a managed panel campaign.
const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
for(const key of ['TEMP','TMP','TMPDIR'])assert.equal(path.resolve(process.env[key]),path.resolve(campaign,'scratch'));
const url='http://127.0.0.1:'+(process.env.WLVPANEL_PORT||38134);
const result={method:{repetitions:3,quietWindowMs:150,mobileNavigation:'Wait for the menu to finish opening before clicking a tab; animation time is included.',server:'one reused local R/Shiny process; the first pass can warm shared caches',profiles:{desktop:{width:1440,network:'unthrottled loopback',cpuRate:1},limited:{width:390,latencyMs:80,downloadBytesPerSecond:500000,uploadBytesPerSecond:250000,cpuRate:4}}},runs:[]};
async function settle(page){
 await page.evaluate(()=>window.performanceQuiet=0);
 await page.waitForFunction(()=>{
  if(document.documentElement.classList.contains('shiny-busy')){window.performanceQuiet=0;return false;}
  if(!window.performanceQuiet)window.performanceQuiet=performance.now();
  return performance.now()-window.performanceQuiet>=150;
 },null,{timeout:90000});
}
async function ready(page,tab){
 await page.waitForFunction(tab=>window.Shiny?.shinyapp?.$inputValues.main_nav===tab,tab);
 if(tab==='map')await page.waitForFunction(()=>window.WLVMap?.stats('map')?.layers>0&&document.getElementById('map')?.getAttribute('aria-busy')==='false');
 if(tab==='country')await page.waitForFunction(()=>document.getElementById('wlv-country-entry')?.dataset.state==='ready');
 if(tab==='indicators')await page.locator('[id^="indicators-catalogue_"]').first().waitFor({state:'visible'});
 if(tab==='trade')await page.waitForFunction(()=>document.getElementById('trade-app')?.dataset.ready==='true');
 if(tab==='publications')await page.locator('.wlv-publication').first().waitFor({state:'visible'});
 await settle(page);
}
async function nav(page,tab){
 const toggle=page.locator('.navbar-toggle'),link=page.locator('#main_nav a[data-value="'+tab+'"]');
 if(await toggle.isVisible()){
  await page.waitForFunction(()=>!document.querySelector('.navbar-collapse')?.classList.contains('collapsing'));
  if(!await page.locator('.navbar-collapse').evaluate(node=>node.classList.contains('in')))await toggle.click();
  await page.waitForFunction(()=>{const menu=document.querySelector('.navbar-collapse');return menu?.classList.contains('in')&&!menu.classList.contains('collapsing');});
 }
 await link.click();await ready(page,tab);
}
async function readMetrics(client){return Object.fromEntries((await client.send('Performance.getMetrics')).metrics.map(item=>[item.name,item.value]));}
function diffMetrics(before,after){
 const keys=['TaskDuration','ScriptDuration','LayoutDuration','RecalcStyleDuration'];
 return Object.fromEntries(keys.map(key=>[key+'Ms',Math.round(((after[key]||0)-(before[key]||0))*1000)]).concat([['heapMiB',+(after.JSHeapUsedSize/1048576).toFixed(2)],['nodes',after.Nodes]]));
}
(async()=>{const browser=await chromium.launch({headless:true});try{
 for(const profile of ['desktop','limited'])for(let repeat=1;repeat<=3;repeat++){
  const context=await browser.newContext({viewport:{width:result.method.profiles[profile].width,height:1000},locale:'pt-BR',acceptDownloads:true});
  const page=await context.newPage();page.setDefaultTimeout(90000);
  await page.addInitScript(()=>{
   window.perfAudit={longTasks:[],lcp:[]};
   new PerformanceObserver(list=>list.getEntries().forEach(entry=>window.perfAudit.longTasks.push({start:entry.startTime,duration:entry.duration}))).observe({type:'longtask',buffered:true});
   new PerformanceObserver(list=>list.getEntries().forEach(entry=>window.perfAudit.lcp.push({start:entry.startTime,size:entry.size,url:entry.url}))).observe({type:'largest-contentful-paint',buffered:true});
  });
  const client=await context.newCDPSession(page);
  await client.send('Network.enable');await client.send('Performance.enable');
  if(profile==='limited'){
   await client.send('Network.emulateNetworkConditions',{offline:false,latency:80,downloadThroughput:500000,uploadThroughput:250000,connectionType:'cellular4g'});
   await client.send('Emulation.setCPUThrottlingRate',{rate:4});
  }
  const run={profile,repeat,phases:[],requests:[],websocket:[],errors:[]};result.runs.push(run);
  let phase='cold_open';const requests=new Map();
  page.on('pageerror',error=>run.errors.push(error.message));
  client.on('Network.responseReceived',event=>{
   const headers=event.response.headers;
   requests.set(event.requestId,{phase,url:event.response.url,type:event.type,status:event.response.status,mime:event.response.mimeType,
    cache:event.response.fromDiskCache||event.response.fromPrefetchCache||false,
    encoding:headers['Content-Encoding']||headers['content-encoding']||'',cacheControl:headers['Cache-Control']||headers['cache-control']||''});
  });
  client.on('Network.loadingFinished',event=>{const entry=requests.get(event.requestId);if(entry){entry.encodedBytes=event.encodedDataLength;run.requests.push(entry);requests.delete(event.requestId);}});
  client.on('Network.webSocketFrameReceived',event=>{
   const payload=event.response.payloadData;
   const entry={phase,bytes:Buffer.byteLength(payload)};
   try{const data=JSON.parse(payload);entry.keys=Object.keys(data);if(data.values)entry.outputs=Object.fromEntries(Object.entries(data.values).map(([key,value])=>[key,Buffer.byteLength(JSON.stringify(value)||'')]));}catch{}
   run.websocket.push(entry);
  });
  async function measure(name,action){
   phase=name;const before=await readMetrics(client),start=Date.now();
   try{await action();}catch(error){
    run.failure={phase:name,message:String(error),state:await page.evaluate(()=>({input:Shiny?.shinyapp?.$inputValues.main_nav,active:document.querySelector('#main_nav li.active a')?.dataset.value,menu:document.querySelector('.navbar-collapse')?.className})).catch(()=>null)};
    await page.screenshot({path:path.join(campaign,'results',`performance-failure-${profile}-${repeat}.png`)}).catch(()=>{});
    throw error;
   }
   const elapsed=Date.now()-start;
   const after=await readMetrics(client);
   const snapshot=await page.evaluate(()=>({navigation:performance.getEntriesByType('navigation').map(entry=>({ttfbMs:entry.responseStart,domContentLoadedMs:entry.domContentLoadedEventEnd,loadMs:entry.loadEventEnd,transfer:entry.transferSize,decoded:entry.decodedBodySize,encoded:entry.encodedBodySize}))[0],paints:performance.getEntriesByType('paint').map(entry=>({name:entry.name,start:entry.startTime})),lcp:window.perfAudit?.lcp.at(-1),longTasks:window.perfAudit?.longTasks||[],visibleErrors:[...document.querySelectorAll('.shiny-output-error')].filter(node=>node.getClientRects().length).map(node=>node.textContent)}));
   assert.deepEqual(snapshot.visibleErrors,[]);
   // Chromium resets duration counters on navigation; subtract only within a document.
   const entry={name,elapsedMs:elapsed,...diffMetrics(['cold_open','warm_reload'].includes(name)?{}:before,after)};
   if(['cold_open','warm_reload'].includes(name))Object.assign(entry,snapshot);
   run.phases.push(entry);console.log(profile,repeat,name,elapsed);
  }
  await measure('cold_open',async()=>{await page.goto(url,{waitUntil:'load'});await ready(page,'about');});
  await measure('warm_reload',async()=>{await page.reload({waitUntil:'load'});await ready(page,'about');});
  for(const tab of ['map','country','indicators'])await measure('open_'+tab,()=>nav(page,tab));
  await measure('indicator_series',async()=>{
   await page.locator('[id^="indicators-catalogue_"]').first().click();
   await page.waitForFunction(()=>document.getElementById('indicators-series')?._fullLayout);
   await settle(page);
  });
  await measure('open_trade',()=>nav(page,'trade'));
  for(const n of [1,2])await measure('trade_download_'+n,async()=>{
   const pending=page.waitForEvent('download');await page.locator('#trade-download').click();const download=await pending;
   assert.equal(await download.failure(),null);await download.saveAs(path.join(campaign,'results',profile+'-'+repeat+'-trade-'+n+'.xlsx'));
  });
  await measure('open_publications',()=>nav(page,'publications'));
  await measure('return_about',()=>nav(page,'about'));
  await measure('language_french',async()=>{
   await page.locator('#language_menu_toggle').click();await page.locator('#language_menu [lang="fr"]').click();
   await page.waitForFunction(()=>Shiny.shinyapp.$inputValues.l==='Français'&&document.documentElement.lang==='fr');await settle(page);
  });
  await measure('idle_about',async()=>{await page.waitForTimeout(2500);});
  assert.deepEqual(run.errors,[]);
  fs.writeFileSync(path.join(campaign,'results','performance-baseline.json'),JSON.stringify(result,null,2),'utf8');
  await context.close();
 }
}finally{await browser.close();fs.writeFileSync(path.join(campaign,'results','performance-baseline.json'),JSON.stringify(result,null,2),'utf8');}})().catch(error=>{console.error(error.stack);process.exitCode=1;});
