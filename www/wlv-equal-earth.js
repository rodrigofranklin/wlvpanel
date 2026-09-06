/* Equal Earth esférica, meridiano central 0°. Sem tiles ou dependências de rede.
 * Fórmulas: Šavrič, Patterson e Jenny (2018), DOI 10.1080/13658816.2018.1504949.
 * Referência matemática: https://proj.org/en/stable/operations/projections/eqearth.html
 * Implementação local das equações publicadas; não representa EPSG:8857 (elipsoidal).
 * O ciclo de vida de BoxZoom adapta Leaflet 1.x (BSD-2-Clause):
 * Copyright (c) 2010-2017, Vladimir Agafonkin; (c) 2010-2011, CloudMade.
 * Aviso completo em wlv-equal-earth.LICENSE.md.
 */
(function (root) {
  "use strict";

  const A1 = 1.340264, A2 = -0.081106, A3 = 0.000893, A4 = 0.003796;
  const M = Math.sqrt(3) / 2, DEG = Math.PI / 180;
  const clamp = (value, low, high) => Math.min(high, Math.max(low, value));
  const states = new WeakMap();
  const prepared = new WeakSet();

  function polynomial(theta) {
    const t2 = theta * theta, t6 = t2 * t2 * t2;
    return {
      y: theta * (A1 + A2 * t2 + t6 * (A3 + A4 * t2)),
      derivative: A1 + 3 * A2 * t2 + t6 * (7 * A3 + 9 * A4 * t2)
    };
  }

  // Entradas em graus; saída em unidades de uma esfera de raio 1.
  function forward(lng, lat) {
    const theta = Math.asin(M * Math.sin(clamp(lat, -90, 90) * DEG));
    const p = polynomial(theta);
    return { x: lng * DEG * Math.cos(theta) / (M * p.derivative), y: p.y };
  }

  const X = forward(180, 0).x, Y = forward(0, 90).y;

  function inverse(x, y) {
    // Leaflet também inverte posições fora do contorno durante pan/zoom.
    // Limitar y evita NaN nos polos, sem fazer wrap de longitude na borda.
    const target = clamp(y, -Y, Y);
    let theta = target;
    for (let iteration = 0; iteration < 12; iteration += 1) {
      const p = polynomial(theta);
      const step = (p.y - target) / p.derivative;
      theta -= step;
      if (Math.abs(step) < 1e-12) break;
    }
    return {
      lng: x * M * polynomial(theta).derivative / Math.cos(theta) / DEG,
      lat: Math.asin(clamp(Math.sin(theta) / M, -1, 1)) / DEG
    };
  }

  function install(L) {
    if (L.CRS.WLVEqualEarth) return L.CRS.WLVEqualEarth;
    const factor = 1 / (2 * X);
    L.CRS.WLVEqualEarth = L.extend({}, L.CRS.Earth, {
      code: "WLV:EqualEarthSphere",
      projection: {
        project: function (latlng) {
          const p = forward(latlng.lng, latlng.lat);
          return L.point(p.x, p.y);
        },
        unproject: function (point) {
          const p = inverse(point.x, point.y);
          return L.latLng(p.lat, p.lng);
        },
        bounds: L.bounds([-X, -Y], [X, Y])
      },
      // A mesma escala nos dois eixos é necessária para preservar áreas.
      // A largura máxima ocorre NO EQUADOR, não nos cantos ±180°/±90°.
      transformation: new L.Transformation(factor, 0.5, -factor, Y * factor),
      wrapLng: undefined,
      wrapLat: undefined,
      infinite: false
    });
    return L.CRS.WLVEqualEarth;
  }

  function fitZoom(width, height, padding) {
    const gap = padding === undefined ? 16 : padding;
    return Math.log2(Math.max(1, Math.min(width - 2 * gap,
      (height - 2 * gap) * X / Y)) / 256);
  }

  function boxView(map, start, end) {
    const viewport = map.getSize();
    const scale = Math.min(viewport.x / Math.max(1, Math.abs(end.x - start.x)),
      viewport.y / Math.max(1, Math.abs(end.y - start.y)));
    const zoom = clamp(map.getScaleZoom(scale, map.getZoom()), map.getMinZoom(), map.getMaxZoom());
    return { center: map.containerPointToLatLng([(start.x + end.x) / 2, (start.y + end.y) / 2]), zoom: zoom };
  }

  function prepareBoxZoom(map, L) {
    if (!map.boxZoom) return function () {};
    const handler = map.boxZoom, original = handler._onMouseUp;
    // Leaflet 1.x encerra Shift+arrastar com fitBounds geográfico, cujo centro
    // é incorreto em projeções pseudocilíndricas. Especializar só esta instância
    // preserva os hooks de teclado, retângulo, cancelamento e clique nativos.
    handler._onMouseUp = function (event) {
      if (event.which !== 1 && event.button !== 1) return;
      this._finish();
      if (!this._moved) return;
      this._clearDeferredResetState();
      this._resetStateTimeout = root.setTimeout(() => this._resetState(), 0);
      const view = boxView(map, this._startPoint, this._point);
      const bounds = L.latLngBounds(map.containerPointToLatLng(this._startPoint),
        map.containerPointToLatLng(this._point));
      map.setView(view.center, view.zoom, { animate: false });
      map.fire("boxzoomend", { boxZoomBounds: bounds });
    };
    return function () { handler._onMouseUp = original; };
  }

  // Interpolar segmentos da base evita transformar meridianos curvos em
  // cordas. As bases locais já estão cortadas no antimeridiano. Em particular,
  // -180° -> +180° no polo sul fecha a Antártida: não deve receber wrap.
  function densify(latlngs, makeLatLng) {
    if (!latlngs.length) return latlngs;
    if (typeof latlngs[0].lat !== "number") {
      return latlngs.map(part => densify(part, makeLatLng));
    }
    const result = [];
    latlngs.forEach(function (point, index) {
      result.push(point);
      const next = latlngs[(index + 1) % latlngs.length];
      const span = Math.max(Math.abs(next.lat - point.lat), Math.abs(next.lng - point.lng));
      const count = Math.ceil(span / 2);
      for (let step = 1; step < count; step += 1) {
        const fraction = step / count;
        result.push(makeLatLng(point.lat + fraction * (next.lat - point.lat),
          point.lng + fraction * (next.lng - point.lng)));
      }
    });
    return result;
  }

  function prepareLayer(layer, L) {
    if (!layer || prepared.has(layer)) return;
    prepared.add(layer);
    // FeatureGroup recursivo: não troca objetos, ids, eventos ou tooltips.
    if (layer.eachLayer) layer.eachLayer(child => prepareLayer(child, L));
    if (layer instanceof L.Polygon && layer.getLatLngs && layer.setLatLngs) {
      layer.setLatLngs(densify(layer.getLatLngs(), L.latLng));
    }
  }

  function backdrop(map, L) {
    const oceanPane = map.createPane("wlv-equal-earth-ocean");
    oceanPane.style.zIndex = 2;
    oceanPane.style.pointerEvents = "none";
    const gridPane = map.createPane("wlv-equal-earth-grid");
    gridPane.style.zIndex = 3;
    gridPane.style.pointerEvents = "none";
    const edge = [];
    for (let lat = -90; lat <= 90; lat += 2) edge.push([lat, -180]);
    for (let lng = -178; lng <= 180; lng += 2) edge.push([90, lng]);
    for (let lat = 88; lat >= -90; lat -= 2) edge.push([lat, 180]);
    for (let lng = 178; lng >= -180; lng -= 2) edge.push([-90, lng]);
    const ocean = L.polygon(edge, { pane: "wlv-equal-earth-ocean", interactive: false,
      color: "#9ebbbd", weight: 0.8, fillColor: "#deecec", fillOpacity: 1,
      smoothFactor: 0.2 });
    prepared.add(ocean);
    ocean.addTo(map);
    const grid = [];
    for (let lng = -150; lng <= 150; lng += 30) {
      const line = [];
      for (let lat = -90; lat <= 90; lat += 2) line.push([lat, lng]);
      grid.push(line);
    }
    for (let lat = -60; lat <= 60; lat += 30) {
      const line = [];
      for (let lng = -180; lng <= 180; lng += 2) line.push([lat, lng]);
      grid.push(line);
    }
    const graticule = L.polyline(grid, { pane: "wlv-equal-earth-grid", interactive: false,
      color: "#b8cece", weight: 0.65, opacity: 0.65, smoothFactor: 0.2 }).addTo(map);
    return [ocean, graticule];
  }

  function attach(element, map) {
    const L = root.L;
    if (!L || !map.options || map.options.crs !== L.CRS.WLVEqualEarth) return null;
    if (states.has(map)) return states.get(map);
    const state = { worldView: true, fitting: false, width: 0, height: 0 };
    states.set(map, state);
    element.setAttribute("data-wlv-projection", "Equal Earth");
    element.setAttribute("role", "region");
    const onLayerAdd = event => prepareLayer(event.layer, L);
    map.on("layeradd", onLayerAdd);
    map.eachLayer(layer => prepareLayer(layer, L));
    state.backdrop = backdrop(map, L);
    const restoreBoxZoom = prepareBoxZoom(map, L);

    state.fitWorld = function () {
      if (!element.clientWidth || !element.clientHeight) return;
      state.fitting = true;
      state.worldZoom = fitZoom(element.clientWidth, element.clientHeight);
      map.setView([0, 0], state.worldZoom, { animate: false, reset: true });
      state.worldView = true;
      state.view = { center: { lat: 0, lng: 0 }, zoom: state.worldZoom };
      state.fitting = false;
    };

    // Navegação livre: registrar a vista sem corrigir o pan ou o zoom.
    const onMoveEnd = function () {
      if (state.fitting) return;
      // O binding htmlwidgets chama invalidateSize antes do ResizeObserver.
      // Não registrar o pan arredondado dessa etapa como navegação do usuário.
      if (element.clientWidth !== state.width || element.clientHeight !== state.height) return;
      const zoom = map.getZoom();
      const position = map.getCenter();
      state.view = { center: { lat: position.lat, lng: position.lng }, zoom: zoom };
    };
    map.on("moveend", onMoveEnd);

    const control = L.control({ position: "topleft" });
    let button;
    control.onAdd = function () {
      const container = L.DomUtil.create("div", "leaflet-bar wlv-map-world-control");
      button = L.DomUtil.create("button", "wlv-map-world", container);
      button.type = "button";
      L.DomEvent.disableClickPropagation(container);
      L.DomEvent.disableScrollPropagation(container);
      button.addEventListener("click", state.fitWorld);
      return container;
    };
    control.addTo(map);

    const translate = function () {
      const english = root.document.documentElement.lang === "en";
      button.textContent = english ? "World" : "Mundo";
      button.title = english ? "Show the whole world" : "Mostrar o mundo inteiro";
      button.setAttribute("aria-label", button.title);
      element.setAttribute("aria-label", english ?
        "World map in Equal Earth. Use arrow keys to pan and plus or minus to zoom. Country profiles are in the Country module." :
        "Mapa-múndi em Equal Earth. Use as setas para mover e mais ou menos para ampliar. Os perfis dos países estão no módulo País.");
      const labels = english ? ["Zoom in", "Zoom out"] : ["Ampliar", "Reduzir"];
      [".leaflet-control-zoom-in", ".leaflet-control-zoom-out"].forEach(function (selector, index) {
        const link = element.querySelector(selector);
        if (link) { link.title = labels[index]; link.setAttribute("aria-label", labels[index]); }
      });
    };
    translate();
    if (root.MutationObserver) {
      state.languageObserver = new root.MutationObserver(translate);
      state.languageObserver.observe(root.document.documentElement, { attributes: true, attributeFilter: ["lang"] });
    }
    state.resize = function () {
      const width = element.clientWidth, height = element.clientHeight;
      if (!width || !height || (width === state.width && height === state.height)) return;
      state.width = width;
      state.height = height;
      const firstView = !state.view;
      const center = state.view ? state.view.center : map.getCenter();
      const zoom = state.view ? state.view.zoom : map.getZoom();
      state.fitting = true;
      map.invalidateSize({ pan: false, debounceMoveend: true });
      // Uma mudança de idioma/tamanho preserva a vista aproximada do usuário.
      state.worldZoom = fitZoom(width, height);
      if (firstView) state.fitWorld();
      else {
        // No mesmo zoom, setView pode escolher panBy, que arredonda pixels e
        // acumula deslocamento a cada resize. reset preserva o centro exato.
        map.setView(center, zoom, { animate: false, reset: true });
      }
      state.fitting = false;
    };
    state.destroy = function () {
      if (state.destroyed) return;
      state.destroyed = true;
      if (state.languageObserver) state.languageObserver.disconnect();
      restoreBoxZoom();
      map.off("layeradd", onLayerAdd);
      map.off("moveend", onMoveEnd);
      map.off("unload", state.destroy);
      map.removeControl(control);
      state.backdrop.forEach(layer => { if (map.hasLayer(layer)) map.removeLayer(layer); });
      states.delete(map);
    };
    map.on("unload", state.destroy);
    state.resize();
    return state;
  }

  const api = { install: install, attach: attach, forward: forward, inverse: inverse,
    fitZoom: fitZoom, boxView: boxView, densify: densify, extent: { x: X, y: Y },
    fitWorld: function (map) { if (states.has(map)) states.get(map).fitWorld(); } };
  root.WLVEqualEarth = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
})(typeof window !== "undefined" ? window : globalThis);
