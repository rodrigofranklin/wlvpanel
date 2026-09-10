test_that("language payloads are identical for native names and codes and version content", {
  env <- new.env(parent = environment())
  env$wlvpanel_test_root <- wlvpanel_test_root
  sys.source(file.path(wlvpanel_test_root, "utils/i18n.R"), env)
  dictionary <- data.frame(English = "One", Português = "Um", Français = "Un", row.names = "test", check.names = FALSE)
  messages <- env$wlv_language_payload_cache(dictionary)
  expect_identical(messages("fr"), messages("Français"))
  expect_identical(messages("fr")$labels$test, "Un")
  dictionary$Français <- "Une autre valeur"
  changed <- env$wlv_language_payload_cache(dictionary)
  expect_false(identical(messages("fr")$fingerprint, changed("fr")$fingerprint))
  expect_identical(messages("fr")$labels$test, "Un")
})

test_that("matching bootstrap suppresses only redundant delivery and stale reconnect resynchronizes", {
  env <- new.env(parent = environment())
  env$wlvpanel_test_root <- wlvpanel_test_root
  sys.source(file.path(wlvpanel_test_root, "utils/i18n.R"), env)
  shiny::testServer(function(input, output, session) {
    sent <- new.env(parent = emptyenv())
    sent$messages <- list()
    session$sendCustomMessage <- function(type, message) { sent$messages[[length(sent$messages) + 1L]] <- list(type = type, message = message) }
    messages <- function(lang) list(lang = lang, fingerprint = paste0("version-", lang), labels = list(title = lang), phrases = list())
    env$wlv_language_delivery(input, session, messages)
  }, {
    session$setInputs(l = "fr", wlv_language_bootstrap = "version-fr",
      wlv_language_sync = list(fingerprint = "version-fr", connection = 1))
    expect_length(sent$messages, 0L)
    session$setInputs(l = "bn")
    expect_length(sent$messages, 1L)
    expect_identical(sent$messages[[1L]]$message$lang, "bn")
    session$setInputs(wlv_language_sync = list(fingerprint = "version-bn", connection = 2))
    expect_length(sent$messages, 1L)
    session$setInputs(wlv_language_sync = list(fingerprint = "stale", connection = 3))
    expect_length(sent$messages, 2L)
    expect_identical(sent$messages[[2L]]$message$fingerprint, "version-bn")
    session$setInputs(wlv_language_sync = "malformed")
    expect_length(sent$messages, 2L)
  })
})

test_that("absent and outdated bootstraps retain the full initial response", {
  env <- new.env(parent = environment())
  env$wlvpanel_test_root <- wlvpanel_test_root
  sys.source(file.path(wlvpanel_test_root, "utils/i18n.R"), env)
  for (bootstrap in list(NULL, "old-version")) {
    shiny::testServer(function(input, output, session) {
      sent <- new.env(parent = emptyenv())
      sent$messages <- list()
      session$sendCustomMessage <- function(type, message) { sent$messages[[length(sent$messages) + 1L]] <- message }
      env$wlv_language_delivery(input, session, function(lang) list(lang = lang, fingerprint = "current-version"))
    }, {
      session$setInputs(l = "fr", wlv_language_bootstrap = bootstrap)
      expect_length(sent$messages, 1L)
      expect_identical(sent$messages[[1L]]$fingerprint, "current-version")
    })
  }
})
