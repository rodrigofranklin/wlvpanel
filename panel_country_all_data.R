tagList(
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
        
        tags$table(
          tags$tr(
            tags$td(
              shiny::icon("flag", style = "font-size: 32px; color: gray"),
              rowspan = 2
            ),
            tags$td(
              "Download country data",
              style = "padding: 0px 15px;
                      font-weight: bold;
                      font-size: 16px", width = "100%")
          ),
          tags$tr(
            tags$td(
              tags$a("WIOD.13", href = "dowmload/WIOD.13/bra.xlsx"),
              " | ",
              tags$a("WIOD.16", href = "dowmload/WIOD.13/bra.xlsx"),
              style = "text-align: center;
                      font-size: 12px"
            )
          )
        )
        
        %>%
          div(class = "panel-heading",
              style = "background-image:none;
                  background: white;
                  font-size: 16px; 
                  padding: 5px 15px !important;
                  "),
        
        tags$table(
          tags$tr(
            tags$td(
              shiny::icon("chart-pie",
                          style = "font-size: 32px; color: gray"),
              rowspan = 2
            ),
            tags$td(
              "Download setorial data",
              style = "padding: 0px 15px;
                      font-weight: bold;
                      font-size: 16px", width = "100%")
          ),
          tags$tr(
            tags$td(
              tags$a("WIOD.13", href = "dowmload/WIOD.13/bra.xlsx"),
              " | ",
              tags$a("WIOD.16", href = "dowmload/WIOD.13/bra.xlsx"),
              style = "text-align: center;
                      font-size: 12px"
            )
          )
        ) %>%
          div(class = "panel-body",
              style = "background-image:none;
                  background: white;
                  font-size: 16px; 
                  padding: 5px 15px !important;
                  ")
      ),
      
      # Todos os gráficos
      country_graphs,
      
      # Painel de distribuição setorial
      absolutePanel(
        top = "190px",
        left = "calc(68% + 60px)",
        right = "5px",
        height = (top-200),
        
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
      ),
      
    )
  ),
  
  conditionalPanel(
    "output.show_info_panel !=0",
    
    absolutePanel(
      id = "info_background",
      style = "
          position: fixed !important;
          top: 45px;
          left: 0px;
          right: 0px;
          bottom: 0px;
          background-color: rgba(0, 0, 0, 0.4);
          text-align: center;
          z-index: 50000;
        "
    ),
    
    absolutePanel(
      top = "calc(50vh - 30vh)",
      left = "calc(50vw - 30vw)",
      width = "60vw",
      height = "60vh",
      class="panel panel-default",
      style = "z-index: 50000;",
      div(class = "panel-heading",
          textOutput("info_indicator"),
          actionLink(
            "info_close_button",
            label = NULL,
            top = 5,
            right = 5,
            style = "
              position: absolute;
              top: 5px;
              right: 10px;
              padding: 0px;
              font-size: 14px;
              color: gray;
            ",
            icon = icon("times")
          )
      ),
      
      div(class = "panel-body",
          uiOutput("info_text"))
    ) 
  )
)