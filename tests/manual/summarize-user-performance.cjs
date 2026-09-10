'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
const input=JSON.parse(fs.readFileSync(path.join(campaign,'results/performance-baseline.json'),'utf8'));
const median=values=>values.slice().sort((a,b)=>a-b)[Math.floor(values.length/2)];
const invalidNavigationCounters=input.runs.some(run=>run.phases.some(phase=>phase.name==='warm_reload'&&phase.TaskDurationMs<0));
const summary={method:{...input.method,server:'one reused local R/Shiny process; the first pass can warm shared caches'},navigationCpuNote:invalidNavigationCounters?'Duration counters reset on navigation; raw warm_reload CPU deltas are invalid and excluded. Reusable measurement script now uses absolute counters for navigation.':'Navigation CPU counters are excluded from the timing summary; interaction durations are compared within one document.',profiles:{}};
for(const profile of ['desktop','limited']){
 const runs=input.runs.filter(run=>run.profile===profile);assert.equal(runs.length,3);
 const phases={};
 for(const name of runs[0].phases.map(phase=>phase.name)){
  const samples=runs.map(run=>run.phases.find(phase=>phase.name===name));
  phases[name]={medianMs:median(samples.map(item=>item.elapsedMs)),minMs:Math.min(...samples.map(item=>item.elapsedMs)),maxMs:Math.max(...samples.map(item=>item.elapsedMs))};
  if(!['cold_open','warm_reload'].includes(name))phases[name].medianBrowserTaskMs=median(samples.map(item=>item.TaskDurationMs));
 }
 const network={};
 for(const phase of ['cold_open','warm_reload','open_map','language_french','language_french_with_idle']){
  const records=runs.map(run=>{
   const phases=phase==='language_french_with_idle'?['language_french','idle_about']:[phase];
   const requests=run.requests.filter(item=>phases.includes(item.phase)),frames=run.websocket.filter(item=>phases.includes(item.phase));
   const outputs={};for(const frame of frames)for(const [key,bytes] of Object.entries(frame.outputs||{}))outputs[key]=(outputs[key]||0)+bytes;
   return {httpEncodedBytes:requests.reduce((sum,item)=>sum+(item.encodedBytes||0),0),requests:requests.length,cachedRequests:requests.filter(item=>item.cache).length,
    websocketDecodedBytes:frames.reduce((sum,item)=>sum+item.bytes,0),websocketFrames:frames.length,
    largestOutputs:Object.entries(outputs).sort((a,b)=>b[1]-a[1]).slice(0,10)};
  });
  network[phase]={medianHttpEncodedBytes:median(records.map(item=>item.httpEncodedBytes)),medianWebsocketDecodedBytes:median(records.map(item=>item.websocketDecodedBytes)),samples:records};
 }
 const sample=runs[1];
 const navigation=sample.phases.filter(item=>['cold_open','warm_reload'].includes(item.name)).map(item=>({name:item.name,navigation:item.navigation,paints:item.paints,lcp:item.lcp,longTaskCount:item.longTasks.length,longTaskMs:item.longTasks.reduce((sum,task)=>sum+task.duration,0)}));
 summary.profiles[profile]={phases,network,navigation,largestColdRequests:sample.requests.filter(item=>item.phase==='cold_open').sort((a,b)=>b.encodedBytes-a.encodedBytes).slice(0,12),errors:runs.flatMap(run=>run.errors)};
}
fs.writeFileSync(path.join(campaign,'results/performance-summary.json'),JSON.stringify(summary,null,2),'utf8');
console.log(JSON.stringify(summary,null,2));
