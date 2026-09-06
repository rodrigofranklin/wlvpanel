# Mapa temático; os perfis ficam no módulo País.
source("modules/countries/map.R", encoding = "UTF-8")
modules_ui[[length(modules_ui) + 1L]] <- tabPanel(
  l("tab_name.countries"), value = "map",
  tags$main(class = "wlv-map-layout", panel_of_inputs, map_ui)
)
modules_server[[length(modules_server) + 1L]] <- function(IP, OP, RV, SESSION) {
  map_server(IP, OP, RV, SESSION)
}
