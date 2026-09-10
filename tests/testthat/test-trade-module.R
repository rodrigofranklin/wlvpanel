trade_module_root <- function() {
  candidate <- if (file.exists("modules/trade/main.R")) "." else "../.."
  normalizePath(candidate, winslash = "/", mustWork = TRUE)
}

trade_module_environment <- function(register = FALSE) {
  root <- trade_module_root()
  env <- new.env(parent = globalenv())
  env$source <- function(file, ...) base::source(file.path(root, file), local = env, ...)
  env$readRDS <- function(...) stop("Unexpected startup data read")
  if (register) {
    env$modules_ui <- list(); env$modules_server <- list()
    env$language_file <- matrix("", nrow = 1L, ncol = 2L,
      dimnames = list("tab_name.trade", c("Português", "English")))
    env$l <- function(key) shiny::span(key)
    env$meta_methods <- data.frame(code = "TEST", source = "test")
    env$countries_sp <- NULL
  }
  previous <- getwd(); on.exit(setwd(previous), add = TRUE); setwd(root)
  base::source(file.path(root, "modules/trade/main.R"), local = env, encoding = "UTF-8")
  env
}

trade_module_fixture <- function(api, partial = FALSE) {
  metrics <- c("exports_mp", "exports_productive_mp", "exports_values", "transfers_values",
    "transfers_productive_values", "transfers_dp", "transfers_productive_dp")
  values <- array(0, c(2L, 7L, 3L, 3L),
    dimnames = list(c("2000", "2001"), metrics, c("BRA", "CHN", "ROW"), c("BRA", "CHN", "ROW")))
  for (year in c("2000", "2001")) {
    values[year, , "BRA", "CHN"] <- c(120, 80, 40, -3, 5, -6, 10)
    values[year, , "CHN", "BRA"] <- c(90, 30, 15, -10, -6, -20, -12)
  }
  if (partial) values["2000", "transfers_values", "BRA", "CHN"] <- NA_real_
  attr(values, "method") <- "TEST"
  detail <- expand.grid(country = c("BRA", "CHN", "ROW"), partner = c("BRA", "CHN", "ROW"),
    sector = c("s1", "s2"), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  detail <- detail[detail$country != detail$partner, ]
  detail$productive <- detail$sector == "s1"
  detail$exports_usd <- 0; detail$embodied_hours <- 0; detail$transfer_hours <- 0
  outgoing <- detail$country == "BRA" & detail$partner == "CHN"
  incoming <- detail$country == "CHN" & detail$partner == "BRA"
  detail$exports_usd[outgoing] <- c(80, 40); detail$exports_usd[incoming] <- c(30, 60)
  detail$embodied_hours[outgoing] <- c(40, 0); detail$embodied_hours[incoming] <- c(15, 0)
  detail$transfer_hours[outgoing] <- c(5, -8); detail$transfer_hours[incoming] <- c(-6, -4)
  attr(detail, "method") <- "TEST"; attr(detail, "version") <- "test-v1"
  attr(detail, "factor_usd_per_hour") <- 2
  calls <- new.env(parent = emptyenv())
  calls$values <- c(methods = 0L, bilateral = 0L, years = 0L, detail_years = 0L, detail = 0L)
  calls$detail_years <- integer()
  count <- function(name) calls$values[[name]] <- calls$values[[name]] + 1L
  store <- list(methods = function() { count("methods"); "TEST" },
    bilateral = function(method) { count("bilateral"); values },
    years = function(...) { count("years"); 2000:2001 },
    detail_years = function(method) { count("detail_years"); 2000:2001 },
    detail = function(method, year) { count("detail"); calls$detail_years <- c(calls$detail_years, as.integer(year)); attr(detail, "year") <- as.character(year); detail },
    info = function() list(version = "test-v1", provenance = list(publication_mode = "synthetic")))
  language <- matrix(c("Brasil", "China", "Resto do mundo", "Agricultura", "Serviços",
    "Brazil", "China", "Rest of the world", "Agriculture", "Services"), ncol = 2L,
    dimnames = list(c("ISO3.BRA", "ISO3.CHN", "ISO3.ROW", "test.s1", "test.s2"), c("Português", "English")))
  list(store = store, calls = calls, data = list(language = language,
    methods = data.frame(code = "TEST", source = "test"), polygons = NULL))
}

trade_module_inputs <- function(session, ...) {
  defaults <- list(method = "TEST", country = "BRA", year = 2000L, metric = "transfer",
    scope = "total", unit = "value", dimension = "partner", partner = "", sector = "", view = "rank")
  supplied <- list(...); defaults[names(supplied)] <- supplied
  do.call(session$setInputs, defaults)
}

trade_expect_missing_plotly_warning <- function(expression) {
  count <- 0L
  value <- withCallingHandlers(expression, warning = function(condition) {
    # Only the expected rendering warning for the fixture's deliberate gap is
    # consumed. Every other warning propagates to the strict test runner.
    if (!identical(conditionMessage(condition), "Ignoring 1 observations")) return()
    count <<- count + 1L
    invokeRestart("muffleWarning")
  })
  testthat::expect_identical(count, 1L)
  invisible(value)
}

testthat::test_that("sourcing and registration never open trade data or mount the module", {
  api <- trade_module_environment(register = TRUE)
  testthat::expect_length(api$modules_ui, 1L)
  testthat::expect_length(api$modules_server, 1L)
  testthat::expect_identical(unname(api$wlv_trade_store$stats()$reads), c(0L, 0L, 0L))
  testthat::expect_false(api$wlv_trade_store$stats()$bilateral_loaded)
  mounts <- 0L
  api$trade_server <- function(...) { mounts <<- mounts + 1L; invisible(NULL) }
  shiny::testServer(function(input, output, session) {
    api$modules_server[[1L]](input, output, list(bases = shiny::reactive("TEST")), session)
  }, {
    session$setInputs(main_nav = "countries")
    testthat::expect_identical(mounts, 0L)
    session$setInputs(main_nav = "trade")
    testthat::expect_identical(mounts, 1L)
    session$setInputs(main_nav = "indicators")
    session$setInputs(main_nav = "trade")
    testthat::expect_identical(mounts, 1L)
    testthat::expect_match(output$trade_mount$html, "wlv-trade-layout", fixed = TRUE)
  })
  global <- readLines(file.path(trade_module_root(), "global.R"), encoding = "UTF-8", warn = FALSE)
  testthat::expect_true(any(grepl('source("modules/trade/main.R"', global, fixed = TRUE)))
  testthat::expect_false(any(grepl('readRDS("data/m_countries.RDS")', global, fixed = TRUE)))
})

testthat::test_that("inactive modules do not query on creation or while hidden", {
  api <- trade_module_environment(); fixture <- trade_module_fixture(api)
  enabled <- shiny::reactiveVal(FALSE)
  shiny::testServer(api$trade_server, args = list(store = fixture$store, data = fixture$data,
    lang = shiny::reactiveVal("pt"), bases = shiny::reactiveVal("TEST"), active = enabled), {
    # These widgets have not rendered in an inactive mock session yet.
    session$userData$plotlyShinyEventIDs <- paste0("plotly_click-", session$ns(c("rank", "composition")))
    session$flushReact()
    testthat::expect_equal(sum(fixture$calls$values), 0)
    trade_module_inputs(session)
    testthat::expect_equal(sum(fixture$calls$values), 0)
    enabled(TRUE); session$flushReact()
    testthat::expect_equal(rows()$value, c(7, 0))
    testthat::expect_gt(sum(fixture$calls$values), 0)
    stable <- fixture$calls$values
    session$flushReact(); session$flushReact()
    testthat::expect_identical(fixture$calls$values, stable)
    enabled(FALSE); session$flushReact()
    before <- fixture$calls$values
    session$setInputs(year = 2001L, country = "CHN", sector = "s1", view = "series")
    testthat::expect_identical(fixture$calls$values, before)
    enabled(TRUE); session$flushReact()
    testthat::expect_equal(sum(rows()$value), -11)
    testthat::expect_true(is.null(error()))
  })
})

testthat::test_that("dynamic controls are initialized only after the browser binds them", {
  api <- trade_module_environment(); fixture <- trade_module_fixture(api)
  messages <- list()
  mock <- shiny::MockShinySession$new()
  mock$sendInputMessage <- function(inputId, message) {
    messages[[length(messages) + 1L]] <<- list(id = inputId, message = message)
  }
  shiny::testServer(api$trade_server, session = mock,
    args = list(store = fixture$store, data = fixture$data,
      lang = shiny::reactiveVal("pt"), bases = shiny::reactiveVal("TEST"), active = shiny::reactiveVal(TRUE)), {
    session$userData$plotlyShinyEventIDs <- paste0("plotly_click-", session$ns(c("rank", "composition")))
    session$flushReact()
    updates <- Filter(function(x) grepl("(^|-)method$", x$id), messages)
    testthat::expect_length(updates, 0L)
    testthat::expect_equal(sum(fixture$calls$values), 0)
    session$setInputs(method = "__initial__")
    updates <- Filter(function(x) grepl("(^|-)method$", x$id), messages)
    testthat::expect_gte(length(updates), 1L)
    testthat::expect_identical(tail(updates, 1L)[[1L]]$message$value, "TEST")
    testthat::expect_match(as.character(tail(updates, 1L)[[1L]]$message$options), "TEST", fixed = TRUE)
    trade_module_inputs(session)
    testthat::expect_equal(rows()$value, c(7, 0))
    testthat::expect_true(is.null(error()))
  })
  testthat::expect_match(as.character(api$trade_ui("test")), 'value="__initial__"', fixed = TRUE)
})

testthat::test_that("source errors remain errors until their query recovers", {
  api <- trade_module_environment(); fixture <- trade_module_fixture(api)
  valid_detail <- fixture$store$detail
  fixture$store$detail <- function(method, year) {
    if (as.integer(year) == 2000L) stop("Hash da partição diverge do manifesto.")
    valid_detail(method, year)
  }
  shiny::testServer(api$trade_server, args = list(store = fixture$store, data = fixture$data,
    lang = shiny::reactiveVal("pt"), bases = shiny::reactiveVal("TEST"), active = shiny::reactiveVal(TRUE)), {
    trade_module_inputs(session, dimension = "sector")
    testthat::expect_null(rows())
    testthat::expect_match(output$status$html, api$wlv_trade_text("data_error"), fixed = TRUE)
    session$setInputs(year = 2001L)
    testthat::expect_equal(rows()$value, c(11, -4))
    testthat::expect_true(is.null(error()))
  })
})

testthat::test_that("inapplicable sector scopes never claim complete missing series", {
  api <- trade_module_environment(); fixture <- trade_module_fixture(api)
  shiny::testServer(api$trade_server, args = list(store = fixture$store, data = fixture$data,
    lang = shiny::reactiveVal("pt"), bases = shiny::reactiveVal("TEST"), active = shiny::reactiveVal(TRUE)), {
    trade_module_inputs(session, sector = "s2", scope = "productive")
    testthat::expect_equal(nrow(rows()), 0L)
    testthat::expect_equal(nrow(plot_rows()), 0L)
    values <- series_data()
    testthat::expect_false(any(!is.finite(values$value) & values$coverage == "complete"))
    testthat::expect_false(any(is.finite(values$value)))
  })
})

testthat::test_that("a failed historical partition is not erased by the next successful year", {
  api <- trade_module_environment(); fixture <- trade_module_fixture(api)
  valid_detail <- fixture$store$detail
  fixture$store$detail <- function(method, year) {
    if (as.integer(year) == 2000L) stop("Hash da partição histórica diverge do manifesto.")
    valid_detail(method, year)
  }
  shiny::testServer(api$trade_server, args = list(store = fixture$store, data = fixture$data,
    lang = shiny::reactiveVal("pt"), bases = shiny::reactiveVal("TEST"), active = shiny::reactiveVal(TRUE)), {
    trade_expect_missing_plotly_warning(trade_module_inputs(session, year = 2001L, sector = "s1", view = "series"))
    testthat::expect_equal(sum(rows()$value), 11)
    values <- series_data()
    testthat::expect_identical(values$year, 2000:2001)
    testthat::expect_true(is.na(values$value[values$year == 2000L]))
    testthat::expect_identical(values$coverage[values$year == 2000L], "missing")
    testthat::expect_match(output$status$html, api$wlv_trade_text("data_error"), fixed = TRUE)
  })
})

testthat::test_that("module preserves transfer signs units coverage and translated labels", {
  api <- trade_module_environment(); fixture <- trade_module_fixture(api, partial = TRUE)
  language <- shiny::reactiveVal("pt")
  shiny::testServer(api$trade_server, args = list(store = fixture$store, data = fixture$data,
    lang = language, bases = shiny::reactiveVal("TEST"), active = shiny::reactiveVal(TRUE)), {
    trade_expect_missing_plotly_warning(trade_module_inputs(session))
    testthat::expect_identical(rows()$coverage, c("partial", "complete"))
    testthat::expect_true(is.na(rows()$value[[1L]]))
    testthat::expect_match(output$status$html, "ausentes ou incompletas", fixed = TRUE)
    testthat::expect_identical(plot_rows()$label, c("China", "Resto do mundo"))
    trade_expect_missing_plotly_warning(session$setInputs(year = 2001L, partner = "CHN"))
    testthat::expect_equal(rows()$value, 7)
    testthat::expect_equal(totals()$outgoing, -3)
    testthat::expect_equal(totals()$incoming, -10)
    record <- export_frame(rows())
    testthat::expect_equal(record$export_contribution + record$import_contribution, record$value)
    testthat::expect_match(record$sign_convention, "positive_receipt_for_focal_country", fixed = TRUE)
    testthat::expect_match(output$summary$html, "Recebimento líquido", fixed = TRUE)
    session$setInputs(unit = "usd")
    testthat::expect_equal(rows()$value, 14)
    testthat::expect_match(unit_label(), "preços diretos", fixed = TRUE)
    session$setInputs(metric = "balance")
    testthat::expect_equal(rows()$value, 30)
    testthat::expect_match(unit_label(), "mercado", fixed = TRUE)
    record <- export_frame(rows())
    testthat::expect_equal(record$export_contribution + record$import_contribution, record$value)
    testthat::expect_match(record$sign_convention, "positive_trade_surplus", fixed = TRUE)
    session$setInputs(metric = "exports")
    record <- export_frame(rows())
    testthat::expect_equal(record$value, record$outgoing)
    testthat::expect_identical(record$sign_convention, "outgoing")
    session$setInputs(metric = "imports")
    record <- export_frame(rows())
    testthat::expect_equal(record$value, record$incoming)
    testthat::expect_identical(record$sign_convention, "incoming")
    language("en"); session$flushReact()
    testthat::expect_identical(output$title, "Value transfers")
    testthat::expect_match(context_title(), "Brazil", fixed = TRUE)
    stable <- fixture$calls$values
    language("pt"); session$flushReact()
    testthat::expect_identical(fixture$calls$values, stable)
  })
})

testthat::test_that("partner and supplier filters stay consistent in snapshot and series", {
  api <- trade_module_environment(); fixture <- trade_module_fixture(api)
  shiny::testServer(api$trade_server, args = list(store = fixture$store, data = fixture$data,
    lang = shiny::reactiveVal("pt"), bases = shiny::reactiveVal("TEST"), active = shiny::reactiveVal(TRUE)), {
    trade_module_inputs(session, dimension = "sector", partner = "CHN")
    testthat::expect_equal(rows()$value, c(11, -4))
    testthat::expect_identical(plot_rows()$label, c("Agricultura", "Serviços"))
    session$setInputs(sector = "s2", dimension = "partner")
    testthat::expect_equal(rows()$value, -4)
    testthat::expect_equal(series_data()$value, c(-4, -4))
    testthat::expect_identical(series_data()$year, 2000:2001)
    testthat::expect_match(context_title(), "Serviços", fixed = TRUE)
    exported <- export_frame(series_data())
    testthat::expect_identical(exported$selected_partner, c("CHN", "CHN"))
    testthat::expect_identical(exported$selected_sector, c("s2", "s2"))
    testthat::expect_identical(exported$data_version, c("test-v1", "test-v1"))
    session$setInputs(partner = "", sector = "")
    testthat::expect_equal(series_data()$value, c(7, 7))
    testthat::expect_null(selection()$sector)
  })
})

testthat::test_that("returning to a chart or module never replays a persisted Plotly click", {
  testthat::skip_if_not_installed("plotly")
  for (view in c("rank", "composition")) {
    api <- trade_module_environment(); fixture <- trade_module_fixture(api)
    enabled <- shiny::reactiveVal(TRUE)
    messages <- new.env(parent = emptyenv())
    messages$updates <- list()
    mock <- shiny::MockShinySession$new()
    mock$sendInputMessage <- function(inputId, message) {
      messages$updates[[length(messages$updates) + 1L]] <- list(id = inputId, message = message)
    }
    shiny::testServer(api$trade_server, session = mock,
      args = list(store = fixture$store, data = fixture$data, lang = shiny::reactiveVal("pt"),
        bases = shiny::reactiveVal("TEST"), active = enabled), {
      # The browser registers these events after rendering a widget. Populate
      # that registry here while exercising the real event_data input parser.
      session$userData$plotlyShinyEventIDs <- paste0("plotly_click-", session$ns(c("rank", "composition")))
      trade_module_inputs(session, dimension = "sector", partner = "CHN", view = view)
      messages$updates <- list()
      click <- function(id) {
        payload <- jsonlite::toJSON(list(list(customdata = id)), auto_unbox = TRUE)
        event_id <- paste0("plotly_click-", session$ns(view))
        do.call(session$rootScope()$setInputs, stats::setNames(list(payload), event_id))
      }
      sector_updates <- function() {
        # Ignore ordinary label/choice refreshes when the module is reactivated;
        # a drill sends only the selected value to this input.
        selected <- Filter(function(update) update$id %in% c("sector", session$ns("sector")) &&
          identical(names(update$message), "value"), messages$updates)
        vapply(selected, function(update) as.character(update$message$value), character(1L))
      }
      click("s1")
      testthat::expect_identical(sector_updates(), "s1")
      # Mock sessions record update messages without applying browser-side
      # inputs, so a replay would execute the same valid sector drill again.
      session$setInputs(view = if (view == "rank") "composition" else "rank")
      session$setInputs(view = view)
      testthat::expect_identical(sector_updates(), "s1")
      enabled(FALSE); session$flushReact()
      enabled(TRUE); session$flushReact()
      testthat::expect_identical(sector_updates(), "s1")
      click("s2")
      testthat::expect_identical(sector_updates(), c("s1", "s2"))
    })
  }
})
