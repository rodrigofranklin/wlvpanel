// Run with Node from any working directory; no browser or installed npm package
// is required. Keep the shell's temporary paths inside an active panel campaign.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const repo = path.resolve(__dirname, '../..');
const script = fs.readFileSync(path.join(repo, 'www/wlv-trade.js'), 'utf8');
const stylesheet = fs.readFileSync(path.join(repo, 'www/wlv-trade.css'), 'utf8');
const moduleSource = fs.readFileSync(path.join(repo, 'modules/trade/main.R'), 'utf8');

// Derive the filter classes from the actual Shiny UI. A stub that returned
// every details element for any selector would miss UI/JS class drift.
const details = Array.from(moduleSource.matchAll(/shiny::tags\$details\([^)]*?\bclass\s*=\s*"([^"]+)"/g),
  match => ({open: true, classes: match[1].split(/\s+/)}))
  .filter(detail => detail.classes.some(className => className.endsWith('filter-group')));
assert.ok(details.length >= 2, 'The actual trade UI must supply filter details.');
const controlClass = 'wlv-trade-controls';
assert.ok(new RegExp('class = "' + controlClass + '(?: [^"]*)?"').test(moduleSource), 'The filter container class must exist in the UI.');
details.forEach(detail => detail.classes.forEach(className => {
  assert.ok(stylesheet.includes('.' + controlClass + ' .' + className),
    'The trade stylesheet must style the actual filter class: ' + className);
}));
const app = {dataset: {}, querySelectorAll(selector) {
  const match = selector.match(/^\.([\w-]+) details\.([\w-]+)$/);
  assert.ok(match, 'The mobile filter query must target details within their container.');
  assert.equal(match[1], controlClass);
  const selected = details.filter(detail => detail.classes.includes(match[2]));
  assert.equal(selected.length, details.length, 'The JS selector must match all filter details declared by main.R.');
  return selected;
}};
const inputs = [], handlers = {}, observers = [];
let geometryReady = 0, projectionDestroyed = 0, resized = 0;
const root = {
  console, Map, Set, URL, module: {exports: {}},
  requestAnimationFrame: f => f(), setTimeout: f => f(),
  location: {href: 'https://example.test/panel?keep=1&keep=2&lang=en&search=a%20b&trade_old=stale&trade_version=old#overview'},
  matchMedia: () => ({matches: true}),
  document: {documentElement: {lang: 'pt'}, getElementById: id => id === 'trade-app' ? app : null, addEventListener() {}},
  Shiny: {addCustomMessageHandler: (name, f) => { handlers[name] = f; }, setInputValue: (...args) => inputs.push(args)},
  ResizeObserver: class {
    constructor(callback) { this.callback = callback; observers.push(this); }
    observe(element) { this.element = element; }
    disconnect() { this.disconnected = true; }
  },
  WLVEqualEarth: {attach: (element, map, options) => {
    assert.equal(options.polygonPane, 'wlv-trade-polygons');
    assert.equal(options.waitForGeometry, true);
    return {geometryReady: () => { geometryReady++; }, resize: () => { resized++; }, destroy: () => { projectionDestroyed++; }};
  }}
};
vm.runInNewContext(script, root, {filename: 'www/wlv-trade.js'});
const api = root.module.exports;
assert.equal(typeof handlers.wlvTradeMap, 'function');
assert.equal(typeof handlers.wlvTradeState, 'function');
const layer = () => ({setStyle(s) { this.style = s; }, getTooltip() { return this.tooltip; },
  setTooltipContent(text) { this.tooltip = text; }, bindTooltip(text) { this.tooltip = text; }});
const map = layers => ({layerManager: {getLayer: (_, id) => layers[id]}, listeners: {},
  on(name, f) { this.listeners[name] = f; }, off(name) { delete this.listeners[name]; }});
