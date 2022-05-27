ui <- navbarPage(
  theme = bs_theme(version = 4, bootswatch = "minty"),
  collapsible = TRUE,
  windowTitle = "World Labour Value Database",
  title = "WLVD",
  # selected = 2,
  
  # header contém o botão e o painel de configuração.
  header = tagList(
    useShinyjs(),  # Set up shinyjs
    
    # Loading panel... (para ocultar todos os conditionalPanels)
    conditionalPanel(
      "output.loading!=''",
      absolutePanel(
        top = 45,
        left = 0,
        right = 0,
        bottom = 0,
        style = "
          background-color: rgba(220, 222, 225, 1);
          text-align: center;
          z-index: 100000;
        ",
        img(
          src = "hug.gif",
          height = "50px",
          style = "
            position: fixed;
            top: calc(50vh - 25px);
            left: calc(50vw - 25px);
          "
        ) 
      )
    ),

    # Google Analytics
    tags$head(
      includeHTML("www/google_analytics.html"),
      tags$script('
                                var dimension = [0, 0];
                                $(document).on("shiny:connected", function(e) {
                                    dimension[0] = window.innerWidth;
                                    dimension[1] = window.innerHeight;
                                    Shiny.onInputChange("dimension", dimension);
                                });
                                $(window).resize(function(e) {
                                    dimension[0] = window.innerWidth;
                                    dimension[1] = window.innerHeight;
                                    Shiny.onInputChange("dimension", dimension);
                                });
                            ')
    ),

    config_panel
  ),
  
  # footer contém o painel de créditos.
  footer = absolutePanel(
    fixed = TRUE,
    style = "
      background-color: rgba(255,255,255,0.6);
      z-index: 100;
      padding: 0px
    ",
    bottom = 0,
    left = 0,
    width = 300,
    height = 20,
    tags$table(
      tags$tr(
        tags$td(
          img(src = "https://worldlabourvalues.org/images/a_batallar_ideas.png",
              height = "20px",
              style = "
                -webkit-filter: grayscale(100%);
                filter: grayscale(80%)
          ")
        ),
        tags$td(
          "World Labour Values Task Force | ",
          span("©", style = "
              display: inline-block;
              text-align: right;
              margin: 0px;
              -moz-transform: scaleX(-1);
              -o-transform: scaleX(-1);
              -webkit-transform: scaleX(-1);
              transform: scaleX(-1);
              filter: FlipH;
              -ms-filter: 'FlipH'
            "
          ),
          " CC-BY-NC SA 4.0",
          style = "font-size: 10px;"
        )
      )
    )
  ),
  
  tabPanel(
    l("Country"),
    # Mapa (estilos para eliminar borda)
    tags$style(type = "text/css", "#map {z-index: 1;}"),
    leafletOutput("map", width = "100%", height = "calc(100vh - 45px)"),
    tags$style(type = "text/css", ".container-fluid {padding-left:0px;padding-right:0px;}"),
    tags$style(type = "text/css", ".navbar {margin-bottom: 0px;}"),
    tags$style(type = "text/css", ".container-fluid .navbar-header .navbar-brand {margin-left: 0px;}"),
    tags$style(type = "text/css", ".js-plotly-plot .plotly .main-svg:first-of-type {background: rgba(255,255,255,0.4) !important;}"),
    # tags$style(type = "text/css", "tr.odd {background-color: rgba(249,249,249,0.7) !important};"),
    # tags$style(type = "text/css", "tr.even {background-color: rgba(255,255,255,0.7) !important};"),
    # tags$style(type = "text/css", "tr.even.selected {background-color: rgba(176, 190, 217,0.6) !important};"),
    tags$style(type = "text/css", ".profile_table {
      line-height: 0.5 !important;
      border-style: none !important;
        border-color: red !important;
    }"),
    
    
    # table.dataTable thead th, table.dataTable thead td
    tags$style(type = "text/css", "table.dataTable thead th {
      border-bottom-width: 2px;
      border-color: #999999;
      font-size: 14px;
      font-weight: normal;
      text-align: right;
      padding: 15px;
      padding-right: 30px;
      color: #999999;
    }"),
    
    tags$style(type = "text/css", "table.dataTable thead .sorting {
      background-image: none;
    }"),

    tags$style(type = "text/css", "table.dataTable thead .sorting_asc {
      border-color: rgb(51, 51, 51);
      color: rgb(51, 51, 51);
      font-weight: bold;
    }"),
    
    tags$style(type = "text/css", "table.dataTable thead .sorting_desc {
      border-color: rgb(51, 51, 51);
      color: rgb(51, 51, 51);
      font-weight: bold;
    }"),
    

    # Panel of Inputs
    absolutePanel(
      id = "inputs_panel",
      top = 60,
      right = "1.5%",
      width = "22%",
      # draggable = TRUE,
      style = "z-index: 100;
      font-size: 10px; 
      padding: 10px 10px 0px 10px; 
      background-color: rgba(0,0,0,0.1);",

      uiOutput("select.country"),

      uiOutput("select.indicator"),

      uiOutput("select.year"),
        
      
      uiOutput("select.base") %>% div(style = "text-align: right")
    # ) %>%  jqui_draggable(options = list(containment = "parent")),
    ),

    # country_tp_panel,
    country_panel,
    indicator_info_panel,
    
    # Loading gif...
    # Aparece assim que input.pais se modifica.
    # É sobreposto após output.pais se modificar.
    conditionalPanel(
      "input.pais != ''",
      img(src = "hug.gif",
          height = "50px",
          style = "
                position: fixed;
                top: calc(50vh - 25px);
                left: calc(50vw - 25px);
                z-index: 50;
          ") 
    )
    
  ),                  

  tabPanel(
    l("Indicators"),
    value = 2,
    style = "
      background-color: rgba(242,243,246,1);
      height: calc(100vh - 45px);
      overflow-y:scroll;
    ",
  
    
    tags$table(
      width = "100%",
      height = "100%",
      tags$tr(
        tags$td(
          width = "75%",
          style = "
            vertical-align: top;
            padding: 20px;
          ",
          div(
            class = "panel panel-default",
            div(
              class = "panel-body",
              height = "100%",
              width = "100%",
              style = "padding: 0px !important",
              tags$head(tags$style(HTML("
                #termo.form-control{
                  background: url('search_textinput3.png') top left no-repeat;
                  height: 32px;
                  padding-left:35px;
                  font-size: 13px;
                }"
              ))),
              
              textInput(
                inputId = "termo",
                label = NULL,
                placeholder = "pesquisar...",
                width = 300
              ) %>% 
                tagAppendAttributes(
                  style = "
                    margin-bottom: 20px !important;
                    margin-left: 15px;
                    margin-top: 20px;
                    margin-right: 15px;
                  "),
              uiOutput("indicators_links")
            )
          )
        ),
        
        tags$td(
          width = "25%",
          style = "
            vertical-align: top;
            padding: 20px 20px 20px 0px;
          ",
          div(
            class = "panel panel-default",
            style = "
              border-top: 0px;
            ",
            div(
              class = "panel-body",
              style = "
                padding: 0px;
              ",
              uiOutput("groups_links")
    ))))),

    panel_indicators
  ),
  
  tabPanel(
    l("Trade"),
    conditionalPanel(
      "!output.exportacoes_monetarias",
      p("Tenha Nervo/Be patient!",  style = "
                position: fixed;
                top: calc(50vh - 45px);
                left: calc(50vw - 85px);
                z-index: 50;"),
      img(src = "hug.gif",
          height = "50px",
          style = "
                position: fixed;
                top: calc(50vh - 25px);
                left: calc(50vw - 25px);
                z-index: 50;
          ") 
    ),
    absolutePanel(
      top = 100,
      right = "1.5%",
      width = "22%",
      height = "28%",
      class = "panel panel-default",
      style =
        "background-color: rgba(255,255,255,0.2);
        z-index: 504;
        padding: 0;
        box-shadow: 0 0 10px rgba(0,0,0,0.2);
        border-radius: 2px;
        font-size: 10px",
      selectInput("paistrade","Country",lista_paises, selected="BRA"),
      radioButtons(inputId = "transacoes_agregacao", choices = lista_agr, selected = "Agregado", label = ""),
      radioButtons(inputId = "transacoes_versao", choices = c("WIOD13", "WIOD16"), selected = "WIOD13", label = "Base de dados:"),
      sliderInput("anotrade","YEAR",min = 1995, max = 2021, value = 2009, ticks = F, animate=F),
      actionButton("fill", "Fill Cache")
    ),
    absolutePanel(
      width="30%",
      top=50,
      height="30%",
      left="1.5%",
      d3tree3Output("exportacoes_monetarias")
    ),
    absolutePanel(
      width="30%",
      top=50,
      height="30%",
      left="33.5%",
      d3tree3Output("exportacoes_valores")
      ),
    absolutePanel(
      width="30%",
      bottom=50,
      height="30%",
      left="1.5%",
      d3tree3Output("exportacoes_transferencias")
    )
    
  ),
  tabPanel(
    l("Download"),
    br(),br(),
    a("WLVD Portable / BDMVT portátil",href = "https://cloud.worldlabourvalues.org/s/5oDfapMJJdDMnSn",
    )
  ),

)  
# tabPanel(
#   "Trade",
#   absolutePanel(
#      id= "tradecontrols",
#      top = 50,
#      right = "1.5%",
#      width = "22%",
#      height = "68%",
#      class = "panel panel-default",
#      style =
#        "background-color: rgba(255,255,255,0.2);
#         z-index: 504;
#         padding: 0;
#         box-shadow: 0 0 10px rgba(0,0,0,0.2);
#         border-radius: 2px;
#         font-size: 10px",
#      selectInput("paistrade","Country",lista_paises, selected="BRA"),
#      radioButtons(inputId = "transacoes_ind", choices = c("exports","imports","balance","unequal exchange"),selected="exports",label="Variable"),
#      radioButtons(inputId = "transacoes_agregacao", choices = c("Aggr.", "Sector"), selected = "Aggr.", label = "Type"),
#      radioButtons(inputId = "transacoes_versao", choices = c("WIOD13", "WIOD16"), selected = "WIOD13", label = "Base de dados:"),
#      sliderInput("anotrade","YEAR",min = 1995, max = 2021, value = 2009, ticks = F, animate=T)
#   ),

  



