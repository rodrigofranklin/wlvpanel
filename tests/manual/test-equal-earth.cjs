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
