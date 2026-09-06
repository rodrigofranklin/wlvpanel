(function () {
  'use strict';
  function snapYear(years, value, previous) {
    if (years.includes(value)) return value;
    // Teclado e animação precisam ultrapassar lacunas, sem voltar sempre
    // ao mesmo ano. Uma nova cobertura, sem direção, usa o mais próximo.
    if (previous !== undefined && value > previous) return years.find(year => year >= value) ?? years[years.length - 1];
    if (previous !== undefined && value < previous) return years.slice().reverse().find(year => year <= value) ?? years[0];
    return years.reduce((best, year) => Math.abs(year - value) < Math.abs(best - value) ? year : best, years[0]);
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = {snapYear};
  if (typeof document === 'undefined') return;
  function initialize() {
    const layout = document.querySelector('.wlv-map-layout');
    if (!layout) return;
    const search = document.getElementById('map-indicator-search');
    const selected = document.getElementById('co_select_indicator');
    const yearInput = document.getElementById('co_select_year');
    let years = [], lastYear;
    window.Shiny.addCustomMessageHandler('wlv-map-years', function (message) {
      // Discard a previous source/indicator response after a newer choice.
      const method = document.getElementById('co_map_method');
      if ((method.value && method.value !== message.method) ||
          (selected.value && selected.value !== message.indicator)) return;
      const values = Array.isArray(message.years) ? message.years : [message.years];
      years = values.map(Number).filter(Number.isFinite).sort((a, b) => a - b);
      const slider = window.jQuery(yearInput).data('ionRangeSlider');
      if (!years.length || !slider) return;
      const previous = slider.result.from;
      const year = snapYear(years, previous);
      slider.update({min:years[0], max:years[years.length - 1], from:year});
      lastYear = year;
      const label = document.getElementById('co_select_year-label');
      if (label) label.textContent = message.label;
      if (year !== previous) window.jQuery(yearInput).trigger('change');
    });
    window.jQuery(yearInput).on('change.wlv-map-year', function () {
      const slider = window.jQuery(yearInput).data('ionRangeSlider');
      if (!slider || !years.length) return;
      const current = slider.result.from;
      const year = snapYear(years, current, lastYear);
      lastYear = year;
      if (year !== current) {
        slider.update({from:year});
        window.jQuery(yearInput).trigger('change');
      }
    });
    const mobile = () => window.matchMedia('(max-width: 767px)').matches;
    let opener;
    const normalize = text => text.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
    function filter() {
      const query = normalize(search.value.trim());
      layout.querySelectorAll('.wlv-map-indicator-group').forEach(function (group) {
        let count = 0;
        group.querySelectorAll('[data-indicator]').forEach(function (button) {
          button.hidden = !normalize(button.textContent + ' ' + button.dataset.indicator).includes(query);
          if (!button.hidden) count += 1;
        });
        group.hidden = count === 0;
        if (query) group.open = count > 0;
      });
    }
    function sync() {
      const code = selected.selectize ? selected.selectize.getValue() : selected.value;
      let label;
      layout.querySelectorAll('[data-indicator]').forEach(function (button) {
        const active = button.dataset.indicator === code;
        button.setAttribute('aria-pressed', String(active));
        if (active) { label = button.textContent; button.closest('details').open = true; }
      });
      const title = document.getElementById('map-current-indicator');
      if (label && title.textContent !== label) title.textContent = label;
      filter();
    }
    function close(restoreFocus) {
      delete layout.dataset.sheet;
      layout.querySelectorAll('[data-map-sheet]').forEach(button => button.setAttribute('aria-expanded', 'false'));
      if (restoreFocus && opener) opener.focus();
    }
    layout.addEventListener('click', function (event) {
      const option = event.target.closest('[data-indicator]');
      if (option) {
        selected.selectize.setValue(option.dataset.indicator);
        if (mobile()) close(true);
        sync();
      }
      const button = event.target.closest('[data-map-sheet]');
      if (button) {
        const sheet = button.dataset.mapSheet;
        const wasOpen = layout.dataset.sheet === sheet;
        close(false);
        if (!wasOpen) {
          opener = button;
          layout.dataset.sheet = sheet;
          button.setAttribute('aria-expanded', 'true');
          if (sheet === 'legend') {
            const legend = layout.querySelector('.wlv-map-legend');
            if (legend) legend.open = true;
          }
          if (sheet === 'indicators') search.focus();
        }
      }
      if (event.target.closest('[data-map-close]')) close(true);
      if (event.target.closest('#map-world-button')) {
        close(false);
        if (window.WLVMap) window.WLVMap.fitWorld('map');
      }
    });
    layout.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && layout.dataset.sheet) { event.preventDefault(); close(true); }
    });
    search.addEventListener('input', filter);
    window.jQuery(selected).on('change', sync);
    new MutationObserver(sync).observe(document.getElementById('map_indicator_list'), { childList:true, subtree:true });
    window.matchMedia('(max-width: 767px)').addEventListener('change', () => close(false));
    sync();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
})();
