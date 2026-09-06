# Build one workbook from the canonical arrays only after a download is requested.
# A valid selection no longer depends on thousands of pre-generated XLSX files.
wlv_download_label <- function(language, key, fallback = key) {
  if (!key %in% rownames(language) || !"English" %in% colnames(language)) return(fallback)
  value <- as.character(language[key, "English"])
  if (length(value) == 1L && !is.na(value) && nzchar(value)) value else fallback
}

wlv_download_header <- function(method, language, selected = list()) {
  rows <- lapply(names(selected), function(label) c(paste0(label, ":"), selected[[label]]))
  rows <- c(rows, list(c("Computation method:", method$name[[1L]]),
    c("Main source:", method$source[[1L]])))
  result <- matrix(NA_character_, nrow = 6L, ncol = 2L)
  result[seq_along(rows), ] <- do.call(rbind, rows)
  result[6L, ] <- c("Name", "Code")
  result
}

wlv_aggregated_download_request <- function(method, country = NULL, indicator = NULL,
    sector = NULL, countries, sectors, metadata, methods, language, contracts) {
  nonempty <- wlv_nonempty_selection
  if (!nonempty(method) || !method %in% dimnames(countries)[[1L]] ||
      !method %in% methods$code) return(NULL)
  sector_countries <- if (method %in% names(sectors)) wlv_sector_country_codes(sectors, method) else character()
  href <- wlv_aggregated_download_href(method, country, indicator, sector, sector_countries)
  if (!nzchar(href)) return(NULL)
  method_row <- methods[methods$code == method, , drop = FALSE]
  label <- function(code, fallback = code) wlv_download_label(language, code, fallback)
  public <- intersect(metadata$value, dimnames(countries)[[3L]])
  if (nonempty(indicator) && !indicator %in% public) return(NULL)
  if (nonempty(country) && !country %in% dimnames(countries)[[4L]]) return(NULL)
  selected <- list()
  if (nonempty(country)) selected$Country <- label(paste0("ISO3.", country), country)
  if (nonempty(indicator)) selected$Indicator <- label(indicator)
  if (nonempty(sector)) selected$Sector <- label(paste0(method_row$source[[1L]], ".", sector), sector)

  if (nonempty(sector) || (nonempty(country) && nonempty(indicator))) {
    if (!method %in% names(sectors)) return(NULL)
    values <- sectors[[method]]
    axes <- dimnames(values)
    if (nonempty(indicator) && !indicator %in% axes[[2L]]) return(NULL)
    if (nonempty(sector) && !sector %in% axes[[3L]]) return(NULL)
    indicators <- if (nonempty(indicator)) indicator else intersect(public, axes[[2L]])
    if (!length(indicators)) return(NULL)
    values <- values[, indicators, if (nonempty(sector)) sector else axes[[3L]],
      if (nonempty(country)) country else axes[[4L]], drop = FALSE]
    row_axis <- if (!nonempty(indicator)) 2L else if (!nonempty(sector)) 3L else 4L
    matrix <- wlv_xlsx_export_matrix(values, row_axis, 1L)
    row_keys <- if (row_axis == 2L) rownames(matrix) else if (row_axis == 3L)
      paste0(method_row$source[[1L]], ".", rownames(matrix)) else paste0("ISO3.", rownames(matrix))
  } else {
    indicators <- if (nonempty(indicator)) indicator else public
    if (!length(indicators)) return(NULL)
    values <- countries[method, , indicators,
      if (nonempty(country)) country else dimnames(countries)[[4L]], drop = FALSE]
    row_axis <- if (nonempty(country)) 3L else 4L
    matrix <- wlv_xlsx_export_matrix(values, row_axis, 2L)
    row_keys <- if (row_axis == 3L) rownames(matrix) else paste0("ISO3.", rownames(matrix))
  }
  observed_rows <- apply(matrix, 1L, wlv_has_observations)
  observed_years <- apply(matrix, 2L, wlv_has_observations)
  if (!any(observed_rows) || !any(observed_years)) return(NULL)
  matrix <- matrix[observed_rows, observed_years, drop = FALSE]
  row_keys <- row_keys[observed_rows]
  indicators <- if (nonempty(indicator)) indicator else rownames(matrix)
  meta <- data.frame(Code = indicators,
    Name = vapply(indicators, label, character(1L)),
    Description = vapply(paste0("desc.", indicators), label, character(1L)),
    Observations = vapply(paste0("obs.", method, ".", indicators), label, character(1L)),
    row.names = NULL, stringsAsFactors = FALSE)
  list(filename = basename(href), data = matrix,
    labels = unname(vapply(row_keys, label, character(1L))), metadata = meta,
    header = wlv_download_header(method_row, language, selected), specs = method_row,
    method = method, indicators = indicators, contracts = contracts)
}

wlv_multilateral_indicator_codes <- function() {
  combinations <- expand.grid(category = c("CX", "CM", "CN", "TS", "TR", "TT"),
    scope = c("T", "P", "U"), unit = c("MP", "DP", "MV"), stringsAsFactors = FALSE)
  combinations <- combinations[!(startsWith(combinations$category, "T") & combinations$unit == "MP"), ]
  sort(apply(combinations, 1L, paste, collapse = "."))
}

