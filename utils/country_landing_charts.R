# The landing charts use the same units supplied by the country profile.
# Missing annual observations stay missing in both lines and shaded intervals.
wlv_country_landing_chart_rows <- function(years, first, second) {
  if (length(years) != length(first) || length(years) != length(second)) {
    stop("years, first and second must have the same length.")
  }
  if (!is.numeric(years) || !is.numeric(first) || !is.numeric(second)) {
    stop("years, first and second must be numeric.")
  }
  if (any(!is.finite(years)) || any(years != floor(years)) || anyDuplicated(years)) {
    stop("years must contain unique, finite calendar years.")
  }
  if (!length(years)) return(data.frame(year = numeric(), first = numeric(), second = numeric()))
  if (diff(range(years)) > 1000) stop("The annual chart cannot span more than 1,000 years.")
  annual <- seq.int(min(years), max(years))
  rows <- data.frame(year = annual, first = first[match(annual, years)], second = second[match(annual, years)])
  rows$first[!is.finite(rows$first)] <- NA_real_
  rows$second[!is.finite(rows$second)] <- NA_real_
  observed <- which(is.finite(rows$first) | is.finite(rows$second))
  if (!length(observed)) return(rows[FALSE, , drop = FALSE])
  # Other datasets may extend the shared year axis. Show this chart's own
  # observed extent while retaining every unavailable year inside it.
  rows[seq.int(observed[[1L]], tail(observed, 1L)), , drop = FALSE]
}

# Piecewise cubic Hermite interpolation keeps each series within its observed
# interval bounds. Slopes restart at missing observations; an isolated value
# never receives an interpolated neighbour. The normalized interval is [0, 1].
wlv_country_landing_curves <- function(rows) {
  series <- function(values) {
    result <- vector("list", max(0L, nrow(rows) - 1L))
    observed <- which(is.finite(values))
    if (length(observed) < 2L) return(result)
    runs <- split(observed, cumsum(c(1L, diff(observed) != 1L)))
    endpoint <- function(first, next_delta) {
      slope <- (3 * first - next_delta) / 2
      if (sign(slope) != sign(first)) return(0)
      if (sign(first) != sign(next_delta) && abs(slope) > 3 * abs(first)) return(3 * first)
      slope
    }
    for (run in runs) {
      n <- length(run)
      if (n < 2L) next
      values_run <- values[run]
      delta <- diff(values_run)
      slopes <- numeric(n)
      if (n == 2L) {
        slopes[] <- delta
      } else {
        slopes[[1L]] <- endpoint(delta[[1L]], delta[[2L]])
        slopes[[n]] <- endpoint(delta[[n - 1L]], delta[[n - 2L]])
        for (j in 2L:(n - 1L)) {
          before <- delta[[j - 1L]]; after <- delta[[j]]
          if (before != 0 && after != 0 && sign(before) == sign(after))
            slopes[[j]] <- 2 / (1 / before + 1 / after)
        }
      }
      for (j in seq_len(n - 1L)) {
        result[[run[[j]]]] <- c(values_run[[j]], slopes[[j]],
          3 * delta[[j]] - 2 * slopes[[j]] - slopes[[j + 1L]],
          -2 * delta[[j]] + slopes[[j]] + slopes[[j + 1L]])
      }
    }
    result
  }
  list(first = series(rows$first), second = series(rows$second))
}

wlv_country_landing_curve_value <- function(curve, at) {
  ((curve[[4L]] * at + curve[[3L]]) * at + curve[[2L]]) * at + curve[[1L]]
}

wlv_country_landing_curve_derivative <- function(curve, at) {
  (3 * curve[[4L]] * at + 2 * curve[[3L]]) * at + curve[[2L]]
}

# The area uses those very same curves, split at every real root of their
# cubic difference. This also handles multiple crossings inside one year.
wlv_country_landing_segments <- function(rows, curves = wlv_country_landing_curves(rows)) {
  result <- list()
  if (nrow(rows) < 2L) return(result)
  for (i in seq_len(nrow(rows) - 1L)) {
    first <- curves$first[[i]]; second <- curves$second[[i]]
    if (is.null(first) || is.null(second)) next
    gap <- first - second
    if (all(gap == 0)) next
    roots <- polyroot(gap)
    roots <- sort(Re(roots[abs(Im(roots)) < 1e-8 & Re(roots) > 1e-9 & Re(roots) < 1 - 1e-9]))
    if (length(roots)) roots <- roots[c(TRUE, diff(roots) > 1e-8)]
    fractions <- c(0, roots, 1)
    for (j in seq_len(length(fractions) - 1L)) {
      at <- fractions[c(j, j + 1L)]
      result[[length(result) + 1L]] <- list(
        year = rows$year[[i]] + at,
        first = wlv_country_landing_curve_value(first, at),
        second = wlv_country_landing_curve_value(second, at),
        first_curve = first, second_curve = second,
        origin = rows$year[[i]], fraction = at,
        direction = if (wlv_country_landing_curve_value(gap, mean(at)) > 0) "sent" else "received"
      )
    }
  }
  result
}

