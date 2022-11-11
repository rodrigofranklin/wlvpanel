### Panel: SETUP

## GLOBAL ###########

# list_methods
list_methods <- meta_methods$code
languages <- colnames(language_file)

## UI ##############

setup_panel <- tagList(
  # Loading panel...
  conditionalPanel(
    "output.loading!=''",
    absolutePanel(
      top = bar_height,
      left = 0,
      right = 0,
      bottom = 0,
      style = "background-color: rgba(252, 252, 252, 1);
        text-align: center;
        z-index: 100000;",
      img(
        src = "spinner.gif",
        style = "position: fixed;
          top: calc(50vh - 5px);
          left: calc(50vw - 8px);"
  ))),
  
  # setup Button
  actionLink(
    "setup_button",
    label = NULL,
    style = paste0("position: fixed;
      top:", (bar_height-28)/2,"px;
      right: 10px;
      font-size: 20px;
      color:", item_color,";
      z-index: 5000;"),
    icon = icon("cog")
  ),
  
  conditionalPanel(
    "output.show_setup_panel != 0",
    # Setup background
    absolutePanel(
      id = "setup_background",
      top = 0,
      left = 0,
      right = 0,
      bottom = 0,
      style = paste0("background-color: ", bg_color, ";
        opacity: 0.7;
        text-align: center;
        z-index: 5000;")
    ),
    # Setup Panel
    absolutePanel(
      top = 120,
      left = 25,
      # draggable = TRUE,
      style = "z-index: 5001; border-radius:10px;",
      width = 350,
      class="panel panel-default",
      actionLink(
        "setup_close_button",
        label = NULL,
        style = "
          position: absolute;
          top: 5px;
          right: 10px;
          z-index: 5000;
          padding: 0px;
          color:black;
          font-size: 14px;",
        icon = icon("times")
      ),
      div(
        l("ps.title.setup_panel"),
        class = "panel-heading",
        style = "text-align: left; border-radius:10px 10px 0px 0px"),
      div(
        class = "panel-body",
        style = "text-align: center; padding-bottom: 0px;",
        withTags(
          table(
            width = "100%",
            tr(
              td(
                width = "30%",
                height = "25px",
                style = "
                  padding-bottom: 15px !important; 
                  vertical-align:middle; 
                  font-weight: bold",
                l("ps.language")
              ),
              td(
                width = "70%",
                style = "padding: 0px; vertical-align: middle;",
                selectInput(
                  inputId = "l",
                  label = NULL,
                  selected = default_language,
                  choices = languages,
                  width = "100%")
              ),
              tr(
                td(
                  colspan = 2,
                  style = "padding: 0px 0px; height: 5",
                  hr(style="margin: 5px !important")
                )
              ),
              tr(
                td(
                  colspan = 2,
                  table( 
                    width = "100%",
                    tr(
                      td(
                        width = "80%",
                        table(
                          width = "100%",
                          tr(
                            td(
                              style = "padding-bottom: 15px;",
                              width = "20%",
                              l("ps.base_1") |> div(style = "vertical-align:middle;")
                            ),
                            td(
                              style = "padding: 0px 20px 0px 20px;",
                              width = "80%",
                              selectInput(
                                "base1",
                                label = NULL,
                                width = "100%",
                                choices = list_methods,
                                selected = base1
                          ))),
                          tr(
                            td(
                              style = "padding-bottom: 15px;",
                              width = "20%",
                              l("ps.base_2") |> div(style = "vertical-align:middle;")
                            ),
                            td(
                              style = "padding: 0px 20px 0px 20px;",
                              width = "80%",
                              selectInput(
                                "base2",
                                label = NULL,
                                width = "100%",
                                choices = list_methods,
                                selected = base2
                              ))),
                          tr(
                            td(
                              style = "padding-bottom: 15px;",
                              width = "20%",
                              l("ps.base_3") |> div(style = "vertical-align:middle;")
                            ),
                            td(
                              style = "padding: 0px 20px 0px 20px;",
                              width = "80%",
                              selectInput(
                                "base3",
                                label = NULL,
                                width = "100%",
                                choices = list_methods,
                                selected = base3
                              ))),
                          tr(
                            td(
                              style = "padding-bottom: 15px;",
                              width = "20%",
                              l("ps.base_4") |> div(style = "vertical-align:middle;")
                            ),
                            td(
                              style = "padding: 0px 20px 0px 20px;",
                              width = "80%",
                              selectInput(
                                "base4",
                                label = NULL,
                                width = "100%",
                                choices = list_methods,
                                selected = base4
  ))))),
  td(
    width = "20%",
    actionButton("info_bases", label = l("ps.bases_info")))
))))))))) |> 
  # jqui_draggable are required to solve problem with selectize input within 
  # a draggable panel
  jqui_draggable(options = list(cancel = ".selectize-control"))),
  
  # Bases_info_panel
  conditionalPanel(
    "output.show_bases_info_panel !=1",
    
    absolutePanel(
      top = 120,
      left = 400,
      width = 400,
      draggable = TRUE,
      class="panel panel-default",
      style = "z-index: 5000; border-radius:10px 10px 0px 0px;",
      div(class = "panel-heading",
          style = "border-radius:10px 10px 0px 0px;",
          l("ps.title.bases_info"),
          actionLink(
            "bases_info_close_button",
            label = NULL,
            top = 5,
            right = 5,
            style = "
              position: absolute;
              top: 5px;
              right: 10px;
              padding: 0px;
              font-size: 14px;
              color: black;",
            icon = icon("times")
          )
      ),
      
      div(class = "panel-body",
          uiOutput("bases_info_text"),
          style =  "overflow-y:scroll;
            height: 60vh;"
))))

## SERVER ############

SERVER <- function(IP, OP, RV, SESSION) {
  
  # Open/close system of panel setup
  show_setup_panel <- reactiveVal(0)
  OP$show_setup_panel <- reactive(show_setup_panel())
  outputOptions(OP,"show_setup_panel", suspendWhenHidden = FALSE)
  observeEvent(IP$setup_button,show_setup_panel(1))
  observeEvent(IP$setup_close_button, {
    show_setup_panel(0)
    show_bases_info_panel(1)
  })
  
  # Bases selection
  RV$bases <- reactive({
    IP$setup_close_button
    unique(c(IP$base1 |> isolate(),
             IP$base2 |> isolate(),
             IP$base3 |> isolate(),
             IP$base4 |> isolate()))})

  # Open/close system for bases_info_panel
  show_bases_info_panel <- reactiveVal(1)
  OP$show_bases_info_panel <- renderText(show_bases_info_panel())
  outputOptions(OP,"show_bases_info_panel", suspendWhenHidden = FALSE)
  observeEvent(IP$bases_info_close_button, show_bases_info_panel(show_bases_info_panel()*-1))
  observeEvent(IP$info_bases, show_bases_info_panel(show_bases_info_panel()*-1))
  
  OP$bases_info_text <- renderUI({
    tagList(
      lapply(1:length(meta_methods$code), function(z) {
        req(z)
        withTags(
          table(
            width = "100%",
            tr(
              td(
                width = "50%",
                lb("ps.base_code",IP$l) |> strong(),
                meta_methods$code[z]
              ),
              td(
                width = "50%",
                lb("ps.base_source", IP$l) |> strong(),
                meta_methods$source[z]
            )),
            tr(
              td(
                colspan = 2,
                lb("ps.base_name", IP$l) |> strong(),
                meta_methods$name[z]
            )),
            tr(
              td(
                colspan = 2,
                style = "text-align: justifY;",
                lb("ps.description", IP$l) |> strong(),
                lb(paste0("DESC.",meta_methods$code[z]), IP$l)
            )),
            tr(
              td(
                colspan = 2,
                style = "padding: 0px 0px; height: 5",
                hr(style="margin: 5px !important")
  ))))}))})
  
  # De-active loading panel when OP$loading is set to ""
  OP$loading <- renderText("x")
  outputOptions(OP, 'loading', suspendWhenHidden=FALSE)
}

modules_server[[modules_server |> length() +1]] <- SERVER
