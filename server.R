
server <- function(input, output, session) {
 
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
        mapResolution = "high")
    camadas <- camadas[camadas$ISO3 %in% paises$Legenda,]
    camadas
  })
  
  labels <- reactive(
    sprintf(
      "<strong>%s</strong><br/>%s : %g %s",
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
  
  # sistema para esconder os painéis
  # 0 -> esconde; 1-> mostra
  # ingnoreInit é importante para manter o valor em 0 no início do painel
  esconde <- reactiveVal(0)
  
  observeEvent(
    input$xis,
    esconde(0),
    ignoreInit = T
  )

  observeEvent(
    input$pais,
    esconde(1),
    ignoreInit = T
  )
  
  output$esconde <- reactive(
    return(esconde())
  )
  
  outputOptions(output, 'esconde', suspendWhenHidden=FALSE)
  
  # efeito do clique no mapa: selecionar país e mostrar painéis
  observeEvent(input$map_click, {
    click <- input$map_click
    piso3 <- coords2country(data.frame(lng = click$lng, lat = click$lat))
    pafil <- (paises%>%filter(Legenda ==  piso3))$Legenda
    paisvei <- input$pais
    if (piso3 %in% paises$Legenda) {
      updateSelectInput(inputId = "pais",
                      selected = pafil)
      esconde(1)
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
  
  comerciantes_p <-  function(bd=13,pais = input$pais,ano = input$ano, elemento = "exportacoes_pm",qtde = 15) {
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
  
  output$debuga <- renderText({
    #glimpse(dados())
    paste(input$pais)
  })
  
  output$pais <- renderDataTable(
    
    tabmil(t(sea_paises[,as.character(input$ano),,input$pais]))%>%
      filter(var %in% c(input$indicador,perfil_sumario))%>%
      arrange(match(var,c(input$indicador,perfil_sumario)))%>%
      left_join(varst)%>%
      select(var = pt, 2:3),
    # rownames = TRUE,
    #    spacing = "xs",
    #    striped = TRUE,
    #    hover = TRUE,
    #    width = "100%",
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
  
  output$serie_pais <- renderPlotly({
    dados <- sea_paises[,,input$indicador,input$pais]
    plotaserie(dados)
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
      scrollY= "340",
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
      scrollY= "340",
      info = FALSE,
      lengthChange = FALSE
    )
  )
  
  
  output$titulo_detalhamento_pais <-
    renderText(
      paste(varst[varst$var==input$indicador,"pt"])
    )
  
  
  output$subtitulo_detalhamento_pais <-
    renderText(
      paste(paises[paises$Legenda==input$pais,1],
            "-",
            input$ano)
    )
  
  output$titulo_serie_pais <-
    renderText(titspais())
  
  output$subtitulo_serie_pais <-
    renderText(
      subtspais())
  
  output$titulo_painel <-
    renderText(
      paste("Country Profile:",paises[paises$Legenda==input$pais,1],
            "-",
            input$ano
      )
      
    )
  
  
  output$indicadores1 <- renderDT(
    {
      dados <- t(rbind(
        paises[match(names(sea_paises[1,1,1,]),paises[,3]),1],
        sea_paises[,as.character(input$anoind),input$indicadorind,]))
      dados <- datatable(dados,
                         rownames = 1,
                         options = list(
                           ordering = FALSE,
                           searching = FALSE,
                           paging = FALSE,
                           scrollY= "100%",
                           info = FALSE,
                           lengthChange = FALSE
                         )
      ) %>%
        formatPercentage("WIOD13", 2)
      formatStyle(dados, names(dados$x$data),`line-height` = '10px')
    },
  )
  
  output$indicadores2 <- DT::renderDataTable(
    {
      dados <- t(rbind(
        paises[match(names(sea_paises[1,1,1,]),paises[,3]),1],
        sea_paises[,as.character(input$ano),input$indicador,]))[((num_paises/2)+1):num_paises,]
      dados <- datatable(dados,
                         rownames = 1,
                         options = list(
                           ordering = FALSE,
                           searching = FALSE,
                           paging = FALSE,
                           scrollY= "100%",
                           info = FALSE,
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
  
  
  ### sobre esses outputs que se seguem: é preciso melhorar. Seria possível ter
  ### uma única função que fosse chamada conforme a seleção de (exportação,
  ### importação e saldo), e chamada 3 vezes (monetária, valor e transferência)?
  # Problema: os dados de exportacoes, importacoes e saldo são distintos.
  # Mas são os mesmos dados conforme o tipo de variável (monetário, valor transf)
  # No entanto, os gráficos conforme tipo de variábel são concomitantes.

  ### Sim certamente possível
  #   output$exportacoes_monetarias <- renderD3tree3({
  #     selecao <- fazer_selecao()
  #     
  #     agrupamento <- case_when(
  #       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
  #       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
  #       )
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

#   
#   output$importacoes_monetarias <- renderD3tree3({
#     selecao <- fazer_selecao()
#     
#     agrupamento <- case_when(
#       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
#       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
#     )
#     agrupamento <- unlist(agrupamento)
#     dados <- prep_treemap(agru = agrupamento,el="importacoes_monetarias")
#     
#     d3tree3(treemap(dados, index = agrupamento, vSize = "valor",
#                     type = "index", palette = "Set1"),)
#     
# })
#   
#   output$importacoes_valores <- renderD3tree3({
#     selecao <- fazer_selecao()
#     
#     agrupamento <- case_when(
#       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
#       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
#     )
#     agrupamento <- unlist(agrupamento)
#     dados <- prep_treemap(agru = agrupamento,el="importacoes_valores")
#     
#     d3tree3(treemap(dados, title = "exportações",  index = agrupamento, vSize = "valor",
#                     type = "index", palette = "Set1"))
#     
# })
#   
#   output$saldo_monetarias <- renderD3tree3({
#     selecao <- fazer_selecao()
#     
#     agrupamento <- case_when(
#       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
#       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
#     )
#     agrupamento <- unlist(agrupamento)
#     dados <- prep_treemap(agru = agrupamento,el="saldo")
#     
#     d3tree3(treemap(dados, title = "exportações",  index = agrupamento, vSize = "valor",
#                     type = "index", palette = "Set1"))
#     
#     
#     })
#   
#   
#   output$saldo_valores <- renderD3tree3({
#     selecao <- fazer_selecao()
#     
#     agrupamento <- case_when(
#       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
#       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
#     )
#     agrupamento <- unlist(agrupamento)
#     dados <- prep_treemap(agru = agrupamento,el="saldo_valores")
#     
#     d3tree3(treemap(dados, title = "exportações",  index = agrupamento, vSize = "valor",
#                     type = "index", palette = "Set1"))
#     
#     
# })
#   
#   output$saldo_transferencias <- renderD3tree3({
#     selecao <- fazer_selecao()
#     
#     agrupamento <- case_when(
#       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
#       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
#     )
#     agrupamento <- unlist(agrupamento)
#     dados <- prep_treemap(agru = agrupamento,el="saldo_transferencias")
#     
#     d3tree3(treemap(dados, title = "exportações",  index = agrupamento, vSize = "valor",
#                     type = "index", palette = "Set1"))
#     
#     
#     })
# 
# ### Análise das transferências: tabelas sobre troca desigual e trocas nos setores
# ### improdutivos
# 
#   ## Juntar tanto as exportacoes quanto as importacoes
#   output$td_envios_recebimentos <- renderTable({
#     selecao <- fazer_selecao()
#     if (selecao == 1) {
#       temp1 <- m_paises_13[as.character(input$ano_transacoes),
#                            "transferências_produtivas.valores",
#                            input$pais_transacoes,
#                            ]
#       temp2 <-  -m_paises_13[as.character(input$ano_transacoes),
#                             "transferências_produtivas.valores",
#                             ,
#                             input$pais_transacoes]
#       names(temp1) <- paste0("X.",names(temp1))
#       names(temp2) <- paste0("M.",names(temp2))
#       c(temp1, temp2)
#     } else if (selecao == 2) {
#     } else if (selecao == 3) {
#     } else if (selecao == 4) {
#     } else if (selecao == 5) {
#     } else if (selecao == 6) {
#     }
#   }, rownames = TRUE)
# 
#   output$td_envios_recebimentos_saldo <- renderTable({
#     selecao <- fazer_selecao()
#     if (selecao == 1){
#       m_paises_13[as.character(input$ano_transacoes),
#                            "transferências_produtivas.valores",
#                            input$pais_transacoes,] -
#       m_paises_13[as.character(input$ano_transacoes),
#                           "transferências_produtivas.valores",
#                           ,input$pais_transacoes]
#     } else if (selecao == 2) {
#     } else if (selecao == 3) {
#     } else if (selecao == 4) {
#     } else if (selecao == 5) {
#     } else if (selecao == 6) {
#     }
#   }, rownames = TRUE)
# 
# 
#   output$improdutivos_envios_recebimentos <- renderTable({
#     selecao <- fazer_selecao()
#     if (selecao == 1){
#       temp1 <- m_paises_13[as.character(input$ano_transacoes),
#                            "transferencias_valores",
#                            input$pais_transacoes,] -
#         m_paises_13[as.character(input$ano_transacoes),
#                            "transferências_produtivas.valores",
#                            input$pais_transacoes,]
#       temp2 <-  -(m_paises_13[as.character(input$ano_transacoes),
#                             "transferencias_valores",
#                             ,input$pais_transacoes] -
#         m_paises_13[as.character(input$ano_transacoes),
#                     "transferências_produtivas.valores",
#                     ,input$pais_transacoes])
#       names(temp1) <- paste0("X.",names(temp1))
#       names(temp2) <- paste0("M.",names(temp2))
#       c(temp1, temp2)
#     } else if (selecao == 2) {
#     } else if (selecao == 3) {
#     } else if (selecao == 4) {
#     } else if (selecao == 5) {
#     } else if (selecao == 6) {
#     }
#   }, rownames = TRUE)
# 
# 
#   output$improdutivos_envios_recebimentos_saldo <- renderTable({
#     selecao <- fazer_selecao()
#     if (selecao == 1){
#       temp1 <- m_paises_13[as.character(input$ano_transacoes),
#                            "transferencias_valores",
#                            input$pais_transacoes,] -
#         m_paises_13[as.character(input$ano_transacoes),
#                     "transferências_produtivas.valores",
#                     input$pais_transacoes,] -
#         (m_paises_13[as.character(input$ano_transacoes),
#                               "transferencias_valores",
#                               ,input$pais_transacoes] -
#            m_paises_13[as.character(input$ano_transacoes),
#                                 "transferências_produtivas.valores",
#                                 ,input$pais_transacoes])
#     } else if (selecao == 2) {
#     } else if (selecao == 3) {
#     } else if (selecao == 4) {
#     } else if (selecao == 5) {
#     } else if (selecao == 6) {
#     }
#   }, rownames = TRUE)
# 
#   output$proporcao_td_transferencias <- renderText({
#     as.character(sum(m_paises_13[as.character(input$ano_transacoes),
#                                  "transferências_produtivas.valores",
#                                  input$pais_transacoes,] +
#                        m_paises_13[as.character(input$ano_transacoes),
#                                    "transferências_produtivas.valores",
#                                    ,input$pais_transacoes])/
#                    sum(m_paises_13[as.character(input$ano_transacoes),
#                                    "transferencias_valores",
#                                    input$pais_transacoes,] +
#                          m_paises_13[as.character(input$ano_transacoes),
#                                      "transferencias_valores",
#                                      ,input$pais_transacoes]))
#   })
#   textOutput("proporcao_td_transferencias_saldo")

}


