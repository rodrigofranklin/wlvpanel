download_request_environment <- function() {
  root <- if (file.exists("utils/download_requests.R")) "." else "../.."
  env <- new.env(parent = asNamespace("openxlsx"))
  for (file in c("display_contracts", "download_workbooks", "download_requests")) {
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
