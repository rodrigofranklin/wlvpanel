(function (root) {
  "use strict";
  const maps = new Map(), latest = new Map(), pending = new Map(), selections = new Map(), flowMessages = new Map();
  const frames = new Set();
  const nextFrame = root.requestAnimationFrame ? root.requestAnimationFrame.bind(root) : callback => root.setTimeout(callback, 0);
  let registered = false, instance = 0;
  root.wlvTradeMaps = root.wlvTradeMaps || {};

  // Curves are made in the current Equal Earth map plane. Interpolating longitude
  // or wrapping a point by 360 degrees would connect the wrong displayed shapes.
  function curveGeometry(start, end, width, id) {
    if (!start || !end || ![start.x, start.y, end.x, end.y, width].every(Number.isFinite) || width <= 0) return null;
    const dx = end.x - start.x, dy = end.y - start.y, distance = Math.hypot(dx, dy);
    if (distance < 1) return null;
    let hash = 0;
    String(id || "").split("").forEach(character => { hash = (hash * 31 + character.charCodeAt(0)) | 0; });
    const bend = Math.min(90, distance * 0.18) * (hash % 2 ? -1 : 1);
    const control = {x: (start.x + end.x) / 2 - dy / distance * bend, y: (start.y + end.y) / 2 + dx / distance * bend};
    const tangentLength = Math.hypot(end.x - control.x, end.y - control.y);
    const tx = (end.x - control.x) / tangentLength, ty = (end.y - control.y) / tangentLength;
    // Only the shaft width represents magnitude; the small arrowhead denotes direction.
    const headLength = Math.min(distance * 0.35, Math.max(4, Math.min(26, width * 2.4)));
    const headHalf = Math.min(headLength * 0.5, Math.max(2, width * 0.8));
    const base = {x: end.x - tx * headLength, y: end.y - ty * headLength};
    const number = value => Math.round(value * 1000) / 1000;
    const point = value => number(value.x) + "," + number(value.y);
    return {
      shaft: "M" + point(start) + " Q" + point(control) + " " + point(base),
      head: "M" + point(end) + " L" + point({x: base.x - ty * headHalf, y: base.y + tx * headHalf}) +
        " L" + point({x: base.x + ty * headHalf, y: base.y - tx * headHalf}) + " Z",
      control: control, end: {x: end.x, y: end.y},
      middle: {x: (start.x + 2 * control.x + end.x) / 4, y: (start.y + 2 * control.y + end.y) / 4}
    };
  }

  function normalizeFlows(specification) {
    if (!specification || specification.enabled !== true) return {enabled: false, rows: []};
    const rows = Array.isArray(specification.rows) ? specification.rows :
      specification.rows && typeof specification.rows === "object" ? Object.values(specification.rows) : [];
    const valid = rows.filter(function (flow) {
      return flow && flow.id != null && flow.from && flow.to && flow.from !== flow.to &&
        !["ROW", "WWW"].includes(flow.from) && !["ROW", "WWW"].includes(flow.to) &&
        [flow.from_lat, flow.from_lng, flow.to_lat, flow.to_lng, flow.width, flow.amount, flow.value].every(Number.isFinite) &&
        Math.abs(flow.from_lat) <= 90 && Math.abs(flow.to_lat) <= 90 &&
        Math.abs(flow.from_lng) <= 180 && Math.abs(flow.to_lng) <= 180 && flow.width > 0 && flow.amount > 0 && Math.abs(flow.value) === flow.amount;
    });
    return {enabled: true, rows: valid, interactive: specification.interactive !== false,
      legend: specification.legend == null ? null : String(specification.legend)};
  }

  function closeFlowTooltip(state) {
    const record = state.flowTooltip && state.tooltips.get(state.flowTooltip);
    if (record) {
      if (state.flowTooltip._setPosition === record.position) state.flowTooltip._setPosition = record.original;
      state.tooltips.delete(state.flowTooltip);
    }
    if (state.flowTooltip && typeof state.map.removeLayer === "function") state.map.removeLayer(state.flowTooltip);
    state.flowTooltip = null;
  }

  function openFlowTooltip(state, flow, event, middle) {
    if (!root.L || typeof root.L.tooltip !== "function") return;
    let latlng;
    if (event && typeof state.map.mouseEventToLatLng === "function") latlng = state.map.mouseEventToLatLng(event);
    else if (typeof state.map.layerPointToLatLng === "function") latlng = state.map.layerPointToLatLng([middle.x, middle.y]);
    if (!latlng) return;
    if (!state.flowTooltip) {
      state.flowTooltip = root.L.tooltip({direction: "auto", className: "wlv-trade-tooltip", opacity: 0.98});
      state.flowTooltip.setContent(flow.label == null ? String(flow.from) + " → " + String(flow.to) + ": " + flow.amount : String(flow.label));
      state.flowTooltip.setLatLng(latlng).addTo(state.map);
      prepareTooltip(state, state.flowTooltip);
    } else state.flowTooltip.setLatLng(latlng);
  }

  function selectFlow(state, flow, event) {
    if (event && typeof event.preventDefault === "function") event.preventDefault();
    if (event && typeof event.stopPropagation === "function") event.stopPropagation();
    if (root.Shiny && typeof root.Shiny.setInputValue === "function")
      root.Shiny.setInputValue(state.element.id + "_shape_click", {id: String(flow.id), source: "trade-flow"}, {priority: "event"});
  }

  function flowOverlay(state) {
    if (state.flowSvg) return state.flowSvg;
    const document = root.document, map = state.map;
    if (!document || typeof document.createElementNS !== "function" || typeof map.getPanes !== "function" ||
        typeof map.getSize !== "function" || typeof map.latLngToLayerPoint !== "function") return null;
    let pane = typeof map.getPane === "function" ? map.getPane("wlv-trade-flows") : null;
    if (!pane && typeof map.createPane === "function") pane = map.createPane("wlv-trade-flows");
    if (pane) { pane.style.zIndex = "450"; pane.style.pointerEvents = "none"; }
    else pane = map.getPanes().overlayPane;
    if (!pane || typeof pane.appendChild !== "function") return null;
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("class", "wlv-trade-flow-overlay");
    svg.setAttribute("role", "group");
    Object.assign(svg.style, {position: "absolute", pointerEvents: "none", overflow: "hidden"});
    pane.appendChild(svg); state.flowSvg = svg;
    return svg;
  }

  function drawFlows(state) {
    const specification = flowMessages.get(state.element.id) || {enabled: false, rows: []};
    if (!specification.enabled && !state.flowSvg) { state.flowCount = 0; return; }
    const svg = flowOverlay(state);
    if (!svg) return;
    closeFlowTooltip(state);
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    state.flowCount = 0;
    svg.style.display = specification.enabled && specification.rows.length ? "block" : "none";
    if (!specification.enabled || !specification.rows.length) return;
    const map = state.map, size = map.getSize();
    if (!size || size.x <= 0 || size.y <= 0) return;
    const origin = typeof map.containerPointToLayerPoint === "function" ? map.containerPointToLayerPoint([0, 0]) : {x: 0, y: 0};
    svg.style.left = origin.x + "px"; svg.style.top = origin.y + "px";
    svg.setAttribute("width", size.x); svg.setAttribute("height", size.y);
    svg.setAttribute("viewBox", "0 0 " + size.x + " " + size.y);
    svg.setAttribute("aria-label", specification.legend || (language() === "en" ? "Net value transfers; arrow direction shows who receives value." : "Transferências líquidas de valor; a direção da seta indica quem recebe valor."));
    const node = tag => root.document.createElementNS("http://www.w3.org/2000/svg", tag);
    specification.rows.forEach(function (flow) {
      const source = map.latLngToLayerPoint([flow.from_lat, flow.from_lng]);
      const target = map.latLngToLayerPoint([flow.to_lat, flow.to_lng]);
      const geometry = curveGeometry({x: source.x - origin.x, y: source.y - origin.y},
        {x: target.x - origin.x, y: target.y - origin.y}, flow.width, flow.id);
      if (!geometry) return;
      const group = node("g"), shaft = node("path"), head = node("path");
      const color = typeof flow.color === "string" ? flow.color : flow.value > 0 ? "#b37b15" : "#8D2028";
      const description = flow.aria_label || (flow.label == null ? flow.from + " → " + flow.to + ": " + flow.amount : String(flow.label).replace(/<[^>]*>/g, " ").replace(/\s+/g, " ").trim());
      group.setAttribute("class", "wlv-trade-flow"); group.setAttribute("data-partner", flow.id);
      group.setAttribute("data-from", flow.from); group.setAttribute("data-to", flow.to);
      group.setAttribute("data-amount", flow.amount); group.setAttribute("data-width", flow.width);
      group.setAttribute("aria-label", description);
      shaft.setAttribute("class", "wlv-trade-flow-line"); shaft.setAttribute("d", geometry.shaft);
      shaft.setAttribute("fill", "none"); shaft.setAttribute("stroke", color);
      shaft.setAttribute("stroke-width", flow.width); shaft.setAttribute("stroke-opacity", "0.85");
      shaft.setAttribute("vector-effect", "non-scaling-stroke");
      head.setAttribute("class", "wlv-trade-flow-head"); head.setAttribute("d", geometry.head);
      head.setAttribute("fill", color); head.setAttribute("fill-opacity", "0.95"); head.style.pointerEvents = "none";
      if (specification.interactive) {
        group.setAttribute("role", "button"); group.setAttribute("tabindex", "0");
        shaft.style.pointerEvents = "stroke"; shaft.style.cursor = "pointer";
        const middle = {x: geometry.middle.x + origin.x, y: geometry.middle.y + origin.y};
        group.addEventListener("pointerenter", event => openFlowTooltip(state, flow, event, middle));
        group.addEventListener("pointermove", event => openFlowTooltip(state, flow, event, middle));
        group.addEventListener("pointerleave", () => closeFlowTooltip(state));
        group.addEventListener("focus", () => openFlowTooltip(state, flow, null, middle));
        group.addEventListener("blur", () => closeFlowTooltip(state));
        group.addEventListener("click", event => selectFlow(state, flow, event));
        group.addEventListener("keydown", event => { if (event.key === "Enter" || event.key === " ") selectFlow(state, flow, event); });
      }
      group.appendChild(shaft); group.appendChild(head); svg.appendChild(group); state.flowCount += 1;
    });
  }

  function flush(id) {
    const state = maps.get(id), countries = pending.get(id);
    if (!state || !state.active) return;
    drawFlows(state);
    if (!countries) return;
    const manager = state.map.layerManager;
    if (!manager || typeof manager.getLayer !== "function") return;
    const remaining = {};
    Object.keys(countries).forEach(function (code) {
      const value = countries[code], layer = manager.getLayer("shape", code);
      if (!value || !layer || typeof layer.setStyle !== "function") { remaining[code] = value; return; }
      layer.setStyle({fillColor: value.color, fillOpacity: value.missing ? 0.25 : 0.8});
      const label = value.label == null ? code : String(value.label);
      if (typeof layer.getTooltip === "function" && layer.getTooltip() && typeof layer.setTooltipContent === "function") layer.setTooltipContent(label);
      else if (typeof layer.bindTooltip === "function") layer.bindTooltip(label, {sticky: true, direction: "auto", className: "wlv-trade-tooltip"});
    });
    if (Object.keys(remaining).length) pending.set(id, remaining);
    else {
      pending.delete(id);
      if (state.projection && state.projection.geometryReady) state.projection.geometryReady();
    }
  }

  function schedule(id) {
    if (frames.has(id)) return;
    frames.add(id);
    nextFrame(function () { frames.delete(id); flush(id); });
  }

  function receive(message) {
    if (!message || !message.id) return;
    if (message.countries && typeof message.countries === "object") {
      latest.set(message.id, message.countries);
      pending.set(message.id, message.countries);
    }
    flowMessages.set(message.id, normalizeFlows(message.flows));
    schedule(message.id);
  }

  function language() { return root.document && root.document.documentElement.lang === "en" ? "en" : "pt"; }

  function applyState(id) {
    const selection = selections.get(id);
    const app = root.document && root.document.getElementById(id);
    if (!selection || !app) return;
    app.dataset.ready = "true";
    if (selection.lang) app.dataset.tradeLang = selection.lang;
    if (!app.dataset.tradeFiltersInitialized) {
      if (root.matchMedia && root.matchMedia("(max-width: 767px)").matches) {
        app.querySelectorAll(".wlv-trade-controls details.wlv-trade-filter-group").forEach(function (details) { details.open = false; });
      }
      app.dataset.tradeFiltersInitialized = "true";
    }
  }

  function receiveState(message) {
    if (!message || !message.id || !message.state || typeof message.state !== "object") return;
    selections.set(message.id, {state: Object.assign({}, message.state), lang: message.lang || language()});
    applyState(message.id);
  }

  function announce(state) {
    if (state.announced || !state.active || !root.Shiny || typeof root.Shiny.setInputValue !== "function") return;
    state.announced = true;
    root.Shiny.setInputValue(state.element.id + "_ready", ++instance, {priority: "event"});
  }

  function register() {
    if (!registered && root.Shiny && typeof root.Shiny.addCustomMessageHandler === "function") {
      root.Shiny.addCustomMessageHandler("wlvTradeMap", receive);
      root.Shiny.addCustomMessageHandler("wlvTradeState", receiveState);
      registered = true;
    }
    if (registered) maps.forEach(announce);
    selections.forEach(function (_, id) { applyState(id); });
  }

  function prepareTooltip(state, tooltip) {
    if (!tooltip || state.tooltips.has(tooltip) || !root.L || typeof tooltip._setPosition !== "function") return;
    const original = tooltip._setPosition;
    const position = function (point) {
      const node = this.getElement();
      if (!node) return original.call(this, point);
      node.style.maxWidth = Math.max(1, Math.min(300, state.element.clientWidth - 16)) + "px";
      node.style.boxSizing = "border-box";
      node.style.transitionProperty = "none";
      original.call(this, point);
      const viewport = state.element.getBoundingClientRect(), bounds = node.getBoundingClientRect();
      const left = Math.max(viewport.left + 8, Math.min(bounds.left, viewport.right - 8 - bounds.width));
      const top = Math.max(viewport.top + 8, Math.min(bounds.top, viewport.bottom - 8 - bounds.height));
      const dx = left - bounds.left, dy = top - bounds.top;
      if (dx || dy) {
        const current = root.L.DomUtil.getPosition(node);
        root.L.DomUtil.setPosition(node, root.L.point(current.x + dx, current.y + dy));
      }
    };
    state.tooltips.set(tooltip, {original: original, position: position});
    tooltip._setPosition = position;
    if (typeof tooltip.update === "function") tooltip.update();
  }

  function attach(element, map) {
    if (!element || !element.id || !map) return null;
    register();
    const previous = maps.get(element.id);
    if (previous && previous.active && previous.map === map && previous.element === element) { schedule(element.id); return previous; }
    if (previous) previous.destroy();
    const state = {map: map, element: element, active: true, announced: false, tooltips: new Map()};
    state.projection = root.WLVEqualEarth ? root.WLVEqualEarth.attach(element, map,
      {polygonPane: "wlv-trade-polygons", waitForGeometry: true}) : null;
    state.translate = function () {
      if (!element.setAttribute) return;
      element.setAttribute("aria-label", language() === "en" ?
        "Trade partner map in Equal Earth. Use arrow keys to pan and plus or minus to zoom. Click a country to select a partner." :
        "Mapa de parceiros comerciais em Equal Earth. Use as setas para mover e mais ou menos para ampliar. Clique em um país para selecionar um parceiro.");
    };
    state.translate();
    if (root.MutationObserver && root.document) {
      state.languageObserver = new root.MutationObserver(state.translate);
      state.languageObserver.observe(root.document.documentElement, {attributes: true, attributeFilter: ["lang"]});
    }
    state.onResize = function () {
      if (!state.active) return;
      if (state.projection && state.projection.resize) state.projection.resize();
      else if (typeof map.invalidateSize === "function") map.invalidateSize({pan: false});
      schedule(element.id);
    };
    if (root.ResizeObserver) {
      state.resizeObserver = new root.ResizeObserver(state.onResize);
      state.resizeObserver.observe(element);
    } else if (root.addEventListener) root.addEventListener("resize", state.onResize);
    state.onLayerAdd = function () { if (pending.has(element.id)) schedule(element.id); };
    state.onReady = function () { schedule(element.id); announce(state); };
    state.onFlowMove = function () { schedule(element.id); };
    state.onTooltipOpen = function (event) { prepareTooltip(state, event.tooltip); };
    state.destroy = function () {
      if (!state.active) return;
      state.active = false;
      if (state.languageObserver) state.languageObserver.disconnect();
      if (state.resizeObserver) state.resizeObserver.disconnect();
      else if (root.removeEventListener) root.removeEventListener("resize", state.onResize);
      map.off("layeradd", state.onLayerAdd);
      map.off("load", state.onReady);
      map.off("unload", state.destroy);
      map.off("tooltipopen", state.onTooltipOpen);
      map.off("move zoom viewreset resize", state.onFlowMove);
      closeFlowTooltip(state);
      if (state.flowSvg && state.flowSvg.parentNode) state.flowSvg.parentNode.removeChild(state.flowSvg);
      state.flowSvg = null; state.flowCount = 0;
      state.tooltips.forEach(function (record, tooltip) {
        if (tooltip._setPosition === record.position) tooltip._setPosition = record.original;
      });
      state.tooltips.clear();
      if (state.projection && state.projection.destroy) state.projection.destroy();
      if (root.wlvTradeMaps[element.id] === map) delete root.wlvTradeMaps[element.id];
    };
    maps.set(element.id, state);
    root.wlvTradeMaps[element.id] = map;
    map.on("layeradd", state.onLayerAdd);
    map.on("load", state.onReady);
    map.on("unload", state.destroy);
    map.on("tooltipopen", state.onTooltipOpen);
    map.on("move zoom viewreset resize", state.onFlowMove);
    if (latest.has(element.id)) pending.set(element.id, latest.get(element.id));
    schedule(element.id);
    announce(state);
    return state;
  }

  function shareUrl(id, href) {
    const url = new URL(href || root.location.href);
    Array.from(url.searchParams.keys()).forEach(function (key) { if (key.indexOf("trade_") === 0) url.searchParams.delete(key); });
    const selection = selections.get(id);
    if (selection) Object.keys(selection.state).forEach(function (key) {
      const value = selection.state[key];
      if (/^[a-z][a-z0-9_]*$/i.test(key) && value != null && ["string", "number", "boolean"].includes(typeof value)) {
        url.searchParams.set("trade_" + key, String(value));
      }
    });
    url.searchParams.set("trade_open", "1");
    return url.toString();
  }

  const api = {attach: attach, receive: receive, receiveState: receiveState, flush: flush, shareUrl: shareUrl,
    curveGeometry: curveGeometry,
    flows: id => maps.has(id) ? {count: maps.get(id).flowCount || 0, active: maps.get(id).active} : {count: 0, active: false},
    pending: id => pending.has(id) ? Object.keys(pending.get(id)) : [],
    state: id => selections.has(id) ? Object.assign({}, selections.get(id).state) : null};
  root.WLVTrade = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  register();
  if (root.document) {
    root.document.addEventListener("DOMContentLoaded", register, {once: true});
    root.document.addEventListener("shiny:connected", register);
    if (root.jQuery) root.jQuery(root.document).on("shiny:connected.wlvTrade", register);
  }
})(typeof window !== "undefined" ? window : globalThis);
