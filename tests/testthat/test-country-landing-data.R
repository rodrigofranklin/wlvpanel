landing_env <- new.env(parent = environment())
source(file.path(wlvpanel_test_root, "utils", "country_landing_data.R"),
  local = landing_env, encoding = "UTF-8")

wlvpanel_landing_fixture <- function() {
  codes <- c("abstract_labour.empe.m.mv", "labour_force_value.m.mv",
    "surplus_value.empe.r.pc", "empe.s.un", "trade_transfers.s.mv")
  units <- c(rep("abstract_labour_hour_per_person", 2), "ratio", "person",
    "abstract_labour_hour")
  contract <- function(method) data.frame(method_dir = tolower(method),
    method = method, indicator = codes, canonical_unit = units,
    display_unit = replace(units, 3L, "percent"),
    display_multiplier = c(1, 1, 100, 1, 1), index_base_year = NA_character_,
    index_storage_base = NA_real_, metadata_source = "method_metadata",
    legacy_type = NA_character_, stringsAsFactors = FALSE)
  contracts <- rbind(contract("OLDER"), contract("NEWER"))
  countries <- array(NA_real_, c(2L, 3L, 5L, 1L),
    list(c("OLDER", "NEWER"), c("2000", "2001", "2002"), codes, "BRA"))
  for (method in dimnames(countries)[[1L]]) {
    countries[method, , codes[[1L]], "BRA"] <- c(2000, 2100, NA)
    countries[method, , codes[[2L]], "BRA"] <- c(800, 1000, NA)
    countries[method, , codes[[3L]], "BRA"] <- c(1.5, 1.1, NA)
    countries[method, , codes[[4L]], "BRA"] <- c(100, 110, NA)
    countries[method, , codes[[5L]], "BRA"] <- c(-35, 35, NA)
  }
  bilateral <- array(0, c(3L, 2L, 4L, 4L), list(c("2000", "2001", "2002"),
    c("exports_values", "transfers_values"), c("BRA", "AAA", "BBB", "WWW"),
    c("BRA", "AAA", "BBB", "WWW")))
  bilateral[, "exports_values", "BRA", "AAA"] <- 100
  bilateral[, "exports_values", "BRA", "BBB"] <- 50
  bilateral[, "exports_values", "AAA", "BRA"] <- 40
  bilateral[, "exports_values", "BBB", "BRA"] <- 60
  bilateral[, "transfers_values", "BRA", "AAA"] <- c(-20, 45, NA)
  bilateral[, "transfers_values", "BRA", "BBB"] <- c(10, 15, 15)
  bilateral[, "transfers_values", "AAA", "BRA"] <- 20
  bilateral[, "transfers_values", "BBB", "BRA"] <- 5
  # Comércio doméstico e a linha agregada não são parceiros internacionais.
  bilateral[, , "BRA", "BRA"] <- 1e7
  bilateral[, , "BRA", "WWW"] <- 2e7
  bilateral[, , "WWW", "BRA"] <- 3e7
  list(countries = countries, contracts = contracts, country = "BRA",
    methods = c("OLDER", "NEWER"), bilateral = list(OLDER = bilateral, NEWER = bilateral))
}

test_that("country entry computes coherent annual labour and percentage units", {
  fixture <- wlvpanel_landing_fixture()
  result <- do.call(landing_env$wlv_country_landing_data, fixture)
  expect_identical(result$method, "OLDER")
  expect_identical(result$labour_unit, "abstract_labour_hour_per_person")
  expect_equal(result$labour$workday, c(2000, 2100, NA))
  expect_equal(result$labour$labour_power, c(800, 1000, NA))
  expect_equal(result$labour$surplus, c(1200, 1100, NA))
  expect_equal(result$labour$exploitation, c(150, 110, NA))
  expect_equal(result$labour$employees, c(100, 110, NA))
  expect_identical(result$latest_labour$year, 2001L)
  # Presentation multipliers never change the declared canonical hours.
  fixture$contracts$display_multiplier[fixture$contracts$indicator ==
    "labour_force_value.m.mv"] <- 0.001
  scaled <- do.call(landing_env$wlv_country_landing_data, fixture)
  expect_equal(scaled$labour, result$labour)
})

