/* Interactive country selector. All geometry and projection assets are local.
 * Requires wlv-country-geo.js; updates the country selector with an ISO3 code.
 * co_globe_country is the Shiny fallback when Selectize is unavailable.
 */
(function (root) {
  "use strict";

  const document = root.document;
  const ID = "wlv-country-globe";
  const script = document.currentScript;
  const assetURL = new URL("wlv-countries-110m.geojson", script && script.src || document.baseURI).href;
  const geo = root.WLVCountryGeo;
  const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
  const normalize = value => ((value + 180) % 360 + 360) % 360 - 180;
  // A missing first message is distinct from a real, empty country list.
  let latest = null;
  let controller = null;
  let geometryPromise = null;
  let registered = false;
  let bootFrame = 0;

  const labels = {
    pt: {
      globe: "Globo interativo para escolher um país",
      instruction: "Arraste para girar e clique em um país.",
      loading: "Carregando o globo…",
      error: "Não foi possível carregar o globo. Você pode escolher um país na caixa de seleção.",
      retry: "Tentar novamente",
      unavailable: "Sem dados nesta seleção",
      available: "Com dados",
      selected: "País selecionado",
      north: "Girar para o norte", south: "Girar para o sul",
      west: "Girar para o oeste", east: "Girar para o leste",
      reset: "Centralizar país selecionado",
      ocean: "Oceano",
      noOutline: "Localização indisponível no globo; use a caixa de seleção.",
      empty: "Nenhum país com dados nesta seleção."
    },
    en: {
      globe: "Interactive globe to choose a country",
      instruction: "Drag to rotate and click a country.",
      loading: "Loading the globe…",
      error: "The globe could not be loaded. You can choose a country from the dropdown.",
      retry: "Try again", unavailable: "No data in this selection",
      available: "With data", selected: "Selected country",
      north: "Rotate north", south: "Rotate south",
      west: "Rotate west", east: "Rotate east",
      reset: "Center selected country",
      ocean: "Ocean",
      noOutline: "Location unavailable on the globe; use the dropdown.",
      empty: "No countries with data in this selection."
    }
  };

  function geometry() {
    if (!geometryPromise) {
      // Geometry is shared across remounted hosts, so its timeout must own an
      // independent controller. A stalled fetch must release the entry loader.
      const request = new root.AbortController();
      const timeout = root.setTimeout(() => request.abort(), 15000);
      geometryPromise = root.fetch(assetURL, { credentials: "same-origin", signal: request.signal }).then(response => {
        if (!response.ok) throw new Error("Globe geometry HTTP " + response.status);
        return response.json();
      }).then(collection => {
        if (!collection || !Array.isArray(collection.features) || !collection.features.length) {
          throw new Error("Missing country geometry");
        }
        return collection.features.map(feature => ({
          feature: feature,
          code: String(feature.properties.code || ""),
          center: feature.properties.center || geo.geoCentroid(feature),
          area: geo.geoArea(feature)
        }));
      }).catch(error => {
        geometryPromise = null;
        throw error;
      }).finally(() => root.clearTimeout(timeout));
    }
    return geometryPromise;
  }

  function element(tag, className, parent) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (parent) parent.appendChild(node);
    return node;
  }

  function create(host) {
    const events = new root.AbortController();
    const signal = events.signal;
    const reducedMotion = root.matchMedia && root.matchMedia("(prefers-reduced-motion: reduce)");
    const state = {
      host: host, countries: new Map(), selected: "", lang: "pt", features: [],
      rotation: [30, -15, 0], width: 360, radius: 160,
      frame: 0, animation: null, pointer: null, hovered: null, error: false,
      disposed: false, loaded: false, received: false
    };
    const text = key => root.wlvI18n.text(labels.pt[key], labels.en[key], state.lang);
    host.replaceChildren();
    host.classList.add("wlv-globe");
    host.dataset.animating = "false";
    host.dataset.ready = "loading";
    host.dataset.received = "false";
    const viewport = element("div", "wlv-globe-viewport", host);
    viewport.style.position = "relative";
    const canvas = element("canvas", "wlv-globe-canvas", viewport);
    canvas.style.cssText = "display:block;width:100%;aspect-ratio:1;touch-action:none;cursor:grab;";
    canvas.setAttribute("role", "img");
    canvas.setAttribute("aria-describedby", ID + "-instructions " + ID + "-status");
    const context = canvas.getContext("2d");
    const projection = geo ? geo.geoOrthographic().precision(0.35).clipAngle(90) : null;
    const path = projection && context ? geo.geoPath(projection, context) : null;
    const graticule = geo ? geo.geoGraticule().step([30, 30])() : null;
    const tooltip = element("div", "wlv-globe-tooltip", viewport);
    tooltip.hidden = true;
    tooltip.setAttribute("role", "tooltip");
    tooltip.style.cssText = "position:absolute;pointer-events:none;max-width:calc(100% - 20px);z-index:2;";
    const status = element("div", "wlv-globe-status", host);
    status.id = ID + "-status";
    status.setAttribute("role", "status");
    status.setAttribute("aria-live", "polite");
    const instructions = element("p", "wlv-globe-instructions", host);
    instructions.id = ID + "-instructions";
    const controls = element("div", "wlv-globe-controls", host);
    const buttonSpecs = [["west", "←", 16, 0], ["north", "↑", 0, -12],
      ["south", "↓", 0, 12], ["east", "→", -16, 0], ["reset", "↺", 0, 0]];
    const buttons = buttonSpecs.map(spec => {
      const button = element("button", "wlv-globe-control", controls);
      button.type = "button";
      button.dataset.direction = spec[0];
      button.textContent = spec[1];
      button.addEventListener("click", () => {
        if (spec[0] === "reset") centerSelected();
        else rotate(spec[2], spec[3]);
      }, { signal: signal });
      return button;
    });
    const retry = element("button", "wlv-globe-retry", host);
    retry.type = "button";
    retry.hidden = true;
    retry.addEventListener("click", load, { signal: signal });
    const legend = element("div", "wlv-globe-legend", host);
    const legendItems = ["available", "selected", "unavailable"].map(key => {
      const item = element("span", "wlv-globe-legend-item", legend);
      element("i", "wlv-globe-swatch wlv-globe-swatch-" + key, item).setAttribute("aria-hidden", "true");
      return { label: element("span", "", item), key: key };
    });
    const attribution = element("small", "wlv-globe-attribution", host);
    const attributionLink = element("a", "", attribution);
    attributionLink.href = "https://www.naturalearthdata.com/";
    attributionLink.target = "_blank";
    attributionLink.rel = "noopener noreferrer";
    attributionLink.textContent = "Natural Earth";

    function countryLabel(item) {
      if (!item) return text("ocean");
      const label = state.countries.get(item.code);
      if (label) return label;
      return root.wlvI18n.label("ISO3." + item.code,
        root.wlvI18n.text(item.feature.properties.name_pt || item.feature.properties.name, item.feature.properties.name, state.lang) || item.code);
    }

    function selectionStatus() {
      if (state.error) return text("error");
      if (!state.loaded || !state.received) return text("loading");
      if (!state.countries.size) return text("empty");
      const selected = state.features.find(item => item.code === state.selected);
      const name = state.countries.get(state.selected) || (selected ? countryLabel(selected) : "");
      if (!name) return "";
      return text("selected") + ": " + name + (selected ? "" : ". " + text("noOutline"));
    }

    function translate() {
      host.setAttribute("aria-busy", String(!state.error && (!state.loaded || !state.received)));
      canvas.setAttribute("aria-label", text("globe"));
      instructions.textContent = text("instruction");
      buttons.forEach((button, index) => {
        button.setAttribute("aria-label", text(buttonSpecs[index][0]));
        button.title = text(buttonSpecs[index][0]);
        button.disabled = !state.loaded || !state.received;
      });
      retry.textContent = text("retry");
      legendItems.forEach(item => { item.label.textContent = text(item.key); });
      status.textContent = selectionStatus();
    }

    function updateProjection() {
      projection.rotate(state.rotation).translate([state.width / 2, state.width / 2]).scale(state.radius);
      host.dataset.longitude = normalize(-state.rotation[0]).toFixed(4);
      host.dataset.latitude = (-state.rotation[1]).toFixed(4);
    }

    function drawFeature(item, fill, stroke, lineWidth) {
      context.beginPath();
      path(item.feature);
      context.fillStyle = fill;
      context.fill();
      if (stroke) {
        context.strokeStyle = stroke;
        context.lineWidth = lineWidth;
        context.stroke();
      }
    }

    function draw(timestamp) {
      state.frame = 0;
      if (state.disposed || !projection || !context) return;
      if (state.animation) {
        const animation = state.animation;
        const progress = reducedMotion && reducedMotion.matches ? 1 :
          clamp((timestamp - animation.started) / 780, 0, 1);
        const eased = progress < 0.5 ? 4 * progress * progress * progress :
          1 - Math.pow(-2 * progress + 2, 3) / 2;
        state.rotation = [animation.from[0] + animation.delta[0] * eased,
          animation.from[1] + animation.delta[1] * eased, 0];
        if (progress === 1) stopAnimation();
      }
      updateProjection();
      context.clearRect(0, 0, state.width, state.width);
      const mid = state.width / 2;
      const ocean = context.createRadialGradient(mid * 0.65, mid * 0.6, state.radius * 0.1,
        mid, mid, state.radius);
      ocean.addColorStop(0, "#f4f7f6");
      ocean.addColorStop(1, "#dce6e4");
      context.beginPath();
      path({ type: "Sphere" });
      context.fillStyle = ocean;
      context.fill();
      context.strokeStyle = "#a7b7b5";
      context.lineWidth = 0.8;
      context.stroke();
      context.beginPath();
      path(graticule);
      context.strokeStyle = "rgba(159,181,177,0.36)";
      context.lineWidth = 0.55;
      context.stroke();

      const selected = state.features.find(item => item.code === state.selected);
      state.features.forEach(item => {
        if (item === selected) return;
        const available = state.countries.has(item.code);
        const hovered = state.hovered === item;
        drawFeature(item, hovered && available ? "#e7c49d" : available ? "#f9faf8" : "#c4cecc",
          hovered && available ? "#9a5d37" : "#8b9b99", hovered && available ? 1.2 : 0.55);
      });
      if (selected) drawFeature(selected, "#ae363e", "#76252f", 0.9);

      // Real small states remain selectable at this scale, using their label
      // point only when their projected footprint would be a few pixels.
      const center = projection.invert([mid, mid]);
      state.features.forEach(item => {
        if (!state.countries.has(item.code) || item.area * state.radius * state.radius > 18) return;
        if (geo.geoDistance(center, item.center) > Math.PI / 2 - 0.025) return;
        const point = projection(item.center);
        if (!point || !point.every(Number.isFinite)) return;
        context.beginPath();
        context.arc(point[0], point[1], item === selected ? 3.8 : 3.1, 0, Math.PI * 2);
        context.fillStyle = item === selected ? "#ae363e" : state.hovered === item ? "#e7c49d" : "#f9faf8";
        context.fill();
        context.strokeStyle = item === selected ? "#76252f" : "#596f6c";
        context.lineWidth = 0.8;
        context.stroke();
      });
      if (state.animation) schedule();
    }

    function schedule() {
      if (!state.frame && !state.disposed) state.frame = root.requestAnimationFrame(draw);
    }

    function resize() {
      if (state.disposed || !context) return;
      const width = Math.max(1, host.getBoundingClientRect().width);
      if (width < 2) return;
      state.width = width;
      state.radius = width * 0.455;
      const ratio = Math.min(root.devicePixelRatio || 1, 3);
      canvas.width = Math.round(width * ratio);
      canvas.height = Math.round(width * ratio);
      context.setTransform(ratio, 0, 0, ratio, 0, 0);
      schedule();
    }

    function hideTooltip() {
      tooltip.hidden = true;
      if (state.hovered) {
        state.hovered = null;
        schedule();
      }
    }

    function pointFor(event) {
      const bounds = canvas.getBoundingClientRect();
      return [(event.clientX - bounds.left) * state.width / bounds.width,
        (event.clientY - bounds.top) * state.width / bounds.height];
    }

    function countryAt(point) {
      if (!state.loaded || !state.received) return null;
      const mid = state.width / 2;
      if (Math.hypot(point[0] - mid, point[1] - mid) > state.radius) return null;
      updateProjection();
      // Marker hit areas are deliberately bounded; no ocean click selects a
      // distant country merely because that country has data.
      const center = projection.invert([mid, mid]);
      const marker = state.features.filter(item => state.countries.has(item.code) &&
        item.area * state.radius * state.radius <= 18 &&
        geo.geoDistance(center, item.center) <= Math.PI / 2 - 0.025)
        .map(item => ({ item: item, point: projection(item.center) }))
        .map(mark => ({ mark: mark,
          distance: Math.hypot(mark.point[0] - point[0], mark.point[1] - point[1]) }))
        .filter(entry => entry.distance <= 6).sort((a, b) => a.distance - b.distance)[0];
      if (marker) return marker.mark.item;
      const location = projection.invert(point);
      if (!location || !location.every(Number.isFinite)) return null;
      return state.features.find(item => geo.geoContains(item.feature, location)) || null;
    }

    function preview(point) {
      const item = countryAt(point);
      if (state.hovered !== item) {
        state.hovered = item;
        schedule();
      }
      canvas.style.cursor = item && state.countries.has(item.code) ? "pointer" : "grab";
      if (!item) { tooltip.hidden = true; return; }
      tooltip.textContent = countryLabel(item) + (state.countries.has(item.code) ? "" : " · " + text("unavailable"));
      tooltip.hidden = false;
      const left = clamp(point[0] + 12, 8, Math.max(8, state.width - tooltip.offsetWidth - 8));
      const top = clamp(point[1] + 12, 8, Math.max(8, state.width - tooltip.offsetHeight - 8));
      tooltip.style.left = left + "px";
      tooltip.style.top = top + "px";
    }

    function stopAnimation() {
      state.animation = null;
      host.dataset.animating = "false";
    }

    function rotate(longitude, latitude) {
      if (!state.loaded || !state.received) return;
      stopAnimation();
      state.rotation[0] = normalize(state.rotation[0] + longitude);
      state.rotation[1] = clamp(state.rotation[1] + latitude, -89.5, 89.5);
      hideTooltip();
      schedule();
    }

    function centerSelected(animate = true) {
      const item = state.features.find(feature => feature.code === state.selected);
      if (state.animation && state.animation.country === state.selected) return;
      stopAnimation();
      if (item) {
        const target = [-item.center[0], -item.center[1], 0];
        const delta = [normalize(target[0] - state.rotation[0]), target[1] - state.rotation[1]];
        if (animate && !(reducedMotion && reducedMotion.matches) && Math.hypot(delta[0], delta[1]) > 0.05) {
          // Preserve the current visible orientation and take the shortest
          // longitude arc, including transitions across the antimeridian.
          state.animation = { country: state.selected, from: state.rotation.slice(), delta: delta,
            started: root.performance.now() };
          host.dataset.animating = "true";
        } else state.rotation = target;
      }
      hideTooltip();
      schedule();
      status.textContent = selectionStatus();
    }

    function select(item) {
      if (!item) return;
      if (!state.countries.has(item.code)) {
        status.textContent = countryLabel(item) + " · " + text("unavailable");
        return;
      }
      // Start immediately; the matching Shiny echo must not restart the spin.
      state.selected = item.code;
      host.dataset.selected = item.code;
      centerSelected();
      const selector = document.getElementById("co_select_country");
      if (selector && selector.selectize && typeof selector.selectize.setValue === "function") {
        // Selectize already sends co_select_country through its Shiny binding.
        // Updating it here avoids a server round trip that could overwrite a
        // newer local click with an older co_globe_country response.
        selector.selectize.setValue(item.code);
      } else if (root.Shiny && root.Shiny.setInputValue) {
        root.Shiny.setInputValue("co_globe_country", item.code, { priority: "event" });
      }
    }

    canvas.addEventListener("pointerdown", event => {
      if (!state.loaded || !state.received || state.pointer || event.button !== 0) return;
      const point = pointFor(event);
      if (Math.hypot(point[0] - state.width / 2, point[1] - state.width / 2) > state.radius) return;
      stopAnimation();
      state.pointer = { id: event.pointerId, point: point, rotation: state.rotation.slice(), moved: false };
      canvas.setPointerCapture(event.pointerId);
      canvas.style.cursor = "grabbing";
      hideTooltip();
    }, { signal: signal });
    canvas.addEventListener("pointermove", event => {
      const point = pointFor(event);
      if (!state.pointer) { if (event.pointerType !== "touch") preview(point); return; }
      if (event.pointerId !== state.pointer.id) return;
      const dx = point[0] - state.pointer.point[0];
      const dy = point[1] - state.pointer.point[1];
      if (Math.hypot(dx, dy) > 5) state.pointer.moved = true;
      if (!state.pointer.moved) return;
      const speed = 100 / state.radius;
      state.rotation = [normalize(state.pointer.rotation[0] + dx * speed),
        clamp(state.pointer.rotation[1] - dy * speed, -89.5, 89.5), 0];
      schedule();
    }, { signal: signal });
    canvas.addEventListener("pointerup", event => {
      if (!state.pointer || event.pointerId !== state.pointer.id) return;
      const pointer = state.pointer;
      state.pointer = null;
      if (canvas.hasPointerCapture(event.pointerId)) canvas.releasePointerCapture(event.pointerId);
      canvas.style.cursor = "grab";
      if (!pointer.moved) select(countryAt(pointFor(event)));
    }, { signal: signal });
    function cancelPointer() {
      state.pointer = null;
      canvas.style.cursor = "grab";
      hideTooltip();
    }
    canvas.addEventListener("pointercancel", cancelPointer, { signal: signal });
    canvas.addEventListener("lostpointercapture", cancelPointer, { signal: signal });
    canvas.addEventListener("pointerleave", () => { if (!state.pointer) hideTooltip(); }, { signal: signal });

    const resizeObserver = root.ResizeObserver ? new root.ResizeObserver(resize) : null;
    if (resizeObserver) resizeObserver.observe(host);
    else root.addEventListener("resize", resize, { signal: signal });

    function load() {
      state.error = false;
      host.dataset.ready = "loading";
      retry.hidden = true;
      host.setAttribute("aria-busy", "true");
      translate();
      if (!geo || !context || !root.fetch) { failed(); return; }
      geometry().then(features => {
        if (state.disposed) return;
        state.features = features;
        state.loaded = true;
        host.dataset.ready = "true";
        host.dataset.featureCount = String(features.length);
        host.setAttribute("aria-busy", "false");
        translate();
        resize();
        centerSelected(false);
      }).catch(failed);
    }

    function failed() {
      if (state.disposed) return;
      state.error = true;
      host.dataset.ready = "error";
      host.setAttribute("aria-busy", "false");
      retry.hidden = false;
      translate();
    }

    function update(message) {
      const previous = state.selected;
      state.received = true;
      host.dataset.received = "true";
      state.lang = String(message.lang || root.wlvI18n.code());
      const entries = Array.isArray(message.countries) ? message.countries : [];
      state.countries = new Map(entries.filter(country => country && country.code)
        .map(country => [String(country.code), String(country.label || country.code)]));
      const selector = document.getElementById("co_select_country");
      const control = selector && selector.selectize;
      const current = control && typeof control.getValue === "function" ? String(control.getValue() || "") : "";
      // The current client selection can already be several clicks ahead of
      // this server message. Keep it when valid for the received availability;
      // if a dataset change removes it, accept the server's fallback country.
      state.selected = current && state.countries.has(current) ? current : String(message.selected || "");
      host.dataset.selected = state.selected;
      host.dataset.availableCount = String(state.countries.size);
      translate();
      if (state.loaded && previous !== state.selected) centerSelected(Boolean(previous));
      hideTooltip();
      schedule();
    }

    function destroy() {
      state.disposed = true;
      stopAnimation();
      events.abort();
      if (resizeObserver) resizeObserver.disconnect();
      if (state.frame) root.cancelAnimationFrame(state.frame);
      host.replaceChildren();
    }

    if (latest) update(latest);
    load();
    return { host: host, update: update, destroy: destroy };
  }

  function boot() {
    bootFrame = 0;
    if (!registered && root.Shiny && root.Shiny.addCustomMessageHandler) {
      root.Shiny.addCustomMessageHandler("wlv-country-globe", receive);
      registered = true;
    }
    const host = document.getElementById(ID);
    if (controller && controller.host !== host) {
      controller.destroy();
      controller = null;
    }
    if (host && !controller) controller = create(host);
  }

  function scheduleBoot() {
    if (!bootFrame) bootFrame = root.requestAnimationFrame(boot);
  }

  function receive(message) {
    if (!message || typeof message !== "object") return;
    latest = message;
    boot();
    if (controller) controller.update(latest);
  }

  root.WLVCountryGlobe = { update: receive, init: boot };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot, { once: true });
  else boot();
  if (root.jQuery) root.jQuery(document).on("shiny:connected.wlvCountryGlobe shiny:bound.wlvCountryGlobe", boot);
  const observer = new root.MutationObserver(mutations => {
    if (mutations.some(mutation => Array.from(mutation.addedNodes).concat(Array.from(mutation.removedNodes))
      .some(node => node.nodeType === 1 && (node.id === ID || node.querySelector && node.querySelector("#" + ID))))) {
      scheduleBoot();
    }
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
})(window);
