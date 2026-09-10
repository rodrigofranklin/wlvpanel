trade_data_environment <- function() {
  root <- if (file.exists("utils/trade_data.R")) "." else "../.."
  env <- new.env(parent = baseenv())
  sys.source(file.path(root, "utils", "trade_data.R"), envir = env)
  env
}

trade_bilateral_fixture <- function() {
  metrics <- c("exports_mp", "exports_productive_mp", "exports_values",
    "transfers_values", "transfers_productive_values", "transfers_dp",
    "transfers_productive_dp")
  value <- array(0, c(3L, length(metrics), 3L, 3L),
    dimnames = list(c("2000", "2001", "2002"), metrics,
      c("A", "B", "ROW"), c("A", "B", "ROW")))
  value["2000", , "A", "B"] <- c(120, 80, 40, -3, 5, -6, 10)
  value["2000", , "B", "A"] <- c(90, 30, 15, -10, -6, -20, -12)
  value["2001", "transfers_values", "A", "B"] <- NA_real_
  value["2001", "transfers_values", "B", "A"] <- 2
  value["2002", , , ] <- NA_real_
  attr(value, "method") <- "TEST"
  value
}

trade_partition_fixture <- function(year = 2000L) {
  data <- expand.grid(country = c("A", "B", "ROW"), partner = c("A", "B", "ROW"),
    sector = c("s1", "s2"), KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  data <- data[data$country != data$partner, , drop = FALSE]
  data$productive <- data$sector == "s1"
  data$exports_usd <- 0; data$embodied_hours <- 0; data$transfer_hours <- 0
  outgoing <- data$country == "A" & data$partner == "B"
  incoming <- data$country == "B" & data$partner == "A"
  data$exports_usd[outgoing] <- c(80, 40); data$exports_usd[incoming] <- c(30, 60)
  data$embodied_hours[outgoing] <- c(40, 0); data$embodied_hours[incoming] <- c(15, 0)
  data$transfer_hours[outgoing] <- c(5, -8); data$transfer_hours[incoming] <- c(-6, -4)
  data$transfer_usd <- data$transfer_hours * 2
  list(schema_version = 1L, version = "fixture-v1", method = "TEST", year = year,
    factor_usd_per_hour = 2, data = data)
}

trade_test_directory <- function() {
  root <- Sys.getenv("WLV_CAMPAIGN_ROOT")
  if (!nzchar(root)) stop("Execute os testes com WLV_CAMPAIGN_ROOT em temp/<id>/.")
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  project <- if (file.exists("utils/trade_data.R")) getwd() else file.path(getwd(), "../..")
  allowed <- paste0(normalizePath(file.path(project, "temp"), winslash = "/", mustWork = TRUE), "/")
  if (!startsWith(tolower(root), tolower(allowed))) stop("Campanha de teste fora de temp/.")
  directory <- tempfile("trade-data-", tmpdir = file.path(root, "scratch"))
  dir.create(directory)
  directory
}

trade_write_store_fixture <- function(years = 2000:2001) {
  directory <- trade_test_directory()
  saveRDS(list(TEST = trade_bilateral_fixture()), file.path(directory, "bilateral.rds"))
  entries <- lapply(years, function(year) {
    file <- paste0(year, ".rds")
    partition <- trade_partition_fixture(year)
    saveRDS(partition, file.path(directory, file))
    data.frame(method = "TEST", year = year, file = file,
      sha256 = digest::digest(file = file.path(directory, file), algo = "sha256", serialize = FALSE),
      rows = nrow(partition$data), stringsAsFactors = FALSE)
  })
  manifest <- list(schema_version = 1L, version = "fixture-v1",
    methods = list(TEST = list(countries = c("A", "B", "ROW"), sectors = c("s1", "s2"),
      years = years, files = setNames(paste0(years, ".rds"), years))),
    partitions = do.call(rbind, entries), provenance = list(origin = "synthetic-test"))
  manifest$bilateral_sha256 <- digest::digest(file = file.path(directory, "bilateral.rds"),
    algo = "sha256", serialize = FALSE)
  saveRDS(manifest, file.path(directory, "manifest.rds"))
  list(directory = directory, bilateral = file.path(directory, "bilateral.rds"), manifest = manifest)
}

testthat::test_that("transfer signs express appropriation and reverse with the focal country", {
  api <- trade_data_environment(); data <- trade_bilateral_fixture()
  a <- api$wlv_trade_snapshot(data, "A", 2000, partner = "B")
  b <- api$wlv_trade_snapshot(data, "B", 2000, partner = "A")
  testthat::expect_equal(a$value, 7)
  testthat::expect_equal(a$outgoing, -3)
  testthat::expect_equal(a$incoming, -10)
  testthat::expect_equal(b$value, -a$value)
  testthat::expect_equal(b$outgoing, a$incoming)
  testthat::expect_equal(api$wlv_trade_snapshot(data, "A", 2000, unit = "usd", partner = "B")$value, 14)
  testthat::expect_identical(a$coverage, "complete")
  testthat::expect_identical(a$id, "B")
})

testthat::test_that("productive and unproductive parts reconcile across all metrics and units", {
  api <- trade_data_environment(); data <- trade_bilateral_fixture()
  for (metric in c("transfer", "exports", "imports", "balance")) {
    for (unit in c("value", "usd")) {
      query <- function(scope) api$wlv_trade_snapshot(data, "A", 2000,
        metric = metric, unit = unit, scope = scope, partner = "B")
      total <- query("total"); productive <- query("productive"); unproductive <- query("unproductive")
      testthat::expect_equal(total$value, productive$value + unproductive$value)
      testthat::expect_equal(total$outgoing, productive$outgoing + unproductive$outgoing)
      testthat::expect_equal(total$incoming, productive$incoming + unproductive$incoming)
    }
  }
  balance <- api$wlv_trade_snapshot(data, "A", 2000, metric = "balance", unit = "usd", partner = "B")
  testthat::expect_equal(balance$value, 30)
  testthat::expect_equal(balance$outgoing, 120)
  testthat::expect_equal(balance$incoming, 90)
  testthat::expect_equal(api$wlv_trade_snapshot(data, "A", 2000,
    metric = "exports", unit = "value", scope = "unproductive", partner = "B")$value, 0)
})

testthat::test_that("zero, unavailable years and partial coverage remain distinct", {
  api <- trade_data_environment(); data <- trade_bilateral_fixture()
  zero <- api$wlv_trade_snapshot(data, "A", 2000, partner = "ROW")
  partial <- api$wlv_trade_snapshot(data, "A", 2001, partner = "B")
  missing <- api$wlv_trade_snapshot(data, "A", 2002, partner = "B")
  testthat::expect_identical(zero$value, 0)
  testthat::expect_identical(zero$coverage, "complete")
  testthat::expect_true(is.na(partial$value))
  testthat::expect_identical(partial$coverage, "partial")
  testthat::expect_equal(partial$incoming, 2)
  testthat::expect_true(is.na(missing$value))
  testthat::expect_identical(missing$coverage, "missing")
  testthat::expect_identical(api$wlv_trade_available_years(data, "A"), 2000:2001)
  series <- api$wlv_trade_series(data, "A")
  testthat::expect_identical(series$year, 2000:2002)
  testthat::expect_equal(series$value, c(7, NA, NA))
  testthat::expect_identical(series$coverage, c("complete", "partial", "missing"))
  incoming <- api$wlv_trade_snapshot(data, "A", 2001, metric = "imports", partner = "B")
  testthat::expect_identical(incoming$coverage, "complete")
})

testthat::test_that("singletons retain axes and domestic/world totals are excluded", {
  api <- trade_data_environment(); data <- trade_bilateral_fixture()
  singleton <- data["2000", , c("A", "B"), c("A", "B"), drop = FALSE]
  testthat::expect_equal(api$wlv_trade_snapshot(singleton, "A", 2000)$value, 7)
  testthat::expect_equal(api$wlv_trade_series(singleton, "A", partner = "B")$value, 7)
  testthat::expect_identical(api$wlv_trade_snapshot(data, "A", 2000)$partner, c("B", "ROW"))
  testthat::expect_error(api$wlv_trade_snapshot(data, "WWW", 2000), "País")
  testthat::expect_error(api$wlv_trade_snapshot(data, "A", 2000, partner = "A"), "Parceiro")
  testthat::expect_equal(nrow(api$wlv_trade_snapshot(data, "A", 1990)), 0)
})

testthat::test_that("sector and partner drilling use the same directional supplier contract", {
  api <- trade_data_environment(); fixture <- trade_write_store_fixture()
  store <- api$wlv_trade_data_store(fixture$bilateral, fixture$directory)
  bilateral <- store$bilateral("TEST"); detail <- store$detail("TEST", 2000)
  for (metric in c("transfer", "exports", "imports", "balance")) {
    for (unit in c("value", "usd")) {
      sectors <- api$wlv_trade_snapshot(bilateral, "A", 2000, metric = metric,
        unit = unit, dimension = "sector", partner = "B", detail = detail)
      partners <- api$wlv_trade_snapshot(bilateral, "A", 2000, metric = metric,
        unit = unit, partner = "B")
      testthat::expect_equal(sum(sectors$value), partners$value)
    }
  }
  sectors <- api$wlv_trade_snapshot(bilateral, "A", 2000, dimension = "sector", partner = "B", detail = detail)
  testthat::expect_equal(sectors$value, c(11, -4))
  partners <- api$wlv_trade_snapshot(bilateral, "A", 2000, sector = "s2", detail = detail)
  testthat::expect_equal(partners$value, c(-4, 0))
  testthat::expect_identical(attr(sectors, "sector_definition"), "supplier")
  testthat::expect_error(api$wlv_trade_snapshot(bilateral, "A", 2000, dimension = "sector"), "indisponível")
  testthat::expect_error(api$wlv_trade_snapshot(bilateral, "A", 2001, dimension = "sector", detail = detail), "não corresponde")
  inapplicable <- api$wlv_trade_snapshot(bilateral, "A", 2000,
    scope = "productive", sector = "s2", detail = detail)
  testthat::expect_equal(nrow(inapplicable), 0L)
  testthat::expect_type(inapplicable$value, "double")
  testthat::expect_identical(attr(inapplicable, "sector_definition"), "supplier")
  detail <- detail[!(detail$country == "A" & detail$partner == "B" & detail$sector == "s2"), ]
  incomplete <- api$wlv_trade_snapshot(bilateral, "A", 2000, dimension = "sector", partner = "B", detail = detail)
  testthat::expect_true(is.na(incomplete$value[incomplete$sector == "s2"]))
  testthat::expect_identical(incomplete$coverage[incomplete$sector == "s2"], "partial")
})

testthat::test_that("stores read nothing before demand and bound their detail cache", {
  api <- trade_data_environment(); fixture <- trade_write_store_fixture()
  paths <- character()
  reader <- function(path) { paths <<- c(paths, path); readRDS(path) }
  store <- api$wlv_trade_data_store(fixture$bilateral, fixture$directory, cache_size = 1L, reader = reader)
  testthat::expect_length(paths, 0L)
  testthat::expect_identical(unname(store$stats()$reads), c(0L, 0L, 0L))
  testthat::expect_null(store$info()$version)
  testthat::expect_identical(store$methods(), "TEST")
  testthat::expect_identical(store$countries("TEST"), c("A", "B", "ROW"))
  testthat::expect_identical(store$years("TEST"), 2000:2001)
  store$bilateral("TEST")
  testthat::expect_length(paths, 1L)
  testthat::expect_identical(store$detail_years("TEST"), 2000:2001)
  store$detail("TEST", 2000); store$detail("TEST", 2000)
  testthat::expect_identical(store$stats()$cache_hits, 1L)
  testthat::expect_identical(store$stats()$reads[["detail"]], 1L)
  store$detail("TEST", 2001)
  testthat::expect_identical(store$stats()$detail_entries, 1L)
  store$detail("TEST", 2000)
  testthat::expect_identical(store$stats()$reads[["detail"]], 3L)
  testthat::expect_null(store$detail("TEST", 1990))
  uncached <- api$wlv_trade_data_store(fixture$bilateral, fixture$directory, max_cache_bytes = 1)
  uncached$detail("TEST", 2000); uncached$detail("TEST", 2000)
  testthat::expect_identical(uncached$stats()$detail_entries, 0L)
  testthat::expect_identical(uncached$stats()$reads[["detail"]], 2L)
})

testthat::test_that("invalid hashes and mismatched identities cannot enter the cache", {
  api <- trade_data_environment(); fixture <- trade_write_store_fixture(2000)
  path <- file.path(fixture$directory, "2000.rds")
  partition <- readRDS(path); partition$year <- 2001L; saveRDS(partition, path)
  store <- api$wlv_trade_data_store(fixture$bilateral, fixture$directory)
  testthat::expect_error(store$detail("TEST", 2000), "Hash")
  fixture$manifest$partitions$sha256 <- digest::digest(file = path, algo = "sha256", serialize = FALSE)
  saveRDS(fixture$manifest, file.path(fixture$directory, "manifest.rds"))
  store <- api$wlv_trade_data_store(fixture$bilateral, fixture$directory)
  testthat::expect_error(store$detail("TEST", 2000), "Identidade")
  testthat::expect_identical(store$stats()$detail_entries, 0L)
  partition$year <- 2000L; partition$version <- "other-generation"
  testthat::expect_error(api$wlv_trade_validate_partition(partition,
    fixture$manifest, fixture$manifest$partitions), "Identidade")
  partition$version <- "fixture-v1"; partition$schema_version <- 2L
  testthat::expect_error(api$wlv_trade_validate_partition(partition,
    fixture$manifest, fixture$manifest$partitions), "Identidade")
})

testthat::test_that("incomplete grids, inconsistent conversions and paths are rejected", {
  api <- trade_data_environment(); fixture <- trade_write_store_fixture(2000)
  partition <- trade_partition_fixture(); entry <- fixture$manifest$partitions
  partition$data <- partition$data[-1L, ]; entry$rows <- nrow(partition$data)
  testthat::expect_error(api$wlv_trade_validate_partition(partition, fixture$manifest, entry), "Grade")
  partition <- trade_partition_fixture(); partition$data$transfer_usd[[1L]] <- 99
  testthat::expect_error(api$wlv_trade_validate_partition(partition, fixture$manifest,
    fixture$manifest$partitions), "Conversão")
  fixture$manifest$partitions$file <- "../outside.rds"
  saveRDS(fixture$manifest, file.path(fixture$directory, "manifest.rds"))
  store <- api$wlv_trade_data_store(fixture$bilateral, fixture$directory)
  testthat::expect_error(store$detail("TEST", 2000), "fora do diretório")
  fixture$manifest$schema_version <- 2L
  testthat::expect_error(api$wlv_trade_validate_manifest(fixture$manifest), "Manifesto")
})

testthat::test_that("detail generations must match the pinned bilateral snapshot", {
  api <- trade_data_environment(); fixture <- trade_write_store_fixture(2000)
  store <- api$wlv_trade_data_store(fixture$bilateral, fixture$directory)
  store$bilateral("TEST")
  replacement <- trade_bilateral_fixture()
  replacement["2000", "transfers_values", "A", "B"] <- 123
  saveRDS(list(TEST = replacement), fixture$bilateral)
  fixture$manifest$bilateral_sha256 <- digest::digest(file = fixture$bilateral,
    algo = "sha256", serialize = FALSE)
  saveRDS(fixture$manifest, file.path(fixture$directory, "manifest.rds"))
  testthat::expect_error(store$detail("TEST", 2000), "outro catálogo bilateral")
  testthat::expect_identical(store$stats()$reads[["detail"]], 0L)
  fixture$manifest$bilateral_sha256 <- paste(rep("0", 64L), collapse = "")
  saveRDS(fixture$manifest, file.path(fixture$directory, "manifest.rds"))
  fresh <- api$wlv_trade_data_store(fixture$bilateral, fixture$directory)
  testthat::expect_error(fresh$detail("TEST", 2000), "outro catálogo bilateral")
})

testthat::test_that("current small bilateral data preserve coverage and bilateral identities", {
  api <- trade_data_environment()
  root <- if (file.exists("data/m_countries.RDS")) "." else "../.."
  path <- file.path(root, "data", "m_countries.RDS")
  testthat::skip_if_not(file.exists(path))
  store <- api$wlv_trade_data_store(path)
  expected <- list(WIOD13 = 1995:2007, WIOD16 = 2000:2014)
  for (method in intersect(names(expected), store$methods())) {
    testthat::expect_identical(store$years(method), expected[[method]])
    data <- store$bilateral(method)
    a <- api$wlv_trade_snapshot(data, "BRA", 2007, partner = "CHN")
    b <- api$wlv_trade_snapshot(data, "CHN", 2007, partner = "BRA")
    testthat::expect_equal(a$value, -b$value)
    testthat::expect_identical(a$coverage, "complete")
    for (scope in c("total", "productive", "unproductive")) {
      focal <- api$wlv_trade_snapshot(data, "BRA", 2007, scope = scope)
      testthat::expect_equal(sum(focal$value),
        api$wlv_trade_series(data, "BRA", scope = scope, years = 2007)$value)
    }
  }
})
