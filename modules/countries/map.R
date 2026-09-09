### Module: Countries
# Description: plot indicator on map and shows detailed info of a country
# map.R: map interaction


### Global ####

# Mapa-base vetorial local, independente de chaves e serviços de tiles.
# Proveniência e regeneração: tests/manual/MAP-UPDATES.md.
wlv_land_geojson <- paste(readLines(
  "www/wlv-land-110m.geojson", warn = FALSE, encoding = "UTF-8"
), collapse = "")

# Create colour pallet from data
mypallet <- function(data, indicator) {
  # If data has positive and negative values, pallet is divergent and centred in 0
  data[!is.finite(data)] <- NA_real_
  if (!any(is.finite(data))) {
    return(function(value) rep("transparent", length(value)))
  }
  
  qtt <- data |> length()
  
  if (meta_indicators$reverted[meta_indicators$value==indicator]) {
    negative <- colorRampPalette(colors = c("#0000FF", "#C8C8FF"))(qtt)
    positive <- colorRampPalette(colors = c("#FFC8C8", "#FF0000"))(qtt)
  } else {
    negative <- colorRampPalette(colors = c("#FF0000", "#FFC8C8"))(qtt)
    positive <- colorRampPalette(colors = c("#C8C8FF", "#0000FF"))(qtt)
  }
  onlypositive <- colorRampPalette(colors = c("#FFC8C8", "#FF0000"))(qtt)
  
  
  suppressWarnings({
    maximum <- max(data, na.rm = TRUE) *1.1
    minimum <- min(data, na.rm = TRUE) *1.1
  })
  if (is.finite(minimum) && is.finite(maximum) &&
      minimum == 0 && maximum == 0) {
    minimum <- -1e-12
    maximum <- 1e-12
  }
  
  if (minimum < 0 & maximum >0) {
    if (maximum > abs(minimum)) {
      dominium <- c(-maximum,maximum)
    } else {
      dominium <- c(minimum,-minimum)
    }
    colours <- c(negative, positive)
  } else if (maximum < 0) {
    dominium <- c(minimum,0)
    colours <- negative
  } else {
    dominium <- c(0,maximum)
    colours <- onlypositive
  }
  
  if (maximum |> is.infinite()) {
    function (i) "transparent"
  } else {
    colorNumeric(
      colours,
      domain = dominium, 
      na.color="transparent")
  }
}

# Format labels numbers for legend
label_f2s <- function(ind, method, lng) {
  function(type, cuts, ...) {
    list_display_f2s(cuts, ind, method, lng)
  }
}

# O tooltip mostra a unidade em uma coluna própria, preservando os mesmos
# arredondamentos e sufixos de magnitude usados nas demais visualizações.
map_tooltip_values <- function(values, indicator, method, lng) {
  formatted <- list_display_f2s(values, indicator, method, lng) |>
    unlist(use.names = FALSE) |>
    as.character()
  type <- wlv_display_format_type(meta_indicator_contracts, method, indicator)
  suffix <- switch(type, percent = "%", value = "mv", hours = lb("hours", lng), "")
  if (nzchar(suffix)) {
    matched <- !is.na(formatted) & endsWith(formatted, suffix)
    formatted[matched] <- substr(formatted[matched], 1L,
      nchar(formatted[matched]) - nchar(suffix))
  }
  if (identical(type, "usd")) {
    matched <- !is.na(formatted) & startsWith(formatted, "US$ ")
    formatted[matched] <- substring(formatted[matched], 5L)
  }
  formatted[!is.finite(values)] <- wlv_tr("Sem dados", "No data", lng)
  formatted
}

