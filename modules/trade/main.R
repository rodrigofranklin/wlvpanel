### Module: template
# Description: xxxx

### Global #####

## Global code here


### UI ####

TABPANEL <- tabPanel(
  l("tab_name.trade")

  ## UI code here 
  
)

modules_ui[[modules_ui |> length() +1]] <- TABPANEL

### Server ####

SERVER <- function(IP, OP, RV, SESSION) {

  ## SERVER code here
  
}

modules_server[[modules_server |> length() +1]] <- SERVER
