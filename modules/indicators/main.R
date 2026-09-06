# Restores the catalogue, international comparisons, map and tables from
# panel_indicators.R at ebe8168, using the current method display contracts.

wlv_indicators_text <- function(key, lang = "pt") {
  dictionary <- list(
    title = c("Indicadores", "Indicators"),
    intro = c("Explore os indicadores e compare países, anos e bases de dados.", "Explore indicators and compare countries, years and databases."),
    indicator = c("Indicador", "Indicator"), countries = c("Países para comparar", "Countries to compare"),
    methods = c("Bases para comparar", "Databases to compare"), year = c("Ano das tabelas e do mapa", "Year for tables and map"),
    map_method = c("Base do mapa", "Map database"), series = c("Série histórica", "Time series"),
    map = c("Mapa", "Map"), catalogue = c("Catálogo de indicadores", "Indicator catalogue"),
    catalogue_intro = c("Escolha um indicador por grupo e subgrupo, ou pesquise pelo nome.", "Choose an indicator by group and subgroup, or search by name."),
    group = c("Grupo", "Group"), subgroup = c("Subgrupo", "Subgroup"),
    all_groups = c("Todos os grupos", "All groups"), all_subgroups = c("Todos os subgrupos", "All subgroups"),
    back = c("Voltar ao catálogo", "Back to catalogue"),
    search = c("Buscar no catálogo", "Search the catalogue"), all = c("Todos os países", "All countries"),
    selected = c("Países selecionados", "Selected countries"), country = c("País", "Country"),
    hint = c("Toque em uma linha ou em um país no mapa para adicioná-lo à comparação.", "Tap a row or a country on the map to add it to the comparison."),
    empty = c("Não há observações para esta seleção.", "No observations are available for this selection."),
    choose = c("Selecione pelo menos um país e uma base para comparar.", "Select at least one country and database to compare."),
    no_match = c("Nenhum indicador encontrado.", "No indicators found."),
    export = c("Baixar série selecionada (CSV)", "Download selected series (CSV)"),
    workbooks = c("Indicador completo por base (XLSX)", "Complete indicator by database (XLSX)"),
    export_hint = c("Inclui todos os anos dos países e bases selecionados, nas unidades exibidas.", "Includes all years for the selected countries and databases, in display units."),
    missing = c("Sem dados", "No data"), unit = c("Unidade", "Unit"),
    unit_note = c("Bases com unidades diferentes aparecem em gráficos separados.", "Databases with different units appear in separate charts."),
    table_search = c("Buscar país:", "Search country:"), table_info = c("_START_–_END_ de _TOTAL_ países", "_START_–_END_ of _TOTAL_ countries"),
    previous = c("Anterior", "Previous"), next_page = c("Próxima", "Next")
  )
  dictionary[[key]][[if (identical(lang, "en")) 2L else 1L]]
}

wlv_indicators_label <- function(language, key, lang = "pt", fallback = key) {
  # paste0("ISO3.", character()) produces one string; its empty fallback
  # still denotes an empty selection and must not invent a country label.
  if (!length(key) || !length(fallback)) return(character())
  column <- if (identical(lang, "en")) "English" else setdiff(colnames(language), "English")[[1L]]
  result <- as.character(language[match(key, rownames(language)), column])
  invalid <- is.na(result) | !nzchar(result)
  result[invalid] <- rep_len(fallback, length(result))[invalid]
  result
}

wlv_indicators_unit_label <- function(unit, lang = "pt") {
  unit <- sub("^legacy:", "", unit)
  labels <- list(percent = c("%", "%"), usd = c("US$", "US$"), index = c("Índice", "Index"),
    index_point = c("Pontos de índice", "Index points"), person = c("Pessoas", "People"),
    integer = c("Pessoas", "People"), hour = c("Horas", "Hours"), hours = c("Horas", "Hours"),
    value = c("Horas de trabalho abstrato", "Abstract labour hours"),
    abstract_labour_hour = c("Horas de trabalho abstrato", "Abstract labour hours"))
  if (unit %in% names(labels)) labels[[unit]][[if (identical(lang, "en")) 2L else 1L]] else unit
}

