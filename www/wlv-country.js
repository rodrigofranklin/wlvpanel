(function () {
  'use strict';
  function initialize() {
    var page = document.getElementById('wlv-country-page');
    if (!page) return;
    page.addEventListener('click', function (event) {
      var option = event.target.closest('[data-wlv-country]');
      if (option && window.Shiny) {
        Shiny.setInputValue('co_catalogue_country', option.dataset.wlvCountry, { priority: 'event' });
      }
    });
    var detail = document.getElementById('wlv-country-content');
    if (!detail) return;
    var wasOpen = false;
    new MutationObserver(function () {
      var open = detail.style.display !== 'none';
      if (open === wasOpen) return;
      wasOpen = open;
      requestAnimationFrame(function () {
        if (!page.getClientRects().length) return;
        var target = document.getElementById(open ? 'wlv-country-detail' : 'co_catalogue_search');
        if (target) target.focus({ preventScroll: true });
        page.scrollIntoView({ block: 'start' });
        window.dispatchEvent(new Event('resize'));
      });
    }).observe(detail, { attributes: true, attributeFilter: ['style'] });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
})();
