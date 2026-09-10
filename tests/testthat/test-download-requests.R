download_request_environment <- function() {
  root <- if (file.exists("utils/download_requests.R")) "." else "../.."
  env <- new.env(parent = asNamespace("openxlsx"))
  env$wlvpanel_test_root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  for (file in c("i18n", "display_contracts", "download_workbooks", "download_requests")) {
    sys.source(file.path(root, "utils", paste0(file, ".R")), envir = env)
  }
  env
}

download_request_fixture <- function() {
  countries <- array(seq_len(12L), c(1L, 2L, 2L, 3L),
    dimnames = list("BASE", c("2000", "2001"), c("ratio", "output"), c("A", "B", "WWW")))
  sectors <- list(BASE = array(seq_len(16L), c(2L, 2L, 2L, 2L),
    dimnames = list(c("2000", "2001"), c("ratio", "output"), c("s1", "s2"), c("A", "B"))))
  metadata <- data.frame(value = c("ratio", "output"))
  methods <- data.frame(code = "BASE", name = "Test base", source = "TEST", description = "Test")
  language <- matrix(c("País A", "País B", "World", "Ratio", "Output", "Sector 1", "Sector 2"), ncol = 1L,
    dimnames = list(c("ISO3.A", "ISO3.B", "ISO3.WWW", "ratio", "output", "TEST.s1", "TEST.s2"), "English"))
  contracts <- data.frame(method_dir = "BASE", method = "BASE", indicator = c("ratio", "output"),
    canonical_unit = c("ratio", "usd"), display_unit = c("percent", "usd"),
    display_multiplier = c(100, 1), index_base_year = NA_character_, index_storage_base = NA_real_,
    metadata_source = "method_metadata", legacy_type = NA_character_)
  list(countries = countries, sectors = sectors, metadata = metadata, methods = methods,
    language = language, contracts = contracts)
}

testthat::test_that("download requests use the selected language in country and workbook labels", {
  api <- download_request_environment()
  fixture <- download_request_fixture()
  fixture$language <- cbind(fixture$language,
    Castellano = c("País A", "País B", "Mundo", "Razón", "Producto", "Sector 1", "Sector 2"),
    "中文" = c("国家A", "国家B", "世界", "比率", "产出", "部门1", "部门2"))
  for (lang in c("es", "zh")) {
    request <- do.call(api$wlv_aggregated_download_request,
      c(list(method = "BASE", country = "A", lang = lang), fixture))
    testthat::expect_identical(request$lang, lang)
    testthat::expect_identical(request$header[1L, 1L], if (lang == "es") "País:" else "国家:")
    testthat::expect_identical(request$labels, if (lang == "es") c("Razón", "Producto") else c("比率", "产出"))
    testthat::expect_equal(unname(request$data), unname(fixture$countries[1L, , , "A"] |> t()))
    testthat::expect_match(api$wlv_multilateral_indicator_label("TT.P.MV", lang),
      if (lang == "es") "Transferencias netas de valor" else "净价值转移", fixed = TRUE)
  }
})

testthat::test_that("all supported aggregated selections work without prepared files", {
  export <- download_request_environment()
  fixture <- download_request_fixture()
  request <- function(...) do.call(export$wlv_aggregated_download_request, c(list(method = "BASE", ...), fixture))
  country <- request(country = "A")
  testthat::expect_identical(country$filename, "A.BASE.xlsx")
  testthat::expect_equal(unname(country$data), matrix(1:4, nrow = 2L, byrow = TRUE))
  testthat::expect_identical(request(indicator = "ratio")$filename, "ratio.BASE.xlsx")
  testthat::expect_identical(request(country = "A", indicator = "ratio")$filename, "A.ratio.BASE.xlsx")
  testthat::expect_identical(request(country = "A", sector = "s1")$filename, "A.s1.BASE.xlsx")
  testthat::expect_identical(request(indicator = "ratio", sector = "s1")$filename, "ratio.s1.BASE.xlsx")
  testthat::expect_null(request())
  testthat::expect_null(request(sector = "s1"))
  testthat::expect_null(request(country = "A", sector = "s1", indicator = "ratio"))
  testthat::expect_null(request(country = "WWW", indicator = "ratio"))
  testthat::expect_null(request(country = "A", indicator = "not-an-indicator"))
  testthat::expect_null(request(indicator = "ratio", sector = "not-a-sector"))
  testthat::expect_null(request(country = "not-a-country"))
})

