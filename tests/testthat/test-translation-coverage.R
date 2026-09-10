# Cobertura do catálogo operacional e dos textos literais, sem iniciar o Shiny.
translation_coverage_env <- new.env(parent = globalenv())
# test_dir stores helper variables in its test environment, not globalenv().
# Bind the catalogue root explicitly so isolation never depends on caller state.
translation_coverage_env$wlvpanel_test_root <- wlvpanel_test_root
sys.source(file.path(wlvpanel_test_root, "utils/i18n.R"), translation_coverage_env)
translation_coded_files <- c("translations", "about-translations", "indicator-translations",
  "method-translations", "legacy-translations")
translation_literal_files <- c("core-translations", "exploration-translations",
  "trade-translations", "client-translations")
translation_read <- function(name) jsonlite::fromJSON(
  file.path(wlvpanel_test_root, "config", paste0(name, ".json")), simplifyVector = FALSE)

translation_literal <- function(expression) {
  if (is.character(expression)) return(expression)
  if (!is.call(expression) || !identical(expression[[1L]], as.name("c"))) return(NULL)
  arguments <- as.list(expression)[-1L]
  if (!length(arguments) || !all(vapply(arguments, is.character, logical(1L)))) return(NULL)
  unlist(arguments, use.names = FALSE)
}

