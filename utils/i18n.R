# Rótulos estáticos são traduzidos em lote, sem recriar os controles.
# Um registro único mantém nomes nativos, códigos HTML e disponibilidade alinhados.
wlv_i18n_root <- function() {
  if (file.exists("config/languages.json")) return(".")
  if (exists("wlvpanel_test_root", inherits = TRUE)) return(get("wlvpanel_test_root", inherits = TRUE))
  # R also sources helpers from tests/testthat in isolated environments.
  if (file.exists("../../config/languages.json")) return("../..")
  stop("Cannot locate the panel language registry.", call. = FALSE)
}
wlv_languages <- local({
  registry <- NULL
  function() {
    if (is.null(registry)) {
      registry <<- jsonlite::fromJSON(file.path(wlv_i18n_root(), "config/languages.json"))
      registry$available <<- rep(TRUE, nrow(registry))
    }
    registry
  }
})
wlv_language <- function(lang = "Português") {
  if (length(lang) != 1L || is.na(lang)) return("Português")
  languages <- wlv_languages()
  index <- match(lang, languages$value)
  if (is.na(index)) index <- match(tolower(lang), tolower(languages$code))
  if (is.na(index)) index <- match(sub("[-_].*$", "", tolower(lang)), languages$key)
  if (is.na(index) || !languages$available[[index]]) return("Português")
  languages$value[[index]]
}
wlv_language_column <- wlv_language
wlv_language_name <- wlv_language
wlv_language_code <- function(lang) {
  registry <- wlv_languages()
  registry$key[[match(wlv_language(lang), registry$value)]]
}
wlv_language_locale <- function(lang) {
  registry <- wlv_languages()
  registry$code[[match(wlv_language(lang), registry$value)]]
}
wlv_number_marks <- function(lang) {
  registry <- wlv_languages()
  row <- registry[match(wlv_language(lang), registry$value), ]
  list(decimal = row$decimal, grouping = row$grouping)
}
wlv_plotly_separators <- function(lang) {
  marks <- wlv_number_marks(lang)
  paste0(marks$decimal, marks$grouping)
}
wlv_plotly_config <- function(chart, lang, ...) {
  code <- wlv_language_code(lang)
  if (!code %in% c("hi", "bn")) return(plotly::config(chart, ..., locale = tolower(wlv_language_locale(lang))))
  chart <- plotly::config(chart, ...)
  chart$x$config$locale <- code
  chart$dependencies <- c(chart$dependencies, list(htmltools::htmlDependency(
    name = "wlv-plotly-locales", version = "1.0.0", src = c(file = file.path(wlv_i18n_root(), "www")),
    script = "wlv-plotly-locales.js", all_files = FALSE)))
  chart
}
wlv_locale_catalogs <- local({
  cache <- NULL
  function(refresh = FALSE) {
    if (!is.null(cache) && !refresh) return(cache)
    keys <- setdiff(wlv_languages()$key, c("pt", "en", "es", "zh"))
    cache <<- setNames(lapply(keys, function(key) {
      jsonlite::fromJSON(file.path(wlv_i18n_root(), "config/locales", paste0(key, ".json")), simplifyVector = FALSE)
    }), keys)
    cache
  }
})
wlv_complete_locale_languages <- function(dictionary) {
  dictionary <- as.data.frame(dictionary, stringsAsFactors = FALSE)
  catalogs <- wlv_locale_catalogs()
  for (key in names(catalogs)) {
    labels <- catalogs[[key]]$labels
    dictionary[names(labels), wlv_language(key)] <- unlist(labels, use.names = FALSE)
  }
  # Separators describe numeric formatting and must never pass through translation.
  for (key in wlv_languages()$key) {
    marks <- wlv_number_marks(key)
    dictionary[c("big.mark", "decimal.mark"), wlv_language(key)] <- c(marks$grouping, marks$decimal)
  }
  dictionary
}

# One catalogue is shared by R and the browser. Text keys cover dynamic UI,
# while code-keyed catalogues also contribute their existing English wording.
wlv_text_catalog <- local({
  cache <- NULL
  function(refresh = FALSE) {
    if (!is.null(cache) && !refresh) return(cache)
    root <- wlv_i18n_root()
    cache <<- list()
    coded <- c("translations", "about-translations", "indicator-translations", "method-translations", "legacy-translations")
    literal <- c("core-translations", "exploration-translations", "trade-translations", "client-translations")
    for (name in c(coded, literal)) {
      path <- file.path(root, "config", paste0(name, ".json"))
      if (!file.exists(path)) next
      entries <- jsonlite::fromJSON(path, simplifyVector = FALSE)
      for (key in names(entries)) {
        entry <- entries[[key]]
        source <- if (name %in% coded) entry$en else key
        if (is.null(source) || !is.character(source) || !nzchar(source)) next
        previous <- cache[[source]]
        for (code in setdiff(wlv_languages()$key, c("pt", "en"))) {
          if (!is.null(entry[[code]])) previous[[code]] <- entry[[code]]
        }
        cache[[source]] <<- previous
      }
    }
    locales <- wlv_locale_catalogs(refresh)
    for (code in names(locales)) for (key in names(locales[[code]]$phrases)) {
      cache[[key]][[code]] <<- locales[[code]]$phrases[[key]]
    }
    cache
  }
})