const element = {id: 'trade-map', clientWidth: 390, setAttribute() {}};
api.receive({id: element.id, countries: {BRA: {color: 'gold', label: 'Brazil'}, CHN: {color: 'wine', label: 'China', missing: true}}});
const layers = {BRA: layer()}, first = map(layers);
api.attach(element, first);
assert.equal(inputs.length, 1);
assert.equal(geometryReady, 0);
assert.equal(layers.BRA.style.fillColor, 'gold');
assert.equal(api.pending(element.id).join(','), 'CHN');
observers[0].callback();
assert.equal(resized, 1);
layers.CHN = layer(); first.listeners.layeradd();
assert.equal(geometryReady, 1);
assert.equal(layers.CHN.style.fillOpacity, 0.25);
assert.equal(api.pending(element.id).length, 0);
api.attach(element, first);
assert.equal(inputs.length, 1);
const secondLayers = {BRA: layer(), CHN: layer()}, second = map(secondLayers);
api.attach(element, second);
assert.equal(inputs.length, 2);
assert.equal(projectionDestroyed, 1);
assert.equal(observers[0].disconnected, true);
assert.equal(secondLayers.BRA.tooltip, 'Brazil');
assert.equal(Object.keys(first.listeners).length, 0);
api.receiveState({id: 'trade-app', lang: 'pt', state: {country: 'BRA', label: 'Com\u00e9rcio', year: 2014, version: 'release-20260909', private: {skip: true}}});
assert.equal(app.dataset.ready, 'true');
assert.equal(details.every(d => !d.open), true);
assert.equal(new URL(api.shareUrl('trade-app')).searchParams.has('trade_private'), false);
details[0].open = true;
api.receiveState({id: 'trade-app', lang: 'pt', state: {country: 'CHN', label: 'Com\u00e9rcio', year: 2014, version: 'release-20260909'}});
assert.equal(details[0].open, true);
const url = new URL(api.shareUrl('trade-app'));
assert.deepEqual(url.searchParams.getAll('keep'), ['1', '2']);
assert.equal(url.searchParams.get('lang'), 'en');
assert.equal(url.searchParams.get('search'), 'a b');
assert.equal(url.pathname, '/panel');
assert.equal(url.hash, '#overview');
assert.equal(url.searchParams.has('trade_old'), false);
assert.equal(url.searchParams.get('trade_country'), 'CHN');
assert.equal(url.searchParams.get('trade_label'), 'Com\u00e9rcio');
assert.equal(url.searchParams.get('trade_version'), 'release-20260909');
assert.equal(url.searchParams.getAll('trade_version').length, 1);
assert.equal(url.searchParams.get('trade_open'), '1');