translation_r_sources <- function() {
  found <- list()
  add <- function(text, file) {
    if (!length(text)) return(invisible(NULL))
    for (value in text) found[[length(found) + 1L]] <<- c(file = file, text = value)
  }
  visit <- function(expression, file) {
    if (!is.call(expression) && !is.expression(expression)) return(invisible(NULL))
    if (is.call(expression)) {
      head <- expression[[1L]]
      if (is.symbol(head) && as.character(head) %in% c("wlv_tr", "tr") && length(expression) >= 3L) {
        add(translation_literal(expression[[3L]]), file)
      }
      if (is.symbol(head) && as.character(head) %in% c("<-", "=") &&
          length(expression) == 3L && is.symbol(expression[[2L]])) {
        variable <- as.character(expression[[2L]])
        right <- expression[[3L]]
        if (variable %in% c("dictionary", "entries", "texts", "labels") &&
            is.call(right) && identical(right[[1L]], as.name("list"))) {
          for (entry in as.list(right)[-1L]) {
            pair <- translation_literal(entry)
            if (length(pair) == 2L) add(pair[[2L]], file)
          }
        }
        if (grepl("_en$", variable)) add(translation_literal(right), file)
        if (identical(file, "modules/countries/country_panel.R") && variable == "labels" &&
            is.call(right) && identical(right[[1L]], as.name("c"))) {
          add(names(as.list(right))[-1L], file)
        }
      }
    }
    for (child in as.list(expression)) {
      if (missing(child)) next
      if (is.call(child) || is.expression(child)) visit(child, file)
    }
    invisible(NULL)
  }
  files <- c(list.files(file.path(wlvpanel_test_root, "modules"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE),
    list.files(file.path(wlvpanel_test_root, "utils"), pattern = "\\.R$", recursive = TRUE, full.names = TRUE))
  for (file in files) {
    relative <- substring(gsub("\\\\", "/", file), nchar(wlvpanel_test_root) + 2L)
    visit(parse(file = file, encoding = "UTF-8"), relative)
  }
  chart_env <- new.env(parent = translation_coverage_env)
  chart_definitions <- parse(file.path(wlvpanel_test_root, "modules/trade/charts.R"), encoding = "UTF-8")
  for (definition in chart_definitions) {
    if (is.call(definition) && identical(definition[[1L]], as.name("<-")) &&
        identical(definition[[2L]], as.name("wlv_trade_chart_words"))) eval(definition, chart_env)
  }
  add(unlist(chart_env$wlv_trade_chart_words("en"), use.names = FALSE), "modules/trade/charts.R")
  add(c("Country", "Indicator", "Sector", "Partner"), "utils/download_requests.R")
  unique(as.data.frame(do.call(rbind, found), stringsAsFactors = FALSE))
}

test_that("every operational code has complete labels in the added languages", {
  path <- file.path(wlvpanel_test_root, "data/language_file.RDS")
  skip_if_not(file.exists(path), "Operational language RDS is not present in this checkout")
  dictionary <- readRDS(path)
  for (name in translation_coded_files) dictionary <- translation_coverage_env$wlv_complete_language(
    dictionary, file.path(wlvpanel_test_root, "config", paste0(name, ".json")))
  dictionary <- translation_coverage_env$wlv_complete_locale_languages(dictionary)
  for (language in setdiff(translation_coverage_env$wlv_languages()$value, c("English", "Português"))) {
    missing <- rownames(dictionary)[is.na(dictionary[[language]]) | !nzchar(dictionary[[language]])]
    expect_identical(missing, character(), info = paste(language, "missing operational keys:", paste(missing, collapse = ", ")))
    expect_false(any(grepl("\ufffd", dictionary[[language]], fixed = TRUE)))
  }
})

test_that("R translation calls and helper dictionaries are covered without an English fallback", {
  sources <- translation_r_sources()
  neutral <- c("", "%", "US$", "USD", "mv", "mv/US$")
  catalogue <- translation_coverage_env$wlv_text_catalog(refresh = TRUE)
  for (language in setdiff(translation_coverage_env$wlv_languages()$key, c("pt", "en"))) {
    available <- vapply(sources$text, function(key) key %in% neutral || !grepl("[[:alpha:]]", key) ||
      (length(catalogue[[key]][[language]]) == 1L && nzchar(catalogue[[key]][[language]])), logical(1L))
    missing <- sources[!available, , drop = FALSE]
    expect_equal(nrow(missing), 0L, info = paste(language,
      paste(paste(missing$file, missing$text, sep = ": "), collapse = "\n")))
  }
})

test_that("translation payloads preserve placeholders, table tokens and Latin word boundaries", {
  capture <- function(value, pattern) regmatches(value, gregexpr(pattern, value, perl = TRUE))[[1L]]
  sprintf_pattern <- "(?<!%)%(?:[0-9]+\\$)?[-+ 0#]*(?:[0-9]+|\\*)?(?:\\.(?:[0-9]+|\\*))?[diouxXeEfFgGaAs](?![A-Za-z])"
  token_pattern <- "_[A-Z]+_|\\{[A-Za-z_][A-Za-z_0-9]*\\}"
  problems <- character()
  for (name in c(translation_coded_files, translation_literal_files)) {
    entries <- translation_read(name)
    for (key in names(entries)) {
      entry <- entries[[key]]
      source <- if (name %in% translation_literal_files) key else if (!is.null(entry$en)) entry$en else entry$pt
      for (language in c("es", "zh")) {
        value <- entry[[language]]
        context <- paste(name, key, language, sep = ": ")
        if (is.null(value) || !nzchar(value) || !validUTF8(value) || grepl("\ufffd", value, fixed = TRUE)) {
          problems <- c(problems, paste(context, "missing or invalid UTF-8")); next
        }
        if (is.null(source)) next # Legacy overlay contains translations only.
        if (!identical(capture(source, sprintf_pattern), capture(value, sprintf_pattern)))
          problems <- c(problems, paste(context, "sprintf placeholders differ"))
        if (!identical(sort(capture(source, token_pattern)), sort(capture(value, token_pattern))))
          problems <- c(problems, paste(context, "named placeholders differ"))
        # Chinese punctuation supplies its own boundaries; Spanish fragments need spaces.
        if (language == "es" && name %in% translation_literal_files &&
            ((!identical(grepl("^[[:space:]]", source), grepl("^[[:space:]]", value))) ||
             (!identical(grepl("[[:space:]]$", source), grepl("[[:space:]]$", value)))))
          problems <- c(problems, paste(context, "fragment boundary spacing differs"))
      }
    }
  }
  expect_identical(problems, character(), info = paste(problems, collapse = "\n"))
})
