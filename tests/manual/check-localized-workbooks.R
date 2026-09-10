# Verify the XLSX files obtained by check-expanded-languages.cjs.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8"))
campaign <- Sys.getenv("WLV_CAMPAIGN_ROOT")
stopifnot(nzchar(campaign), file.exists(file.path(campaign, ".campaign.json")))
registry <- jsonlite::fromJSON("config/languages.json")
codes <- setdiff(registry$key, c("pt", "en", "es", "zh"))
numeric_cells <- function(file) {
  stopifnot(identical(openxlsx::getSheetNames(file)[[1L]], "data"))
  connection <- unz(file, "xl/worksheets/sheet1.xml")
  on.exit(try(close(connection), silent = TRUE))
  xml <- xml2::read_xml(connection)
  cells <- xml2::xml_find_all(xml, "//*[local-name()='c' and (not(@t) or @t='n')]")
  values <- vapply(cells, function(cell) as.numeric(xml2::xml_text(xml2::xml_find_first(cell, "./*[local-name()='v']"))), numeric(1L))
  setNames(values, xml2::xml_attr(cells, "r"))
}
for (kind in c("indicator", "trade")) {
  files <- file.path(campaign, "results", paste0(kind, "-", codes, ".xlsx"))
  stopifnot(all(file.exists(files)))
  reference <- numeric_cells(files[[1L]])
  stopifnot(length(reference) > 0L)
  for (i in seq_along(files)) {
    stopifnot(identical(numeric_cells(files[[i]]), reference))
    text <- unlist(openxlsx::read.xlsx(files[[i]], sheet = "metadata", colNames = FALSE), use.names = FALSE)
    stopifnot(!any(grepl("\ufffd", text, fixed = TRUE), na.rm = TRUE))
  }
  cat(kind, length(files), "localized workbooks;", length(reference), "numeric cells identical\n")
}
