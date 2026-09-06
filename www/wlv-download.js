/* Refresh option labels atomically, preserving the user's latest selection. */
(function () {
  'use strict';
  function updateChoices(message) {
    var element = document.getElementById(message.id);
    if (!element || !element.selectize) return;
    var expected = message.expected || {};
    if (Object.keys(expected).some(function (id) {
      var dependency = document.getElementById(id);
      return dependency && String(dependency.value || '') !== String(expected[id] || '');
    })) return;
    var select = element.selectize;
    var previous = select.getValue();
    var choices = message.choices || [];
    var allowed = new Set(choices.map(function (choice) { return String(choice.value); }));
    var selected = allowed.has(previous) ? previous : '';
    var wasOpen = select.isOpen;

    // These synchronous, silent operations cannot expose a temporary empty value
    // to Shiny or let a late server snapshot overwrite a newer user selection.
    select.clear(true);
    select.clearOptions(true);
    select.clearOptionGroups();
    var groups = new Set();
    choices.forEach(function (choice) {
      if (choice.groups && !groups.has(choice.groups)) {
        groups.add(choice.groups);
        select.addOptionGroup(choice.groups, { value: choice.groups, label: choice.groups });
      }
    });
    select.addOption(choices);
    select.setValue(selected, true);
    if (message.placeholder !== null && message.placeholder !== undefined) {
      select.settings.placeholder = message.placeholder;
      select.updatePlaceholder();
    }
    if (message.label !== null && message.label !== undefined) {
      var label = document.getElementById(message.id + '-label');
      if (label) label.textContent = message.label;
    }
    if (wasOpen) select.refreshOptions(false);
    if (previous !== selected) window.jQuery(element).trigger('change');
  }
  function register() {
    if (!window.Shiny || register.done) return;
    register.done = true;
    window.Shiny.addCustomMessageHandler('wlv-download-choices', updateChoices);
  }
  register();
  if (window.jQuery) window.jQuery(document).on('shiny:connected', register);
}());
