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
    function expandGroup(group, expanded) {
      const header = group.querySelector('.wlv-map-group-header');
      const body = group.querySelector('.wlv-map-group-body');
      header.setAttribute('aria-expanded', String(expanded));
      body.dataset.expanded = String(expanded);
      body.inert = !expanded;
      body.setAttribute('aria-hidden', String(!expanded));
      body.style.setProperty('--wlv-group-height', body.scrollHeight + 'px');
    }
    function openGroup(group) {
      layout.querySelectorAll('.wlv-map-indicator-group').forEach(function (item) {
        expandGroup(item, item === group);
      });
    }
    function sync() {
      const code = selected.selectize ? selected.selectize.getValue() : selected.value;
      let label;
      layout.querySelectorAll('.wlv-map-indicator-group').forEach(function (group) {
        expandGroup(group, group.querySelector('.wlv-map-group-header').getAttribute('aria-expanded') === 'true');
      });
      document.getElementById('inputs_panel').setAttribute('aria-label',
        document.documentElement.lang === 'en' ? 'Indicators' : 'Indicadores');
      layout.querySelectorAll('[data-indicator]').forEach(function (button) {
        const active = button.dataset.indicator === code;
        button.setAttribute('aria-pressed', String(active));
        if (active) {
          label = button.closest('.wlv-map-indicator-row').querySelector('.wlv-map-indicator-label').textContent;
          openGroup(button.closest('.wlv-map-indicator-group'));
        }
      });
      const title = document.getElementById('map-current-indicator');
      if (label && title.textContent !== label) title.textContent = label;
    }
    function close(restoreFocus) {
      delete layout.dataset.sheet;
      layout.querySelectorAll('[data-map-sheet]').forEach(button => button.setAttribute('aria-expanded', 'false'));
      if (mobile()) {
        const legend = layout.querySelector('.wlv-map-legend');
        if (legend) legend.open = false;
      }
      if (restoreFocus && opener) opener.focus();
    }
    layout.addEventListener('click', function (event) {
      const help = event.target.closest('[data-indicator-info]');
      if (help) {
        window.Shiny.setInputValue('map_show_indicator_info', help.dataset.indicatorInfo, {priority:'event'});
        return;
      }
      const header = event.target.closest('.wlv-map-group-header');
      if (header) {
        const group = header.closest('.wlv-map-indicator-group');
        if (header.getAttribute('aria-expanded') === 'true') expandGroup(group, false);
        else openGroup(group);
      }
      const row = event.target.closest('[data-indicator-code]');
      if (row) {
        if (selected.selectize) selected.selectize.setValue(row.dataset.indicatorCode);
        else window.jQuery(selected).val(row.dataset.indicatorCode).trigger('change');
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
          if (sheet === 'indicators') {
            const current = layout.querySelector('[data-indicator][aria-pressed="true"]');
            if (current) current.focus();
          }
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
    window.jQuery(selected).on('change', sync);
    new MutationObserver(sync).observe(document.getElementById('map_indicator_list'), { childList:true, subtree:true });
    window.matchMedia('(max-width: 767px)').addEventListener('change', () => close(false));
    function measureGroups() {
      layout.querySelectorAll('.wlv-map-group-body').forEach(function (body) {
        body.style.setProperty('--wlv-group-height', body.scrollHeight + 'px');
      });
    }
    new ResizeObserver(measureGroups).observe(document.getElementById('inputs_panel'));
    if (document.fonts) document.fonts.ready.then(measureGroups);
    sync();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
})();