wlv_country_landing_number <- function(value, lang = "Português", digits = 2L) {
  if (!is.finite(value)) return(wlv_tr("Indisponível", "Unavailable", lang))
  value <- round(value, digits)
  if (value == 0) value <- 0 # Do not display a rounded negative zero.
  format(value, scientific = FALSE, trim = TRUE, nsmall = 0,
    big.mark = wlv_number_marks(lang)$grouping, decimal.mark = wlv_number_marks(lang)$decimal)
}

wlv_country_landing_chart_id <- local({
  serial <- 0L
  function(id) {
    serial <<- serial + 1L
    paste0("wlv-country-chart-", gsub("[^A-Za-z0-9_-]", "-", id), "-", serial)
  }
})

wlv_country_landing_chart_prepare <- function(years, first, second, id = "profile") {
  rows <- wlv_country_landing_chart_rows(years, first, second)
  result <- list(id = wlv_country_landing_chart_id(id), rows = rows,
    ticks = numeric(), yr = c(0, 1), curves = list(), segments = list())
  if (!nrow(rows)) return(result)
  yr <- range(c(0, rows$first, rows$second), na.rm = TRUE)
  if (diff(yr) == 0) yr <- c(0, 1)
  result$yr <- yr + c(if (yr[[1L]] < 0) -0.05 else 0, 0.08) * diff(yr)
  ticks <- pretty(result$yr, n = 4)
  result$ticks <- ticks[ticks >= result$yr[[1L]] & ticks <= result$yr[[2L]]]
  result$curves <- wlv_country_landing_curves(rows)
  result$segments <- wlv_country_landing_segments(rows, result$curves)
  result
}

# Localization never recalculates curves or replaces their DOM nodes. This
# payload also supplies the initial render, so text, rounding and accessibility
# remain identical whether a language was chosen before or after opening País.
wlv_country_landing_chart_text <- function(prepared, labels = NULL,
    kind = c("labour", "trade"), lang = "Português") {
  kind <- match.arg(kind)
  tr <- function(pt, en) wlv_tr(pt, en, lang)
  if (is.null(labels)) {
    labels <- if (kind == "labour") {
      tr(c("Jornada de trabalho", "Valor da força de trabalho"), c("Working day", "Value of labour power"))
    } else {
      tr(c("Valor bruto enviado", "Valor bruto recebido"), c("Gross value sent", "Gross value received"))
    }
  }
  if (length(labels) != 2L || anyNA(labels)) stop("labels must contain two series names.")
  rows <- prepared$rows
  description <- if (kind == "labour") {
    tr("A área preenchida representa o mais-valor: jornada de trabalho menos valor da força de trabalho. O vermelho indica diferença positiva; o âmbar, negativa.",
      "The filled area shows surplus value: working day minus the value of labour power. Red marks a positive difference; amber marks a negative difference.")
  } else {
    tr("A área vermelha representa envio líquido de valor; a âmbar, recebimento líquido.",
      "The red area shows net value sent; the amber area shows net value received.")
  }
  empty <- tr("Sem dados disponíveis para este país e método.", "No data available for this country and method.")
  number <- function(value, digits = 2L) wlv_country_landing_number(value, lang, digits)
  ticks <- vapply(prepared$ticks, number, character(1L), digits = 3L)
  observations <- lapply(seq_len(nrow(rows)), function(i) {
    gap <- rows$first[[i]] - rows$second[[i]]
    gap_label <- if (kind == "labour") {
      tr("Mais-valor", "Surplus value")
    } else if (is.finite(gap) && gap < 0) {
      tr("Recebimento líquido", "Net value received")
    } else {
      tr("Envio líquido", "Net value sent")
    }
    list(year = as.character(rows$year[[i]]), text = paste0(rows$year[[i]], ". ",
      labels[[1L]], ": ", number(rows$first[[i]]), "; ",
      labels[[2L]], ": ", number(rows$second[[i]]), "; ", gap_label, ": ",
      number(if (kind == "trade") abs(gap) else gap), "."))
  })
  list(id = prepared$id, empty = empty, labels = unname(labels),
    title = paste(labels, collapse = tr(" e ", " and ")),
    description = paste(description,
      tr("As curvas são suavizadas. Selecione cada ano pelo teclado para ler os valores originais. Lacunas indicam dados indisponíveis.",
        "Curves are smoothed. Focus each year to read its original values. Gaps mean unavailable data.")),
    ticks = unname(ticks), y_chars = max(nchar(ticks), 1L), observations = observations,
    legend = unname(c(labels, if (kind == "labour") tr("Mais-valor", "Surplus value") else
      tr(c("Envio líquido", "Recebimento líquido"), c("Net value sent", "Net value received")))),
    note = tr("Uma série está indisponível; não é possível calcular a diferença.",
      "One series is unavailable; the difference cannot be calculated."))
}

