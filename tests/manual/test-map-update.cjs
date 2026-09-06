/* Execute com node tests/manual/test-map-update.cjs, dentro de uma campanha. */
const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const vm = require("node:vm");
const api = require("../../www/wlv-map.js");

function polygon(color = "transparent") {
  return {
    options: { fillColor: color, color: "red", fillOpacity: 0.7 },
    styleCalls: 0,
    bindCalls: 0,
    contentCalls: 0,
    getTooltip() { return this.tooltip; },
    setStyle(style) { Object.assign(this.options, style); this.styleCalls += 1; },
    bindTooltip(label, options) { this.tooltip = { label, options }; this.bindCalls += 1; },
    setTooltipContent(label) { this.tooltip.label = label; this.contentCalls += 1; }
  };
}

test("atualiza a mesma geometria e preserva realce, evento e zoom", () => {
  const layer = polygon();
  const click = () => "BRA";
  layer.click = click;
  const map = { zoom: 5, layerManager: { getLayer: (category, id) => {
    assert.equal(category, "shape");
    assert.equal(id, "WIOD16.BRA");
    return layer;
  } } };
  assert.equal(api.updateLayers(map, [{ id: "WIOD16.BRA", color: "#0000ff", label: "Brasil" }]).changed, 1);
  assert.equal(layer.options.fillColor, "#0000ff");
  assert.equal(layer.options.color, "red");
  assert.equal(layer.options.fillOpacity, 0.7);
  assert.equal(layer.click, click);
  assert.equal(map.zoom, 5);
  api.updateLayers(map, [{ id: "WIOD16.BRA", color: "#0000ff", label: "Brazil" }]);
  assert.equal(layer.styleCalls, 1);
  assert.equal(layer.bindCalls, 1);
  assert.equal(layer.contentCalls, 1);
  assert.equal(layer.tooltip.label, "Brazil");
});

test("bases ocultas recebem o estado atual; ausência de dados limpa a cor antiga", () => {
  const hidden = polygon("#ff0000");
  const map = { layerManager: { getLayer: () => hidden } };
  const update = { id: "WIOD13.BRA", color: "transparent", label: "Sem dados" };
  api.updateLayers(map, [update]);
  api.updateLayers(map, [update]);
  assert.equal(hidden.options.fillColor, "transparent");
  assert.equal(hidden.tooltip.label, "Sem dados");
  assert.equal(hidden.styleCalls, 1);
  assert.equal(hidden.bindCalls, 1);
  assert.equal(hidden.contentCalls, 0);
});

test("geometrias ainda não carregadas permanecem pendentes", () => {
  const update = { id: "WIOD16.BRA", color: "#0000ff", label: "Brasil" };
  assert.deepEqual(api.updateLayers({ layerManager: { getLayer: () => null } }, [update]), {
    missing: [update], changed: 0
  });
});

test("fila tolera inicialização do gerenciador de layers", () => {
  const updates = [{ id: "BRA", color: "blue", label: "Brasil" }];
  assert.deepEqual(api.updateLayers({}, updates), { missing: updates, changed: 0 });
});

test("fila espera o mapa e coalesce filtros rápidos antes do desenho", () => {
  const callbacks = [];
  const ready = [];
  const context = {
    setTimeout: (callback) => callbacks.push(callback),
    Shiny: { addCustomMessageHandler() {}, setInputValue: (...args) => ready.push(args) }
  };
  vm.runInNewContext(fs.readFileSync(require.resolve("../../www/wlv-map.js"), "utf8"), context);
  const isolated = context.WLVMap;
  const flush = () => { while (callbacks.length) callbacks.shift()(); };
  const first = { id: "map", layers: [{ id: "BRA", color: "red", label: "Antigo" }] };
  isolated.receive(first);
  flush();
  const layers = new Map();
  const handlers = {};
  const attrs = {};
  const map = { layerManager: { getLayer: (_, id) => layers.get(id) },
    on: (event, callback) => { handlers[event] = callback; }, off() {} };
  isolated.attach({ id: "map", setAttribute: (key, value) => { attrs[key] = value; } }, map);
  assert.equal(ready[0][0], "map_wlv_ready");
  flush();
  assert.equal(attrs["aria-busy"], "true");
  isolated.receive({ id: "map", layers: [{ id: "BRA", color: "blue", label: "Atual" }] });
  const layer = polygon();
  layers.set("BRA", layer);
  handlers.layeradd();
  flush();
  assert.equal(layer.options.fillColor, "blue");
  assert.equal(layer.tooltip.label, "Atual");
  assert.equal(layer.styleCalls, 1);
  assert.equal(attrs["aria-busy"], "false");
  assert.equal(isolated.stats("map").layers, 1);
});