# A ajuda consulta o código clicado, sem alterar o indicador exibido no mapa.
# Unidades vêm dos mesmos contratos de apresentação usados nos dados e tooltips.
map_indicator_info <- function(indicator, methods, lng,
    dictionary = language_file, contracts = meta_indicator_contracts) {
  methods <- unique(methods)
  stopifnot(length(methods) > 0L)
  optional_label <- function(key) {
    value <- wlv_label(key, lng, dictionary)
    if (!length(value) || is.na(value) || !nzchar(trimws(value)) ||
        identical(value, key)) "" else value
  }
  by_method <- function(values, missing) {
    values[!nzchar(values)] <- missing
    if (length(unique(values)) == 1L) return(unname(values[[1L]]))
    paste(paste(methods, values, sep = ": "), collapse = "\n")
  }
  units <- vapply(methods, function(method) {
    wlv_unit_label(wlv_display_unit(contracts, method, indicator), lng)
  }, character(1))
  missing_notes <- wlv_tr("Não informadas", "Not provided", lng)
  general_notes <- optional_label(paste0("obs.", indicator))
  method_notes <- vapply(paste0("obs.", methods, ".", indicator),
    optional_label, character(1), USE.NAMES = FALSE)
  notes <- c(general_notes, if (any(nzchar(method_notes))) {
    by_method(method_notes, missing_notes)
  })
  notes <- unique(notes[nzchar(notes)])
  description <- optional_label(paste0("desc.", indicator))
  list(
    variable = wlv_label(indicator, lng, dictionary),
    unit = by_method(units, wlv_tr("Não informada", "Not provided", lng)),
    description = if (nzchar(description)) description else
      wlv_tr("Não informada", "Not provided", lng),
    observations = if (length(notes)) paste(notes, collapse = "\n") else missing_notes
  )
}

### UI ####

# Controles únicos: o CSS os apresenta como painéis flutuantes no mobile.
map_sheet_button <- function(sheet, label, symbol) {
  tags$button(type = "button", class = "wlv-map-tool",
    "data-map-sheet" = sheet, "aria-controls" = paste0("map-", sheet, "-panel"),
    "aria-expanded" = "false", icon(symbol), l(label))
}
map_ui <- div(class = "wlv-map-canvas",
  # Capturar os recursos junto com a UI impede que um processo R em uso
  # combine seu HTML anterior com arquivos www de uma versão mais recente.
  includeCSS("www/wlv-map-controls.css"),
  includeScript("www/wlv-map.js"),
  includeScript("www/wlv-map-controls.js"),
  tags$button(type = "button", class = "wlv-map-indicator-toggle",
    "data-map-sheet" = "indicators", "aria-controls" = "inputs_panel",
    "aria-expanded" = "false", tags$span(id = "map-current-indicator", l("map.indicator")), icon("chevron-down")),
  leafletOutput("map", width = "100%", height = "100%"),
  div(class = "wlv-map-float wlv-map-filter-panel",
    div(id = "map-base-panel", class = "wlv-map-base",
      selectInput("co_map_method", l("map.base"), choices = init_bases, selectize = FALSE)),
    div(id = "map-year-panel", class = "wlv-map-year",
      sliderInput("co_select_year", label = l("map.year"), min = 1995,
        max = 2007, value = default_year, ticks = FALSE, sep = "",
        animate = animationOptions(interval = 500, loop = FALSE)))),
  tags$p(class = "wlv-map-status", role = "status", textOutput("map_status")),
  div(class = "wlv-map-bottom-bar",
    map_sheet_button("legend", "map.legend", "list"),
    map_sheet_button("year", "map.year", "calendar"),
    map_sheet_button("base", "map.base", "layer-group"),
    tags$button(type = "button", class = "wlv-map-tool", id = "map-world-button",
      icon("globe"), l("map.world")))
)
panel_of_inputs <- tags$aside(id = "inputs_panel", class = "wlv-map-controls",
  "aria-label" = lb("map.indicators", default_language),
  div(style = "display:none", "aria-hidden" = "true",
    selectizeInput("co_select_indicator", NULL, choices = NULL,
      selected = default_indicator)),
  uiOutput("map_indicator_list"),
  tags$button(type = "button", class = "wlv-map-indicators-close", "data-map-close" = "true",
    icon("xmark", class = "wlv-map-close-icon"), l("app.close"))
)

