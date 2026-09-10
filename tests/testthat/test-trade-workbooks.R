trade_workbook_env <- new.env(parent = environment())
source(file.path(wlvpanel_test_root, "utils/trade_workbooks.R"), local = trade_workbook_env, encoding = "UTF-8")

trade_workbook_fixture <- function(metric = "transfer", series = FALSE) {
  outgoing <- c(12345678901.125, -4.25, 0, NA_real_)
  incoming <- c(2345678901.125, -6.75, 0, 2)
  data.frame(id = c("CHN", "DEU", "ROW", "USA"), label = c("China", "Alemanha", "Resto do mundo", "Estados Unidos"),
    year = if (series) c(2007L, 2005L, 2006L, 2008L) else rep(2007L, 4L),
    value = switch(metric, exports = outgoing, imports = incoming, outgoing - incoming),
    outgoing = outgoing, incoming = incoming, coverage = c("complete", "complete", "complete", if (metric == "imports") "complete" else "partial"),
    observed = c(2L, 2L, 2L, 1L), expected = rep(2L, 4L), method = "WIOD16", country = "BRA",
    metric = metric, scope = "productive", unit = "value", stringsAsFactors = FALSE)
}

testthat::test_that("trade XLSX payload preserves signs, zero and gaps for every metric", {
  api <- trade_workbook_env
  for (metric in c("transfer", "balance", "exports", "imports")) {
    rows <- trade_workbook_fixture(metric)
    payload <- api$wlv_trade_workbook_payload(rows, selection = list(unit = "value"))
    testthat::expect_equal(unname(payload$values[, 2L]), rows$value)
    testthat::expect_equal(unname(payload$values[, 3L]), rows$outgoing)
    testthat::expect_equal(unname(payload$values[, 4L]), if (metric %in% c("transfer", "balance")) -rows$incoming else rows$incoming)
    testthat::expect_identical(payload$values[3L, 2L], 0)
    testthat::expect_identical(payload$ids, rows$id)
  }
})

testthat::test_that("trade XLSX rejects inconsistent signs and untyped units", {
  api <- trade_workbook_env
  rows <- trade_workbook_fixture(); rows$value[1L] <- -rows$value[1L]
  testthat::expect_error(api$wlv_trade_workbook_payload(rows, selection = list(unit = "value")), "value")
  rows <- trade_workbook_fixture(); rows$import_contribution <- rows$incoming
  testthat::expect_error(api$wlv_trade_workbook_payload(rows, selection = list(unit = "value")), "import_contribution")
  rows <- trade_workbook_fixture(); rows$unit <- "Horas de trabalho abstrato"
  testthat::expect_error(api$wlv_trade_workbook_payload(rows), "selection\\$unit")
  testthat::expect_silent(api$wlv_trade_workbook_payload(rows, selection = list(unit = "value")))
  rows$coverage[4L] <- "complete"
  testthat::expect_error(api$wlv_trade_workbook_payload(rows, selection = list(unit = "value")), "completo")
})

testthat::test_that("trade XLSX series are chronological and context is not duplicated per row", {
  api <- trade_workbook_env
  rows <- trade_workbook_fixture(series = TRUE)
  payload <- api$wlv_trade_workbook_payload(rows, selection = list(unit = "value"),
    context = list(country_label = "Brasil", partner_label = "China"), lang = "en", kind = "series")
  testthat::expect_equal(unname(payload$values[, 1L]), 2005:2008)
  testthat::expect_identical(payload$ids, as.character(2005:2008))
  testthat::expect_equal(ncol(payload$values), 4L)
  testthat::expect_true(any(payload$specs[[2L]] == "China"))
  testthat::expect_identical(colnames(payload$values)[[2L]], "Net value transfer")
  testthat::expect_identical(payload$coverage[[4L]], "Partial")
})