test("mapa recriado recupera atributos recentes e não altera a geometria", () => {
  const callbacks = [], handlers = {};
  const context = {
    setTimeout: callback => callbacks.push(callback),
    Shiny: { addCustomMessageHandler() {}, setInputValue() {} }
  };
  vm.runInNewContext(fs.readFileSync(require.resolve("../../www/wlv-map.js"), "utf8"), context);
  const flush = () => { while (callbacks.length) callbacks.shift()(); };
  const makeMap = layer => ({
    layerManager: { getLayer: () => layer },
    on(event, handler) { handlers[event] = handler; }, off() {}
  });
  const element = { id: "map", setAttribute() {} };
  const first = polygon();
  context.WLVMap.attach(element, makeMap(first));
  context.WLVMap.receive({ id: "map", layers: [{ id: "BRA", color: "green", label: "Brasil — seleção" }] });
  flush();
  handlers.unload();
  context.WLVMap.receive({ id: "map", layers: [{ id: "BRA", color: "gold", label: "Brazil — selection" }] });
  flush();
  assert.equal(first.options.fillColor, "green", "não repinta um mapa removido");
  const recreated = polygon();
  const geometry = [{ lat: -12, lng: -52 }];
  recreated.geometry = geometry;
  context.WLVMap.attach(element, makeMap(recreated));
  flush();
  assert.equal(recreated.options.fillColor, "gold");
  assert.equal(recreated.tooltip.label, "Brazil — selection");
  assert.equal(recreated.geometry, geometry);
});

test("tooltip cabe no mapa mobile após mover e traduzir, com alteração restrita à instância", () => {
  const handlers = {}, attributes = {};
  const L = { point: (x, y) => ({x, y}), DomUtil: {
    getPosition: node => node.position,
    setPosition: (node, point) => { node.position = point; }
  } };
  const context = { L, setTimeout() {},
    Shiny: { addCustomMessageHandler() {}, setInputValue() {} } };
  vm.runInNewContext(fs.readFileSync(require.resolve("../../www/wlv-map.js"), "utf8"), context);
  const map = { on(event, handler) { handlers[event] = handler; },
    off(event, handler) { if (handlers[event] === handler) delete handlers[event]; } };
  const element = { id: "map", clientWidth: 256, setAttribute() {},
    getBoundingClientRect: () => ({left: 32, right: 288, top: 20, bottom: 440}) };
  context.WLVMap.attach(element, map);
  let desiredWidth = 260;
  const node = { style: {}, position: {x: 0, y: 0},
    setAttribute: (key, value) => { attributes[key] = value; },
    getBoundingClientRect() {
      const width = Math.min(desiredWidth, parseFloat(this.style.maxWidth) || desiredWidth);
      const left = 32 + this.position.x, top = 20 + this.position.y;
      return {left, right: left + width, top, bottom: top + 72, width, height: 72};
    }
  };
  const nativePosition = point => { node.position = point; };
  const tooltip = { _setPosition: nativePosition, getElement: () => node,
    update() { this._setPosition({x: 134, y: 399}); } };
  const unrelatedTooltip = { _setPosition: nativePosition };
  handlers.tooltipopen({tooltip});
  function checkBounds() {
    const b = node.getBoundingClientRect();
    assert.ok(b.left >= 40 && b.right <= 280);
    assert.ok(b.top >= 28 && b.bottom <= 432);
  }
  checkBounds();
  assert.equal(node.style.maxWidth, "240px");
  assert.equal(attributes["data-wlv-clamped"], "true");
  desiredWidth = 400; // Texto em inglês mais longo, atualizado ainda aberto.
  tooltip.update();
  checkBounds();
  tooltip._setPosition({x: -20, y: -20}); // Sticky junto da borda oposta.
  checkBounds();
  assert.equal(unrelatedTooltip._setPosition, nativePosition);
  handlers.unload();
  assert.equal(tooltip._setPosition, nativePosition);
  assert.equal(handlers.tooltipopen, undefined);
});
