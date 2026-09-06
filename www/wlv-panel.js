(function () {
  'use strict';
  var dictionary = {}, currentLanguage = 'Português', scheduled = false;
  function translate() {
    scheduled = false;
    document.querySelectorAll('[data-wlv-label]').forEach(function (node) {
      var value = dictionary[node.getAttribute('data-wlv-label')];
      if (typeof value === 'string' && node.textContent !== value) node.textContent = value;
    });
  }
  function resize() {
    var nav = document.querySelector('.navbar');
    if (nav) document.documentElement.style.setProperty('--wlv-nav-height', nav.offsetHeight + 'px');
    var active = document.querySelector('#main_nav li.active > a[data-value]');
    if (active) document.body.dataset.wlvTab = active.dataset.value;
    window.dispatchEvent(new Event('resize'));
  }
  function receiveLanguage(message) {
    currentLanguage = message.lang;
    dictionary = message.labels;
    var english = currentLanguage === 'English';
    document.documentElement.lang = english ? 'en' : 'pt-BR';
    var button = document.getElementById('language_toggle');
    if (button) {
      button.textContent = english ? 'Português' : 'English';
      button.lang = english ? 'pt-BR' : 'en';
      button.setAttribute('aria-label', english ? 'Mudar para português' : 'Switch to English');
    }
    var toggle = document.querySelector('.navbar-toggle');
    if (toggle) toggle.setAttribute('aria-label', english ? 'Open navigation' : 'Abrir navegação');
    var settings = document.getElementById('settings_toggle');
    if (settings) settings.setAttribute('aria-label', english ? 'Settings' : 'Configurações');
    translate();
  }
  function initialize() {
    document.documentElement.lang = 'pt-BR';
    var button = document.getElementById('language_toggle');
    var nav = document.querySelector('.navbar .container-fluid');
    if (button && nav) nav.appendChild(button);
    var settings = document.getElementById('wlv-settings');
    if (settings && nav) nav.appendChild(settings);
    document.addEventListener('click', function (event) {
      if (settings && !settings.contains(event.target)) settings.open = false;
      if (settings && event.target.closest('#info_bases')) settings.open = false;
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && settings && settings.open) {
        settings.open = false;
        document.getElementById('settings_toggle').focus();
      }
    });
    if (button) button.addEventListener('click', function () {
      var input = document.getElementById('l');
      input.value = input.value === 'English' ? 'Português' : 'English';
      window.jQuery(input).trigger('change');
    });
    Shiny.addCustomMessageHandler('wlv-language', receiveLanguage);
    new MutationObserver(function () {
      if (!scheduled) { scheduled = true; requestAnimationFrame(translate); }
    }).observe(document.body, {childList: true, subtree: true});
    var navbar = document.querySelector('.navbar');
    if (window.ResizeObserver && navbar) new ResizeObserver(function () {
      document.documentElement.style.setProperty('--wlv-nav-height', navbar.offsetHeight + 'px');
    }).observe(navbar);
    var toolbar = document.querySelector('.wlv-toolbar');
    if (toolbar && window.ResizeObserver) new ResizeObserver(function () {
      document.documentElement.style.setProperty('--wlv-toolbar-height', toolbar.offsetHeight + 'px');
    }).observe(toolbar);
    window.jQuery(document).on('shown.bs.tab shown.bs.collapse hidden.bs.collapse', resize);
    window.jQuery(document).on('click', '#main_nav a[data-value]', function () {
      var menu = document.querySelector('.navbar-collapse');
      if (!menu || !window.matchMedia('(max-width: 767px)').matches) return;
      if (menu.classList.contains('in')) window.jQuery(menu).collapse('hide');
      else if (menu.classList.contains('collapsing') && document.querySelector('.navbar-toggle').getAttribute('aria-expanded') === 'true') {
        window.jQuery(menu).one('shown.bs.collapse', function () { window.jQuery(menu).collapse('hide'); });
      }
    });
    resize();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
})();
