(function () {
  'use strict';
  var dictionary = {}, currentLanguage = 'Português', scheduled = false;
  var navigationCookie = 'wlv_last_tab';
  function navigationLink(value) {
    return Array.from(document.querySelectorAll('#main_nav a[data-value]')).find(function (link) {
      return link.dataset.value === value;
    });
  }
  function readNavigation() {
    try {
      var entry = document.cookie.split(';').map(function (item) { return item.trim(); }).find(function (item) {
        return item.indexOf(navigationCookie + '=') === 0;
      });
      var value = entry ? decodeURIComponent(entry.substring(navigationCookie.length + 1)) : '';
      return navigationLink(value) ? value : 'about';
    } catch (_) { return 'about'; }
  }
  function saveNavigation(value) {
    if (!navigationLink(value)) return;
    try {
      var path = window.location.pathname.replace(/\/+$/, '') || '/';
      document.cookie = navigationCookie + '=' + encodeURIComponent(value) +
        '; Path=' + path + '; Max-Age=31536000; SameSite=Lax' +
        (window.location.protocol === 'https:' ? '; Secure' : '');
    } catch (_) { /* A navegação continua disponível se cookies forem bloqueados. */ }
  }
  function updateHeaderSize() {
    var topbar = document.querySelector('.wlv-topbar');
    var nav = document.querySelector('.navbar');
    var topbarHeight = topbar ? topbar.offsetHeight : 0;
    document.documentElement.style.setProperty('--wlv-topbar-height', topbarHeight + 'px');
    if (nav) document.documentElement.style.setProperty('--wlv-nav-height', (topbarHeight + nav.offsetHeight) + 'px');
  }
  function updateCurrentPage() {
    var active = document.querySelector('#main_nav li.active > a[data-value]');
    var current = document.getElementById('wlv-mobile-current');
    if (!active) return;
    document.body.dataset.wlvTab = active.dataset.value;
    var label = active.textContent.trim();
    if (current && current.textContent !== label) current.textContent = label;
  }
  function translate() {
    scheduled = false;
    document.querySelectorAll('[data-wlv-label]').forEach(function (node) {
      var value = dictionary[node.getAttribute('data-wlv-label')];
      if (typeof value === 'string' && node.textContent !== value) node.textContent = value;
    });
    updateCurrentPage();
  }
  function resize() {
    updateHeaderSize();
    updateCurrentPage();
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
    var scrollport = document.querySelector('body > .container-fluid');
    if (scrollport) {
      scrollport.id = 'wlv-page-scroll';
      scrollport.classList.add('wlv-page-scroll');
    }
    // Seleciona a aba antes da vinculação inicial dos inputs do Shiny.
    var initialLink = navigationLink(readNavigation());
    if (initialLink) window.jQuery(initialLink).tab('show');
    window.jQuery(document).on('shown.bs.tab.wlvNavigation', '#main_nav a[data-value]', function (event) {
      saveNavigation(event.target.dataset.value);
      if (scrollport) scrollport.scrollTop = 0;
    });
    window.jQuery(document).one('shiny:connected.wlvNavigation', function () {
      var active = document.querySelector('#main_nav li.active > a[data-value]');
      if (active) {
        Shiny.setInputValue('main_nav', active.dataset.value, {priority:'event'});
        saveNavigation(active.dataset.value);
      }
    });
    var button = document.getElementById('language_toggle');
    var settings = document.getElementById('wlv-settings');
    var nav = document.querySelector('.navbar');
    var menu = document.querySelector('.navbar-collapse');
    var toggle = document.querySelector('.navbar-toggle');
    if (toggle) toggle.setAttribute('aria-label', 'Abrir navegação');
    var currentLink = document.querySelector('.navbar-brand');
    if (currentLink && toggle && menu) {
      currentLink.setAttribute('role', 'button');
      currentLink.setAttribute('aria-controls', menu.id);
      currentLink.setAttribute('aria-expanded', 'false');
      currentLink.addEventListener('keydown', function (event) {
        if (event.key !== ' ' || !window.matchMedia('(max-width: 767px)').matches) return;
        event.preventDefault();
        window.jQuery(menu).collapse('toggle');
      });
    }
    document.addEventListener('click', function (event) {
      if (settings && !settings.contains(event.target)) settings.open = false;
      if (settings && event.target.closest('#info_bases')) settings.open = false;
      if (nav && menu && !nav.contains(event.target) && menu.classList.contains('in')) window.jQuery(menu).collapse('hide');
    });
    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape' && settings && settings.open) {
        settings.open = false;
        document.getElementById('settings_toggle').focus();
      }
      if (event.key === 'Escape' && menu && menu.classList.contains('in')) {
        window.jQuery(menu).collapse('hide');
        if (toggle) toggle.focus();
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
    if (window.ResizeObserver) {
      var headerObserver = new ResizeObserver(updateHeaderSize);
      if (nav) headerObserver.observe(nav);
      var topbar = document.querySelector('.wlv-topbar');
      if (topbar) headerObserver.observe(topbar);
    }
    window.addEventListener('resize', updateHeaderSize);
    var toolbar = document.querySelector('.wlv-toolbar');
    if (toolbar && window.ResizeObserver) new ResizeObserver(function () {
      document.documentElement.style.setProperty('--wlv-toolbar-height', toolbar.offsetHeight + 'px');
    }).observe(toolbar);
    window.jQuery(document).on('shown.bs.tab shown.bs.collapse hidden.bs.collapse', resize);
    window.jQuery(menu).on('shown.bs.collapse hidden.bs.collapse', function () {
      if (currentLink) currentLink.setAttribute('aria-expanded', menu.classList.contains('in') ? 'true' : 'false');
    });
    window.jQuery('.navbar > .container-fluid').on('click', function (event) {
      if (!menu || !window.matchMedia('(max-width: 767px)').matches || event.target.closest('.navbar-toggle, .navbar-collapse')) return;
      event.preventDefault();
      window.jQuery(menu).collapse('toggle');
    });
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
