trade_map_environment <- function() {
  root <- if (file.exists("utils/trade_map.R")) "." else "../.."
  env <- new.env(parent = baseenv())
  sys.source(file.path(root, "utils/trade_map.R"), envir = env)
  env
}

trade_map_fixture <- function() {
  list(values = data.frame(id = c("A", "B", "C", "ROW", "WWW", "D", "E", "F"),
    value = c(10, 100, -25, 9999, 9999, 0, NA_real_, Inf), coverage = "complete"),
    centroids = data.frame(id = c("A", "B", "C", "D", "E", "F"),
      lng = c(-40, 120, -100, 0, 10, 20), lat = c(-10, 30, 40, 0, 10, 20)))
}

testthat::test_that("arrow direction denotes net value received by the focal country", {
  api <- trade_map_environment(); fixture <- trade_map_fixture()
  arrows <- api$wlv_trade_map_flows(fixture$values, "A", fixture$centroids)
  testthat::expect_identical(arrows$id, c("B", "C"))
  testthat::expect_identical(arrows$from, c("B", "A"))
  testthat::expect_identical(arrows$to, c("A", "C"))
  testthat::expect_equal(arrows$from_lng, c(120, -40))
  testthat::expect_equal(arrows$to_lat, c(-10, 40))
  testthat::expect_equal(arrows$value, c(100, -25))
  testthat::expect_equal(arrows$amount, c(100, 25))
  testthat::expect_equal(arrows$width, c(14, 3.5))
  testthat::expect_identical(attr(arrows, "width_scaling"), "linear_absolute_value")
  reverse <- api$wlv_trade_map_flows(data.frame(id = "A", value = -100), "B", fixture$centroids)
  testthat::expect_identical(reverse$from, "B")
  testthat::expect_identical(reverse$to, "A")
})

testthat::test_that("selected partner and displayed limit preserve exact amounts", {
  api <- trade_map_environment(); fixture <- trade_map_fixture()
  selected <- api$wlv_trade_map_flows(fixture$values, "A", fixture$centroids, partner = "C")
  testthat::expect_identical(selected$id, "C")
  testthat::expect_equal(selected$value, -25)
  testthat::expect_equal(selected$width, 14)
  testthat::expect_identical(attr(selected, "eligible"), 1L)
  testthat::expect_identical(attr(selected, "omitted"), 0L)
  limited <- api$wlv_trade_map_flows(fixture$values, "A", fixture$centroids, limit = 1L)
  testthat::expect_identical(limited$id, "B")
  testthat::expect_equal(limited$value, 100)
  testthat::expect_identical(attr(limited, "eligible"), 2L)
  testthat::expect_identical(attr(limited, "omitted"), 1L)
  testthat::expect_equal(attr(limited, "max_amount"), 100)
})

testthat::test_that("unknown geometry and partial observations never become arrows", {
  api <- trade_map_environment(); fixture <- trade_map_fixture()
  fixture$values$coverage[fixture$values$id == "B"] <- "partial"
  fixture$centroids <- fixture$centroids[fixture$centroids$id != "C", ]
  arrows <- api$wlv_trade_map_flows(fixture$values, "A", fixture$centroids)
  testthat::expect_equal(nrow(arrows), 0L)
  testthat::expect_identical(attr(arrows, "unmapped"), 1L)
  testthat::expect_equal(nrow(api$wlv_trade_map_flows(fixture$values, "ROW", fixture$centroids)), 0L)
  fixture$centroids$lng[[1L]] <- NA_real_
  testthat::expect_equal(nrow(api$wlv_trade_map_flows(fixture$values, "A", fixture$centroids)), 0L)
})

testthat::test_that("top twelve sorting is stable and widths have no artificial floor", {
  api <- trade_map_environment()
  centroids <- data.frame(id = c("A", paste0("P", seq_len(15L))),
    lng = seq_len(16L), lat = seq_len(16L))
  values <- data.frame(id = centroids$id[-1L], value = c(1e8, 1, 2:14))
  arrows <- api$wlv_trade_map_flows(values, "A", centroids)
  testthat::expect_equal(nrow(arrows), 12L)
  testthat::expect_identical(attr(arrows, "omitted"), 3L)
  testthat::expect_true(all(diff(arrows$amount) <= 0))
  testthat::expect_equal(arrows$width / arrows$amount, rep(14 / 1e8, 12L))
  testthat::expect_true(min(arrows$width) < 0.001)
  tied <- api$wlv_trade_map_flows(data.frame(id = c("P2", "P1"), value = c(-1, 1)), "A", centroids)
  testthat::expect_identical(tied$id, c("P1", "P2"))
})

testthat::test_that("invalid geometry and duplicate bilateral partners are rejected", {
  api <- trade_map_environment(); fixture <- trade_map_fixture()
  duplicate <- rbind(fixture$values, fixture$values[1L, ])
  testthat::expect_error(api$wlv_trade_map_flows(duplicate, "A", fixture$centroids), "linha")
  invalid <- fixture$centroids; invalid$lng[[1L]] <- 181
  testthat::expect_error(api$wlv_trade_map_flows(fixture$values, "A", invalid), "WGS84")
  testthat::expect_error(api$wlv_trade_map_flows(fixture$values, "A", fixture$centroids, limit = 0), "Limite")
})
