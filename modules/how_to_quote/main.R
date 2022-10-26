### Module: How to Quote
# Description: brings instructions on how to quote our panel

### Global #####


### UI ####

tab_how_to_quote <- tabPanel(
  l("tab_name.how_to_quote"),
  absolutePanel(
    top = 45,
    left = 0,
    right = 0,
    height = "calc(100vh - 45px)",
    style = "margin:0px !important;
      padding: 10px;
      background-color: rgba(252,252,252,1);",
    
    absolutePanel(
      width = "calc(100vw - 20px)",
      class="panel panel-default",
      div(
        class = "panel-heading",
        l("text.quote") |> strong()
      ),
      div(
        class = "panel-body",
        HTML("Franklin, R. S. P., Borges, R. E. S., Sánchez, C., & Montibeler,
                 E. E. (2022). Skilled Labour and the Reduction Problem: Questioning
                 the Exploitation Rate Equalization Hypothesis. <i>World Review of
                 Political Economy</i>, 13(3), 362-390. DOI:
                 10.13169/worlrevipoliecon.13.3.0362<BR>"),
        a(href = "http://doi.org/10.13169/worlrevipoliecon.13.3.0362",
          target="_blank",
          "[LINK]")
    )),
    br(),br(),
    
    textOutput("debug")
))

modules_ui[modules_ui |> length() +1] <- "tab_how_to_quote"

### Server ####

SERVER <- function(IP, OP, RV, SESSION) {

}

modules_server$how_to_quote <- SERVER
