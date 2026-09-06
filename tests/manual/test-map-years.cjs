const {test}=require('node:test');
const assert=require('node:assert/strict');
const {snapYear}=require('../../www/wlv-map-controls.js');
test('source coverage preserves valid years and clamps outside its limits',()=>{
  assert.equal(snapYear([2000,2001,2002],2001),2001);
  assert.equal(snapYear([1995,2000,2007],2014),2007);
  assert.equal(snapYear([2000,2014],1995),2000);
});
test('new source chooses its nearest available year',()=>{
  assert.equal(snapYear([2000,2007,2014],2008),2007);
  assert.equal(snapYear([2005],2014),2005);
});
test('animation and keyboard advance across sparse years instead of looping',()=>{
  assert.equal(snapYear([2005,2007],2006,2005),2007);
  assert.equal(snapYear([2000,2005,2014],2006,2005),2014);
});
test('backward navigation crosses gaps and stops at the first available year',()=>{
  assert.equal(snapYear([2005,2007],2006,2007),2005);
  assert.equal(snapYear([2000,2005,2014],2013,2014),2005);
  assert.equal(snapYear([2005,2007],2004,2005),2005);
});