# Keep all dimensions: singleton methods, years and countries are valid inputs.
# Conversion takes place once, before any chart, table, tooltip or export.
wlv_indicators_series <- function(countries, indicator, methods, contracts) {
  axes <- dimnames(countries)
  stopifnot(length(dim(countries)) == 4L, length(indicator) == 1L)
  methods <- intersect(as.character(methods), axes[[1L]])
  methods <- methods[vapply(methods, function(method) {
    indicator %in% axes[[3L]] && any(is.finite(countries[method, , indicator, , drop = FALSE]))
  }, logical(1L))]
  empty <- data.frame(method = character(), year = integer(), country = character(), value = numeric(), unit = character())
  if (!length(methods)) return(empty)
  do.call(rbind, lapply(methods, function(method) {
    grid <- expand.grid(year = axes[[2L]], country = axes[[4L]], stringsAsFactors = FALSE)
    raw <- as.numeric(countries[method, , indicator, , drop = FALSE])
    data.frame(method = method, year = as.integer(grid$year), country = grid$country,
      value = wlv_display_values(raw, method, indicator, contracts),
      unit = wlv_display_unit(contracts, method, indicator), stringsAsFactors = FALSE)
  }))
}

wlv_indicators_snapshot <- function(series, year, methods) {
  year <- suppressWarnings(as.integer(year))
  valid_year <- length(year) == 1L && is.finite(year)
  current <- if (valid_year) series[series$year == year, , drop = FALSE] else series[FALSE, , drop = FALSE]
  countries <- unique(current$country[is.finite(current$value)])
  result <- data.frame(country = countries, stringsAsFactors = FALSE)
  for (method in methods) {
    rows <- current[current$method == method, , drop = FALSE]
    result[[method]] <- rows$value[match(countries, rows$country)]
  }
  result
}

# Older metadata stores only groups. Subgroups follow each stable indicator
# family; an explicit metadata subgroup takes precedence when supplied.
wlv_indicators_catalogue_rows <- function(metadata, codes) {
  rows <- metadata[match(codes, metadata$value), , drop = FALSE]
  subgroup_column <- intersect(c("subgroups", "subgroup"), names(rows))
  rows$subgroup <- if (length(subgroup_column)) as.character(rows[[subgroup_column[[1L]]]]) else sub("[.].*$", "", rows$value)
  rows$subgroup[is.na(rows$subgroup)] <- ""
  rows
}

wlv_indicators_subgroup_label <- function(code, lang = "pt") {
  dictionary <- list(
    capital_stock = c("Estoque de capital", "Capital stock"), profit = c("Lucro", "Profit"),
    capital_depreciation = c("Depreciação do capital", "Capital depreciation"),
    appropriated_profit = c("Lucro apropriado", "Appropriated profit"),
    trade_transfers = c("Transferência de valor pelo comércio", "Value transfers through trade"),
    exports = c("Exportações", "Exports"), imports = c("Importações", "Imports"),
    trade_balance = c("Saldo comercial", "Trade balance"), hours_worked = c("Horas trabalhadas", "Hours worked"),
    emp = c("Pessoas ocupadas", "Employed people"), empe = c("Trabalhadores assalariados", "Employees"),
    abstract_labour = c("Trabalho abstrato", "Abstract labour"), exchange = c("Taxa de câmbio", "Exchange rate"),
    go_price = c("Preços do produto total", "Gross output prices"),
    complex_labour_multiplier = c("Multiplicador de trabalho complexo", "Complex labour multiplier"),
    basket_price = c("Preço da cesta de consumo", "Consumption basket price"),
    basket_value = c("Valor da cesta de consumo", "Consumption basket value"),
    gross_output = c("Produto total", "Gross output"), gdp = c("Produto Interno Bruto", "Gross Domestic Product"),
    value = c("Valor", "Value"), surplus_value = c("Mais-valor", "Surplus value"),
    compensation = c("Remuneração do trabalho", "Labour compensation"),
    labour_force_value = c("Valor da força de trabalho", "Value of labour power")
  )
  vapply(code, function(value) {
    if (value %in% names(dictionary)) dictionary[[value]][[if (identical(lang, "en")) 2L else 1L]] else value
  }, character(1L), USE.NAMES = FALSE)
}

