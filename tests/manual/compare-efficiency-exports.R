# Compare actual XLSX downloads before/after an optimization. No app is started.
# Usage:
# Rscript --vanilla tests/manual/compare-efficiency-exports.R \
#   --before <before-results> --after <after-results> --expect-count 15
# TEMP, TMP and TMPDIR must point to WLV_CAMPAIGN_ROOT/scratch.
# Every uncompressed ZIP member must match byte for byte, except the creation
# timestamp text in docProps/core.xml. ZIP packaging metadata is not cell data.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8"))

arguments <- commandArgs(trailingOnly = TRUE)
if (!length(arguments) || "--help" %in% arguments) {
  cat(paste0(
    "Usage: compare-efficiency-exports.R --before DIR --after DIR ",
    "[--expect-count N] [--pattern REGEX] [--output NAME.json]\n",
    "Default pattern: ^equivalence-.*\\.xlsx$\n",
    "The JSON report is written to WLV_CAMPAIGN_ROOT/results.\n"
  ))
  quit(status = if (length(arguments)) 0L else 1L)
}
if (length(arguments) %% 2L) stop("Arguments must be supplied as --name value pairs.")
argument_names <- arguments[seq.int(1L, length(arguments), 2L)]
if (anyDuplicated(argument_names)) stop("Repeated argument names are not allowed.")
if (!all(argument_names %in% c("--before", "--after", "--expect-count", "--pattern", "--output"))) {
  stop("Unknown argument; use --help.")
}
options <- setNames(as.list(arguments[seq.int(2L, length(arguments), 2L)]), argument_names)
if (is.null(options[["--before"]]) || is.null(options[["--after"]])) stop("Both --before and --after are required.")

canonical <- function(value) normalizePath(value, winslash = "/", mustWork = TRUE)
campaign <- Sys.getenv("WLV_CAMPAIGN_ROOT")
stopifnot(nzchar(campaign), file.exists(file.path(campaign, ".campaign.json")))
campaign <- canonical(campaign)
scratch <- canonical(file.path(campaign, "scratch"))
for (key in c("TEMP", "TMP", "TMPDIR")) {
  if (!nzchar(Sys.getenv(key)) || !identical(canonical(Sys.getenv(key)), scratch)) {
    stop(key, " must point to WLV_CAMPAIGN_ROOT/scratch.")
  }
}
before_dir <- canonical(options[["--before"]])
after_dir <- canonical(options[["--after"]])
stopifnot(dir.exists(before_dir), dir.exists(after_dir))
pattern <- if (is.null(options[["--pattern"]])) "^equivalence-.*\\.xlsx$" else options[["--pattern"]]
output_name <- if (is.null(options[["--output"]])) "export-equivalence.json" else options[["--output"]]
if (!grepl("^[A-Za-z0-9][A-Za-z0-9._-]*\\.json$", output_name)) stop("--output must be a JSON filename without a directory.")
expected_count <- if (is.null(options[["--expect-count"]])) NULL else as.integer(options[["--expect-count"]])
if (!is.null(expected_count) && (is.na(expected_count) || expected_count < 1L)) stop("--expect-count must be positive.")

xml_nodes <- function(document, name) xml2::xml_find_all(document, paste0("//*[local-name()='", name, "']"))
read_parts <- function(file) {
  entries <- utils::unzip(file, list = TRUE)
  if (anyDuplicated(entries$Name)) stop("Duplicate ZIP member names: ", basename(file))
  entries <- entries[!grepl("/$", entries$Name), , drop = FALSE]
  if (any(!is.finite(entries$Length)) || any(entries$Length < 0) || any(entries$Length > .Machine$integer.max)) {
    stop("Invalid or unsupported ZIP member length in ", basename(file))
  }
  result <- lapply(seq_len(nrow(entries)), function(index) {
    connection <- unz(file, entries$Name[[index]], open = "rb")
    on.exit(close(connection))
    value <- readBin(connection, what = "raw", n = entries$Length[[index]])
    if (length(value) != entries$Length[[index]]) stop("Truncated ZIP member: ", entries$Name[[index]])
    value
  })
  names(result) <- entries$Name
  result
}

