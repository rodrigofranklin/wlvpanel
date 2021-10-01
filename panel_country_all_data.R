conditionalPanel(
  "output.pais != ''",
  
  # Botão fechar
  actionButton(
    inputId = "close_country_data_panel",
    label = NULL,
    icon = icon("times"),
    style ="
            border-radius: 50%;
            border-color: transparent;
            color: white;
            font-size: 12px;
            position: absolute;
            top: 58px;
            left: calc(50vw - 17px);
            z-index: 501;
            background-color: rgba(127,127,127,1);
          "
  ),
  
  # Painel dados país
  absolutePanel(
    top = 75,
    left = 10,
    height = "calc(100vh - 75px)",
    width = "calc(100vw - 20px)",
    style = "
            overflow-y:scroll;
            z-index:500;
            padding: 20px;
            background-color: rgba(242,243,246,0.95);
            border: solid;
            border-width: 1px;
            border-color: rgba(221,221,221,1);
          ",
    
    # Título
    textOutput("pais") %>%
      div(style = "font-size: 24px; font-weight: bold") ,
    
    # Panel: country_profile
    absolutePanel(
      top = 70,
      left = 20,
      style = "width: calc(68% + 20px)",
      class = "panel panel-default",
      
      fluidRow(
        column(
          width = 6,
          "Country Profile -",
          textOutput("ano")
        ),
        column(
          width = 6,
          # chakraSliderInput(
          #   "ano_painel",
          #   label = NULL,
          #   min = ano_min, 
          #   max = ano_max, 
          #   sep = "") %>%
          #   p(style = "font-size: '20px'")
          
        )
      ) %>%
        div(
          class = "panel-heading",
          style = "
                background-image:none;
                background: white;
                font-size: 16px; 
                font-weight: bold;
                padding: 3px 5px;
              "
        ),
      
      dataTableOutput("profile") %>%
        div(
          class = "panel-body",
          style = "
                  background-image:none;
                  background: white;
                  padding: 0px;
                "
        )
    ),
    
    # Painel de download
    absolutePanel(
      top = 70,
      left = "calc(68% + 60px)",
      right = 5,
      class = "panel panel-default",
      
      tagList(
        shiny::icon("flag", style = "color: gray"),
        "Download country data"
      ) %>%
        div(class = "panel-heading",
            style = "background-image:none;
                  background: white;
                  font-size: 16px; 
                  font-weight: bold;
                  padding: 15px !important;
                  "),
      
      tagList(
        shiny::icon("chart-pie",
                    style = "color: gray"),
        "Download setorial data"
      ) %>%
        div(class = "panel-body",
            style = "background-image:none;
                  background: white;
                  font-size: 16px; 
                  font-weight: bold;
                  padding: 15px !important;
                  ")
    ),
    
    # Todos os gráficos
    country_graphs,
    
    # Painel de distribuição setorial
    absolutePanel(
      top = "190px",
      left = "calc(68% + 60px)",
      right = "5px",
      style = distribution_table_height,
      
      div(
        class = "panel panel-default",
        style ="
                position:sticky;
                top:0;
                height: calc(100vh - 120px);
              ",
        textOutput("indicador") %>%
          div(class = "panel-heading",
              style = "background-image:none;
                  background: white;
                  font-size:16px; 
                  font-weight: bold;
                  padding: 3px 5px;
                  "),
        tagList(
          p("Setorial data", style = "text-align: center; padding: 4px"),
          tabsetPanel(
            type = "tabs",
            tabPanel(
              "WIOD.13",
              dataTableOutput("setores_pais_13")
            ),
            tabPanel(
              "WIOD.16",
              dataTableOutput("setores_pais_16")
            )
          )
        ) %>%
          div(class = "panel-body",
              style = "padding:0;")
      )
    )
  )
)