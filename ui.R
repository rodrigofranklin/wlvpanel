ui <- navbarPage(

  theme = shinytheme("yeti"),
  collapsible = TRUE,
  windowTitle = "World Labour Value Database",
  title = "WLVD",

  tabPanel(
    "Country",
    # Mapa (estilos para eliminar borda)
    tags$style(type = "text/css", "#map {height: calc(100vh - 45px)  !important;}"),
    leafletOutput("map", width = "100%"),
    tags$style(type = "text/css", ".container-fluid {padding-left:0px;padding-right:0px;}"),
    tags$style(type = "text/css", ".navbar {margin-bottom: 0px;}"),
    tags$style(type = "text/css", ".container-fluid .navbar-header .navbar-brand {margin-left: 0px;}"),
    
    absolutePanel(
      id = "header",
      top = 60,
      left = "2%",
      width = "72%",
      height = "200",
      class = "panel panel-default",
      draggable = TRUE,
      style =
        "background-color: rgba(255,255,255,0.3);
            z-index: 500;
            padding: 0;
            box-shadow: 0 0 10px rgba(0,0,0,0.2)",
      textOutput("titulo_painel"),
      dataTableOutput("pais")
    ),
    
    absolutePanel(
      top = 60,
      right = "2%",
      width = "22%",
      height = 1800,
      class = "panel panel-default",
      style =
        "background-color: rgba(255,255,255,0.2);
        z-index: 500;
        padding: 0;
        box-shadow: 0 0 10px rgba(0,0,0,0.2);
        border-radius: 2px",
      # tag$div(class="panel-heading", "Download"),
      selectInput("pais","Country",lista_paises, selected="BRA"),
      sliderInput("ano","YEAR",min = 1995, max = 2021, value = 2009)
    ),
    
    
    absolutePanel(
      class = "panel panel-default",
      style =
        "background-color: rgba(255,255,255,0.2);
        z-index: 500;
        padding: 0;
        box-shadow: 0 0 10px rgba(0,0,0,0.4);
        border-radius: 2px",
      top = 280,
      left = "2%",
      width = "32%",
      height = "250",
#      plotlyOutput("serie_pais")
    ),
  
  absolutePanel(
    class = "panel panel-default",
    style =
      "background-color: rgba(255,255,255,0.2);
        z-index: 500;
        padding: 0;
        box-shadow: 0 0 10px rgba(0,0,0,0.9);
        border-radius: 2px",
    bottom = 20,
    left = "2%",
    width = "100px",
    height = "90px",
    span((tags$i(
      p(align="center",img(src = "https://worldlabourvalues.org/images/a_batallar_ideas.png",
            height = "32px"),"World Labour Values Task Force"))))
  )
),

    
  column(
    width = 7,
    shinydashboard::box(
      width = "100%",
      title = ,
      status = "danger",
      solidHeader = TRUE,
      # dataTableOutput("pais")
      "xc"
    ),
    shinydashboard::box(
      width = "100%",
      title = "Série Temporal",
      status = "danger",
      solidHeader = TRUE,
#      div(textOutput("titulo_serie_pais"), align = "center" ,
#          style = "font-size:20px; font-weight: bold"),
#      div(textOutput("subtitulo_serie_pais"), align = "center"),
      # plotlyOutput("serie_pais")
      "xy"
    )
  ),
  
  column(
    width = 5,
    shinydashboard::box(
      width = "100%",
      title = "Detalhamento Setorial",
      status = "danger",
      solidHeader = TRUE,
      "xz"
#      div(textOutput("titulo_detalhamento_pais"), align = "center",
#          style = "font-size:20px; font-weight: bold"),
#      div(textOutput("subtitulo_detalhamento_pais"), align = "center"),
    #   tabsetPanel(
    #     tabPanel(
    #       "WIOD.13",
    #       dataTableOutput("setores_pais_13")
    #     ),
    #     tabPanel(
    #       "WIOD.16",
    #       dataTableOutput("setores_pais_16")
    #   )
    # )
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



