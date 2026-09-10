indicator_env <- new.env(parent = environment())
for (helper in c("download_workbooks.R", "download_requests.R")) {
  source(file.path(wlvpanel_test_root, "utils", helper), local = indicator_env, encoding = "UTF-8")
}
source(file.path(wlvpanel_test_root, "modules", "indicators", "main.R"), local = indicator_env, encoding = "UTF-8")

wlvpanel_indicator_fixture <- function() {
  legacy <- wlvpanel_legacy_metadata()
  paths <- c(wlvpanel_write_metadata(wlvpanel_method_metadata()), wlvpanel_write_metadata(wlvpanel_method_metadata(c(100, 100, 1), "index_point")))
  on.exit(unlink(paths), add = TRUE)
  contracts <- wlv_bind_display_contracts(list(
    wlv_read_method_display_contract(paths[[1L]], "w13", "W13", legacy$value, legacy),
    wlv_read_method_display_contract(paths[[2L]], "w16", "W16", legacy$value, legacy)
  ))
  values <- array(NA_real_, dim = c(2, 2, 2, 3), dimnames = list(c("W13", "W16"), c("2000", "2001"), c("price", "share"), c("AAA", "BRA", "CCC")))
  values["W13", , "share", "AAA"] <- c(0.5, NA)
  values["W13", , "share", "BRA"] <- c(0.125, 0.25)
  values["W16", , "share", "AAA"] <- c(1, 2)
  values["W16", , "share", "BRA"] <- c(3, 4)
  values[, , "price", ] <- 1
  language <- matrix(c("Pre\u00e7o", "Participa\u00e7\u00e3o", "Grupo", "Alfa", "Brasil", "Gama", "Price", "Share", "Group", "Alpha", "Brazil", "Gamma"), ncol = 2L, dimnames = list(c("price", "share", "group.test", "ISO3.AAA", "ISO3.BRA", "ISO3.CCC"), c("Portugu\u00eas", "English")))
  list(countries = values, metadata = legacy, contracts = contracts, language = language)
}

test_that("indicator comparisons preserve singleton axes and convert once", {
  fixture <- wlvpanel_indicator_fixture()
  fixture$countries <- fixture$countries["W13", "2000", "share", "BRA", drop = FALSE]
  values <- indicator_env$wlv_indicators_series(fixture$countries, "share", "W13", fixture$contracts)
  expect_equal(values$value, 12.5)
  expect_identical(values$unit, "percent")
  expect_identical(values$country, "BRA")
  expect_identical(values$year, 2000L)
  table <- indicator_env$wlv_indicators_snapshot(values, 2000, "W13")
  expect_equal(table$W13, 12.5)
})

test_that("indicator snapshots keep ISO identity across absent rows and methods", {
  fixture <- wlvpanel_indicator_fixture()
  values <- indicator_env$wlv_indicators_series(fixture$countries, "share", c("W13", "W16"), fixture$contracts)
  table <- indicator_env$wlv_indicators_snapshot(values, 2001, c("W13", "W16"))
  expect_identical(table$country, c("BRA", "AAA"))
  expect_equal(table$W13, c(25, NA))
  expect_equal(table$W16, c(400, 200))
  expect_false("CCC" %in% table$country)
  expect_equal(nrow(indicator_env$wlv_indicators_snapshot(values, 1990, c("W13", "W16"))), 0L)
  for (year in list(NULL, "", NA_integer_, "invalid")) {
    expect_equal(nrow(indicator_env$wlv_indicators_snapshot(values, year, c("W13", "W16"))), 0L)
  }
  fixture$countries["W16", , "share", ] <- NA_real_
  values <- indicator_env$wlv_indicators_series(fixture$countries, "share", c("W13", "W16"), fixture$contracts)
  expect_identical(unique(values$method), "W13")
  expect_equal(nrow(indicator_env$wlv_indicators_series(fixture$countries, "unknown", "W13", fixture$contracts)), 0L)
})

test_that("method-specific units remain explicit in comparison and export data", {
  fixture <- wlvpanel_indicator_fixture()
  values <- indicator_env$wlv_indicators_series(fixture$countries, "price", c("W13", "W16"), fixture$contracts)
  expect_identical(unique(values$unit), c("index", "index_point"))
  expect_equal(unique(values$value[values$method == "W13"]), 1)
  expect_equal(unique(values$value[values$method == "W16"]), 100)
  expect_true(anyNA(indicator_env$wlv_indicators_series(fixture$countries, "share", "W13", fixture$contracts)$value))
})

