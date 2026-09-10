# Trade chart contract: native Plotly widgets for the Shiny trade module.
# Ranking compares signed amounts on a zero-based horizontal axis; transfers
# run from the largest net sending at the top to largest net receipt below.
# Selection still uses absolute magnitude before sorting all bars. Composition
# uses absolute areas with separate positive/negative branches, never net areas.
# Annual series retain gaps. Ranking draws at most 20 categories including
# remainder groups by sign; the treemap retains every available category.
# Missing observations are disclosed, not zero-filled.
# Source Sans 3 and the two sign colours match the surrounding panel. The final
# Shiny page is the visual QA surface; these functions have no global data inputs.

wlv_trade_chart_words <- function(lang = "pt") {
  if (identical(lang, "en")) {
    return(list(
      empty = "No data for this selection.", zero = "All available values are zero; there are no areas to show.",
      unavailable = "Unavailable", outgoing = "Exports", incoming = "Imports", value = "Value",
      transfer_outgoing = "Through exports", transfer_incoming = "Through imports",
      positive = "Positive values", negative = "Negative values", neutral = "Zero values",
      receipts = "Receipts", sending = "Sending",
      others = "Others", categories = "categories", missing = "unavailable observations",
      magnitude = "Sum of absolute values", share = "Share of total absolute value",
      zero_note = "zero-valued categories have no area", year = "Year",
      gaps = "Unavailable years remain gaps", sparse = "Available annual observations"
    ))
  }
  list(
    empty = "Sem dados para esta seleção.", zero = "Todos os valores disponíveis são zero; não há áreas a mostrar.",
    unavailable = "Indisponível", outgoing = "Exportações", incoming = "Importações", value = "Valor",
    transfer_outgoing = "Pelas exportações", transfer_incoming = "Pelas importações",
    positive = "Valores positivos", negative = "Valores negativos", neutral = "Valores zero",
    receipts = "Recebimentos", sending = "Envios",
    others = "Outros", categories = "categorias", missing = "observações indisponíveis",
    magnitude = "Soma dos valores absolutos", share = "Parcela do valor absoluto total",
    zero_note = "categorias com valor zero não têm área", year = "Ano",
    gaps = "Anos indisponíveis permanecem como lacunas", sparse = "Observações anuais disponíveis"
  )
}

wlv_trade_chart_escape <- function(text) as.character(htmltools::htmlEscape(as.character(text)))

wlv_trade_chart_format <- function(value, lang = "pt", signed = FALSE) {
  words <- wlv_trade_chart_words(lang)
  vapply(value, function(number) {
    if (!is.finite(number)) return(words$unavailable)
    formatted <- format(signif(number, 6), scientific = FALSE, trim = TRUE,
      big.mark = if (identical(lang, "en")) "," else ".",
      decimal.mark = if (identical(lang, "en")) "." else ",")
    if (signed && number > 0) paste0("+", formatted) else formatted
  }, character(1L), USE.NAMES = FALSE)
}

wlv_trade_chart_colours <- function(value) {
  ifelse(value > 0, "#b37b15", ifelse(value < 0, "#8D2028", "#68717B"))
}

# Axis labels are intentionally abbreviated; the full original remains in hover.
# Row geometry uses the actual wrapped line count, so longer labels get room.
wlv_trade_chart_labels <- function(labels, width = 24L, max_lines = 3L) {
  wrapped <- lapply(labels, function(label) {
    lines <- strwrap(label, width = width)
    if (!length(lines)) lines <- ""
    lines <- unlist(lapply(lines, function(line) {
      starts <- seq.int(1L, max(1L, nchar(line)), by = width)
      substring(line, starts, starts + width - 1L)
    }), use.names = FALSE)
    if (length(lines) > max_lines) {
      lines <- head(lines, max_lines)
      lines[[max_lines]] <- paste0(sub("\\s+$", "", substr(lines[[max_lines]], 1L, width - 1L)), "…")
    }
    lines
  })
  list(text = vapply(wrapped, function(lines) paste(wlv_trade_chart_escape(lines), collapse = "<br>"), character(1L)),
    lines = lengths(wrapped))
}

