/* Execute com node --test tests/manual/test-equal-earth.cjs dentro de uma campanha. */
const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const ee = require("../../www/wlv-equal-earth.js");
const DEG = Math.PI / 180;
const close = (actual, expected, epsilon = 1e-11) =>
  assert.ok(Math.abs(actual - expected) <= epsilon, `${actual} != ${expected}`);

test("Equal Earth coincide com referências independentes do PROJ em esfera de raio 1", () => {
  // Obtidos com sf::sf_project('+proj=longlat +R=1', '+proj=eqearth +R=1', ...).
  const points = [
    [0, 0, 0, 0],
    [180, 0, 2.7066299836960748, 0],
    [0, 90, 0, 1.3173627591574133],
    [-52, -12, -0.7737398571326466, -0.2421657412072243],
    [120, 60, 1.3593733917143729, 1.0883008355053194]
  ];
  points.forEach(([lng, lat, x, y]) => {
    const result = ee.forward(lng, lat);
    close(result.x, x);
    close(result.y, y);
  });
});

test("transformação inversa retorna as coordenadas em todo o mundo, incluindo polos e antimeridiano", () => {
  const latitudes = [-90, -89.999, -80, -60, -23.5, 0, 23.5, 60, 80, 89.999, 90];
  const longitudes = [-180, -179.999, -130, -45, 0, 45, 130, 179.999, 180];
  latitudes.forEach(lat => longitudes.forEach(lng => {
    const projected = ee.forward(lng, lat);
    const result = ee.inverse(projected.x, projected.y);
    close(result.lng, lng, 1e-8);
    close(result.lat, lat, 1e-7);
    assert.ok(Math.abs(projected.x) <= ee.extent.x + 1e-12);
    assert.ok(Math.abs(projected.y) <= ee.extent.y + 1e-12);
  }));
  assert.ok(ee.forward(-180, 0).x < 0);
  assert.ok(ee.forward(180, 0).x > 0);
});

test("Jacobiano preserva área da esfera em latitudes distintas", () => {
  const delta = 0.0001;
  [-85, -60, -30, 0, 30, 60, 85].forEach(lat => {
    [-160, -45, 0, 110, 170].forEach(lng => {
      const west = ee.forward(lng - delta, lat), east = ee.forward(lng + delta, lat);
      const south = ee.forward(lng, lat - delta), north = ee.forward(lng, lat + delta);
      const dxdl = (east.x - west.x) / (2 * delta * DEG);
      const dydl = (east.y - west.y) / (2 * delta * DEG);
      const dxdp = (north.x - south.x) / (2 * delta * DEG);
      const dydp = (north.y - south.y) / (2 * delta * DEG);
      close((dxdl * dydp - dydl * dxdp) / Math.cos(lat * DEG), 1, 1e-8);
    });
  });
});

test("inversa permanece finita nos espaços fora do contorno usados por pan e zoom", () => {
  [-100, -ee.extent.y, 0, ee.extent.y, 100].forEach(y => {
    [-100, 0, 100].forEach(x => {
      const p = ee.inverse(x, y);
      assert.ok(Number.isFinite(p.lng) && Number.isFinite(p.lat));
      assert.ok(Math.abs(p.lat) <= 90);
    });
  });
});

test("enquadramento cabe em desktop e mobile e inclui a largura máxima do equador", () => {
  [[1440, 700], [768, 500], [390, 420], [320, 420], [280, 330]].forEach(([width, height]) => {
    const zoom = ee.fitZoom(width, height);
    const scale = 256 * 2 ** zoom;
    assert.ok(scale <= width - 32 + 1e-8);
    assert.ok(scale * ee.extent.y / ee.extent.x <= height - 32 + 1e-8);
  });
  assert.ok(ee.fitZoom(280, 330) < 0, "telas estreitas exigem zoom negativo");
  assert.ok(ee.forward(180, 90).x < ee.extent.x * 0.6,
    "fitBounds de cantos polares cortaria quase metade da largura");
});

