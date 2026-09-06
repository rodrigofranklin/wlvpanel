const assert = require('node:assert/strict');
const frames = [];
const projectionEvents = [];
const observers = [];
global.WLVEqualEarth = {attach(element, map) {
  projectionEvents.push(['attach', element.id, map]);
  return {resize() {projectionEvents.push(['resize', element.id]);},
    destroy() {projectionEvents.push(['destroy', element.id]);}};
}};
global.ResizeObserver = class {
  constructor(callback) {this.callback = callback; observers.push(this);}
  observe(element) {this.element = element;}
  disconnect() {this.disconnected = true;}
};
global.requestAnimationFrame = callback => frames.push(callback);
global.Shiny = {addCustomMessageHandler() {}, setInputValue() {}};
const updates = require('../../www/wlv-indicators.js');
const tick = () => { while (frames.length) frames.shift()(); };
function map() {
  const handlers = {};
  return {on(event, fn) {(handlers[event] ||= new Set()).add(fn);},
    off(event, fn) {handlers[event]?.delete(fn);},
    fire(event) {handlers[event]?.forEach(fn => fn());}};
}
function shape() {
  return {style: {}, tooltip: null,
    setStyle(style) {this.style = style;}, getTooltip() {return this.tooltip;},
    bindTooltip(label) {this.tooltip = label;}, setTooltipContent(label) {this.tooltip = label;}};
}
const first = {BRA: {color: '#111111', label: 'Brasil: 1', missing: false}};
const newest = {BRA: {color: '#222222', label: 'Brasil: 2', missing: false},
  AUT: {color: '#333333', label: '\u00c1ustria: 3', missing: false}};
updates.receive({id: 'indicator-map', countries: first});
tick();
assert.deepEqual(updates.pending('indicator-map'), ['BRA']);
const original = map();
updates.attach({id: 'indicator-map'}, original);
assert.equal(projectionEvents[0][0], 'attach');
observers[0].callback();
assert.deepEqual(projectionEvents[1], ['resize', 'indicator-map']);
updates.receive({id: 'indicator-map', countries: newest});
tick();
assert.deepEqual(updates.pending('indicator-map'), ['BRA', 'AUT']);
const brazil = shape(), austria = shape(), layers = {BRA: brazil};
original.layerManager = {getLayer: (type, id) => layers[id]};
original.fire('layeradd');
tick();
assert.equal(brazil.style.fillColor, '#222222');
assert.equal(brazil.tooltip, 'Brasil: 2');
assert.deepEqual(updates.pending('indicator-map'), ['AUT']);
layers.AUT = austria;
original.fire('layeradd');
tick();
assert.equal(austria.tooltip, '\u00c1ustria: 3');
assert.deepEqual(updates.pending('indicator-map'), []);
original.fire('unload');
assert.equal(observers[0].disconnected, true);
assert.equal(projectionEvents.at(-1)[0], 'destroy');
delete original.layerManager;
updates.receive({id: 'indicator-map', countries: first});
tick();
assert.deepEqual(updates.pending('indicator-map'), ['BRA']);
const replacement = map(), newBrazil = shape();
replacement.layerManager = {getLayer: () => newBrazil};
updates.attach({id: 'indicator-map'}, replacement);
tick();
assert.equal(newBrazil.tooltip, 'Brasil: 1');
assert.equal(newBrazil.style.fillColor, '#111111');
assert.deepEqual(updates.pending('indicator-map'), []);
const secondReplacement = map(), secondBrazil = shape();
secondReplacement.layerManager = {getLayer: () => secondBrazil};
updates.attach({id: 'indicator-map'}, secondReplacement);
tick();
assert.equal(secondBrazil.tooltip, 'Brasil: 1');
assert.equal(observers[1].disconnected, true);
const identity = secondBrazil;
updates.receive({id:'indicator-map', countries:{BRA:{color:'#444444', label:'Brazil: 4', missing:false}}});
tick();
assert.equal(secondReplacement.layerManager.getLayer('shape', 'BRA'), identity);
assert.equal(identity.tooltip, 'Brazil: 4');
assert.equal(identity.style.fillColor, '#444444');
console.log('Indicator map lifecycle: latest payload, missing manager/layers and recreation passed.');