### Server ####
map_server <- function(IP, OP, RV, SESSION) {
  control_availability <- reactive({
    methods <- RV$bases()
    indicators <- unique(method_indicator_availability$indicator[
      method_indicator_availability$method %in% methods])
    req(length(indicators))
    indicators
  })
  observe({
    available <- control_availability()
    indicator <- isolate(IP$co_select_indicator)
    if (!length(indicator) || !indicator %in% available) {
      indicator <- if (default_indicator %in% available) default_indicator else available[[1L]]
    }
    choices <- stats::setNames(available, lb(available, IP$l))
    updateSelectizeInput(SESSION, "co_select_indicator", choices = choices,
      selected = indicator, server = FALSE)
  })
  OP$map_indicator_list <- renderUI({
    rows <- meta_indicators[meta_indicators$value %in% control_availability(), ]
    selected <- isolate(IP$co_select_indicator)
    tags$ul(class = "wlv-map-indicator-list", lapply(unique(rows$groups), function(group) {
      codes <- rows$value[rows$groups == group]
      expanded <- any(codes %in% selected)
      body_id <- paste0("map-indicator-group-", match(group, unique(rows$groups)))
      tags$li(class = "wlv-map-indicator-group",
        tags$button(type = "button", class = "wlv-map-group-header",
          "aria-expanded" = if (expanded) "true" else "false", "aria-controls" = body_id,
          tags$span(lb(paste0("group.", group), IP$l)),
          tags$span(class = "wlv-map-group-arrow", icon("chevron-right"))),
        tags$ul(id = body_id, class = "wlv-map-group-body",
          "data-expanded" = if (expanded) "true" else "false",
          lapply(codes, function(code) {
            label_id <- paste0("map-indicator-label-", code)
            tags$li(class = "wlv-map-indicator-row", "data-indicator-code" = code,
              tags$button(type = "button", class = "wlv-map-indicator-option",
                "data-indicator" = code, "aria-labelledby" = label_id,
                "aria-pressed" = if (identical(code, selected)) "true" else "false",
                tags$svg(class = "wlv-map-indicator-svg", xmlns = "http://www.w3.org/2000/svg",
                  viewBox = "0 0 17 17", "aria-hidden" = "true",
                  tags$circle(cx = "8.5", cy = "8.5", r = "8", fill = "var(--wlv-ink)",
                    stroke = "#fff", "stroke-width" = "1"),
                  tags$circle(cx = "8.5", cy = "8.5", r = "4", class = "inner-circle", fill = "#fff"))),
              div(class = "wlv-map-indicator-text",
                tags$span(id = label_id, class = "wlv-map-indicator-label", lb(code, IP$l)),
                HTML("&nbsp;"),
                tags$button(type = "button", class = "wlv-map-indicator-help",
                  "data-indicator-info" = code,
                  "aria-label" = paste(wlv_tr("Sobre", "About", IP$l), lb(code, IP$l)),
                  icon("question-circle"))))
          })))
    }))
  })
  outputOptions(OP, "map_indicator_list", suspendWhenHidden = FALSE)
  observeEvent(IP$map_show_indicator_info, {
    code <- IP$map_show_indicator_info
    req(length(code) == 1L, code %in% control_availability())
    methods <- wlv_methods_with_indicator(method_indicator_availability, RV$bases(), code)
    info <- map_indicator_info(code, methods, IP$l)
    fields <- wlv_tr(c("Variável", "Unidade", "Descrição", "Observações"),
      c("Variable", "Unit", "Description", "Notes"), IP$l)
    showModal(modalDialog(title = lb(code, IP$l),
      div(class = "wlv-map-indicator-info", lapply(seq_along(info), function(i) {
        tags$p(class = paste0("wlv-map-indicator-", names(info)[[i]]),
          tags$span(class = "wlv-map-info-label", paste0(fields[[i]], ": ")),
          tags$span(class = "wlv-map-info-value", info[[i]]))
      })),
      easyClose = TRUE, footer = modalButton(lb("app.close", IP$l))))
  })
  indicator_methods <- reactive({
    req(IP$co_select_indicator)
    wlv_methods_with_indicator(method_indicator_availability, RV$bases(), IP$co_select_indicator)
  })
  active_method <- reactive({
    methods <- indicator_methods()
    req(length(methods))
    selected <- intersect(IP$co_map_method, methods)
    if (length(selected)) selected[[1L]] else methods[[1L]]
  })
  observe({
    updateSelectInput(SESSION, "co_map_method", label = lb("map.base", IP$l),
      choices = indicator_methods(), selected = active_method())
  })
  available_years <- reactive({
    data <- sea_countries[active_method(), , IP$co_select_indicator, , drop = FALSE]
    years <- as.numeric(dimnames(data)[[2L]])
    years <- years[apply(data, 2L, function(x) any(is.finite(x)))]
    req(length(years))
    sort(years)
  })
  selected_year <- reactive({
    years <- available_years()
    year <- IP$co_select_year
    if (!length(year) || !is.finite(year)) year <- default_year
    years[[which.min(abs(years - year))]]
  })
  observe({
    years <- available_years()
    # Enviar limites, não devolver uma captura antiga do ano. O navegador
    # conserva sua seleção mais recente e a ajusta à cobertura recebida.
    SESSION$sendCustomMessage("wlv-map-years", list(
      years = years, label = lb("map.year", IP$l), method = active_method(),
      indicator = IP$co_select_indicator))
  })

  ## Base map ####
  OP$map <- renderLeaflet({
    leaflet(
      options = leafletOptions(
        # O binding R normaliza `crs` para sua lista interna. mapFactory aplica
        # o CRS próprio antes de criar este mapa, sem alterar o de Indicadores.
        mapFactory = htmlwidgets::JS("function(el, options) {
          options.crs = window.WLVEqualEarth.install(L);
          return L.map(el, options);
        }"),
        zoomControl = TRUE,
        boxZoom = TRUE,
        doubleClickZoom = FALSE,
        zoomSnap = 0,
        zoomDelta = 0.25,
        maxZoom = 10,
        minZoom = -2,
        preferCanvas = TRUE,
        worldCopyJump = FALSE,
        trackResize = FALSE
      )) |>
      addMapPane("base", zIndex = 5) |>
      addMapPane("polygons", zIndex = 10) |>
      addGeoJSON(
        wlv_land_geojson,
        layerId = "wlv-world-land",
        color = "#CDD5D6", weight = 0.6,
        fillColor = "#F7F3ED", fillOpacity = 1,
        options = pathOptions(pane = "base", interactive = FALSE)
      ) |>
      # O cliente aguarda as geometrias e enquadra seus vértices projetados.
      # Cantos geográficos não descrevem a extensão real em Equal Earth.
      setView(lng = 0, lat = 0, zoom = 0) |>
      htmlwidgets::onRender("function(el, x) {
        this.attributionControl.addAttribution(
          '<a href=\"https://www.naturalearthdata.com/\" target=\"_blank\" rel=\"noopener\">Natural Earth</a> / rworldmap · Equal Earth'
        );
        window.WLVMap.attach(el, this);
      }")
    
    
  })
  outputOptions(OP, "map", suspendWhenHidden = FALSE) 

  ## Change data ####
  # Select data for each layer considering:
  # 1) methods selected in setup
  # 2) indicator
  # 3) year
  map_data <- reactive({
    methods <- indicator_methods()
    indicator <- IP$co_select_indicator
    year <- selected_year()
    
    req(length(methods))
    req(indicator)
    req(year)
    
    temp_all_data <- lapply(methods, function(i){
      # As coordenadas ficam fora do caminho reativo de ano/indicador/idioma.
      temp_data <- countries_sp[[i]]@data
      canonical_values <- sea_countries[
        i,
        year |> as.character(),
        indicator,
        temp_data$ISO3 |> as.character()
      ]
      temp_data$data <- wlv_display_values(
        canonical_values,
        i,
        indicator,
        meta_indicator_contracts
      )
      temp_data
    })
    names(temp_all_data) <- methods
    temp_all_data
  })
  
  ## Change colour pallets ####
  # Creates colour pallets for each layer considering:
  # 1) methods selected in setup
  # 2) map_data
  pallet <- reactive({
    indicator <- IP$co_select_indicator
    map_data <- map_data()
    methods <- names(map_data)
    
    temp_all_pallet <- lapply(methods, function(i){
      temp_pallet <- mypallet(map_data[[i]]$data, indicator)
      temp_pallet
    })
    names(temp_all_pallet) <- methods
    temp_all_pallet
  })
  
  ## Labels for mouse hover ####
  OP$map_status <- renderText({
    data <- map_data()
    method <- active_method()
    if (any(is.finite(data[[method]]$data))) return("")
    paste0(method, " · ", selected_year(), ": ",
      wlv_tr("sem observações. Escolha outra base ou ano.",
        "no observations. Choose another source or year.", IP$l))
  })
  outputOptions(OP, "map_status", suspendWhenHidden = FALSE)

  labels <- reactive({
    map_data <- map_data()
    methods <- names(map_data)
    lng <- IP$l
    indicator <- IP$co_select_indicator

    method_labels <- lapply(methods, function(method) {
      method_data <- map_data[[method]]
      unit <- wlv_unit_label(
        wlv_display_unit(meta_indicator_contracts, method, indicator), lng
      )

      sprintf(
        "<div><div class='tooltip-city'>%s</div>
          <div class='tooltip-content'>
            <span class='tooltip-label'>%s:</span>
            <span class='tooltip-value'>%s</span>
            <span class='tooltip-unit'>%s</span>
          </div></div>",
        htmltools::htmlEscape(lb(paste0("ISO3.", method_data$ISO3), lng)),
        htmltools::htmlEscape(lb(indicator, lng)),
        htmltools::htmlEscape(map_tooltip_values(method_data$data, indicator, method, lng)),
        htmltools::htmlEscape(unit)
      ) |>
        lapply(htmltools::HTML)
    })
    names(method_labels) <- methods
    method_labels
  })
  
  ## Geometria persistente e atualização incremental ####
  # Cada base é transmitida na primeira utilização. Ao mudar os filtros,
  # somente cores e textos atravessam a conexão, como no mapa do e-mar.
  loaded_methods <- character()
  shown_method <- NULL
  map_instance <- NULL
  observe({
    ready <- IP$map_wlv_ready
    req(ready)
    map_data <- map_data()
    methods <- names(map_data)
    pallet <- pallet()
    labels <- labels()
    # Um novo widget (por exemplo, após reconexão) precisa receber a geometria.
    if (!identical(map_instance, ready)) {
      loaded_methods <<- character()
      shown_method <<- NULL
      map_instance <<- ready
    }
    proxy <- leafletProxy("map", session = SESSION, deferUntilFlush = FALSE)
    loaded_before <- loaded_methods
    for (method in setdiff(methods, loaded_methods)) {
      layer_data <- countries_sp[[method]]
      proxy |> addPolygons(
        data = layer_data,
        layerId = layer_data@data$layerId,
        fillColor = "transparent",
        fillOpacity = 0.6,
        group = method,
        color = "black",
        weight = 0.5,
        options = pathOptions(pane = "polygons"),
        highlightOptions = highlightOptions(
          color = "red", fillOpacity = 0.7, bringToFront = TRUE
        )
      )
    }
    loaded_methods <<- union(loaded_methods, methods)

    selected <- active_method()
    if (!identical(shown_method, selected) || length(setdiff(methods, loaded_before))) {
      for (method in setdiff(loaded_methods, selected)) proxy |> hideGroup(method)
      proxy |> showGroup(selected)
      shown_method <<- selected
    }

    updates <- unlist(lapply(methods, function(method) {
      layer_data <- map_data[[method]]
      colors <- pallet[[method]](layer_data$data)
      lapply(seq_len(nrow(layer_data)), function(i) list(
        id = as.character(layer_data$layerId[[i]]),
        color = colors[[i]],
        label = as.character(labels[[method]][[i]])
      ))
    }), recursive = FALSE, use.names = FALSE)
    SESSION$sendCustomMessage("wlv-map-update", list(id = "map", layers = updates))
  })
  
  ## Legend control ####
  # Change legend with layer
  observe({
    method <- active_method()
    map_data <- map_data()
    methods <- names(map_data)
    pallet <- pallet()
    indicator <- IP$co_select_indicator
    lng <- IP$l

    req(IP$map_wlv_ready)
    req(map_data)
    req(indicator)

    method <- intersect(method, methods)
    method <- if (length(method)) method[[1L]] else methods[[1L]]
    proxy <- leafletProxy("map", session = SESSION)
    proxy |> removeControl("wlv-legend")
    if (any(is.finite(map_data[[method]]$data))) {
      unit <- wlv_unit_label(
        wlv_display_unit(meta_indicator_contracts, method, indicator), lng
      )
      legend_range <- range(map_data[[method]]$data, finite = TRUE)
      if (legend_range[[1L]] == legend_range[[2L]]) {
        spread <- max(abs(legend_range[[1L]]) * 1e-8, 1e-12)
        legend_range <- legend_range + c(-spread, spread)
      }
      proxy |>
        addLegend("bottomleft",
                  layerId = "wlv-legend",
                  # informing values as an interval to solve a bug when there 
                  # is only one number
                  values = c(legend_range[[1L]] * 0.99999999,
                             legend_range[[2L]] * 1.00000001),
                  pal = pallet[[method]],
                  title = paste0(method, "<br>", lb(indicator, lng), " (", unit, ")"),
                  labFormat = label_f2s(indicator, method, lng))
    }

    # De-active loading panel
    OP$loading <- renderText("")
  })
  
}
