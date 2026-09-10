# Consultas do Comércio. Nenhuma leitura ocorre ao carregar este arquivo ou ao
# construir o store: os dados são abertos somente na primeira solicitação.

wlv_trade_scalar <- function(value, name) {
  if (length(value) != 1L || is.na(value) || !nzchar(as.character(value)))
    stop(sprintf("Seleção inválida: %s.", name), call. = FALSE)
  as.character(value)
}

wlv_trade_validate_bilateral <- function(values, method = NULL) {
  axes <- dimnames(values)
  required <- c("exports_mp", "exports_productive_mp", "exports_values",
    "transfers_values", "transfers_productive_values", "transfers_dp",
    "transfers_productive_dp")
  if (!is.numeric(values) || length(dim(values)) != 4L || length(axes) != 4L ||
      any(vapply(axes, function(x) is.null(x) || anyNA(x) || anyDuplicated(x) > 0L,
        logical(1L))) || !all(required %in% axes[[2L]]) ||
      !identical(axes[[3L]], axes[[4L]]) || any(is.infinite(values)))
    stop("Estrutura bilateral de Comércio inválida.", call. = FALSE)
  if (!is.null(method)) attr(values, "method") <- method
  values
}

wlv_trade_options <- function(metric, scope, unit) {
  list(metric = match.arg(metric, c("transfer", "exports", "imports", "balance")),
    scope = match.arg(scope, c("total", "productive", "unproductive")),
    unit = match.arg(unit, c("value", "usd")))
}

wlv_trade_empty <- function() {
  data.frame(id = character(), key = character(), partner = character(),
    sector = character(), year = integer(), value = numeric(), outgoing = numeric(),
    incoming = numeric(), coverage = character(), observed = integer(),
    expected = integer(), unit = character(), metric = character(), scope = character(),
    stringsAsFactors = FALSE)
}

# NA continua ausente. Uma soma parcial nunca é apresentada como total completo.
wlv_trade_total <- function(x) {
  if (!length(x) || any(!is.finite(x))) NA_real_ else sum(x)
}

wlv_trade_reduce <- function(rows, metric, scope, unit, dimension = "partner") {
  if (!nrow(rows)) return(wlv_trade_empty())
  keys <- if (dimension == "year") as.character(rows$year) else rows[[dimension]]
  groups <- split(seq_len(nrow(rows)), factor(keys, levels = unique(keys)))
  result <- lapply(names(groups), function(key) {
    x <- rows[groups[[key]], , drop = FALSE]
    outgoing <- wlv_trade_total(x$outgoing)
    incoming <- wlv_trade_total(x$incoming)
    components <- switch(metric, exports = x$outgoing, imports = x$incoming,
      c(x$outgoing, x$incoming))
    observed <- sum(is.finite(components)); expected <- length(components)
    value <- switch(metric, exports = outgoing, imports = incoming,
      outgoing - incoming)
    data.frame(id = key, key = key,
      partner = if (dimension == "partner") key else NA_character_,
      sector = if (dimension == "sector") key else NA_character_,
      year = as.integer(x$year[[1L]]), value = value, outgoing = outgoing,
      incoming = incoming,
      coverage = if (observed == expected) "complete" else if (observed) "partial" else "missing",
      observed = as.integer(observed), expected = as.integer(expected),
      unit = unit, metric = metric, scope = scope, stringsAsFactors = FALSE)
  })
  result <- do.call(rbind, result); rownames(result) <- NULL
  result
}

