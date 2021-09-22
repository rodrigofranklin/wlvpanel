ui <- navbarPage(
  
  theme = shinytheme("yeti"),
  collapsible = TRUE,
  windowTitle = "World Labour Value Database",
  title = "WLVD",
  
  tabPanel(
    "Country",
    # Mapa (estilos para eliminar borda)
    tags$style(type = "text/css", "#map {height: calc(100vh - 45px)  !important;
               z-index: 500;}"),
    leafletOutput("map", width = "100%"),
    tags$style(type = "text/css", ".container-fluid {padding-left:0px;padding-right:0px;}"),
    tags$style(type = "text/css", ".navbar {margin-bottom: 0px;}"),
    tags$style(type = "text/css", ".container-fluid .navbar-header .navbar-brand {margin-left: 0px;}"),
    tags$style(type = "text/css", ".js-plotly-plot .plotly .main-svg:first-of-type {background: rgba(255,255,255,0.4) !important;}"),
    tags$style(type = "text/css", "tr.odd {background-color: rgba(249,249,249,0.7) !important};"),
    tags$style(type = "text/css", "tr.even {background-color: rgba(255,255,255,0.7) !important};"),
    tags$style(type = "text/css", "tr.even.selected {background-color: rgba(176, 190, 217,0.6) !important};"),
    
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
      selectInput("pais","Country",lista_paises, selected="BRA"),
      selectInput("indicador","Variable",lista_variaveis_sea, selected="taxa_exploracao"),
      sliderInput("ano","YEAR",min = 1995, max = 2021, value = 2009, ticks = F, animate=T, sep = "")
    ),
    
    
    conditionalPanel(
      "output.esconde",
      style =
        "background-color: rgba(255,255,255,0.3);
        z-index: 500;
        padding: 0;
        box-shadow: 0 0 10px rgba(0,0,0,0.2)",
                     
      absolutePanel(
        id = "header",
        top = 50,
        left = "1.5%",
        width = "72%",
        height = "32%",
        style =
          "background-color: rgba(255,255,255,0.01);
          z-index: 500;
          padding: 0;
          box-shadow: 0 0 0px rgba(0,0,0,0);
          border-radius= none",
        textOutput("titulo_painel"),
        dataTableOutput("pais")
      ),
      
      absolutePanel(
        id = "fechabaixa",
        top = 50,
        left = "40%",
        style =
          "z-index: 501;
          padding: 0;
          border-line: none;
          font-size: 8px",
        tags$div(tags$table(tags$tr(tags$td(actionButton("xis","X",
                                                         style ="border-radius: 20px;
                                                          border-color: transparent;
                                                          background-color: rgba(80,30,30,0.4)")),
                                    tags$td(width = "20px",""),
                                    tags$td(a(href="worldlabourvalues.org","Download data")),
                                    
        )))
      ),                     
                     
      absolutePanel(
        top = "35%",
        # height = "75%",
        right = "1.5%",
        width = "22%",
        style =
          "background-color: rgba(255,255,255,0.05);
        z-index: 500;
        padding: 0;
        box-shadow: 0 0 0px rgba(0,0,0,0);
        border-radius: none",
        div(textOutput("titulo_detalhamento_pais"), align = "center",
            style = "font-size:16px; font-weight: bold;background-color: rgba(255,255,255,0.2)"),
        div(textOutput("subtitulo_detalhamento_pais"), align = "center",
            style = "background-color: rgba(255,255,255,0.2)"),
        tabsetPanel(
          tabPanel(
            "WIOD.13",
            dataTableOutput("setores_pais_13")
          ),
          tabPanel(
            "WIOD.16",
            dataTableOutput("setores_pais_16")
          )
        )
      ),                     
                     
                     
                     absolutePanel(
                       style =
                         "background-color: rgba(255,255,255,0);
        z-index: 500;
        padding: 0;
        box-shadow: 0 0 0px rgba(0,0,0,0);
        border-radius: none",
                       top = "44%",
                       left = "1%",
                       width = "34%",
                       height = "23%",
                       div(textOutput("titulo_serie_pais"), align = "center" ,
                           style = "font-size:18px; font-weight: bold"),
                       div(textOutput("subtitulo_serie_pais"), align = "center"),
                       plotlyOutput("serie_pais")
                     )
    ), 
    absolutePanel(
      id = "credits",
      class = "panel panel-default",
      style =
        "background-color: rgba(255,255,255,0.2);
        z-index: 500;
        padding: 0;
        box-shadow: 0 0 10px rgba(0,0,0,0.3);
        border-radius: 5px;
        ",
      bottom = 20,
      left = "48%",
      width = "110px",
      height = "50px",
      tags$i(tags$table(tags$tr(tags$td(img(src = "https://worldlabourvalues.org/images/a_batallar_ideas.png",
                                            height = "32px",
                                            style = "-webkit-filter: grayscale(100%); filter: grayscale(80%)")),
                                tags$td(tags$p("World Labour Values Task Force",align="center"),colspan=3,
                                        style = "font-size: 9px;")),
                        tags$tr(tags$td(tags$p("🄯 CC-BY-NC SA 4.0", align="center"),colspan=4,
                                        style = "font-size: 8px;"))))
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
  )

)  


