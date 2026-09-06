i18n_env <- new.env(parent = globalenv())
sys.source(file.path(wlvpanel_test_root, "utils/i18n.R"), i18n_env)

test_that("Portuguese is the default and missing labels have a deterministic fallback", {
  expect_identical(i18n_env$wlv_language(NULL), "Português")
  expect_identical(i18n_env$wlv_language("en"), "English")
  original <- data.frame(pt = c("País", NA, ""), en = c("Country", "Series", NA), row.names = c("country", "series", "empty"))
  names(original) <- c("Português", "English")
  expect_identical(i18n_env$wlv_label(c("country", "series", "empty", "unknown"), "pt", original),
    c("País", "Series", "empty", "unknown"))
  expect_length(i18n_env$wlv_label(character(), "pt", original), 0L)
})

test_that("versioned translations are valid UTF-8 and cover every navigation item", {
  path <- file.path(wlvpanel_test_root, "config/translations.json")
  raw <- readChar(path, file.info(path)$size, useBytes = TRUE)
  expect_false(grepl("\ufffd", raw, fixed = TRUE))
  expect_true(validUTF8(raw))
  labels <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  expected <- c(about = "Sobre", countries = "Mapa", indicators = "Indicadores", download = "Download", how_to_quote = "Como citar")
  for (key in names(expected)) {
    expect_identical(labels[[paste0("tab_name.", key)]]$pt, unname(expected[[key]]))
    expect_true(nzchar(labels[[paste0("tab_name.", key)]]$en))
  }
})
