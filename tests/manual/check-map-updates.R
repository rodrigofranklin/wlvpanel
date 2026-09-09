# Execute a partir da raiz, com WLV_CAMPAIGN_ROOT e temporários configurados.
# Verifica mensagens reais do servidor; não mede latência de rede ou do navegador.
campaign <- Sys.getenv("WLV_CAMPAIGN_ROOT")
stopifnot(nzchar(campaign), dir.exists(campaign))
if (.Platform$OS.type == "windows") {
  Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8")
}
source("global.R", encoding = "UTF-8")
stopifnot(exists("wlv_tr", mode = "function"))
stopifnot(identical(mypallet(c(NA_real_, NA_real_), default_indicator)(c(NA, NA)),
  c("transparent", "transparent")))
stopifnot(length(mypallet(c(0, 0), default_indicator)(c(0, 0))) == 2L)

# Ajuda: usa unidades reais por base, mantém notas disponíveis e identifica
# lacunas de metadados sem apresentar o código de tradução como conteúdo.
for (lng in c("Português", "English")) {
  info <- map_indicator_info(default_indicator, init_bases, lng)
  stopifnot(identical(names(info), c("variable", "unit", "description", "observations")),
    identical(info$variable, lb(default_indicator, lng)),
    identical(info$description, lb(paste0("desc.", default_indicator), lng)),
    identical(info$unit, "%"), !grepl("obs\\.", info$observations))
  empty_notes <- language_file[!startsWith(rownames(language_file), "obs."), , drop = FALSE]
  missing_info <- map_indicator_info(default_indicator, init_bases, lng, dictionary = empty_notes)
  stopifnot(identical(missing_info$observations,
    if (lng == "English") "Not provided" else "Não informadas"))
  differing_units <- meta_indicator_contracts
  rows <- differing_units$indicator == default_indicator & differing_units$method %in% init_bases
  differing_units$metadata_source[rows] <- "method_metadata"
  differing_units$display_unit[rows] <- ifelse(
    differing_units$method[rows] == init_bases[[1L]], "person", "hour")
  varied <- map_indicator_info(default_indicator, init_bases, lng, contracts = differing_units)
  stopifnot(identical(varied$unit, paste0(init_bases[[1L]], ": ",
    wlv_unit_label("person", lng), "\n", init_bases[[2L]], ": ", wlv_unit_label("hour", lng))))
}

# A troca de base pode produzir um ciclo sem observações. Mesmo quando
# list_display_f2s devolve apenas NA numéricos, o tooltip continua textual.
tooltip_cases <- unique(meta_indicator_contracts[c("method", "indicator")])
tooltip_cases$type <- vapply(seq_len(nrow(tooltip_cases)), function(i) {
  wlv_display_format_type(meta_indicator_contracts,
    tooltip_cases$method[[i]], tooltip_cases$indicator[[i]])
}, character(1))
tooltip_cases <- tooltip_cases[!duplicated(tooltip_cases$type), , drop = FALSE]
for (i in seq_len(nrow(tooltip_cases))) {
  method <- tooltip_cases$method[[i]]
  indicator <- tooltip_cases$indicator[[i]]
  for (language in c("Português", "English")) {
    missing_label <- if (language == "English") "No data" else "Sem dados"
    for (missing_values in list(c(NA_real_, NA_real_), c(NaN, NaN),
      c(Inf, -Inf), c(NA_real_, NaN, Inf, -Inf))) {
      stopifnot(identical(map_tooltip_values(missing_values, indicator, method, language),
        rep(missing_label, length(missing_values))))
    }
    expected <- if (language == "English") {
      c("235", "1.20K", "-1.20K")
    } else {
      c("235", "1,20K", "-1,20K")
    }
    stopifnot(identical(map_tooltip_values(
      c(235, 1200, -1200, NA_real_, NaN, Inf, -Inf), indicator, method, language),
      c(expected, rep(missing_label, 4L))))
    stopifnot(identical(map_tooltip_values(numeric(), indicator, method, language),
      character()))
  }
}

capture <- new.env(parent = emptyenv())
capture$messages <- list()
capture$inputs <- list()
capture$modals <- list()

map_calls <- function(messages, method) {
  sum(vapply(messages, function(message) {
    if (message$type != "leaflet-calls") return(0L)
    sum(vapply(message$data$calls, function(call) identical(call$method, method), logical(1)))
  }, integer(1)))
}

