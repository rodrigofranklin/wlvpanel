wlvpanel_file <- function(...) {
  relative <- file.path(...)
  candidates <- c(relative, file.path("..", "..", relative))
  existing <- candidates[file.exists(candidates)]
  if (!length(existing)) {
    stop(sprintf("Cannot find test project file `%s`.", relative), call. = FALSE)
  }
  normalizePath(existing[[1L]], winslash = "/", mustWork = TRUE)
}

load_download_export_functions <- function() {
  parent <- if (requireNamespace("openxlsx", quietly = TRUE)) {
    asNamespace("openxlsx")
  } else {
    globalenv()
  }
  environment <- new.env(parent = parent)
  sys.source(wlvpanel_file("utils", "display_contracts.R"), envir = environment)
  expressions <- parse(wlvpanel_file("utils", "prepare_downloadable_files.R"))
  functions <- c(
    "ind_type",
    "wlv_legacy_xlsx_num_format",
    "wlv_xlsx_export_matrix",
    "wlv_prepare_xlsx_display",
    "wlv_xlsx_contract_metadata",
    "save_my_xlsx"
  )
  for (expression in expressions) {
    if (
      is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
        is.symbol(expression[[2L]]) &&
        as.character(expression[[2L]]) %in% functions
    ) {
      eval(expression, envir = environment)
    }
  }
  environment
}

