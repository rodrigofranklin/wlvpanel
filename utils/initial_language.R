# The hosting proxy may supply an IP-derived ISO 3166-1 country. No visitor IP
# is sent to an additional service or retained by this language resolver.
wlv_supported_language <- function(value) {
  if (length(value) != 1L || is.na(value) || !nzchar(value)) return(NULL)
  native <- value %in% wlv_languages()$value
  base <- sub("[-_].*$", "", tolower(value))
  if (!native && !base %in% wlv_languages()$key) return(NULL)
  wlv_language(value)
}

wlv_country_language <- function(country) {
  if (length(country) != 1L || is.na(country)) return(NULL)
  country <- toupper(trimws(country))
  defaults <- c(FR = "fr", MC = "fr", DE = "de", AT = "de", LI = "de", IT = "it", SM = "it", VA = "it",
    NL = "nl", SR = "nl", AD = "ca", RU = "ru", UA = "uk", PL = "pl", CZ = "cs", RO = "ro", MD = "ro",
    GR = "el", CY = "el", JP = "ja", KR = "ko", IN = "hi", BD = "bn", ID = "id", VN = "vi", TH = "th")
  if (country %in% names(defaults)) return(wlv_language(defaults[[country]]))
  if (country %in% c("BR", "PT", "AO", "MZ", "CV", "GW", "ST", "TL")) return(wlv_language("pt"))
  if (country %in% c("ES", "MX", "AR", "BO", "CL", "CO", "CR", "CU", "DO", "EC", "SV", "GQ", "GT", "HN", "NI", "PA", "PY", "PE", "PR", "UY", "VE")) return(wlv_language("es"))
  if (country %in% c("CN", "TW", "HK", "MO")) return(wlv_language("zh"))
  if (country %in% c("US", "GB", "IE", "AU", "NZ", "CA", "SG", "ZA", "IN", "NG", "PH", "JM", "TT", "BZ", "GY")) return(wlv_language("en"))
  NULL
}

wlv_accept_language <- function(header) {
  if (length(header) != 1L || is.na(header) || !nzchar(header)) return(NULL)
  entries <- strsplit(header, ",", fixed = TRUE)[[1L]]
  tags <- trimws(sub(";.*$", "", entries))
  weights <- vapply(entries, function(value) {
    if (!grepl(";\\s*q\\s*=", value, perl = TRUE)) return(1)
    weight <- suppressWarnings(as.numeric(sub(".*;\\s*q\\s*=\\s*([^;]+).*$", "\\1", value, perl = TRUE)))
    if (is.na(weight) || weight < 0 || weight > 1) 0 else weight
  }, numeric(1L))
  for (index in order(-weights, seq_along(weights))) {
    if (weights[[index]] == 0) next
    language <- wlv_supported_language(tags[[index]])
    if (!is.null(language)) return(language)
  }
  NULL
}

wlv_initial_language <- function(request, country_header = Sys.getenv("WLVPANEL_COUNTRY_HEADER", ""), fallback = "Português") {
  read <- function(key) {
    value <- request[[key]]
    if (is.null(value) || length(value) != 1L || is.na(value)) "" else as.character(value)
  }
  result <- function(language, source) list(language = language, code = wlv_language_code(language), source = source)
  decode <- function(value) tryCatch(utils::URLdecode(value), error = function(e) "")
  # A shared URL and the visitor's saved choice are explicit preferences.
  query <- strsplit(sub("^\\?", "", read("QUERY_STRING")), "&", fixed = TRUE)[[1L]]
  query <- query[grepl("^lang=", query)]
  if (length(query)) {
    language <- wlv_supported_language(decode(sub("^lang=", "", query[[1L]])))
    if (!is.null(language)) return(result(language, "url"))
  }
  cookies <- trimws(strsplit(read("HTTP_COOKIE"), ";", fixed = TRUE)[[1L]])
  cookie <- cookies[grepl("^wlv_language=", cookies)]
  if (length(cookie)) {
    language <- wlv_supported_language(decode(sub("^wlv_language=", "", cookie[[1L]])))
    if (!is.null(language)) return(result(language, "saved"))
  }
  # Opt in to the header the trusted hosting proxy overwrites. Never infer
  # geolocation from an arbitrary visitor-provided X-Forwarded-For value.
  if (nzchar(country_header) && grepl("^[A-Za-z][A-Za-z0-9_-]*$", country_header)) {
    key <- toupper(gsub("-", "_", country_header, fixed = TRUE))
    if (!startsWith(key, "HTTP_")) key <- paste0("HTTP_", key)
    language <- wlv_country_language(read(key))
    if (!is.null(language)) return(result(language, "country"))
  }
  language <- wlv_accept_language(read("HTTP_ACCEPT_LANGUAGE"))
  if (!is.null(language)) return(result(language, "browser"))
  result(wlv_language(fallback), "default")
}
