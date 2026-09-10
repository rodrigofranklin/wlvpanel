country_landing_chart_env <- new.env(parent = environment())
source(file.path(wlvpanel_test_root, "utils", "country_landing_charts.R"),
  local = country_landing_chart_env, encoding = "UTF-8")

test_that("profile extraction and chart preparation coexist in the landing source order", {
  skip_if_not_installed("htmltools")
  combined <- new.env(parent = environment())
  source(file.path(wlvpanel_test_root, "utils", "country_landing_data.R"),
    local = combined, encoding = "UTF-8")
  source(file.path(wlvpanel_test_root, "utils", "country_landing_charts.R"),
    local = combined, encoding = "UTF-8")
  countries <- array(NA_real_, c(1L, 1L, 1L, 1L),
    list("A", "2000", "unused", "BRA"))
  profile <- combined$wlv_country_landing_data(countries, data.frame(), "BRA", character())
  expect_identical(profile$country, "BRA")
  expect_null(profile$latest_labour)
  chart <- as.character(combined$wlv_country_landing_chart(2000, 0, 0))
  expect_match(chart, "<svg", fixed = TRUE)
})

test_that("two-observation curves retain their exact linear crossing", {
  rows <- country_landing_chart_env$wlv_country_landing_chart_rows(c(2000, 2001), c(10, 4), c(2, 8))
  segments <- country_landing_chart_env$wlv_country_landing_segments(rows)
  expect_length(segments, 2L)
  expect_equal(segments[[1L]]$year, c(2000, 2000 + 2 / 3))
  expect_equal(segments[[2L]]$year, c(2000 + 2 / 3, 2001))
  expect_equal(segments[[1L]]$first[[2L]], 6)
  expect_equal(segments[[1L]]$second[[2L]], 6)
  expect_equal(segments[[2L]]$first[[1L]], 6)
  expect_equal(segments[[2L]]$second[[1L]], 6)
  expect_identical(vapply(segments, `[[`, character(1L), "direction"), c("sent", "received"))
  # The areas on the two sides of the intersection have opposite signs.
  expect_gt(diff(segments[[1L]]$year) * mean(segments[[1L]]$first - segments[[1L]]$second), 0)
  expect_lt(diff(segments[[2L]]$year) * mean(segments[[2L]]$first - segments[[2L]]$second), 0)
})

test_that("smooth curves interpolate source observations without overshooting", {
  rows <- country_landing_chart_env$wlv_country_landing_chart_rows(
    2000:2004, c(0, 5, 5, -2, 8), c(4, 2, 0, 3, 6))
  curves <- country_landing_chart_env$wlv_country_landing_curves(rows)
  value <- country_landing_chart_env$wlv_country_landing_curve_value
  derivative <- country_landing_chart_env$wlv_country_landing_curve_derivative
  for (key in c("first", "second")) {
    for (i in seq_along(curves[[key]])) {
      curve <- curves[[key]][[i]]
      bounds <- rows[[key]][c(i, i + 1L)]
      expect_equal(value(curve, c(0, 1)), bounds)
      smooth <- value(curve, seq(0, 1, length.out = 101))
      expect_true(all(smooth >= min(bounds) - 1e-10 & smooth <= max(bounds) + 1e-10))
      if (i > 1L) expect_equal(derivative(curves[[key]][[i - 1L]], 1), derivative(curve, 0))
    }
  }
})

test_that("gap colors split at the curved crossing rather than the straight-line crossing", {
  rows <- country_landing_chart_env$wlv_country_landing_chart_rows(
    2000:2002, c(8, 2, 6), c(1, 4, 2))
  segments <- country_landing_chart_env$wlv_country_landing_segments(rows)
  value <- country_landing_chart_env$wlv_country_landing_curve_value
  expect_length(segments, 4L)
  expect_gt(abs(segments[[1L]]$fraction[[2L]] - 7 / 9), 0.1)
  expect_equal(segments[[1L]]$first[[2L]], segments[[1L]]$second[[2L]])
  for (segment in segments) {
    at <- seq(segment$fraction[[1L]], segment$fraction[[2L]], length.out = 21)
    gap <- value(segment$first_curve, at) - value(segment$second_curve, at)
    expect_true(if (segment$direction == "sent") all(gap >= -1e-10) else all(gap <= 1e-10))
  }
  expect_identical(vapply(segments, `[[`, character(1L), "direction"),
    c("sent", "received", "received", "sent"))
})

test_that("cubic intervals split all crossings even when endpoint signs match", {
  rows <- country_landing_chart_env$wlv_country_landing_chart_rows(2000:2001, c(0.16, 0.16), c(0, 0))
  # Difference (t - .2)(t - .8) crosses twice with positive endpoints.
  curves <- list(first = list(c(0.16, -1, 1, 0)), second = list(c(0, 0, 0, 0)))
  segments <- country_landing_chart_env$wlv_country_landing_segments(rows, curves)
  expect_length(segments, 3L)
  expect_equal(segments[[1L]]$fraction, c(0, 0.2))
  expect_equal(segments[[2L]]$fraction, c(0.2, 0.8))
  expect_equal(segments[[3L]]$fraction, c(0.8, 1))
  expect_identical(vapply(segments, `[[`, character(1L), "direction"), c("sent", "received", "sent"))
})

