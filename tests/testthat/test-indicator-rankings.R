ranking_env <- new.env(parent = environment())
source(file.path(wlvpanel_test_root, "utils", "indicator_rankings.R"),
  local = ranking_env, encoding = "UTF-8")

wlvpanel_ranking_fixture <- function() {
  data.frame(method = "A", year = c(2001L, 2000L, 2000L, 2000L, 2000L, 2001L, 2001L),
    country = c("BRA", "BRA", "USA", "TWN", "HKG", "USA", "TWN"),
    value = c(-3, 0, 2, 2, -2, NA, -1), unit = "index", stringsAsFactors = FALSE)
}

test_that("historical ranks descend across all countries and retain ties and negatives", {
  result <- ranking_env$wlv_indicator_rankings(wlvpanel_ranking_fixture(), "A")
  first <- result[result$year == 2000L, ]
  expect_identical(first$country, c("TWN", "USA", "BRA", "HKG"))
  expect_identical(first$rank, c(1L, 1L, 3L, 4L))
  expect_identical(first$count, rep(4L, 4L))
  expect_equal(first$value, c(2, 2, 0, -2))
  expect_identical(result$year, c(rep(2000L, 4L), rep(2001L, 2L)))
  # Highlighting Brazil must retain its position in the complete universe.
  brazil <- result[result$country == "BRA", ]
  expect_identical(brazil$rank, c(3L, 2L))
  expect_identical(brazil$count, c(4L, 2L))
})

test_that("unavailable observations neither rank nor interpolate and coverage changes yearly", {
  fixture <- wlvpanel_ranking_fixture()
  invalid <- data.frame(method = "A", year = c(2001, 2001, 2002, NA, Inf, -Inf),
    country = c("HKG", "FRA", "BRA", "ZZZ", "XXX", "YYY"),
    value = c(NaN, Inf, -Inf, 100, 100, 100), unit = "index")
  result <- ranking_env$wlv_indicator_rankings(rbind(fixture, invalid), "A")
  second <- result[result$year == 2001L, ]
  expect_identical(second$country, c("TWN", "BRA"))
  expect_identical(second$rank, c(1L, 2L))
  expect_identical(second$count, c(2L, 2L))
  expect_equal(second$value, c(-1, -3))
  expect_false(any(result$year == 2002L))
  expect_true(all(is.finite(result$year) & is.finite(result$value)))
})

test_that("rankings use one method and preserve its values and units without mutating input", {
  fixture <- wlvpanel_ranking_fixture()
  second_method <- fixture
  second_method$method <- "B"
  second_method$value <- -fixture$value * 100
  second_method$unit <- "percent"
  fixture <- rbind(fixture, second_method)
  original <- fixture
  result <- ranking_env$wlv_indicator_rankings(fixture, "B")
  expect_identical(fixture, original)
  expect_identical(unique(result$method), "B")
  expect_identical(unique(result$unit), "percent")
  expect_identical(result$country[result$year == 2000L], c("HKG", "BRA", "TWN", "USA"))
  expect_identical(result$rank[result$year == 2000L], c(1L, 2L, 3L, 3L))
  expect_equal(result$value[result$year == 2000L], c(200, 0, -200, -200))
  expect_error(ranking_env$wlv_indicator_rankings(fixture, c("A", "B")), "exactly one")
})

test_that("world and residual regions are excluded while countries remain available", {
  fixture <- wlvpanel_ranking_fixture()
  aggregates <- data.frame(method = "A", year = 2000L,
    country = c("ROW", "WWW", "WW", "WA", "WE", "WL", "WM", "WLF"),
    value = 100, unit = "index")
  result <- ranking_env$wlv_indicator_rankings(rbind(fixture, aggregates), "A")
  expect_setequal(unique(result$country), c("BRA", "USA", "TWN", "HKG"))
  expect_identical(result$count[result$year == 2000L], rep(4L, 4L))
  custom <- ranking_env$wlv_indicator_rankings(rbind(fixture, aggregates), "A", excluded = character())
  expect_true(all(aggregates$country %in% custom$country))
})

test_that("duplicate method-year-country rows fail even when one value is missing", {
  fixture <- wlvpanel_ranking_fixture()
  duplicate <- fixture[1L, , drop = FALSE]
  expect_error(ranking_env$wlv_indicator_rankings(rbind(fixture, duplicate), "A"), "Duplicate")
  duplicate$value <- NA_real_
  expect_error(ranking_env$wlv_indicator_rankings(rbind(fixture, duplicate), "A"), "Duplicate")
  # An unselected method never participates in validation or the universe.
  duplicate$method <- "B"
  expect_identical(ranking_env$wlv_indicator_rankings(rbind(fixture, duplicate, duplicate), "A"),
    ranking_env$wlv_indicator_rankings(fixture, "A"))
})

test_that("empty and unavailable selections return a consistent typed schema", {
  fixture <- wlvpanel_ranking_fixture()
  empty <- data.frame(method = character(), year = integer(), country = character(),
    value = numeric(), unit = character(), rank = integer(), count = integer())
  expect_identical(ranking_env$wlv_indicator_rankings(fixture[FALSE, ], "A"), empty)
  expect_identical(ranking_env$wlv_indicator_rankings(fixture, "unknown"), empty)
  expect_identical(ranking_env$wlv_indicator_rankings(fixture, NULL), empty)
  expect_identical(ranking_env$wlv_indicator_rankings(NULL, "A"), empty)
  fixture$value <- NA_real_
  expect_identical(ranking_env$wlv_indicator_rankings(fixture, "A"), empty)
  expect_error(ranking_env$wlv_indicator_rankings(fixture, NA_character_), "exactly one")
  expect_error(ranking_env$wlv_indicator_rankings(fixture, ""), "exactly one")
  expect_error(ranking_env$wlv_indicator_rankings(fixture["country"], "A"), "must contain")
})
