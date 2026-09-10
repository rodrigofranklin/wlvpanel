trade_chart_env <- new.env(parent = environment())
source(file.path(wlvpanel_test_root, "modules", "trade", "charts.R"), local = trade_chart_env, encoding = "UTF-8")

trade_chart_fixture <- function(value = c(12, -8, 0, NA_real_)) {
  data.frame(id = paste0("ID", seq_along(value)), label = paste("Category", seq_along(value)),
    value = value, outgoing = abs(value) + 2, incoming = rep(2, length(value)))
}

trade_mosaic_leaves <- function(traces) {
  do.call(rbind, lapply(traces, function(trace) data.frame(
    customdata = as.character(trace$customdata), labels = as.character(trace$labels),
    values = as.numeric(trace$values), parents = as.character(trace$parents),
    text = as.character(trace$text), texttemplate = as.character(trace$texttemplate),
    colour = as.character(trace$marker$colors), font_size = as.numeric(trace$insidetextfont$size))))
}

test_that("trade charts preserve signed long-tail totals without netting remainder groups", {
  rows <- trade_chart_fixture(c(100:70, -(69:40), 0, NA_real_))
  rows$outgoing[50] <- NA_real_
  prepared <- trade_chart_env$wlv_trade_chart_categories(rows)
  expect_lte(nrow(prepared$rows), 20L)
  expect_equal(prepared$missing, 1L)
  expect_true(prepared$grouped)
  expect_equal(sum(prepared$rows$value), sum(rows$value, na.rm = TRUE))
  expect_equal(sum(abs(prepared$rows$value)), sum(abs(rows$value), na.rm = TRUE))
  rest <- prepared$rows[prepared$rows$id == "", ]
  expect_true(any(rest$value > 0))
  expect_true(any(rest$value < 0))
  expect_true(any(rest$value == 0))
  expect_true(is.na(rest$outgoing[rest$value < 0]))
})

test_that("ranking retains signed click identities and discloses missing rows", {
  skip_if_not_installed("plotly")
  chart <- trade_chart_env$wlv_trade_rank_chart(trade_chart_fixture(), "USD", "Trade")
  built <- plotly::plotly_build(chart)
  expect_equal(as.numeric(built$x$data[[1]]$x), c(-8, 0, 12))
  expect_identical(as.character(built$x$data[[1]]$customdata), c("ID2", "ID3", "ID1"))
  expect_true(all(built$x$data[[1]]$textposition == "none"))
  expect_equal(built$x$layout$xaxis$rangemode, "tozero")
  expect_true("plotly_click" %in% chart$x$shinyEvents)
  expect_match(gsub("<br>", " ", built$x$layout$title$text, fixed = TRUE), "1 observações indisponíveis", fixed = TRUE)
})

test_that("composition groups signs in contiguous proportional domains with globally comparable areas", {
  skip_if_not_installed("plotly")
  chart <- trade_chart_env$wlv_trade_composition_chart(trade_chart_fixture(), "USD", "Trade", show_title = FALSE)
  built <- plotly::plotly_build(chart)
  traces <- built$x$data
  expect_length(traces, 2L)
  leaves <- trade_mosaic_leaves(traces)
  expect_true(all(leaves$values >= 0))
  expect_true(all(leaves$parents == ""))
  expect_equal(sum(leaves$values), 20)
  expect_equal(leaves$values[leaves$customdata == "ID1"], 12)
  expect_equal(leaves$values[leaves$customdata == "ID2"], 8)
  expect_setequal(leaves$customdata, c("ID1", "ID2"))
  expect_equal(as.character(traces[[1L]]$customdata), "ID2")
  expect_equal(as.character(traces[[2L]]$customdata), "ID1")
  expect_equal(traces[[1L]]$domain$x, c(0, 0.4))
  expect_equal(traces[[2L]]$domain$x, c(0.4, 1))
  expect_equal(tail(traces[[1L]]$domain$x, 1L), head(traces[[2L]]$domain$x, 1L))
  for (trace in traces) {
    expect_identical(trace$type, "treemap")
    expect_identical(trace$branchvalues, "total")
    expect_equal(trace$domain$y, c(0, 1))
    expect_equal(diff(trace$domain$x), sum(trace$values) / sum(leaves$values))
    expect_false(trace$pathbar$visible)
    expect_null(trace$title)
  }
  expect_identical(built$x$layout$title$text, "")
  expect_null(built$x$layout$shapes)
  expect_match(leaves$text[leaves$customdata == "ID1"], "valor absoluto total: 60%", fixed = TRUE)
  expect_match(leaves$text[leaves$customdata == "ID2"], "valor absoluto total: 40%", fixed = TRUE)
  expect_match(leaves$text[leaves$customdata == "ID2"], "-8", fixed = TRUE)
})

