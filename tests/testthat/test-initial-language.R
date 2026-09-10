initial_env <- new.env(parent = globalenv())
sys.source(file.path(wlvpanel_test_root, "utils/i18n.R"), initial_env)
sys.source(file.path(wlvpanel_test_root, "utils/initial_language.R"), initial_env)

test_that("explicit choices override country and browser hints", {
  request <- list(HTTP_CF_IPCOUNTRY = "CN", HTTP_ACCEPT_LANGUAGE = "en-US,en;q=0.9", HTTP_COOKIE = "other=x; wlv_language=es")
  expect_identical(initial_env$wlv_initial_language(request, "CF-IPCountry")$code, "es")
  request$QUERY_STRING <- "indicator=gdp&lang=pt-BR"
  expect_identical(initial_env$wlv_initial_language(request, "CF-IPCountry")$source, "url")
  expect_identical(initial_env$wlv_initial_language(request, "CF-IPCountry")$code, "pt")
  request$QUERY_STRING <- "?lang=zh-CN"
  expect_identical(initial_env$wlv_initial_language(request, "CF-IPCountry")$code, "zh")
})

test_that("country detection is approximate and requires an opted-in proxy header", {
  for (country in c("CN", "TW", "HK", "MO")) expect_identical(initial_env$wlv_country_language(country), "中文")
  expect_identical(initial_env$wlv_country_language("BR"), "Português")
  expect_identical(initial_env$wlv_country_language("MX"), "Castellano")
  request <- list(HTTP_CF_IPCOUNTRY = "BR", HTTP_ACCEPT_LANGUAGE = "es-MX")
  expect_identical(initial_env$wlv_initial_language(request, "")$code, "es")
  expect_identical(initial_env$wlv_initial_language(request, "CF-IPCountry")$code, "pt")
  request$HTTP_CF_IPCOUNTRY <- "XX"
  expect_identical(initial_env$wlv_initial_language(request, "CF-IPCountry")$source, "browser")
  expect_identical(initial_env$wlv_initial_language(list(), "CF-IPCountry")$source, "default")
})

test_that("browser language negotiation respects quality and rejects unsupported values", {
  expect_identical(initial_env$wlv_accept_language("fr-FR,es-AR;q=0.8,en;q=0.5"), "Français")
  expect_identical(initial_env$wlv_accept_language("en;q=0,zh-CN;q=0.9"), "中文")
  expect_identical(initial_env$wlv_accept_language("es;q=0.2,pt;q=0.8"), "Português")
  expect_null(initial_env$wlv_accept_language("en;q=0,xx;q=1,*;q=0.5"))
  expect_null(initial_env$wlv_accept_language("es;q=invalid"))
  expect_null(initial_env$wlv_supported_language("bogus"))
  request <- list(QUERY_STRING = "lang=bogus", HTTP_COOKIE = "wlv_language=xx", HTTP_ACCEPT_LANGUAGE = "zh-TW")
  expect_identical(initial_env$wlv_initial_language(request)$code, "zh")
})

test_that("new languages resolve by browser, saved choice and configured country", {
  for (code in c("fr", "de", "it", "nl", "ca", "gl", "ru", "uk", "pl", "cs", "ro", "el", "ja", "ko", "hi", "bn", "id", "vi", "th")) {
    expect_identical(initial_env$wlv_initial_language(list(HTTP_ACCEPT_LANGUAGE = code), "")$code, code)
    expect_identical(initial_env$wlv_initial_language(list(HTTP_COOKIE = paste0("wlv_language=", code)), "")$code, code)
  }
  countries <- c(FR = "fr", DE = "de", JP = "ja", KR = "ko", UA = "uk", BD = "bn", PL = "pl")
  for (country in names(countries)) {
    expect_identical(initial_env$wlv_country_language(country), initial_env$wlv_language(countries[[country]]))
  }
  expect_identical(initial_env$wlv_initial_language(list(HTTP_CF_IPCOUNTRY = "JP"), "CF-IPCountry")$code, "ja")
})
