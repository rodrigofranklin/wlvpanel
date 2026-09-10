/* Explore the full ranking locally; hovering never changes Shiny inputs. */
(function (root) {
  "use strict";

  const defaultPalette = ["#8D2028", "#CC858A", "#F2DCDD", "#FCE7C0", "#F6AE2D"];
  const ink = "#415866";
  const labelInk = "#263238";
  const frame = root.requestAnimationFrame ? root.requestAnimationFrame.bind(root) :
    callback => root.setTimeout(callback, 0);
  const cancelFrame = root.cancelAnimationFrame ? root.cancelAnimationFrame.bind(root) : root.clearTimeout.bind(root);

  function array(value) { return value == null ? [] : Array.isArray(value) ? value : [value]; }
  function html(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, character =>
      ({"&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;"})[character]);
  }
  function color(row, palette) {
    return palette[Math.max(0, Math.min(palette.length - 1,
      Math.floor((row.rank - 0.5) / row.count * palette.length)))];
  }
  function contrast(fill, opacity) {
    const channels = fill.replace("#", "").match(/.{2}/g).map(channel => {
      const channelValue = (parseInt(channel, 16) * opacity + 255 * (1 - opacity)) / 255;
      return channelValue <= 0.04045 ? channelValue / 12.92 : Math.pow((channelValue + 0.055) / 1.055, 2.4);
    });
    const luminance = channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722;
    return luminance <= 0.18 ? "#FFFFFF" : labelInk;
  }
  function finite(value) { return value != null && Number.isFinite(Number(value)); }

  function attach(element, supplied) {
    if (!element || !root.Plotly) return;
    if (element._wlvRanking && element._wlvRanking.destroy) element._wlvRanking.destroy();
    // The R binding installs these Shiny input-clear handlers even when its
    // shinyEvents list is empty. This chart uses neither Shiny plot events nor
    // Crosstalk selections; replace only these handlers before adding ours.
    if (typeof element.removeAllListeners === "function") {
      ["plotly_unhover", "plotly_deselect", "plotly_doubleclick"].forEach(event => element.removeAllListeners(event));
    }
    const payload = supplied || {};
    const suppliedPalette = array(payload.palette).filter(value => /^#[0-9a-f]{6}$/i.test(value));
    const palette = suppliedPalette.length ? suppliedPalette : defaultPalette;
    const selected = new Set(array(payload.selected).map(String));
    const rows = array(payload.rows).filter(row => row && row.country && finite(row.year) &&
      finite(row.rank) && finite(row.count) && Number(row.count) > 0).map(row => Object.assign({}, row, {
        country:String(row.country), year:Number(row.year), rank:Number(row.rank), count:Number(row.count)
      }));
    const years = array(payload.years).map(Number).filter(Number.isFinite).sort((a, b) => a - b);
    const byCountry = new Map();
    const byCell = new Map();
    rows.forEach(function (row) {
      if (!byCountry.has(row.country)) byCountry.set(row.country, new Map());
      byCountry.get(row.country).set(row.year, row);
      const key = row.year + "|" + row.rank;
      if (!byCell.has(key)) byCell.set(key, []);
      byCell.get(key).push(row);
    });
    byCell.forEach(group => group.sort((a, b) => Number(selected.has(b.country)) - Number(selected.has(a.country)) ||
      a.country.localeCompare(b.country)));

    const wrapper = element.closest ? element.closest(".wlv-indicators-ranking") : null;
    const readout = wrapper && wrapper.querySelector(".wlv-ranking-readout");
        const baseAnnotations = array(element.layout && element.layout.annotations).filter(item =>
      !String(item.name || "").startsWith("wlv-ranking-"));
    const baseShapes = array(element.layout && element.layout.shapes).filter(item =>
      !String(item.name || "").startsWith("wlv-ranking-"));
    let active = true;
    let pendingFrame = null;
    let rendering = false;
    let dirty = false;
    let pointerInside = false;
    let hoverRow = null;
    let geometry = "";
    let gesture = null;

    function traceIndex(role) {
      return array(element.data).findIndex(trace => trace.meta && trace.meta.role === role);
    }
    function rowFor(country, year) {
      const countryRows = byCountry.get(String(country));
      if (!countryRows) return null;
      if (year != null && countryRows.has(Number(year))) return countryRows.get(Number(year));
      const observed = Array.from(countryRows.keys()).sort((a, b) => b - a);
      return countryRows.get(observed[0]) || null;
    }
    function cellFor(year, rank) {
      return byCell.get(Number(year) + "|" + Number(rank)) || [];
    }
    function valueText(row) {
      if (row.valueLabel != null) return String(row.valueLabel);
      const number = Number(row.value);
      const value = Number.isFinite(number) ? number.toLocaleString(root.wlvI18n.locale(payload.lang), {
        maximumFractionDigits:2
      }) : "—";
      return value + (row.unit || payload.unitLabel ? " " + (row.unit || payload.unitLabel) : "");
    }
    function announce() {
      if (!readout) return;
      if (!hoverRow) {
        readout.textContent = "";
        return;
      }
      const others = cellFor(hoverRow.year, hoverRow.rank).filter(row => row.country !== hoverRow.country);
      const tied = others.length ? (root.wlvI18n.text(" · Empatado com: ", " · Tied with: ")) +
        others.map(row => row.label || row.country).join(", ") : "";
      const unit = payload.unitLabel || hoverRow.unit || "";
      const value = valueText(hoverRow);
      readout.textContent = (hoverRow.label || hoverRow.country) + " · " + hoverRow.year + " · " +
        (root.wlvI18n.text("Posição ", "Rank ")) + hoverRow.rank + (root.wlvI18n.text(" de ", " of ")) + hoverRow.count +
        " · " + value + (unit && !value.endsWith(unit) ? " " + unit : "") + tied;
    }
    function displayedCountries() {
      const countries = Array.from(selected).filter(country => byCountry.has(country));
      if (hoverRow && !selected.has(hoverRow.country)) countries.push(hoverRow.country);
      return countries;
    }
    function textColor(row, role, hovering) {
      if (!row) return labelInk;
      const axis = element._fullLayout && element._fullLayout.yaxis;
      const rowHeight = axis && axis.l2p ? Math.abs(axis.l2p(2) - axis.l2p(1)) : 12;
      const fontSize = role === "rank" ? 11 : 10;
      // The text sits outside its country's strip. Sample the band behind
      // the label itself so a quintile boundary does not reverse contrast.
      const sample = row.rank + (role === "rank" ? -1 : 1) *
        (0.5 + (fontSize * 0.6 + 3) / Math.max(1, rowHeight));
      const background = cellFor(row.year, Math.round(sample))[0];
      if (!background) return labelInk;
      const highlighted = hovering && Math.abs(sample - background.rank) <= 0.45 &&
        cellFor(row.year, background.rank).some(candidate => selected.has(candidate.country) ||
          hoverRow && candidate.country === hoverRow.country);
      return contrast(color(background, palette), hovering && !highlighted ? 0.3 : 1);
    }
    function selectedLabelColors(hovering) {
      const indices = [];
      const colors = [];
      array(element.data).forEach(function (trace, index) {
        const meta = trace.meta || {};
        if (!["ranking-selected-rank", "ranking-selected-value"].includes(meta.role)) return;
        const countryRows = byCountry.get(String(meta.country));
        const role = meta.role === "ranking-selected-rank" ? "rank" : "value";
        indices.push(index);
        colors.push(array(trace.x).map(year => textColor(countryRows && countryRows.get(Number(year)), role, hovering)));
      });
      return indices.length ? root.Plotly.restyle(element, {"textfont.color":colors}, indices) : Promise.resolve();
    }
    function annotations(countries) {
      const axis = element._fullLayout && element._fullLayout.yaxis;
      const endpoints = countries.map(country => rowFor(country)).filter(Boolean).map(function (row) {
        const name = String(row.label || row.country) +
          (row.year !== years[years.length - 1] ? " (" + row.year + ")" : "");
        const words = name.split(/\s+/).flatMap(word => {
          const letters = Array.from(word);
          const parts = [];
          while (letters.length) parts.push(letters.splice(0, 24).join(""));
          return parts;
        });
        const lines = [];
        let line = "";
        let limit = 24 - String(row.rank).length - 2;
        words.forEach(function (word) {
          if (line && line.length + word.length + 1 > limit) {
            lines.push(line); line = ""; limit = 24;
          }
          line += (line ? " " : "") + word;
        });
        if (line) lines.push(line);
        return {row:row, pixel:axis && axis.l2p ? axis.l2p(row.rank) : row.rank * 4,
          text:"<b>" + html(row.rank) + ".</b> " + lines.map(html).join("<br>"),
          height:Math.max(1, lines.length) * 14};
      }).sort((a, b) => a.pixel - b.pixel);
      let previous = -Infinity;
      let previousHeight = 0;
      endpoints.forEach(endpoint => {
        endpoint.target = Math.max(endpoint.pixel, previous + previousHeight / 2 + endpoint.height / 2 + 6);
        previous = endpoint.target;
        previousHeight = endpoint.height;
      });
      if (axis && endpoints.length) {
        const last = endpoints[endpoints.length - 1];
        const overflow = Math.max(0, last.target - axis._length + last.height / 2);
        if (overflow) endpoints.forEach(endpoint => { endpoint.target -= overflow; });
      }
      return baseAnnotations.concat(endpoints.map(function (endpoint) {
        const row = endpoint.row;
        return {
          name:"wlv-ranking-endpoint-" + row.country,
          xref:"paper", yref:"y", x:1.01, y:row.rank,
          xanchor:"left", yanchor:"middle", align:"left", showarrow:false,
          yshift:endpoint.pixel - endpoint.target,
          text:endpoint.text,
          font:{color:ink, size:12}, captureevents:false
        };
      }));
    }
    function shapes(countries, hovering) {
      // The opaque heatmap covers native grid lines. Rebuild the named
      // annual grid above it; baseShapes excludes the R-created copies.
      const grid = Array.from(new Set(years)).map(year => ({
        name:"wlv-ranking-grid-" + year, type:"line", xref:"x", yref:"paper",
        x0:year, x1:year, y0:0, y1:1,
        line:{color:"rgba(70,65,65,0.28)", dash:"dash", width:1}, layer:"above"
      }));
      const outlines = [];
      countries.forEach(country => byCountry.get(country).forEach(function (row) {
        outlines.push({
          name:"wlv-ranking-cell-" + country + "-" + row.year,
          type:"rect", xref:"x", yref:"y", x0:row.year - 0.5, x1:row.year + 0.5,
          y0:row.rank - 0.45, y1:row.rank + 0.45,
          fillcolor:hovering ? color(row, palette) : "rgba(0,0,0,0)", opacity:1,
          line:{color:contrast(color(row, palette), 1), width:1}, layer:hovering ? "below" : "above"
        });
      }));
      return baseShapes.concat(grid, outlines);
    }
    function hoverTraces() {
      const indices = ["ranking-hover-line", "ranking-hover-rank", "ranking-hover-value"].map(traceIndex);
      if (indices.some(index => index < 0)) return Promise.resolve();
      const countryRows = hoverRow && !selected.has(hoverRow.country) ? byCountry.get(hoverRow.country) : null;
      const points = years.map(year => countryRows && countryRows.get(year) || null);
      const ranks = points.map(row => row ? row.rank - 0.5 : null);
      const values = points.map(row => row ? row.rank + 0.5 : null);
      const line = points.map(row => row ? row.rank - 0.45 : null);
      return root.Plotly.restyle(element, {
        x:[years, years, years], y:[line, ranks, values],
        text:[[], points.map(row => row ? String(row.rank) : ""), points.map(row => row ? valueText(row) : "")],
        mode:["lines", "text", "text"], textposition:["middle center", "top center", "bottom center"],
        "textfont.color":[ink, points.map(row => textColor(row, "rank", true)),
          points.map(row => textColor(row, "value", true))], "textfont.size":[11, 11, 10],
        "line.shape":"hvh", "line.color":ink, "line.width":1.3,
        connectgaps:false, hoverinfo:"skip"
      }, indices);
    }
    function render() {
      pendingFrame = null;
      if (!active) return;
      if (rendering) { dirty = true; return; }
      rendering = true;
      dirty = false;
      const countries = displayedCountries();
      const hovering = Boolean(hoverRow);
      const heatmap = array(element.data).findIndex(trace => trace.type === "heatmap");
      Promise.resolve(hoverTraces()).then(function () {
        if (!active || heatmap < 0) return;
        const opacity = hovering ? 0.3 : 1;
        if (element.data[heatmap].opacity !== opacity) return root.Plotly.restyle(element, {opacity:opacity}, [heatmap]);
      }).then(function () {
        if (active) return selectedLabelColors(hovering);
      }).then(function () {
        if (!active) return;
        return root.Plotly.relayout(element, {annotations:annotations(countries), shapes:shapes(countries, hovering),
          "xaxis.showgrid":false});
      }).catch(function (error) {
        if (active && root.console && root.console.warn) root.console.warn("Ranking highlight:", error);
      }).finally(function () {
        rendering = false;
        if (active && dirty) schedule();
      });
    }
    function schedule() {
      if (!active) return;
      if (rendering) { dirty = true; return; }
      if (pendingFrame == null) pendingFrame = frame(render);
    }
    function setHover(row) {
      if (!active) return;
      const previous = hoverRow;
      hoverRow = row || null;
      state.hoverCountry = hoverRow ? hoverRow.country : null;
      state.hoverYear = hoverRow ? hoverRow.year : null;
      element.dataset.rankingHoverCountry = hoverRow ? hoverRow.country : "";
      if (hoverRow) element.dataset.rankingHoverYear = String(hoverRow.year);
      else delete element.dataset.rankingHoverYear;
      if (!previous || !hoverRow || previous.country !== hoverRow.country || previous.year !== hoverRow.year) announce();
      if ((!previous && hoverRow) || (previous && !hoverRow) ||
        (previous && hoverRow && previous.country !== hoverRow.country)) schedule();
    }
    function clearHover() { setHover(null); }
    function focusCountry(country, year) {
      const row = rowFor(country, year);
      setHover(row);
      return row;
    }
    function pointerRow(event) {
      const layout = element._fullLayout;
      if (!layout || !layout.xaxis || !layout.yaxis) return;
      const bounds = element.getBoundingClientRect();
      const scaleX = bounds.width ? element.clientWidth / bounds.width : 1;
      const scaleY = bounds.height ? element.clientHeight / bounds.height : 1;
      const x = (event.clientX - bounds.left) * scaleX - layout.xaxis._offset;
      const y = (event.clientY - bounds.top) * scaleY - layout.yaxis._offset;
      pointerInside = x >= 0 && x <= layout.xaxis._length && y >= 0 && y <= layout.yaxis._length;
      if (!pointerInside) return null;
      const year = Math.round(layout.xaxis.p2d(x));
      const rank = Math.round(layout.yaxis.p2d(y));
      return cellFor(year, rank)[0] || null;
    }
    function pointer(event) {
      if (gesture && event.pointerId === gesture.id &&
        Math.hypot(event.clientX - gesture.x, event.clientY - gesture.y) > 7) gesture.moved = true;
      setHover(pointerRow(event));
    }
    function addCountry(row) {
      if (!row || !root.document || !payload.countriesInputId) return false;
      const input = root.document.getElementById(payload.countriesInputId);
      if (!input) return false;
      if (input.selectize) {
        const control = input.selectize;
        const current = array(control.items || control.getValue()).map(String);
        if (current.includes(row.country)) return false;
        control.addItem(row.country);
        return true;
      }
      const option = Array.from(input.options || []).find(item => item.value === row.country);
      if (!option || option.selected) return false;
      option.selected = true;
      if (root.jQuery) root.jQuery(input).trigger("change");
      else input.dispatchEvent(new root.Event("change", {bubbles:true}));
      return true;
    }
    function click(event) {
      if (event.button !== 0 || !gesture || gesture.cancelled || gesture.moved ||
        Date.now() - gesture.started > 1500) return;
      const row = pointerRow(event);
      gesture = null;
      if (!row) return;
      setHover(row);
      addCountry(row);
    }
    function pointerDown(event) {
      if (event.button !== 0) { gesture = null; return; }
      gesture = {id:event.pointerId, x:event.clientX, y:event.clientY, moved:false,
        cancelled:false, started:Date.now()};
      pointer(event);
    }
    function pointerUp(event) {
      if (gesture && event.pointerId === gesture.id &&
        Math.hypot(event.clientX - gesture.x, event.clientY - gesture.y) > 7) gesture.moved = true;
    }
    function pointerCancel() {
      if (gesture) gesture.cancelled = true;
      pointerInside = false;
      clearHover();
    }
    function leave(event) {
      if (event && event.pointerType === "touch") return;
      pointerInside = false;
      clearHover();
    }
    function plotHover(event) {
      if (pointerInside) return;
      const point = event && event.points && event.points[0];
      if (!point) return;
      const candidates = cellFor(Math.round(Number(point.x)), Math.round(Number(point.y)));
      if (candidates.length) setHover(candidates[0]);
    }
    function plotUnhover() { if (!pointerInside) clearHover(); }
    function keydown(event) {
      if (event.key === "Escape") { clearHover(); return; }
      if (event.target === element && ["Enter", " ", "Spacebar"].includes(event.key)) {
        event.preventDefault();
        if (!event.repeat) addCountry(hoverRow);
        return;
      }
      if (event.target !== element || !["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(event.key)) return;
      event.preventDefault();
      const current = hoverRow || rowFor(Array.from(selected)[0]) || rows.find(row => row.year === years[years.length - 1]);
      if (!current) return;
      let year = current.year;
      let rank = current.rank;
      let direction = 0;
      if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
        const index = years.indexOf(year) + (event.key === "ArrowRight" ? 1 : -1);
        year = years[Math.max(0, Math.min(years.length - 1, index))];
        const sameCountry = byCountry.get(current.country).get(year);
        if (sameCountry) { setHover(sameCountry); return; }
      } else {
        direction = event.key === "ArrowDown" ? 1 : -1;
        rank += direction;
      }
      const available = rows.filter(row => row.year === year &&
        (!direction || direction > 0 && row.rank > current.rank || direction < 0 && row.rank < current.rank)).sort((a, b) =>
        Math.abs(a.rank - rank) - Math.abs(b.rank - rank) || a.rank - b.rank || a.country.localeCompare(b.country));
      if (available.length) setHover(cellFor(year, available[0].rank)[0]);
    }
    function afterPlot() {
      const layout = element._fullLayout;
      if (!layout || !layout.xaxis || !layout.yaxis) return;
      const next = [layout.width, layout.height, layout.xaxis._length, layout.yaxis._length].join("|");
      if (geometry && geometry !== next) schedule();
      geometry = next;
    }

    const state = {payload:payload, hoverCountry:null, hoverYear:null, focusCountry:focusCountry,
      clearHover:clearHover, rowsForCountry:country => Array.from((byCountry.get(country) || new Map()).values()),
      destroy:function () {
        active = false;
        if (pendingFrame != null) cancelFrame(pendingFrame);
        element.removeEventListener("pointermove", pointer);
        element.removeEventListener("pointerdown", pointerDown);
        element.removeEventListener("pointerup", pointerUp);
        element.removeEventListener("pointercancel", pointerCancel);
        element.removeEventListener("pointerleave", leave);
        element.removeEventListener("click", click, true);
        element.removeEventListener("keydown", keydown);
        if (typeof element.removeListener === "function") {
          element.removeListener("plotly_hover", plotHover);
          element.removeListener("plotly_unhover", plotUnhover);
          element.removeListener("plotly_afterplot", afterPlot);
        }
      }};
    element._wlvRanking = state;
    element.dataset.rankingHoverCountry = "";
    element.setAttribute("tabindex", "0");
    element.setAttribute("aria-label", root.wlvI18n.text("Ranking dos países ao longo do tempo. Passe o mouse para explorar; clique para adicionar um país à comparação. Use as setas para explorar, Enter ou Espaço para adicionar e Escape para limpar o destaque.", "Country ranking over time. Hover to explore; click to add a country to the comparison. Use arrow keys to explore, Enter or Space to add, and Escape to clear the highlight."));
    if (readout) { readout.setAttribute("aria-live", "polite"); readout.setAttribute("aria-atomic", "true"); }
    announce();
    element.addEventListener("pointermove", pointer);
    element.addEventListener("pointerdown", pointerDown);
    element.addEventListener("pointerup", pointerUp);
    element.addEventListener("pointercancel", pointerCancel);
    element.addEventListener("pointerleave", leave);
    element.addEventListener("click", click, true);
    element.addEventListener("keydown", keydown);
    if (typeof element.on === "function") {
      element.on("plotly_hover", plotHover);
      element.on("plotly_unhover", plotUnhover);
      element.on("plotly_afterplot", afterPlot);
    }
    afterPlot();
    schedule();
    return state;
  }

  const api = {attach:attach};
  root.WLVIndicatorRanking = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
})(typeof window !== "undefined" ? window : globalThis);
