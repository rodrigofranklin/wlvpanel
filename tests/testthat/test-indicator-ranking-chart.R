ranking_chart_env <- new.env(parent = environment())
source(file.path(wlvpanel_test_root, "utils", "indicator_rankings.R"),
  local = ranking_chart_env, encoding = "UTF-8")
source(file.path(wlvpanel_test_root, "utils", "indicator_ranking_chart.R"),
  local = ranking_chart_env, encoding = "UTF-8")

wlvpanel_ranking_chart_fixture <- function() {
  grid <- expand.grid(country = c("BRA", "USA", "TWN", "HKG"),
    year = 2000:2002, stringsAsFactors = FALSE)
  grid$method <- "A"
  grid$value <- c(0, 2, 2, -2, NA, 4, 1, -1, -3, 0, -1, NA)
  grid$unit <- "index"
  ranking_chart_env$wlv_indicator_rankings(grid, "A")
}

wlvpanel_build_ranking_chart <- function(rows = wlvpanel_ranking_chart_fixture(),
    selected = "BRA", lang = "pt", labels = c(BRA = "Brasil", USA = "Estados Unidos", TWN = "Taiwan"),
    countries_input = NULL) {
  chart <- ranking_chart_env$wlv_indicator_ranking_chart(rows, selected, labels,
    indicator = "Participação no comércio", unit_label = "Índice", lang = lang,
    countries_input = countries_input)
  plotly::plotly_build(chart)
}

wlvpanel_ranking_trace <- function(chart, role, country = NULL) {
  matching <- vapply(chart$x$data, function(trace) {
    identical(trace$meta$role, role) && (is.null(country) || identical(trace$meta$country, country))
  }, logical(1L))
  chart$x$data[[which(matching)[[1L]]]]
}

test_that("ranking chart keeps its universe and reverse rank axis when highlights change", {
  skip_if_not_installed("plotly")
  plain <- wlvpanel_build_ranking_chart(selected = character())
  selected <- wlvpanel_build_ranking_chart(selected = c("BRA", "TWN"))
  plain_background <- wlvpanel_ranking_trace(plain, "ranking-background")
  selected_background <- wlvpanel_ranking_trace(selected, "ranking-background")
  expect_identical(plain_background$z, selected_background$z)
  expect_identical(plain_background$x, selected_background$x)
  expect_identical(plain_background$y, selected_background$y)
  expect_equal(plain_background$opacity, 1)
  expect_equal(plain_background$ygap, 0)
  expect_false(plain$x$layout$yaxis$showgrid)
  guides <- plain$x$layout$shapes
  expect_length(guides, length(plain_background$x))
  expect_true(all(vapply(guides, function(guide) {
    identical(guide$type, "line") && guide$x0 == guide$x1 &&
      guide$y0 == 0 && guide$y1 == 1 && identical(guide$yref, "paper") &&
      identical(guide$layer, "above") && identical(guide$line$dash, "dash")
  }, logical(1L))))
  expect_equal(selected_background$opacity, 1)
  expect_gt(selected$x$layout$yaxis$range[[1L]], selected$x$layout$yaxis$range[[2L]])
  expect_identical(selected$x$layout$meta$method, "A")
  expect_identical(selected$x$layout$meta$selected, c("BRA", "TWN"))
  expect_equal(selected$x$layout$meta$countries, 4L)
  expect_identical(selected$x$layout$yaxis$fixedrange, TRUE)
  expect_identical(selected_background$hoverongaps, FALSE)
})

test_that("historical step lines do not bridge missing country observations or absent years", {
  skip_if_not_installed("plotly")
  expect_warning(built <- wlvpanel_build_ranking_chart(), NA)
  line <- wlvpanel_ranking_trace(built, "ranking-selected-line", "BRA")
  expect_identical(line$line$shape, "hvh")
  expect_identical(line$connectgaps, FALSE)
  expect_equal(as.numeric(line$x), c(2000, NA, 2002))
  expect_true(is.na(line$y[[2L]]))
  expect_equal(as.numeric(line$y[c(1L, 3L)]), c(3, 3) - 0.45)
  rows <- wlvpanel_ranking_chart_fixture()
  rows <- rows[rows$year != 2001L, ]
  gap <- wlvpanel_build_ranking_chart(rows, selected = "USA")
  background <- wlvpanel_ranking_trace(gap, "ranking-background")
  expect_equal(as.numeric(background$x), 2000:2002)
  expect_true(all(is.na(background$z[, 2L])))
  gap_line <- wlvpanel_ranking_trace(gap, "ranking-selected-line", "USA")
  expect_true(is.na(gap_line$y[[2L]]))
  expect_identical(gap_line$connectgaps, FALSE)
})

