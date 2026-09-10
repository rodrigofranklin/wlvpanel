/* Atualização incremental: as geometrias permanecem no Leaflet durante a sessão. */
(function (root) {
  "use strict";

  const maps = new Map();
  const latest = new Map();
  const pending = new Map();
  const frames = new Set();
  let instance = 0;
  let registered = false;
  const now = () => root.performance ? root.performance.now() : Date.now();
  const nextFrame = root.requestAnimationFrame ?
    root.requestAnimationFrame.bind(root) : (callback) => root.setTimeout(callback, 0);

  // O gerenciador também encontra polígonos das bases temporariamente ocultas.
  // Percorrer map.eachLayer() deixaria essas bases com cores e textos antigos.
  function updateLayers(map, updates) {
    if (!map.layerManager || typeof map.layerManager.getLayer !== "function") {
      return { missing: updates, changed: 0 };
    }
    const missing = [];
    let changed = 0;
    updates.forEach(function (update) {
      const layer = map.layerManager.getLayer("shape", String(update.id));
      if (!layer) {
        missing.push(update);
        return;
      }
      if (layer.options.fillColor !== update.color) {
        layer.setStyle({ fillColor: update.color });
      }
      if (layer._wlvLabel !== update.label) {
        if (layer.getTooltip()) {
          layer.setTooltipContent(update.label);
        } else {
          layer.bindTooltip(update.label, { sticky: true, direction: "auto", className: "tooltip-container" });
        }
        layer._wlvLabel = update.label;
      }
      changed += 1;
    });
    return { missing: missing, changed: changed };
  }

  function schedule(id) {
    if (frames.has(id)) return;
    frames.add(id);
    nextFrame(function () {
      frames.delete(id);
      const state = maps.get(id);
      const updates = pending.get(id);
      if (!state || !state.active || !updates) return;
      const started = now();
      const result = updateLayers(state.map, updates);
      state.stats.updates += 1;
      state.stats.layers = result.changed;
      state.stats.lastDurationMs = now() - started;
      if (result.missing.length) {
        // A mensagem pode chegar antes do addPolygons; layeradd retoma a fila.
        pending.set(id, result.missing);
      } else {
        pending.delete(id);
        state.element.setAttribute("aria-busy", "false");
        if (state.projection) state.projection.geometryReady();
      }
    });
  }

  function receive(message) {
    if (!message || !message.id || !Array.isArray(message.layers)) return;
    // Durante animação, somente o estado mais recente precisa ser desenhado.
    latest.set(message.id, message.layers);
    pending.set(message.id, message.layers);
    const state = maps.get(message.id);
    if (state) state.element.setAttribute("aria-busy", "true");
    schedule(message.id);
  }

  function prepareLegend(state) {
    if (!state.controls) return;
    state.controls.querySelectorAll(".legend").forEach(function (legend) {
      if (legend.dataset.wlvLegend) return;
      legend.dataset.wlvLegend = "true";
      const details = root.document.createElement("details");
      legend.id = "map-legend-panel";
      details.className = "wlv-map-legend";
      details.open = state.legendOpen;
      const summary = root.document.createElement("summary");
            const icon = root.document.createElement("i");
      icon.className = "fas fa-list";
      icon.setAttribute("aria-hidden", "true");
      const label = root.document.createElement("span");
      label.setAttribute("data-wlv-label", "map.legend");
      label.textContent = root.wlvI18n.text("Legenda", "Legend");
      summary.append(icon, label);
      const content = root.document.createElement("div");
      content.className = "wlv-map-legend-content";
      content.id = state.element.id + "-legend-content";
      summary.setAttribute("aria-controls", content.id);
      while (legend.firstChild) content.appendChild(legend.firstChild);
      const close = root.document.createElement("button");
      close.type = "button";
      close.className = "wlv-map-legend-close";
      const cross = root.document.createElement("span");
      cross.setAttribute("aria-hidden", "true");
      cross.textContent = "\u00d7";
      const closeLabel = root.document.createElement("span");
      closeLabel.className = "sr-only";
      closeLabel.setAttribute("data-wlv-label", "app.close");
      closeLabel.textContent = root.wlvI18n.text("Fechar", "Close");
      close.append(cross, closeLabel);
      close.addEventListener("click", function () {
        details.open = false;
        summary.focus();
      });
      content.appendChild(close);
      details.append(summary, content);
      legend.appendChild(details);
      details.addEventListener("toggle", function () {
        if (details.isConnected) {
          state.legendOpen = details.open;
          // Ao abrir, o botão de fechar substitui o acionador como no e-mar.
          if (details.open && root.document.activeElement === summary) close.focus();
        }
      });
      if (root.L && root.L.DomEvent) {
        root.L.DomEvent.disableClickPropagation(details);
        root.L.DomEvent.disableScrollPropagation(content);
      }
    });
  }

  function prepareTooltip(state, tooltip) {
    if (!tooltip || state.tooltips.has(tooltip) || !root.L || !tooltip._setPosition) return;
    const original = tooltip._setPosition;
    const position = function (point) {
      const node = this.getElement();
      node.style.maxWidth = Math.max(1, Math.min(320, state.element.clientWidth - 16)) + "px";
      node.style.boxSizing = "border-box";
      // Medir o destino, não o frame anterior da transição de transform do Leaflet.
      node.style.transitionProperty = "none";
      original.call(this, point);
      const viewport = state.element.getBoundingClientRect();
      const bounds = node.getBoundingClientRect();
      const left = Math.max(viewport.left + 8, Math.min(bounds.left, viewport.right - 8 - bounds.width));
      const top = Math.max(viewport.top + 8, Math.min(bounds.top, viewport.bottom - 8 - bounds.height));
      const dx = left - bounds.left, dy = top - bounds.top;
      node.setAttribute("data-wlv-clamped", dx || dy ? "true" : "false");
      if (dx || dy) {
        const current = root.L.DomUtil.getPosition(node);
        root.L.DomUtil.setPosition(node, root.L.point(current.x + dx, current.y + dy));
      }
    };
    state.tooltips.set(tooltip, { original: original, position: position });
    // Somente esta instância: sticky, setContent e zoom usam o mesmo caminho.
    tooltip._setPosition = position;
    tooltip.update();
  }

  function releaseTooltips(state) {
    state.map.off("tooltipopen", state.onTooltipOpen);
    state.tooltips.forEach(function (record, tooltip) {
      if (tooltip._setPosition === record.position) tooltip._setPosition = record.original;
    });
    state.tooltips.clear();
  }

  function attach(element, map) {
    register();
    const previous = maps.get(element.id);
    if (previous) {
      previous.map.off("layeradd", previous.onLayerAdd);
      previous.map.off("unload", previous.onUnload);
      if (previous.resizeObserver) previous.resizeObserver.disconnect();
      if (previous.legendObserver) previous.legendObserver.disconnect();
      if (previous.projection && previous.map !== map) previous.projection.destroy();
      releaseTooltips(previous);
    }
    const state = {
      element: element,
      map: map,
      active: true,
      tooltips: new Map(),
      legendOpen: previous ? previous.legendOpen : false,
      stats: { updates: 0, layers: 0, lastDurationMs: 0 },
      onLayerAdd: function () { if (pending.has(element.id)) schedule(element.id); }
    };
    state.onUnload = function () { state.active = false; releaseTooltips(state); };
    state.onTooltipOpen = function (event) { prepareTooltip(state, event.tooltip); };
    maps.set(element.id, state);
    map.on("layeradd", state.onLayerAdd);
    map.on("unload", state.onUnload);
    map.on("tooltipopen", state.onTooltipOpen);
    if (root.WLVEqualEarth) state.projection = root.WLVEqualEarth.attach(element, map, {waitForGeometry:true});
    if (element.querySelector && root.MutationObserver) {
      state.controls = element.querySelector(".leaflet-control-container");
      if (state.controls) {
        state.legendObserver = new root.MutationObserver(function () { prepareLegend(state); });
        state.legendObserver.observe(state.controls, { childList: true, subtree: true });
        prepareLegend(state);
      }
    }
    if (root.ResizeObserver) {
      state.resizeObserver = new root.ResizeObserver(function () {
        if (element.clientWidth && element.clientHeight) {
          if (state.projection) state.projection.resize();
          else map.invalidateSize({ pan: false, debounceMoveend: true });
        }
      });
      state.resizeObserver.observe(element);
    }
    if (latest.has(element.id)) pending.set(element.id, latest.get(element.id));
    element.setAttribute("aria-busy", "true");
    schedule(element.id);
    root.Shiny.setInputValue(element.id + "_wlv_ready", ++instance, { priority: "event" });
  }

  const api = { attach: attach, receive: receive, updateLayers: updateLayers,
    fitWorld: function (id) { const state = maps.get(id); if (state && state.projection) state.projection.fitWorld(); },
    stats: function (id) { return maps.has(id) ? maps.get(id).stats : null; } };
  root.WLVMap = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;

  function register() {
    if (registered || !root.Shiny || !root.Shiny.addCustomMessageHandler) return;
    root.Shiny.addCustomMessageHandler("wlv-map-update", receive);
    registered = true;
  }
  if (root.Shiny) register();
  else if (root.document) root.document.addEventListener("DOMContentLoaded", register, { once: true });
})(typeof window !== "undefined" ? window : globalThis);
