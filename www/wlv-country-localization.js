/* Keep country-chart geometry and map-indicator controls while relabelling. */
(function (root) {
  'use strict';

  function asArray(value) { return Array.isArray(value) ? value : value == null ? [] : [value]; }
  function text(node, value) {
    if (node && node.textContent !== String(value)) node.textContent = String(value);
  }
  function attribute(node, name, value) {
    if (node && node.getAttribute(name) !== String(value)) node.setAttribute(name, String(value));
  }
  function legendText(node, value) {
    if (!node) return;
    // The existing anonymous flex item stays a text node: no wrapper changes
    // wrapping, spacing, swatches, or the original DOM's focusable elements.
    const label = Array.from(node.childNodes).find(child => child.nodeType === 3 && child.nodeValue.trim());
    if (label && label.nodeValue.trim() !== value) {
      const before = label.nodeValue.match(/^\s*/)[0], after = label.nodeValue.match(/\s*$/)[0];
      label.nodeValue = before + value + after;
    }
  }
  function applyChartText(chart, message) {
    if (!chart || chart.getAttribute('data-wlv-chart-id') !== message.id) return false;
    if (chart.classList.contains('wlv-country-chart-empty')) {
      text(chart, message.empty);
      return true;
    }
    text(chart.querySelector('svg > title'), message.title);
    text(chart.querySelector('svg > desc'), message.description);
    const ticks = asArray(message.ticks), legend = asArray(message.legend);
    chart.querySelectorAll('.wlv-country-chart-tick-y').forEach((node, index) => text(node, ticks[index]));
    const frame = chart.querySelector('.wlv-country-chart-frame');
    if (frame && frame.style.getPropertyValue('--wlv-chart-y-chars') !== String(message.y_chars)) {
      frame.style.setProperty('--wlv-chart-y-chars', String(message.y_chars));
    }
    const observations = new Map(asArray(message.observations).map(item => [String(item.year), item.text]));
    chart.querySelectorAll('.wlv-country-chart-observation').forEach(function (node) {
      const value = observations.get(node.getAttribute('data-year'));
      if (value === undefined) return;
      attribute(node, 'aria-label', value);
      text(node.querySelector('title'), value);
    });
    chart.querySelectorAll('.wlv-country-chart-legend-item').forEach((node, index) => legendText(node, legend[index]));
    text(chart.querySelector('.wlv-country-chart-note'), message.note);
    return true;
  }
  function mergeMapDelta(previous, message) {
    const reset = !previous || message.reset || previous.instance !== message.instance;
    const layers = reset ? new Map() : new Map(previous.layers);
    asArray(message.layers).forEach(layer => layers.set(String(layer.id), layer));
    return {instance: message.instance, layers: layers};
  }

  const api = {applyChartText: applyChartText, mergeMapDelta: mergeMapDelta};
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (!root.document) return;
  const pendingCharts = new Map(), mapStates = new Map();
  let registered = false;
  function applyPendingCharts() {
    const lang = root.document.documentElement.lang;
    pendingCharts.forEach(function (entry, output) {
      if (entry.lang !== lang) return;
      const container = root.document.getElementById(output);
      if (container) applyChartText(container.querySelector('[data-wlv-chart-id]'), entry.chart);
    });
  }
  function syncMapLabels() {
    const container = root.document.getElementById('map_indicator_list');
    if (!container || !root.wlvI18n) return;
    // Visible labels use the shared dictionary; help controls retain their
    // exact accessible name even when an update precedes list insertion.
    container.querySelectorAll('[data-wlv-label]').forEach(node =>
      text(node, root.wlvI18n.label(node.getAttribute('data-wlv-label'))));
    container.querySelectorAll('[data-indicator-info]').forEach(function (node) {
      const name = root.wlvI18n.label(node.getAttribute('data-indicator-info'));
      attribute(node, 'aria-label', root.wlvI18n.text('Sobre', 'About') + ' ' + name);
    });
  }
  function register() {
    if (registered || !root.Shiny || !root.Shiny.addCustomMessageHandler) return;
    registered = true;
    root.Shiny.addCustomMessageHandler('wlv-country-chart-text', function (message) {
      asArray(message.charts).forEach(chart => pendingCharts.set(chart.output, {lang: message.lang, chart: chart}));
      applyPendingCharts();
    });
    root.Shiny.addCustomMessageHandler('wlv-map-delta', function (message) {
      const state = mergeMapDelta(mapStates.get(message.id), message);
      mapStates.set(message.id, state);
      if (root.WLVMap) root.WLVMap.receive({id: message.id, layers: Array.from(state.layers.values())});
    });
  }
  function initialize() {
    register();
    ['co_entry_labour_chart', 'co_entry_trade_chart'].forEach(function (id) {
      const node = root.document.getElementById(id);
      if (node) new MutationObserver(applyPendingCharts).observe(node, {childList: true, subtree: true});
    });
    const mapList = root.document.getElementById('map_indicator_list');
    if (mapList) new MutationObserver(syncMapLabels).observe(mapList, {childList: true, subtree: true});
    new MutationObserver(function () {
      applyPendingCharts();
      syncMapLabels();
    }).observe(root.document.documentElement, {attributes: true, attributeFilter: ['lang']});
    syncMapLabels();
    if (root.jQuery) root.jQuery(root.document).on('shiny:connected.wlvCountryLocalization', register);
  }
  if (root.document.readyState === 'loading') root.document.addEventListener('DOMContentLoaded', initialize, {once: true});
  else initialize();
})(typeof window !== 'undefined' ? window : globalThis);
