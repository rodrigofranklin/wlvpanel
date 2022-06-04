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
  
  RV$anomax <- reactive({
    if (length(RV$bases())==1) {
      margen <- 1
    } else {
      margen <- 2
    }
    temp_data <- sea_paises[RV$bases(),,,] %>% apply(margen, sum, na.rm = TRUE)
    max(as.numeric(names(temp_data[temp_data!=0])))
  })
  
  RV$anomin <- reactive({
    if (length(RV$bases())==1) {
      margen <- 1
    } else {
      margen <- 2
    }
    temp_data <- apply(sea_paises[RV$bases(),,,],margen,sum, na.rm = TRUE)
    min(as.numeric(names(temp_data[temp_data!=0])))
  })
  

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
        minZoom = 2
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
      choices = country_list
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

  output$select.year <- renderUI({
    sliderInput(
      "ano",
      label = NULL,
      min = RV$anomin(), 
      max = RV$anomax(), 
      value = 2009, 
      ticks = F, 
      animate = F, 
      sep = "")
    })

  output$select.countrytrade <- renderUI({
    country_list <- unique(substr(names(m_io_16[1,1,1,]),1,3))
    names(country_list) <- language_file[country_list,input$l]
    country_list <- c("",country_list)
    names(country_list)[1] <- language_file["Search a country...",input$l]
    selectInput(
      "paistrade",
      label = NULL,
      choices = country_list,
      selected = "MEX"
    )
  })
  
  output$select.basetrade <- renderUI({
    radioButtons(
      inputId = "transacoes_versao", 
      choices = RV$bases()[1:2],
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
  
  labels <- reactive({
    
    sprintf(
      "<p style='
      text-align: center;
      border-style: none none solid;
      border-width: 1px;
      font-weight: bold'>
      %s</p>%s : %g %s",
      camada_base1()$ADMIN,
      lb(RV$indicator(),input$l),
      camada_base1()$value,
      varst[varst$var == RV$indicator(),"type"]) %>%
      lapply(htmltools::HTML)
  })
  
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

  lista_agr <- reactive({
    req(input$l)
    a <- language_file[grepl("trade_agg",rownames(language_file)),input$l]
    b <- rownames(language_file[grepl("trade_agg",rownames(language_file)),])
    lala <- b
    names(lala) <- a
    lala
    })
    
  observeEvent(lista_agr(), {
    updateRadioButtons(session, inputId = "transacoes_agregacao", 
                      choices = lista_agr())
  })
  linhas_13 <- reactive({
    encontrar_pais(m_io_13, input$paistrade, rownames)
  })
  
  colunas_13 <- reactive({
    encontrar_pais(m_io_13, input$pais_transacoes, colnames)
  })
  
  linhas_16 <- reactive({
    encontrar_pais(m_io_16, input$paistrade, rownames)
  })
  
  colunas_16 <- reactive({
    encontrar_pais(m_io_16, input$trade, colnames)
  })
  

  
  comerciantes_p <-  function(bd=13,
                              pais = input$paistrade,
                              ano = input$anotrade, 
                              elem = "exportacoes_pm",
                              qtde = 15) {
      bd <- ifelse(grepl("13",bd),13,16)
      
      mat <- get(paste0("m_paises_",bd))
      mat <- mat[as.character(ano),elem,match(pais,dimnames(mat)[[3]]),]
      mat <- sapply(mat,abs)
   
      paises <- names(sort(mat,T)[2:(qtde+1)])
      rm(mat)
      paises
     
    }

  

  fazer_selecao <- reactive({
    switch(paste0(input$transacoes_versao,input$transacoes_agregacao),
           "WIOD13trade_aggregation_country" = 1,
           "WIOD13trade_aggregation_sector" = 2,
           "WIOD16trade_aggregation_country" = 3,
           "WIOD16trade_aggregation_sector" = 4
    )
  })


  dados <- reactive({
    paste0(input$transacoes_versao)
  })
  
  output$debuga <- renderText({
    #glimpse(dados())
    paste(input$pais)
  })
  
  output$listapais <- renderDataTable( {
    
    tabmil(t(sea_paises[,as.character(input$ano),,input$pais]))%>%
      filter(var %in% c(input$indicador,perfil_sumario))%>%
      arrange(match(var,c(input$indicador,perfil_sumario)))%>%
      left_join(varst)%>%
      select(var = pt, 2:3)
    },
    # rownames = TRUE,
    #    spacing = "xs",
    #    striped = TRUE,
    #    hover = TRUE,
    #    width = "100%",
    server = F,
    options = list(
    ordering = FALSE,
    searching = FALSE,
    paging = FALSE,
      #      scrollY = "200",
      # pageLength = 10,
    info = FALSE,
    lengthChange = FALSE
    )
  )%>%bindCache(input$ano, input$pais,input$indicador)

  
  output$serie_pais <- renderPlotly({
    dados <- sea_paises[,,input$indicador,input$pais]
    plotaserie(dados)
  })%>% bindCache(input$indicador,input$pais)

  
  
  output$setores_pais_13 <- renderDataTable(
    tabmil(sea_setores_13[as.character(input$ano),
                          input$indicador,,
                          input$pais])%>%
      left_join(setorest,by=c("var" = "Code"))%>%
      select(sector=pt,value=x),
    server = F,
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
    renderText({
      paste("Country Profile:",paises[paises$Legenda==input$pais,1],
            "-",
            input$ano)
      }
      )
      
  output$indicadores <- renderDT({
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
                ))
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
                           elem = "exportacoes_pm",
                           qcorte = T,
                           qtde = 15,
                           agru = agrupamento,
                           pod = 1) {
    
    sctc <- dimnames(sea_sectors[[bd]])[[3]]
    bd <- ifelse(grepl("13",bd),13,16)
    p <- comerciantes_p(bd,pais,ano,elem,qtde)
    
    
    sctnames <- sapply(sctc,function(i) {abrevia(language_file[paste0("SEC.CODE.",i),input$l])})
    sct <- data.frame(Code=sctc,nsect=sctnames)
#    sct$nset <- sapply(sct$nset,abrevia)
    paisl <- data.frame(nome_pais = language_file[lista_paises,input$l], 
                        Legenda = lista_paises) 
    dados <- get(paste0("m_io_",bd))%>%
      agregado(ano, elem, get(paste0("linhas_",bd))())%>%
      as.data.table(keep.rownames = "paisect") %>%
      filter(substr(paisect,1,3) == pais)%>%
      separate(paisect,c("pais_origen","sector_origen"),sep="\\.")

    dados <- dados%>%
      select(-pais_origen)%>%
      pivot_longer(-c(sector_origen),names_to="paisect_d",values_to="valor")%>%
      separate(paisect_d,c("pais_d","sect_d"),sep="\\.")%>%
      mutate(pais_d = ifelse(pais_d %in% p,pais_d,"ROW")) %>%
      dplyr::group_by_at(agru) %>%
       summarize(valor=sum(valor,na.rm=T))
    
    dados <- dados%>%filter(pais_d != "ROW")
    dados <- dados %>%
      left_join(paisl, by = c("pais_d" = "Legenda"))%>%
      left_join(sct,by = c("sect_d" = "Code"))

    print(unique(dados$sect_d[is.na(dados$nsect)]))
    
    dados <- dados%>%
      transmute(pais_d = nome_pais,sect_d = nsect, valor,
                ettm = paste(sect_d,milhares(round(valor)),sep=" "))%>%
      mutate(across(-valor,as.factor))%>%
      ungroup()
    

    dados <- dados[!(is.na(dados$sect_d)),]
    
    dados
  }
  
  
  output$exportacoes_monetarias <- renderD3tree3({
    selecao <- fazer_selecao()
    ele <- "exportacoes_pm" 
    agrupamento <- case_when(
      selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
      selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
    )

    agrupamento <- unlist(agrupamento)
    
    dados <- prep_treemap(agru = agrupamento)

    dados <- dados[dados$pais_d != "Resto do mundo",]

    
    sumpaisd <- dados%>%group_by(pais_d)%>%summarize(paisds = round(sum(valor)))

    dados <- dados %>% left_join(sumpaisd) %>%mutate(pais_d = paste(pais_d,milhares(paisds),sep = " "),
                                                     sect_d = ettm)
    
    d3tree3(treemap(dados, index = agrupamento, vSize = "valor",
                    type = "index", palette = "Set1",
                    fontsize.labels = c(16,12,8),
                    fontsize.legend = 12,
                    overlap.labels = 0.1,
                    lowerbound.cex.labels = 1,
                    inflate.labels = T,
                    align.labels = c("center","center"),
                    force.print.labels = F),
            rootname = "Monetary Exports")
  })%>% bindCache("exportacoes_pm",input$l,input$paistrade,input$anotrade,
                  input$transacoes_versao,input$transacoes_agregacao)

   
  output$exportacoes_valores <- renderD3tree3({
    selecao <- fazer_selecao()
    ele <- "exportacoes_valores"
    agrupamento <- case_when(
      selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
      selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
    )
    
    agrupamento <- unlist(agrupamento)
    dados <- prep_treemap(agru = agrupamento,
                          elem = ele)
    dados <- dados[dados$pais_d != "Resto do mundo",]

    sumpaisd <- dados%>%group_by(pais_d)%>%summarize(paisds = round(sum(valor)))
    
    dados <- dados %>% left_join(sumpaisd) %>%mutate(pais_d = paste(pais_d,milhares(paisds),sep = " "),
                                                     sect_d = ettm)
    
    d3tree3(treemap(dados, index = agrupamento, vSize = "valor",
                    type = "index", palette = "Set1",
                    fontsize.labels = c(16,12,8),
                    fontsize.legend = 12,
                    lowerbound.cex.labels = 1,
                    inflate.labels = F,
                    align.labels = c("center","center"),
                    force.print.labels = F
    ),
    rootname = "Exports in Value Terms")
  }) %>% bindCache("exportacoes_valores",input$l,input$paistrade,input$anotrade,
                  input$transacoes_versao,input$transacoes_agregacao)
 
   output$exportacoes_transferencias <- renderD3tree3({
     selecao <- fazer_selecao()
     ele <- "transferencias_valores"
     agrupamento <- case_when(
       selecao %% 2 == 1 ~  list(c("pais_d","sect_d")),
       selecao %% 2 == 0 ~ list(c("sector_origen","pais_d","sect_d"))
     )
     
     agrupamento <- unlist(agrupamento)
    
     dados <- prep_treemap(agru = agrupamento,
                           elem = ele)
    
     dados <- dados[dados$pais_d != "Resto do mundo",] %>%
       mutate(sinal = !(valor <0),
              sinal = ifelse(sinal == 0,-1,sinal),
              posit = case_when(sinal == -1 ~ "losses",
                                sinal == 1 ~ "wins/gains"),
              valor = abs(valor))
   
     sumposit <- dados%>%group_by(posit)%>%summarize(posits = round(sum(valor)))
     sumpaisd <- dados%>%group_by(posit,pais_d)%>%summarize(paisds = round(sum(valor)))
     
     dados <- dados %>% left_join(sumpaisd) %>%mutate(pais_d = paste(pais_d,milhares(paisds),sep = " "))
     
     dados <- dados %>% left_join(sumposit) %>%mutate(posit = paste(posit,milhares(posits),sep = " "))
     

     dados <- treemap(dados, index = c("posit","pais_d","ettm"), 
                      vSize = "valor",
                      align.labels = c("center","center"),
                      algorithm = "pivotSize",
                      type = "index", 
                      palette = "Set1",
                      title = "Transferred Values",
                      fontsize.labels = 10,
                      inflate.labels = F,
                      overlap.labels = 0,
                      force.print.labels = F)
     
     
     d3tree3(dados, rootname = "Value Transfers")
     }) %>% 
     bindCache("transferencias_valores",input$l, input$paistrade,input$anotrade,
                 input$transacoes_versao,input$transacoes_agregacao)

  output$loading <- renderText("")
  outputOptions(output, 'loading', suspendWhenHidden=FALSE)
  
  
  
  idl <- idpaistrade <- idele <- idanotrade <- idtver <- 1


  observe({ 
    req(input$fill) 
    if (idpaistrade != (unique(substr(names(m_io_16[1,1,1,]),1,3))-1)|| idanotrade != length(lista_anos) || 
        idtver != length(lista_versoes)||idele != length(lista_versoes) || idl != nrow(languages)) { 
      ## need the invalidateLater approach 
      ## to allow shiny reacting on the change 
      ## not sure whether we cannot trip over race conditions 
      ## recommendation: do it once by hand (it's persistent anyways ;) 
      invalidateLater(30000, session) 
      if (idpaistrade == (length(unique(substr(names(m_io_16[1,1,1,]),1,3)))-1)) {
        if(idanotrade == length(lista_anos)) {
          if(idele == length(lista_agr)) {
            if(idl == nrow(languages)){
              message("Atualizando versao do bd:", idtver) 
              idpaistrade<<- 1
              idanotrade <<- 1
              idele <<- 1
              idl <<- 1
              idtver <<- idtver + 1 
              updateRadioButtons(session, "transacoes_versao", selected = lista_versoes[[idtver]])
          } else {
            message("Atualizando idioma:", idl) 
            idpaistrade<<- 1
            idanotrade <<- 1
            idele <<- 1
            idl <<- idl + 1 
            updateSelectInput(session,"l",languages[idl,1])
            }} else { message("Atualizando agregação: ", idele) 
          idpaistrade<<- 1
          idanotrade <<- 1
          idele <<- idele + 1 
          updateRadioButtons(session, "transacoes_agregacao", selected = lista_agr[[idele]])
        }}  else {
        message("Atualizando anotrade:", idanotrade) 
        idpaistrade <<- 1 
        idanotrade <<- idanotrade + 1 
        updateSliderInput(session, "anotrade", value = lista_anos[[idanotrade]])
        }} else { 
          message("atualizando pais",idpaistrade) 
          updateSelectInput(session, "paistrade", selected = lista_paises[[idpaistrade+1]]) 
          idpaistrade <<- idpaistrade + 1 } 
        } 
      
    })

  ##Completar auto cache de painel país
  ##Caches em função de:
  #RV$bases(),input$ano,input$pais,input$l
  #(i,input$ano,RV$indicator(),input$pais,input$l)
  #i,input$pais,RV$bases())
  
  idll <- idi <- idpais_det <- idpais_ind <- idano_det <- idpais_bases <- 1
  idano_det <- 1
  #idl <- idpaistrade <- idele <- idanotrade <- idtver <- 1
  
  observe({ 
    req(input$fillpais) 
    if (idpais_det != (length(lista_paises)-1)|| idano_det != length(lista_anos) || 
        idpais_bases != length(RV$bases()) ||idpais_ind != nrow(varst$var) || idll != nrow(languages)) { 
      ## need the invalidateLater approach 
      ## to allow shiny reacting on the change 
      ## not sure whether we cannot trip over race conditions 
      ## recommendation: do it once by hand (it's persistent anyways ;) 
      invalidateLater(10000, session) 
      if (idpais_det == (length(lista_paises)-1)) {
        if(idano_det == length(lista_anos)) {
          if(idpais_ind == length(nrow(varst$var))) {
            if(idll == nrow(languages)){
              message("A implementar atualizar bases escolhidas:", idpais_bases) 
              ### IDEIA - fazer outer das distintas combinações de 4 dentro do total
              # idpais_det<<- 1
              # idano_det <<- 1
              # idpais_ind <<- 1
              # idll <<- 1
              # idpais_bases <<- idpais_bases + 1 
              # RV$bases(RV$bases)
            } else {
              message("Atualizando idioma:", idll) 
              idpais_det<<- 1
              idano_det <<- 1
              idpais_ind <<- 1
              idll <<- idll + 1 
              updateSelectInput(session,"l",languages[idll,1])
            }} else { message("Atualizando indicador a detalhar setorialmente: ", idpais_ind) 
              idpais_det<<- 1
              idano_det <<- 1
              idpais_ind <<- idpais_ind + 1 
              #updateRadioButtons(session, "transacoes_agregacao", selected = lista_agr[[idpais_ind]])
              RV$indicator(varst$var[idpais_ind])
            }}  else {
              message("Atualizando ano_det:", idano_det) 
              idpais_det <<- 1 
              idano_det <<- idano_det + 1 
              updateSliderInput(session, "ano_detalhado", value = lista_anos[[idano_det]])
            }} else { 
              message("atualizando pais",idpais_det) 
              updateSelectInput(session, "pais_detalhado", selected = lista_paises[[idpais_det+1]]) 
              idpais_det <<- idpais_det + 1 } 
    } 
    
  })
  
}



