'use strict';
// Compare the independently captured application views, without altering images.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {PNG}=require('pngjs');
const [beforeDirectory,afterDirectory]=process.argv.slice(2);
assert.ok(beforeDirectory&&afterDirectory,'Supply before and after results directories');
const campaign=process.env.WLV_CAMPAIGN_ROOT;
assert.ok(campaign&&fs.existsSync(path.join(campaign,'.campaign.json')));
const before=JSON.parse(fs.readFileSync(path.join(beforeDirectory,'efficiency-equivalence.json'),'utf8'));
const after=JSON.parse(fs.readFileSync(path.join(afterDirectory,'efficiency-equivalence.json'),'utf8'));
assert.deepEqual(before.errors,[]);assert.deepEqual(after.errors,[]);
assert.deepEqual(before.downloads,after.downloads);
assert.equal(before.views.length,24);assert.equal(after.views.length,24);
const results=[];
for(const old of before.views){
 const current=after.views.find(item=>item.code===old.code&&item.width===old.width&&item.tab===old.tab);
 assert.ok(current);
 const differences={};
 for(const property of ['controls','svg','texts']){
  if(JSON.stringify(old[property])!==JSON.stringify(current[property]))differences[property]={before:old[property],after:current[property]};
 }
 const oldKeys=new Set(old.texts.map(item=>item.key));
 const retainedTexts=current.texts.filter(item=>oldKeys.has(item.key));
 const textsPreserved=JSON.stringify(retainedTexts)===JSON.stringify(old.texts);
 const name=`equivalence-${old.code}-${old.width}-${old.tab}.png`;
 const a=PNG.sync.read(fs.readFileSync(path.join(beforeDirectory,name)));
 const b=PNG.sync.read(fs.readFileSync(path.join(afterDirectory,name)));
 assert.equal(a.width,b.width);assert.equal(a.height,b.height);
 let changedPixels=0,channelDifference=0;const pixelExamples=[];
 for(let i=0;i<a.data.length;i+=4){
  let changed=false;
  for(let j=0;j<4;j++){const difference=Math.abs(a.data[i+j]-b.data[i+j]);channelDifference+=difference;if(difference)changed=true;}
  if(changed){changedPixels++;if(pixelExamples.length<24)pixelExamples.push({x:(i/4)%a.width,y:Math.floor(i/4/a.width),before:[...a.data.subarray(i,i+4)],after:[...b.data.subarray(i,i+4)]});}
 }
 results.push({code:old.code,width:old.width,tab:old.tab,textsPreserved,additionalTextBindings:current.texts.length-retainedTexts.length,pixels:{changed:changedPixels,total:a.width*a.height,percent:100*changedPixels/(a.width*a.height),meanChannelDifference:channelDifference/a.data.length,examples:pixelExamples},differences});
}
fs.writeFileSync(path.join(campaign,'results/efficiency-view-comparison.json'),JSON.stringify(results,null,2),'utf8');
console.log(JSON.stringify(results.map(({differences,...item})=>({...item,differentFields:Object.keys(differences)})),null,2));
// New data-wlv-label attributes intentionally make more text observable. A
// reviewer must inspect these differences; controls and geometry must be exact.
assert.ok(results.every(item=>!item.differences.controls&&!item.differences.svg),'Controls and numeric geometry must be identical');
assert.ok(results.every(item=>item.textsPreserved),'Every previously observed text must be identical and in the same order');
