ui <- navbarPage(
  theme = shinytheme("yeti"),
  collapsible = TRUE,
  windowTitle = "World Labour Value Database",
  title = "WLVD",

  # header contém o botão e o painel de configuração.
  header = tagList(
    absolutePanel(
      id="config",
      top = 10,
      right = 10,
      style = "z-index: 5000",
      actionLink(
        "config_button",
        label = NULL, 
        style = "padding: 2px; font-size: 20px; color: white",
        icon = icon("cog")
      )
    # ),
    # conditionalPanel(
    #   "output.show_config_panel % 2 != 0",
    #   absolutePanel(
    #     top = 70,
    #     left = 70,
    #     class="panel panel-default",
    #     style = "z-index: 5000",
    #     div("WLVD Setup", class = "panel-heading"),
    #     "XXX",
    #     draggable = TRUE
    #   )
    )
  ),
  
  # footer contém o painel de créditos.
  footer = absolutePanel(
    id = "credits",
    fixed = TRUE,
    style =
      "background-color: rgba(255,255,255,0.6);
        z-index: 100;
        padding: 0",
    bottom = 0,
    left = 0,
    width = "300px",
    height = 20,
    tags$table(
      tags$tr(
        tags$td(
          img(src = "https://worldlabourvalues.org/images/a_batallar_ideas.png",
              height = "20px",
              style = "-webkit-filter: grayscale(100%);
                filter: grayscale(80%)")),
        tags$td(
          "World Labour Values Task Force | ",
          span("©",style ="display: inline-block; text-align: right; margin: 0px; -moz-transform: scaleX(-1); -o-transform: scaleX(-1); -webkit-transform: scaleX(-1); transform: scaleX(-1); filter: FlipH; -ms-filter: “FlipH”"),
          " CC-BY-NC SA 4.0",
          style = "font-size: 10px;")
      )
    )
  ),
  
  tabPanel(
    "Country",
    # Mapa (estilos para eliminar borda)
    tags$style(type = "text/css", "#map {height: calc(100vh - 45px)  !important;
               z-index: 50;}"),
    leafletOutput("map", width = "100%"),
    tags$style(type = "text/css", ".container-fluid {padding-left:0px;padding-right:0px;}"),
    tags$style(type = "text/css", ".navbar {margin-bottom: 0px;}"),
    tags$style(type = "text/css", ".container-fluid .navbar-header .navbar-brand {margin-left: 0px;}"),
    tags$style(type = "text/css", ".js-plotly-plot .plotly .main-svg:first-of-type {background: rgba(255,255,255,0.4) !important;}"),
    tags$style(type = "text/css", "tr.odd {background-color: rgba(249,249,249,0.7) !important};"),
    tags$style(type = "text/css", "tr.even {background-color: rgba(255,255,255,0.7) !important};"),
    tags$style(type = "text/css", "tr.even.selected {background-color: rgba(176, 190, 217,0.6) !important};"),
    tags$style(type = "text/css", ".profile_table {
      line-height: 0.5 !important;
      border-style: none !important;
        border-color: red !important;

    }"),
    
    absolutePanel(
      id="controls",
      top = 50,
      right = "1.5%",
      width = "22%",
      height = "0",
      style = "z-index: 100; font-size: 10px; padding: 0",

      selectInput(
        "pais",
        label = NULL,
        choices = lista_paises,
        selectize = TRUE),

      selectInput(
        "indicador",
        label = NULL,
        choices = lista_variaveis_sea, 
        selected = "taxa_exploracao"),
      
      sliderInput(
        "ano",
        label = NULL,
        min = ano_min, 
        max = ano_max, 
        value = 2009, 
        ticks = F, 
        animate=F, 
        sep = "")
    ),
    
    uiOutput("country_data_panel"),
    
  ),                  
  tabPanel(
    "Indicators",
    absolutePanel(
      id="controls",
      top = 50,
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
      #    selectInput("pais","Country",lista_paises, selected="BRA"),
      selectInput("indicadorind","Variable",lista_variaveis_sea, selected="taxa_exploracao"),
      sliderInput("anoind","YEAR",min = 1995, max = 2021, value = 2009, ticks = F, animate=T),
      checkboxGroupInput(inputId = "versao",
                         choices = lista_versoes,
                         selected =  lista_versoes,
                         label = "Base de dados:"),
      selectInput(inputId = "paises",
                  label = "Países:",
                  choices = lista_paises,
                  selected = c("BRA","CHN","USA"),
                  multiple = TRUE)
    ),
    
    absolutePanel(
      "Série Temporal",
      width = "70%",
      height = "43%",
      top = 50,
      left = "1.5%",
      class = "panel panel-default",
      plotlyOutput("serie", height="85%")
    ),
    
    absolutePanel(
      top = "54%",
      left = "1.5%",
      width = "70%",
      height = "35%",
      class = "panel panel-default",
      dataTableOutput("indicadores")
    ),
  ),
  
  tabPanel(
    "Trade",
    absolutePanel(
      "tradecontrols",
      top = 50,
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
      radioButtons(inputId = "transacoes_agregacao", choices = c("Agregado", "Por setor de origem"), selected = "Agregado", label = ""),
      radioButtons(inputId = "transacoes_versao", choices = c("WIOD13", "WIOD16"), selected = "WIOD13", label = "Base de dados:"),
      sliderInput("anotrade","YEAR",min = 1995, max = 2021, value = 2009, ticks = F, animate=T)
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
    "Download",
    icon = icon("download"), #coloquei esse ícone pq o font-awesome não está funcionando se não colocar algo aqui!
    "xxx",
  )

)  


