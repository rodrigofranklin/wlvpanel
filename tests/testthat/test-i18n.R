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

test_that("the language registry exposes native names and only selects available translations", {
  languages <- i18n_env$wlv_languages()
  expect_identical(languages$value[1:4], c("English", "Castellano", "中文", "Português"))
  expect_identical(languages$code[1:4], c("en", "es", "zh-CN", "pt-BR"))
  expect_identical(languages$key, c("en", "es", "zh", "pt", "fr", "de", "it", "nl", "ca", "gl", "ru", "uk", "pl", "cs", "ro", "el", "ja", "ko", "hi", "bn", "id", "vi", "th"))
  expect_false(anyDuplicated(languages$key) > 0L)
  expect_identical(i18n_env$wlv_language("pt-BR"), "Português")
  expect_identical(i18n_env$wlv_language("pt"), "Português")
  for (index in which(languages$available)) {
    expect_identical(i18n_env$wlv_language(languages$code[[index]]), languages$value[[index]])
    expect_identical(i18n_env$wlv_language(languages$value[[index]]), languages$value[[index]])
  }
  for (index in which(!languages$available)) {
    expect_identical(i18n_env$wlv_language(languages$value[[index]]), "Português")
  }
})

test_that("localized numbers and optional overrides do not leak another language", {
  expect_identical(i18n_env$wlv_language("uk-UA"), "Українська")
  expect_identical(i18n_env$wlv_language("ja-JP"), "日本語")
  expect_identical(i18n_env$wlv_number_marks("fr")$grouping, "\u202f")
  expect_identical(i18n_env$wlv_number_marks("ja")$decimal, ".")
  expect_identical(i18n_env$wlv_plotly_separators("de"), ",.")
  expect_identical(i18n_env$wlv_tr(", ", ", ", "fr", zh = "年，"), ", ")
  expect_identical(i18n_env$wlv_tr(", ", ", ", "zh", zh = "年，"), "年，")
})

test_that("translated sentences can reorder named values without injecting markup", {
  value <- i18n_env$wlv_fill_template("{country}: {year} — {value}", list(
    year = htmltools::tags$strong(2014), country = "<Brazil>", value = "2,5"))
  html <- as.character(value)
  expect_match(html, "&lt;Brazil&gt;", fixed = TRUE)
  expect_match(html, "<strong>2014</strong>", fixed = TRUE)
  expect_true(regexpr("&lt;Brazil&gt;", html, fixed = TRUE)[[1L]] < regexpr("2014", html, fixed = TRUE)[[1L]])
  expect_true(regexpr("2014", html, fixed = TRUE)[[1L]] < regexpr("2,5", html, fixed = TRUE)[[1L]])
  expect_error(i18n_env$wlv_fill_template("{missing}", list()), "Unknown translation placeholder")
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
