# Rótulos estáticos são traduzidos em lote, sem recriar os controles.
wlv_language <- function(lang = "Português") {
  if (length(lang) == 1L && !is.na(lang) && lang %in% c("English", "en")) "English" else "Português"
}
wlv_tr <- function(pt, en, lang = default_language) {
  if (wlv_language(lang) == "English") en else pt
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
  translations <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  for (code in names(translations)) {
    entry <- translations[[code]]
    if (!code %in% rownames(original)) original[code, ] <- NA_character_
    if (!is.null(entry$pt)) original[code, "Português"] <- entry$pt
    if (!is.null(entry$en)) original[code, "English"] <- entry$en
  }
  original
}
wlv_label <- function(code, lang, dictionary) {
  indices <- match(code, rownames(dictionary))
  value <- dictionary[indices, wlv_language(lang)]
  missing <- is.na(value) | !nzchar(value)
  value[missing] <- dictionary[indices[missing], "English"]
  missing <- is.na(value) | !nzchar(value)
  value[missing] <- code[missing]
  unname(value)
}
