# Method-specific display contracts for canonical WLVDB result arrays.

wlv_display_metadata_columns <- function() {
  c(
    "canonical_unit", "display_unit", "display_multiplier",
    "index_base_year", "index_storage_base"
  )
}

wlv_legacy_method_metadata_columns <- function() {
  c(
    "code", "name", "description", "observation",
    "group", "type", "reverted"
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
  if (!is.data.frame(metadata)) {
    stop(
      sprintf(
        "Method-specific display metadata `%s` has an incomplete schema.",
        path
      ),
      call. = FALSE
    )
  }
  display_columns <- wlv_display_metadata_columns()
  present_display_columns <- intersect(display_columns, names(metadata))
  if (!length(present_display_columns)) {
    legacy_columns <- wlv_legacy_method_metadata_columns()
    if (any(!legacy_columns %in% names(metadata))) {
      stop(
        sprintf(
          "Method-specific display metadata `%s` has an incomplete schema.",
          path
        ),
        call. = FALSE
      )
    }
    legacy_codes <- as.character(metadata$code)
    if (
      length(legacy_codes) != nrow(metadata) || anyNA(legacy_codes) ||
        any(!nzchar(legacy_codes)) || anyDuplicated(legacy_codes) ||
        !setequal(legacy_codes, indicators)
    ) {
      stop(
        sprintf(
          "Legacy method metadata `%s` has invalid or non-exact coverage.",
          path
        ),
        call. = FALSE
      )
    }
    if (isTRUE(warn_legacy)) {
      warning(
        sprintf(
          paste0(
            "Method `%s` has legacy method metadata without display fields; ",
            "using display_multiplier = 1 and legacy percent presentation rules."
          ),
          method_dir
        ),
        call. = FALSE
      )
    }
    return(wlv_legacy_display_contract(
      method_dir,
      method,
      indicators,
      legacy_metadata,
      warn = FALSE
    ))
  }
  required <- c("code", display_columns)
  if (any(!required %in% names(metadata))) {
    stop(
      sprintf(
        "Method-specific display metadata `%s` has a partial modern schema.",
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
  # The shared legacy catalog remains authoritative for labels/grouping only.
  # Requiring coverage here does not import its presentation type.
  invisible(wlv_legacy_indicator_types(legacy_metadata, indicators))

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
    legacy_type = rep(NA_character_, length(indicators)),
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
  character_columns <- c(
    "method_dir", "method", "indicator", "canonical_unit", "display_unit",
    "index_base_year", "metadata_source", "legacy_type"
  )
  if (
    any(!vapply(contracts[character_columns], is.character, logical(1L))) ||
      !is.numeric(contracts$display_multiplier) ||
      !is.numeric(contracts$index_storage_base)
  ) {
    stop("Display contracts contain invalid field types.",
      call. = FALSE
    )
  }
  keys <- paste(contracts$method, contracts$indicator, sep = "\034")
  if (
    anyNA(contracts[c("method_dir", "method", "indicator", "metadata_source")]) ||
      any(!nzchar(as.character(contracts$method))) ||
      any(!nzchar(as.character(contracts$method_dir))) ||
      any(!nzchar(as.character(contracts$indicator))) ||
      anyDuplicated(keys) ||
      any(!contracts$metadata_source %in% c("method_metadata", "legacy_fallback")) ||
      anyNA(contracts$display_multiplier) ||
      any(!is.finite(contracts$display_multiplier)) ||
      any(contracts$display_multiplier <= 0)
  ) {
    stop("Display contracts contain invalid or duplicate rows.", call. = FALSE)
  }
  fallback <- contracts$metadata_source == "legacy_fallback"
  method_sources <- tapply(
    contracts$metadata_source,
    contracts$method,
    function(value) length(unique(value))
  )
  if (any(method_sources != 1L)) {
    stop("Each method must use exactly one display metadata source.",
      call. = FALSE
    )
  }
  invalid_fallback_type <- fallback & (
    is.na(contracts$legacy_type) |
      !nzchar(as.character(contracts$legacy_type))
  )
  if (any(invalid_fallback_type)) {
    stop("Legacy display fallback requires an explicit presentation type.",
      call. = FALSE
    )
  }
  if (any(!fallback & !is.na(contracts$legacy_type))) {
    stop("Modern display contracts must not carry legacy presentation types.",
      call. = FALSE
    )
  }
  if (any(fallback & contracts$display_multiplier != 1)) {
    stop("Legacy display fallback must keep display_multiplier = 1.",
      call. = FALSE
    )
  }
  modern <- !fallback
  invalid_modern_units <- modern & (
    is.na(contracts$canonical_unit) |
      !nzchar(contracts$canonical_unit) |
      is.na(contracts$display_unit) |
      !nzchar(contracts$display_unit)
  )
  is_index <- modern & !is.na(contracts$canonical_unit) &
    contracts$canonical_unit == "index"
  invalid_modern_index <- is_index & (
    is.na(contracts$index_base_year) |
      !grepl("^[0-9]{4}$", contracts$index_base_year) |
      is.na(contracts$index_storage_base) |
      !is.finite(contracts$index_storage_base) |
      contracts$index_storage_base <= 0 |
      !contracts$display_unit %in% c("index", "index_point")
  )
  invalid_modern_non_index <- modern & !is_index & (
    !is.na(contracts$index_base_year) |
      !is.na(contracts$index_storage_base)
  )
  invalid_fallback_units <- fallback & (
    !is.na(contracts$canonical_unit) |
      !is.na(contracts$display_unit) |
      !is.na(contracts$index_base_year) |
      !is.na(contracts$index_storage_base)
  )
  if (
    any(invalid_modern_units) || any(invalid_modern_index) ||
      any(invalid_modern_non_index) || any(invalid_fallback_units)
  ) {
    stop("Display contracts contain inconsistent unit metadata.",
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

wlv_has_observations <- function(value) {
  if (!is.numeric(value)) {
    stop("Observation checks require numeric values.", call. = FALSE)
  }
  any(!is.na(value))
}

wlv_observed_axis_labels <- function(value, axis) {
  if (
    !is.numeric(value) || is.null(dim(value)) || is.null(dimnames(value)) ||
      !is.numeric(axis) || length(axis) != 1L || is.na(axis) ||
      axis %% 1 != 0 || axis < 1L || axis > length(dim(value))
  ) {
    stop(
      "Observed-axis selection requires a labelled numeric array and one axis.",
      call. = FALSE
    )
  }
  axis <- as.integer(axis)
  labels <- dimnames(value)[[axis]]
  if (
    is.null(labels) || !length(labels) || anyNA(labels) ||
      any(!nzchar(labels)) || anyDuplicated(labels)
  ) {
    stop("Observed axes must have unique non-empty labels.", call. = FALSE)
  }
  observed <- apply(value, axis, wlv_has_observations)
  labels[as.logical(observed)]
}

wlv_validate_method_indicator_availability <- function(value) {
  if (
    !is.data.frame(value) || !nrow(value) ||
      any(!c("method", "indicator") %in% names(value)) ||
      anyNA(value[c("method", "indicator")]) ||
      any(!nzchar(as.character(value$method))) ||
      any(!nzchar(as.character(value$indicator))) ||
      anyDuplicated(paste(value$method, value$indicator, sep = "\034"))
  ) {
    stop("Method indicator availability is invalid or duplicated.",
      call. = FALSE
    )
  }
  invisible(value)
}

wlv_method_indicator_availability <- function(values, indicator_axis = 2L) {
  if (
    !is.list(values) || !length(values) || is.null(names(values)) ||
      anyNA(names(values)) || any(!nzchar(names(values))) ||
      anyDuplicated(names(values)) || !is.numeric(indicator_axis) ||
      length(indicator_axis) != 1L || is.na(indicator_axis) ||
      indicator_axis %% 1 != 0
  ) {
    stop("Method arrays and the indicator axis are invalid.", call. = FALSE)
  }
  indicator_axis <- as.integer(indicator_axis)
  parts <- lapply(seq_along(values), function(index) {
    array <- values[[index]]
    if (
      !is.numeric(array) || is.null(dim(array)) || is.null(dimnames(array)) ||
        indicator_axis < 1L || indicator_axis > length(dim(array))
    ) {
      stop("Method availability requires labelled numeric arrays.",
        call. = FALSE
      )
    }
    indicators <- dimnames(array)[[indicator_axis]]
    if (
      is.null(indicators) || !length(indicators) || anyNA(indicators) ||
        any(!nzchar(indicators)) || anyDuplicated(indicators)
    ) {
      stop("Method indicator axes must have unique labels.", call. = FALSE)
    }
    data.frame(
      method = rep(names(values)[[index]], length(indicators)),
      indicator = indicators,
      stringsAsFactors = FALSE
    )
  })
  availability <- do.call(rbind, parts)
  row.names(availability) <- NULL
  wlv_validate_method_indicator_availability(availability)
  availability
}

wlv_validate_display_contract_coverage <- function(contracts, availability) {
  wlv_validate_display_contracts(contracts)
  wlv_validate_method_indicator_availability(availability)
  resolved <- paste(contracts$method, contracts$indicator, sep = "\034")
  expected <- paste(availability$method, availability$indicator, sep = "\034")
  missing <- setdiff(expected, resolved)
  unexpected <- setdiff(resolved, expected)
  if (length(missing) || length(unexpected)) {
    printable <- function(keys) gsub("\034", "/", keys, fixed = TRUE)
    details <- c(
      if (length(missing)) {
        paste0("missing: ", paste(printable(missing), collapse = ", "))
      },
      if (length(unexpected)) {
        paste0("unexpected: ", paste(printable(unexpected), collapse = ", "))
      }
    )
    condition <- structure(
      list(
        message = sprintf(
          "Display contract coverage differs from method indicators (%s).",
          paste(details, collapse = "; ")
        ),
        call = NULL,
        missing = missing,
        unexpected = unexpected
      ),
      class = c(
        "wlv_display_contract_coverage_error",
        "error",
        "condition"
      )
    )
    stop(condition)
  }
  invisible(contracts)
}

wlv_methods_with_indicator <- function(availability, methods, indicator) {
  wlv_validate_method_indicator_availability(availability)
  if (
    !is.character(methods) || anyNA(methods) || any(!nzchar(methods)) ||
      anyDuplicated(methods) || !is.character(indicator) ||
      length(indicator) != 1L || is.na(indicator) || !nzchar(indicator)
  ) {
    stop("Methods and indicator must be unique non-empty identifiers.",
      call. = FALSE
    )
  }
  unknown_methods <- setdiff(methods, availability$method)
  if (length(unknown_methods)) {
    stop(
      sprintf(
        "Unknown data method(s): %s.",
        paste(unknown_methods, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  methods[methods %in% availability$method[
    availability$indicator == indicator
  ]]
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
  if (identical(row$metadata_source[[1L]], "legacy_fallback")) {
    return(as.character(row$legacy_type[[1L]]))
  }
  unit <- as.character(row$display_unit[[1L]])
  if (identical(unit, "percent")) return("percent")
  if (identical(unit, "usd")) return("usd")
  if (identical(unit, "person")) return("integer")
  if (identical(unit, "hour")) return("hours")
  if (unit %in% c("index", "index_point")) return("index")
  if (startsWith(unit, "abstract_labour_hour")) return("value")
  "neutral"
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
  columns <- c(
    "method_dir", "method", "indicator", wlv_display_metadata_columns(),
    "metadata_source", "legacy_type"
  )
  ordered <- contracts[
    order(
      contracts$method_dir,
      contracts$method,
      contracts$indicator,
      method = "radix"
    ),
    columns,
    drop = FALSE
  ]
  character_columns <- c(
    "method_dir", "method", "indicator", "canonical_unit", "display_unit",
    "index_base_year", "metadata_source", "legacy_type"
  )
  ordered[character_columns] <- lapply(
    ordered[character_columns],
    as.character
  )
  ordered$display_multiplier <- as.double(ordered$display_multiplier)
  ordered$index_storage_base <- as.double(ordered$index_storage_base)
  row.names(ordered) <- NULL
  payload <- serialize(ordered, connection = NULL, ascii = TRUE, version = 2L)
  paste0(
    "wlv-display-contract-v2:",
    paste(sprintf("%02x", as.integer(payload)), collapse = "")
  )
}
