/* Keep the latest indicator values until Leaflet has registered its shapes. */
(function (root) {
  "use strict";
  const states = new Map();
  const latest = new Map();
  const pending = new Map();
  const frames = new Set();
  const nextFrame = root.requestAnimationFrame ? root.requestAnimationFrame.bind(root) :
    callback => root.setTimeout(callback, 0);
  let registered = false;
  let instance = 0;
  root.wlvIndicatorMaps = root.wlvIndicatorMaps || {};

  function flush(id) {
    const state = states.get(id);
    const countries = pending.get(id);
    if (!state || !countries || !state.active) return;
    const manager = state.map.layerManager;
    // Leaflet's onRender and proxy messages can precede its layer manager on
    // a newly revealed widget. Retain everything for attach/layeradd/ready.
    if (!manager || typeof manager.getLayer !== "function") return;
    const remaining = {};
    Object.keys(countries).forEach(function (code) {
      const layer = manager.getLayer("shape", code);
      const value = countries[code];
      if (!layer || typeof layer.setStyle !== "function") {
        remaining[code] = value;
        return;
      }
      layer.setStyle({fillColor: value.color, fillOpacity: value.missing ? 0.25 : 0.8});
      if (layer.getTooltip()) layer.setTooltipContent(value.label);
      else layer.bindTooltip(value.label, {sticky: true, direction: "auto", className: "wlv-indicator-tooltip"});
    });
    if (Object.keys(remaining).length) pending.set(id, remaining);
    else {
      pending.delete(id);
      // The first complete paint confirms that all thematic shapes exist.
      // Fit once; subsequent base/year updates retain the user's map view.
      if (state.projection && state.projection.geometryReady) state.projection.geometryReady();
    }
  }

  function schedule(id) {
    if (frames.has(id)) return;
    frames.add(id);
    nextFrame(function () { frames.delete(id); flush(id); });
  }

  function receive(message) {
    if (!message || !message.id || !message.countries) return;
    latest.set(message.id, message.countries);
    pending.set(message.id, message.countries);
    schedule(message.id);
  }

  function register() {
    if (registered || !root.Shiny || !root.Shiny.addCustomMessageHandler) return;
    root.Shiny.addCustomMessageHandler("wlvIndicatorsMap", receive);
    registered = true;
  }

  function prepareTooltip(state, tooltip) {
    if (!tooltip || state.tooltips.has(tooltip) || !root.L || !tooltip._setPosition) return;
    const original = tooltip._setPosition;
    const position = function (point) {
      const node = this.getElement();
      if (!node) return original.call(this, point);
      node.style.maxWidth = Math.max(1, Math.min(300, state.element.clientWidth - 16)) + "px";
      node.style.boxSizing = "border-box";
      node.style.transitionProperty = "none";
      original.call(this, point);
      const viewport = state.element.getBoundingClientRect();
      const bounds = node.getBoundingClientRect();
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
    tooltip.update();
  }

  function prepareLegend(state) {
    if (!state.element.querySelectorAll || !root.document) return;
    state.element.querySelectorAll('.leaflet-control.info.legend').forEach(function (legend) {
      if (legend.querySelector('.wlv-indicator-legend')) return;
      const details = root.document.createElement('details');
      details.className = 'wlv-indicator-legend';
      details.open = state.legendOpen;
      const summary = root.document.createElement('summary');
      summary.textContent = root.document.documentElement.lang === 'en' ? 'Legend' : 'Legenda';
      const content = root.document.createElement('div');
      content.className = 'wlv-indicator-legend-content';
      while (legend.firstChild) content.appendChild(legend.firstChild);
      details.append(summary, content);
      legend.appendChild(details);
      details.addEventListener('toggle', function () {
        if (details.isConnected) state.legendOpen = details.open;
      });
      if (root.L && root.L.DomEvent) {
        root.L.DomEvent.disableClickPropagation(details);
        root.L.DomEvent.disableScrollPropagation(content);
      }
    });
  }

  function attach(element, map) {
    register();
    const previous = states.get(element.id);
    if (previous) {
      previous.onUnload();
      previous.map.off("layeradd", previous.onLayerAdd);
      previous.map.off("load", previous.onReady);
      previous.map.off("unload", previous.onUnload);
    }
    const state = {map: map, element: element, active: true, tooltips: new Map(), legendOpen: previous ? previous.legendOpen : false};
    state.projection = root.WLVEqualEarth ? root.WLVEqualEarth.attach(element, map,
      {polygonPane: "wlv-indicator-polygons", waitForGeometry: true}) : null;
    state.translate = function () {
      if (!element.setAttribute || !root.document) return;
      element.setAttribute("aria-label", root.document.documentElement.lang === "en" ?
        "Indicator map in Equal Earth. Use arrow keys to pan and plus or minus to zoom. Click a country or use Countries to compare to add it to the comparison." :
        "Mapa do indicador em Equal Earth. Use as setas para mover e mais ou menos para ampliar. Clique em um país ou use Países para comparar para adicioná-lo à comparação.");
      element.querySelectorAll('.wlv-indicator-legend > summary').forEach(function (summary) {
        summary.textContent = root.document.documentElement.lang === 'en' ? 'Legend' : 'Legenda';
      });
    };
    state.translate();
    if (root.MutationObserver && root.document) {
      state.languageObserver = new root.MutationObserver(state.translate);
      state.languageObserver.observe(root.document.documentElement, {attributes:true, attributeFilter:["lang"]});
      state.legendObserver = new root.MutationObserver(function () { prepareLegend(state); });
      const controls = element.querySelector('.leaflet-control-container');
      if (controls) state.legendObserver.observe(controls, {childList:true, subtree:true});
      prepareLegend(state);
    }
    state.onResize = function () {
      if (!state.active) return;
      if (state.projection) state.projection.resize();
      else if (typeof map.invalidateSize === "function") map.invalidateSize({pan: false});
    };
    if (root.ResizeObserver) {
      state.resizeObserver = new root.ResizeObserver(state.onResize);
      state.resizeObserver.observe(element);
    } else if (root.addEventListener) root.addEventListener("resize", state.onResize);
    state.onLayerAdd = function () { if (pending.has(element.id)) schedule(element.id); };
    state.onReady = function () { schedule(element.id); };
    state.onTooltipOpen = function (event) { prepareTooltip(state, event.tooltip); };
    state.onUnload = function () {
      state.active = false;
      if (state.languageObserver) state.languageObserver.disconnect();
      if (state.legendObserver) state.legendObserver.disconnect();
      if (state.resizeObserver) state.resizeObserver.disconnect();
      else if (root.removeEventListener) root.removeEventListener("resize", state.onResize);
      map.off("tooltipopen", state.onTooltipOpen);
      state.tooltips.forEach(function (record, tooltip) {
        if (tooltip._setPosition === record.position) tooltip._setPosition = record.original;
      });
      state.tooltips.clear();
      if (state.projection) state.projection.destroy();
    };
    states.set(element.id, state);
    root.wlvIndicatorMaps[element.id] = map;
    map.on("layeradd", state.onLayerAdd);
    map.on("load", state.onReady);
    map.on("unload", state.onUnload);
    map.on("tooltipopen", state.onTooltipOpen);
    // Recreated widgets need the complete latest payload, including countries
    // successfully painted on the previous map, not just its missing layers.
    if (latest.has(element.id)) pending.set(element.id, latest.get(element.id));
    schedule(element.id);
    root.Shiny.setInputValue(element.id + "_ready", ++instance, {priority: "event"});
  }

  const api = {attach: attach, receive: receive, flush: flush,
    pending: id => pending.has(id) ? Object.keys(pending.get(id)) : []};
  root.WLVIndicators = api;
  // Compatibility for existing diagnostics of the custom message handler.
  root.wlvIndicatorPaint = receive;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  register();
  if (root.document) root.document.addEventListener("DOMContentLoaded", register, {once: true});
})(typeof window !== "undefined" ? window : globalThis);