test_that("ranking text and hover payload retain ties, zero and signed values", {
  skip_if_not_installed("plotly")
  built <- wlvpanel_build_ranking_chart(selected = c("BRA", "TWN", "USA"))
  value_trace <- wlvpanel_ranking_trace(built, "ranking-selected-value", "BRA")
  expect_identical(as.character(value_trace$text), c("0", "-3"))
  rank_trace <- wlvpanel_ranking_trace(built, "ranking-selected-rank", "BRA")
  expect_true(all(rank_trace$y < value_trace$y))
  expect_true(all(rank_trace$textposition == "top center"))
  expect_true(all(value_trace$textposition == "bottom center"))
  payload <- built$jsHooks$render[[1L]]$data
  first <- Filter(function(row) row$year == 2000L, payload$rows)
  brazil <- Filter(function(row) row$country == "BRA", first)[[1L]]
  taiwan <- Filter(function(row) row$country == "TWN", first)[[1L]]
  united_states <- Filter(function(row) row$country == "USA", first)[[1L]]
  expect_identical(brazil$value, 0)
  expect_identical(brazil$valueLabel, "0")
  expect_identical(taiwan$rank, 1L)
  expect_identical(united_states$rank, 1L)
  expect_identical(brazil$count, 4L)
  expect_true(all(vapply(payload$rows, function(row) identical(row$method, "A"), logical(1L))))
  expect_identical(payload$unitLabel, "Índice")
  fallback <- Filter(function(row) row$country == "HKG", first)[[1L]]
  expect_identical(fallback$label, "HKG")
})

test_that("htmlwidgets serializes hover rows as objects with scalar identities and raw values", {
  skip_if_not_installed("plotly")
  built <- wlvpanel_build_ranking_chart(selected = "BRA", countries_input = "indicators-countries")
  serialized <- getFromNamespace("toJSON", "htmlwidgets")(built$jsHooks)
  expect_match(serialized, '"rows":[{', fixed = TRUE)
  hooks <- jsonlite::fromJSON(serialized, simplifyVector = FALSE)
  payload <- hooks$render[[1L]]$data
  expect_length(payload$rows, nrow(wlvpanel_ranking_chart_fixture()))
  expect_true(all(vapply(payload$rows, function(row) {
    is.list(row) && is.character(row$country) && length(row$country) == 1L &&
      is.numeric(row$year) && length(row$year) == 1L &&
      is.numeric(row$value) && length(row$value) == 1L &&
      is.numeric(row$rank) && length(row$rank) == 1L
  }, logical(1L))))
  expect_identical(payload$indicator, "Participação no comércio")
  expect_identical(payload$unitLabel, "Índice")
  expect_identical(payload$selected, "BRA")
  expect_identical(payload$countriesInputId, "indicators-countries")
  expect_equal(unlist(payload$years), 2000:2002)
})

