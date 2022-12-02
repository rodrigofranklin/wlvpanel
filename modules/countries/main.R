### Module: Countries
# Description: plot indicator on map and shows detailed info of a country

### Global #####

source("modules/countries/map.R")
source("modules/countries/country_panel.R")


### UI ####

TABPANEL <- tabPanel(
  l("tab_name.countries"),
  
  map_ui,
  
  panel_of_inputs,
  
  country_panel,
  
  co_info_panel

)

modules_ui[[modules_ui |> length() +1]] <- TABPANEL

### Server ####

SERVER <- function(IP, OP, RV, SESSION) {
 
  map_server(IP, OP, RV, SESSION)
  
  country_panel_server(IP, OP, RV, SESSION)

}

modules_server[[modules_server |> length() +1]] <- SERVER