wlv_country_landing_chart <- function(years, first, second, labels = NULL,
                                      kind = c("labour", "trade"),
                                      lang = "Português", id = "profile", prepared = NULL) {
  kind <- match.arg(kind)
  if (is.null(prepared)) prepared <- wlv_country_landing_chart_prepare(years, first, second, id)
  rows <- prepared$rows
  chart_id <- prepared$id
  text <- wlv_country_landing_chart_text(prepared, labels, kind, lang)
  labels <- text$labels
  if (!nrow(rows) || !any(is.finite(c(rows$first, rows$second)))) {
    return(htmltools::tags$div(class = "wlv-country-landing-chart wlv-country-chart-empty",
      `data-wlv-chart-id` = chart_id, role = "status", text$empty))
  }
  svg_tag <- function(name, ..., children = list()) htmltools::tag(name, c(list(...), children))
  coord <- function(value) format(round(value, 3), scientific = FALSE, trim = TRUE, decimal.mark = ".")
  first_color <- "#8D2028"
  second_color <- "#F6AE2D"
  sent_color <- "#F2DCDD"
  received_color <- "#FCE7C0"
  left <- 0
  right <- 500
  top <- 16
  bottom <- 195
  xr <- range(rows$year)
  if (diff(xr) == 0) xr <- xr + c(-0.5, 0.5)
  yr <- prepared$yr
  x <- function(value) left + (value - xr[[1L]]) / diff(xr) * (right - left)
  y <- function(value) bottom - (value - yr[[1L]]) / diff(yr) * (bottom - top)
  # A cubic subcurve converted to Bézier controls exactly matches the line.
  curve_command <- function(curve, origin, at = c(0, 1)) {
    width <- diff(at)
    endpoints <- wlv_country_landing_curve_value(curve, at)
    slopes <- wlv_country_landing_curve_derivative(curve, at)
    px <- origin + c(at[[1L]] + width / 3, at[[2L]] - width / 3, at[[2L]])
    py <- c(endpoints[[1L]] + slopes[[1L]] * width / 3,
      endpoints[[2L]] - slopes[[2L]] * width / 3, endpoints[[2L]])
    paste("C", paste(coord(x(px)), coord(y(py)), collapse = " "))
  }
  ticks <- prepared$ticks
  grid <- lapply(ticks, function(value)
    svg_tag("line", x1 = coord(left), x2 = coord(right), y1 = coord(y(value)), y2 = coord(y(value)),
      stroke = "#d7ddd9", `stroke-width` = "0.7", `stroke-dasharray` = if (value == 0) NULL else "2 4"))
  # Keep labels outside the SVG: a 14px label must stay 14px in a narrow column.
  tick_labels <- text$ticks
  value_labels <- lapply(seq_along(ticks), function(i) htmltools::tags$span(
    class = "wlv-country-chart-tick wlv-country-chart-tick-y",
    style = paste0("top:", coord(y(ticks[[i]]) / 230 * 100), "%;"), tick_labels[[i]]))
  # Keep calendar-year labels even when the observed range is only one year.
  year_ticks <- unique(rows$year[unique(round(seq(1, nrow(rows), length.out = min(4L, nrow(rows)))))])
  year_labels <- lapply(year_ticks, function(value) htmltools::tags$span(
    class = "wlv-country-chart-tick wlv-country-chart-tick-x",
    style = paste0("left:", coord(x(value) / 500 * 100), "%;top:", coord(bottom / 230 * 100), "%;"),
    as.character(value)))
  curves <- prepared$curves
  segments <- prepared$segments
  # One closed path per continuous color region prevents antialias seams at
  # annual boundaries. True crossings and missing years still split regions.
  run_ids <- cumsum(vapply(seq_along(segments), function(i) {
    if (i == 1L) return(TRUE)
    previous <- segments[[i - 1L]]; current <- segments[[i]]
    previous$direction != current$direction || abs(previous$year[[2L]] - current$year[[1L]]) > 1e-8
  }, logical(1L)))
  fills <- lapply(unname(split(segments, run_ids)), function(run) {
    first <- run[[1L]]; last <- run[[length(run)]]
    direction <- first$direction
    upper <- vapply(run, function(segment)
      curve_command(segment$first_curve, segment$origin, segment$fraction), character(1L))
    lower <- vapply(rev(run), function(segment)
      curve_command(segment$second_curve, segment$origin, rev(segment$fraction)), character(1L))
    path <- paste("M", coord(x(first$year[[1L]])), coord(y(first$first[[1L]])),
      paste(upper, collapse = " "),
      "L", coord(x(last$year[[2L]])), coord(y(last$second[[2L]])),
      paste(lower, collapse = " "), "Z")
    svg_tag("path", d = path, fill = if (direction == "sent") sent_color else received_color,
      class = paste0("wlv-country-chart-gap wlv-country-chart-gap-", direction),
      `data-start-year` = coord(first$year[[1L]]), `data-end-year` = coord(last$year[[2L]]),
      `aria-hidden` = "true")
  })
  series <- function(values, color, key) {
    available <- is.finite(values)
    previous <- c(FALSE, head(available, -1L))
    following <- c(tail(available, -1L), FALSE)
    commands <- vapply(which(available), function(i) {
      if (!previous[[i]]) paste("M", coord(x(rows$year[[i]])), coord(y(values[[i]]))) else
        curve_command(curves[[key]][[i - 1L]], rows$year[[i - 1L]])
    }, character(1L))
    path <- paste(commands, collapse = " ")
    list(
      svg_tag("path", d = path, fill = "none", stroke = color, `stroke-width` = "2",
        `stroke-linejoin` = "round", `stroke-linecap` = "round", `data-series` = key,
        `vector-effect` = "non-scaling-stroke", `aria-hidden` = "true"),
      lapply(which(available & !previous & !following), function(i) svg_tag("circle", cx = coord(x(rows$year[[i]])), cy = coord(y(values[[i]])),
        r = "1.6", fill = color, `aria-hidden` = "true"))
    )
  }
  observations <- lapply(seq_len(nrow(rows)), function(i) {
    annotation <- text$observations[[i]]$text
    x0 <- if (i == 1L) left else mean(x(rows$year[c(i - 1L, i)]))
    x1 <- if (i == nrow(rows)) right else mean(x(rows$year[c(i, i + 1L)]))
    svg_tag("rect", x = coord(x0), y = coord(top), width = coord(x1 - x0), height = coord(bottom - top),
      fill = "transparent", tabindex = "0", role = "img", `aria-label` = annotation,
      class = "wlv-country-chart-observation", `data-year` = as.character(rows$year[[i]]),
      children = list(svg_tag("title", children = list(annotation))))
  })
  legend_item <- function(label, color, filled = FALSE) htmltools::tags$span(
    class = "wlv-country-chart-legend-item", style = "display:inline-flex;align-items:center;gap:6px;min-width:0;",
    htmltools::tags$span(`aria-hidden` = "true", style = if (filled) {
      paste0("display:inline-block;width:11px;height:11px;background:", color, ";flex-shrink:0;")
    } else
      paste0("display:inline-block;width:17px;height:2px;background:", color, ";flex-shrink:0;")), label)
  legend <- htmltools::tags$div(class = "wlv-country-chart-legend",
    style = "display:flex;flex-wrap:wrap;gap:8px 17px;font-size:14px;line-height:1.5;color:var(--wlv-muted,#65595A);",
    legend_item(labels[[1L]], first_color), legend_item(labels[[2L]], second_color),
    if (kind == "labour") legend_item(text$legend[[3L]], sent_color, TRUE) else
      htmltools::tagList(legend_item(text$legend[[3L]], sent_color, TRUE),
        legend_item(text$legend[[4L]], received_color, TRUE)))
  incomplete <- !any(is.finite(rows$first)) || !any(is.finite(rows$second))
  htmltools::tags$div(class = paste("wlv-country-landing-chart", paste0("wlv-country-chart-", kind)),
    `data-wlv-chart-id` = chart_id,
    htmltools::tags$div(class = "wlv-country-chart-frame",
      style = paste0("--wlv-chart-y-chars:", max(nchar(tick_labels), 1L), ";"),
    svg_tag("svg", xmlns = "http://www.w3.org/2000/svg", viewBox = "0 0 500 230", width = "100%",
      preserveAspectRatio = "none",
      role = "group", `aria-labelledby` = paste0(chart_id, "-title ", chart_id, "-desc"),
      style = "display:block;overflow:visible;font-family:inherit;",
      children = c(list(
        svg_tag("title", id = paste0(chart_id, "-title"), children = list(text$title)),
        svg_tag("desc", id = paste0(chart_id, "-desc"), children = list(text$description))),
        grid, fills, series(rows$first, first_color, "first"), series(rows$second, second_color, "second"),
        observations)),
      htmltools::tags$div(class = "wlv-country-chart-axis-y", value_labels),
      htmltools::tags$div(class = "wlv-country-chart-axis-x", year_labels)),
    legend,
    if (incomplete) htmltools::tags$p(class = "wlv-country-chart-note", role = "status",
      style = "font-size:14px;line-height:1.5;color:var(--wlv-muted,#65595A);margin:8px 0 0;",
      text$note))
}