test_that("indicator translations use UTF-8 and fall back to stable identifiers", {
  fixture <- wlvpanel_indicator_fixture()
  expect_identical(indicator_env$wlv_indicators_label(fixture$language, "price"), "Pre\u00e7o")
  expect_identical(indicator_env$wlv_indicators_label(fixture$language, "price", "en"), "Price")
  expect_identical(indicator_env$wlv_indicators_label(fixture$language, "unknown"), "unknown")
  expect_identical(indicator_env$wlv_indicators_label(fixture$language, paste0("ISO3.", character()), fallback = character()), character())
  expect_identical(indicator_env$wlv_indicators_text("countries"), "Pa\u00edses para comparar")
})

test_that("catalogue subgroups follow stable families and preserve explicit metadata", {
  metadata <- data.frame(value = c("exports.s.us", "exports.s.mv", "imports.s.us"), groups = "Trade")
  rows <- indicator_env$wlv_indicators_catalogue_rows(metadata, metadata$value)
  expect_identical(rows$subgroup, c("exports", "exports", "imports"))
  metadata$subgroups <- c("a", "b", "a")
  expect_identical(indicator_env$wlv_indicators_catalogue_rows(metadata, metadata$value)$subgroup, metadata$subgroups)
  expect_identical(indicator_env$wlv_indicators_subgroup_label("exports"), "Exporta\u00e7\u00f5es")
  expect_identical(indicator_env$wlv_indicators_subgroup_label("exports", "en"), "Exports")
})

test_that("catalogue highlights preserve accents and escape HTML-like labels and queries", {
  highlight <- indicator_env$wlv_indicators_highlight
  expect_identical(as.character(highlight("Participação no comércio", "participacao")), "<mark>Participação</mark> no comércio")
  expect_identical(as.character(highlight("<b>Preço</b> & preço", "preco")), "&lt;b&gt;<mark>Preço</mark>&lt;/b&gt; &amp; <mark>preço</mark>")
  expect_identical(as.character(highlight("Produto (USD)", "(USD)")), "Produto <mark>(USD)</mark>")
  expect_identical(as.character(highlight("<script>alert(1)</script>", "<script>")), "<mark>&lt;script&gt;</mark>alert(1)&lt;/script&gt;")
  expect_identical(highlight("Preço", ""), "Preço")
  expect_identical(highlight("Preço", NULL), "Preço")
  expect_identical(highlight("Preço", "sem correspondência"), "Preço")
})

test_that("compound units use readable translated labels", {
  unit_label <- indicator_env$wlv_indicators_unit_label
  expect_identical(unit_label("abstract_labour_hour_per_person"), "mv/pessoa")
  expect_identical(unit_label("abstract_labour_hour_per_person", "en"), "mv/person")
  expect_identical(unit_label("legacy:abstract_labour_hour_per_usd"), "mv/US$")
  expect_identical(unit_label("local_currency_per_usd"), "Moeda local/US$")
})

test_that("ranking layout reserves a live readout without a permanent instructional hint", {
  for (package in c("shiny", "plotly", "leaflet", "DT")) skip_if_not_installed(package)
  html <- withr::with_dir(wlvpanel_test_root, as.character(indicator_env$indicators_ui("ranking-layout")))
  expect_false(grepl('id="ranking-layout-ranking_hint"', html, fixed = TRUE))
  expect_false(grepl('class="wlv-ranking-hint"', html, fixed = TRUE))
  expect_match(html, 'class="wlv-ranking-readout" role="status" aria-live="polite"', fixed = TRUE)
})

