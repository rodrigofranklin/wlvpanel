country_localization_env <- new.env(parent = environment())
source(file.path(wlvpanel_test_root, "utils", "country_landing_charts.R"),
  local = country_localization_env, encoding = "UTF-8")

test_that("localization matches complete renders without recalculating chart geometry", {
  skip_if_not_installed("xml2")
  api <- country_localization_env
  state <- api$wlv_country_landing_chart_prepare(2000:2004,
    c(1234.567, 0, NA, -25.1, 3), c(1200, 1, 2, NA, 5), "localization")
  original <- state
  original_curves <- api$wlv_country_landing_curves
  api$wlv_country_landing_curves <- function(...) stop("Geometry must be reused")
  on.exit(api$wlv_country_landing_curves <- original_curves)
  geometry <- NULL
  for (lang in wlv_languages()$value) {
    for (kind in c("labour", "trade")) {
      message <- api$wlv_country_landing_chart_text(state, kind = kind, lang = lang)
      html <- as.character(api$wlv_country_landing_chart(prepared = state, kind = kind, lang = lang))
      doc <- xml2::read_html(html)
      get_text <- function(query) xml2::xml_text(xml2::xml_find_all(doc, query), trim = TRUE)
      expect_identical(get_text("//svg/title"), message$title, info = paste(lang, kind))
      expect_identical(get_text("//svg/desc"), message$description, info = paste(lang, kind))
      expect_identical(get_text("//span[contains(@class,'wlv-country-chart-tick-y')]"), message$ticks)
      expect_identical(get_text("//span[@class='wlv-country-chart-legend-item']"), message$legend)
      observations <- xml2::xml_find_all(doc, "//rect[@class='wlv-country-chart-observation']")
      expect_identical(xml2::xml_attr(observations, "aria-label"),
        vapply(message$observations, `[[`, character(1L), "text"))
      expect_identical(get_text("//rect/title"), vapply(message$observations, `[[`, character(1L), "text"))
      paths <- xml2::xml_attr(xml2::xml_find_all(doc, "//svg/path"), "d")
      if (is.null(geometry)) geometry <- paths else expect_identical(paths, geometry)
      expect_identical(message$id, state$id)
      expect_false(any(c("curves", "segments", "paths", "rows") %in% names(message)))
    }
  }
  expect_identical(state, original)
})

test_that("empty and single-series localization retains explicit unavailable states", {
  api <- country_localization_env
  empty <- api$wlv_country_landing_chart_prepare(numeric(), numeric(), numeric())
  partial <- api$wlv_country_landing_chart_prepare(2000, 0, NA_real_)
  for (lang in c("Português", "Français", "বাংলা")) {
    text <- api$wlv_country_landing_chart_text(empty, lang = lang)
    html <- as.character(api$wlv_country_landing_chart(prepared = empty, lang = lang))
    expect_match(html, htmltools::htmlEscape(text$empty), fixed = TRUE)
    expect_match(html, paste0('data-wlv-chart-id="', empty$id, '"'), fixed = TRUE)
    expect_length(text$observations, 0L)
    text <- api$wlv_country_landing_chart_text(partial, lang = lang)
    html <- as.character(api$wlv_country_landing_chart(prepared = partial, lang = lang))
    expect_match(html, htmltools::htmlEscape(text$note), fixed = TRUE)
    expect_match(text$observations[[1L]]$text, ": 0", fixed = TRUE)
    expect_match(text$observations[[1L]]$text,
      wlv_tr("Indisponível", "Unavailable", lang), fixed = TRUE)
  }
})