testthat::test_that("generated download contains canonical data scaled exactly once and readable Unicode", {
  export <- download_request_environment()
  fixture <- download_request_fixture()
  request <- do.call(export$wlv_aggregated_download_request,
    c(list(method = "BASE", indicator = "ratio"), fixture))
  file <- tempfile(fileext = ".xlsx")
  export$wlv_write_download_request(request, file)
  data <- openxlsx::read.xlsx(file, sheet = "data", startRow = 6L)
  metadata <- openxlsx::read.xlsx(file, sheet = "metadata")
  testthat::expect_identical(openxlsx::getSheetNames(file), c("data", "metadata", "specs"))
  testthat::expect_identical(data$Name[[1L]], "País A")
  testthat::expect_equal(data[["2000"]], c(100, 500, 900))
  testthat::expect_equal(metadata$display_multiplier, 100)
  testthat::expect_identical(metadata$display_unit, "percent")
  testthat::expect_identical(request$data[[1L]], 1)
})

testthat::test_that("downloads reject missing observations while preserving zeros and available years", {
  export <- download_request_environment()
  fixture <- download_request_fixture()
  fixture$countries[] <- NA_real_
  request <- function() do.call(export$wlv_aggregated_download_request,
    c(list(method = "BASE", country = "A", indicator = NULL), fixture))
  testthat::expect_null(request())
  fixture$countries[1L, 1L, 1L, 1L] <- 0
  result <- request()
  testthat::expect_identical(rownames(result$data), "ratio")
  testthat::expect_identical(colnames(result$data), "2000")
  testthat::expect_equal(result$data[[1L]], 0)
})

testthat::test_that("multilateral exports retain direction and valid category-unit combinations", {
  export <- download_request_environment()
  fixture <- download_request_fixture()
  keys <- c("exports_values", "exports_mp", "exports_productive_mp", "transfers_values",
    "transfers_dp", "transfers_productive_values", "transfers_productive_dp")
  values <- array(seq_len(56L), dim = c(2L, 7L, 2L, 2L),
    dimnames = list(c("2000", "2001"), keys, c("A", "B"), c("A", "B")))
  request <- function(...) export$wlv_multilateral_download_request(method = "BASE", country = "A", ...,
    values = list(BASE = values), methods = fixture$methods, language = fixture$language)
  bilateral <- request(partner = "B")
  testthat::expect_equal(nrow(bilateral$data), 45L)
  testthat::expect_equal(unname(bilateral$data["CX.T.MP", ]), unname(values[, "exports_mp", "A", "B"]))
  testthat::expect_equal(unname(bilateral$data["CM.T.MP", ]), unname(values[, "exports_mp", "B", "A"]))
  testthat::expect_equal(bilateral$data["CN.T.MP", ], bilateral$data["CX.T.MP", ] - bilateral$data["CM.T.MP", ])
  testthat::expect_equal(bilateral$data["TT.T.MV", ], bilateral$data["TR.T.MV", ] - bilateral$data["TS.T.MV", ])
  testthat::expect_null(request(partner = "A"))
  testthat::expect_null(request(category = "TS.", scope = "T.", unit = "MP"))
  multilateral <- request(category = "CX.", scope = "T.", unit = "MP")
  testthat::expect_equal(multilateral$data["B", ], bilateral$data["CX.T.MP", ])
  file <- tempfile(fileext = ".xlsx")
  export$wlv_write_download_request(bilateral, file)
  testthat::expect_equal(nrow(openxlsx::read.xlsx(file, sheet = "data", startRow = 6L)), 45L)
})

testthat::test_that("aggregated availability never materializes or translates a workbook", {
  api <- download_request_environment()
  fixture <- download_request_fixture()
  arguments <- fixture[setdiff(names(fixture), "language")]
  api$wlv_xlsx_export_matrix <- function(...) stop("Unexpected matrix materialization")
  api$wlv_download_label <- function(...) stop("Unexpected label translation")
  selections <- list(list(country = "A"), list(indicator = "ratio"),
    list(country = "A", indicator = "ratio"), list(country = "A", sector = "s1"),
    list(indicator = "ratio", sector = "s1"))
  for (selection in selections) {
    plan <- do.call(api$wlv_aggregated_download_plan, c(list(method = "BASE"), selection, arguments))
    testthat::expect_false(is.null(plan))
    testthat::expect_false(any(c("labels", "header", "metadata", "lang") %in% names(plan)))
  }
  for (selection in list(list(), list(sector = "s1"), list(country = "unknown"),
      list(indicator = "unknown"), list(country = "WWW", indicator = "ratio"),
      list(country = "A", indicator = "ratio", sector = "s1"))) {
    testthat::expect_null(do.call(api$wlv_aggregated_download_plan,
      c(list(method = "BASE"), selection, arguments)))
  }
})