test("instala CRS isotrópico sem alterar Mercator ou outros mapas", () => {
  const mercator = { code: "EPSG:3857" };
  const L = {
    CRS: { Earth: { wrapLng: [-180, 180], distance() {} }, EPSG3857: mercator },
    extend: Object.assign,
    point: (x, y) => ({ x, y }),
    latLng: (lat, lng) => ({ lat, lng }),
    bounds: (min, max) => ({ min, max }),
    Transformation: class { constructor(a, b, c, d) { Object.assign(this, {a, b, c, d}); } }
  };
  const crs = ee.install(L);
  assert.equal(ee.install(L), crs);
  assert.equal(L.CRS.EPSG3857, mercator);
  assert.deepEqual(L.CRS.Earth.wrapLng, [-180, 180]);
  assert.equal(crs.wrapLng, undefined);
  assert.equal(crs.transformation.a, -crs.transformation.c);
  const origin = crs.projection.project({ lat: 0, lng: 0 });
  assert.deepEqual(origin, { x: 0, y: 0 });
  assert.deepEqual(crs.projection.unproject(origin), { lat: 0, lng: 0 });
});

test("Shift+arrastar enquadra o centro projetado da caixa, incluindo latitudes altas", () => {
  // Caixa assimétrica NW(60N,50E) / SE(0N,100E): fitBounds geográfico
  // confundiria NE/SW com os cantos reais e deslocaria o centro 6,52° a oeste.
  const nw = ee.forward(50, 60), se = ee.forward(100, 0);
  const map = {
    getSize: () => ({x: 1000, y: 600}), getZoom: () => 2,
    getMinZoom: () => 0, getMaxZoom: () => 10,
    getScaleZoom: (scale, zoom) => zoom + Math.log2(scale),
    containerPointToLatLng: ([x, y]) => ee.inverse(x / 100, -y / 100)
  };
  const start = { x: nw.x * 100, y: -nw.y * 100 };
  const end = { x: se.x * 100, y: -se.y * 100 };
  const view = ee.boxView(map, start, end);
  close(view.center.lat, 27.4168664, 1e-7);
  close(view.center.lng, 72.7707051, 1e-7);
  const scale = 2 ** (view.zoom - 2);
  assert.ok(Math.abs(end.x - start.x) * scale <= 1000 + 1e-8);
  assert.ok(Math.abs(end.y - start.y) * scale <= 600 + 1e-8);
  assert.deepEqual(ee.boxView(map, end, start), view, "arrastar em sentido inverso deve enquadrar a mesma área");
});

test("densificação única respeita buracos e a borda polar da Antártida", () => {
  const ll = (lat, lng) => ({ lat, lng });
  const outer = [ll(-90, -180), ll(-90, 180), ll(-80, 180), ll(-80, -180)];
  const hole = [ll(-82, 30), ll(-81, 30), ll(-81, 31), ll(-82, 31)];
  const input = [[outer, hole]], result = ee.densify(input, ll);
  assert.equal(result.length, 1);
  assert.equal(result[0].length, 2);
  assert.equal(result[0][0][0], outer[0]);
  assert.ok(result[0][0].some(p => p.lat === -90 && p.lng === 0));
  assert.deepEqual(input, [[outer, hole]], "não altera as coordenadas de origem");
  result[0].forEach(ring => ring.forEach((point, i) => {
    const next = ring[(i + 1) % ring.length];
    assert.ok(Math.abs(point.lat - next.lat) <= 2 + 1e-12);
    assert.ok(Math.abs(point.lng - next.lng) <= 2 + 1e-12);
  }));
});

test("base local é finita, cobre a Antártida e já está cortada no antimeridiano", () => {
  const data = JSON.parse(fs.readFileSync(require.resolve("../../www/wlv-land-110m.geojson"), "utf8"));
  let minimumLatitude = 90, maximumLatitude = -90;
  function coordinates(parts) {
    if (typeof parts[0][0] !== "number") return parts.forEach(coordinates);
    parts.forEach((p, index) => {
      minimumLatitude = Math.min(minimumLatitude, p[1]);
      maximumLatitude = Math.max(maximumLatitude, p[1]);
      const q = parts[(index + 1) % parts.length];
      const projected = ee.forward(p[0], p[1]);
      assert.ok(Number.isFinite(projected.x) && Number.isFinite(projected.y));
      if (Math.abs(p[0] - q[0]) > 180) {
        assert.equal(p[1], -90);
        assert.equal(q[1], -90);
      }
    });
  }
  function geometry(g) {
    if (g.type === "GeometryCollection") g.geometries.forEach(geometry);
    else coordinates(g.coordinates);
  }
  data.features.forEach(feature => geometry(feature.geometry));
  assert.equal(minimumLatitude, -90);
  assert.ok(maximumLatitude > 83);
});