test_that("indicator module translates without changing data and renders all three views", {
  for (package in c("shiny", "plotly", "leaflet", "DT", "sp")) skip_if_not_installed(package)
  fixture <- wlvpanel_indicator_fixture()
  make_polygon <- function(x, id) sp::Polygons(list(sp::Polygon(matrix(c(x, 0, x + 1, 0, x + 1, 1, x, 1, x, 0), byrow = TRUE, ncol = 2L))), ID = id)
  polygons <- sp::SpatialPolygons(lapply(seq_len(3L), function(i) make_polygon(i * 2, c("AAA", "BRA", "CCC")[[i]])), proj4string = sp::CRS("+proj=longlat +datum=WGS84"))
  fixture$polygons <- list(W13 = sp::SpatialPolygonsDataFrame(polygons, data.frame(ISO3 = c("AAA", "BRA", "CCC"), row.names = c("AAA", "BRA", "CCC"))))
  language <- shiny::reactiveVal("pt")
  shiny::testServer(indicator_env$indicators_server, args = list(data = fixture, lang = language, bases = shiny::reactive(c("W13", "W16"))), {
    # Browser bindings arrive over multiple reactive flushes, including empty
    # select values before the first updateSelectInput reaches the client.
    expect_no_error(session$flushReact())
    expect_identical(output$page, "catalogue")
    session$setInputs(indicator = "price", year = "", methods = character(), countries = character(), map_method = "")
    expect_no_error(session$flushReact())
    session$setInputs(methods = c("W13", "W16"))
    expect_no_error(session$flushReact())
    expect_false(session$isClosed())
    session$setInputs(indicator = "share", methods = c("W13", "W16"), countries = "BRA", year = 2000, map_method = "W13")
    original <- series()
    expect_identical(output$title, "Indicadores")
    expect_match(output$all, "Pa\u00eds", fixed = TRUE)
    table <- jsonlite::fromJSON(output$all, simplifyVector = FALSE)
    expect_false(table$x$options$paging)
    expect_false(table$x$options$info)
    session$setInputs(search = "participacao")
    expect_match(output$catalogue$html, "catalogue_share", fixed = TRUE)
    expect_match(output$catalogue$html, "<mark>Participação</mark>", fixed = TRUE)
    expect_false(grepl("catalogue_price", output$catalogue$html, fixed = TRUE))
    session$setInputs(search = "", group = "test", subgroup = "price")
    expect_match(output$catalogue$html, "catalogue_price", fixed = TRUE)
    expect_false(grepl("catalogue_share", output$catalogue$html, fixed = TRUE))
    session$setInputs(catalogue_price = 1L)
    expect_identical(output$page, "detail")
    session$setInputs(back = 1L)
    expect_identical(output$page, "catalogue")
    expect_identical(input$subgroup, "price")
    expect_identical(input$countries, "BRA")
    expect_match(output$series, "Brazil|Brasil")
    session$setInputs(ranking_method = "W13")
    expect_identical(output$ranking_label, "Ranking")
    ranking <- jsonlite::fromJSON(output$ranking, simplifyVector = FALSE)
    expect_length(ranking$x$shinyEvents, 0L)
    expect_identical(ranking$x$layout$meta$method, "W13")
    ranking_payload <- ranking$jsHooks$render[[1L]]$data
    expect_identical(ranking_payload$countriesInputId, session$ns("countries"))
    expect_identical(unlist(ranking_payload$palette, use.names = FALSE),
      c("#8D2028", "#CC858A", "#F2DCDD", "#FCE7C0", "#F6AE2D"))
    expect_equal(ranking$x$data[[1L]]$opacity, 1)
    expect_identical(ranking_rows()$country, c("AAA", "BRA", "BRA"))
    expect_identical(ranking_rows()$rank, c(1L, 2L, 1L))
    map <- jsonlite::fromJSON(output$map, simplifyVector = FALSE)
    expect_identical(map$x$calls[[1L]]$method, "createMapPane")
    expect_identical(map$x$calls[[2L]]$method, "addPolygons")
    expect_identical(map$x$calls[[2L]]$args[[4L]]$pane, "wlv-indicator-polygons")
    expect_match(map$x$options$mapFactory, "WLVEqualEarth.install", fixed = TRUE)
    session$setInputs(map_ready = 1L)
    language("en")
    session$flushReact()
    expect_identical(output$title, "Indicators")
    expect_identical(series(), original)
    expect_identical(jsonlite::fromJSON(output$map, simplifyVector = FALSE), map)
    expect_identical(input$countries, "BRA")
    expect_identical(input$ranking_method, "W13")
    expect_match(output$ranking_context, "countries per year", fixed = TRUE)
    expect_match(output$all, "Country", fixed = TRUE)
    expect_identical(output$map_available, "yes")
    session$setInputs(methods = character())
    expect_identical(output$map_available, "no")
    expect_equal(nrow(series()), 0L)
    expect_false(session$isClosed())
    session$setInputs(methods = c("W13", "W16"))
    expect_identical(output$map_available, "yes")
    expect_identical(input$countries, "BRA")
    session$setInputs(indicator = "price")
    chart <- jsonlite::fromJSON(output$series, simplifyVector = FALSE)
    expect_true(all(c("yaxis", "yaxis2") %in% names(chart$x$layout)))
    session$setInputs(countries = character())
    expect_equal(nrow(selected_series()), 0L)
  })
})
