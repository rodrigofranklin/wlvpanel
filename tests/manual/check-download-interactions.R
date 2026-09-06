# Regressão dos seletores e do conteúdo XLSX real, sem arquivos pré-gerados.
campaign <- Sys.getenv("WLV_CAMPAIGN_ROOT")
stopifnot(nzchar(campaign), dir.exists(campaign))
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8")
source("global.R", encoding = "UTF-8")
method <- init_bases[[1L]]
country_codes <- wlv_sector_country_codes(sea_sectors, method)
country <- if ("BRA" %in% country_codes) "BRA" else country_codes[[1L]]
partner <- setdiff(country_codes, country)[[1L]]
sector <- dimnames(sea_sectors[[method]])[[3L]][[1L]]
indicator <- default_indicator
aggregate_file <- paste0(country, ".", indicator, ".", method, ".xlsx")
bilateral_file <- paste0(country, ".", partner, ".", method, ".xlsx")
multilateral_file <- paste0(country, ".CX.T.MP.", method, ".xlsx")
capture <- new.env(parent = emptyenv())
capture$inputs <- list()
capture$choices <- list()
latest <- function(id) {
  matches <- Filter(function(value) value$id == id, capture$choices)
  if (!length(matches)) stop("No choice update for input: ", id)
  matches[[length(matches)]]
}
choice_values <- function(id) vapply(latest(id)$choices, `[[`, "", "value")
assert_selected <- function(expected, input) {
  for (id in names(expected)) {
    stopifnot(identical(input[[id]], expected[[id]]))
    stopifnot(!any(c("selected", "value", "url") %in% names(latest(id))))
    if (nzchar(expected[[id]])) stopifnot(expected[[id]] %in% choice_values(id))
  }
}
as_html <- function(value) paste(value$html, collapse = "")

shiny::testServer(function(input, output, session) {
  session$sendInputMessage <- function(inputId, message) {
    capture$inputs[[length(capture$inputs) + 1L]] <- list(id = inputId, data = message)
  }
  session$sendCustomMessage <- function(type, message) {
    if (identical(type, "wlv-download-choices")) {
      capture$choices[[length(capture$choices) + 1L]] <- message
    }
  }
  RV <- reactiveValues()
  RV$bases <- reactiveVal(init_bases)
  download_server(input, output, RV, session)
}, {
  session$setInputs(l = default_language, dl_method = method,
    dl_country = country, dl_indicator = indicator, dl_sector = "",
    dl_ml_method = method, dl_ml_country = country, dl_ml_partner = partner,
    dl_ml_ind_cat = "", dl_ml_ind_scope = "", dl_ml_ind_un = "")
  stopifnot(grepl('id="dl_file"', as_html(output$dl_download), fixed = TRUE))
  stopifnot(grepl('id="dl_ml_file"', as_html(output$dl_ml_download), fixed = TRUE))
  stopifnot(!grepl("<button", as_html(output$dl_download), fixed = TRUE))
  aggregate_path <- output$dl_file
  bilateral_path <- output$dl_ml_file
  stopifnot(identical(basename(aggregate_path), aggregate_file))
  stopifnot(identical(basename(bilateral_path), bilateral_file))
  stopifnot(identical(openxlsx::getSheetNames(aggregate_path), c("data", "metadata", "specs")))
  stopifnot(nrow(openxlsx::read.xlsx(aggregate_path, sheet = "data", startRow = 6L)) > 0L)
  stopifnot(nrow(openxlsx::read.xlsx(bilateral_path, sheet = "data", startRow = 6L)) > 0L)

  capture$inputs <- list()
  session$setInputs(l = "English")
  assert_selected(list(dl_method = method, dl_country = country, dl_indicator = indicator,
    dl_sector = "", dl_ml_method = method, dl_ml_country = country,
    dl_ml_partner = partner, dl_ml_ind_cat = "", dl_ml_ind_scope = "", dl_ml_ind_un = ""), input)
  stopifnot(grepl("Download file", as_html(output$dl_download), fixed = TRUE))
  stopifnot(!country %in% choice_values("dl_ml_partner"))

  session$setInputs(dl_country = "", dl_sector = sector, dl_ml_partner = "",
    dl_ml_ind_cat = "CX.", dl_ml_ind_scope = "T.", dl_ml_ind_un = "MP")
  stopifnot(grepl('id="dl_ml_file"', as_html(output$dl_ml_download), fixed = TRUE))
  multilateral_path <- output$dl_ml_file
  stopifnot(identical(basename(multilateral_path), multilateral_file))
  stopifnot(nrow(openxlsx::read.xlsx(multilateral_path, sheet = "data", startRow = 6L)) > 0L)
  capture$inputs <- list()
  session$setInputs(l = default_language)
  assert_selected(list(dl_method = method, dl_country = "", dl_indicator = indicator,
    dl_sector = sector, dl_ml_method = method, dl_ml_country = country,
    dl_ml_partner = "", dl_ml_ind_cat = "CX.", dl_ml_ind_scope = "T.", dl_ml_ind_un = "MP"), input)
  stopifnot(!"TS." %in% choice_values("dl_ml_ind_cat"))
  stopifnot(grepl('id="dl_file"', as_html(output$dl_download), fixed = TRUE))
  session$setInputs(dl_sector = "MISSING-SECTOR")
  stopifnot(grepl(lb("app.no_file", default_language), as_html(output$dl_download), fixed = TRUE))
  stopifnot(grepl("aria-describedby", as_html(output$dl_download), fixed = TRUE))
  stopifnot(!grepl("<a", as_html(output$dl_download), fixed = TRUE))

  session$setInputs(dl_ml_ind_cat = "TS.", dl_ml_ind_un = "MV")
  capture$inputs <- list()
  session$setInputs(l = "English")
  assert_selected(list(dl_ml_ind_cat = "TS.", dl_ml_ind_scope = "T.", dl_ml_ind_un = "MV"), input)
  stopifnot(!"MP" %in% choice_values("dl_ml_ind_un"))
  stopifnot(grepl('id="dl_ml_file"', as_html(output$dl_ml_download), fixed = TRUE))
  session$setInputs(dl_ml_ind_un = "MP")
  stopifnot(grepl(lb("app.no_file", "English"), as_html(output$dl_ml_download), fixed = TRUE))
  session$setInputs(dl_method = "", dl_ml_method = "")
  stopifnot(grepl("Complete a valid selection", as_html(output$dl_download), fixed = TRUE))
  stopifnot(grepl("Complete a valid selection", as_html(output$dl_ml_download), fixed = TRUE))
})

jsonlite::write_json(list(status = "passed", checked = c("aggregated-link", "bilateral-link",
  "multilateral-link", "language-preserves-selection", "dependent-choice-restrictions",
  "disabled-feedback", "accessible-links", "real-xlsx-content", "incomplete-selection-feedback")), file.path(campaign, "results", "download-ui-check.json"),
  auto_unbox = TRUE, pretty = TRUE)
cat("Download UI interactions: passed\n")