function leafletScene(width = 1000, height = 600) {
  const ll = (lat, lng) => ({ lat, lng });
  const latlngs = parts => parts.map(p => Array.isArray(p) ?
    (typeof p[0] === "number" ? ll(p[0], p[1]) : latlngs(p)) : p);
  class Polygon {
    constructor(points, options = {}) { this.points = latlngs(points); this.options = options; }
    getLatLngs() { return this.points; }
    setLatLngs(points) { this.points = points; }
    addTo(map) { map.addLayer(this); return this; }
  }
  class Polyline {
    constructor(points, options = {}) { this.points = points; this.options = options; }
    addTo(map) { map.addLayer(this); return this; }
  }
  const node = () => ({ style: {}, children: [], listeners: {},
    setAttribute(name, value) { this[name] = value; },
    addEventListener(name, callback) { this.listeners[name] = callback; } });
  const L = {
    CRS: { WLVEqualEarth: {} }, Polygon: Polygon, latLng: ll,
    polygon: (points, options) => new Polygon(points, options),
    polyline: (points, options) => new Polyline(points, options),
    control: options => ({ options, addTo(map) { this.container = this.onAdd(); map.controls.push(this); } }),
    DomUtil: { create(tag, className, parent) {
      const result = Object.assign(node(), { tag, className });
      if (parent) parent.children.push(result);
      return result;
    } },
    DomEvent: { disableClickPropagation() {}, disableScrollPropagation() {} }
  };
  const element = Object.assign(node(), { clientWidth: width, clientHeight: height, querySelector: () => null });
  const map = {
    options: { crs: L.CRS.WLVEqualEarth }, layers: new Set(), controls: [], listeners: new Map(),
    center: ll(0, 0), zoom: 0, views: [], _loaded: true,
    getContainer() { return element; },
    hasLayer(layer) { return this.layers.has(layer); },
    eachLayer(callback) { this.layers.forEach(callback); },
    addLayer(layer) { this.layers.add(layer); this.fire("layeradd", { layer }); },
    removeLayer(layer) { this.layers.delete(layer); },
    createPane() { return node(); },
    on(name, callback) {
      if (!this.listeners.has(name)) this.listeners.set(name, new Set());
      this.listeners.get(name).add(callback);
    },
    off(name, callback) { if (this.listeners.has(name)) this.listeners.get(name).delete(callback); },
    fire(name, event) { if (this.listeners.has(name)) this.listeners.get(name).forEach(fn => fn(event)); },
    getCenter() { return this.center; }, getZoom() { return this.zoom; },
    getMinZoom: () => -2, getMaxZoom: () => 10,
    invalidateSize() {},
    setView(center, zoom) {
      this.fire("movestart");
      this.center = Array.isArray(center) ? ll(center[0], center[1]) : { ...center };
      this.zoom = zoom;
      this.views.push({ center: this.center, zoom });
      this.fire("moveend");
    },
    removeControl(control) { this.controls = this.controls.filter(item => item !== control); }
  };
  function withGlobals(callback) {
    const original = { L: globalThis.L, document: globalThis.document,
      getComputedStyle: globalThis.getComputedStyle };
    globalThis.L = L;
    globalThis.document = { documentElement: { lang: "pt" } };
    globalThis.getComputedStyle = () => ({ getPropertyValue: () => "" });
    try { callback(); } finally {
      if (original.L === undefined) delete globalThis.L; else globalThis.L = original.L;
      if (original.document === undefined) delete globalThis.document; else globalThis.document = original.document;
      if (original.getComputedStyle === undefined) delete globalThis.getComputedStyle;
      else globalThis.getComputedStyle = original.getComputedStyle;
    }
  }
  return { L, map, element, withGlobals };
}

