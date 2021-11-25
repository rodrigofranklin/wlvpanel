server <- function(input, output, session) {
  
  
  panel_setup_server(input, output)
  
 # RV -> Valores reativos para passar para outras funções
  RV <- NULL
  RV$bases <- reactive(
    unique(
      c(
        input$base1,
        input$base2,
        input$base3,
        input$base4
      )
    )
  )
  RV$ibases <- isolate(RV$bases())
  RV$indicator <- reactive(
    if (is.null(input$indicator)) {
      default_indicator
    } else {
      input$indicator
    }
  )

  
  ## Panel: all_data_country ----------
  ## Painel com detalhamento completo dos países.
  # Tabela de resumo, distribuição setorial e gráficos de todas as variáveis
  panel_country_server(input, output, RV)
  # panel_country_tp_server(input, output, sea_paises)
  
  panel_indicators_server(input, output, RV)
  
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
  
  output$select.country <- renderUI({
    country_list <- names(sea_paises[1,1,1,])
    names(country_list) <- language_file[country_list,input$l]
    country_list <- c("",country_list)
    names(country_list)[1] <- language_file["Search a country...",input$l]
    selectInput(
      "pais",
      label = NULL,
      choices = country_list,
    )
  })
  
  output$select.indicator <- renderUI({
    indicators_list <- names(sea_paises[1,1,,1])
    names(indicators_list) <- language_file[indicators_list,input$l]
    selectInput(
      "indicator",
      label = NULL,
      choices = indicators_list,
      selected = default_indicator
      )    
  })
  
  output$select.base <- renderUI({
    radioButtons(
      inputId = "map_base", 
      choices = RV$bases(), 
      label = NULL)
  })

  ####
  ##Reactive values to use in more than one place (titles, popups)

  #-------- Valores reativos para utilizar no leaflet
  # camada_base1 (talvez incluir novas camadas para outras bases?)
  # labels (para o hover)
  # fill_group (para selecionar os elementos a apagar (o objetivo é permitir
  # apagar os poligonos antigos após desenhar os novos))

  camada_base1 <- reactive({
    basecam <- sea_paises[input$map_base,as.character(input$ano),RV$indicator(),]
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
      RV$indicator(),
      camada_base1()$value,
      varst[varst$var == RV$indicator(),"type"]) %>%
      lapply(htmltools::HTML)
  )
  
  fill_group <- reactiveVal(0)
  
  # Atualização dos polígonos conforme os dados são alterados
  observeEvent(camada_base1(),{

    palas <- colorBin(colorRampPalette(RColorBrewer::brewer.pal(9,name = 'Reds'))(length(camada_base1()$value)), domain = camada_base1()$value)
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
                pal = palas)
  })
  
  # efeito do clique no mapa: selecionar país e mostrar painéis
  observeEvent(input$map_click, {
    click <- input$map_click
    piso3 <- coords2country(data.frame(lng = click$lng, lat = click$lat))
    if (piso3 %in% paises$Legenda) {
      updateTextInput(inputId = "wait", value = "guenta_firme")
      updateSelectInput(inputId = "pais",
                      selected = piso3)
    }
  })
  
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

  # prep_treemap <- function(bd=input$transacoes_versao,
  #                          pais = input$paistrade,
  #                          ano = input$anotrade,
  #                          agr = input$transacoes_agregacao,
  #                          el = "exportacoes_pm",
  #                          qcorte = T,
  #                          qtde = 9,
  #                          agru = agrupamento,
  #                          pod = 1) {
  #   bd <- ifelse(grepl("13",bd),13,16)
  #   p <- comerciantes_p(bd,pais,ano,el,9)
  #   dados <- get(paste0("m_io_",bd)) %>%
  #     agregado(ano, el, get(paste0("linhas_",bd))()) %>%
  #     as.data.table(keep.rownames = "paisect")%>%
  #     separate(paisect,c("pais_origen","sector_origen"),sep="\\.")%>%
  #     select(-pais_origen)%>%
  #     pivot_longer(-c(sector_origen),names_to="paisect_d",values_to="valor")%>%
  #     separate(paisect_d,c("pais_d","sect_d"),sep="\\.")%>%
  #     mutate(pais_d = ifelse(pais_d %in% p,pais_d,"ROW"))%>%
  #     dplyr::group_by(across(all_of(agru)))%>%
  #     summarize(valor=sum(valor))%>%
  #     left_join(paises, by = c("pais_d" = "Legenda"))%>%
  #     left_join(setorest,by = c("sect_d" = "Code"))%>%
  #     transmute(pais_d = `Países`,sect_d = pt, valor)%>%
  #     mutate(across(-valor,as.factor))%>% ungroup()
  #   print(head(dados))
  #   dados
  # }
  
  # dados <- reactive({
  #   paste0(input$transacoes_versao)
  # })
  # 

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
                           qtde = 9,
                           agru = agrupamento,
                           pod = 1) {
    bd <- ifelse(grepl("13",bd),13,16)
    p <- comerciantes_p(bd,pais,ano,el,9)
    dados <- get(paste0("m_io_",bd)) %>%
      agregado(ano, el, get(paste0("linhas_",bd))()) %>%
      as.data.table(keep.rownames = "paisect")%>%
      separate(paisect,c("pais_origen","sector_origen"),sep="\\.")%>%
      select(-pais_origen)%>%
      pivot_longer(-c(sector_origen),names_to="paisect_d",values_to="valor")%>%
      separate(paisect_d,c("pais_d","sect_d"),sep="\\.")%>%
      mutate(pais_d = ifelse(pais_d %in% p,pais_d,"ROW"))%>%
      dplyr::group_by(across(all_of(agru)))%>%
      summarize(valor=sum(valor,na.rm=T))%>%
      left_join(paises, by = c("pais_d" = "Legenda"))%>%
      left_join(setorest,by = c("sect_d" = "Code"))%>%
      transmute(pais_d = `Países`,sect_d = pt, valor)%>%
      mutate(across(-valor,as.factor))%>% ungroup()

    print(head(dados))
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
                    type = "index", palette = "Set1",
                    title.legend = "valor"
                    ),
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
                     type = "index", palette = "Set1",
                     title.legend = "valor"),
             rootname = "Exports in Value Terms")
     })
 
   output$exportacoes_transferencias <- renderD3tree3({
     selecao <- fazer_selecao()
     print(selecao)
     agrupamento <- case_when(
       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
     )
     
     agrupamento <- unlist(agrupamento)
     dados <- prep_treemap(agru = agrupamento,el="transferencias_valores")%>%filter(pais_d != "Resto do mundo")%>%
       mutate(sinal = round(valor) , 
              valor = abs(valor),
              posit = case_when(!(valor < 0) ~ "transfer",
                                valor<0 ~ "rec."))
     print(dados)
     d3tree3(treemap(dados, index = c("posit",agrupamento), vSize = "valor",
                     type = "index", 
                      palette = "Set1",
                     title.legend = "valor",
                     ),
             rootname = "Value Transfers(Unequal Exchange)")
     
 }
 )
  output$loading <- renderText("")
  outputOptions(output, 'loading', suspendWhenHidden=FALSE)
  

}