method_contract <- function(method, indicators, units, multipliers, types = NULL) {
  data.frame(
    method_dir = rep(method, length(indicators)),
    method = rep(method, length(indicators)),
    indicator = indicators,
    canonical_unit = units,
    display_unit = units,
    display_multiplier = multipliers,
    index_base_year = rep(NA_character_, length(indicators)),
    index_storage_base = rep(NA_real_, length(indicators)),
    metadata_source = rep("method_metadata", length(indicators)),
    legacy_type = rep(NA_character_, length(indicators)),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

format_for_row <- function(payload, row) {
  selected <- which(vapply(
    payload$rows_style_list,
    function(rows) row %in% rows,
    logical(1L)
  ))
  payload$styles_list[[selected]]
}

xlsx_style_for_cell <- function(workbook, sheet, row, col) {
  selected <- Filter(
    function(object) {
      identical(object$sheet, sheet) && row %in% object$rows &&
        col %in% object$cols
    },
    workbook[["styleObjects"]]
  )
  selected[[length(selected)]]$style
}

testthat::test_that("method contracts scale XLSX values exactly once", {
  export <- load_download_export_functions()
  contracts <- method_contract(
    "NEW",
    c("ratio.r.pc", "output.s.us"),
    c("percent", "usd"),
    c(100, 1),
    c("percent", "usd")
  )
  export$wlv_validate_display_contracts(contracts)
  canonical <- matrix(
    c(0.125, 0.25, 10, 20),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(c("ratio.r.pc", "output.s.us"), c("2000", "2001"))
  )

  payload <- export$wlv_prepare_xlsx_display(
    canonical,
    "NEW",
    rownames(canonical),
    contracts
  )

  testthat::expect_identical(canonical[1L, ], c("2000" = 0.125, "2001" = 0.25))
  testthat::expect_identical(payload$data[1L, ], c("2000" = 12.5, "2001" = 25))
  testthat::expect_identical(payload$data[2L, ], canonical[2L, ])
  testthat::expect_identical(format_for_row(payload, 7L), '0.00"%"')
  testthat::expect_identical(format_for_row(payload, 8L), "#,##0.00")

  repeated <- export$wlv_prepare_xlsx_display(
    matrix(c(0.125, 0.25), nrow = 2L),
    "NEW",
    "ratio.r.pc",
    contracts
  )
  testthat::expect_identical(as.vector(repeated$data), c(12.5, 25))
  testthat::expect_identical(repeated$rows_style_list[[1L]], c(7L, 8L))
})

testthat::test_that("legacy fallback preserves stored values and Excel scaling", {
  export <- load_download_export_functions()
  legacy_metadata <- data.frame(
    value = c("ratio.r.pc", "output.s.us"),
    type = c("percent", "usd"),
    stringsAsFactors = FALSE
  )
  contracts <- export$wlv_legacy_display_contract(
    method_dir = "LEGACY",
    method = "LEGACY",
    indicators = legacy_metadata$value,
    legacy_metadata = legacy_metadata,
    warn = FALSE
  )
  canonical <- matrix(c(0.125, 10), nrow = 2L)

  payload <- export$wlv_prepare_xlsx_display(
    canonical,
    "LEGACY",
    legacy_metadata$value,
    contracts,
    legacy_metadata
  )

  testthat::expect_identical(payload$data, canonical)
  testthat::expect_identical(format_for_row(payload, 7L), "PERCENTAGE")
  testthat::expect_identical(format_for_row(payload, 8L), "#,##0.00")

  metadata <- export$wlv_xlsx_contract_metadata(
    data.frame(Code = legacy_metadata$value),
    "LEGACY",
    legacy_metadata$value,
    contracts
  )
  testthat::expect_identical(metadata$method, rep("LEGACY", 2L))
  testthat::expect_true(all(is.na(metadata$canonical_unit)))
  testthat::expect_identical(metadata$display_multiplier, c(1, 1))
  testthat::expect_identical(
    metadata$metadata_source,
    rep("legacy_fallback", 2L)
  )
  testthat::expect_identical(metadata$legacy_type, legacy_metadata$type)

  no_suffix_legacy <- data.frame(
    value = "ratio_without_suffix",
    type = "percent",
    stringsAsFactors = FALSE
  )
  no_suffix_contract <- export$wlv_legacy_display_contract(
    "legacy", "LEGACY-NO-SUFFIX", no_suffix_legacy$value,
    no_suffix_legacy, warn = FALSE
  )
  no_suffix_payload <- export$wlv_prepare_xlsx_display(
    matrix(0.125, nrow = 1L),
    "LEGACY-NO-SUFFIX",
    no_suffix_legacy$value,
    no_suffix_contract
  )
  testthat::expect_identical(no_suffix_payload$styles_list, list("PERCENTAGE"))
})

testthat::test_that("modern neutral units stay neutral in XLSX", {
  export <- load_download_export_functions()
  indicators <- c("ratio.r.pc", "exchange.r.us", "future.s.un")
  contracts <- method_contract(
    "NEW",
    indicators,
    c("ratio", "local_currency_per_usd", "future_unit"),
    c(1, 1, 1)
  )
  canonical <- matrix(
    c(0.125, 0.25, 5.2, 5.4, 7.25, 8.5),
    nrow = 3L,
    byrow = TRUE,
    dimnames = list(indicators, c("2000", "2001"))
  )
  payload <- export$wlv_prepare_xlsx_display(
    canonical,
    "NEW",
    indicators,
    contracts
  )

  testthat::expect_identical(payload$data, canonical)
  testthat::expect_identical(payload$styles_list, list("#,##0.00"))
  testthat::expect_identical(payload$rows_style_list[[1L]], 7:9)

  metadata <- export$wlv_xlsx_contract_metadata(
    data.frame(Code = indicators),
    "NEW",
    indicators,
    contracts
  )
  testthat::expect_identical(metadata$canonical_unit, contracts$canonical_unit)
  testthat::expect_identical(metadata$display_unit, contracts$display_unit)
  testthat::expect_identical(metadata$display_multiplier, c(1, 1, 1))
  testthat::expect_true(all(c(
    "method", "canonical_unit", "display_unit", "display_multiplier",
    "index_base_year", "index_storage_base", "metadata_source",
    "legacy_type"
  ) %in% names(metadata)))
})

testthat::test_that("XLSX inputs preserve cancellation and valid zeros", {
  export <- load_download_export_functions()
  indicators <- c("cancel", "zero")
  contracts <- method_contract(
    "METHOD", indicators, rep("ratio", 2L), rep(1, 2L)
  )
  country_a <- matrix(
    c(-1, 1, 0, 0),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(indicators, c("2000", "2001"))
  )
  cancel_by_country <- matrix(
    c(-1, 1, 3, 4),
    nrow = 2L,
    byrow = TRUE,
    dimnames = list(c("A", "B"), c("2000", "2001"))
  )

  country_payload <- export$wlv_prepare_xlsx_display(
    country_a,
    "METHOD",
    indicators,
    contracts
  )
  indicator_payload <- export$wlv_prepare_xlsx_display(
    cancel_by_country,
    "METHOD",
    "cancel",
    contracts
  )

  testthat::expect_identical(country_payload$data, country_a)
  testthat::expect_identical(indicator_payload$data, cancel_by_country)
  testthat::expect_true(export$wlv_has_observations(country_a["zero", ]))
  testthat::expect_identical(
    export$wlv_observed_axis_labels(
      array(
        country_a,
        dim = c(1L, 2L, 2L),
        dimnames = list(method = "METHOD", indicator = indicators,
          year = c("2000", "2001"))
      ),
      2L
    ),
    indicators
  )
})

testthat::test_that("XLSX export matrices preserve singleton axes", {
  export <- load_download_export_functions()
  indicators <- c("first", "second")
  countries <- c("A", "B")
  values <- array(
    c(11, 22, 33, 44),
    dim = c(1L, 1L, 2L, 2L),
    dimnames = list(
      method = "METHOD",
      year = "2000",
      indicator = indicators,
      country = countries
    )
  )
  contracts <- method_contract(
    "METHOD", indicators, rep("ratio", 2L), rep(1, 2L)
  )

  country_data <- export$wlv_xlsx_export_matrix(
    values["METHOD", "2000", indicators, "A", drop = FALSE],
    row_axis = 3L,
    column_axis = 2L
  )
  indicator_data <- export$wlv_xlsx_export_matrix(
    values["METHOD", "2000", "first", countries, drop = FALSE],
    row_axis = 4L,
    column_axis = 2L
  )
  singleton <- export$wlv_xlsx_export_matrix(
    values["METHOD", "2000", "second", "B", drop = FALSE],
    row_axis = 3L,
    column_axis = 2L
  )
  two_years <- array(
    c(51, 52),
    dim = c(1L, 2L, 1L, 1L),
    dimnames = list(
      method = "METHOD",
      year = c("2000", "2001"),
      indicator = "first",
      country = "A"
    )
  )
  single_row <- export$wlv_xlsx_export_matrix(
    two_years,
    row_axis = 3L,
    column_axis = 2L
  )

  testthat::expect_identical(
    country_data,
    matrix(c(11, 22), nrow = 2L,
      dimnames = list(indicator = indicators, year = "2000"))
  )
  testthat::expect_identical(
    indicator_data,
    matrix(c(11, 33), nrow = 2L,
      dimnames = list(country = countries, year = "2000"))
  )
  testthat::expect_identical(
    singleton,
    matrix(44, nrow = 1L,
      dimnames = list(indicator = "second", year = "2000"))
  )
  testthat::expect_identical(
    single_row,
    matrix(c(51, 52), nrow = 1L,
      dimnames = list(indicator = "first", year = c("2000", "2001")))
  )
  testthat::expect_identical(
    export$wlv_prepare_xlsx_display(
      country_data, "METHOD", indicators, contracts
    )$data,
    country_data
  )
  testthat::expect_identical(
    export$wlv_prepare_xlsx_display(
      indicator_data, "METHOD", "first", contracts
    )$data,
    indicator_data
  )
})

testthat::test_that("generated XLSX stores display percent with a literal format", {
  testthat::skip_if_not_installed("openxlsx")
  export <- load_download_export_functions()
  contracts <- method_contract(
    "NEW", "ratio.r.pc", "percent", 100, "percent"
  )
  file <- tempfile(fileext = ".xlsx")
  export$save_my_xlsx(
    file_name = file,
    header = matrix(c("Indicator:", "Ratio"), nrow = 1L),
    row_names = "Ratio",
    my_data = matrix(0.125, nrow = 1L, dimnames = list(NULL, "2000")),
    metadata = data.frame(Code = "ratio.r.pc"),
    specs = data.frame(code = "NEW"),
    rows_style_list = list(7L),
    styles_list = list("PERCENTAGE"),
    width_c1 = 20,
    width_c2 = 10,
    method_code = "NEW",
    indicator_codes = "ratio.r.pc",
    display_contracts = contracts
  )

  stored <- openxlsx::read.xlsx(
    file, sheet = "data", rows = 7L, cols = 3L, colNames = FALSE
  )
  workbook <- openxlsx::loadWorkbook(file)
  style <- xlsx_style_for_cell(workbook, "data", 7L, 3L)
  published_metadata <- openxlsx::read.xlsx(file, sheet = "metadata")

  testthat::expect_identical(stored[[1L]], 12.5)
  testthat::expect_identical(
    style$numFmt$formatCode,
    "0.00&quot;%&quot;"
  )
  testthat::expect_identical(published_metadata$method, "NEW")
  testthat::expect_identical(published_metadata$display_unit, "percent")
  testthat::expect_identical(published_metadata$display_multiplier, 100)
  testthat::expect_identical(
    published_metadata$metadata_source,
    "method_metadata"
  )
  testthat::expect_identical(
    stored[[1L]] / published_metadata$display_multiplier,
    0.125
  )
})

testthat::test_that("generated index XLSX publishes storage and display bases", {
  testthat::skip_if_not_installed("openxlsx")
  export <- load_download_export_functions()
  contracts <- method_contract(
    "WIOD16", "price.r.id", "index", 100
  )
  contracts$display_unit <- "index_point"
  contracts$index_base_year <- "2000"
  contracts$index_storage_base <- 1
  file <- tempfile(fileext = ".xlsx")
  export$save_my_xlsx(
    file_name = file,
    header = matrix(c("Indicator:", "Price"), nrow = 1L),
    row_names = "Price",
    my_data = matrix(1, nrow = 1L, dimnames = list(NULL, "2000")),
    metadata = data.frame(Code = "price.r.id"),
    specs = data.frame(code = "WIOD16"),
    rows_style_list = list(7L),
    styles_list = list("#,##0.00"),
    width_c1 = 20,
    width_c2 = 10,
    method_code = "WIOD16",
    indicator_codes = "price.r.id",
    display_contracts = contracts
  )

  stored <- openxlsx::read.xlsx(
    file, sheet = "data", rows = 7L, cols = 3L, colNames = FALSE
  )
  published_metadata <- openxlsx::read.xlsx(file, sheet = "metadata")
  testthat::expect_identical(stored[[1L]], 100)
  testthat::expect_identical(published_metadata$canonical_unit, "index")
  testthat::expect_identical(published_metadata$display_unit, "index_point")
  testthat::expect_identical(published_metadata$display_multiplier, 100)
  testthat::expect_identical(published_metadata$index_base_year, "2000")
  testthat::expect_identical(published_metadata$index_storage_base, 1)
  testthat::expect_identical(
    stored[[1L]] / published_metadata$display_multiplier,
    published_metadata$index_storage_base
  )
})

testthat::test_that("generated legacy XLSX retains fraction and percent numFmt", {
  testthat::skip_if_not_installed("openxlsx")
  export <- load_download_export_functions()
  legacy_metadata <- data.frame(
    value = "ratio.r.pc",
    type = "percent",
    stringsAsFactors = FALSE
  )
  contracts <- export$wlv_legacy_display_contract(
    method_dir = "LEGACY",
    method = "LEGACY",
    indicators = "ratio.r.pc",
    legacy_metadata = legacy_metadata,
    warn = FALSE
  )
  file <- tempfile(fileext = ".xlsx")
  export$save_my_xlsx(
    file_name = file,
    header = matrix(c("Indicator:", "Ratio"), nrow = 1L),
    row_names = "Ratio",
    my_data = matrix(0.125, nrow = 1L, dimnames = list(NULL, "2000")),
    metadata = data.frame(Code = "ratio.r.pc"),
    specs = data.frame(code = "LEGACY"),
    rows_style_list = list(7L),
    styles_list = list("PERCENTAGE"),
    width_c1 = 20,
    width_c2 = 10,
    method_code = "LEGACY",
    indicator_codes = "ratio.r.pc",
    display_contracts = contracts,
    legacy_metadata = legacy_metadata
  )

  stored <- openxlsx::read.xlsx(
    file, sheet = "data", rows = 7L, cols = 3L, colNames = FALSE
  )
  workbook <- openxlsx::loadWorkbook(file)
  style <- xlsx_style_for_cell(workbook, "data", 7L, 3L)
  published_metadata <- openxlsx::read.xlsx(file, sheet = "metadata")

  testthat::expect_identical(stored[[1L]], 0.125)
  testthat::expect_identical(as.numeric(style$numFmt$numFmtId), 10)
  testthat::expect_null(style$numFmt$formatCode)
  testthat::expect_identical(published_metadata$method, "LEGACY")
  testthat::expect_identical(published_metadata$display_multiplier, 1)
  testthat::expect_identical(
    published_metadata$metadata_source,
    "legacy_fallback"
  )
  testthat::expect_identical(published_metadata$legacy_type, "percent")
  testthat::expect_identical(
    stored[[1L]] / published_metadata$display_multiplier,
    0.125
  )
})

testthat::test_that("legacy type overrides a misleading percent suffix", {
  testthat::skip_if_not_installed("openxlsx")
  export <- load_download_export_functions()
  indicator <- "basket_price.r.pc"
  legacy_metadata <- data.frame(
    value = indicator,
    type = "index",
    stringsAsFactors = FALSE
  )
  contracts <- export$wlv_legacy_display_contract(
    method_dir = "LEGACY",
    method = "LEGACY",
    indicators = indicator,
    legacy_metadata = legacy_metadata,
    warn = FALSE
  )
  file <- tempfile(fileext = ".xlsx")
  export$save_my_xlsx(
    file_name = file,
    header = matrix(c("Indicator:", "Basket price"), nrow = 1L),
    row_names = "Basket price",
    my_data = matrix(1, nrow = 1L, dimnames = list(NULL, "2000")),
    metadata = data.frame(Code = indicator),
    specs = data.frame(code = "LEGACY"),
    rows_style_list = list(7L),
    styles_list = list("PERCENTAGE"),
    width_c1 = 20,
    width_c2 = 10,
    method_code = "LEGACY",
    indicator_codes = indicator,
    display_contracts = contracts,
    legacy_metadata = legacy_metadata
  )

  stored <- openxlsx::read.xlsx(
    file, sheet = "data", rows = 7L, cols = 3L, colNames = FALSE
  )
  workbook <- openxlsx::loadWorkbook(file)
  style <- xlsx_style_for_cell(workbook, "data", 7L, 3L)
  published_metadata <- openxlsx::read.xlsx(file, sheet = "metadata")

  testthat::expect_identical(stored[[1L]], 1)
  testthat::expect_identical(style$numFmt$formatCode, "#,##0.00")
  testthat::expect_identical(published_metadata$legacy_type, "index")
  testthat::expect_identical(published_metadata$display_multiplier, 1)
})