test("limites projetados incluem apenas geometrias temáticas ativas, sem terra de fundo ou overlays", () => {
  const { L, map } = leafletScene();
  const country = L.polygon([[70, -160], [50, -120], [60, -110]], { pane: "polygons" }).addTo(map);
  const land = L.polygon([[-30, 20], [-10, 40], [-20, 50]], { pane: "base" }).addTo(map);
  L.polygon([[-90, -180], [0, 180], [90, -180]], { pane: "wlv-equal-earth-ocean" }).addTo(map);
  L.polyline([[-90, -180], [90, 180]], { pane: "wlv-equal-earth-grid" }).addTo(map);
  L.polygon([[-90, -180], [-60, 150], [-60, -150]], { pane: "overlayPane" }).addTo(map);
  L.polygon([[-90, -180], [0, 180], [90, -180]], { pane: "auxiliary" }).addTo(map);
  const hidden = L.polygon([[-85, -180], [-80, 180], [90, 0]], { pane: "polygons" });
  const group = { eachLayer(callback) { [country, hidden].forEach(callback); } };
  map.addLayer(group);
  country.setLatLngs(ee.densify(country.getLatLngs(), L.latLng));
  land.setLatLngs(ee.densify(land.getLatLngs(), L.latLng));
  const actual = ee.polygonBounds(map, L);
  const drawn = country.getLatLngs().map(p => ee.forward(p.lng, p.lat));
  assert.deepEqual(actual, {
    min: { x: Math.min(...drawn.map(p => p.x)), y: Math.min(...drawn.map(p => p.y)) },
    max: { x: Math.max(...drawn.map(p => p.x)), y: Math.max(...drawn.map(p => p.y)) }
  });
  assert.ok(actual.min.x > ee.forward(-160, -30).x,
    "o canto inexistente do bbox geográfico não deve ampliar o enquadramento");
  assert.ok(actual.min.y > -ee.extent.y && actual.max.y < ee.extent.y,
    "o contorno da esfera não é o limite dos polígonos");
  country.options.fillColor = "#cccccc";
  country.options.fillOpacity = 0;
  assert.deepEqual(ee.polygonBounds(map, L), actual,
    "valor ausente ou mudança de estilo não altera a extensão da geometria temática");
  map.removeLayer(country);
  assert.equal(ee.polygonBounds(map, L), null,
    "sem geometrias temáticas ativas, a terra de fundo não serve de fallback");
});

test("resize de mapa revelado após Sobre espera setView e preserva o fit inicial", () => {
  const scene = leafletScene();
  const { L, map, element } = scene;
  map._loaded = false;
  map.center = undefined;
  map.zoom = undefined;
  const getCenter = map.getCenter;
  map.getCenter = function () {
    if (!this._loaded) throw new Error("Set map center and zoom first.");
    return getCenter.call(this);
  };
  scene.withGlobals(() => {
    const state = ee.attach(element, map, {waitForGeometry:true});
    try {
      assert.doesNotThrow(() => state.resize());
      assert.equal(state.initialFitPending, true);
      assert.equal(state.width, 0);
      // Leaflet sets _loaded just before movestart, then supplies center/zoom
      // and emits load at the end of its first _resetView.
      map._loaded = true;
      map.fire('movestart');
      assert.equal(state.initialFitPending, true, 'first Leaflet setView is not user navigation');
      map.center = {lat:0,lng:0}; map.zoom = 0;
      map.fire('moveend');
      map.fire('load');
      L.polygon([[0,160],[50,150],[30,100]], {pane:'polygons'}).addTo(map);
      state.geometryReady();
      state.resize();
      assert.equal(state.initialFitPending, false);
      const expected = ee.boundsView(ee.polygonBounds(map,L),element.clientWidth,element.clientHeight);
      assert.deepEqual(state.view,expected);
    } finally { state.destroy(); }
  });
});

test("o pane temático de Indicadores é explícito e não inclui os demais panes", () => {
  const scene = leafletScene();
  const { L, map, element } = scene;
  L.polygon([[-90, -180], [0, 180], [90, -180]], { pane: "base" }).addTo(map);
  L.polygon([[0, 0], [70, 150], [-30, 150]], { pane: "overlayPane" }).addTo(map);
  assert.equal(ee.polygonBounds(map, L), null);
  scene.withGlobals(() => {
    const state = ee.attach(element, map, { polygonPane: "overlayPane" });
    try {
      assert.equal(state.initialFitPending, false);
      assert.deepEqual(state.view,
        ee.boundsView(ee.polygonBounds(map, L, "overlayPane"), element.clientWidth, element.clientHeight));
    } finally { state.destroy(); }
  });
});