test_that("a hidden ready country keeps its SVG and profile on language-only changes", {
  skip_if_not_installed("shiny")
  api <- new.env(parent = environment())
  for (name in c("reactiveVal", "reactive", "observe", "observeEvent", "req", "isolate",
      "renderText", "renderUI", "outputOptions", "updateSelectInput", "updateSelectizeInput",
      "updateActionButton", "tagList", "div")) api[[name]] <- getExportedValue("shiny", name)
  api$tags <- htmltools::tags
  api$source <- function(file, ...) base::source(file.path(wlvpanel_test_root, file), local = api, ...)
  base::source(file.path(wlvpanel_test_root, "modules/country/landing.R"), local = api, encoding = "UTF-8")
  api$sea_countries <- array(1, c(1, 3, 1, 2), list("A", as.character(2000:2002), "unused", c("BRA", "CHN")))
  api$meta_indicator_contracts <- data.frame()
  api$wlv_trade_store <- list(bilateral = function(...) stop("Unexpected bilateral read"))
  api$wlv_country_regions <- c(BRA = "Other", CHN = "Other")
  api$lb <- function(code, lang) ifelse(code == "ISO3.BRA", wlv_tr("Brasil", "Brazil", lang), wlv_tr("China", "China", lang))
  profile_calls <- 0L
  api$wlv_country_landing_data <- function(countries, contracts, country, methods, bilateral) {
    profile_calls <<- profile_calls + 1L
    labour <- data.frame(year = 2000:2002, workday = c(8, 2, 6), labour_power = c(1, 4, 2),
      surplus = c(7, -2, 4), exploitation = c(700, -50, 200))
    trade <- data.frame(year = 2000:2002, sent = c(10, 4, 8) * 1e9,
      received = c(2, 8, 5) * 1e9, net = c(-8, 4, -3) * 1e9)
    list(method = methods, country = country, labour = labour, trade = trade,
      latest_labour = tail(labour, 1L), latest_trade = tail(trade, 1L))
  }
  messages <- list()
  mock <- shiny::MockShinySession$new()
  mock$sendCustomMessage <- function(type, message) {
    messages[[length(messages) + 1L]] <<- list(type = type, message = message)
  }
  shiny::testServer(function(input, output, session) {
    api$wlv_country_landing_server(input, output, list(bases = shiny::reactive("A")), session,
      availability = shiny::reactive({ input$l; list(countries = c("BRA", "CHN")) }),
      country = shiny::reactive({ input$l; input$co_select_country }))
  }, session = mock, {
    session$setInputs(l = "Português", co_select_country = "BRA", co_entry_method = "A", main_nav = "about")
    labour <- output$co_entry_labour_chart$html
    trade <- output$co_entry_trade_chart$html
    expect_identical(profile_calls, 1L)
    session$setInputs(co_entry_more = 1)
    expect_identical(output$co_entry_expanded, "true")
    for (lang in c("Français", "বাংলা", "Português")) {
      session$setInputs(l = lang)
      expect_identical(output$co_entry_labour_chart$html, labour)
      expect_identical(output$co_entry_trade_chart$html, trade)
      expect_identical(profile_calls, 1L)
      expect_identical(output$co_entry_expanded, "true")
      patches <- Filter(function(item) identical(item$type, "wlv-country-chart-text"), messages)
      patch <- tail(patches, 1L)[[1L]]$message
      expect_identical(patch$lang, wlv_language_locale(lang))
      expect_length(patch$charts, 2L)
      expect_match(labour, patch$charts[[1L]]$id, fixed = TRUE)
      expect_match(trade, patch$charts[[2L]]$id, fixed = TRUE)
    }
    session$setInputs(main_nav = "country")
    expect_identical(output$co_entry_labour_chart$html, labour)
    expect_identical(profile_calls, 1L)
    session$setInputs(co_select_country = "CHN")
    expect_identical(profile_calls, 2L)
    expect_false(identical(output$co_entry_labour_chart$html, labour))
    expect_identical(output$co_entry_expanded, "false")
  })
})

test_that("map deltas keep complete color-tooltip pairs and omit identical layers", {
  source <- parse(file.path(wlvpanel_test_root, "modules/countries/map.R"), encoding = "UTF-8")
  definition <- Filter(function(expr) is.call(expr) && identical(expr[[1L]], as.name("<-")) &&
    identical(expr[[2L]], as.name("wlv_map_layer_delta")), as.list(source))
  api <- new.env(parent = environment()); eval(definition[[1L]], api)
  first <- list(id = "A-BRA", color = "red", label = "Brasil")
  second <- list(id = "A-CHN", color = "amber", label = "China")
  previous <- list(`A-BRA` = first, `A-CHN` = second)
  expect_length(api$wlv_map_layer_delta(previous, list(first, second)), 0L)
  translated <- first; translated$label <- "Brésil"
  expect_identical(api$wlv_map_layer_delta(previous, list(translated, second)), list(translated))
  expect_identical(api$wlv_map_layer_delta(list(), list(first, second)), list(first, second))
  expect_identical(previous[["A-BRA"]], first)
})