indicators_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::tags$link(rel = "stylesheet", href = "wlv-indicators.css"),
    shiny::tags$script(src = "wlv-equal-earth.js"),
    shiny::tags$script(src = "wlv-indicators.js"),
    shiny::div(class = "wlv-indicators",
      shiny::h2(shiny::textOutput(ns("title"), inline = TRUE)),
      shiny::p(shiny::textOutput(ns("intro"), inline = TRUE)),
      shiny::conditionalPanel("output.page === 'catalogue'", ns = ns,
        shiny::div(class = "wlv-indicators-catalogue-page",
          shiny::h3(shiny::textOutput(ns("catalogue_title"), inline = TRUE)),
          shiny::p(shiny::textOutput(ns("catalogue_intro"), inline = TRUE)),
          shiny::div(class = "wlv-indicators-catalogue-filters",
            shiny::textInput(ns("search"), "Buscar no catálogo", width = "100%"),
            shiny::selectInput(ns("group"), "Grupo", choices = NULL, width = "100%", selectize = FALSE),
            shiny::selectInput(ns("subgroup"), "Subgrupo", choices = NULL, width = "100%", selectize = FALSE)),
          shiny::uiOutput(ns("catalogue")))),
      shiny::conditionalPanel("output.page === 'detail'", ns = ns,
       shiny::div(class = "wlv-indicators-grid",
        shiny::div(class = "wlv-indicators-controls",
          shiny::actionButton(ns("back"), "Voltar ao catálogo", icon = shiny::icon("arrow-left"), width = "100%"),
          shiny::selectizeInput(ns("indicator"), "Indicador", choices = NULL, width = "100%"),
          shiny::selectizeInput(ns("countries"), "Países para comparar", choices = NULL, multiple = TRUE, width = "100%"),
          shiny::selectizeInput(ns("methods"), "Bases para comparar", choices = NULL, multiple = TRUE, width = "100%"),
          shiny::selectInput(ns("year"), "Ano das tabelas e do mapa", choices = NULL, width = "100%"),
          shiny::selectInput(ns("map_method"), "Base do mapa", choices = NULL, width = "100%"),
          shiny::uiOutput(ns("workbooks")),
          shiny::downloadButton(ns("download"), shiny::textOutput(ns("export_label"), inline = TRUE)),
          shiny::tags$small(shiny::textOutput(ns("export_hint"), inline = TRUE))) ,
        shiny::div(class = "wlv-indicators-main",
          shiny::h3(shiny::textOutput(ns("indicator_title"), inline = TRUE)),
          shiny::uiOutput(ns("description")),
          shiny::tabsetPanel(id = ns("view"),
            shiny::tabPanel(shiny::textOutput(ns("series_label"), inline = TRUE), value = "series", plotly::plotlyOutput(ns("series"), height = "420px")),
            shiny::tabPanel(shiny::textOutput(ns("map_label"), inline = TRUE), value = "map",
              shiny::conditionalPanel("output.map_available === 'yes'", ns = ns, leaflet::leafletOutput(ns("map"), height = "420px")),
              shiny::conditionalPanel("output.map_available !== 'yes'", ns = ns, shiny::p(shiny::textOutput(ns("map_empty"), inline = TRUE))))),
          shiny::p(shiny::textOutput(ns("hint"), inline = TRUE)),
          shiny::h3(shiny::textOutput(ns("selected_title"), inline = TRUE)), DT::DTOutput(ns("selected")),
          shiny::h3(shiny::textOutput(ns("all_title"), inline = TRUE)), DT::DTOutput(ns("all")))))))
}

