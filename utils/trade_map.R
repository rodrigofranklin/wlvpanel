# Conexões cartográficas da transferência líquida, na perspectiva do país focal.
# Os pontos devem ser os pontos representativos dos polígonos usados pelo mapa,
# em longitude/latitude WGS84. A geometria curva é projetada pelo navegador.
wlv_trade_map_flows <- function(values, country, centroids, partner = NULL,
    limit = 12L, max_width = 14) {
  if (!is.data.frame(values) || !all(c("id", "value") %in% names(values)) ||
      !is.numeric(values$value) || anyDuplicated(values$id))
    stop("A seleção do mapa deve ter uma linha numérica por parceiro.", call. = FALSE)
  if (length(country) != 1L || is.na(country) || !nzchar(country))
    stop("País focal inválido.", call. = FALSE)
  if (!is.data.frame(centroids) || !all(c("id", "lng", "lat") %in% names(centroids)) ||
      !is.numeric(centroids$lng) || !is.numeric(centroids$lat) ||
      anyNA(centroids$id) || anyDuplicated(centroids$id) ||
      any(is.finite(centroids$lat) & abs(centroids$lat) > 90) ||
      any(is.finite(centroids$lng) & abs(centroids$lng) > 180))
    stop("Pontos do mapa inválidos: use id, lng e lat em WGS84.", call. = FALSE)
  if (length(limit) != 1L || !is.finite(limit) || limit < 1 || limit != floor(limit) ||
      length(max_width) != 1L || !is.finite(max_width) || max_width <= 0)
    stop("Limite ou largura de conexões inválido.", call. = FALSE)
  result <- data.frame(id = character(), from = character(), to = character(),
    from_lat = numeric(), from_lng = numeric(), to_lat = numeric(), to_lng = numeric(),
    value = numeric(), amount = numeric(), width = numeric(), stringsAsFactors = FALSE)
  finish <- function(result, eligible = 0L, unmapped = 0L) {
    attr(result, "eligible") <- as.integer(eligible)
    attr(result, "omitted") <- as.integer(eligible - nrow(result))
    attr(result, "unmapped") <- as.integer(unmapped)
    attr(result, "max_amount") <- if (nrow(result)) max(result$amount) else 0
    attr(result, "width_scaling") <- "linear_absolute_value"
    attr(result, "max_width") <- max_width
    attr(result, "limit") <- as.integer(limit)
    result
  }
  country <- as.character(country)
  keep <- !is.na(values$id) & !values$id %in% c(country, "ROW", "WWW") &
    is.finite(values$value) & values$value != 0
  if ("coverage" %in% names(values)) keep <- keep & !is.na(values$coverage) & values$coverage == "complete"
  if (!is.null(partner) && length(partner)) keep <- keep & values$id %in% partner
  values <- values[keep, , drop = FALSE]
  geographic <- is.finite(centroids$lng) & is.finite(centroids$lat)
  centroids <- centroids[geographic, , drop = FALSE]
  focal <- match(country, centroids$id)
  if (country %in% c("ROW", "WWW") || is.na(focal)) return(finish(result, unmapped = nrow(values)))
  indices <- match(values$id, centroids$id)
  unmapped <- sum(is.na(indices))
  values <- values[!is.na(indices), , drop = FALSE]
  if (!nrow(values)) return(finish(result, unmapped = unmapped))
  values <- values[order(-abs(values$value), as.character(values$id)), , drop = FALSE]
  eligible <- nrow(values)
  values <- utils::head(values, as.integer(limit))
  indices <- match(values$id, centroids$id)
  gain <- values$value > 0
  result <- data.frame(id = as.character(values$id),
    from = ifelse(gain, as.character(values$id), country),
    to = ifelse(gain, country, as.character(values$id)),
    from_lat = ifelse(gain, centroids$lat[indices], centroids$lat[[focal]]),
    from_lng = ifelse(gain, centroids$lng[indices], centroids$lng[[focal]]),
    to_lat = ifelse(gain, centroids$lat[[focal]], centroids$lat[indices]),
    to_lng = ifelse(gain, centroids$lng[[focal]], centroids$lng[indices]),
    value = values$value, amount = abs(values$value),
    width = max_width * (abs(values$value) / max(abs(values$value))),
    stringsAsFactors = FALSE)
  finish(result, eligible, unmapped)
}