wlv_tr <- function(pt, en, lang = default_language, es = NULL, zh = NULL) {
  code <- wlv_language_code(lang)
  if (code == "pt") return(pt)
  if (code == "en") return(en)
  supplied <- switch(code, es = es, zh = zh, NULL)
  if (!is.null(supplied)) return(supplied)
  if (!length(en)) return(en)
  catalog <- wlv_text_catalog()
  translated <- vapply(as.character(en), function(key) {
    if (is.na(key)) return(NA_character_)
    value <- catalog[[key]][[code]]
    if (is.null(value) || !nzchar(value)) key else value
  }, character(1L), USE.NAMES = FALSE)
  names(translated) <- names(en)
  translated
}
wlv_client_phrases <- function(lang) {
  code <- wlv_language_code(lang)
  if (code %in% c("pt", "en")) return(list())
  lapply(wlv_text_catalog(), function(entry) entry[intersect(names(entry), code)])
}

# One immutable payload per language/process is shared by HTML and WebSocket.
wlv_language_payload_cache <- function(dictionary) {
  cache <- new.env(parent = emptyenv())
  force(dictionary)
  function(lang) {
    lang <- wlv_language(lang)
    if (!exists(lang, envir = cache, inherits = FALSE)) {
      message <- list(lang = lang,
        labels = setNames(as.list(wlv_label(rownames(dictionary), lang, dictionary)), rownames(dictionary)),
        phrases = wlv_client_phrases(lang))
      message$fingerprint <- digest::digest(message, algo = "sha256")
      assign(lang, message, envir = cache)
    }
    get(lang, envir = cache, inherits = FALSE)
  }
}

wlv_language_delivery <- function(input, session, messages) {
  delivered <- NULL
  send <- function(message) {
    session$sendCustomMessage("wlv-language", message)
    delivered <<- message$fingerprint
  }
  language <- shiny::observe({
    shiny::req(input$l)
    message <- messages(input$l)
    if (is.null(delivered) && identical(shiny::isolate(input$wlv_language_bootstrap), message$fingerprint)) {
      delivered <<- message$fingerprint
    }
    if (!identical(delivered, message$fingerprint)) send(message)
  })
  # A new socket can reconnect an existing page to a restarted R process.
  sync <- shiny::observeEvent(input$wlv_language_sync, {
    shiny::req(input$l)
    message <- messages(input$l)
    handshake <- input$wlv_language_sync
    if (!is.list(handshake)) return()
    reconnect <- is.list(handshake) && is.numeric(handshake$connection) &&
      length(handshake$connection) == 1L && !is.na(handshake$connection) && handshake$connection > 1
    if (!identical(handshake$fingerprint, message$fingerprint) &&
        (is.null(delivered) || reconnect)) send(message)
  }, ignoreNULL = TRUE)
  invisible(list(language = language, sync = sync))
}
# Keep translated sentence order while rendering interpolated nodes safely.
wlv_fill_template <- function(template, values) {
  matches <- gregexpr("\\{[A-Za-z_][A-Za-z_0-9]*\\}", template, perl = TRUE)[[1L]]
  if (matches[[1L]] == -1L) return(htmltools::tagList(template))
  lengths <- attr(matches, "match.length")
  pieces <- list(); cursor <- 1L
  for (index in seq_along(matches)) {
    start <- matches[[index]]; end <- start + lengths[[index]] - 1L
    if (start > cursor) pieces[[length(pieces) + 1L]] <- substr(template, cursor, start - 1L)
    key <- substr(template, start + 1L, end - 1L)
    if (!key %in% names(values)) stop("Unknown translation placeholder: ", key, call. = FALSE)
    pieces[[length(pieces) + 1L]] <- values[[key]]
    cursor <- end + 1L
  }
  if (cursor <= nchar(template)) pieces[[length(pieces) + 1L]] <- substr(template, cursor, nchar(template))
  do.call(htmltools::tagList, pieces)
}
wlv_unit_label <- function(unit, lng = default_language) {
  unit <- sub("^legacy:", "", unit)
  switch(unit,
    percent = "%", usd = "US$",
    hour = wlv_tr("Horas", "Hours", lng),
    hours = wlv_tr("Horas", "Hours", lng),
    person = wlv_tr("Pessoas", "People", lng),
    integer = wlv_tr("Pessoas", "People", lng),
    ratio = wlv_tr("Razão", "Ratio", lng),
    multiplier = wlv_tr("Multiplicador", "Multiplier", lng),
    index = wlv_tr("Índice", "Index", lng),
    index_point = wlv_tr("Pontos de índice", "Index points", lng),
    local_currency_per_usd = wlv_tr("Moeda local/US$", "Local currency/US$", lng),
    value = "mv", abstract_labour_hour = "mv",
    abstract_labour_hour_per_usd = "mv/US$",
    abstract_labour_hour_per_person = wlv_tr("mv/pessoa", "mv/person", lng),
    unit
  )
}
wlv_complete_language <- function(original, path = "config/translations.json") {
  original <- as.data.frame(original, stringsAsFactors = FALSE)
  for (name in wlv_languages()$value) {
    if (!name %in% names(original)) original[[name]] <- NA_character_
  }
  translations <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  for (code in names(translations)) {
    entry <- translations[[code]]
    if (!code %in% rownames(original)) original[code, ] <- NA_character_
    for (lang in wlv_languages()$key) {
      if (!is.null(entry[[lang]])) original[code, wlv_language(lang)] <- entry[[lang]]
    }
  }
  original
}
wlv_label <- function(code, lang, dictionary) {
  indices <- match(code, rownames(dictionary))
  column <- wlv_language(lang)
  value <- if (column %in% colnames(dictionary)) dictionary[indices, column] else rep(NA_character_, length(indices))
  missing <- is.na(value) | !nzchar(value)
  value[missing] <- dictionary[indices[missing], "English"]
  missing <- is.na(value) | !nzchar(value)
  value[missing] <- code[missing]
  unname(value)
}
