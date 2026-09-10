test_that("all new catalogs preserve source keys, formatting tokens and HTML", {
  env <- new.env(parent = environment())
  env$wlvpanel_test_root <- wlvpanel_test_root
  sys.source(file.path(wlvpanel_test_root, "utils/i18n.R"), env)
  dictionary <- readRDS(file.path(wlvpanel_test_root, "data/language_file.RDS"))
  for (name in c("translations", "about-translations", "indicator-translations", "method-translations", "legacy-translations")) {
    dictionary <- env$wlv_complete_language(dictionary, file.path(wlvpanel_test_root, "config", paste0(name, ".json")))
  }
  sources <- dictionary$English
  fallback <- is.na(sources) | !nzchar(sources)
  sources[fallback] <- dictionary$Português[fallback]
  names(sources) <- rownames(dictionary)
  capture <- function(value, pattern) regmatches(value, gregexpr(pattern, value, perl = TRUE))[[1L]]
  patterns <- c("(?<!%)%(?:[0-9]+\\$)?[-+ 0#]*(?:[0-9]+|\\*)?(?:\\.(?:[0-9]+|\\*))?[diouxXeEfFgGaAs](?![A-Za-z])", "_[A-Z]+_|\\{[A-Za-z_][A-Za-z_0-9]*\\}", "<[^>]+>", "https?://[^[:space:]<>\"']+")
  catalogs <- env$wlv_locale_catalogs()
  reference <- jsonlite::fromJSON(file.path(wlvpanel_test_root, "config/locales/fr.json"), simplifyVector = FALSE)
  problems <- character()
  for (code in names(catalogs)) {
    catalog <- catalogs[[code]]
    expect_identical(sort(names(catalog$labels)), sort(rownames(dictionary)), info = code)
    expect_identical(sort(names(catalog$phrases)), sort(names(reference$phrases)), info = code)
    for (kind in c("labels", "phrases")) for (key in names(catalog[[kind]])) {
      value <- catalog[[kind]][[key]]
      if (length(value) != 1L || !is.character(value) || !nzchar(value) || !validUTF8(value) || grepl("\ufffd", value, fixed = TRUE)) {
        problems <- c(problems, paste(code, kind, key, "invalid text")); next
      }
      source <- if (kind == "labels") sources[[key]] else key
      if (is.na(source)) next
      for (pattern in patterns) if (!identical(sort(capture(source, pattern)), sort(capture(value, pattern)))) {
        problems <- c(problems, paste(code, kind, key, "altered placeholders or markup"))
      }
      if (kind == "phrases" && !code %in% c("ja", "ko", "th") &&
          (!identical(grepl("^[[:space:]]", source), grepl("^[[:space:]]", value)) ||
           !identical(grepl("[[:space:]]$", source), grepl("[[:space:]]$", value)))) {
        problems <- c(problems, paste(code, key, "fragment whitespace"))
      }
    }
  }
  expect_identical(problems, character(), info = paste(problems, collapse = "\n"))
})
