(function () {
  'use strict';
  var initialLanguage = window.wlvInitialLanguage || {};
  var languageFingerprint = initialLanguage.fingerprint || '', languageConnection = 0;
  var dictionary = initialLanguage.labels || {}, phraseDictionary = initialLanguage.phrases || {};
  var currentLanguage = initialLanguage.language || 'Português', targetLanguage = 'English', scheduled = false;
  function languages() {
    return (window.wlvInitialLanguage || initialLanguage).languages || [
      {value:'English',key:'en',code:'en'}, {value:'Castellano',key:'es',code:'es'},
      {value:'中文',key:'zh',code:'zh-CN'}, {value:'Português',key:'pt',code:'pt-BR'}
    ];
  }
  function languageEntry(value) {
    var name = String(value || currentLanguage), normalized = name.toLowerCase(), base = normalized.split(/[-_]/)[0];
    return languages().find(function (entry) { return entry.value === name || entry.code.toLowerCase() === normalized || entry.key === base; }) ||
      languages().find(function (entry) { return entry.key === 'pt'; });
  }
  function languageCode(value) {
    return languageEntry(value).key;
  }
  window.wlvI18n = {
    code: function (value) { return languageCode(value || currentLanguage); },
    locale: function (value) { return languageEntry(value).code; },
    text: function (pt, en, value) {
      var code = languageCode(value || currentLanguage);
      if (code === 'pt') return pt;
      if (code === 'en') return en;
      return phraseDictionary[en] && phraseDictionary[en][code] || en;
    },
    label: function (key, fallback) { return dictionary[key] || fallback || key; }
  };
  var tr = window.wlvI18n.text;
  function saveLanguage(value) {
    try {
      var path = window.location.pathname.replace(/\/+$/, '') || '/';
      document.cookie = 'wlv_language=' + languageCode(value) + '; Path=' + path +
        '; Max-Age=31536000; SameSite=Lax' + (window.location.protocol === 'https:' ? '; Secure' : '');
      var url = new URL(window.location.href);
      if (url.searchParams.has('lang')) {
        url.searchParams.set('lang', languageCode(value));
        window.history.replaceState(window.history.state, '', url.href);
      }
    } catch (_) { /* Manual switching also works when cookies are blocked. */ }
  }
  var navigationCookie = 'wlv_last_tab';
  function navigationLink(value) {
    return Array.from(document.querySelectorAll('#main_nav a[data-value]')).find(function (link) {
      return link.dataset.value === value;
    });
  }
  function readNavigation() {
    try {
      if (new URLSearchParams(window.location.search).get('trade_open') === '1' && navigationLink('trade')) return 'trade';
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
    if (message.phrases) phraseDictionary = message.phrases;
    languageFingerprint = message.fingerprint || '';
    var bootstrap = document.getElementById('wlv_language_bootstrap');
    if (bootstrap) bootstrap.value = languageFingerprint;
    document.documentElement.lang = window.wlvI18n.locale();
    updateLanguageTarget();
    var languageMenu = document.getElementById('language_menu_toggle');
    if (languageMenu) languageMenu.setAttribute('aria-label', tr('Escolher idioma', 'Choose language'));
    var toggle = document.querySelector('.navbar-toggle');
    if (toggle) toggle.setAttribute('aria-label', tr('Abrir navegação', 'Open navigation'));
    var settings = document.getElementById('settings_toggle');
    if (settings) settings.setAttribute('aria-label', tr('Configurações', 'Settings'));
    translate();
  }
  function updateLanguageTarget() {
    var button = document.getElementById('language_toggle');
    var option = Array.from(document.querySelectorAll('#language_menu [data-language]')).find(function (node) {
      return node.dataset.language === targetLanguage;
    });
    if (!button || !option) return;
    button.textContent = targetLanguage;
    button.lang = option.lang;
    button.dataset.language = targetLanguage;
    button.setAttribute('aria-label', tr('Mudar para ', 'Switch to ') + targetLanguage);
    document.querySelectorAll('#language_menu [data-language]').forEach(function (node) {
      node.setAttribute('aria-checked', node.dataset.language === targetLanguage ? 'true' : 'false');
    });
  }
  function initializeLanguageMenu() {
    var control = document.getElementById('wlv-language');
    var button = document.getElementById('language_toggle');
    var toggle = document.getElementById('language_menu_toggle');
    var menu = document.getElementById('language_menu');
    if (!control || !button || !toggle || !menu) return;
    var options = Array.from(menu.querySelectorAll('[role="menuitemradio"]'));
    var typeahead = '', typeaheadTimer;
    function closeMenu(returnFocus) {
      menu.hidden = true;
      toggle.setAttribute('aria-expanded', 'false');
      if (returnFocus) toggle.focus();
    }
    function openMenu(last) {
      menu.hidden = false;
      toggle.setAttribute('aria-expanded', 'true');
      var selected = options.find(function (option) { return option.dataset.language === targetLanguage; });
      (last ? options[options.length - 1] : selected || options[0]).focus();
    }
    function applyLanguage(value) {
      var option = options.find(function (item) { return item.dataset.language === value; });
      var input = document.getElementById('l');
      if (!option || option.dataset.available !== 'true' || !input) return;
      targetLanguage = value;
      saveLanguage(value);
      updateLanguageTarget();
      input.value = value;
      window.jQuery(input).trigger('change');
      closeMenu(false);
    }
    button.addEventListener('click', function () { applyLanguage(targetLanguage); });
    toggle.addEventListener('click', function () { if (menu.hidden) openMenu(false); else closeMenu(true); });
    toggle.addEventListener('keydown', function (event) {
      if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
      event.preventDefault();
      openMenu(event.key === 'ArrowUp');
    });
    menu.addEventListener('click', function (event) {
      var option = event.target.closest('[data-language]');
      if (!option || option.dataset.available !== 'true') return;
      applyLanguage(option.dataset.language);
      button.focus();
    });
    menu.addEventListener('keydown', function (event) {
      var index = options.indexOf(document.activeElement);
      if (event.key === 'Escape') { event.preventDefault(); closeMenu(true); return; }
      if (event.key === 'Tab') { closeMenu(false); return; }
      if (!['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
        if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey && event.key !== ' ') {
          typeahead += event.key.toLocaleLowerCase();
          clearTimeout(typeaheadTimer);
          typeaheadTimer = setTimeout(function () { typeahead = ''; }, 700);
          var match = options.find(function (option) { return option.dataset.language.toLocaleLowerCase().startsWith(typeahead); });
          if (match) { event.preventDefault(); match.focus(); }
        }
        return;
      }
      event.preventDefault();
      if (event.key === 'Home') index = 0;
      else if (event.key === 'End') index = options.length - 1;
      else index = (index + (event.key === 'ArrowDown' ? 1 : -1) + options.length) % options.length;
      options[index].focus();
    });
    document.addEventListener('click', function (event) { if (!control.contains(event.target)) closeMenu(false); });
    control.addEventListener('focusout', function () {
      window.setTimeout(function () { if (!control.contains(document.activeElement)) closeMenu(false); }, 0);
    });
    updateLanguageTarget();
  }
  function initialize() {
    initialLanguage = window.wlvInitialLanguage || initialLanguage;
    languageFingerprint = initialLanguage.fingerprint || '';
    dictionary = initialLanguage.labels || dictionary;
    phraseDictionary = initialLanguage.phrases || phraseDictionary;
    currentLanguage = initialLanguage.language || currentLanguage;
    document.documentElement.lang = window.wlvI18n.locale();
    var languageInput = document.getElementById('l');
    if (languageInput) languageInput.value = currentLanguage;
    if (['saved', 'url'].includes(initialLanguage.source)) targetLanguage = currentLanguage;
    translate();
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
    window.jQuery(document).on('shiny:connected.wlvLanguageSync', function () {
      Shiny.setInputValue('wlv_language_sync', {fingerprint: languageFingerprint, connection: ++languageConnection}, {priority: 'event'});
    });
    window.jQuery(document).one('shiny:connected.wlvNavigation', function () {
      var active = document.querySelector('#main_nav li.active > a[data-value]');
      if (active) {
        Shiny.setInputValue('main_nav', active.dataset.value, {priority:'event'});
        saveNavigation(active.dataset.value);
      }
    });
    initializeLanguageMenu();
    var settings = document.getElementById('wlv-settings');
    var nav = document.querySelector('.navbar');
    var menu = document.querySelector('.navbar-collapse');
    var toggle = document.querySelector('.navbar-toggle');
    if (toggle) toggle.setAttribute('aria-label', tr('Abrir navegação', 'Open navigation'));
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
