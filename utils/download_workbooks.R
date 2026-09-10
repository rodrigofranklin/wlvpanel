ind_type <- function(x){
  substr(x, nchar(x)-1, nchar(x))
}

wlv_country_axis_names <- function(codes, language_file, language = "English") {
  if (is.character(language) && length(language) == 1L && !is.na(language) &&
      (language %in% wlv_languages()$value ||
       sub("[-_].*$", "", tolower(language)) %in% wlv_languages()$key)) {
    language <- wlv_language_name(language)
  }
  if (
    !is.character(codes) || !length(codes) || anyNA(codes) ||
      any(!nzchar(codes)) || anyDuplicated(codes) ||
      !(is.data.frame(language_file) || is.matrix(language_file)) ||
      is.null(rownames(language_file)) || !is.character(language) ||
      length(language) != 1L || is.na(language) || !language %in% colnames(language_file)
  ) {
    stop("Country display labels require a valid country axis and language table.",
      call. = FALSE
    )
  }
  keys <- paste0("ISO3.", codes)
  missing <- setdiff(keys, rownames(language_file))
  if (length(missing)) {
    stop(
      sprintf("Country display labels are missing: %s.", paste(missing, collapse = ", ")),
      call. = FALSE
    )
  }
  labels <- as.character(language_file[keys, language, drop = TRUE])
  if (length(labels) != length(codes) || anyNA(labels) || any(!nzchar(labels))) {
    stop("Country display labels must be complete and non-empty.", call. = FALSE)
  }
  unname(labels)
}

wlv_legacy_xlsx_num_format <- function(indicator, legacy_type = NULL) {
  if (!is.null(legacy_type)) {
    if (
      !is.character(legacy_type) || length(legacy_type) != 1L ||
        is.na(legacy_type) || !nzchar(legacy_type)
    ) {
      stop("Legacy XLSX presentation types must be non-empty strings.",
        call. = FALSE
      )
    }
    if (identical(legacy_type, "percent")) return("PERCENTAGE")
    if (identical(legacy_type, "integer")) return("#,##0")
    return("#,##0.00")
  }
  type <- ind_type(indicator)
  if (identical(type, "pc")) {
    "PERCENTAGE"
  } else if (type %in% c("us", "cu", "du", "mv", "hr", "id")) {
    "#,##0.00"
  } else {
    "#,##0"
  }
}

wlv_xlsx_export_matrix <- function(value, row_axis, column_axis) {
  supplied_axes <- list(row_axis, column_axis)
  if (
    !is.numeric(value) || is.null(dim(value)) || is.null(dimnames(value)) ||
      any(!vapply(
        supplied_axes,
        function(axis) {
          is.numeric(axis) && length(axis) == 1L && !is.na(axis) &&
            axis %% 1 == 0
        },
        logical(1L)
      ))
  ) {
    stop(
      "XLSX export reshaping requires a labelled numeric array and two axes.",
      call. = FALSE
    )
  }
  axes <- as.integer(unlist(supplied_axes, use.names = FALSE))
  if (
    any(axes < 1L) || any(axes > length(dim(value))) ||
      anyDuplicated(axes)
  ) {
    stop("XLSX export axes are invalid or duplicated.", call. = FALSE)
  }
  fixed_axes <- setdiff(seq_along(dim(value)), axes)
  if (length(fixed_axes) && any(dim(value)[fixed_axes] != 1L)) {
    stop("Every non-export XLSX axis must select exactly one value.",
      call. = FALSE
    )
  }
  labels <- dimnames(value)[axes]
  if (any(vapply(labels, is.null, logical(1L))) ||
      any(vapply(labels, anyNA, logical(1L))) ||
      any(vapply(labels, function(value) any(!nzchar(value)), logical(1L))) ||
      any(vapply(labels, anyDuplicated, integer(1L)) != 0L)) {
    stop("XLSX export axes must have unique non-missing labels.",
      call. = FALSE
    )
  }
  permuted <- aperm(value, c(axes, fixed_axes))
  matrix(
    as.numeric(permuted),
    nrow = dim(value)[axes[[1L]]],
    ncol = dim(value)[axes[[2L]]],
    dimnames = labels
  )
}

wlv_prepare_xlsx_display <- function(
    my_data,
    method_code,
    indicator_codes,
    display_contracts,
    legacy_metadata = NULL) {
  data <- as.matrix(my_data)
  if (!is.numeric(data) || length(dim(data)) != 2L) {
    stop("XLSX display conversion requires a numeric matrix.", call. = FALSE)
  }
  if (
    !is.character(method_code) || length(method_code) != 1L ||
      is.na(method_code) || !nzchar(method_code)
  ) {
    stop("XLSX display conversion requires one method code.", call. = FALSE)
  }
  if (
    !is.character(indicator_codes) || !length(indicator_codes) ||
      anyNA(indicator_codes) || any(!nzchar(indicator_codes))
  ) {
    stop("XLSX display conversion requires indicator codes.", call. = FALSE)
  }
  if (length(indicator_codes) == 1L) {
    row_indicators <- rep(indicator_codes, nrow(data))
  } else if (length(indicator_codes) == nrow(data)) {
    row_indicators <- indicator_codes
  } else {
    stop(
      "XLSX indicator codes must identify one indicator or every data row.",
      call. = FALSE
    )
  }

  display_data <- data
  row_formats <- character(nrow(data))
  for (indicator in unique(row_indicators)) {
    rows <- which(row_indicators == indicator)
    contract <- wlv_display_contract_row(
      display_contracts,
      method_code,
      indicator
    )
    if (identical(contract$metadata_source[[1L]], "method_metadata")) {
      display_data[rows, ] <- wlv_display_values(
        data[rows, , drop = FALSE],
        method_code,
        indicator,
        display_contracts,
        legacy_metadata
      )
      row_formats[rows] <- wlv_excel_num_format(
        method_code,
        indicator,
        display_contracts,
        legacy_metadata
      )
    } else {
      # Legacy workbooks stored fractions and delegated percent scaling to Excel.
      row_formats[rows] <- wlv_legacy_xlsx_num_format(
        indicator,
        contract$legacy_type[[1L]]
      )
    }
  }

  formats <- unique(row_formats)
  list(
    data = display_data,
    rows_style_list = lapply(
      formats,
      function(format) which(row_formats == format) + 6L
    ),
    styles_list = as.list(formats)
  )
}

