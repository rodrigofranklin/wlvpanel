## Panel: country - all data
# Variáveis para serem usadas em UI:
# country_panel
# indicator_info_panel
#
# Função para ser chamada em server:
# panel_country_server(input, output)

## GLOBAL ----------------

# Inicia variáveis
country_graphs <- NULL # tagList com todos os gráficos e títulos de grupos


## Funções a reutilizar
plotaserie_country_all <- function(dados, anos, perc=F) {
  ##produz data.frame com cada versão para juntar
  
  base <- names(dados[,1])
  # names(dados[1,colSums(!is.na(dados[,]))!=0])
  dados <- as.data.table(t(dados[base,anos]))
  dados$year <- as.Date(paste0("01/01/",anos),
                        tryFormats="%d/%m/%Y")
  dados <- dados%>%pivot_longer(-year,names_to = "base",values_to="value")%>%
    mutate(base=as.factor(base))

  if((length(anos) %% 2) != 0) {
    metade <- (length(anos)+1)/2
    break_years <- c(as.Date(paste0(min(anos),"-01-01")),
                     as.Date(paste0(anos[metade],"-01-01")),
                     as.Date(paste0(max(anos),"-01-01")))
    labels_years <- c(as.character(min(anos)),
                      as.character(anos[metade]),
                      as.character(max(anos)))
  } else {
    metade <- (length(anos))/2
    break_years <- c(as.Date(paste0(min(anos),"-01-01")),
                     as.Date(paste0(anos[metade-1],"-01-01")),
                     as.Date(paste0(anos[metade+2],"-01-01")),
                     as.Date(paste0(max(anos),"-01-01")))
    labels_years <- c(as.character(min(anos)),
                      as.character(anos[metade-1]),
                      as.character(anos[metade+2]),
                      as.character(max(anos)))
  }
  
  p <- ggplot(dados,aes(x=year,y=value,col=base))
  
  p <- p +
    geom_line( size = 0.5)  +
    geom_line(size = 0.5)  +
    scale_x_date(breaks = break_years, labels = labels_years) +
    theme_classic() +
    theme(axis.title = element_blank(),
          axis.line = element_blank(),
          axis.ticks = element_blank(),
          axis.text = element_text(size = 8, colour = "grey60"),
          legend.position='bottom',
          legend.title = element_blank())
  
  if (min(dados$value, na.rm = TRUE)<0 & max(dados$value, na.rm = TRUE)>0) {
    p <- p +
      geom_hline(yintercept=0, size = 0.1, color = "grey80")
  }
  
  ggplotly(p, tooltip = c("value", "base")) %>%
    plotly::layout(legend = list(title = "", orientation = "h", y="-0.1"))
  
}

## UI --------------------