test_that("compositions containing only one sign fill the entire mosaic", {
  skip_if_not_installed("plotly")
  for (direction in c(-1, 1)) {
    rows <- trade_chart_fixture(direction * c(8, 2, 0, NA_real_))
    chart <- trade_chart_env$wlv_trade_composition_chart(rows, "USD", "Trade", "en", show_title = FALSE)
    traces <- plotly::plotly_build(chart)$x$data
    expect_length(traces, 1L)
    expect_equal(traces[[1L]]$domain$x, c(0, 1))
    expect_equal(traces[[1L]]$domain$y, c(0, 1))
    leaves <- trade_mosaic_leaves(traces)
    expect_equal(sum(leaves$values), 10)
    expect_setequal(leaves$customdata, c("ID1", "ID2"))
    expect_match(leaves$text[leaves$customdata == "ID1"], "80%", fixed = TRUE)
    expect_match(leaves$text[leaves$customdata == "ID2"], "20%", fixed = TRUE)
    expect_true(all(leaves$parents == ""))
  }
})

test_that("annual series preserve explicit and absent-year gaps instead of inventing zeros", {
  skip_if_not_installed("plotly")
  rows <- data.frame(year = c(2004L, 2000L, 2001L, 2002L), value = c(-3, 1, NA, 2))
  chart <- trade_chart_env$wlv_trade_series_chart(rows, "USD", "Trade")
  prepared <- attr(chart, "wlv_trade_chart_rows")
  expect_equal(prepared$year, 2000:2004)
  expect_equal(prepared$value, c(1, NA, 2, NA, -3))
  expect_true(all(is.na(prepared$outgoing)))
  trace <- plotly::plotly_build(chart)$x$data[[1]]
  expect_false(trace$connectgaps)
  expect_identical(trace$mode, "lines+markers")
  sparse <- trade_chart_env$wlv_trade_series_chart(rows[1, ], "USD", "Trade")
  expect_identical(plotly::plotly_build(sparse)$x$data[[1]]$mode, "markers")
})

test_that("empty and all-zero compositions explain why no areas are drawn", {
  skip_if_not_installed("plotly")
  for (rows in list(NULL, trade_chart_fixture(NA_real_))) {
    chart <- trade_chart_env$wlv_trade_composition_chart(rows, "USD", "Trade", "en")
    built <- plotly::plotly_build(chart)
    expect_match(built$x$layout$annotations[[1]]$text, "No data", fixed = TRUE)
  }
  chart <- trade_chart_env$wlv_trade_composition_chart(trade_chart_fixture(c(0, 0)), "USD", "Trade", "en")
  expect_match(plotly::plotly_build(chart)$x$layout$annotations[[1]]$text, "zero", fixed = TRUE)
})

test_that("chart labels and titles escape markup while retaining accented text", {
  skip_if_not_installed("plotly")
  rows <- trade_chart_fixture(1)
  rows$label <- "<b>Comércio & indústria</b>"
  chart <- trade_chart_env$wlv_trade_rank_chart(rows, "USD", "<b>Comércio</b>")
  built <- plotly::plotly_build(chart)
  expect_match(built$x$data[[1]]$text, "&lt;b&gt;Comércio &amp; indústria&lt;/b&gt;", fixed = TRUE)
  expect_match(built$x$layout$title$text, "&lt;b&gt;Comércio&lt;/b&gt;", fixed = TRUE)
})

test_that("transfer hovers show export and import contributions without mutating raw amounts", {
  skip_if_not_installed("plotly")
  rows <- data.frame(id = "BRA", label = "Brasil", value = 6, outgoing = 10, incoming = 4)
  for (builder in list(trade_chart_env$wlv_trade_rank_chart, trade_chart_env$wlv_trade_composition_chart)) {
    chart <- builder(rows, "USD", "Trade", "en", metric = "transfer")
    built <- plotly::plotly_build(chart)
    text <- built$x$data[[1]]$text[built$x$data[[1]]$customdata == "BRA"]
    expect_match(text, "Through exports: +10 USD", fixed = TRUE)
    expect_match(text, "Through imports: -4 USD", fixed = TRUE)
    expect_equal(attr(chart, "wlv_trade_chart_rows")$incoming, 4)
  }
  series <- data.frame(year = 2000, value = 6, outgoing = 10, incoming = -4)
  text <- plotly::plotly_build(trade_chart_env$wlv_trade_series_chart(series, "USD", "Trade", metric = "transfer"))$x$data[[1]]$text
  expect_match(text, "Pelas importações: +4 USD", fixed = TRUE)
  for (metric in c("exports", "imports", "balance")) {
    chart <- trade_chart_env$wlv_trade_rank_chart(rows, "USD", "Trade", "en", metric = metric)
    text <- plotly::plotly_build(chart)$x$data[[1]]$text
    expect_match(text, "Exports: 10 USD", fixed = TRUE)
    expect_match(text, "Imports: 4 USD", fixed = TRUE)
    expect_false(grepl("Through", text, fixed = TRUE))
  }
})