test_that("missing observations and omitted calendar years interrupt the gap", {
  rows <- country_landing_chart_env$wlv_country_landing_chart_rows(
    c(2000, 2001, 2002, 2004, 2005), c(8, 9, NA, 7, 8), c(4, 3, 2, 3, 4))
  expect_equal(rows$year, 2000:2005)
  expect_true(is.na(rows$first[rows$year == 2003]))
  expect_true(is.na(rows$second[rows$year == 2003]))
  segments <- country_landing_chart_env$wlv_country_landing_segments(rows)
  expect_length(segments, 2L)
  expect_equal(segments[[1L]]$year, c(2000, 2001))
  expect_equal(segments[[2L]]$year, c(2004, 2005))
})

test_that("charts trim wholly missing ends and preserve internal annual gaps", {
  rows <- country_landing_chart_env$wlv_country_landing_chart_rows(
    2000:2006, c(NA, NA, 0, NA, 2, NA, NA), c(NA, NA, 1, NA, 1, NA, NA))
  expect_equal(rows$year, 2002:2004)
  expect_equal(rows$first, c(0, NA, 2))
  expect_equal(rows$second, c(1, NA, 1))
  expect_length(country_landing_chart_env$wlv_country_landing_segments(rows), 0L)
  # An endpoint available in only one series still belongs on the axis.
  partial <- country_landing_chart_env$wlv_country_landing_chart_rows(
    2000:2004, c(NA, 0, NA, NA, NA), c(NA, NA, NA, 1, NA))
  expect_equal(partial$year, 2001:2003)
  expect_equal(partial$first, c(0, NA, NA))
  expect_equal(partial$second, c(NA, NA, 1))
  skip_if_not_installed("htmltools")
  html <- as.character(country_landing_chart_env$wlv_country_landing_chart(
    2000:2006, c(NA, NA, 0, NA, 2, NA, NA), c(NA, NA, 1, NA, 1, NA, NA)))
  expect_match(html, 'data-year="2002"', fixed = TRUE)
  expect_match(html, 'data-year="2004"', fixed = TRUE)
  expect_false(grepl('data-year="2000"', html, fixed = TRUE))
  expect_false(grepl('data-year="2006"', html, fixed = TRUE))
})

test_that("zeros, ties and signs are preserved without imaginary shaded intervals", {
  rows <- country_landing_chart_env$wlv_country_landing_chart_rows(2000:2003, c(0, 0, -2, 0), c(0, 0, 1, 0))
  expect_equal(rows$first, c(0, 0, -2, 0))
  segments <- country_landing_chart_env$wlv_country_landing_segments(rows)
  expect_length(segments, 2L)
  expect_identical(vapply(segments, `[[`, character(1L), "direction"), c("received", "received"))
  expect_equal(segments[[1L]]$year, c(2001, 2002))
  equal <- country_landing_chart_env$wlv_country_landing_chart_rows(2000:2001, c(0, 0), c(0, 0))
  expect_length(country_landing_chart_env$wlv_country_landing_segments(equal), 0L)
})

test_that("localized numbers preserve exact zeros and distinguish unavailable values", {
  number <- country_landing_chart_env$wlv_country_landing_number
  expect_identical(number(1234.56), "1.234,56")
  expect_identical(number(-1234.56, "English"), "-1,234.56")
  expect_identical(number(0), "0")
  expect_identical(number(-0.001), "0")
  expect_identical(number(NA_real_), "Indisponível")
  expect_identical(number(Inf, "en"), "Unavailable")
})

test_that("trade SVG uses brand lines, solid directional areas and original annual values", {
  skip_if_not_installed("htmltools")
  chart <- country_landing_chart_env$wlv_country_landing_chart(2000:2001,
    c(10, 4), c(2, 8), kind = "trade", id = "same")
  html <- as.character(chart)
  expect_match(html, "viewBox=\"0 0 500 230\"", fixed = TRUE)
  expect_match(html, "wlv-country-chart-gap-sent", fixed = TRUE)
  expect_match(html, "wlv-country-chart-gap-received", fixed = TRUE)
  expect_match(html, 'stroke="#8D2028"', fixed = TRUE)
  expect_match(html, 'stroke="#F6AE2D"', fixed = TRUE)
  expect_match(html, 'fill="#F2DCDD"', fixed = TRUE)
  expect_match(html, 'fill="#FCE7C0"', fixed = TRUE)
  expect_false(grepl("<pattern", html, fixed = TRUE))
  expect_false(grepl("<circle", html, fixed = TRUE))
  expect_false(grepl("hachura", html, fixed = TRUE))
  expect_match(html, "Envio líquido: 8", fixed = TRUE)
  expect_match(html, "Recebimento líquido: 4", fixed = TRUE)
  expect_match(html, "tabindex=\"0\"", fixed = TRUE)
  next_html <- as.character(country_landing_chart_env$wlv_country_landing_chart(
    2000:2001, c(10, 4), c(2, 8), kind = "trade", id = "same"))
  title_id <- function(value) regmatches(value, regexpr("wlv-country-chart-same-[0-9]+-title", value))
  expect_false(identical(title_id(html), title_id(next_html)))
  line_paths <- regmatches(html, gregexpr('<path[^>]+data-series="[^"]+"[^>]*>', html))[[1L]]
  expect_true(all(grepl(" C ", line_paths, fixed = TRUE)))
  expect_false(any(grepl("stroke-dasharray", line_paths, fixed = TRUE)))
  gap_paths <- regmatches(html, gregexpr('<path[^>]+class="wlv-country-chart-gap [^"]+"[^>]*>', html))[[1L]]
  expect_length(gap_paths, 2L)
  expect_true(all(grepl(" C .* L .* C .* Z", gap_paths)))
})