wlv_trade_mosaic_colours <- function(ids, values) {
  positive <- c("#B37B15", "#C38B24", "#D5A34E", "#AD7218", "#906014", "#E2BE79")
  negative <- c("#8D2028", "#A3323C", "#BA4E57", "#CB7077", "#7A1D25", "#D79095")
  indices <- vapply(ids, function(id) {
    codes <- utf8ToInt(enc2utf8(id))
    as.integer(sum(codes * seq_along(codes)) %% length(positive)) + 1L
  }, integer(1L))
  ifelse(values >= 0, positive[indices], negative[indices])
}

wlv_trade_mosaic_text_colours <- function(colours) {
  rgb <- grDevices::col2rgb(colours) / 255
  linear <- ifelse(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055)^2.4)
  luminance <- colSums(linear * c(0.2126, 0.7152, 0.0722))
  ifelse(luminance > 0.179, "#211C17", "#FFFFFF")
}

wlv_trade_chart_rows <- function(rows, series = FALSE) {
  required <- if (series) c("year", "value") else c("id", "label", "value")
  if (is.null(rows) || (is.data.frame(rows) && !nrow(rows))) {
    if (series) return(data.frame(year = numeric(), value = numeric(), outgoing = numeric(), incoming = numeric()))
    return(data.frame(id = character(), label = character(), value = numeric(), outgoing = numeric(), incoming = numeric()))
  }
  if (!is.data.frame(rows) || !all(required %in% names(rows))) {
    stop("Trade chart rows must contain: ", paste(required, collapse = ", "), call. = FALSE)
  }
  rows <- as.data.frame(rows, stringsAsFactors = FALSE)
  for (field in c("value", "outgoing", "incoming")) {
    if (!field %in% names(rows)) rows[[field]] <- NA_real_
    if (!is.numeric(rows[[field]])) stop("Trade chart amounts must be numeric.", call. = FALSE)
    rows[[field]][!is.finite(rows[[field]])] <- NA_real_
  }
  if (!series) {
    rows$id <- as.character(rows$id)
    rows$label <- as.character(rows$label)
    rows$id[is.na(rows$id)] <- ""
    blank <- is.na(rows$label) | !nzchar(rows$label)
    rows$label[blank] <- rows$id[blank]
  }
  rows
}

wlv_trade_chart_categories <- function(rows, lang = "pt", limit = 20L) {
  words <- wlv_trade_chart_words(lang)
  missing <- sum(!is.finite(rows$value))
  rows <- rows[is.finite(rows$value), c("id", "label", "value", "outgoing", "incoming"), drop = FALSE]
  rows <- rows[order(-abs(rows$value), rows$label, rows$id), , drop = FALSE]
  rows$grouped_count <- rep(1L, nrow(rows))
  grouped <- nrow(rows) > limit
  if (grouped) {
    keep <- limit - 1L
    while (keep + length(unique(sign(rows$value[-seq_len(keep)]))) > limit) keep <- keep - 1L
    remainder <- rows[-seq_len(keep), , drop = FALSE]
    rows <- rows[seq_len(keep), , drop = FALSE]
    for (direction in c(1, -1, 0)) {
      part <- remainder[sign(remainder$value) == direction, , drop = FALSE]
      if (!nrow(part)) next
      sign_label <- if (direction > 0) words$positive else if (direction < 0) words$negative else words$neutral
      complete_sum <- function(value) if (all(is.finite(value))) sum(value) else NA_real_
      rows <- rbind(rows, data.frame(
        id = "", label = paste0(words$others, " · ", sign_label, " (", nrow(part), ")"),
        value = sum(part$value), outgoing = complete_sum(part$outgoing), incoming = complete_sum(part$incoming),
        grouped_count = nrow(part), stringsAsFactors = FALSE
      ))
    }
  }
  rownames(rows) <- NULL
  list(rows = rows, missing = missing, grouped = grouped)
}

wlv_trade_chart_hover <- function(rows, unit, lang = "pt", metric = "transfer") {
  words <- wlv_trade_chart_words(lang)
  transfer <- identical(metric, "transfer")
  outgoing_label <- if (transfer) words$transfer_outgoing else words$outgoing
  incoming_label <- if (transfer) words$transfer_incoming else words$incoming
  incoming <- if (transfer) -rows$incoming else rows$incoming
  paste0("<b>", wlv_trade_chart_escape(rows$label), "</b><br>", words$value, ": ",
    wlv_trade_chart_format(rows$value, lang, signed = TRUE), " ", wlv_trade_chart_escape(unit),
    "<br>", outgoing_label, ": ", wlv_trade_chart_format(rows$outgoing, lang, signed = transfer), " ", wlv_trade_chart_escape(unit),
    "<br>", incoming_label, ": ", wlv_trade_chart_format(incoming, lang, signed = transfer), " ", wlv_trade_chart_escape(unit))
}

