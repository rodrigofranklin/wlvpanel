ui <- navbarPage(
  theme = shinytheme("yeti"),
  collapsible = TRUE,
  windowTitle = "World Labour Value Database",
  title = "WLVD",

  # header contém o botão e o painel de configuração.
  header = tagList(
    
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
      includeHTML("www/google_analytics.html")
    ),

    # Config Button
    actionLink(
      "config_button",
      label = NULL,
      style = "
        position: fixed;
        top: 10px;
        right: 10px;
        font-size: 20px;
        color: white;
        z-index: 5000;
      ",
      icon = icon("cog")
    ),
    
    # Config Panel
    conditionalPanel(
      "input.config_button % 2 != 0",
      absolutePanel(
        top = 45,
        left = 0,
        right = 0,
        bottom = 0,
        style = "
          background-color: rgba(0, 0, 0, 0.4);
          text-align: center;
          z-index: 5000;
        ",
        absolutePanel(
          top = "calc(50vh - 100px)",
          left = "calc(50vw - 100px)",
          width = 200,
          height = 200,
          class="panel panel-default",
          div("WLVD Setup", class = "panel-heading"),
          "XXX"
        ) 
      )
    )
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
    "Country",
    # Mapa (estilos para eliminar borda)
    tags$style(type = "text/css", "#map {height: calc(100vh - 45px)  !important;
               z-index: 1;}"),
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
    
    # Panel of Inputs
    absolutePanel(
      top = 50,
      right = "1.5%",
      width = "22%",
      height = "0",
      style = "z-index: 100; font-size: 10px; padding: 0px",

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

    # uiOutput("country_indicator_panel"),
    
    # uiOutput("country_data_panel"),
    
    source("panel_country_all_data.R", local = TRUE)$value,
    
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
    # icon = icon("download"), #coloquei esse ícone pq o font-awesome não está funcionando se não colocar algo aqui!
    "xxx",
  )

)  