without_creation_time <- function(value) {
  document <- xml2::read_xml(value)
  created <- xml2::xml_find_all(document,
    "//*[local-name()='created' and namespace-uri()='http://purl.org/dc/terms/']")
  if (length(created) != 1L) stop("core.xml must contain exactly one dcterms:created timestamp.")
  timestamp <- xml2::xml_text(created)
  if (!grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$", timestamp)) {
    stop("Unexpected core.xml creation timestamp format.")
  }
  text <- rawToChar(value)
  # Replace only the element's text, retaining its tag, namespace declarations,
  # attributes and every surrounding byte. A changed author is still a failure.
  expression <- paste0(
    "(<([A-Za-z_][A-Za-z0-9_.-]*:)?created(?:\\s[^<>]*)?>)",
    "([^<>]*)(</([A-Za-z_][A-Za-z0-9_.-]*:)?created\\s*>)"
  )
  matches <- gregexpr(expression, text, perl = TRUE)[[1L]]
  if (length(matches) != 1L || matches[[1L]] < 0L) stop("Ambiguous core.xml creation element.")
  normalized <- sub(expression, "\\1__ALLOWED_CREATION_TIMESTAMP__\\4", text, perl = TRUE)
  list(value = charToRaw(normalized), timestamp = timestamp)
}

cell_records <- function(value) {
  document <- xml2::read_xml(value)
  cells <- xml2::xml_find_all(document,
    "//*[local-name()='sheetData']/*[local-name()='row']/*[local-name()='c']")
  coordinates <- xml2::xml_attr(cells, "r")
  if (anyNA(coordinates) || anyDuplicated(coordinates)) stop("Invalid or duplicate worksheet cell coordinates.")
  # Complete cell XML retains coordinate, type, style reference, raw numeric/text
  # value, formula attributes, inline rich text and any other cell attributes.
  records <- setNames(as.character(cells), coordinates)
  types <- xml2::xml_attr(cells, "t")
  types[is.na(types)] <- "n"
  list(records = records, count = length(cells), types = as.list(table(types)))
}

summarize_workbook <- function(parts) {
  if (!"xl/workbook.xml" %in% names(parts)) stop("Missing xl/workbook.xml.")
  if (!"xl/styles.xml" %in% names(parts)) stop("Missing xl/styles.xml.")
  workbook <- xml2::read_xml(parts[["xl/workbook.xml"]])
  sheet_names <- xml2::xml_attr(xml_nodes(workbook, "sheet"), "name")
  sheets <- grep("^xl/worksheets/[^/]+\\.xml$", names(parts), value = TRUE)
  details <- setNames(lapply(sheets, function(name) {
    cells <- cell_records(parts[[name]])
    list(cell_count = cells$count, cell_types = cells$types)
  }), sheets)
  list(sheet_names = unname(sheet_names), worksheets = details,
    cell_count = sum(vapply(details, function(detail) detail$cell_count, integer(1L))),
    zip_members = length(parts), uncompressed_bytes = sum(vapply(parts, length, integer(1L))))
}

