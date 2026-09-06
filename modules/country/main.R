# Country profile is a standalone page, with its own country and year controls.
source("modules/countries/country_panel.R", encoding = "UTF-8")

modules_ui[[length(modules_ui) + 1L]] <- tabPanel(
  l("tab_name.country"), value = "country", country_panel, co_info_panel
)

modules_server[[length(modules_server) + 1L]] <- function(IP, OP, RV, SESSION) {
  country_panel_server(IP, OP, RV, SESSION)
}