test_that("country trade includes both goods and money with the requested signs", {
  result <- do.call(landing_env$wlv_country_landing_data, wlvpanel_landing_fixture())
  trade <- result$trade
  expect_identical(result$trade_unit, "abstract_labour_hour")
  expect_equal(trade$exports_hours, rep(150, 3))
  expect_equal(trade$imports_hours, rep(100, 3))
  expect_equal(trade$export_money_hours, c(140, 210, NA))
  expect_equal(trade$import_money_hours, rep(125, 3))
  expect_equal(trade$sent, rep(275, 3))
  expect_equal(trade$received, c(240, 310, NA))
  expect_equal(trade$net, c(-35, 35, NA))
  expect_identical(result$latest_trade$year, 2001L)
  expect_identical(result$provenance$trade_sign, "received_minus_sent")
})

test_that("country entry chooses one complete method and preserves missing years", {
  fixture <- wlvpanel_landing_fixture()
  fixture$bilateral$OLDER <- NULL
  result <- do.call(landing_env$wlv_country_landing_data, fixture)
  expect_identical(result$method, "NEWER")
  fixture <- wlvpanel_landing_fixture()
  fixture$countries["OLDER", "2001", , ] <- NA
  fixture$bilateral$OLDER["2001", , , ] <- NA
  result <- do.call(landing_env$wlv_country_landing_data, fixture)
  expect_identical(result$method, "NEWER")
  fixture$methods <- "OLDER"
  result <- do.call(landing_env$wlv_country_landing_data, fixture)
  expect_identical(result$method, "OLDER")
  expect_identical(result$latest_labour$year, 2000L)
  expect_true(all(is.na(result$labour$workday[result$labour$year > 2000])))
  expect_true(all(is.na(result$trade$net[result$trade$year > 2000])))
})

test_that("partial bilateral observations never become complete national totals", {
  fixture <- wlvpanel_landing_fixture()
  fixture$methods <- "OLDER"
  fixture$bilateral$OLDER["2000", "exports_values", "BRA", "BBB"] <- NA
  result <- do.call(landing_env$wlv_country_landing_data, fixture)
  expect_true(is.na(result$trade$exports_hours[[1L]]))
  expect_true(is.na(result$trade$export_money_hours[[1L]]))
  expect_true(is.na(result$trade$sent[[1L]]))
  expect_true(is.na(result$trade$net[[1L]]))
  fixture$bilateral <- NULL
  result <- do.call(landing_env$wlv_country_landing_data, fixture)
  expect_equal(nrow(result$trade), 0L)
  expect_null(result$latest_trade)
  expect_false(is.null(result$latest_labour))
  fixture$methods <- character()
  result <- do.call(landing_env$wlv_country_landing_data, fixture)
  expect_true(is.na(result$method))
  expect_null(result$latest_labour)
})

test_that("country entry rejects incompatible units, methods and source balances", {
  fixture <- wlvpanel_landing_fixture()
  fixture$contracts$canonical_unit[[1L]] <- "hour"
  expect_error(do.call(landing_env$wlv_country_landing_data, fixture), "Unidade")
  fixture <- wlvpanel_landing_fixture()
  attr(fixture$bilateral$OLDER, "method") <- "NEWER"
  expect_error(do.call(landing_env$wlv_country_landing_data, fixture), "Base bilateral")
  fixture <- wlvpanel_landing_fixture()
  fixture$countries["OLDER", "2000", "trade_transfers.s.mv", ] <- 35
  expect_error(do.call(landing_env$wlv_country_landing_data, fixture), "transferências líquidas")
  fixture <- wlvpanel_landing_fixture()
  fixture$countries["OLDER", "2000", "surplus_value.empe.r.pc", ] <- 150
  expect_error(do.call(landing_env$wlv_country_landing_data, fixture), "taxa de exploração")
})

test_that("country entry supports lazy bilateral loading and singleton axes", {
  fixture <- wlvpanel_landing_fixture()
  values <- fixture$bilateral
  loaded <- character()
  fixture$bilateral <- function(method) { loaded <<- c(loaded, method); values[[method]] }
  fixture$methods <- "NEWER"
  fixture$countries <- fixture$countries["NEWER", "2000", , , drop = FALSE]
  values$NEWER <- values$NEWER["2000", , , , drop = FALSE]
  result <- do.call(landing_env$wlv_country_landing_data, fixture)
  expect_identical(loaded, "NEWER")
  expect_identical(result$latest_labour$year, 2000L)
  expect_identical(result$latest_trade$year, 2000L)
  expect_equal(result$latest_trade$net, -35)
})