wlv_trade_bilateral_rows <- function(data, country, years, metric, scope, unit,
    partner = NULL) {
  axes <- dimnames(data)
  country <- wlv_trade_scalar(country, "country")
  if (!country %in% axes[[3L]] || country == "WWW")
    stop("País ausente da base bilateral.", call. = FALSE)
  partners <- setdiff(axes[[4L]], c(country, "WWW"))
  if (!is.null(partner) && length(partner)) {
    if (anyNA(partner) || !all(partner %in% partners))
      stop("Parceiro ausente da base bilateral.", call. = FALSE)
    partners <- unique(as.character(partner))
  }
  years <- intersect(as.character(years), axes[[1L]])
  if (!length(years) || !length(partners))
    return(data.frame(partner = character(), year = integer(), outgoing = numeric(), incoming = numeric()))
  if (metric == "transfer") {
    suffix <- if (unit == "value") "values" else "dp"
    total_key <- paste0("transfers_", suffix)
    productive_key <- paste0("transfers_productive_", suffix)
  } else {
    total_key <- if (unit == "value") "exports_values" else "exports_mp"
    productive_key <- if (unit == "value") "exports_values" else "exports_productive_mp"
  }
  direction <- function(reverse) {
    extract <- function(key) {
      if (reverse) as.numeric(data[years, key, partners, country, drop = FALSE])
      else as.numeric(data[years, key, country, partners, drop = FALSE])
    }
    total <- extract(total_key)
    if (scope == "total") return(total)
    productive <- extract(productive_key)
    if (scope == "productive") productive else total - productive
  }
  rows <- expand.grid(year = as.integer(years), partner = partners,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  rows$outgoing <- direction(FALSE); rows$incoming <- direction(TRUE)
  rows
}

wlv_trade_available_years <- function(data, country = NULL, metric = "transfer",
    scope = "total", unit = "value") {
  option <- wlv_trade_options(metric, scope, unit)
  axes <- dimnames(data)
  countries <- if (is.null(country)) setdiff(axes[[3L]], "WWW") else country
  available <- lapply(countries, function(code) {
    rows <- wlv_trade_bilateral_rows(data, code, axes[[1L]], option$metric,
      option$scope, option$unit)
    observed <- switch(option$metric, exports = is.finite(rows$outgoing),
      imports = is.finite(rows$incoming),
      is.finite(rows$outgoing) & is.finite(rows$incoming))
    unique(rows$year[observed])
  })
  sort(unique(as.integer(unlist(available, use.names = FALSE))))
}

wlv_trade_detail_rows <- function(detail, data, country, year, metric, scope,
    unit, partner = NULL, sector = NULL) {
  if (is.null(detail)) stop("Detalhamento setorial indisponível para esta seleção.", call. = FALSE)
  if (!is.data.frame(detail)) stop("Partição setorial inválida.", call. = FALSE)
  if (!identical(as.character(attr(detail, "year")), as.character(year)) ||
      (!is.null(attr(data, "method")) &&
        !identical(attr(detail, "method"), attr(data, "method"))))
    stop("Partição setorial não corresponde à base e ao ano solicitados.", call. = FALSE)
  countries <- setdiff(dimnames(data)[[3L]], c(country, "WWW"))
  if (!is.null(partner) && length(partner)) {
    if (!all(partner %in% countries)) stop("Parceiro inválido.", call. = FALSE)
    countries <- unique(as.character(partner))
  }
  sectors <- unique(as.character(detail$sector))
  productivity <- vapply(sectors, function(code) {
    unique_value <- unique(detail$productive[detail$sector == code])
    if (length(unique_value) != 1L || is.na(unique_value))
      stop("Classificação produtiva setorial inconsistente.", call. = FALSE)
    unique_value
  }, logical(1L))
  if (scope != "total") sectors <- sectors[productivity == (scope == "productive")]
  if (!is.null(sector) && length(sector)) {
    if (anyNA(sector) || !all(sector %in% unique(detail$sector)))
      stop("Setor ausente da partição.", call. = FALSE)
    sectors <- intersect(sectors, as.character(sector))
  }
  rows <- expand.grid(partner = countries, sector = sectors,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
  rows$year <- rep(as.integer(year), nrow(rows))
  if (!nrow(rows)) {
    rows$outgoing <- numeric(); rows$incoming <- numeric()
    return(rows)
  }
  column <- if (metric == "transfer") "transfer_hours" else if (unit == "usd")
    "exports_usd" else "embodied_hours"
  key <- function(a, b, s) paste(a, b, s, sep = "\034")
  data_keys <- key(detail$country, detail$partner, detail$sector)
  rows$outgoing <- detail[[column]][match(key(country, rows$partner, rows$sector), data_keys)]
  rows$incoming <- detail[[column]][match(key(rows$partner, country, rows$sector), data_keys)]
  if (metric == "transfer" && unit == "usd") {
    factor <- attr(detail, "factor_usd_per_hour")
    if (length(factor) != 1L || !is.finite(factor) || factor <= 0)
      stop("Fator anual de conversão de transferências indisponível.", call. = FALSE)
    rows$outgoing <- rows$outgoing * factor; rows$incoming <- rows$incoming * factor
  }
  rows
}

# Setor significa setor fornecedor do produto, inclusive nas importações.
# Transferência líquida positiva = apropriação do país: tau saída - tau entrada.
wlv_trade_snapshot <- function(data, country, year, metric = "transfer",
    scope = "total", unit = "value", dimension = "partner", partner = NULL,
    detail = NULL, sector = NULL) {
  option <- wlv_trade_options(metric, scope, unit)
  dimension <- match.arg(dimension, c("partner", "sector"))
  year <- wlv_trade_scalar(year, "year")
  use_detail <- dimension == "sector" || (!is.null(sector) && length(sector) > 0L)
  if (!use_detail) {
    rows <- wlv_trade_bilateral_rows(data, country, year, option$metric,
      option$scope, option$unit, partner)
  } else {
    rows <- wlv_trade_detail_rows(detail, data, country, year, option$metric,
      option$scope, option$unit, partner, sector)
  }
  result <- wlv_trade_reduce(rows, option$metric, option$scope, option$unit, dimension)
  attr(result, "method") <- attr(data, "method")
  attr(result, "version") <- if (use_detail) attr(detail, "version") else NULL
  attr(result, "provenance") <- if (use_detail) attr(detail, "provenance") else NULL
  attr(result, "available_years") <- wlv_trade_available_years(data, country,
    option$metric, option$scope, option$unit)
  attr(result, "sector_definition") <- if (use_detail) "supplier" else NULL
  result
}

wlv_trade_series <- function(data, country, metric = "transfer", scope = "total",
    unit = "value", partner = NULL, years = NULL) {
  option <- wlv_trade_options(metric, scope, unit)
  if (is.null(years)) years <- dimnames(data)[[1L]]
  rows <- wlv_trade_bilateral_rows(data, country, years, option$metric,
    option$scope, option$unit, partner)
  result <- wlv_trade_reduce(rows, option$metric, option$scope, option$unit, "year")
  result <- result[order(result$year), , drop = FALSE]
  attr(result, "method") <- attr(data, "method")
  attr(result, "available_years") <- wlv_trade_available_years(data, country,
    option$metric, option$scope, option$unit)
  result
}

wlv_trade_validate_manifest <- function(manifest) {
  if (!is.list(manifest) || !identical(as.integer(manifest$schema_version), 1L) ||
      length(manifest$version) != 1L || is.na(manifest$version) || !nzchar(manifest$version) ||
      !is.list(manifest$methods) || is.null(names(manifest$methods)) ||
      length(manifest$bilateral_sha256) != 1L || is.na(manifest$bilateral_sha256) ||
      !grepl("^[a-fA-F0-9]{64}$", manifest$bilateral_sha256) ||
      !is.data.frame(manifest$partitions) ||
      !all(c("method", "year", "file", "sha256", "rows") %in% names(manifest$partitions)))
    stop("Manifesto setorial de Comércio inválido ou incompatível.", call. = FALSE)
  partitions <- manifest$partitions
  if (anyNA(partitions[c("method", "year", "file", "sha256", "rows")]) ||
      anyDuplicated(paste(partitions$method, partitions$year)) ||
      any(!grepl("^[a-fA-F0-9]{64}$", partitions$sha256)) ||
      !all(partitions$method %in% names(manifest$methods)))
    stop("Índice das partições de Comércio inválido.", call. = FALSE)
  manifest
}

wlv_trade_validate_partition <- function(partition, manifest, entry) {
  if (!is.list(partition) || !identical(as.integer(partition$schema_version), 1L) ||
      !identical(as.character(partition$version), as.character(manifest$version)) ||
      !identical(as.character(partition$method), as.character(entry$method)) ||
      !identical(as.character(partition$year), as.character(entry$year)))
    stop("Identidade da partição de Comércio incompatível com o manifesto.", call. = FALSE)
  data <- partition$data
  required <- c("country", "partner", "sector", "productive", "exports_usd",
    "embodied_hours", "transfer_hours")
  if (!is.data.frame(data) || !all(required %in% names(data)) ||
      nrow(data) != entry$rows || !is.logical(data$productive) ||
      anyNA(data[c("country", "partner", "sector", "productive")]) ||
      any(data$country == data$partner) || any(data$country == "WWW" | data$partner == "WWW") ||
      anyDuplicated(paste(data$country, data$partner, data$sector, sep = "\034")) ||
      !all(vapply(data[c("exports_usd", "embodied_hours", "transfer_hours")],
        function(x) is.numeric(x) && !any(is.infinite(x)), logical(1L))))
    stop("Conteúdo da partição de Comércio inválido.", call. = FALSE)
  factor <- partition$factor_usd_per_hour
  if (length(factor) != 1L || !is.finite(factor) || factor <= 0)
    stop("Fator anual da partição de Comércio inválido.", call. = FALSE)
  method <- manifest$methods[[partition$method]]
  countries <- as.character(method$countries); sectors <- as.character(method$sectors)
  if (length(countries) < 2L || !length(sectors) || anyNA(countries) || anyNA(sectors) ||
      anyDuplicated(countries) || anyDuplicated(sectors) || "WWW" %in% countries ||
      nrow(data) != length(countries) * (length(countries) - 1L) * length(sectors) ||
      !setequal(data$country, countries) || !setequal(data$partner, countries) ||
      !setequal(data$sector, sectors) ||
      !all(vapply(split(data$productive, data$sector), function(x) length(unique(x)) == 1L,
        logical(1L))))
    stop("Grade setorial incompleta ou incompatível com o manifesto.", call. = FALSE)
  if ("transfer_usd" %in% names(data) &&
      (!is.numeric(data$transfer_usd) || !isTRUE(all.equal(data$transfer_usd,
        data$transfer_hours * factor, tolerance = 1e-10, check.attributes = FALSE))))
    stop("Conversão monetária da partição diverge do fator anual.", call. = FALSE)
  attr(data, "method") <- partition$method
  attr(data, "year") <- as.character(partition$year)
  attr(data, "version") <- partition$version
  attr(data, "factor_usd_per_hour") <- factor
  attr(data, "provenance") <- manifest$provenance
  data
}

wlv_trade_data_store <- function(bilateral_path = "data/m_countries.RDS",
    detail_root = "data/trade", cache_size = 3L, max_cache_bytes = 64 * 1024^2,
    reader = readRDS, hash_file = function(path) digest::digest(file = path,
      algo = "sha256", serialize = FALSE)) {
  if (length(cache_size) != 1L || !is.finite(cache_size) || cache_size < 0L ||
      length(max_cache_bytes) != 1L || !is.finite(max_cache_bytes) || max_cache_bytes < 0)
    stop("Limite de cache inválido.", call. = FALSE)
  bilateral <- NULL; bilateral_sha256 <- NULL; manifest <- NULL; manifest_checked <- FALSE
  cache <- list(); recency <- character()
  reads <- c(bilateral = 0L, manifest = 0L, detail = 0L); cache_hits <- 0L
  load_bilateral <- function() {
    if (is.null(bilateral)) {
      signature <- hash_file(bilateral_path)
      candidate <- reader(bilateral_path); reads[["bilateral"]] <<- reads[["bilateral"]] + 1L
      if (!identical(signature, hash_file(bilateral_path)))
        stop("Catálogo bilateral foi alterado durante a leitura.", call. = FALSE)
      if (!is.list(candidate) || !length(candidate) || is.null(names(candidate)) ||
          anyNA(names(candidate)) || anyDuplicated(names(candidate)))
        stop("Catálogo bilateral de Comércio inválido.", call. = FALSE)
      for (method in names(candidate))
        candidate[[method]] <- wlv_trade_validate_bilateral(candidate[[method]], method)
      if (as.numeric(utils::object.size(candidate)) > 128 * 1024^2)
        stop("Catálogo bilateral excede o limite de memória de 128 MiB.", call. = FALSE)
      bilateral <<- candidate
      bilateral_sha256 <<- signature
    }
    bilateral
  }
  load_manifest <- function() {
    if (!manifest_checked) {
      path <- file.path(detail_root, "manifest.rds")
      if (file.exists(path)) {
        candidate <- reader(path); reads[["manifest"]] <<- reads[["manifest"]] + 1L
        candidate <- wlv_trade_validate_manifest(candidate)
        load_bilateral()
        if (!identical(tolower(candidate$bilateral_sha256), tolower(bilateral_sha256)))
          stop("Manifesto setorial pertence a outro catálogo bilateral.", call. = FALSE)
        manifest <<- candidate
      }
      manifest_checked <<- TRUE
    }
    manifest
  }
  get_bilateral <- function(method) {
    method <- wlv_trade_scalar(method, "method")
    catalogue <- load_bilateral()
    if (!method %in% names(catalogue)) stop("Base bilateral inexistente.", call. = FALSE)
    catalogue[[method]]
  }
  get_detail <- function(method, year) {
    method <- wlv_trade_scalar(method, "method"); year <- wlv_trade_scalar(year, "year")
    index <- load_manifest()
    if (is.null(index)) return(NULL)
    entry <- index$partitions[index$partitions$method == method &
      as.character(index$partitions$year) == year, , drop = FALSE]
    if (!nrow(entry)) return(NULL)
    key <- paste(method, year, index$version, entry$sha256, sep = "|")
    if (key %in% names(cache)) {
      cache_hits <<- cache_hits + 1L; recency <<- c(setdiff(recency, key), key)
      return(cache[[key]])
    }
    relative <- gsub("\\", "/", entry$file, fixed = TRUE)
    if (grepl("^([A-Za-z]:|/)|(^|/)\\.\\.(/|$)", relative))
      stop("Caminho de partição fora do diretório de Comércio.", call. = FALSE)
    root <- normalizePath(detail_root, winslash = "/", mustWork = TRUE)
    path <- normalizePath(file.path(root, relative), winslash = "/", mustWork = TRUE)
    if (!startsWith(tolower(path), paste0(tolower(root), "/")))
      stop("Caminho de partição fora do diretório de Comércio.", call. = FALSE)
    if (!identical(tolower(hash_file(path)), tolower(entry$sha256)))
      stop("Hash da partição de Comércio diverge do manifesto.", call. = FALSE)
    partition <- reader(path); reads[["detail"]] <<- reads[["detail"]] + 1L
    data <- wlv_trade_validate_partition(partition, index, entry)
    if (cache_size > 0L && as.numeric(utils::object.size(data)) <= max_cache_bytes) {
      cache[[key]] <<- data; recency <<- c(recency, key)
      while (length(cache) > cache_size ||
          sum(vapply(cache, function(x) as.numeric(utils::object.size(x)), numeric(1L))) > max_cache_bytes) {
        cache[[recency[[1L]]]] <<- NULL; recency <<- recency[-1L]
      }
    }
    data
  }
  list(methods = function() names(load_bilateral()), bilateral = get_bilateral,
    countries = function(method) setdiff(dimnames(get_bilateral(method))[[3L]], "WWW"),
    years = function(method, country = NULL, metric = "transfer", scope = "total", unit = "value")
      wlv_trade_available_years(get_bilateral(method), country, metric, scope, unit),
    detail = get_detail,
    detail_years = function(method) {
      index <- load_manifest()
      if (is.null(index)) return(integer())
      sort(as.integer(index$partitions$year[index$partitions$method == method]))
    },
    info = function() list(bilateral_path = bilateral_path, detail_root = detail_root,
      bilateral_sha256 = bilateral_sha256,
      version = if (is.null(manifest)) NULL else manifest$version,
      provenance = if (is.null(manifest)) NULL else manifest$provenance),
    stats = function() list(reads = reads, cache_hits = cache_hits,
      bilateral_loaded = !is.null(bilateral), detail_entries = length(cache),
      detail_bytes = sum(vapply(cache, function(x) as.numeric(utils::object.size(x)), numeric(1L))),
      bilateral_bytes = if (is.null(bilateral)) 0 else as.numeric(utils::object.size(bilateral))))
}
