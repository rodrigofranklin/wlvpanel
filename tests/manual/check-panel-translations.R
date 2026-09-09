# Confere o catálogo operacional e os overlays sem alterar os dados de origem.
stopifnot(nzchar(Sys.getenv("WLV_CAMPAIGN_ROOT")))
if (.Platform$OS.type == "windows") {
  Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8")
  version <- paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L], sep = ".")
  .libPaths(c(file.path(Sys.getenv("LOCALAPPDATA"), "R/win-library", version), .libPaths()))
}
source("global.R", encoding = "UTF-8")
pt <- language_file[, "Português"]
en <- language_file[, "English"]
visible <- meta_indicators$value
keys <- c(visible, paste0("desc.", visible), paste0("group.", groups),
  paste0("ISO3.", dimnames(sea_countries)[[4L]]))
stopifnot(all(keys %in% rownames(language_file)))
rows <- match(keys, rownames(language_file))
stopifnot(!anyNA(pt[rows]), all(nzchar(pt[rows])))
stopifnot(!any(grepl("\ufffd", pt[rows], fixed = TRUE)))
stopifnot(identical(lb("surplus_value.empe_p.r.pc"), "Taxa de mais-valor (trabalhadores produtivos)"))
stopifnot(!any(grepl("mais.?valia", pt, ignore.case = TRUE)))
stopifnot(identical(lb("surplus_value.empe_p.r.pc", "English"), "Rate of surplus value (productive workers)"))
for (file in c("config/translations.json", "config/indicator-translations.json", "config/method-translations.json", "config/about-translations.json")) {
  value <- jsonlite::fromJSON(file, simplifyVector = FALSE)
  restored <- jsonlite::fromJSON(jsonlite::toJSON(value, auto_unbox = TRUE), simplifyVector = FALSE)
  stopifnot(identical(value, restored))
}
cat("TRANSLATIONS_OK:", length(visible), "indicators,", length(groups), "groups\n")