indicators_server <- function(id, data, lang, bases) {
  shiny::moduleServer(id, function(input, output, session) {
    tr <- function(key) wlv_indicators_text(key, lang())
    label <- function(key, fallback = key) wlv_indicators_label(data$language, key, lang(), fallback)
    subgroup_label <- function(code) label(paste0("subgroup.", code), wlv_indicators_subgroup_label(code, lang()))
    page <- shiny::reactiveVal("catalogue")
    output$page <- shiny::renderText(page())
    shiny::outputOptions(output, "page", suspendWhenHidden = FALSE)
    shiny::observeEvent(input$back, page("catalogue"))
    output_labels <- c(title = "title", intro = "intro", export_label = "export", export_hint = "export_hint", catalogue_title = "catalogue", catalogue_intro = "catalogue_intro", series_label = "series", map_label = "map", hint = "hint", selected_title = "selected", all_title = "all")
    lapply(names(output_labels), function(id) { output[[id]] <- shiny::renderText(tr(output_labels[[id]])) })
    available_methods <- shiny::reactive(intersect(bases(), dimnames(data$countries)[[1L]]))
    available_indicators <- shiny::reactive({
      methods <- available_methods()
      if (!length(methods)) return(character())
      values <- data$countries[methods, , , , drop = FALSE]
      observed <- dimnames(values)[[3L]][apply(values, 3L, function(x) any(is.finite(x)))]
      intersect(data$metadata$value, observed)
    })
    methods_initialized <- FALSE
    countries_initialized <- FALSE
    shiny::observe({
      methods <- available_methods()
      indicators <- available_indicators()
      groups <- data$metadata$groups[match(indicators, data$metadata$value)]
      choices <- split(stats::setNames(indicators, label(indicators)), label(paste0("group.", groups), groups))
      selected <- shiny::isolate(input$indicator)
      if (!length(selected) || !selected %in% indicators) selected <- if ("surplus_value.empe_p.r.pc" %in% indicators) "surplus_value.empe_p.r.pc" else head(indicators, 1L)
      # The public catalogue is small (dozens of indicators). Local options
      # avoid an asynchronous Selectize reload that temporarily clears the
      # indicator and then restores stale country selections after a relabel.
      shiny::updateSelectizeInput(session, "indicator", label = tr("indicator"), choices = choices, selected = selected, server = FALSE)
      previous_methods <- shiny::isolate(input$methods)
      selected_methods <- intersect(previous_methods, methods)
      if (!methods_initialized || (length(previous_methods) && !length(selected_methods))) selected_methods <- methods
      if (length(methods)) methods_initialized <<- TRUE
      shiny::updateSelectizeInput(session, "methods", label = tr("methods"), choices = methods, selected = selected_methods)
      shiny::updateTextInput(session, "search", label = tr("search"))
      shiny::updateActionButton(session, "back", label = tr("back"))
    })
    catalogue_rows <- shiny::reactive(wlv_indicators_catalogue_rows(data$metadata, available_indicators()))
    shiny::observe({
      groups <- unique(catalogue_rows()$groups)
      selected <- shiny::isolate(input$group)
      if (!length(selected) || !selected %in% groups) selected <- ""
      choices <- stats::setNames(groups, label(paste0("group.", groups), groups))
      shiny::updateSelectInput(session, "group", label = tr("group"),
        choices = c(stats::setNames("", tr("all_groups")), choices[order(names(choices))]), selected = selected)
    })
    shiny::observe({
      rows <- catalogue_rows()
      if (length(input$group) && nzchar(input$group)) rows <- rows[rows$groups == input$group, , drop = FALSE]
      subgroups <- unique(rows$subgroup)
      selected <- shiny::isolate(input$subgroup)
      if (!length(selected) || !selected %in% subgroups) selected <- ""
      choices <- stats::setNames(subgroups, subgroup_label(subgroups))
      shiny::updateSelectInput(session, "subgroup", label = tr("subgroup"),
        choices = c(stats::setNames("", tr("all_subgroups")), choices[order(names(choices))]), selected = selected)
    })
    series <- shiny::reactive({
      shiny::req(input$indicator)
      wlv_indicators_series(data$countries, input$indicator, intersect(input$methods, available_methods()), data$contracts)
    })
    shiny::observe({
      values <- series()
      # Keep the country selection while comparison methods are temporarily
      # empty, so choosing methods again restores the same comparison.
      if (!nrow(values)) {
        shiny::updateSelectizeInput(session, "countries", label = tr("countries"))
        shiny::updateSelectInput(session, "map_method", label = tr("map_method"))
        return(invisible(NULL))
      }
      countries <- unique(values$country[is.finite(values$value)])
      current <- shiny::isolate(input$countries)
      selected <- intersect(current, countries)
      if (!countries_initialized || (length(current) && !length(selected))) selected <- if ("BRA" %in% countries) "BRA" else head(countries, 1L)
      if (length(countries)) countries_initialized <<- TRUE
      names(countries) <- label(paste0("ISO3.", countries), countries)
      countries <- countries[order(names(countries))]
      shiny::updateSelectizeInput(session, "countries", label = tr("countries"), choices = countries, selected = selected)
      methods <- unique(values$method)
      current_method <- shiny::isolate(input$map_method)
      selected_method <- if (length(current_method) && current_method %in% methods) current_method else head(methods, 1L)
      shiny::updateSelectInput(session, "map_method", label = tr("map_method"), choices = methods, selected = selected_method)
      years <- sort(unique(values$year[is.finite(values$value)]))
      if (length(years)) {
        # Empty select controls reach the server as "" before their choices are
        # acknowledged by the browser. Never index with which.min(NA).
        current_year <- suppressWarnings(as.integer(shiny::isolate(input$year)))
        if (length(current_year) != 1L || !is.finite(current_year)) current_year <- 2007L
        current_year <- years[[which.min(abs(years - current_year))]]
        shiny::updateSelectInput(session, "year", label = tr("year"), choices = years, selected = current_year)
      }
    })
    output$indicator_title <- shiny::renderText({ shiny::req(input$indicator); label(input$indicator) })
    output$description <- shiny::renderUI({
      shiny::req(input$indicator)
      description <- label(paste0("desc.", input$indicator), "")
      shiny::tagList(if (nzchar(description)) shiny::p(description), if (length(unique(series()$unit)) > 1L) shiny::p(tr("unit_note")))
    })
    output$catalogue <- shiny::renderUI({
      rows <- catalogue_rows()
      if (length(input$group) && nzchar(input$group)) rows <- rows[rows$groups == input$group, , drop = FALSE]
      if (length(input$subgroup) && nzchar(input$subgroup) && input$subgroup %in% rows$subgroup) rows <- rows[rows$subgroup == input$subgroup, , drop = FALSE]
      search <- input$search
      if (!is.null(search) && nzchar(search)) {
        # Accent-insensitive matching keeps a plain keyboard search useful in
        # Portuguese, and fixed=TRUE treats punctuation as text, not a regexp.
        fold <- function(value) tolower(iconv(value, from = "UTF-8", to = "ASCII//TRANSLIT", sub = ""))
        haystack <- paste(label(rows$value), rows$value, label(paste0("group.", rows$groups), rows$groups), subgroup_label(rows$subgroup))
        rows <- rows[grepl(fold(search), fold(haystack), fixed = TRUE), , drop = FALSE]
      }
      if (!nrow(rows)) return(shiny::p(role = "status", tr("no_match")))
      grouped <- split(rows, rows$groups)
      shiny::tagList(lapply(names(grouped), function(group) {
        values <- grouped[[group]]
        families <- split(values$value, values$subgroup)
        shiny::tags$section(class = "wlv-indicators-catalogue-group",
          shiny::h3(label(paste0("group.", group), group)),
          shiny::div(class = "wlv-indicators-catalogue-families", lapply(names(families), function(family) {
            codes <- families[[family]]
            shiny::div(class = "wlv-indicators-catalogue-family", shiny::h4(subgroup_label(family)),
              shiny::tags$ul(lapply(codes[order(label(codes))], function(code) {
                shiny::tags$li(shiny::actionLink(session$ns(paste0("catalogue_", code)), label(code)))
              })))
          })))
      }))
    })
    lapply(data$metadata$value, function(code) {
      shiny::observeEvent(input[[paste0("catalogue_", code)]], {
        shiny::updateSelectizeInput(session, "indicator", selected = code)
        page("detail")
      }, ignoreInit = TRUE)
    })
    selected_series <- shiny::reactive(series()[series()$country %in% input$countries, , drop = FALSE])
    output$map_empty <- shiny::renderText(tr("empty"))
    output$map_available <- shiny::renderText({
      values <- series()
      method <- input$map_method
      year <- suppressWarnings(as.integer(input$year))
      if (!length(method) || length(year) != 1L || !is.finite(year)) return("no")
      if (any(values$method == method & values$year == year & is.finite(values$value))) "yes" else "no"
    })
    shiny::outputOptions(output, "map_available", suspendWhenHidden = FALSE)
    output$series <- plotly::renderPlotly({
      values <- selected_series()
      shiny::validate(shiny::need(nrow(values) && any(is.finite(values$value)), tr("choose")))
      units <- unique(values$unit)
      charts <- lapply(units, function(unit) {
        unit_label <- wlv_indicators_unit_label(unit, lang())
        current <- values[values$unit == unit, , drop = FALSE]
        chart <- plotly::plot_ly()
        for (country in unique(current$country)) for (method in unique(current$method)) {
          rows <- current[current$country == country & current$method == method, , drop = FALSE]
          if (!any(is.finite(rows$value))) next
          country_name <- label(paste0("ISO3.", country), country)
          chart <- plotly::add_trace(chart, x = rows$year, y = rows$value, type = "scatter", mode = "lines+markers", name = paste(country_name, method, sep = " · "), connectgaps = FALSE, hovertemplate = paste0("%{x}: %{y:.4~g} ", htmltools::htmlEscape(unit_label), "<extra>%{fullData.name}</extra>"))
        }
        plotly::layout(chart, xaxis = list(title = "", tickformat = "d"), yaxis = list(title = unit_label), separators = if (identical(lang(), "en")) ".," else ",.", legend = list(orientation = "h", y = -0.2), margin = list(t = 15, b = 90))
      })
      chart <- if (length(charts) == 1L) charts[[1L]] else plotly::subplot(charts, nrows = length(charts), shareX = TRUE, titleY = TRUE)
      plotly::config(chart, displaylogo = FALSE, responsive = TRUE, locale = if (identical(lang(), "en")) "en" else "pt-br")
    })
    snapshot <- shiny::reactive(wlv_indicators_snapshot(series(), input$year, unique(series()$method)))
    table_widget <- function(values) {
      values$country <- label(paste0("ISO3.", values$country), values$country)
      methods <- setdiff(names(values), "country")
      names(values) <- c(tr("country"), vapply(methods, function(method) paste0(method, " (", wlv_indicators_unit_label(wlv_display_unit(data$contracts, method, input$indicator), lang()), ")"), character(1L)))
      table <- DT::datatable(values, rownames = FALSE, selection = "single", class = "display wlv-indicators-table", options = list(paging = FALSE, info = FALSE, ordering = TRUE, order = list(list(0L, "asc")), lengthChange = FALSE, scrollX = TRUE, language = list(search = tr("table_search"), infoEmpty = tr("empty"), zeroRecords = tr("empty"), emptyTable = tr("empty"))))
      if (length(methods)) table <- DT::formatRound(table, columns = seq_along(methods) + 1L, digits = 2L, mark = if (identical(lang(), "en")) "," else ".", dec.mark = if (identical(lang(), "en")) "." else ",")
      table
    }
    output$all <- DT::renderDT(table_widget(snapshot()), server = TRUE)
    output$selected <- DT::renderDT(table_widget(snapshot()[snapshot()$country %in% input$countries, , drop = FALSE]), server = TRUE)
    add_country <- function(country) {
      if (length(country) == 1L && country %in% unique(series()$country)) shiny::updateSelectizeInput(session, "countries", selected = unique(c(input$countries, country)))
    }
    shiny::observeEvent(input$all_rows_selected, {
      row <- input$all_rows_selected
      if (length(row) == 1L && row <= nrow(snapshot())) add_country(snapshot()$country[[row]])
    })
    polygons <- data$polygons[[1L]]
    for (method in names(data$polygons)[-1L]) {
      additional <- data$polygons[[method]]
      keep <- !as.character(additional@data$ISO3) %in% as.character(polygons@data$ISO3)
      if (any(keep)) polygons <- rbind(polygons, additional[keep, ], makeUniqueIDs = TRUE)
    }
    output$map <- leaflet::renderLeaflet({
      widget <- leaflet::leaflet(options = leaflet::leafletOptions(
        mapFactory = htmlwidgets::JS("function(el, options) { options.crs = window.WLVEqualEarth.install(L); return L.map(el, options); }"),
        minZoom = -2, maxZoom = 10, zoomSnap = 0, zoomDelta = 0.25, worldCopyJump = FALSE,
        preferCanvas = TRUE, trackResize = FALSE, doubleClickZoom = FALSE))
      widget <- leaflet::setView(widget, lng = 0, lat = 0, zoom = 0)
      widget <- leaflet::addPolygons(widget, data = polygons, layerId = as.character(polygons@data$ISO3), fillColor = "#e2e8f0", fillOpacity = 0.8, color = "#ffffff", weight = 0.6)
      htmlwidgets::onRender(widget, "function(el,x){this.attributionControl.addAttribution('<a href=\"https://www.naturalearthdata.com/\" target=\"_blank\" rel=\"noopener\">Natural Earth</a> / rworldmap · Equal Earth'); WLVIndicators.attach(el,this);}")
    })
    shiny::observe({
      shiny::req(input$map_ready, input$map_method, input$year)
      current <- series()
      current <- current[current$method == input$map_method & current$year == input$year, , drop = FALSE]
      codes <- as.character(polygons@data$ISO3)
      values <- current$value[match(codes, current$country)]
      values[!is.finite(values)] <- NA_real_
      finite <- values[is.finite(values)]
      domain <- if (length(finite)) range(c(0, finite)) else c(0, 1)
      if (diff(domain) == 0) domain <- domain + c(-1, 1)
      palette <- leaflet::colorNumeric("YlOrRd", domain = domain, na.color = "#cbd5e1")
      unit <- wlv_indicators_unit_label(wlv_display_unit(data$contracts, input$map_method, input$indicator), lang())
      labels <- lapply(seq_along(codes), function(i) {
        number <- if (!is.finite(values[[i]])) tr("missing") else paste(format(values[[i]], digits = 5L, big.mark = if (identical(lang(), "en")) "," else ".", decimal.mark = if (identical(lang(), "en")) "." else ",", trim = TRUE), unit)
        list(color = palette(values[[i]]), missing = !is.finite(values[[i]]), label = paste0("<strong>", htmltools::htmlEscape(label(paste0("ISO3.", codes[[i]]), codes[[i]])), "</strong>: ", htmltools::htmlEscape(number)))
      })
      names(labels) <- codes
      session$sendCustomMessage("wlvIndicatorsMap", list(id = session$ns("map"), countries = labels))
      proxy <- leaflet::clearControls(leaflet::leafletProxy("map", session))
      if (length(finite)) leaflet::addLegend(proxy, position = "bottomright", pal = palette, values = finite, title = htmltools::htmlEscape(paste(input$map_method, input$year, unit)))
    })
    shiny::observeEvent(input$map_shape_click, add_country(input$map_shape_click$id))
    output$workbooks <- shiny::renderUI({
      shiny::req(input$indicator)
      if (is.null(data$downloads)) return(NULL)
      links <- lapply(unique(series()$method), function(method) {
        href <- wlv_aggregated_download_href(method, indicator = input$indicator)
        if (wlv_download_href_available(href, data$downloads)) shiny::tags$li(shiny::tags$a(method, href = href))
      })
      links <- Filter(Negate(is.null), links)
      if (length(links)) shiny::tagList(shiny::tags$strong(tr("workbooks")), shiny::tags$ul(links))
    })
    output$download <- shiny::downloadHandler(
      filename = function() paste0("WLVD-", input$indicator, ".csv"), contentType = "text/csv; charset=utf-8",
      content = function(file) {
        values <- selected_series()
        values$indicator <- input$indicator
        values$country_name <- label(paste0("ISO3.", values$country), values$country)
        utils::write.csv(values, file, row.names = FALSE, na = "", fileEncoding = "UTF-8")
      })
    list(series = series, snapshot = snapshot, selected_series = selected_series)
  })
}

if (exists("modules_ui", inherits = FALSE) && exists("modules_server", inherits = FALSE)) {
  TABPANEL <- shiny::tabPanel(l("tab_name.indicators"), value = "indicators", indicators_ui("indicators"))
  modules_ui[[length(modules_ui) + 1L]] <- TABPANEL
  SERVER <- function(IP, OP, RV, SESSION) {
    indicators_server("indicators", data = list(countries = sea_countries, metadata = meta_indicators, contracts = meta_indicator_contracts, language = language_file, polygons = countries_sp, downloads = download_directory), lang = shiny::reactive(if (identical(IP$l, "English")) "en" else "pt"), bases = RV$bases)
  }
  modules_server[[length(modules_server) + 1L]] <- SERVER
}
