# Historical rankings: annual rank cells and highlighted step trajectories.
# Palette follows the WLV red-to-amber identity; it encodes
# annual relative position, not economic complexity or a welfare judgement.
wlv_indicator_ranking_chart <- function(rows, selected, labels, indicator,
                                        unit_label, lang = "pt", countries_input = NULL) {
  stopifnot(nrow(rows) > 0L)
  years <- seq.int(min(rows$year), max(rows$year))
  positions <- seq_len(max(rows$count))
  z <- matrix(NA_real_, nrow = length(positions), ncol = length(years))
  for (i in seq_len(nrow(rows))) {
    z[rows$rank[[i]], match(rows$year[[i]], years)] <- (rows$rank[[i]] - 0.5) / rows$count[[i]]
  }
  palette <- c("#8D2028", "#CC858A", "#F2DCDD", "#FCE7C0", "#F6AE2D")
  scale <- unlist(lapply(seq_along(palette), function(i) {
    list(list((i - 1) / 5, palette[[i]]), list(i / 5, palette[[i]]))
  }), recursive = FALSE)
  rows$label <- unname(labels[match(rows$country, names(labels))])
  rows$label[is.na(rows$label)] <- rows$country[is.na(rows$label)]
  # Four significant digits fit each annual cell; full values stay in payload.
  rows$valueLabel <- vapply(rows$value, function(value) {
    abs_value <- abs(value)
    power <- if (abs_value >= 1e12) 12 else if (abs_value >= 1e9) 9 else if (abs_value >= 1e6) 6 else if (abs_value >= 1e3) 3 else 0
    suffix <- c("", "k", "M", "G", "T")[[match(power, c(0, 3, 6, 9, 12))]]
    paste0(format(signif(value / 10^power, 4), scientific = FALSE, trim = TRUE,
      decimal.mark = wlv_number_marks(lang)$decimal), suffix)
  }, character(1L))
  selected <- intersect(selected, unique(rows$country))
  chart <- plotly::plot_ly(x = years, y = positions, z = z, type = "heatmap",
    zmin = 0, zmax = 1, colorscale = scale, showscale = FALSE,
    xgap = 0, ygap = 0, hoverinfo = "none", hoverongaps = FALSE,
    opacity = 1,
    meta = list(role = "ranking-background"))
  add_country <- function(chart, country = NULL, hover = FALSE) {
    current <- rows[rows$country %in% country, , drop = FALSE]
    index <- match(years, current$year)
    x <- if (hover) numeric() else years
    ranks <- if (hover) numeric() else current$rank[index]
    values <- if (hover) character() else current$valueLabel[index]
    name <- if (length(country)) rows$label[match(country, rows$country)] else ""
    role <- if (hover) "ranking-hover-" else "ranking-selected-"
    common <- list(x = x, type = "scatter", name = name, showlegend = FALSE,
      hoverinfo = "skip", inherit = FALSE, connectgaps = FALSE)
    chart <- do.call(plotly::add_trace, c(list(p = chart, y = ranks - 0.45, mode = "lines",
      line = list(color = "#465963", width = 1, shape = "hvh"),
      meta = list(role = paste0(role, "line"), country = country)), common))
    # Keep gaps in the line, but do not pass missing text anchors to Plotly.
    observed <- is.finite(ranks)
    colors <- if (hover) character() else
      ifelse((current$rank[index] - 0.5) / current$count[index] < 0.2, "#FFFFFF", "#292B2E")
    colors <- colors[observed]
    common$x <- x[observed]
    ranks <- ranks[observed]
    values <- values[observed]
    chart <- do.call(plotly::add_trace, c(list(p = chart, y = ranks - 0.5,
      text = ifelse(is.na(ranks), "", as.character(ranks)), mode = "text",
      textposition = "top center", textfont = list(size = 11, color = if (length(colors)) colors else "#292B2E"),
      cliponaxis = FALSE, meta = list(role = paste0(role, "rank"), country = country)), common))
    do.call(plotly::add_trace, c(list(p = chart, y = ranks + 0.5,
      text = ifelse(is.na(ranks), "", values), mode = "text", textposition = "bottom center",
      textfont = list(size = 9, color = if (length(colors)) colors else "#292B2E"), cliponaxis = FALSE,
      meta = list(role = paste0(role, "value"), country = country)), common))
  }
  for (country in selected) chart <- add_country(chart, country)
  chart <- add_country(chart, hover = TRUE)
  step <- if (max(positions) > 70) 10 else if (max(positions) > 20) 5 else if (max(positions) > 8) 2 else 1
  ticks <- sort(unique(c(1L, seq.int(step, max(positions), by = step))))
  font <- list(family = "'Source Sans 3', sans-serif", color = "#465963", size = 12)
  chart <- plotly::layout(chart, font = font, paper_bgcolor = "#FFFFFF", plot_bgcolor = "#FFFFFF",
    hovermode = "closest", dragmode = FALSE, margin = list(l = 62, r = 164, t = 48, b = 48),
    xaxis = list(title = "", range = c(min(years) - 0.5, max(years) + 0.5),
      tickmode = "array", tickvals = years, ticktext = as.character(years), side = "top",
      showgrid = FALSE, zeroline = FALSE, fixedrange = TRUE),
    yaxis = list(title = wlv_tr("Posição", "Rank", lang),
      range = c(max(positions) + 1.2, -0.2), tickmode = "array", tickvals = ticks,
      showgrid = FALSE, zeroline = FALSE, fixedrange = TRUE),
    # Native grid lines sit below the opaque heatmap. Draw annual guides above
    # its cells so the dashed vertical grid survives both resting and hover.
    shapes = lapply(years, function(year) list(name = paste0("wlv-ranking-grid-", year),
      type = "line", xref = "x", yref = "paper", x0 = year, x1 = year, y0 = 0, y1 = 1,
      layer = "above", line = list(color = "rgba(70,65,65,0.28)", width = 1, dash = "dash"))),
    meta = list(method = rows$method[[1L]], selected = selected, years = years,
      role = "indicator-ranking", countries = length(unique(rows$country))))
  chart <- wlv_plotly_config(chart, lang, displaylogo = FALSE, displayModeBar = FALSE,
    responsive = TRUE)
  # This view has no server-side Plotly events. Hover and annotation updates
  # are handled locally and must not emit Shiny inputs for every mouse move.
  chart$preRenderHook <- local({
    prepare <- chart$preRenderHook
    function(widget) {
      if (!is.null(prepare)) widget <- prepare(widget)
      widget$x$shinyEvents <- character()
      widget
    }
  })
  htmlwidgets::onRender(chart,
    "function(el, x, data) { if (window.WLVIndicatorRanking) window.WLVIndicatorRanking.attach(el, data); }",
    data = list(rows = lapply(seq_len(nrow(rows)), function(i) as.list(rows[i, , drop = FALSE])), years = years,
      selected = selected, lang = lang, unitLabel = unit_label, indicator = indicator,
      method = rows$method[[1L]], palette = palette, countriesInputId = countries_input))
}
