exploration_env <- new.env(parent = environment())
source(file.path(wlvpanel_test_root, "modules", "indicators", "main.R"),
  local = exploration_env, encoding = "UTF-8")
source(file.path(wlvpanel_test_root, "utils", "country_landing_charts.R"),
  local = exploration_env, encoding = "UTF-8")
source(file.path(wlvpanel_test_root, "utils", "download_workbooks.R"),
  local = exploration_env, encoding = "UTF-8")
publication_expressions <- parse(file.path(wlvpanel_test_root, "modules", "publications", "main.R"), encoding = "UTF-8")
for (expression in publication_expressions) {
  if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
      is.symbol(expression[[2L]]) &&
      is.call(expression[[3L]]) && identical(expression[[3L]][[1L]], as.name("function"))) {
    eval(expression, envir = exploration_env)
  }
}

test_that("exploration controls translate native labels and preserve multilingual searches", {
  expect_identical(exploration_env$wlv_indicators_text("all", "es"), "Todos los países")
  expect_identical(exploration_env$wlv_indicators_text("all", "zh"), "所有国家")
  expect_identical(exploration_env$wlv_indicators_unit_label("hour", "zh"), "小时")
  expect_identical(exploration_env$wlv_indicators_subgroup_label("surplus_value", "es"), "Plusvalor")
  expect_identical(exploration_env$wlv_indicators_fold("中国劳动 Áustria"), "中国劳动 austria")
  highlighted <- as.character(exploration_env$wlv_indicators_highlight("中国的劳动", "劳动"))
  expect_match(highlighted, "中国的<mark>劳动</mark>", fixed = TRUE)
  expect_identical(exploration_env$wlv_publications_text("all_authors", "zh"), "所有成员")
  entries <- list(list(title = "中国劳动", authors = "Author", venue = "Venue", members = "one", year = 2020),
    list(title = "Other study", authors = "Author", venue = "Venue", members = "one", year = 2021))
  filtered <- exploration_env$wlv_publications_filter(entries, search = "中国")
  expect_length(filtered, 1L)
  expect_identical(filtered[[1L]]$title, "中国劳动")
})

test_that("country charts keep numbers and accessible text localized", {
  expect_identical(exploration_env$wlv_country_landing_number(1234.56, "es"), "1.234,56")
  expect_identical(exploration_env$wlv_country_landing_number(1234.56, "zh"), "1,234.56")
  expect_identical(exploration_env$wlv_country_landing_number(NA_real_, "zh"), "不可用")
  chart_es <- as.character(exploration_env$wlv_country_landing_chart(2000:2001, c(10, 12), c(4, 5), lang = "es"))
  chart_zh <- as.character(exploration_env$wlv_country_landing_chart(2000:2001, c(10, 12), c(4, 5), lang = "zh"))
  expect_match(chart_es, "Plusvalor", fixed = TRUE)
  expect_match(chart_zh, "剩余价值", fixed = TRUE)
  expect_false(grepl("Jornada de trabalho|Value of labour power|Surplus value", chart_zh))
})

test_that("indicator and workbook country labels use all four dictionary columns", {
  dictionary <- data.frame("Português" = "Brasil", "English" = "Brazil", "Castellano" = "Brasil",
    "中文" = "巴西", row.names = "ISO3.BRA", check.names = FALSE)
  expect_identical(exploration_env$wlv_indicators_label(dictionary, "ISO3.BRA", "zh"), "巴西")
  expect_identical(exploration_env$wlv_indicators_label(dictionary, "missing", "es", "fallback"), "fallback")
  expect_identical(exploration_env$wlv_country_axis_names("BRA", dictionary, "zh"), "巴西")
  expect_identical(exploration_env$wlv_country_axis_names("BRA", as.matrix(dictionary), "es"), "Brasil")
  expect_error(exploration_env$wlv_country_axis_names("BRA", dictionary, "unknown"), "valid country axis and language table")
})
