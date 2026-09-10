source(file.path(wlvpanel_test_root, "utils/trade_prepare.R"), encoding = "UTF-8")

testthat::test_that("partial FST reduction includes final demand and preserves missingness", {
  testthat::skip_if_not_installed("fst")
  years <- c("2000", "2001")
  inputs <- c("AAA.a", "AAA.b", "BBB.a", "BBB.b")
  outputs <- c(inputs, "AAA.CONS", "BBB.CONS")
  values <- array(seq_len(2 * 4 * 6), c(2, 4, 6), list(years, inputs, outputs))
  path <- tempfile("trade-prepare-", fileext = ".fst")
  on.exit(unlink(c(path, paste0(path, ".meta"))))
  fst::write_fst(data.frame(value = as.vector(values)), path)
  saveRDS(c(list(dim = dim(values)), dimnames(values)), paste0(path, ".meta"))
  meta <- wlv_trade_prepare_meta(path, 3L)
  reduced <- wlv_trade_prepare_reduce(path, meta, c("AAA", "BBB"), chunk_columns = 2L)$exports_usd
  testthat::expect_equal(unname(reduced[, , "AAA"]),
    unname(apply(values[, , c(1, 2, 5), drop = FALSE], c(1, 2), sum)))
  testthat::expect_equal(unname(reduced[, , "BBB"]),
    unname(apply(values[, , c(3, 4, 6), drop = FALSE], c(1, 2), sum)))
  values[1, 1, 6] <- NA_real_
  fst::write_fst(data.frame(value = as.vector(values)), path)
  missing <- wlv_trade_prepare_reduce(path, meta, c("AAA", "BBB"), chunk_columns = 1L)$exports_usd
  testthat::expect_true(is.na(missing[1, 1, "BBB"]))
})

testthat::test_that("rank-four reduction selects the correct indicator across chunks", {
  testthat::skip_if_not_installed("fst")
  x <- array(seq_len(2 * 3 * 4 * 6), c(2, 3, 4, 6),
    list(c("2000", "2001"), c("unused", "values", "transfers_values"),
      c("AAA.a", "AAA.b", "BBB.a", "BBB.b"),
      c("AAA.a", "AAA.b", "BBB.a", "BBB.b", "AAA.CONS", "BBB.CONS")))
  path <- tempfile("trade-prepare-", fileext = ".fst")
  on.exit(unlink(c(path, paste0(path, ".meta"))))
  fst::write_fst(data.frame(value = as.vector(x)), path)
  saveRDS(c(list(dim = dim(x)), dimnames(x)), paste0(path, ".meta"))
  result <- wlv_trade_prepare_reduce(path, wlv_trade_prepare_meta(path, 4L),
    c("AAA", "BBB"), c("transfers_values", "values"), 2L)
  for (metric in names(result)) {
    expected <- apply(x[, metric, , c(3, 4, 6)], c(1, 2), sum)
    testthat::expect_equal(unname(result[[metric]][, , "BBB"]), unname(expected))
  }
})

testthat::test_that("reconciliation rejects absent data and scale or sign mistakes", {
  testthat::expect_error(wlv_trade_prepare_compare(c(1, NA), c(1, 2), "missing"), "incompleta")
  testthat::expect_error(wlv_trade_prepare_compare(c(1, 2) * 1e6, c(1, 2), "units"), "falhou")
  testthat::expect_error(wlv_trade_prepare_compare(c(-1, -2), c(1, 2), "sign"), "falhou")
  testthat::expect_equal(wlv_trade_prepare_compare(c(1e10, -1e10), c(1e10 + .0001, -1e10), "rounding")$observations, 2L)
})

testthat::test_that("partition direction, domestic exclusion and annual monetary conversion are explicit", {
  axes <- list("2000", c("AAA.a", "AAA.b", "BBB.a", "BBB.b"), c("AAA", "BBB"))
  prices <- array(1:8, c(1, 4, 2), axes)
  reduced <- list(exports_usd = prices, values = prices * 2, transfers_values = prices * -3)
  ref <- array(0, c(1, 2, 2, 2), list("2000", c("exports_productive_mp", "exports_values"), c("AAA", "BBB"), c("AAA", "BBB")))
  ref[, "exports_productive_mp", , ] <- 10
  ref[, "exports_values", , ] <- 5
  part <- wlv_trade_prepare_partition(reduced, "2000", c("AAA", "BBB"),
    data.frame(sector.source = c("a", "b"), productive = c(1, 0)), "EXAMPLE", "v1", ref)
  testthat::expect_equal(nrow(part$data), 4L)
  testthat::expect_true(all(part$data$country != part$data$partner))
  testthat::expect_equal(part$data$exports_usd, c(3, 4, 5, 6))
  testthat::expect_equal(part$data$productive, c(TRUE, FALSE, TRUE, FALSE))
  testthat::expect_equal(part$factor_usd_per_hour, 2)
  testthat::expect_equal(part$data$transfer_usd, part$data$transfer_hours * 2)
  reduced$values[1, 1, 2] <- NA_real_
  testthat::expect_error(wlv_trade_prepare_partition(reduced, "2000", c("AAA", "BBB"),
    data.frame(sector.source = c("a", "b"), productive = c(1, 0)), "EXAMPLE", "v1", ref), "ausentes")
})
