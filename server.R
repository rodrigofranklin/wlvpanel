
server <- function(input, output, session) {

  ### Country indicator panel com transparência
  output$country_indicator_panel <- renderUI({
    if (input$pais != "") {
      absolutePanel(
        top = 45,
        left = 0,
        width = "40%",
        style = "
        background-color: rgba(0,0,0,0.3); 
        z-index: 100;
        height: calc(100vh - 45px)
      ",
        
        # close button
        absolutePanel(
          right = 0,
          actionLink(
            "close_button",
            label = NULL, 
            style = "padding: 10px; font-size: 14px; color: white; right:0",
            icon = icon("times")
          )
        ),
        
        paises[ paises$Legenda==input$pais, 1] %>%
          div(style = "
              position: relative;
              top: 70px;
              font-size: 38px;
              font-weight: bold;
              text-align: center;
          "),
        
        plotlyOutput("country_indicator_graph") %>%
          div(
            style = "
              position: relative;
              top: 30vh;
            ",
          ),
        
        # Show_me_more Button
        actionButton(
          "show_me_more",
          label = "Show me more",
        ) %>%
          div(style = "
              position: relative;
              top: 300px;
              font-size: 24px;
              text-align: center;
          ")
      )
    }
  })
  
  outputOptions(output, "country_indicator_panel", priority = 10)
  
  show_panel <- reactiveVal(-1)
  
  observeEvent(input$show_me_more, {
    show_panel(show_panel() * -1)
  })
  
  # Botão para fechar painel e voltar para o mapa
  observeEvent(
    input$close_button,
    {updateSelectInput(inputId = "pais", selected = "")
    show_panel(show_panel() * -1)}
    
  )
  
  
  #### Cria todos os outputs para os gráficos do país
  top <- 285
  country_graphs <- NULL
  
  for (x in var_groups$cod_group) {
    # Printar linha do título do grupo
    
    country_graphs <- country_graphs %>% tagList(
      var_groups$group_name[x] %>%
        absolutePanel(
          top = top,
          style = "font-size: 18px;
                font-weight: bold;"
        )
    )
    
    top <- top + 25
    left <- "20px"
    graph_position <- 1
    
    for (y in meta_var$cod_var[meta_var$cod_group == x]) {
      # printar cada gráfico
      country_graphs <- country_graphs %>% tagList(
        graphPanel(y, top, left)
      )
      if (graph_position != 1) {
        top <- top + 270
        left <- "20px"
      } else {
        left <- "34% + 40px"
      }
      graph_position <- graph_position * -1
    }
    if (graph_position == 1) {
      top <- top + 25
    } else {
      top <- top + 275
    }
      
  }
  # Fim da criação dos gráficos do país
  
  style_distribuicao <- paste0(
   "top: 190px;left: calc(68% + 60px);right: 5px;height: ", top, "px;"
   )
  
  output$country_data_panel <- renderUI({
    if (show_panel() == 1) {
      tagList(

        # Botão fechar
        actionButton(
          inputId = "close_country_data_panel",
          label = NULL,
          icon = icon("times"), # Esse ícone só está carregando se colocar um ícone no meno do navbar...
          style ="border-radius: 50%;
                  border-color: transparent;
                  color: white;
                  font-size:12px;
                  position: absolute;
                  top: 58px;
                  left: calc(50vw - 17px);
                  z-index: 501;
                  background-color: rgba(127,127,127,1)"
        ),
        
        # Painel dados país
        absolutePanel(
          top = 75,
          left = 10,
          style =
            "overflow-y:scroll;
            z-index:500;
            height: calc(100vh - 75px);
            padding: 20px;
            width:calc(100vw - 20px);
            background-color: rgba(242,243,246,0.95);
            border: solid;
            border-width: 1px;
            border-color: rgba(221,221,221,1);",

          paises[paises$Legenda==input$pais,1] %>%
            div(style = "font-size: 24px;
                font-weight: bold") ,
          
          # country profile
          absolutePanel(
            top = 70,
            left = 20,
            style = "width: calc(68% + 20px)",
            class = "panel panel-default",
            

              fluidRow(
                column(
                  width = 6,
                  paste("Country Profile -", input$ano)
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

              div(class = "panel-heading",
                  style = "background-image:none;
                  background: white;
                  font-size: 16px; 
                  font-weight: bold;
                  padding: 3px 5px;
                  "),
            
            dataTableOutput("profile") %>%
              div(class = "panel-body",
                  style = "background-image:none;
                  background: white;
                  padding: 0;")
          ),
          
          # Painel de download
          absolutePanel(
            top = 70,
            right = 5,
            # height = 100,
            style = "
              left: calc(68% + 60px);
            ",
            
              class = "panel panel-default",
            
            tagList(
              shiny::icon("flag",
                   style = "color: gray"),
              " Download country data"
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
              " Download setorial data") %>%
              div(class = "panel-body",
                  style = "background-image:none;
                  background: white;
                  font-size: 16px; 
                  font-weight: bold;
                  padding: 15px !important;
                  ")
            
            
          ),
          
          country_graphs,

          
        # Painel de distribuição setorial
        absolutePanel(
          style = style_distribuicao,
          
          div(
            class = "panel panel-default",
            style ="
              position:sticky;
              top:0;
              height: calc(100vh - 120px);

            ",
          "Setorial distribution" %>%
            div(class = "panel-heading",
                style = "background-image:none;
                  background: white;
                  font-size:16px; 
                  font-weight: bold;
                  padding: 3px 5px;
                  "),
          tagList(
            input$indicador,
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
                style = "padding:0")
        
        ))
        )
        
        
      )}
  })
  
  output$show_config_panel <- reactive(input$config_button)
  
  output$map <- renderLeaflet({
    # Use leaflet() here, and only include aspects of the map that
    # won't need to change dynamically (at least, not unless the
    # entire map is being torn down and recreated).
    leaflet(
      options = leafletOptions(
        zoomControl = FALSE,
        worldCopyJump = TRUE,
        minZoom = 2,
      )) %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(lat = 0, lng = 0, zoom = 2)
  })
  

  ####
  ##Reactive values to use in more than one place (titles, popups)
  titspais <- reactive({ 
    return(paste(varst[varst$var==input$indicador,"pt"]))
  })
  
  subtspais <- reactive({
    return(paste0(paises[paises$Legenda==input$pais,1],
                  ", ",
                  as.character(ano_min),
                  " - ",
                  as.character(ano_max)))
  })
  
  #-------- Valores reativos para utilizar no leaflet
  # camada_base1 (talvez incluir novas camadas para outras bases?)
  # labels (para o hover)
  # fill_group (para selecionar os elementos a apagar (o objetivo é permitir
  # apagar os poligonos antigos após desenhar os novos))
  
  camada_base1 <- reactive({
    basecam <- sea_paises[1,as.character(input$ano),input$indicador,]
    camadas <- 
      joinCountryData2Map(
        enframe(basecam),
        nameJoinColumn = "name",
        mapResolution = "low")
    camadas <- camadas[camadas$ISO3 %in% paises$Legenda,]
    camadas
  })
  
  labels <- reactive(
    sprintf(
      "<p style='
      text-align: center;
      border-style: none none solid;
      border-width: 1px;
      font-weight: bold'>
      %s</p>%s : %g %s",
      camada_base1()$ADMIN,
      input$indicador,
      camada_base1()$value,
      varst[varst$var == input$indicador,"type"]) %>%
      lapply(htmltools::HTML)
  )
  
  fill_group <- reactiveVal(0)
  
  # Atualização dos polígonos conforme os dados são alterados
  observeEvent(camada_base1(),{

    palas <- colorBin("Reds", domain = camada_base1()$value)
    fill_group(fill_group()+1)
    
    proxy <- leafletProxy("map")
    proxy   %>%
      # clearShapes() %>%
      addPolygons(
        data = camada_base1(),
        fillColor = ~palas(value),
        fillOpacity = 0.6,
        group = as.character(fill_group()),
        color = "#EBD6D8",
        weight = 1,
        label = labels(),
        labelOptions = labelOptions(
          textsize = "9px",
          direction ="auto",
          style = list("font-weight" = "normal", padding = "3px 8px")),
        highlightOptions = highlightOptions(
          color = "#666",
          fillOpacity = 0.7,
          bringToFront = TRUE)) %>%
      clearGroup(as.character(fill_group()-1)) %>%
      removeControl(as.character(fill_group()-1))  %>%
      addLegend("bottomright",
                layerId = as.character(fill_group()),
                values = camada_base1()$value,
                title = titspais(),
                pal = palas)
  })
  
  # Botão para fechar painel e voltar para o mapa
  observeEvent(
    input$close_country_data_panel,
    show_panel(show_panel() * -1)
  )
  
  # efeito do clique no mapa: selecionar país e mostrar painéis
  observeEvent(input$map_click, {
    click <- input$map_click
    piso3 <- coords2country(data.frame(lng = click$lng, lat = click$lat))
    if (piso3 %in% paises$Legenda) {
      updateSelectInput(inputId = "pais",
                      selected = piso3)
    }
  })
  
  
  # observeEvent(input$map_hover, {
  #   hover <- input$map_hover
  #   piso3 <- coords2country(data.frame(lng = hover$lng, lat = hover$lat))
  #   paises%>%filter(Legenda = piso3)$Legenda
  #   valorpontopais <- sea_paises[,as.character(max(input$ano)),,pafil]
  #   text <- paste("Country:",pafil,"<br>",
  #                 titspais(),"-",subtspais(),":",
  #                 valorpontopais)
  #   proxy <-leafletProxy("map")
  #   proxy %>% clearPopups() %>%
  #     addLabelOnlyMarkers(hover$lng,hover$lat,label = text)
  # })
  
  linhas_13 <- reactive({
    encontrar_pais(m_io_13, input$pais, rownames)
  })
  
  colunas_13 <- reactive({
    encontrar_pais(m_io_13, input$pais_transacoes, colnames)
  })
  
  linhas_16 <- reactive({
    encontrar_pais(m_io_16, input$pais_transacoes, rownames)
  })
  
  colunas_16 <- reactive({
    encontrar_pais(m_io_16, input$pais_transacoes, colnames)
  })

  comerciantes_p <-  function(bd=13,pais = input$paistrade,ano = input$anotrade, elemento = "exportacoes_pm",qtde = 15) {
      mat <- get(paste0("m_paises_",bd))
      mat <- mat[as.character(ano),elemento,pais,]
      paises <- names(sort(mat,T)[2:(qtde+1)])
    }


  

  fazer_selecao <- reactive({
    switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
           "WIOD13Agregado" = 1,
           "WIOD13Por setor de origem" = 2,
           "WIOD16Agregado" = 3,
           "WIOD16Por setor de origem" = 4
    )
  })

  prep_treemap <- function(bd=input$transacoes_versao,
                           pais = input$pais,
                           ano = input$ano,
                           agr = input$transacoes_agregacao,
                           el = "exportacoes_pm",
                           qcorte = T,
                           qtde = 15,
                           agru = agrupamento,
                           pod = 1) {
    bd <- ifelse(grepl("13",bd),13,16)
    p <- comerciantes_p(bd,pais,ano,el,10)
    dados <- get(paste0("m_io_",bd)) %>%
      agregado(ano, el, get(paste0("linhas_",bd))()) %>%
      as.data.table(keep.rownames = "paisect")%>%
      separate(paisect,c("pais_origen","sector_origen"),sep="\\.")%>%
      select(-pais_origen)%>%
      pivot_longer(-c(sector_origen),names_to="paisect_d",values_to="valor")%>%
      separate(paisect_d,c("pais_d","sect_d"),sep="\\.")%>%
      mutate(pais_d = ifelse(pais_d %in% p,pais_d,"ROW"))%>%
      dplyr::group_by(across(all_of(agru)))%>%
      summarize(valor=sum(valor))%>%
      left_join(paises, by = c("pais_d" = "Legenda"))%>%
      left_join(setorest,by = c("sect_d" = "Code"))%>%
      transmute(pais_d = `Países`,sect_d = pt, valor)%>%
      mutate(across(-valor,as.factor))%>% ungroup()
    
    dados
  }
  
  dados <- reactive({
    paste0(input$transacoes_versao)
  })
  
  
  output$profile <- renderDataTable(
    
    tabmil(t(sea_paises[,as.character(input$ano),,input$pais]))%>%
      filter(var %in% c(input$indicador,perfil_sumario))%>%
      arrange(match(var,c(input$indicador,perfil_sumario)))%>%
      left_join(varst)%>%
      select(var = pt, 2:3),
    rownames = FALSE,
       # spacing = "xs",
       # striped = TRUE,
       # hover = TRUE,
       # width = "100%",
    class = "profile_table",
    options = list(
      ordering = FALSE,
      searching = FALSE,
      paging = FALSE,
      #      scrollY = "200",
      # pageLength = 10,
      info = FALSE,
      lengthChange = FALSE
    )
  )
  
  lapply(varst$var, function(i) {
    output[[i]] <- renderPlotly({
      dados <- sea_paises[,,i,input$pais]
      plotaserie(dados)
    })
    
    outputOptions(output,i, suspendWhenHidden = FALSE)
    outputOptions(output,i, priority = 0)
  })
  
  output$setores_pais_13 <- renderDataTable(
    tabmil(sea_setores_13[as.character(input$ano),
                          input$indicador,,
                          input$pais])%>%
      left_join(setorest,by=c("var" = "Code"))%>%
      select(sector=pt,value=x),
    options = list(
      ordering = TRUE,
      searching = FALSE,
      paging = FALSE,
      #pageLength = 8,
      scrollY= "calc(100vh - 250px)",
      info = FALSE,
      lengthChange = FALSE
    )
  )
  
  output$setores_pais_16 <- renderDataTable(
    tabmil(sea_setores_16[as.character(input$ano),
                          input$indicador,,
                          input$pais])%>%
      left_join(setorest,by=c("var" = "Code"))%>%
      select(sector=pt,value=x),
    options = list(
      ordering = TRUE,
      searching = FALSE,
      paging = FALSE,
      #pageLength = 8,
      scrollY= "calc(100vh - 250px)",
      info = FALSE,
      lengthChange = FALSE
    )
  )
  
  
   output$indicadores <- renderDT(
    {
      dados <- t(rbind(
        paises[match(names(sea_paises[1,1,1,]),paises[,3]),1],
        sea_paises[,as.character(input$anoind),input$indicadorind,]))
      dados <- datatable(dados,
                rownames = 1,
                options = list(
                  ordering = TRUE,
                  searching = TRUE,
                  paging = FALSE,
                  info = TRUE,
                  #pageLength = 8,
                  scrollY= 220,
                  lengthChange = FALSE

                )
      ) %>%
        formatPercentage("WIOD13", 2)
      formatStyle(dados, names(dados$x$data),`line-height` = '10px')
    },
  )
   
  output$serie <- renderPlotly({
    dados <- sea_paises[input$versao,,
                        input$indicadorind,
                        input$paises]
    plotaserie(dados)
  })
  
  output$country_indicator_graph <- renderPlotly({
    dados <- sea_paises[,,
                        input$indicador,
                        input$pais]
    plotaserie(dados)
  })
  
  ### sobre esses outputs que se seguem: é preciso melhorar. Seria possível ter
  ### uma única função que fosse chamada conforme a seleção de (exportação,
  ### importação e saldo), e chamada 3 vezes (monetária, valor e transferência)?
  # Problema: os dados de exportacoes, importacoes e saldo são distintos.
  # Mas são os mesmos dados conforme o tipo de variável (monetário, valor transf)
  # No entanto, os gráficos conforme tipo de variábel são concomitantes.

### Sim certamente possível
  
  prep_treemap <- function(bd=input$transacoes_versao,
                           pais = input$paistrade,
                           ano = input$anotrade,
                           agr = input$transacoes_agregacao,
                           el = "exportacoes_pm",
                           qcorte = T,
                           qtde = 15,
                           agru = agrupamento,
                           pod = 1) {
    bd <- ifelse(grepl("13",bd),13,16)
    p <- comerciantes_p(bd,pais,ano,el,10)
    dados <- get(paste0("m_io_",bd)) %>%
      agregado(ano, el, get(paste0("linhas_",bd))()) %>%
      as.data.table(keep.rownames = "paisect")%>%
      separate(paisect,c("pais_origen","sector_origen"),sep="\\.")%>%
      select(-pais_origen)%>%
      pivot_longer(-c(sector_origen),names_to="paisect_d",values_to="valor")%>%
      separate(paisect_d,c("pais_d","sect_d"),sep="\\.")%>%
      mutate(pais_d = ifelse(pais_d %in% p,pais_d,"ROW"))%>%
      dplyr::group_by(across(all_of(agru)))%>%
      summarize(valor=sum(valor))%>%
      left_join(paises, by = c("pais_d" = "Legenda"))%>%
      left_join(setorest,by = c("sect_d" = "Code"))%>%
      transmute(pais_d = `Países`,sect_d = pt, valor)%>%
      mutate(across(-valor,as.factor))%>% ungroup()
    
    dados
  }
  
  
  output$exportacoes_monetarias <- renderD3tree3({
    selecao <- fazer_selecao()
    
    agrupamento <- case_when(
      selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
      selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
    )
    
    agrupamento <- unlist(agrupamento)
    dados <- prep_treemap(agru = agrupamento)%>%filter(pais_d != "Resto do mundo")
    
    d3tree3(treemap(dados, index = agrupamento, vSize = "valor",
                    type = "index", palette = "Set1"),
            "Monetary Exports")
  })
  # 
#   
#   
   output$exportacoes_valores <- renderD3tree3({
     selecao <- fazer_selecao()
     
     agrupamento <- case_when(
       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
     )
 
     agrupamento <- unlist(agrupamento)
     dados <- prep_treemap(agru = agrupamento,el = "exportacoes_valores")%>%filter(pais_d != "Resto do mundo")
     
     d3tree3(treemap(dados,  index = agrupamento, vSize = "valor",
                     type = "index", palette = "Set1"),
             rootname = "Exports in Value Terms")
     })
 
   output$exportacoes_transferencias <- renderD3tree3({
     selecao <- fazer_selecao()
     
     agrupamento <- case_when(
       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
     )
     
     agrupamento <- unlist(agrupamento)
     dados <- prep_treemap(agru = agrupamento,el="transferencias_valores")%>%filter(pais_d != "Resto do mundo")%>%
       mutate(sinal = valor , valor = abs(valor))
     
     d3tree3(treemap(dados, index = agrupamento, vSize = "valor",vColor = "sinal",
                     type = "value", palette = "RdYlOr"),
             rootname = "Value Transfers(Unequal Exchange)")
     
 }
 )

}


