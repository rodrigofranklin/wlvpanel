(function () {
  'use strict';
  function initialize() {
    var page = document.getElementById('wlv-country-page');
    if (!page) return;
    var entry = document.getElementById('wlv-country-entry');
    if (entry) {
      var content = entry.querySelector('.wlv-entry-content');
      var loading = entry.querySelector('.wlv-entry-loading');
      var required = ['co_entry_description', 'co_entry_facts', 'co_entry_source',
        'co_entry_labour_chart', 'co_entry_trade_chart', 'co_entry_labour_title',
        'co_entry_labour_unit', 'co_entry_trade_title', 'co_entry_trade_unit',
        'co_entry_globe_title', 'co_entry_catalogue_label', 'co_entry_formulas_label'];
      var revealFrame = 0;
      function revealWhenReady() {
        revealFrame = 0;
        if (entry.dataset.state === 'ready') return;
        var country = document.getElementById('co_select_country');
        var method = document.getElementById('co_entry_method');
        var globe = document.getElementById('wlv-country-globe');
        var complete = required.every(function (id) {
          var node = document.getElementById(id);
          // Explicit empty-data and error messages are also completed outputs.
          return node && (node.textContent.trim() || node.classList.contains('shiny-output-error')) &&
            !node.classList.contains('recalculating');
        });
        if (!complete || !country || !country.value || !method || !method.value ||
            !globe || globe.dataset.received !== 'true' ||
            globe.dataset.selected !== country.value ||
            !['true', 'error'].includes(globe.dataset.ready)) return;
        observer.disconnect();
        entry.removeEventListener('change', scheduleReveal);
        if (window.jQuery) window.jQuery(document).off('.wlvCountryLoading');
        content.removeAttribute('inert');
        content.removeAttribute('aria-hidden');
        loading.hidden = true;
        entry.dataset.state = 'ready';
        content.setAttribute('aria-busy', 'false');
        window.dispatchEvent(new Event('resize'));
      }
      function scheduleReveal() {
        if (!revealFrame) revealFrame = requestAnimationFrame(revealWhenReady);
      }
      function loadingLanguage() {
        entry.setAttribute('aria-label', window.wlvI18n.text('Visão geral do país', 'Country overview'));
        loading.querySelector('.wlv-entry-loading-label').textContent =
          window.wlvI18n.text('Carregando o país…', 'Loading the country…');
      }
      var observer = new MutationObserver(scheduleReveal);
      observer.observe(content, { childList: true, subtree: true, characterData: true,
        attributes: true, attributeFilter: ['class', 'data-ready', 'data-received', 'data-selected'] });
      var languageObserver = new MutationObserver(loadingLanguage);
      languageObserver.observe(document.documentElement, { attributes: true, attributeFilter: ['lang'] });
      loadingLanguage();
      entry.addEventListener('change', scheduleReveal);
      if (window.jQuery) window.jQuery(document).on('shiny:idle.wlvCountryLoading shiny:value.wlvCountryLoading', scheduleReveal);
      scheduleReveal();
    }
    function showDetails() {
      var target = document.getElementById('wlv-country-detail');
      if (!target || !target.getClientRects().length) return;
      target.focus({ preventScroll: true });
      target.scrollIntoView({
        behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth',
        block: 'start'
      });
    }
    page.addEventListener('click', function (event) {
      var option = event.target.closest('[data-wlv-country]');
      if (option && window.Shiny) {
        Shiny.setInputValue('co_catalogue_country', option.dataset.wlvCountry, { priority: 'event' });
        var catalogue = document.getElementById('wlv-country-catalogue');
        if (catalogue) catalogue.open = false;
        document.getElementById('wlv-country-entry').scrollIntoView({ block: 'start' });
        var select = document.getElementById('co_select_country');
        if (select && select.selectize) select.selectize.focus();
      }
      if (event.target.closest('#co_entry_more')) {
        showDetails();
      }
    });
    function overview(message) {
      var entry = document.getElementById('wlv-country-entry');
      if (entry) entry.scrollIntoView({ block: 'start' });
      var select = document.getElementById('co_select_country');
      if (select && select.selectize) select.selectize.focus();
    }
    function registerOverview() {
      if (window.Shiny) Shiny.addCustomMessageHandler('wlv-country-overview', overview);
    }
    registerOverview();
    if (window.jQuery) window.jQuery(document).on('shiny:connected.wlvCountry', registerOverview);
    // Bootstrap supplies keyboard activation, aria-expanded and the height
    // transition. Its shown/hidden events also trigger the shared Shiny and
    // HTMLWidgets resize handler in wlv-panel.js.
    if (window.jQuery) {
      window.jQuery(page).on('hide.bs.collapse show.bs.collapse', '.wlv-country-group-content', function (event) {
        var closing = event.type === 'hide';
        if (closing && this.contains(document.activeElement)) {
          var toggle = document.getElementById(this.getAttribute('aria-labelledby'));
          if (toggle) toggle.focus({ preventScroll: true });
        }
        this.toggleAttribute('inert', closing);
        this.setAttribute('aria-hidden', closing ? 'true' : 'false');
      });
    }
    var detail = document.getElementById('wlv-country-content');
    if (!detail) return;
    var wasOpen = detail.getClientRects().length > 0;
    new MutationObserver(function () {
      // Shiny can switch conditional panels through classes or inline styles.
      var open = detail.getClientRects().length > 0;
      if (open === wasOpen) return;
      wasOpen = open;
      requestAnimationFrame(function () {
        if (!page.getClientRects().length) return;
        if (open) showDetails();
        window.dispatchEvent(new Event('resize'));
      });
    }).observe(detail, { attributes: true, attributeFilter: ['style', 'class', 'hidden'] });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
})();