test_that("ranking publishes a height large enough for the complete category set", {
  skip_if_not_installed("plotly")
  chart <- trade_chart_env$wlv_trade_rank_chart(trade_chart_fixture(1:40), "USD", "Trade")
  geometry <- attr(chart, "wlv_trade_rank_geometry")
  expect_gte(geometry$body_height, sum(geometry$row_heights))
  expect_equal(chart$height, geometry$body_height + sum(attr(chart, "wlv_trade_chart_padding")))
  expect_equal(plotly::plotly_build(chart)$x$layout$height, chart$height)
})

test_that("transfers rank net sending before net receipt while retaining magnitude-selected categories", {
  skip_if_not_installed("plotly")
  rows <- trade_chart_fixture(c(100:70, -(69:40), 0, NA_real_))
  rows$outgoing <- seq_len(nrow(rows))
  rows$incoming <- rows$outgoing - rows$value
  selected <- trade_chart_env$wlv_trade_chart_categories(rows)$rows
  chart <- trade_chart_env$wlv_trade_rank_chart(rows, "USD", "Ganhos e perdas", metric = "transfer")
  prepared <- attr(chart, "wlv_trade_chart_rows")
  built <- plotly::plotly_build(chart)
  expect_equal(nrow(prepared), nrow(selected))
  expect_setequal(prepared$label, selected$label)
  expect_true(all(diff(prepared$value) >= 0))
  expect_equal(prepared$value, prepared$outgoing - prepared$incoming)
  expect_equal(sum(abs(prepared$value)), sum(abs(rows$value), na.rm = TRUE))
  expect_true(prepared$value[[1L]] < 0)
  expect_true(tail(prepared$value, 1L) > 0)
  expect_equal(prepared$id[c(1L, nrow(prepared))], c("", ""))
  expect_true(built$x$layout$yaxis$range[[1L]] > built$x$layout$yaxis$range[[2L]])
  expect_equal(as.numeric(built$x$data[[1L]]$x), prepared$value)
  expect_false(grepl("Do maior envio", built$x$layout$title$text, fixed = TRUE))
  english <- trade_chart_env$wlv_trade_rank_chart(rows, "USD", "Gains and losses", "en", metric = "transfer")
  expect_false(grepl("From largest net sending", plotly::plotly_build(english)$x$layout$title$text, fixed = TRUE))
  composition <- trade_chart_env$wlv_trade_composition_chart(rows, "USD", "Composition")
  expect_setequal(attr(composition, "wlv_trade_chart_rows")$id, rows$id[is.finite(rows$value) & rows$value != 0])
  exports <- trade_chart_env$wlv_trade_rank_chart(rows, "USD", "Exports", "en", metric = "exports")
  expect_identical(attr(exports, "wlv_trade_chart_rows")$id, selected$id)
  expect_equal(attr(exports, "wlv_trade_chart_rows")$value, selected$value)
  expect_false(grepl("Ordered by absolute value", plotly::plotly_build(exports)$x$layout$title$text, fixed = TRUE))
})

test_that("long sector labels get distinct row space while hover preserves the complete name", {
  skip_if_not_installed("plotly")
  rows <- trade_chart_fixture(seq(-10, 9))
  rows$label[2:4] <- paste(rep("Manufacture of chemicals and pharmaceutical products", 4), collapse = " ")
  chart <- trade_chart_env$wlv_trade_rank_chart(rows, "USD", "Sectors", show_title = FALSE)
  geometry <- attr(chart, "wlv_trade_rank_geometry")
  built <- plotly::plotly_build(chart)
  expect_true(all(geometry$line_counts <= 3L))
  expect_equal(geometry$line_counts[2:4], rep(3L, 3L))
  expect_true(all(geometry$row_heights[2:4] > geometry$row_heights[[1L]]))
  distances <- diff(geometry$positions)
  text_half_heights <- 9 * geometry$line_counts
  expect_true(all(distances >= head(text_half_heights, -1L) + tail(text_half_heights, -1L) + 14))
  expect_equal(diff(rev(built$x$layout$yaxis$range)), geometry$body_height)
  expect_equal(as.numeric(built$x$data[[1L]]$width), rep(22, nrow(rows)))
  expect_match(built$x$layout$yaxis$ticktext[[2L]], "…", fixed = TRUE)
  expect_match(built$x$data[[1L]]$text[[2L]], rows$label[[2L]], fixed = TRUE)
})