testthat::test_that("plans preserve sparse and zero-valued observations for every aggregate orientation", {
  api <- download_request_environment()
  fixture <- download_request_fixture()
  fixture$countries[] <- NA_real_
  fixture$sectors$BASE[] <- NA_real_
  selections <- list(list(country = "A"), list(indicator = "ratio"),
    list(country = "A", indicator = "ratio"), list(country = "A", sector = "s1"),
    list(indicator = "ratio", sector = "s1"))
  for (value in c(NA_real_, NaN, 0, Inf, -2)) {
    fixture$countries["BASE", "2001", "ratio", "A"] <- value
    fixture$sectors$BASE["2001", "ratio", "s1", "A"] <- value
    for (selection in selections) {
      plan <- do.call(api$wlv_aggregated_download_plan,
        c(list(method = "BASE"), selection, fixture[setdiff(names(fixture), "language")]))
      testthat::expect_identical(is.null(plan), is.na(value))
      if (!is.null(plan)) {
        data <- api$wlv_aggregated_download_data(plan)
        testthat::expect_identical(dim(data$data), c(1L, 1L))
        testthat::expect_identical(colnames(data$data), "2001")
        testthat::expect_equal(data$data[[1L]], value)
      }
    }
  }
})

testthat::test_that("bilateral availability equals the complete identities with sparse, missing and infinite data", {
  api <- download_request_environment()
  fixture <- download_request_fixture()
  keys <- c("exports_values", "exports_mp", "exports_productive_mp", "transfers_values",
    "transfers_dp", "transfers_productive_values", "transfers_productive_dp")
  values <- array(NA_real_, c(2L, length(keys), 2L, 2L),
    dimnames = list(c("2000", "2001"), keys, c("A", "B"), c("A", "B")))
  codes <- api$wlv_multilateral_indicator_codes()
  api$wlv_download_label <- function(...) stop("Unexpected translation")
  api$wlv_multilateral_indicator_label <- function(...) stop("Unexpected translation")
  for (key in keys) for (reverse in c(FALSE, TRUE)) for (value in c(NA_real_, NaN, 0, Inf, -3)) {
    current <- values
    current["2001", key, if (reverse) "B" else "A", if (reverse) "A" else "B"] <- value
    expected <- do.call(rbind, lapply(codes, function(code)
      api$wlv_multilateral_matrix(current, "A", "B", code)))
    plan <- api$wlv_multilateral_download_plan("BASE", "A", "B",
      values = list(BASE = current), methods = fixture$methods)
    testthat::expect_identical(!is.null(plan), any(!is.na(expected)))
    if (!is.null(plan)) {
      rownames(expected) <- codes
      expected <- expected[rowSums(!is.na(expected)) > 0L, colSums(!is.na(expected)) > 0L, drop = FALSE]
      testthat::expect_identical(api$wlv_multilateral_download_data(plan)$data, expected)
    }
  }
})

testthat::test_that("download callbacks defer composition, reuse numeric data across languages and capture one selection", {
  api <- download_request_environment()
  fixture <- download_request_fixture()
  fixture$language <- cbind(fixture$language,
    Castellano = c("País A", "País B", "Mundo", "Razón", "Producto", "Sector 1", "Sector 2"),
    "中文" = c("国家A", "国家B", "世界", "比率", "产出", "部门1", "部门2"))
  country <- shiny::reactiveVal("A")
  lang <- shiny::reactiveVal("en")
  materializations <- 0L
  compositions <- 0L
  written <- list()
  plan <- shiny::reactive(do.call(api$wlv_aggregated_download_plan,
    c(list(method = "BASE", country = country()), fixture[setdiff(names(fixture), "language")])))
  data <- shiny::reactive({
    materializations <<- materializations + 1L
    api$wlv_aggregated_download_data(plan())
  })
  callbacks <- api$wlv_download_callbacks(function() {
    compositions <<- compositions + 1L
    api$wlv_aggregated_download_localize(data(), fixture$language, lang())
  }, writer = function(request, file) { written[[file]] <<- request })
  testthat::expect_true(shiny::isolate(!is.null(plan())))
  lang("es")
  testthat::expect_true(shiny::isolate(!is.null(plan())))
  testthat::expect_identical(c(materializations, compositions), c(0L, 0L))
  testthat::expect_identical(shiny::isolate(callbacks$filename()), "A.BASE.xlsx")
  country("B")
  lang("zh")
  shiny::isolate(callbacks$content("first"))
  testthat::expect_identical(written$first$filename, "A.BASE.xlsx")
  testthat::expect_identical(written$first$lang, "es")
  testthat::expect_identical(written$first$labels, c("Razón", "Producto"))
  testthat::expect_equal(unname(written$first$data), matrix(1:4, nrow = 2L, byrow = TRUE))
  testthat::expect_identical(c(materializations, compositions), c(1L, 1L))
  testthat::expect_identical(shiny::isolate(callbacks$filename()), "B.BASE.xlsx")
  shiny::isolate(callbacks$content("second"))
  lang("en")
  shiny::isolate(callbacks$filename())
  shiny::isolate(callbacks$content("third"))
  testthat::expect_identical(c(materializations, compositions), c(2L, 3L))
  testthat::expect_identical(written$second$data, written$third$data)
  testthat::expect_identical(written$second$lang, "zh")
  testthat::expect_identical(written$third$lang, "en")
})