compare_workbook <- function(before, after) {
  old_parts <- read_parts(before)
  new_parts <- read_parts(after)
  missing <- setdiff(names(old_parts), names(new_parts))
  added <- setdiff(names(new_parts), names(old_parts))
  shared <- intersect(names(old_parts), names(new_parts))
  if (!"docProps/core.xml" %in% shared) stop("Missing docProps/core.xml in ", basename(before))
  old_core <- without_creation_time(old_parts[["docProps/core.xml"]])
  new_core <- without_creation_time(new_parts[["docProps/core.xml"]])
  changed <- shared[!vapply(shared, function(member) {
    if (identical(member, "docProps/core.xml")) identical(old_core$value, new_core$value)
    else identical(old_parts[[member]], new_parts[[member]])
  }, logical(1L))]
  cell_differences <- list()
  for (member in grep("^xl/worksheets/[^/]+\\.xml$", changed, value = TRUE)) {
    old_cells <- cell_records(old_parts[[member]])$records
    new_cells <- cell_records(new_parts[[member]])$records
    keys <- union(names(old_cells), names(new_cells))
    changed_keys <- keys[!vapply(keys, function(key) identical(unname(old_cells[key]), unname(new_cells[key])), logical(1L))]
    cell_differences[[member]] <- list(count = length(changed_keys), first_coordinates = head(changed_keys, 30L))
  }
  list(
    file = basename(before), passed = !length(c(missing, added, changed)),
    before = summarize_workbook(old_parts), after = summarize_workbook(new_parts),
    creation_time = list(before = old_core$timestamp, after = new_core$timestamp,
      allowed_difference = !identical(old_core$timestamp, new_core$timestamp)),
    missing_members = unname(missing), added_members = unname(added), changed_members = unname(changed),
    cell_differences = cell_differences
  )
}

before_files <- sort(list.files(before_dir, pattern = pattern))
after_files <- sort(list.files(after_dir, pattern = pattern))
problems <- character()
if (!length(before_files)) problems <- c(problems, "No reference XLSX files matched.")
if (!is.null(expected_count) && length(before_files) != expected_count) {
  problems <- c(problems, paste("Expected", expected_count, "reference files; found", length(before_files)))
}
missing_files <- setdiff(before_files, after_files)
added_files <- setdiff(after_files, before_files)
if (length(missing_files)) problems <- c(problems, paste("Missing exports:", paste(missing_files, collapse = ", ")))
if (length(added_files)) problems <- c(problems, paste("Unexpected exports:", paste(added_files, collapse = ", ")))
results <- lapply(intersect(before_files, after_files), function(name) {
  tryCatch(compare_workbook(file.path(before_dir, name), file.path(after_dir, name)),
    error = function(error) list(file = name, passed = FALSE, error = conditionMessage(error)))
})
passed <- !length(problems) && all(vapply(results, function(result) result$passed, logical(1L)))
report <- list(
  passed = passed, checked_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
  before_dir = before_dir, after_dir = after_dir, pattern = pattern, expected_count = expected_count,
  compared_files = length(results), problems = problems,
  comparison = list(
    content = "Every uncompressed ZIP member is compared byte for byte.",
    allowed_difference = "Only dcterms:created timestamp text in docProps/core.xml.",
    excluded_container_metadata = "ZIP compression, entry timestamps and member ordering.",
    covered = c("worksheet names and order", "cell coordinates/types/raw values and formulas",
      "metadata and shared strings", "cell formats/styles, widths and views", "all other XLSX parts and relationships")
  ),
  workbooks = results
)
results_dir <- file.path(campaign, "results")
dir.create(results_dir, showWarnings = FALSE)
output <- file.path(results_dir, output_name)
jsonlite::write_json(report, output, pretty = TRUE, auto_unbox = TRUE, null = "null", na = "null")
for (result in results) {
  cat(if (result$passed) "PASS" else "FAIL", result$file)
  if (result$passed) cat(" -", result$before$cell_count, "cells;", result$before$zip_members, "XLSX members")
  if (!is.null(result$error)) cat("-", result$error)
  if (length(result$changed_members)) cat("- changed:", paste(result$changed_members, collapse = ", "))
  cat("\n")
}
if (length(problems)) cat(paste(problems, collapse = "\n"), "\n")
cat("Report:", output, "\n")
cat(if (passed) "All workbook contents match.\n" else "Workbook equivalence failed.\n")
if (!passed) quit(status = 1L)