# Modelo de gráficos
graphPanel <- function (indicator) {
  div(
    class = "panel panel-default",
    width = "100%",
    height = 250,
    tags$table(
      width = "100%",
      tags$tr(
        tags$td(
          width = "100%",
          actionLink(
            inputId = paste0(indicator,"_title"),
            label = l(indicator),
            style = "
              font-size:14px; 
              font-weight: bold;
              color: gray;
            "
          )
        ),
        tags$td(
          actionLink(
            inputId = paste0(indicator,"_info"),
            label = NULL,
            style = "
              text-align: right;
              font-size:14px; 
              color: gray;
            ",
            icon = icon("info-circle")
          )
        )
      )
    ) %>%
      div(class = "panel-heading",
          style = "background-image:none;
                  background: white;
                  border: none;
                  padding: 3px 5px;
                  "),
    plotlyOutput(paste0(indicator,"_plot"), height = 220, width = "32vw") %>%
      div(class = "panel-body",
          style = "
            padding:0px;
            text-align: center;
          ")
  )
} # FIM modelo de gráfico



# Cria todas as tags para os gráficos do país na variável country_graphs
for (x in var_groups$cod_group) {
  
  # Título do gráfico
  country_graphs <-  tagList(
    country_graphs,
    l(x) %>%
      tags$td(
        colspan = 2,
        style = "
            font-size: 18px;
            font-weight: bold;
          "
      ) %>%
      tags$tr()
  )

  # Os gráficos podem ficar em duas colunas.
  graph_position <- 1
  
  # Gráficos do grupo
  for (y in meta_var$cod_var[meta_var$cod_group == x]) {
    
    if (graph_position == 1) { # gráfico da direita
      first_graph <- graphPanel(y) %>%
        tags$td(width = "50%", style = "padding-right: 10px")
    } else { # gráfico da esquerda (inclui fim da linha)
      second_graph <- tagList(
        first_graph,
        graphPanel(y) %>%
          tags$td(style = "padding-left: 10px")) %>%
        tags$tr()
      
      country_graphs <- tagList(
        country_graphs,
        second_graph
      )
    }
    # indica a posição do próximo gráfico
    tam <- reactiveVal(value = 1)
    graph_position <- graph_position * -1 *tam(!(exists("dimension"))|ifelse(!exists("dimension"),1,dimension>900))
    
  }
  # se o último gráfico foi da coluna direita, inclui fim da linha  
  if (graph_position != 1) {
    country_graphs <- tagList(
      country_graphs,
      first_graph %>% tags$tr()
    )
  }
} # FIM da criação dos gráficos do país


# Painel dos países
country_panel <- conditionalPanel(
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
  actionButton(inputId = "fillpais", label = "Fill Cache",
               style ="
            border-radius: 50%;
            border-color: transparent;
            color: white;
            font-size: 12px;
            position: absolute;
            top: 58px;
            left: calc(50vw - 145px);
            z-index: 501;
            background-color: rgba(127,50,50,0.3);
          "
  ),
  
  absolutePanel(
    top = 75,
    left = 10,
    height = "calc(100vh - 75px)",
    width = "calc(100vw - 20px)",
    style = "
            z-index:500;
            padding: 20px;
            background-color: rgba(242,243,246,1);
            border: solid;
            border-width: 1px;
            border-color: rgba(221,221,221,1);
          ",
    
    # Título
    
    tags$head(tags$style(HTML("
      .selectize-input {}
      #pais_detalhado+ div>.selectize-input{
        background: url('search3.png') top left     no-repeat;
        height: 42px;
        padding-left:41px;
        font-size: 28px;
    }"))),
    tags$table(
      width = "100%",
      tags$tr(
        tags$td(
          width = "50%",
          selectInput(
            "pais_detalhado",
            label = NULL,
            choices = lista_paises,
            width = "100%"
          )
        ),
        tags$td(
          width = "50%",
          style = "padding-left: 20px; padding-right: 20px;",
          
          uiOutput("select.year.panel_country")
          
        )
      )
    ),
    

  # Painel dados país
  absolutePanel(
    top = 75,
    left = 0,
    height = "calc(100vh - 152px)",
    width = "100%",
    style = "
            overflow-y:scroll;
            z-index:500;
            padding: 0px 20px;
            background-color: rgba(242,243,246,1);
            border: solid;
            border-width: 0px;
            border-color: rgba(221,221,221,1);
          ",
    
    
    tags$table(
      tags$tr(
        tags$td(
          valign="top",
          width = "70%",
          tags$table(
            width = "100%",
            tags$tr(
              tags$td( # Profile
                colspan = 2,
                # p(
                #   style = "text-align: left;
                #       font-weight: bold;
                #       font-size:24px",
                #   "Country profile - ",
                #   textOutput("ano1", inline = TRUE)
                # ),
                
                div(
                  style = "width: 100%",
                  class = "panel panel-default",
                  
                  # tagList(
                  #   "Country profile - ",
                  #   textOutput("ano1", inline = TRUE)
                  # ) %>%
                  #   div(
                  #     class = "panel-heading",
                  #     style = "
                  #       background-image:none;
                  #       background: white;
                  #       font-size: 16px; 
                  #       font-weight: bold;
                  #       padding: 3px 5px;
                  #     "
                  #   ),
                  
                  dataTableOutput("profile") %>%
                    div(
                      class = "panel-body",
                      style = "
                        background-image:none;
                        background: white;
                        padding: 0px;
                      "
                    )
                )
              )
            ),
            #TODOS OS GRÁFICOS
            country_graphs
          )
        ),
        tags$td(
          valign="top",
          style = "padding-left : 20px;",
          tags$table(
            tags$tr(
              tags$td( # Download
                div(
                  left = "calc(68% + 60px)",
                  class = "panel panel-default",
                  tags$table(
                    tags$tr(
                      tags$td(
                        shiny::icon("flag", style = "font-size: 28px; color: gray"),
                        rowspan = 2
                      ),
                      tags$td(
                        l("Download country data"),
                        style = "padding: 0px 15px;
                      font-weight: bold;
                      font-size: 16px", width = "100%")
                    ),
                    tags$tr(
                      tags$td(
                        uiOutput("country_link"),
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
                                    style = "font-size: 28px; color: gray"),
                        rowspan = 2
                      ),
                      tags$td(
                        l("Download sector data"),
                        style = "padding: 0px 15px;
                      font-weight: bold;
                      font-size: 16px", width = "100%")
                    ),
                    tags$tr(
                      tags$td(
                        uiOutput("sector_data_link"),
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
                )
              )
            ),
            tags$tr(
              tags$td( # Distribuição setorial
                # Esse height precisa ser até o fim dos gráficos, 
                # para a distribuição ficar sticky
                valign="top",
                style = paste0(
                  "height: ",
                  as.character(
                    ((length(meta_var$cod_var) /2)*250) +
                      (length(var_groups$cod_group)*250)),
                  "px;
                  padding-top : 0px;"),
                
                div(

                  style ="
                      position: sticky;
                      top:0px;
                    ",
                  p(
                    l("Sector Data"),
                    " - ", 
                    textOutput("ano2", inline = TRUE),
                    style = "text-align: center;
                        font-weight: bold;
                        font-size:24px"),

                  div(
                    class = "panel panel-default",
                    textOutput("indicador") %>%
                      div(class = "panel-heading",
                          style = "background-image:none;
                            background: white;
                            font-size:16px;
                            font-weight: bold;
                            padding: 3px 5px;
                          "),
                    div(
                      class = "panel-body",
                      style = "padding: 0px;",
                      uiOutput("tabs_setorial_data")
                    ) 
                  )
                )
              )
            )
          )
        )
      )
    )
  )
  )
)

# Indicator_info_panel
indicator_info_panel <- conditionalPanel(
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
          z-index: 1000;
        "
  ),
  
  absolutePanel(
    top = "calc(50vh - 30vh)",
    left = "calc(50vw - 30vw)",
    width = "60vw",
    height = "60vh",
    class="panel panel-default",
    style = "z-index: 1000;",
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
) # FIM indicator_info_panel

## SERVER ----------------

# Tabela de resumo, distribuição setorial e gráficos de todas as variáveis
# cria outputs para todos os gráficos e observeEvents para todos os títulos
# e icones de info
# ANTEÇÃO: NÃO USAR "FOR"

panel_country_server <- function(input, output, RV) {

  lapply(varst$var, function(i) {
    output[[paste0(i,"_plot")]] <- renderPlotly({
      dados <- sea_paises[RV$bases(),,i,input$pais]
      anos <- as.character(RV$anomin():RV$anomax())
      plotaserie_country_all(dados, anos)
    })%>%bindCache(i,input$pais,RV$bases())
    outputOptions(output,paste0(i,"_plot"), suspendWhenHidden = FALSE)
    
    observeEvent(input[[paste0(i,"_info")]],{
      info_indicator(i)
      show_info_panel(1)
      
    })
    
    observeEvent(input[[paste0(i,"_title")]], ignoreInit = TRUE, {
      updateSelectInput(inputId = "indicator", selected = i)
    })
    
  })  
  
  # Open/close system for info_panel
  show_info_panel <- reactiveVal(0)
  output$show_info_panel <- renderText(show_info_panel())
  outputOptions(output,"show_info_panel", suspendWhenHidden = FALSE)
  observeEvent(input$info_close_button, show_info_panel(0))
  onclick(id = "info_background", show_info_panel(0))
  
  info_indicator <- reactiveVal("")
  output$info_indicator <- renderText({
    varst$pt[varst$var == info_indicator()]
  })
  
  output$info_text <- renderUI({
    tagList(
      p(strong(l("Code_")),
        info_indicator(),
        style = "text-align: justifY;"),
      p(strong(l("Description_")),
        l(paste0("DESC.",info_indicator())),
        style = "text-align: justifY;"),
      p(strong(l("Observations_")),
        l(paste0("OBS.",info_indicator())),
        style = "text-align: justifY;")
    )
  })
  
  # Usado para controlar exibição dos paineis. (Output carrega após Input)
  output$pais <- renderText(paises[paises$Legenda==input$pais,1])
  outputOptions(output, 'pais', suspendWhenHidden=FALSE)
  outputOptions(output, 'pais', priority=100)
  
  output$ano1 = output$ano2 <- renderText(input$ano)

  output$select.year.panel_country <- renderUI({
    sliderInput(
      "ano_detalhado",
      label = NULL,
      width = "100%",
      min = RV$anomin(),
      max = RV$anomax(),
      value = 2009,
      ticks = F,
      animate = F,
      sep = "")
  })
  
  output$indicador <- renderText(varst$pt[varst$var==RV$indicator()])
  
  # Botão para fechar painel e voltar para o mapa
  observeEvent(
    input$close_country_data_panel,
    updateSelectInput(inputId = "pais", selected = "")
  )
  
  
  output$profile <- renderDataTable(server = F,{
    if (length(RV$bases()) == 1) {
      profile_table <- 
        data.frame(
          sea_paises[RV$bases(),
                     as.character(input$ano),
                     perfil_sumario,
                     input$pais])
      rownames(profile_table) <- language_file[rownames(profile_table),input$l]
      colnames(profile_table) <- RV$bases()
    } else {
      profile_table <- 
        data.frame(
          t(sea_paises[RV$bases(),
                       as.character(input$ano),
                       perfil_sumario,
                       input$pais]))
      rownames(profile_table) <- language_file[rownames(profile_table),input$l]
    }
    profile_table},
    rownames = TRUE,
    class = "profile_table",
    options = list(
      ordering = FALSE,
      searching = FALSE,
      paging = FALSE,
      info = FALSE,
      lengthChange = FALSE
    )
  ) %>%bindCache(RV$bases(),input$ano,input$pais,input$l)
  
  # output$profile <- renderDataTable(
  #   tabmil(t(sea_paises[unique(c(input$base1,
  # input$base2,
  # input$base3,
  # input$base4
  # )),as.character(input$ano),,input$pais]))%>%
  #     filter(var %in% c(input$indicador,perfil_sumario))%>%
  #     arrange(match(var,c(input$indicador,perfil_sumario)))%>%
  #     left_join(varst)%>%
  #     select(var = pt, 2:3),
  #   rownames = FALSE,
  #   class = "profile_table",
  #   options = list(
  #     ordering = FALSE,
  #     searching = FALSE,
  #     paging = FALSE,
  #     info = FALSE,
  #     lengthChange = FALSE
  #   )
  # )
  
  # Download links países e setores
  output$country_link <- renderUI({
    country_link <- NULL
    for (x in RV$bases()) {
      country_link <- tagList(
        country_link,
        tags$a(x, href = paste0("download/COUNTRY.",input$pais,".", x, ".xlsx")),
        "|")
    }
    country_link[1:(length(country_link)-1)]
  })

  output$sector_data_link <- renderUI({
    sector_data_link <- NULL
    for (x in RV$bases()) {
      sector_data_link <- tagList(
        sector_data_link,
        tags$a(x, href = paste0("download/SECTORS.",input$pais,".", x, ".xlsx")),
        "|")
    }
    sector_data_link[1:(length(sector_data_link)-1)]
  }) # FIM dos links


  # TabSetPanel de distribuição setorial
  output$tabs_setorial_data <- renderUI({
    tabs_setorial_data <- lapply(
      if (length(RV$bases()) != 1){
        names(
        sea_paises[RV$bases(),
                   as.character(input$ano),
                   RV$indicator(),
                   input$pais][
                     !is.na(
                       sea_paises[RV$bases(),
                                  as.character(input$ano),
                                  RV$indicator(),
                                  input$pais]
                       )
                   ])}
      else {
        RV$bases()
      }, 
      function(i){
        tabPanel(i,dataTableOutput(paste0("setores_pais_",i)))
    })
    do.call(tabsetPanel, tabs_setorial_data) %>%
      tagAppendAttributes(type = "pills")
  })

  lapply(lista_versoes, function(i) {
    name_i <- paste0("setores_pais_",i)
    output[[name_i]] <- renderDataTable(server = F,{
      sector_table <- sea_sectors[[i]][as.character(input$ano),
                                       RV$indicator(),,
                                       input$pais]
      names(sector_table) <-
        lapply(
          names(sector_table),
          function(i) {
            language_file[paste0("SEC.CODE.",i), input$l]
          }
        )
      sector_table <- data.frame(sector_table)
      colnames(sector_table) <- input$ano
      sector_table},
      rownames = TRUE,
      options = list(
        ordering = TRUE,
        searching = FALSE,
        paging = FALSE,
        scrollY= "calc(100vh - 280px)",
        info = FALSE,
        lengthChange = FALSE
      )
    )%>%bindCache(input$ano,RV$indicator(),input$pais,input$l)
  }) #FIM da distribuição setorial
  

  observeEvent(
    input$pais, {
      updateSelectizeInput(
        inputId = "pais_detalhado",
        selected = input$pais
      )
      # if (input$pais != "") {
      #   lapply(varst$var, function(i) {
      #     outputOptions(output, paste0(i,"_plot"), suspendWhenHidden = FALSE)
      #   })
      # } else {
      #   lapply(varst$var, function(i) {
      #     outputOptions(output, paste0(i,"_plot"), suspendWhenHidden = TRUE)
      #   })
      # }
    }
  )
  
  observeEvent(input$pais_detalhado, updateSelectInput(
    inputId = "pais",
    selected = input$pais_detalhado
  ))
  
  observeEvent(
    input$ano, 
    updateSelectizeInput(
      inputId = "ano_detalhado",
      selected = input$ano
    )
  )
  
  observeEvent(input$ano_detalhado, updateSelectInput(
    inputId = "ano",
    selected = input$ano_detalhado
  ))
  
}

