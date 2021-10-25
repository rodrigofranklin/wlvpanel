
## GLOBAL ------

indicators_links <- NULL
groups_links <- NULL

plot_micro_graph <- function(value) {
  anos <- names(value)
  dados <- as.data.table(value)
  dados$year <- anos
  
  p <- ggplot(dados,aes(x=year,y=value, group = 1)) +
    geom_line(size = 0.2, colour = "red") +
    theme_classic() +
    theme(axis.title = element_blank(),
          axis.line = element_blank(),
          axis.ticks = element_blank(),
          axis.text = element_blank(),
          legend.position='none')
  
  p
  # ps <- ggplotly(p)
  
}

plotaserie2 <- function(dados,perc=F) {
  ##produz data.frame com cada versão para juntar
  
  if(length(dim(dados))>2){
    dados <- as.data.table(dados)
    print(head(dados))
    ifelse(ncol(dados)==5,
           names(dados) <- c("bd","ano","indicador","pais","valor"),
           names(dados) <- c("bd","ano","pais","valor")
    )
    print(dados$ano)
    dados <- dados %>% mutate(ano = as.Date(paste0("1/1/",ano),
                                            tryFormats="%d/%m/%Y"),
                              across(c(-ano,-valor),as.factor))
  }else{
    bds <- names(dados[,1])
    anos <- names(dados[1,])
    dados <- as.data.table(t(dados))
    dados$ano <- as.Date(paste0("01/01/",anos),
                         tryFormats="%d/%m/%Y")
    dados <- dados%>%pivot_longer(-ano,names_to = "bd",values_to="valor")%>%
      mutate(bd=as.factor(bd))
  }
  
  ifelse(ncol(dados)==3,
         p <- ggplot(dados,aes(x=ano,y=valor,col=bd)),
         p <- ggplot(dados,aes(x=ano,y=valor,col=pais,linetype=bd)))
  p <- p+geom_line(size = 1)  +
    geom_line(size = 1) +
    geom_point(colour = "white", pch = 21, size = 1.5)+
    theme_classic() +
    theme(axis.title = element_blank(),
          axis.line = element_blank(),
          axis.ticks = element_blank(),
          axis.text = element_text(size = 8, colour = "grey60"),
          legend.position='none')
  
  ps <- ggplotly(p)
  
}

ind_table <-  function (dados, sketch) {
  
  rowCallback <- c(
    "function(row, data, num, index){",
    "  var $row = $(row);",
    "  $row.css('background-color', 'white');",
    "  $row.hover(function(){",
    "      $(this).css('background-color', '#f6f6f6');",
    "     }, function(){",
    "      $(this).css('background-color', 'white');",
    "     }",
    "    )", 
    "}"  
  )

  dados <- datatable(
    dados,
    rownames = FALSE,
    selection = "none",
    container = sketch,
    options = list(
      ordering = TRUE,
      order = c(0, 'asc'),
      searching = FALSE,
      paging = FALSE,
      info = FALSE,
      rowCallback = JS(rowCallback),
      lengthChange = FALSE
    )
  )
  
  dados <- formatStyle(
    dados, 
    1,
    `font-weight` = 'bold', 
    `text-align` = 'left') 
  
  dados <- formatStyle(
    dados, 
    names(dados$x$data),
    `font-size` = '14px',
    `padding` = '15px')
  
  dados <- formatStyle(
    dados, 
    -1,
    `text-align` = 'right',
    `padding-right` = '30px')
}

## UI ---------

