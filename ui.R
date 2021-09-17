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
      sliderInput("ano","YEAR",min = 1995, max = 2021, value = 2009, ticks = F, animate=T)
    ),
    
    
    conditionalPanel("output.esconde",
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
#      draggable = TRUE,
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
        height = "75%",
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
)
)  
  

# ### Indicador -------------------------------
#       # tabItem(
#       #   tabName = "Indicador",
#       tabPanel(
#         "Indicators",
#         shinydashboard::box(
#           width = "100%",
#           # title = "",
#           # solidHeader = TRUE,
#           status = "danger",
#           column(
#             width = 6,
#             dataTableOutput("indicadores1")
#           ),
#           column(
#             width = 6,
#             dataTableOutput("indicadores2")
#           )
#         ),
#         shinydashboard::box(
#           width = "100%",
#           title = "Série Temporal",
#           status = "danger",
#           solidHeader = TRUE,
#           plotlyOutput("serie")
#         )
#       ),
# 
# ### Exportações -------------------------------
#       # tabItem(
#       #   tabName = "Exportações",
#       tabPanel(
#         "Trade",
#         column(width= 6,
#                shinydashboard::box(
#                  width="100%",
#                  d3tree3Output("exportacoes_monetarias")
#        #        )
#         ),
#         #column(width= 6,
#                shinydashboard::box(
#                  width="100%",
#                  d3tree3Output("exportacoes_valores")
#              )
#         ),
#       column(width= 6,
#              shinydashboard::box(
#                width="100%",
#                d3tree3Output("exportacoes_transferencias")
#              )
#       )
#         
#       )      

### Importações -------------------------------
#       tabItem(
#         tabName = "Importações"
#         
#       ),      
# 
# ### Saldo -------------------------------
#       tabItem(
#         tabName = "Saldo"
#         
#       ),      
# 
# ### Transferências -------------------------------
#       tabItem(
#         tabName = "Transferências"
#         
#       )      
    # )
    

        
# ### Painel "Indicador --------------    
#     
#   tabPanel(
#     "Indicador",
#     #                      tags$body(class="skin-yellow sidebar-mini control-sidebar-closed",
#     icon = icon("chart-line"),
#     dashboardPage(
#       dashboardHeader(disable = T),
#       dashboardSidebar(
#         sliderInput(inputId = "ano_indicador",
#                     label = NULL,
#                     min = ano_min,
#                     max = ano_max,
#                     value = 2009,
#                     ticks = FALSE,
#                     width = "95%",
#                     sep = ""),
#         selectInput(inputId = "indicador",
#                     label = NULL,
#                     choices = lista_variaveis_sea),
#         selectInput(inputId = "paises_indicadores",
#                     label = "Países:",
#                     choices = lista_paises,
#                     selected = lista_paises,
#                     multiple = TRUE)
#       ),
#       dashboardBody(
#         shinyDashboardThemes(
#           theme = "grey_light"
#         ),
#         
#       )
#     )
#   ),
#             tabPanel("Unequal Exchange",icon = icon("globe"),
#  #                    tags$body(class="skin-blue sidebar-mini control-sidebar-closed",
#                                dashboardPage(
#                                  dashboardHeader(disable = T),
#                                  dashboardSidebar(
#                                    sliderInput(inputId = "ano_transacoes", label = NULL, min = ano_min, max = ano_max, value = 2009, ticks = FALSE, width = "95%", sep = ""),
#                                    selectInput(inputId = "pais_transacoes", label = "País:", choices = lista_paises),
#                                    radioButtons(inputId = "transacoes_agregacao", choices = c("Agregado", "Por setor de origem", "Por setor de destino"), selected = "Agregado", label = ""),
#                                    radioButtons(inputId = "transacoes_versao", choices = c("WIOD13", "WIOD16"), selected = "WIOD13", label = ""),
#                                    sidebarMenu("",
#                                    menuItem("Export",
#                                             menuSubItem(selectInput(inputId = "par_transacoes", label = "Parceiro/Partner:", choices = lista_paises)),
#                                             tabName = "transf"
#                                    ),
#                                    menuItem("Import",
#                                             menuSubItem(selectInput(inputId = "par_transacoes", label = "Parceiro/Partner:", choices = lista_paises)),
#                                             tabName = "transf"
# 
#                                    ),
#                                    menuItem("Saldo/Position",
#                                             tabName = "transf"
#                                  ),
#                                    menuItem("Unequal Transfers",
#                                             tabName = "transf"
#                                   )
#                                    )
#                                  ),
#                                  dashboardBody(
#                                    shinydashboard::box(
#                                      #plotOutput("exportacoes_monetarias")
#                                      d3tree2Output("exportacoes_monetarias")
# 
#                                    )
#                                    #
#                                    # shinydashboard::box(
#                                    #   plotOutput("exportacoes_valores")
#                                    # ),
#                                    # shinydashboard::box(
#                                    #   plotOutput("exportacoes_transferencias")
#                                    # ),
#                                    # shinydashboard::box(
#                                    #   tableOutput("importacoes_monetarias"),
#                                    #   tableOutput("importacoes_valores"),
#                                    #   tableOutput("importacoes_transferencias"),
#                                    # ),
#                                    # shinydashboard::box(
#                                    #   tableOutput("saldo_monetarias"),
#                                    #   tableOutput("saldo_valores"),
#                                    #   tableOutput("saldo_transferencias"),
#                                    # ),
#                                    # shinydashboard::box(
#                                    #   tableOutput("td_envios_recebimentos"),
#                                    #   tableOutput("td_envios_recebimentos_saldo"),
#                                    #   tableOutput("improdutivos_envios_recebimentos"),
#                                    #   tableOutput("improdutivos_envios_recebimentos_saldo"),
#                                    #   textOutput("proporcao_td_transferencias"),
#                                    #   textOutput("proporcao_td_transferencias_saldo")
#                                    # )
#                                    #
# #                                   shinydashboard::box(tableOutput("debuga"))
#                                  )
#                                )
#                       )
# #             )
# 
#   )



