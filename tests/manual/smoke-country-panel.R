# Run with TEMP/TMP/TMPDIR and WLV_CAMPAIGN_ROOT set by run-experiment.ps1.
# Uses the shipped panel data to exercise country UI and reactive transitions.
campaign <- Sys.getenv("WLV_CAMPAIGN_ROOT", unset = "")
if (!nzchar(campaign)) stop("Launch this smoke through run-experiment.ps1.", call. = FALSE)
if (.Platform$OS.type == "windows") {
  Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8")
  version <- paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L], sep = ".")
  library_path <- file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", version)
  if (dir.exists(library_path)) .libPaths(c(library_path, .libPaths()))
}
source("global.R", encoding = "UTF-8")

ui_html <- htmltools::renderTags(tagList(country_panel, co_info_panel))$html
id_attributes <- regmatches(ui_html, gregexpr('\\bid="[^"]+"', ui_html))[[1L]]
stopifnot(!anyDuplicated(id_attributes))
stopifnot(grepl('id="wlv-country-page"', ui_html, fixed = TRUE))
stopifnot(grepl('id="co_select_country"', ui_html, fixed = TRUE))
stopifnot(!grepl('wlv-country-overlay', ui_html, fixed = TRUE))
stopifnot(!grepl('close_country_panel', ui_html, fixed = TRUE))
group_buttons <- regmatches(ui_html, gregexpr('<button[^>]*class="wlv-country-group-toggle[^"<>]*"[^>]*>', ui_html))[[1L]]
group_contents <- regmatches(ui_html, gregexpr('<div[^>]*class="wlv-country-group-content[^"<>]*"[^>]*>', ui_html))[[1L]]
stopifnot(length(group_buttons) == length(groups), length(group_contents) == length(groups))
stopifnot(all(grepl('class="wlv-country-group-toggle collapsed"', group_buttons, fixed = TRUE)))
stopifnot(all(grepl('aria-expanded="false"', group_buttons, fixed = TRUE)))
stopifnot(all(grepl('class="wlv-country-group-content collapse"', group_contents, fixed = TRUE)))
stopifnot(all(grepl('aria-hidden="true"', group_contents, fixed = TRUE)))
stopifnot(all(grepl('inert=""', group_contents, fixed = TRUE)))
country_css <- paste(readLines("www/wlv-country.css", encoding = "UTF-8"), collapse = "\n")
stopifnot(!grepl(".wlv-country-overlay", country_css, fixed = TRUE))
plot_payload <- function(rendered_ui) {
  script <- regmatches(
    rendered_ui$html,
    regexec('<script type="application/json"[^>]*>([^<]+)</script>', rendered_ui$html)
  )[[1L]]
  stopifnot(length(script) == 2L)
  jsonlite::fromJSON(script[[2L]], simplifyVector = FALSE)$x
}

