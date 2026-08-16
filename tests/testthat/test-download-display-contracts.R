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
    "wlv_prepare_xlsx_display",
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

method_contract <- function(method, indicators, units, multipliers, types) {
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
    legacy_type = types,
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

  testthat::expect_identical(stored[[1L]], 12.5)
  testthat::expect_identical(
    style$numFmt$formatCode,
    "0.00&quot;%&quot;"
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

  testthat::expect_identical(stored[[1L]], 0.125)
  testthat::expect_identical(as.numeric(style$numFmt$numFmtId), 10)
  testthat::expect_null(style$numFmt$formatCode)
})