payload <- function(messages) {
  messages <- Filter(function(message) message$type == "wlv-map-update", messages)
  stopifnot(length(messages) > 0L)
  messages[[length(messages)]]$data
}

shiny::testServer(function(input, output, session) {
  session$sendCustomMessage <- function(type, message) {
    capture$messages[[length(capture$messages) + 1L]] <- list(type = type, data = message)
  }
  session$sendInputMessage <- function(inputId, message) {
    capture$inputs[[length(capture$inputs) + 1L]] <- list(id = inputId, data = message)
  }
  session$sendModal <- function(type, message) {
    capture$modals[[length(capture$modals) + 1L]] <- list(type = type, data = message)
  }
  RV <- reactiveValues()
  RV$bases <- reactiveVal(init_bases)
  map_server(input, output, RV, session)
}, {
  session$setInputs(l = default_language, co_select_indicator = default_indicator,
    co_select_year = default_year, co_map_method = "WIOD13", map_wlv_ready = 1L)
  widget <- jsonlite::fromJSON(output$map, simplifyVector = FALSE)
  widget_methods <- vapply(widget$x$calls, `[[`, "", "method")
  stopifnot(!any(widget_methods %in% c("addTiles", "addProviderTiles")),
    sum(widget_methods == "addGeoJSON") == 1L)
  base_call <- widget$x$calls[[which(widget_methods == "addGeoJSON")]]
  base <- jsonlite::fromJSON(base_call$args[[1L]], simplifyVector = FALSE)
  stopifnot(base$type == "FeatureCollection", length(base$features) == 127L,
    file.info("www/wlv-land-110m.geojson")$size < 150000)
  stopifnot(is.null(widget$x$fitBounds),
    grepl("WLVEqualEarth.install(L)", widget$x$options$mapFactory, fixed = TRUE),
    widget$x$options$minZoom < 0,
    identical(widget$x$options$preferCanvas, TRUE))
  stopifnot(map_calls(capture$messages, "addPolygons") == length(init_bases))
  initial <- payload(capture$messages)
  for (method in init_bases) {
    first <- Filter(function(layer) startsWith(layer$id, paste0(method, ".")), initial$layers)[[1L]]
    unit <- wlv_unit_label(wlv_display_unit(meta_indicator_contracts, method,
      default_indicator), default_language)
    stopifnot(grepl(paste0("<span class='tooltip-unit'>", htmltools::htmlEscape(unit), "</span>"),
      first$label, fixed = TRUE))
  }
  stopifnot(all(vapply(initial$layers, function(layer) {
    identical(names(layer), c("id", "color", "label"))
  }, logical(1))))

  capture$messages <- list()
  session$setInputs(co_select_year = default_year - 1)
  stopifnot(map_calls(capture$messages, "addPolygons") == 0L,
    map_calls(capture$messages, "addLayersControl") == 0L)
  year_payload <- payload(capture$messages)
  stopifnot(!identical(year_payload, initial))
  session$setInputs(co_map_method = "WIOD16", co_select_year = 2014)
  slider <- Filter(function(x) x$type == "wlv-map-years", capture$messages)
  stopifnot(max(tail(slider, 1)[[1L]]$data$years) == 2014)
  stopifnot(identical(output$map_status, ""))
  session$setInputs(co_map_method = "WIOD13")
  slider <- Filter(function(x) x$type == "wlv-map-years", capture$messages)
  stopifnot(max(tail(slider, 1)[[1L]]$data$years) == 2007,
    is.null(tail(slider, 1)[[1L]]$data$value))
  session$setInputs(co_select_year = 2007)

  common <- Reduce(intersect, lapply(init_bases, function(method) {
    method_indicator_availability$indicator[method_indicator_availability$method == method]
  }))
  alternative <- setdiff(common, default_indicator)[[1L]]
  capture$messages <- list()
  session$setInputs(map_show_indicator_info = alternative)
  stopifnot(identical(input$co_select_indicator, default_indicator),
    map_calls(capture$messages, "addPolygons") == 0L)
  modal <- tail(capture$modals, 1L)[[1L]]
  stopifnot(identical(modal$type, "show"), all(vapply(
    c("Variável:", "Unidade:", "Descrição:", "Observações:"),
    function(label) grepl(label, modal$data$html, fixed = TRUE), logical(1))))
  capture$messages <- list()
  session$setInputs(co_select_indicator = alternative)
  stopifnot(map_calls(capture$messages, "addPolygons") == 0L)
  before_language <- payload(capture$messages)
  stopifnot(!identical(before_language, year_payload))

  capture$messages <- list()
  capture$inputs <- list()
  session$setInputs(l = "English")
  stopifnot(identical(output$map_status, ""))
  stopifnot(map_calls(capture$messages, "addPolygons") == 0L,
    map_calls(capture$messages, "addLayersControl") == 0L)
  english <- payload(capture$messages)
  stopifnot(identical(lapply(english$layers, `[[`, "color"),
    lapply(before_language$layers, `[[`, "color")))
  stopifnot(!identical(lapply(english$layers, `[[`, "label"),
    lapply(before_language$layers, `[[`, "label")))
  countries <- Filter(function(value) value$id == "co_select_country", capture$inputs)
  stopifnot(length(countries) == 0L)

  # Remover e recolocar uma base reaproveita a geometria já carregada.
  capture$messages <- list()
  RV$bases(init_bases[[1L]])
  session$flushReact()
  RV$bases(init_bases)
  session$flushReact()
  stopifnot(map_calls(capture$messages, "addPolygons") == 0L)

  additional <- setdiff(wlv_methods_with_indicator(method_indicator_availability,
    list_methods, alternative), init_bases)
  if (length(additional)) {
    capture$messages <- list()
    RV$bases(c(init_bases, additional[[1L]]))
    session$flushReact()
    stopifnot(map_calls(capture$messages, "addPolygons") == 1L)
    RV$bases(init_bases)
    session$flushReact()
  }

  capture$inputs <- list()
  capture$messages <- list()
  session$setInputs(map_shape_click = list(id = paste0(init_bases[[1L]], ".BRA")))
  countries <- Filter(function(value) value$id == "co_select_country", capture$inputs)
  stopifnot(length(countries) == 0L)
  session$setInputs(co_select_country = "BRA")
  stopifnot(map_calls(capture$messages, "addPolygons") == 0L,
    map_calls(capture$messages, "addGeoJSON") == 0L)

  # Uma nova instância do mapa recebe novamente suas geometrias.
  capture$messages <- list()
  session$setInputs(map_wlv_ready = 2L, co_select_indicator = default_indicator)
  stopifnot(map_calls(capture$messages, "addPolygons") == length(init_bases))
  new_payload <- payload(capture$messages)

  # Reconstrói o envio antigo com as mesmas cores/textos e geometrias reais.
  baseline <- leaflet::leaflet()
  for (method in init_bases) {
    geometry <- countries_sp[[method]]
    ids <- as.character(geometry@data$layerId)
    rows <- new_payload$layers[match(ids, vapply(new_payload$layers, `[[`, "", "id"))]
    baseline <- leaflet::addPolygons(baseline, data = geometry, layerId = ids,
      group = method, fillColor = vapply(rows, `[[`, "", "color"),
      label = lapply(rows, function(row) htmltools::HTML(row$label)),
      fillOpacity = 0.6, color = "black", weight = 0.5,
      options = leaflet::pathOptions(pane = "polygons"),
      highlightOptions = leaflet::highlightOptions(color = "red", fillOpacity = 0.7,
        bringToFront = TRUE))
  }
  bytes <- function(value) nchar(jsonlite::toJSON(value, auto_unbox = TRUE, digits = 16),
    type = "bytes")
  old_bytes <- bytes(list(id = "map", calls = baseline$x$calls))
  new_bytes <- bytes(new_payload)
  stopifnot(new_bytes < old_bytes)
  result <- list(status = "passed", methods = init_bases,
    basemap_local = TRUE, projection = "Equal Earth (spherical)",
    basemap_features = length(base$features),
    basemap_asset_bytes = file.info("www/wlv-land-110m.geojson")$size,
    countries_across_methods = length(new_payload$layers),
    old_polygon_payload_bytes = old_bytes,
    new_attribute_payload_bytes = new_bytes,
    payload_reduction_percent = 100 * (1 - new_bytes / old_bytes),
    note = "Serialized JSON without compression; initial geometry and legends excluded.")
  jsonlite::write_json(result, file.path(campaign, "results", "map-update-check.json"),
    auto_unbox = TRUE, pretty = TRUE)
  print(result)
})