test_that("HTML-heading mode leaves charts without internal titles or instructional subtitles", {
  skip_if_not_installed("plotly")
  for (lang in c("pt", "en")) {
    for (builder in list(trade_chart_env$wlv_trade_rank_chart, trade_chart_env$wlv_trade_composition_chart)) {
      rows <- trade_chart_fixture(c(1:30, -(1:10)))
      chart <- builder(rows, "USD", "A very long heading belongs outside the plot", lang, show_title = FALSE)
      built <- plotly::plotly_build(chart)
      expect_identical(built$x$layout$title$text, "")
      expect_equal(built$x$layout$margin$t, 12)
      normal <- plotly::plotly_build(builder(rows, "USD", "Trade", lang))
      expect_false(grepl("maior envio|largest net sending|valor absoluto;|Area =|agrupadas por sinal|grouped by sign", normal$x$layout$title$text))
    }
  }
  series <- trade_chart_env$wlv_trade_series_chart(data.frame(year = 2000:2001, value = c(1, 2)), "USD", "Trade", show_title = FALSE)
  expect_identical(plotly::plotly_build(series)$x$layout$title$text, "")
  empty <- trade_chart_env$wlv_trade_rank_chart(NULL, "USD", "Trade", show_title = FALSE)
  expect_identical(plotly::plotly_build(empty)$x$layout$title$text, "")
})

test_that("the compact mosaic retains all sectors in colour clusters without parent boxes", {
  skip_if_not_installed("plotly")
  rows <- trade_chart_fixture(c(1:28, -(1:28)))
  chart <- trade_chart_env$wlv_trade_composition_chart(rows, "USD", "Composition", show_title = FALSE)
  traces <- plotly::plotly_build(chart)$x$data
  leaves <- trade_mosaic_leaves(traces)
  expect_equal(nrow(leaves), 56L)
  expect_setequal(leaves$customdata, rows$id)
  expect_equal(sum(leaves$values), sum(abs(rows$value)))
  expect_true(all(leaves$values >= 0))
  expect_true(all(leaves$parents == ""))
  expect_setequal(leaves$labels, rows$label)
  positive <- rows$id[rows$value > 0]
  negative <- rows$id[rows$value < 0]
  expect_setequal(traces[[1L]]$customdata, negative)
  expect_setequal(traces[[2L]]$customdata, positive)
  expect_length(intersect(leaves$colour[leaves$customdata %in% positive],
    leaves$colour[leaves$customdata %in% negative]), 0L)
  for (trace in traces) {
    expect_identical(trace$tiling$packing, "squarify")
    expect_equal(trace$tiling$pad, 0)
    expect_equal(trace$marker$line$width, 1)
    expect_equal(unlist(trace$marker$pad[c("t", "r", "b", "l")], use.names = FALSE), rep(0, 4L))
  }
  expect_gt(length(unique(leaves$colour)), 2)
  expect_true(all(grepl("%", leaves$texttemplate, fixed = TRUE)))
  expect_true(all(grepl("Parcela do valor absoluto total", leaves$text, fixed = TRUE)))
})

test_that("large mosaic tiles retain adaptive type instead of global minimum-size text", {
  skip_if_not_installed("plotly")
  chart <- trade_chart_env$wlv_trade_composition_chart(trade_chart_fixture(c(60, -20, 10, 5, 5)), "USD", "Composition", show_title = FALSE)
  built <- plotly::plotly_build(chart)
  leaves <- trade_mosaic_leaves(built$x$data)
  expect_null(built$x$layout$uniformtext)
  expect_gte(leaves$font_size[leaves$customdata == "ID1"], 30)
  expect_gt(leaves$font_size[leaves$customdata == "ID1"], leaves$font_size[leaves$customdata == "ID4"])
})

test_that("mosaic hides unreadably scaled labels after drawing while preserving hover and click data", {
  skip_if_not_installed("plotly")
  rows <- trade_chart_fixture(c(100, -10, 0.001))
  chart <- trade_chart_env$wlv_trade_composition_chart(rows, "USD", "Composition", show_title = FALSE)
  hooks <- vapply(chart$jsHooks$render, function(hook) hook$code, character(1L))
  guard <- hooks[grepl("getScreenCTM", hooks, fixed = TRUE)]
  expect_length(guard, 1L)
  expect_match(guard, "plotly_afterplot", fixed = TRUE)
  expect_match(guard, "getComputedStyle(text).fontSize", fixed = TRUE)
  expect_match(guard, "text.style.opacity = size * scale < 10 ? '0' : ''", fixed = TRUE)
  expect_match(guard, "removeListener", fixed = TRUE)
  expect_false(grepl("Plotly.relayout|Plotly.restyle|uniformtext", guard))
  leaves <- trade_mosaic_leaves(plotly::plotly_build(chart)$x$data)
  expect_setequal(leaves$customdata, rows$id)
  expect_match(leaves$text[leaves$customdata == "ID3"], "Category 3", fixed = TRUE)
  expect_equal(leaves$values[leaves$customdata == "ID3"], 0.001)
})