test("enquadramento dos polígonos centraliza a caixa projetada e encosta no eixo limitante sem margem", () => {
  const bounds = { min: { x: -1.6, y: -1.1 }, max: { x: 2.4, y: 0.8 } };
  [[1440, 700], [768, 500], [390, 420], [280, 330]].forEach(([width, height]) => {
    const view = ee.boundsView(bounds, width, height);
    const center = ee.forward(view.center.lng, view.center.lat);
    close(center.x, 0.4);
    close(center.y, -0.15);
    const scale = 256 * 2 ** view.zoom / (2 * ee.extent.x);
    const spanX = (bounds.max.x - bounds.min.x) * scale;
    const spanY = (bounds.max.y - bounds.min.y) * scale;
    assert.ok(spanX <= width + 1e-8 && spanY <= height + 1e-8);
    assert.ok(Math.abs(spanX - width) < 1e-8 || Math.abs(spanY - height) < 1e-8);
  });
  assert.equal(ee.boundsView(null, 1000, 600), null);
  assert.equal(ee.boundsView(bounds, 0, 600), null);
});

test("primeiro fit espera os países; Mundo recalcula os visíveis; filtros e resize preservam a navegação", () => {
  const scene = leafletScene();
  const { L, map, element } = scene;
  L.polygon([[-30, -30], [40, -30], [40, 30]], { pane: "base" }).addTo(map);
  scene.withGlobals(() => {
    const state = ee.attach(element, map, { waitForGeometry: true });
    try {
      assert.equal(state.initialFitPending, true);
      assert.equal(map.zoom, 0, "a terra inicial não libera o enquadramento antes dos países");
      state.geometryReady();
      assert.equal(state.fitWorld(), false,
        "Mundo não usa o fundo enquanto as geometrias temáticas ainda não chegaram");
      assert.equal(state.initialFitPending, true,
        "uma atualização sem geometrias mantém o primeiro enquadramento pendente");
      map.fire("moveend"); // invalidateSize pode concluir depois do callback inicial.
      assert.equal(state.initialFitPending, true);
      const country = L.polygon([[0, 160], [50, 150], [30, 100]], { pane: "polygons" }).addTo(map);
      state.geometryReady();
      const initial = ee.boundsView(ee.polygonBounds(map, L), element.clientWidth, element.clientHeight);
      assert.deepEqual(state.view, initial);
      assert.equal(state.initialFitPending, false);
      assert.equal(map.controls[0].options.position, "bottomright");
      map.setView({ lat: 12, lng: 28 }, 3.25);
      map.removeLayer(country);
      L.polygon([[-60, -150], [60, -150], [20, 10]], { pane: "polygons" }).addTo(map);
      state.geometryReady();
      assert.deepEqual(map.center, { lat: 12, lng: 28 });
      assert.equal(map.zoom, 3.25);
      element.clientWidth = 650;
      element.clientHeight = 420;
      state.resize();
      assert.deepEqual(map.center, { lat: 12, lng: 28 });
      assert.equal(map.zoom, 3.25);
      map.controls[0].container.children[0].listeners.click();
      const expected = ee.boundsView(ee.polygonBounds(map, L), 650, 420);
      assert.deepEqual(state.view, expected);
      assert.notDeepEqual(expected, initial);
    } finally { state.destroy(); }
    assert.equal(map.controls.length, 0);
    assert.ok([...map.listeners.values()].every(callbacks => callbacks.size === 0));
  });
});

test("navegar antes das geometrias chegarem cancela o fit automático; mapa inicialmente oculto espera dimensões", () => {
  const scene = leafletScene();
  scene.withGlobals(() => {
    const state = ee.attach(scene.element, scene.map, { waitForGeometry: true });
    try {
      scene.map.setView({ lat: 35, lng: 70 }, 4);
      scene.L.polygon([[0, 0], [70, 150], [-30, 150]], { pane: "polygons" }).addTo(scene.map);
      state.geometryReady();
      assert.deepEqual(scene.map.center, { lat: 35, lng: 70 });
      assert.equal(scene.map.zoom, 4);
    } finally { state.destroy(); }
  });
  const hidden = leafletScene(0, 0);
  hidden.L.polygon([[0, 0], [70, 150], [-30, 150]], { pane: "polygons" }).addTo(hidden.map);
  hidden.withGlobals(() => {
    const state = ee.attach(hidden.element, hidden.map);
    try {
      assert.equal(state.initialFitPending, true);
      hidden.element.clientWidth = 900;
      hidden.element.clientHeight = 500;
      state.resize();
      assert.deepEqual(state.view, ee.boundsView(ee.polygonBounds(hidden.map, hidden.L), 900, 500));
      assert.equal(state.initialFitPending, false);
    } finally { state.destroy(); }
  });
});