capture <- new.env(parent = emptyenv())
capture$inputs <- list()
last_control <- function(id) {
  controls <- Filter(function(value) identical(value$id, id), capture$inputs)
  stopifnot(length(controls) > 0L)
  controls[[length(controls)]]$data
}
shiny::testServer(function(input, output, session) {
  session$sendInputMessage <- function(inputId, message) {
    capture$inputs[[length(capture$inputs) + 1L]] <- list(id = inputId, data = message)
  }
  # There is no map server, no RV$yearmin/max and no map indicator/year input.
  RV <- list(bases = reactive(input$bases))
  country_panel_server(input, output, RV, session)
}, {
  session$setInputs(
    bases = init_bases, main_nav = "country",
    l = "English", co_select_country = "BRA",
    co_panel_year = 2007
  )
  stopifnot(identical(output$show_country_panel, "BRA"))
  stopifnot(identical(output$co_panel_title, "Brazil"))
  stopifnot(identical(output$co_entry_expanded, "false"))
  session$setInputs(co_entry_more = 1L)
  stopifnot(identical(output$co_entry_expanded, "true"))
  stopifnot(identical(output$co_panel_year_text, "2007"))
  stopifnot(nzchar(output$co_panel_profile))
  stopifnot(grepl('id="co_country_file_WIOD13"', output$country_link$html, fixed = TRUE))
  stopifnot(grepl('id="co_sector_file_WIOD13"', output$sector_data_link$html, fixed = TRUE))
  country_file <- output$co_country_file_WIOD13
  sector_file <- output$co_sector_file_WIOD13
  for (download in c(country_file, sector_file)) {
    stopifnot(file.exists(download), file.size(download) > 1000)
    stopifnot(identical(openxlsx::getSheetNames(download), c("data", "metadata", "specs")))
  }
  stopifnot(identical(last_control("co_select_country")$value, "BRA"))
  stopifnot(grepl("Brazil", last_control("co_select_country")$options, fixed = TRUE))
  graph <- output[[paste0(default_indicator, "_plot")]]
  stopifnot(grepl("wlv-country-chart", graph$html, fixed = TRUE))
  graph_data <- plot_payload(graph)
  stopifnot(identical(graph_data$layout$separators, ".,"))

  session$setInputs(co_panel_sector_select = "gdp.s.mv")
  stopifnot(identical(output$co_panel_sector_indicator, lb("gdp.s.mv", "English")))
  stopifnot(nzchar(output$co_panel_sector_WIOD13))
  session$setInputs(l = "Português")
  session$setInputs(co_select_country = "BRA")
  stopifnot(identical(output$co_entry_expanded, "true"))
  stopifnot(identical(output$co_panel_profile_label, "Perfil do país"))
  stopifnot(identical(output$co_panel_title, "Brasil"))
  stopifnot(identical(last_control("co_select_country")$value, "BRA"))
  stopifnot(grepl("Brasil", last_control("co_select_country")$options, fixed = TRUE))
  translated_graph <- output[[paste0(default_indicator, "_plot")]]
  stopifnot(grepl(lb(default_indicator, "Português"), translated_graph$html, fixed = TRUE))
  translated_data <- plot_payload(translated_graph)
  stopifnot(identical(translated_data$layout$separators, ",."))
  stopifnot(identical(translated_data$data[[1L]]$y, graph_data$data[[1L]]$y))
  session$setInputs(co_panel_year = 2010)
  stopifnot(identical(output$co_panel_year_text, "2010"))
  session$setInputs(co_select_year = 1998, co_select_indicator = "gdp.s.us")
  stopifnot(identical(output$co_panel_year_text, "2010"))
  stopifnot(identical(output$co_panel_sector_indicator, lb("gdp.s.mv", "Português")))
  session$setInputs(bases = "WIOD13")
  stopifnot(nzchar(output$co_panel_profile))
  expected_years <- as.numeric(dimnames(sea_countries)[[2L]])[
    apply(sea_countries["WIOD13", , , , drop = FALSE], 2L, function(x) any(!is.na(x)))
  ]
  stopifnot(last_control("co_panel_year")$min == min(expected_years))
  stopifnot(last_control("co_panel_year")$max == max(expected_years))
  # Technical information still opens and closes, including a navigation change.
  do.call(session$setInputs, stats::setNames(list(1L), paste0(default_indicator, "_info")))
  stopifnot(identical(output$show_info_panel, "1"))
  stopifnot(nzchar(output$co_info_text$html))
  session$setInputs(info_close_button = 1L)
  stopifnot(identical(output$show_info_panel, "0"))
  do.call(session$setInputs, stats::setNames(list(2L), paste0(default_indicator, "_info")))
  stopifnot(identical(output$show_info_panel, "1"))
  session$setInputs(main_nav = "map")
  stopifnot(identical(output$show_info_panel, "0"))
  stopifnot(identical(output$show_country_panel, "BRA"))
  # Empty selection returns to the catalogue; hidden DT outputs cancel instead
  # of sending NULL (which breaks DT's lazy renderer).
  session$setInputs(co_select_country = "")
  stopifnot(identical(output$show_country_panel, ""))
  stopifnot(grepl('data-wlv-country="BRA"', output$co_country_catalogue$html, fixed = TRUE))
  for (id in c("co_panel_profile", "co_sector_panel", "co_panel_sector_WIOD13")) {
    closed_output <- tryCatch(output[[id]], error = identity)
    stopifnot(inherits(closed_output, "shiny.output.cancel"))
  }
  session$setInputs(co_select_country = "BRA", main_nav = "country")
  stopifnot(identical(output$show_country_panel, "BRA"))
  stopifnot(identical(output$co_panel_sector_indicator, lb("gdp.s.mv", "Português")))
})
cat("COUNTRY_REACTIVE_SMOKE_OK\n")