test_that("annual cells and hover use the same WLV palette with legible highlighted text", {
  skip_if_not_installed("plotly")
  grid <- expand.grid(country = c("BRA", paste0("C", seq_len(9L))),
    year = 2000:2001, stringsAsFactors = FALSE)
  grid$method <- "A"
  grid$value <- c(10, 0:8, -10, 0:8)
  grid$unit <- "index"
  rows <- ranking_chart_env$wlv_indicator_rankings(grid, "A")
  built <- wlvpanel_build_ranking_chart(rows)
  background <- wlvpanel_ranking_trace(built, "ranking-background")
  payload <- built$jsHooks$render[[1L]]$data
  palette <- c("#8D2028", "#CC858A", "#F2DCDD", "#FCE7C0", "#F6AE2D")
  expect_identical(as.character(payload$palette), palette)
  chart_colors <- unique(vapply(background$colorscale, function(stop) stop[[2L]], character(1L)))
  expect_identical(toupper(chart_colors), palette)
  expect_equal(as.numeric(background$z[cbind(c(1L, 10L), c(1L, 2L))]), c(0.05, 0.95))
  rank_trace <- wlvpanel_ranking_trace(built, "ranking-selected-rank", "BRA")
  value_trace <- wlvpanel_ranking_trace(built, "ranking-selected-value", "BRA")
  rank_colors <- toupper(as.character(rank_trace$textfont$color))
  value_colors <- toupper(as.character(value_trace$textfont$color))
  expect_identical(rank_colors, value_colors)
  expect_length(rank_colors, 2L)
  expect_identical(rank_colors[[1L]], "#FFFFFF")
  expect_false(rank_colors[[2L]] %in% c("#FFFFFF", "WHITE"))
  expect_identical(payload$rows[[1L]]$country, "BRA")
  expect_equal(rows$rank[rows$country == "BRA"], c(1L, 10L))
})

test_that("a singleton country and year still has a cell and usable hover slots", {
  skip_if_not_installed("plotly")
  rows <- ranking_chart_env$wlv_indicator_rankings(data.frame(method = "A", year = 2000L,
    country = "BRA", value = 0, unit = "index"), "A")
  built <- wlvpanel_build_ranking_chart(rows)
  background <- wlvpanel_ranking_trace(built, "ranking-background")
  expect_equal(dim(background$z), c(1L, 1L))
  expect_equal(as.numeric(background$z), 0.5)
  expect_equal(as.numeric(background$x), 2000)
  expect_equal(as.numeric(background$y), 1)
  expect_equal(built$x$layout$xaxis$range, c(1999.5, 2000.5))
  expect_equal(as.numeric(built$x$layout$yaxis$tickvals), 1L)
  for (role in c("line", "rank", "value")) {
    trace <- wlvpanel_ranking_trace(built, paste0("ranking-hover-", role))
    expect_identical(trace$type, "scatter")
    expect_identical(trace$connectgaps, FALSE)
    expect_identical(trace$mode, if (role == "line") "lines" else "text")
    if (role != "line") {
      expect_identical(trace$textposition, if (role == "rank") "top center" else "bottom center")
    }
  }
  serialized <- getFromNamespace("toJSON", "htmlwidgets")(built$jsHooks)
  payload <- jsonlite::fromJSON(serialized, simplifyVector = FALSE)$render[[1L]]$data
  expect_length(payload$rows, 1L)
  expect_identical(payload$rows[[1L]]$country, "BRA")
  expect_equal(payload$rows[[1L]]$value, 0)
})

test_that("ranking labels translate and abbreviate without rounding the source payload", {
  skip_if_not_installed("plotly")
  rows <- ranking_chart_env$wlv_indicator_rankings(data.frame(method = "B", year = c(2000L, 2001L),
    country = "BRA", value = c(1234.56789, -0.12567), unit = "index"), "B")
  portuguese <- wlvpanel_build_ranking_chart(rows)
  english <- wlvpanel_build_ranking_chart(rows, lang = "en")
  pt <- portuguese$jsHooks$render[[1L]]$data$rows
  en <- english$jsHooks$render[[1L]]$data$rows
  expect_identical(pt[[1L]]$valueLabel, "1,235k")
  expect_identical(en[[1L]]$valueLabel, "1.235k")
  expect_identical(pt[[2L]]$valueLabel, "-0,1257")
  expect_identical(en[[2L]]$valueLabel, "-0.1257")
  expect_equal(vapply(pt, `[[`, numeric(1L), "value"), rows$value)
  expect_equal(vapply(en, `[[`, numeric(1L), "value"), rows$value)
  expect_identical(english$x$layout$yaxis$title, "Rank")
  expect_identical(portuguese$x$layout$yaxis$title, "Posição")
})