panel_indicators <- conditionalPanel(
  "output.show_indicator_panel != 0",
  absolutePanel(
    top = 45,
    left = 0,
    right = 0,
    height = "calc(100vh - 45px)",
    style = "
      overflow-y:scroll;
      background-color: rgba(242,243,246,1);
    ",
    
    tags$table(
      width = "100%",
      tags$tr( # Title
        tags$td(
          width = "75%",
          style = "
            font-size: 23px;
            font-weight: bold;
            padding: 20px;
          ",
          textOutput("ind_title")
        ),
        tags$td(
          width = "25%"
        )
      ),
      tags$tr( # Content
        tags$td(
          width = "75%",
          style = "
            padding: 20px;
          ",
          tags$table(
            width = "100%",
            tags$tr( # Graph
              tags$td(
                style = "
                  font-size: 14px;
                  vertical-align: middle;
                ",
                tabsetPanel(
                  id = "graphs_panel",
                  type = "pills",
                  tabPanel(
                    title = l("Graph"),
                    value = "Graph",
                    div(
                      width = "100%",
                      style = "
                        border-top-width: 1px;
                        border-top-style: solid;
                        height: 60vh !important;
                        font-size: 64px;
                        color: lightgray;
                        text-align: center;
                        vertical-align: middle;
                      ",
                      conditionalPanel(
                        "output.paises != ''",
                        plotlyOutput("serie",
                                     width = "100%",
                                     height = "60vh")
                      ),
                      conditionalPanel(
                        "output.paises == ''",
                        icon("exclamation-triangle")
                      )
                    )
                  ),
                  tabPanel(
                    title = l("Map"),
                    value = "Map",
                    div(
                      width = "100%",
                      style = "
                        border-top-width: 1px;
                        border-top-style: solid;
                        height: 60vh !important;
                        font-size: 64px;
                        color: lightgray;
                        text-align: left;
                        vertical-align: middle;
                      ",
                      leafletOutput("ind_map", width = "100%", height = "60vh")
                    )
                  )
                ) %>% 
                  tagAppendAttributes(
                    style = "
                      width: 100%;
                    "
                  ) %>% div(
                    class = "panel panel-default",
                  )
              )
            ),
            tags$tr( # Selected countries
              tags$td(
                conditionalPanel(
                  "input.paises.length >= 2",
                  l("Selected_countries_title") %>%
                    p(style = "
                      font-size: 18px; 
                      font-weight: bold;
                      margim-top: 80px;
                    "),
                  div(
                    width = "100%",
                    class = "panel panel-default",
                    style = "font-size: 14px; margim-bottom: 20px;",
                    dataTableOutput("ind_selected_countries")
                  )
                )
              )
            ),
            tags$tr( # Countries list
              tags$td(
                l("All_countries_title") %>%
                  p(style = "
                      font-size: 18px; 
                      font-weight: bold;
                      margim-top: 80px;
                    "),
                div(
                  width = "100%",
                  class = "panel panel-default",
                  style = "font-size: 14px;",
                  # uiOutput("ind_all_table")
                  dataTableOutput("ind_all_countries")
                )
              )
            )
          )
        ),
        tags$td(
          width = "25%",
          style = "
            vertical-align: top;
            padding-top: 20px;
            padding-right: 20px;
          ",
          div(
            style ="
                      position: sticky;
                      top:20px;
                    ",
            actionButton(
              "return_btn",
              label = l("Return to list"),
              width = "100%",
              style = "margin-bottom: 20px;"),
            # Controls
            div(
              id="controls",
              class = "panel panel-default",
              style = "
                background-color: rgba(255,255,255,1);
                padding: 20px 20px 0px 20px;
                font-size: 10px
              ",
              
              uiOutput("select.indicators"),
              
              uiOutput("select.country.ind"),
              
              sliderInput(
                "anoind",
                label = NULL,
                width = "100%",
                min = ano_min, 
                max = ano_max, 
                value = 2009, 
                ticks = F, 
                animate=F, 
                sep = ""),
              
              conditionalPanel(
                "input.graphs_panel == 'Graph'",
                uiOutput("select.bases")
              ),
              
              conditionalPanel(
                "input.graphs_panel == 'Map'",
                uiOutput("choose.bases")
              )
            ),
            # Downloads
            div(
              width = "100%",
              class = "panel panel-default",
              style = "
                background-color: rgba(255,255,255,1);
                padding: 5px 15px 5px 15px;
                font-size: 10px
              ",
              tags$table(
                tags$tr(
                  tags$td(
                    shiny::icon("download", style = "font-size: 28px; color: gray"),
                    rowspan = 2
                  ),
                  tags$td(
                    l("Download data"),
                    style = "padding: 0px 15px;
                      font-weight: bold;
                      font-size: 16px", width = "100%")
                ),
                tags$tr(
                  tags$td(
                    uiOutput("indicator_link"),
                    style = "text-align: center;
                      font-size: 12px"
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


## SERVER ------

panel_indicators_server <- function (IP, OP, RV) {
  
  lapply(meta_var$cod_var, function (y) {
    observeEvent(IP[[paste0(y, "_link")]],{
      show_indicator_panel(1)
      updateSelectInput(inputId = "indicadorind", selected = y)
      })
  })

  OP$indicators_links <- renderUI({
    
    # Seleciona apenas os grupos com conteúdo conforme pesquisa
    # do usuário
    if (IP$termo == "") {
      cod_vars <- meta_var$cod_var
      groups <- unique(meta_var$cod_group)
    } else {
      groups <- 
        unique(
          meta_var$cod_group[
            grep(
              IP$termo,
              language_file[meta_var$cod_var, IP$l],
              ignore.case = TRUE)]
        )
    }
    
    # Ordena os grupos pela ordem alfabética dos códigos
    groups <- groups[order(groups)]
    
    # Cria os links de todos os grupos (um grupo por vez)
    for (x in groups) {
      
      indicators_links <-  
        tagList(
          indicators_links,
          tags$tr(
            tags$td(
              colspan = 2,
              tags$hr(style = "margin: 0px;")
            )
          )
        )
      
      # Título do grupo de links
      indicators_links <-
        tagList(
          indicators_links,
          language_file[x, IP$l] %>%
            tags$span(id = paste0("anchor_",x)) %>%
            tags$td(
              colspan = 2,
              style = "
                font-size: 22px;
                font-weight: bold;
                padding: 30px 15px 20px 15px;
              ") %>%
            tags$tr()
        )
      
      
      # Os links podem ficar em duas colunas.
      link_position <- 1
      
      # seleciona apenas as variáveis com conteúdo conforme a 
      # pesquisa do usuário
      cod_vars <- meta_var$cod_var[meta_var$cod_group == x]
      if (IP$termo != "") {
        cod_vars <- cod_vars[
          grep(
            IP$termo,
            language_file[cod_vars, IP$l],
            ignore.case = TRUE)]
      }
      # Ordena em ordem alfabética dos rótulos
      cod_vars <- cod_vars[order(language_file[cod_vars,IP$l])]
      
      # Cria os links de todas as variáveis do grupo
      for (y in cod_vars) {
        # Rótulo do link
        link_text <- language_file[y, IP$l]
        if (IP$termo != "") {
          search <- IP$termo

          start <- regexpr(search, link_text, ignore.case = TRUE)
          stop <- start + nchar(search) -1
          part <- substr(link_text, start, stop)

          link_text <- tagList(
            span(substr(link_text, 0, start-1), .noWS =  c("after")),
            span(substr(link_text, start, stop), style = "background-color: #FFF3B5", .noWS =  c("after")),
            span(substr(link_text, stop+1, nchar(link_text)), .noWS =  c("after")),
          )
        }
        
        # Formata o link conforme a posição na página
        if (link_position == 1) { # link da direita
          first_link <- 
            actionLink(inputId = paste0(y, "_link"), label = link_text, 
                       style = "color: black !important") %>%
            tags$td(
              width = "50%",
              style = "
                padding: 10px 10px 10px 15px;
                font-size: 13.5px;
              ")
        } else { # link da esquerda (inclui fim da linha)
          second_link <- tags$tr(
            first_link,
            actionLink(inputId = paste0(y, "_link"), label = link_text, 
                       style = "color: black !important") %>%
              tags$td(
                width = "50%", 
                style = "
                padding: 10px 15px 10px 10px;
                font-size: 13.5px;
              ")
          )
          
          indicators_links <-  tagList( indicators_links,
                                        second_link)
          
        }
        # indica a posição do próximo gráfico
        link_position <- link_position * -1
      }
      # se o último gráfico foi da coluna direita, inclui fim da linha  
      if (link_position != 1) {
        indicators_links <-  tagList( indicators_links,
                                      first_link %>% tags$tr())
      }
      indicators_links <-  tagList( indicators_links,
                                    tags$td(tags$br(),tags$br()) %>% tags$tr())
    } # FIM da criação dos gráficos do país
    
    indicators_links %>% tags$table(width = "100%")
  })
  
  OP$groups_links <- renderUI({
    
    # Seleciona apenas os grupos com conteúdo conforme pesquisa
    # do usuário
    if (IP$termo == "") {
      cod_vars <- meta_var$cod_var
      groups <- unique(meta_var$cod_group)
    } else {
      groups <- 
        unique(
          meta_var$cod_group[
            grep(
              IP$termo,
              language_file[meta_var$cod_var, IP$l],
              ignore.case = TRUE)]
        )
    }
    
    # Ordena os grupos pela ordem alfabética dos códigos
    groups <- groups[order(groups)]
    
    # Cria os links de todos os grupos (um grupo por vez)
    for (x in groups) {
      
      groups_links <-  
        tagList(
          groups_links,
          tags$tr(
            tags$td(
              tags$hr(style = "margin: 0px;")
            )
          )
        )
      
      # Título do grupo de links
      groups_links <-
        tagList(
          groups_links,
          tags$a(
            href = paste0("#anchor_",x),
            language_file[x, IP$l],
            style = "color: black !important"
          ) %>%
            tags$td(
              style = "
                font-size: 13.5px;
                padding: 12px 20px;
              ") %>%
            tags$tr()
        )
    }
    
    groups_links %>% tags$table(width = "100%")
  })
  
  # Open/close system for indicator_panel
  show_indicator_panel <- reactiveVal(0)
  OP$show_indicator_panel <- renderText(show_indicator_panel())
  outputOptions(OP,"show_indicator_panel", suspendWhenHidden = FALSE)
  observeEvent(IP$return_btn, show_indicator_panel(0))
  
  OP$serie <- renderPlotly({
    dados <- sea_paises[IP$versao,,
                        IP$indicadorind,
                        IP$paises]
    plotaserie(dados)
  })
  
  outputOptions(OP, "serie", suspendWhenHidden = FALSE)

  # OP$ind_all_table <- renderUI({
  #   num_bases <- RV$bases()
  #   
  #   titles_buttons <- 
  #     tagList(
  #       lapply(RV$bases(), function(i) {
  #         tags$td(
  #           colspan = 2,
  #           actionButton(
  #             paste0("id_btn_",i),
  #             i,
  #             icon = icon("sort-alpha-down"),
  #             style = "
  #               width: 100%;
  #               color: grey;
  #               background-color: white;
  #               border-width: 0px 0px 5px 0px;
  #             "
  #           )
  #         )
  #       })
  #     )
  #   
  #   
  #   id_all_lines <- tagList(lapply(names(sea_paises[1,1,1,]), function(i) {
  #     tagList(
  #       tags$tr(
  #         tags$td(
  #           style = "padding: 5px;",
  #           language_file[i,IP$l]
  #         ),
  #         tagList(lapply(RV$bases(), function(y){
  #           tagList(
  #             tags$td(
  #               sea_paises[y,8,IP$indicadorind,i]
  #             ),
  #             tags$td(
  #               renderPlot(
  #                 width = 80,
  #                 height = 35,
  #                 plot_micro_graph(sea_paises[y,,IP$indicadorind,i]))
  #             )
  #           )
  #         }))
  #       ),
  #       tags$tr(
  #         tags$td(
  #           colspan = 100,
  #           tags$hr(style = "margin: 0px;")
  #         )
  #       )
  #     )
  #   }))
  #   
  #   tags$table(
  #     width = "100%",
  #     tags$tr( # Header
  #       tags$td(
  #         actionButton(
  #           "id_btn_country",
  #           l("id_btn_country"),
  #           icon = icon("sort-alpha-down"),
  #           style = "
  #             width: 100%;
  #             color: red;
  #             border-color: red;
  #             background-color: white;
  #             border-width: 0px 0px 5px 0px;
  #           "
  #         ),
  #       ),
  #       titles_buttons
  #     ),
  #     id_all_lines
  #   )
  # })
  
  ## ind_all_countries ----
  OP$ind_all_countries <- renderDT({
    dados <- t(rbind(
      language_file[names(sea_paises[1,1,1,]),IP$l],
      sea_paises[,as.character(IP$anoind),IP$indicadorind,]))
    
    sketch = withTags(table(
      thead(
        tr(
          th(language_file["id_btn_country", IP$l], style = "text-align: left;"),
          lapply(RV$bases(), th)
        )
      )
    ))

    ind_table(dados, sketch)

  })
  
  outputOptions(OP, "ind_all_countries", suspendWhenHidden = FALSE)
  
  ## ind_selected_countries ----
  OP$ind_selected_countries <- renderDT({
    dados <- t(rbind(
      language_file[names(sea_paises[1,1,1,IP$paises]),IP$l],
      sea_paises[,as.character(IP$anoind),IP$indicadorind,IP$paises]))
    
    sketch = withTags(table(
      thead(
        tr(
          th(language_file["id_btn_country", IP$l], style = "text-align: left;"),
          lapply(RV$bases(), th)
        )
      )
    ))
    
    ind_table(dados, sketch)
    
  })
  
  OP$ind_title <- renderText(
    language_file[IP$indicadorind, IP$l]
  )
  
  ## cell_clicked ----
  # Acrescenta países à lista de países selecionados
  observeEvent(IP$ind_all_countries_cell_clicked, {
    info = IP$ind_all_countries_cell_clicked

    if ((IP$paises == "WWW") && !(is.null(info$value))) {
      selected_countries <- 
        names(sea_paises[1,1,1,])[info$row]
    } else {
      selected_countries <- 
        unique(c(IP$paises, names(sea_paises[1,1,1,])[info$row]))
    }
    
    updateSelectInput(inputId = "paises", selected = selected_countries)
  }, ignoreInit = TRUE, ignoreNULL = TRUE, suspended = FALSE)
  
  OP$select.country.ind <- renderUI({
    country_list <- names(sea_paises[1,1,1,])
    names(country_list) <- language_file[country_list,IP$l]
    country_list <- c("",country_list)
    names(country_list)[1] <- language_file["Select countries...",IP$l]
    selectInput(
      "paises",
      label = NULL,
      width = "100%",
      choices = country_list,
      selected = c("WWW"),
      multiple = TRUE)
  })

  OP$select.indicators <- renderUI({
    indicators_list <- names(sea_paises[1,1,,1])
    names(indicators_list) <- language_file[indicators_list,IP$l]
    selectInput(
      "indicadorind",
      label = NULL,
      width = "100%",
      choices = indicators_list,
      selected = default_indicator
    )    
  })
  
  OP$select.bases <- renderUI({
    checkboxGroupInput(
      inputId = "versao",
      width = "100%",
      choices = RV$bases(), 
      selected = RV$bases(),
      label = NULL,
      inline = TRUE)
  })

  OP$choose.bases <- renderUI({
    radioButtons(
      inputId = "ind_map_base",
      width = "100%",
      choices = RV$bases(), 
      label = NULL,
      inline = TRUE)
  })

  # Download links países e setores
  OP$indicator_link <- renderUI({
    indicator_link <- NULL
    for (x in RV$bases()) {
      indicator_link <- tagList(
        indicator_link,
        tags$a(x, href = paste0("download/", x, "/indicator/", IP$indicadorind, ".xlsx")),
        "|")
    }
    indicator_link[1:(length(indicator_link)-1)]
  })
  
  # Usado para controlar exibição dos paineis. (Output carrega após Input)
  OP$paises <- renderText(IP$paises)
  outputOptions(OP, 'paises', suspendWhenHidden=FALSE)
  outputOptions(OP, 'paises', priority=100)
  
  ## Mapa ------
  OP$ind_map <- renderLeaflet({
    ind_map_data <- as.numeric(
      sea_paises[
        IP$ind_map_base,
        as.character(IP$anoind),
        IP$indicadorind,
        as.character(countries_polygons$ISO3)])
    
    num_countries <- 1:length(countries_polygons$ISO3)
    
    labels_ind <- 
      lapply(num_countries,
             function(i) {
               HTML(
                 paste0(
                   strong(language_file[
                     as.character(countries_polygons$ISO3[i]),
                     IP$l]),
                   ": ",
                   ind_map_data[i]
                 ))
             })
    
    palas <- colorBin("Reds", domain = ind_map_data)
    
    leaflet(
      data = countries_polygons,
      options = leafletOptions(
        zoomControl = TRUE,
        worldCopyJump = FALSE,
        minZoom = 0.5,
      )) %>%
      setView(lat = 0, lng = 0, zoom = 0.8) %>%
      setMaxBounds(-180, -90, 180, 90) %>%
      addPolygons(
        data = countries_polygons,
        fillColor = ~palas(ind_map_data),
        fillOpacity = 1,
        color = "grey",
        weight = 1,
        label = labels_ind,
        labelOptions = labelOptions(
          textsize = "9px",
          direction ="auto",
          style = list("font-weight" = "normal", padding = "3px 8px")))  %>%
      addLegend("bottomright",
                values = ind_map_data,
                pal = palas)
  })

}