# Historical ranks always use the full country universe of a single method.
# Country selections are applied by the view after these ranks are computed.
# Residual regions follow the identifiers in data/config/countries.csv.
wlv_indicator_rankings <- function(series, method,
    excluded = c("ROW", "WWW", "WW", "WA", "WE", "WL", "WM", "WLF")) {
  empty <- data.frame(method = character(), year = integer(), country = character(),
    value = numeric(), unit = character(), rank = integer(), count = integer(),
    stringsAsFactors = FALSE)
  if (!length(method)) return(empty)
  if (length(method) != 1L || !is.character(method) || is.na(method) || !nzchar(method)) {
    stop("Ranking requires exactly one non-empty method.", call. = FALSE)
  }
  if (is.null(series)) return(empty)
  columns <- c("method", "year", "country", "value", "unit")
  if (!is.data.frame(series) || !all(columns %in% names(series))) {
    stop("Ranking series must contain method, year, country, value and unit.", call. = FALSE)
  }
  if (!is.numeric(series$year) || !is.numeric(series$value)) {
    stop("Ranking years and values must be numeric.", call. = FALSE)
  }
  if (!nrow(series)) return(empty)

  keep <- !is.na(series$method) & series$method == method &
    is.finite(series$year) & !is.na(series$country) & nzchar(series$country) &
    !series$country %in% excluded
  values <- series[keep, columns, drop = FALSE]
  if (!nrow(values)) return(empty)
  # Validate before removing unavailable values: a finite/missing duplicate is
  # still ambiguous source data, not a second country or an imputed value.
  if (anyDuplicated(values[c("year", "country")])) {
    stop("Duplicate method-year-country observations in ranking series.", call. = FALSE)
  }
  values <- values[is.finite(values$value), , drop = FALSE]
  if (!nrow(values)) return(empty)
  values$method <- as.character(values$method)
  values$country <- as.character(values$country)
  values$value <- as.numeric(values$value)
  values$unit <- as.character(values$unit)
  values$rank <- integer(nrow(values))
  values$count <- integer(nrow(values))
  for (indices in split(seq_len(nrow(values)), values$year)) {
    values$rank[indices] <- as.integer(rank(-values$value[indices], ties.method = "min"))
    values$count[indices] <- length(indices)
  }
  values <- values[order(values$year, values$rank, values$country), , drop = FALSE]
  rownames(values) <- NULL
  values
}
