# Method-specific display contracts for canonical WLVDB result arrays.

wlv_display_metadata_columns <- function() {
  c(
    "canonical_unit", "display_unit", "display_multiplier",
    "index_base_year", "index_storage_base"
  )
}

wlv_validate_legacy_indicator_metadata <- function(metadata) {
  if (
    !is.data.frame(metadata) ||
      any(!c("value", "type") %in% names(metadata)) ||
      anyNA(metadata[c("value", "type")]) ||
      any(!nzchar(as.character(metadata$value))) ||
      any(!nzchar(as.character(metadata$type))) ||
      anyDuplicated(as.character(metadata$value))
  ) {
    stop(
      "Legacy indicator metadata must contain unique `value` and `type` fields.",
      call. = FALSE
    )
  }
  invisible(metadata)
}

wlv_legacy_indicator_types <- function(metadata, indicators) {
  wlv_validate_legacy_indicator_metadata(metadata)
  rows <- match(indicators, as.character(metadata$value))
  if (anyNA(rows)) {
    stop(
      sprintf(
        "Legacy metadata is missing indicator(s): %s.",
        paste(indicators[is.na(rows)], collapse = ", ")
      ),
      call. = FALSE
    )
  }
  as.character(metadata$type[rows])
}

wlv_legacy_display_contract <- function(
    method_dir,
    method,
    indicators,
    legacy_metadata,
    warn = TRUE) {
  if (isTRUE(warn)) {
    warning(
      sprintf(
        paste0(
          "Method `%s` has no method-specific display metadata; using ",
          "display_multiplier = 1 and legacy percent presentation rules."
        ),
        method_dir
      ),
      call. = FALSE
    )
  }
  data.frame(
    method_dir = rep(method_dir, length(indicators)),
    method = rep(method, length(indicators)),
    indicator = indicators,
    canonical_unit = rep(NA_character_, length(indicators)),
    display_unit = rep(NA_character_, length(indicators)),
    display_multiplier = rep(1, length(indicators)),
    index_base_year = rep(NA_character_, length(indicators)),
    index_storage_base = rep(NA_real_, length(indicators)),
    metadata_source = rep("legacy_fallback", length(indicators)),
    legacy_type = wlv_legacy_indicator_types(legacy_metadata, indicators),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

wlv_read_method_display_contract <- function(
    path,
    method_dir,
    method,
    indicators,
    legacy_metadata,
    warn_legacy = TRUE) {
  scalar <- function(value) {
    is.character(value) && length(value) == 1L && !is.na(value) && nzchar(value)
  }
  if (!scalar(path) || !scalar(method_dir) || !scalar(method)) {
    stop("Display metadata paths and method identifiers must be non-empty.",
      call. = FALSE
    )
  }
  if (
    !is.character(indicators) || !length(indicators) || anyNA(indicators) ||
      any(!nzchar(indicators)) || anyDuplicated(indicators)
  ) {
    stop("Display indicators must be unique non-empty identifiers.",
      call. = FALSE
    )
  }
  if (!file.exists(path)) {
    return(wlv_legacy_display_contract(
      method_dir,
      method,
      indicators,
      legacy_metadata,
      warn = warn_legacy
    ))
  }

  metadata <- tryCatch(
    readRDS(path),
    error = function(error) {
      stop(
        sprintf(
          "Cannot read method-specific display metadata `%s`: %s",
          path,
          conditionMessage(error)
        ),
        call. = FALSE
      )
    }
  )
  required <- c("code", wlv_display_metadata_columns())
  if (!is.data.frame(metadata) || any(!required %in% names(metadata))) {
    stop(
      sprintf(
        "Method-specific display metadata `%s` has an incomplete schema.",
        path
      ),
      call. = FALSE
    )
  }
  if (
    !is.character(metadata$code) ||
      !is.character(metadata$canonical_unit) ||
      !is.character(metadata$display_unit) ||
      !is.numeric(metadata$display_multiplier) ||
      !is.character(metadata$index_base_year) ||
      !is.numeric(metadata$index_storage_base)
  ) {
    stop(
      sprintf(
        "Method-specific display metadata `%s` has invalid field types.",
        path
      ),
      call. = FALSE
    )
  }
  metadata$code <- as.character(metadata$code)
  if (
    anyNA(metadata$code) || any(!nzchar(metadata$code)) ||
      anyDuplicated(metadata$code)
  ) {
    stop(
      sprintf("Method-specific display metadata `%s` has duplicate codes.", path),
      call. = FALSE
    )
  }
  missing <- setdiff(indicators, metadata$code)
  extra <- setdiff(metadata$code, indicators)
  if (length(missing) || length(extra)) {
    details <- c(
      if (length(missing)) paste0("missing: ", paste(missing, collapse = ", ")),
      if (length(extra)) paste0("unexpected: ", paste(extra, collapse = ", "))
    )
    stop(
      sprintf(
        "Method-specific display metadata `%s` has non-exact coverage (%s).",
        path,
        paste(details, collapse = "; ")
      ),
      call. = FALSE
    )
  }
  metadata <- metadata[match(indicators, metadata$code), , drop = FALSE]
  multiplier <- suppressWarnings(as.numeric(metadata$display_multiplier))
  storage_base <- suppressWarnings(as.numeric(metadata$index_storage_base))
  canonical_unit <- as.character(metadata$canonical_unit)
  display_unit <- as.character(metadata$display_unit)
  if (
    anyNA(canonical_unit) || any(!nzchar(canonical_unit)) ||
      anyNA(display_unit) || any(!nzchar(display_unit)) ||
      anyNA(multiplier) || any(!is.finite(multiplier)) || any(multiplier <= 0)
  ) {
    stop(
      sprintf("Method-specific display metadata `%s` has invalid units or multipliers.", path),
      call. = FALSE
    )
  }
  is_index <- canonical_unit == "index"
  base_year <- as.character(metadata$index_base_year)
  if (
    any(is_index & (is.na(base_year) | !grepl("^[0-9]{4}$", base_year))) ||
      any(is_index & (is.na(storage_base) | !is.finite(storage_base) |
        storage_base <= 0)) ||
      any(is_index & !display_unit %in% c("index", "index_point")) ||
      any(!is_index & (!is.na(base_year) | !is.na(storage_base)))
  ) {
    stop(
      sprintf("Method-specific display metadata `%s` has invalid index bases.", path),
      call. = FALSE
    )
  }

  data.frame(
    method_dir = rep(method_dir, length(indicators)),
    method = rep(method, length(indicators)),
    indicator = indicators,
    canonical_unit = canonical_unit,
    display_unit = display_unit,
    display_multiplier = multiplier,
    index_base_year = base_year,
    index_storage_base = storage_base,
    metadata_source = rep("method_metadata", length(indicators)),
    legacy_type = wlv_legacy_indicator_types(legacy_metadata, indicators),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

wlv_validate_display_contracts <- function(contracts) {
  required <- c(
    "method_dir", "method", "indicator", wlv_display_metadata_columns(),
    "metadata_source", "legacy_type"
  )
  if (!is.data.frame(contracts) || !nrow(contracts) ||
      any(!required %in% names(contracts))) {
    stop("Display contracts have an incomplete schema.", call. = FALSE)
  }
  if (!is.numeric(contracts$display_multiplier)) {
    stop("Display contracts contain an invalid multiplier field.",
      call. = FALSE
    )
  }
  keys <- paste(contracts$method, contracts$indicator, sep = "\034")
  if (
    anyNA(contracts[c("method_dir", "method", "indicator", "metadata_source", "legacy_type")]) ||
      any(!nzchar(as.character(contracts$method))) ||
      any(!nzchar(as.character(contracts$method_dir))) ||
      any(!nzchar(as.character(contracts$indicator))) ||
      any(!nzchar(as.character(contracts$legacy_type))) ||
      anyDuplicated(keys) ||
      any(!contracts$metadata_source %in% c("method_metadata", "legacy_fallback")) ||
      anyNA(contracts$display_multiplier) ||
      any(!is.finite(contracts$display_multiplier)) ||
      any(contracts$display_multiplier <= 0)
  ) {
    stop("Display contracts contain invalid or duplicate rows.", call. = FALSE)
  }
  fallback <- contracts$metadata_source == "legacy_fallback"
  if (any(fallback & contracts$display_multiplier != 1)) {
    stop("Legacy display fallback must keep display_multiplier = 1.",
      call. = FALSE
    )
  }
  method_to_dir <- tapply(
    as.character(contracts$method_dir),
    as.character(contracts$method),
    function(value) length(unique(value))
  )
  dir_to_method <- tapply(
    as.character(contracts$method),
    as.character(contracts$method_dir),
    function(value) length(unique(value))
  )
  if (any(method_to_dir != 1L) || any(dir_to_method != 1L)) {
    stop(
      "Display contracts require a one-to-one method directory mapping.",
      call. = FALSE
    )
  }
  invisible(contracts)
}

wlv_bind_display_contracts <- function(values) {
  if (!is.list(values) || !length(values) ||
      any(!vapply(values, is.data.frame, logical(1L)))) {
    stop("Method display contracts must be a non-empty list of data frames.",
      call. = FALSE
    )
  }
  contracts <- do.call(rbind, values)
  row.names(contracts) <- NULL
  wlv_validate_display_contracts(contracts)
  contracts
}

wlv_display_contract_row <- function(contracts, method, indicator) {
  wlv_validate_display_contracts(contracts)
  row <- contracts$method == method & contracts$indicator == indicator
  if (sum(row) != 1L) {
    stop(
      sprintf("No unique display contract exists for `%s/%s`.", method, indicator),
      call. = FALSE
    )
  }
  contracts[row, , drop = FALSE]
}

wlv_effective_display_multiplier <- function(contracts, method, indicator) {
  row <- wlv_display_contract_row(contracts, method, indicator)
  if (identical(row$metadata_source[[1L]], "method_metadata")) {
    return(as.numeric(row$display_multiplier[[1L]]))
  }
  if (identical(row$legacy_type[[1L]], "percent")) 100 else 1
}

wlv_display_values <- function(
    value,
    method,
    indicator,
    contracts,
    legacy_metadata = NULL) {
  if (!is.numeric(value)) {
    stop("Display conversion requires numeric values.", call. = FALSE)
  }
  value * wlv_effective_display_multiplier(contracts, method, indicator)
}

wlv_display_array <- function(
    value,
    method,
    indicator_axis,
    contracts,
    legacy_metadata = NULL) {
  if (!is.numeric(value) || is.null(dim(value)) || is.null(dimnames(value))) {
    stop("Display array conversion requires a labelled numeric array.",
      call. = FALSE
    )
  }
  if (is.character(indicator_axis)) {
    axes <- which(names(dimnames(value)) == indicator_axis)
    if (length(axes) != 1L) {
      stop("The named indicator axis is absent or ambiguous.", call. = FALSE)
    }
    indicator_axis <- axes[[1L]]
  }
  if (
    !is.numeric(indicator_axis) || length(indicator_axis) != 1L ||
      is.na(indicator_axis) || indicator_axis < 1L ||
      indicator_axis > length(dim(value)) || indicator_axis %% 1 != 0
  ) {
    stop("`indicator_axis` must select one array dimension.", call. = FALSE)
  }
  indicators <- dimnames(value)[[as.integer(indicator_axis)]]
  if (is.null(indicators) || anyNA(indicators) || anyDuplicated(indicators)) {
    stop("The indicator axis must have unique labels.", call. = FALSE)
  }
  multipliers <- vapply(
    indicators,
    function(indicator) {
      wlv_effective_display_multiplier(contracts, method, indicator)
    },
    numeric(1L)
  )
  sweep(value, as.integer(indicator_axis), multipliers, "*")
}

wlv_display_unit <- function(contracts, method, indicator) {
  row <- wlv_display_contract_row(contracts, method, indicator)
  if (identical(row$metadata_source[[1L]], "method_metadata")) {
    return(as.character(row$display_unit[[1L]]))
  }
  if (identical(row$legacy_type[[1L]], "percent")) {
    return("percent")
  }
  paste0("legacy:", row$legacy_type[[1L]])
}

wlv_display_format_type <- function(contracts, method, indicator) {
  row <- wlv_display_contract_row(contracts, method, indicator)
  unit <- wlv_display_unit(contracts, method, indicator)
  if (identical(unit, "percent")) return("percent")
  if (identical(unit, "usd")) return("usd")
  if (identical(unit, "person")) return("integer")
  if (identical(unit, "hour")) return("hours")
  if (unit %in% c("index", "index_point")) return("index")
  if (startsWith(unit, "abstract_labour_hour")) return("value")
  as.character(row$legacy_type[[1L]])
}

wlv_assert_comparable_display_units <- function(
    methods,
    indicator,
    contracts) {
  units <- vapply(
    methods,
    function(method) wlv_display_unit(contracts, method, indicator),
    character(1L)
  )
  if (length(unique(units)) != 1L) {
    condition <- structure(
      list(
        message = sprintf(
          "Indicator `%s` has incompatible display units across methods: %s.",
          indicator,
          paste(paste(methods, units, sep = "="), collapse = ", ")
        ),
        call = NULL,
        indicator = indicator,
        methods = methods,
        units = units
      ),
      class = c("wlv_incompatible_display_units", "error", "condition")
    )
    stop(condition)
  }
  unname(units[[1L]])
}

wlv_excel_num_format <- function(
    method,
    indicator,
    contracts,
    legacy_metadata = NULL) {
  unit <- wlv_display_unit(contracts, method, indicator)
  if (identical(unit, "percent")) return('0.00"%"')
  type <- wlv_display_format_type(contracts, method, indicator)
  if (identical(type, "integer")) "#,##0" else "#,##0.00"
}

wlv_display_contract_version <- function(contracts) {
  wlv_validate_display_contracts(contracts)
  ordered <- contracts[order(contracts$method, contracts$indicator), ]
  paste(
    ordered$method,
    ordered$indicator,
    ordered$display_unit,
    format(ordered$display_multiplier, scientific = FALSE, trim = TRUE),
    ordered$metadata_source,
    sep = ":",
    collapse = "|"
  )
}