wlv_xlsx_contract_metadata <- function(
    metadata,
    method_code,
    indicator_codes,
    display_contracts) {
  if (
    !is.data.frame(metadata) || !"Code" %in% names(metadata) ||
      !is.character(method_code) || length(method_code) != 1L ||
      is.na(method_code) || !nzchar(method_code) ||
      !is.character(indicator_codes) || !length(indicator_codes) ||
      anyNA(indicator_codes) || any(!nzchar(indicator_codes))
  ) {
    stop("XLSX contract metadata inputs are invalid.", call. = FALSE)
  }
  codes <- unique(indicator_codes)
  metadata_codes <- as.character(metadata$Code)
  if (
    anyNA(metadata_codes) || any(!nzchar(metadata_codes)) ||
      anyDuplicated(metadata_codes) || !setequal(metadata_codes, codes)
  ) {
    stop(
      "XLSX metadata must cover the exported indicators exactly once.",
      call. = FALSE
    )
  }
  resolved <- do.call(rbind, lapply(metadata_codes, function(indicator) {
    wlv_display_contract_row(
      display_contracts,
      method_code,
      indicator
    )
  }))
  row.names(resolved) <- NULL
  metadata$method <- rep(method_code, nrow(metadata))
  for (column in c(
    wlv_display_metadata_columns(),
    "metadata_source",
    "legacy_type"
  )) {
    metadata[[column]] <- resolved[[column]]
  }
  metadata
}

# Function to save data to a xlsx file
save_my_xlsx <- function(file_name, header, row_names, my_data, metadata, specs,
                         rows_style_list, styles_list, width_c1, width_c2,
                         method_code = NULL, indicator_codes = NULL,
                          display_contracts = NULL, legacy_metadata = NULL) {

  my_data <- as.matrix(my_data)
  if (
    !is.numeric(my_data) || length(dim(my_data)) != 2L ||
      !is.character(row_names) || length(row_names) != nrow(my_data) ||
      anyNA(row_names) || any(!nzchar(row_names))
  ) {
    stop(
      "XLSX row labels must identify every row of one numeric data matrix.",
      call. = FALSE
    )
  }

  display_args <- c(
    !is.null(method_code),
    !is.null(indicator_codes),
    !is.null(display_contracts)
  )
  if (any(display_args) && !all(display_args)) {
    stop(
      "Method, indicator and contracts must be supplied together for XLSX display.",
      call. = FALSE
    )
  }
  if (all(display_args)) {
    display <- wlv_prepare_xlsx_display(
      my_data,
      method_code,
      indicator_codes,
      display_contracts,
      legacy_metadata
    )
    my_data <- display$data
    rows_style_list <- display$rows_style_list
    styles_list <- display$styles_list
    metadata <- wlv_xlsx_contract_metadata(
      metadata,
      method_code,
      indicator_codes,
      display_contracts
    )
  }

  ## create and format xlsx file
  wb <- createWorkbook()
  addWorksheet(wb, "data")
  addWorksheet(wb, "metadata")
  addWorksheet(wb, "specs")

  # data
  writeData(wb, "data",
            row_names,
            startRow = 7,
            colNames = FALSE)

  writeData(wb, "data",
            my_data,
            startCol = 2,
            startRow = 6,
            rowNames = TRUE)

  # header
  writeData(wb, "data",
            header,
            colNames = FALSE)

  cols <- ncol(my_data)+2

  # format Header
  freezePane(wb, "data", 7, 3)
  addStyle(wb, "data", rows = 1:4, cols = rep(1,4),
           style = createStyle(halign = "right"))
  addStyle(wb, "data", rows = 1:4, cols = rep(2,4),
           style = createStyle(textDecoration = "bold"))
  addStyle(wb, "data", rows = rep(6,cols) , cols = 1:cols,
           style = createStyle(halign = "center", textDecoration = "bold"))

  # format lines
  for (i in seq_along(styles_list)) {
    addStyle(wb, "data", gridExpand = TRUE,
             rows = rows_style_list[i] |> unlist(),
             cols = 3:cols,
             style = createStyle(numFmt = styles_list[i] |> unlist()))
  }

  temp_data <- my_data |> round(digits = 2)
  width_vec <- apply(temp_data, 2, function(x) max(nchar(as.character(x))+4, na.rm = TRUE))
  width_vec[is.infinite(width_vec)] <- "4"
  setColWidths(wb, "data", 3:cols, width_vec)
  setColWidths(wb, "data", cols = 1, widths = width_c1)
  setColWidths(wb, "data", cols = 2, widths = width_c2)

  # metadata
  writeData(wb, "metadata", metadata)

  # Methods specifications
  writeData(wb, "specs", specs)

  # save file
  saveWorkbook(wb, file_name, overwrite = TRUE)
}
