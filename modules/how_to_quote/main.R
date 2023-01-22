### Module: How to Quote
# Description: brings instructions on how to quote our panel

### Global #####


### UI ####

tab_how_to_quote <- tabPanel(
  l("tab_name.how_to_quote")
  
)

modules_ui[modules_ui |> length() +1] <- "tab_how_to_quote"

### Server ####

SERVER <- function(ip, op, rv, session) {
  
}

modules_server$how_to_quote <- SERVER