test_that("labour uses both area signs and a single solid surplus legend", {
  skip_if_not_installed("htmltools")
  html <- as.character(country_landing_chart_env$wlv_country_landing_chart(
    2000:2002, c(8, 2, 6), c(1, 4, 2), kind = "labour"))
  expect_match(html, 'fill="#F2DCDD"', fixed = TRUE)
  expect_match(html, 'fill="#FCE7C0"', fixed = TRUE)
  expect_match(html, "Mais-valor: -2", fixed = TRUE)
  expect_match(html, "Jornada de trabalho: 2", fixed = TRUE)
  expect_false(grepl("hachura", html, fixed = TRUE))
  expect_false(grepl("repeating-linear-gradient", html, fixed = TRUE))
  legend_items <- regmatches(html, gregexpr('class="wlv-country-chart-legend-item"', html, fixed = TRUE))[[1L]]
  expect_length(legend_items, 3L)
  expect_match(html, "width:11px;height:11px;background:#F2DCDD", fixed = TRUE)
})

test_that("SVG lines restart after a gap and retain isolated zero observations", {
  skip_if_not_installed("htmltools")
  html <- as.character(country_landing_chart_env$wlv_country_landing_chart(
    2000:2002, c(0, NA, 2), c(0, 1, 1), kind = "labour"))
  paths <- regmatches(html, gregexpr("<path[^>]+data-series=\"first\"[^>]*>", html))[[1L]]
  expect_length(paths, 1L)
  expect_match(paths, "d=\"M [^\"]+ M [^\"]+\"")
  expect_false(grepl(" L ", paths, fixed = TRUE))
  expect_match(html, "Jornada de trabalho: 0", fixed = TRUE)
  expect_match(html, "Jornada de trabalho: Indisponível", fixed = TRUE)
  expect_false(grepl('class="wlv-country-chart-gap ', html, fixed = TRUE))
  circles <- regmatches(html, gregexpr("<circle", html, fixed = TRUE))[[1L]]
  expect_length(circles, 2L)
})

test_that("no-data, single-series and one-year states do not fabricate observations", {
  skip_if_not_installed("htmltools")
  chart <- country_landing_chart_env$wlv_country_landing_chart
  empty <- as.character(chart(numeric(), numeric(), numeric()))
  expect_match(empty, "Sem dados disponíveis", fixed = TRUE)
  expect_false(grepl("<svg", empty, fixed = TRUE))
  nonfinite <- as.character(chart(2000:2001, c(NA, Inf), c(NA, NaN)))
  expect_match(nonfinite, "Sem dados disponíveis", fixed = TRUE)
  single <- as.character(chart(2000, 0, NA_real_))
  expect_match(single, "<svg", fixed = TRUE)
  expect_match(single, "Uma série está indisponível", fixed = TRUE)
  expect_match(single, "Jornada de trabalho: 0", fixed = TRUE)
  expect_false(grepl('class="wlv-country-chart-gap ', single, fixed = TRUE))
  zero <- as.character(chart(2000:2001, c(0, 0), c(0, 0)))
  expect_match(zero, "<svg", fixed = TRUE)
  expect_false(grepl("Sem dados", zero, fixed = TRUE))
  expect_false(grepl('class="wlv-country-chart-gap ', zero, fixed = TRUE))
})

test_that("input validation prevents ambiguous year alignment", {
  data <- country_landing_chart_env$wlv_country_landing_chart_rows
  expect_error(data(c(2000, 2000), c(1, 2), c(3, 4)), "unique")
  expect_error(data(2000:2001, 1, c(3, 4)), "same length")
  expect_error(data(c(2000, NA), c(1, 2), c(3, 4)), "finite")
  sorted <- data(c(2002, 2000), c(2, 0), c(5, 3))
  expect_equal(sorted$year, 2000:2002)
  expect_equal(sorted$first, c(0, NA, 2))
})