wlv_multilateral_indicator_label <- function(code) {
  parts <- strsplit(code, ".", fixed = TRUE)[[1L]]
  category <- c(CX = "Exports", CM = "Imports", CN = "Net trade", TS = "Value transfers from exports",
    TR = "Value transfers from imports", TT = "Net value transfers")[[parts[[1L]]]]
  scope <- c(T = "", P = " of productive sectors", U = " of unproductive sectors")[[parts[[2L]]]]
  unit <- c(MP = " at market prices (USD)", DP = " at direct prices (USD)", MV = " in magnitude of value")[[parts[[3L]]]]
  paste0(category, scope, unit)
}

# Same identities as the original batch exporter, evaluated only for the requested
# country and partners. World totals are used only for the direct-price factor.
wlv_multilateral_matrix <- function(values, country, partners, indicator, factor = NULL) {
  parts <- strsplit(indicator, ".", fixed = TRUE)[[1L]]
  category <- parts[[1L]]; scope <- parts[[2L]]; unit <- parts[[3L]]
  if (unit == "DP" && is.null(factor)) {
    factor <- apply(values[, "exports_productive_mp", , , drop = FALSE], 1L, sum) /
      apply(values[, "exports_values", , , drop = FALSE], 1L, sum)
    factor[!is.finite(factor)] <- NA_real_
  }
  flow <- function(key, reverse) {
    if (reverse) wlv_xlsx_export_matrix(values[, key, partners, country, drop = FALSE], 3L, 1L)
    else wlv_xlsx_export_matrix(values[, key, country, partners, drop = FALSE], 4L, 1L)
  }
  component <- function(transfer, reverse) {
    if (transfer) {
      suffix <- if (unit == "MV") "values" else "dp"
      total <- flow(paste0("transfers_", suffix), reverse)
      productive <- flow(paste0("transfers_productive_", suffix), reverse)
    } else if (unit == "MP") {
      total <- flow("exports_mp", reverse)
      productive <- flow("exports_productive_mp", reverse)
    } else {
      total <- flow("exports_values", reverse)
      if (unit == "DP") total <- sweep(total, 2L, factor, "*")
      productive <- total
    }
    if (scope == "T") total else if (scope == "P") productive else total - productive
  }
  switch(category, CX = component(FALSE, FALSE), CM = component(FALSE, TRUE),
    CN = component(FALSE, FALSE) - component(FALSE, TRUE), TS = component(TRUE, FALSE),
    TR = component(TRUE, TRUE), TT = component(TRUE, TRUE) - component(TRUE, FALSE))
}

wlv_multilateral_download_request <- function(method, country, partner = NULL,
    category = NULL, scope = NULL, unit = NULL, values, methods, language) {
  nonempty <- wlv_nonempty_selection
  if (!nonempty(method) || !method %in% names(values) || !method %in% methods$code ||
      !nonempty(country)) return(NULL)
  data <- values[[method]]
  countries <- dimnames(data)[[3L]]
  if (!country %in% countries) return(NULL)
  if (nonempty(partner)) {
    if (!partner %in% countries || partner == country) return(NULL)
    codes <- wlv_multilateral_indicator_codes()
    factor <- apply(data[, "exports_productive_mp", , , drop = FALSE], 1L, sum) /
      apply(data[, "exports_values", , , drop = FALSE], 1L, sum)
    factor[!is.finite(factor)] <- NA_real_
    matrix <- do.call(rbind, lapply(codes, function(code) wlv_multilateral_matrix(data, country, partner, code, factor)))
    rownames(matrix) <- codes
    labels <- vapply(codes, wlv_multilateral_indicator_label, character(1L))
    filename <- paste(country, partner, method, "xlsx", sep = ".")
    selected <- list(Country = wlv_download_label(language, paste0("ISO3.", country), country),
      Partner = wlv_download_label(language, paste0("ISO3.", partner), partner))
  } else {
    if (!nonempty(category) || !nonempty(scope) || !nonempty(unit)) return(NULL)
    codes <- paste0(category, scope, unit)
    if (!codes %in% wlv_multilateral_indicator_codes()) return(NULL)
    matrix <- wlv_multilateral_matrix(data, country, countries, codes)
    labels <- vapply(paste0("ISO3.", countries), function(key) wlv_download_label(language, key), character(1L))
    filename <- paste(country, codes, method, "xlsx", sep = ".")
    selected <- list(Country = wlv_download_label(language, paste0("ISO3.", country), country),
      Indicator = wlv_multilateral_indicator_label(codes))
  }
  rows <- apply(matrix, 1L, wlv_has_observations)
  years <- apply(matrix, 2L, wlv_has_observations)
  if (!any(rows) || !any(years)) return(NULL)
  matrix <- matrix[rows, years, drop = FALSE]
  if (nonempty(partner)) codes <- rownames(matrix)
  method_row <- methods[methods$code == method, , drop = FALSE]
  list(filename = filename, data = matrix, labels = unname(labels[rows]),
    metadata = data.frame(Code = codes, Name = vapply(codes, wlv_multilateral_indicator_label, character(1L)), row.names = NULL),
    header = wlv_download_header(method_row, language, selected), specs = method_row)
}

wlv_write_download_request <- function(request, file) {
  if (is.null(request)) stop("No observations are available for this download.", call. = FALSE)
  save_my_xlsx(file, request$header, request$labels, request$data,
    request$metadata, request$specs, list(seq_len(nrow(request$data)) + 6L),
    list("#,##0.00"), 35, 20, method_code = request$method,
    indicator_codes = request$indicators, display_contracts = request$contracts)
}