testthat::test_that("trade XLSX uses canonical sheets and writes readable typed values", {
  testthat::skip_if_not_installed("openxlsx")
  api <- trade_workbook_env
  rows <- trade_workbook_fixture()
  file <- tempfile(fileext = ".xlsx")
  on.exit(unlink(file))
  result <- api$wlv_write_trade_xlsx(file, rows, selection = list(unit = "value"),
    context = list(country_label = "Brasil", title = "Transferências de valor"),
    helper_path = file.path(wlvpanel_test_root, "utils/download_workbooks.R"))
  testthat::expect_identical(result$sheets, c("data", "metadata", "specs"))
  values <- openxlsx::read.xlsx(file, "data", rows = 7:10, cols = 1:7,
    colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
  testthat::expect_equal(values[[4L]], rows$value)
  testthat::expect_equal(values[[5L]], rows$outgoing)
  testthat::expect_equal(values[[6L]], -rows$incoming)
  testthat::expect_true(is.na(values[[4L]][[4L]]))
  testthat::expect_identical(values[[4L]][[3L]], 0)
  testthat::expect_identical(values[[1L]], rows$label)
  wb <- openxlsx::loadWorkbook(file)
  testthat::expect_match(wb$worksheets[[1L]]$freezePane, 'topLeftCell="C7"', fixed = TRUE)
  testthat::expect_match(wb$worksheets[[1L]]$autoFilter, 'ref="A6:G10"', fixed = TRUE)
  testthat::expect_true(any(vapply(wb$styleObjects, function(object) {
    identical(object$sheet, "data") && 7L %in% object$rows && 4L %in% object$cols &&
      identical(object$style$numFmt$formatCode, "#,##0.00")
  }, logical(1L))))
  metadata <- openxlsx::read.xlsx(file, "metadata", rows = 1:8)
  testthat::expect_true("import_contribution" %in% metadata[[1L]])
  specs <- openxlsx::read.xlsx(file, "specs")
  testthat::expect_true(any(specs[[2L]] == "Horas de trabalho abstrato"))
})

testthat::test_that("workbook provenance uses only public scientific fields", {
  info <- list(version = "trade-v1-example", bilateral_sha256 = paste(rep("a", 64L), collapse = ""),
    detail_root = "D:/private/path", provenance = list(publication_mode = "legacy",
      contract_validation = list(WIOD16 = "legacy_manifested_contract_snapshot"),
      sources = list(WIOD16 = data.frame(source_generation_id = "source-generation", contract_id = "wiodr16_units_v2"))))
  payload <- trade_workbook_env$wlv_trade_workbook_payload(trade_workbook_fixture(), selection = list(unit = "value"), provenance = info)
  testthat::expect_true(any(payload$specs[[2L]] == "source-generation"))
  testthat::expect_true(any(payload$specs[[2L]] == "trade-v1-example"))
  testthat::expect_false(any(grepl("private", unlist(payload$specs), fixed = TRUE)))
})

testthat::test_that("series XLSX follows the canonical horizontal year layout", {
  testthat::skip_if_not_installed("openxlsx")
  rows <- trade_workbook_fixture(series = TRUE)
  file <- tempfile(fileext = ".xlsx")
  on.exit(unlink(file))
  trade_workbook_env$wlv_write_trade_xlsx(file, rows, selection = list(unit = "value"),
    kind = "series", lang = "en", helper_path = file.path(wlvpanel_test_root, "utils/download_workbooks.R"))
  years <- openxlsx::read.xlsx(file, "data", rows = 6L, cols = 3:6, colNames = FALSE)
  testthat::expect_equal(as.integer(unlist(years)), 2005:2008)
  values <- openxlsx::read.xlsx(file, "data", rows = 7:9, cols = 1:6,
    colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE)
  testthat::expect_equal(as.numeric(unlist(values[1L, 3:6])), rows$value[order(rows$year)])
  testthat::expect_equal(as.numeric(unlist(values[2L, 3:6])), rows$outgoing[order(rows$year)])
  testthat::expect_equal(as.numeric(unlist(values[3L, 3:6])), -rows$incoming[order(rows$year)])
  coverage <- openxlsx::read.xlsx(file, "data", rows = 11L, cols = 3:6, colNames = FALSE)
  testthat::expect_identical(as.character(unlist(coverage, use.names = FALSE)), c("Complete", "Complete", "Complete", "Partial"))
})