// Exercise the SVG layer against map projection methods, not longitude-based
// interpolation. The fake DOM is intentionally small and does not load a browser.
class SvgNode {
  constructor(tag) { this.tag = tag; this.attributes = {}; this.style = {}; this.children = []; this.listeners = {}; }
  setAttribute(name, value) { this.attributes[name] = String(value); }
  appendChild(child) { child.parentNode = this; this.children.push(child); return child; }
  removeChild(child) { this.children.splice(this.children.indexOf(child), 1); child.parentNode = null; return child; }
  addEventListener(name, handler) { this.listeners[name] = handler; }
  get firstChild() { return this.children[0] || null; }
}
root.document.createElementNS = (_, tag) => new SvgNode(tag);
const overlayPane = new SvgNode('div'), panes = {overlayPane};
const projectedCoordinates = [], removedTooltips = [];
const flowMap = Object.assign(map({BRA: layer(), CHN: layer(), CAN: layer()}), {
  scale: 2, origin: {x: 0, y: 0},
  getPanes() { return panes; }, getPane(name) { return panes[name]; },
  createPane(name) { panes[name] = new SvgNode('div'); return panes[name]; },
  getSize() { return {x: 720, y: 360}; },
  containerPointToLayerPoint() { return this.origin; },
  latLngToLayerPoint(coordinates) {
    projectedCoordinates.push(Array.from(coordinates));
    return {x: (coordinates[1] + 180) * this.scale, y: (90 - coordinates[0]) * this.scale};
  },
  layerPointToLatLng(coordinates) { return [90 - coordinates[1] / this.scale, coordinates[0] / this.scale - 180]; },
  mouseEventToLatLng() { return [30, 120]; },
  removeLayer(tooltip) { removedTooltips.push(tooltip); }
});
let lastTooltip;
root.L = {tooltip() {
  lastTooltip = {setContent(content) { this.content = content; return this; },
    setLatLng(latlng) { this.latlng = latlng; return this; }, addTo() { return this; },
    _setPosition() {}, getElement() { return null; }};
  return lastTooltip;
}};
const flowElement = {id: 'trade-flow-map', clientWidth: 720, setAttribute() {}};
const flowState = api.attach(flowElement, flowMap);
const flowRows = [
  {id: 'CHN', from: 'CHN', to: 'BRA', from_lat: 30, from_lng: 120, to_lat: -10, to_lng: -40,
    amount: 100, value: 100, width: 14, label: '<strong>China → Brasil</strong><br>100 horas · 2007'},
  {id: 'CAN', from: 'BRA', to: 'CAN', from_lat: -10, from_lng: -40, to_lat: 50, to_lng: -100,
    amount: 25, value: -25, width: 3.5, label: '<strong>Brasil → Canadá</strong><br>25 horas · 2007'}
];
api.receive({id: flowElement.id, countries: {BRA: {color: 'gold', label: 'Brazil'}}, flows: {enabled: true, rows: flowRows}});
assert.equal(api.flows(flowElement.id).count, 2);
assert.equal(flowState.flowSvg.children.length, 2);
const firstArrow = flowState.flowSvg.children[0];
assert.equal(firstArrow.attributes['data-from'], 'CHN');
assert.equal(firstArrow.attributes['data-to'], 'BRA');
assert.equal(firstArrow.children[0].attributes['stroke-width'], '14');
assert.equal(flowState.flowSvg.children[1].children[0].attributes['stroke-width'], '3.5');
assert.equal(flowState.flowSvg.style.pointerEvents, 'none');
assert.equal(firstArrow.children[0].style.pointerEvents, 'stroke');
assert.equal(firstArrow.attributes.role, 'button');
assert.ok(firstArrow.children[1].attributes.d.startsWith('M280,200 '), 'The arrowhead must point to the projected receiver.');
assert.deepEqual(projectedCoordinates.slice(-4), [[30, 120], [-10, -40], [-10, -40], [50, -100]]);
firstArrow.listeners.pointerenter({});
assert.equal(lastTooltip.content, flowRows[0].label, 'Hover text retains the exact server amount and context.');
firstArrow.listeners.pointerleave();
assert.equal(flowState.tooltips.size, 0, 'Discarded flow tooltips must not accumulate in the clamp registry.');
assert.equal(removedTooltips.length, 1);
firstArrow.listeners.click({preventDefault() {}, stopPropagation() {}});
assert.equal(inputs.at(-1)[0], 'trade-flow-map_shape_click');
assert.equal(inputs.at(-1)[1].id, 'CHN');
firstArrow.listeners.keydown({key: 'Enter', preventDefault() {}, stopPropagation() {}});
assert.equal(inputs.at(-1)[1].source, 'trade-flow');
const previousPath = firstArrow.children[0].attributes.d;
flowMap.scale = 1.5; flowMap.origin = {x: 37, y: 19};
flowMap.listeners['move zoom viewreset resize']();
assert.notEqual(flowState.flowSvg.children[0].children[0].attributes.d, previousPath);
assert.equal(flowState.flowSvg.style.left, '37px');
assert.equal(flowState.flowSvg.style.top, '19px');
assert.equal(flowState.flowSvg.children[0].children[0].attributes['stroke-width'], '14');
const acrossMap = api.curveGeometry({x: 5, y: 90}, {x: 715, y: 95}, 10, 'date-line');
assert.equal(acrossMap.end.x, 715);
assert.ok(!/NaN|Infinity/.test(acrossMap.shaft + acrossMap.head));
assert.equal(api.curveGeometry({x: 5, y: 5}, {x: 5, y: 5}, 10, 'same-point'), null);
api.receive({id: flowElement.id, flows: {enabled: true, rows: [flowRows[1]]}});
assert.equal(api.flows(flowElement.id).count, 1);
assert.equal(flowState.flowSvg.children[0].attributes['data-partner'], 'CAN');
api.receive({id: flowElement.id, flows: {enabled: false, rows: flowRows}});
assert.equal(api.flows(flowElement.id).count, 0);
assert.equal(flowState.flowSvg.children.length, 0);
api.receive({id: flowElement.id, flows: {enabled: true, rows: [{...flowRows[0], to: 'ROW'}, {...flowRows[1], width: NaN}]}});
assert.equal(api.flows(flowElement.id).count, 0);
api.receive({id: flowElement.id, flows: {enabled: true, rows: flowRows}});
api.receive({id: flowElement.id, countries: {CHN: {color: 'gold', label: 'China'}}});
assert.equal(api.flows(flowElement.id).count, 0, 'A replacement metric without arrows must clear the previous arrows.');
flowState.destroy();
assert.equal(panes['wlv-trade-flows'].children.length, 0);
assert.equal(Object.keys(flowMap.listeners).length, 0);
console.log('Trade JS: lifecycle, map races, responsive controls, versioned URL, projected arrows, proportional widths, hover/click and cleanup passed.');