wlv_trade_chart_layout <- function(chart, title, unit, note, lang = "pt", height = 440L, left = 64L, show_title = TRUE, bottom = 58L) {
  subtitle <- paste(c(unit, note)[nzchar(c(unit, note))], collapse = " · ")
  subtitle_lines <- strwrap(subtitle, width = 38L)
  title_lines <- strwrap(title, width = 38L)
  top_margin <- if (show_title) max(90L, 44L + 20L * length(title_lines) + 13L * length(subtitle_lines)) else 12L
  title_text <- if (show_title) paste0(paste(wlv_trade_chart_escape(title_lines), collapse = "<br>"), "<br><sup>",
    paste(wlv_trade_chart_escape(subtitle_lines), collapse = "<br>"), "</sup>") else ""
  chart <- plotly::layout(chart,
    title = list(text = title_text,
      x = 0, xanchor = "left", y = 0.98, yanchor = "top", font = list(size = 17)),
    font = list(family = "'Source Sans 3', sans-serif", size = 13, color = "#292B2E"),
    paper_bgcolor = "rgba(0,0,0,0)", plot_bgcolor = "rgba(0,0,0,0)",
    separators = if (identical(lang, "en")) ".," else ",.",
    margin = list(l = left, r = if (left < 10L) 4L else 24L, b = bottom, t = top_margin, pad = if (left < 10L) 0 else 6),
    autosize = TRUE, showlegend = FALSE,
    hoverlabel = list(bgcolor = "#FFFFFF", bordercolor = "#D8DBDF", font = list(color = "#292B2E")))
  chart$height <- height
  chart$x$layout$height <- height
  chart <- plotly::event_register(chart, "plotly_click")
  chart <- plotly::config(chart, responsive = TRUE, displaylogo = FALSE, scrollZoom = FALSE,
    modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d"))
  chart <- htmlwidgets::onRender(chart, "function(el,x){if(x.layout && x.layout.height){el.style.height=x.layout.height+'px';}}")
  attr(chart, "wlv_trade_chart_padding") <- c(top = top_margin, bottom = bottom)
  attr(chart, "wlv_trade_chart_note") <- note
  chart
}

wlv_trade_chart_empty <- function(title, unit, lang, source, message = NULL, show_title = TRUE) {
  if (is.null(message)) message <- wlv_trade_chart_words(lang)$empty
  chart <- plotly::plot_ly(x = numeric(), y = numeric(), type = "scatter", mode = "markers", source = source)
  chart <- plotly::layout(chart, xaxis = list(visible = FALSE), yaxis = list(visible = FALSE),
    annotations = list(list(x = 0.5, y = 0.5, xref = "paper", yref = "paper", showarrow = FALSE,
      text = wlv_trade_chart_escape(message), font = list(size = 15, color = "#68717B"))))
  wlv_trade_chart_layout(chart, title, unit, "", lang, show_title = show_title)
}

wlv_trade_rank_chart <- function(rows, unit, title, lang = "pt", source = "trade_rank", metric = "transfer", show_title = TRUE) {
  words <- wlv_trade_chart_words(lang)
  prepared <- wlv_trade_chart_categories(wlv_trade_chart_rows(rows), lang)
  rows <- prepared$rows
  if (!nrow(rows)) return(wlv_trade_chart_empty(title, unit, lang, source, show_title = show_title))
  if (identical(metric, "transfer")) {
    rows <- rows[order(rows$value, rows$label, rows$id), , drop = FALSE]
    rownames(rows) <- NULL
  }
  note <- if (prepared$missing) paste(prepared$missing, words$missing) else ""
  labels <- wlv_trade_chart_labels(rows$label)
  row_heights <- pmax(36L, 18L * labels$lines + 14L)
  body_height <- max(300L, sum(row_heights) + 16L)
  positions <- (body_height - sum(row_heights)) / 2 + cumsum(row_heights) - row_heights / 2
  chart <- plotly::add_trace(plotly::plot_ly(source = source), x = rows$value, y = positions, type = "bar", orientation = "h",
    width = rep(22, nrow(rows)),
    customdata = rows$id, text = wlv_trade_chart_hover(rows, unit, lang, metric), textposition = "none", hovertemplate = "%{text}<extra></extra>",
    marker = list(color = wlv_trade_chart_colours(rows$value), line = list(color = "#FFFFFF", width = 0.5)))
  chart <- plotly::layout(chart,
    xaxis = list(title = "", rangemode = "tozero", zeroline = TRUE, zerolinecolor = "#59616B",
      zerolinewidth = 1.3, gridcolor = "#E8EAED", tickformat = ".3~s", automargin = TRUE, fixedrange = TRUE),
    yaxis = list(title = "", tickvals = positions, ticktext = labels$text, range = c(body_height, 0),
      showgrid = FALSE, zeroline = FALSE, automargin = TRUE, fixedrange = TRUE), bargap = 0.28)
  chart <- wlv_trade_chart_layout(chart, title, unit, note, lang, left = 174L, show_title = show_title)
  chart$height <- body_height + sum(attr(chart, "wlv_trade_chart_padding"))
  chart$x$layout$height <- chart$height
  attr(chart, "wlv_trade_chart_rows") <- rows
  attr(chart, "wlv_trade_rank_geometry") <- list(row_heights = row_heights, line_counts = labels$lines, positions = positions, body_height = body_height)
  chart
}

wlv_trade_series_chart <- function(rows, unit, title, lang = "pt", source = "trade_series", metric = "transfer", show_title = TRUE) {
  words <- wlv_trade_chart_words(lang)
  rows <- wlv_trade_chart_rows(rows, series = TRUE)
  if (!nrow(rows)) return(wlv_trade_chart_empty(title, unit, lang, source, show_title = show_title))
  rows$year <- suppressWarnings(as.numeric(as.character(rows$year)))
  rows <- rows[is.finite(rows$year) & rows$year == floor(rows$year), , drop = FALSE]
  if (!nrow(rows) || !any(is.finite(rows$value))) return(wlv_trade_chart_empty(title, unit, lang, source, show_title = show_title))
  if (anyDuplicated(rows$year)) stop("Trade series must have one row per year.", call. = FALSE)
  rows <- merge(data.frame(year = seq.int(min(rows$year), max(rows$year))), rows, by = "year", all.x = TRUE, sort = TRUE)
  rows$label <- as.character(rows$year)
  sparse <- sum(is.finite(rows$value)) < 3L
  note <- c(paste0(min(rows$year), "–", max(rows$year)), if (sparse) words$sparse,
    if (anyNA(rows$value)) words$gaps)
  chart <- plotly::plot_ly(x = rows$year, y = rows$value, type = "scatter",
    mode = if (sparse) "markers" else "lines+markers", connectgaps = FALSE, source = source,
    customdata = as.character(rows$year), text = wlv_trade_chart_hover(rows, unit, lang, metric), hovertemplate = "%{text}<extra></extra>",
    line = if (sparse) NULL else list(color = "#59616B", width = 2),
    marker = list(color = wlv_trade_chart_colours(rows$value), size = 7,
      line = list(color = "#FFFFFF", width = 1)))
  chart <- plotly::layout(chart,
    xaxis = list(title = "", tickformat = "d", dtick = if (nrow(rows) <= 8L) 1 else NULL,
      gridcolor = "#E8EAED", showline = TRUE, linecolor = "#BBC1C8", automargin = TRUE, fixedrange = TRUE),
    yaxis = list(title = "", rangemode = "tozero", zeroline = TRUE, zerolinecolor = "#59616B",
      zerolinewidth = 1.3, gridcolor = "#E8EAED", tickformat = ".3~s", automargin = TRUE, fixedrange = TRUE))
  chart <- wlv_trade_chart_layout(chart, title, unit, paste(note, collapse = " · "), lang, show_title = show_title)
  attr(chart, "wlv_trade_chart_rows") <- rows
  chart
}

wlv_trade_composition_chart <- function(rows, unit, title, lang = "pt", source = "trade_composition", metric = "transfer", show_title = TRUE) {
  words <- wlv_trade_chart_words(lang)
  prepared <- wlv_trade_chart_categories(wlv_trade_chart_rows(rows), lang, limit = Inf)
  rows <- prepared$rows
  if (!nrow(rows)) return(wlv_trade_chart_empty(title, unit, lang, source, show_title = show_title))
  zero_count <- sum(rows$grouped_count[rows$value == 0])
  rows <- rows[rows$value != 0, , drop = FALSE]
  if (!nrow(rows)) return(wlv_trade_chart_empty(title, unit, lang, source, words$zero, show_title = show_title))
  note <- c(if (zero_count) paste(zero_count, words$zero_note),
    if (prepared$missing) paste(prepared$missing, words$missing))
  absolute_total <- sum(abs(rows$value))
  share <- abs(rows$value) / absolute_total
  hover <- paste0(wlv_trade_chart_hover(rows, unit, lang, metric), "<br>", words$share, ": ",
    wlv_trade_chart_format(100 * share, lang), "%")
  label <- wlv_trade_chart_labels(rows$label, width = 22L, max_lines = 2L)$text
  percent <- ifelse(share < 0.0005,
    if (identical(lang, "en")) "&lt;0.1%" else "&lt;0,1%",
    paste0(wlv_trade_chart_format(round(share * 100, 1), lang), "%"))
  template <- ifelse(share >= 0.018, paste0("<b>", percent, "</b><br>", label), paste0("<b>", percent, "</b>"))
  colours <- wlv_trade_mosaic_colours(ifelse(nzchar(rows$id), rows$id, rows$label), rows$value)
  # Adjacent domains keep each sign contiguous without drawing group boxes.
  # Their widths use the same absolute total as every tile percentage.
  nodes <- data.frame(id = paste0("leaf-", seq_len(nrow(rows))), parent = "", label = rows$label,
    area = abs(rows$value), customdata = rows$id, colour = colours, text = hover, template = template,
    font_size = pmin(36, pmax(12, round(12 + 50 * sqrt(share)))))
  boundary <- sum(nodes$area[rows$value < 0]) / absolute_total
  chart <- plotly::plot_ly(source = source)
  for (direction in c(-1, 1)) {
    part <- nodes[sign(rows$value) == direction, , drop = FALSE]
    if (!nrow(part)) next
    domain <- if (direction < 0) c(0, boundary) else c(boundary, 1)
    chart <- plotly::add_trace(chart, type = "treemap", inherit = FALSE,
      ids = part$id, labels = wlv_trade_chart_escape(part$label),
      parents = part$parent, values = part$area, branchvalues = "total", sort = TRUE,
      domain = list(x = domain, y = c(0, 1)),
      customdata = part$customdata, text = part$text,
      texttemplate = part$template, textposition = "middle center", hovertemplate = "%{text}<extra></extra>",
      marker = list(colors = part$colour, line = list(color = "#FFFFFF", width = 1),
        pad = list(t = 0, r = 0, b = 0, l = 0)),
      pathbar = list(visible = FALSE), tiling = list(pad = 0, packing = "squarify", squarifyratio = 1),
      root = list(color = "rgba(0,0,0,0)"),
      insidetextfont = list(color = wlv_trade_mosaic_text_colours(part$colour), size = part$font_size))
  }
  chart <- wlv_trade_chart_layout(chart, title, unit, paste(note, collapse = " · "), lang, height = 540L, left = 4L,
    show_title = show_title, bottom = 4L)
  # Plotly scales each tile label to fit. Hide labels that become unreadable
  # without imposing a uniform font size on the larger tiles or changing data.
  chart <- htmlwidgets::onRender(chart, "function(el) {
    if (el._wlvTradeMosaicLabelsCleanup) el._wlvTradeMosaicLabelsCleanup();
    var frame;
    function apply() {
      frame = null;
      el.querySelectorAll('.treemaplayer text.slicetext').forEach(function(text) {
        var matrix = text.getScreenCTM();
        var size = parseFloat(window.getComputedStyle(text).fontSize);
        if (!matrix || !Number.isFinite(size)) return;
        var scale = Math.min(Math.hypot(matrix.a, matrix.b), Math.hypot(matrix.c, matrix.d));
        text.style.opacity = size * scale < 10 ? '0' : '';
      });
    }
    function schedule() {
      if (frame != null) window.cancelAnimationFrame(frame);
      frame = window.requestAnimationFrame(apply);
    }
    if (typeof el.on === 'function') el.on('plotly_afterplot', schedule);
    el._wlvTradeMosaicLabelsCleanup = function() {
      if (frame != null) window.cancelAnimationFrame(frame);
      if (typeof el.removeListener === 'function') el.removeListener('plotly_afterplot', schedule);
    };
    schedule();
  }")
  attr(chart, "wlv_trade_chart_rows") <- rows
  chart
}
