# Uma base por perfil; todas as grandezas derivadas preservam os anos ausentes.
# As horas da jornada são abstratas e anuais por assalariado, como as horas
# necessárias à reprodução da força de trabalho, para que a diferença seja
# o mais-valor por assalariado. Horas concretas não são intercambiáveis aqui.
wlv_country_landing_latest <- function(data, columns) {
  valid <- if (nrow(data)) Reduce(`&`, lapply(data[columns], is.finite)) else logical()
  rows <- which(valid)
  if (!length(rows)) return(NULL)
  data[rows[[which.max(data$year[rows])]], , drop = FALSE]
}

wlv_country_landing_data <- function(countries, contracts, country, methods,
    bilateral = NULL) {
  axes <- dimnames(countries)
  if (!is.numeric(countries) || length(dim(countries)) != 4L ||
      length(axes) != 4L || any(vapply(axes, function(x)
        is.null(x) || anyNA(x) || anyDuplicated(x) > 0L, logical(1L))))
    stop("Estrutura de indicadores nacionais inválida.", call. = FALSE)
  if (length(country) != 1L || is.na(country) || !country %in% axes[[4L]])
    stop("País ausente dos indicadores nacionais.", call. = FALSE)
  years <- suppressWarnings(as.integer(axes[[2L]]))
  if (anyNA(years) || anyDuplicated(years))
    stop("Anos dos indicadores nacionais inválidos.", call. = FALSE)
  methods <- intersect(as.character(methods), axes[[1L]])
  empty_labour <- data.frame(year = integer(), workday = numeric(),
    labour_power = numeric(), surplus = numeric(), exploitation = numeric(),
    employees = numeric())
  empty_trade <- data.frame(year = integer(), exports_hours = numeric(),
    imports_hours = numeric(), export_money_hours = numeric(),
    import_money_hours = numeric(), sent = numeric(), received = numeric(),
    net = numeric())
  provenance <- list(
    labour = c(workday = "abstract_labour.empe.m.mv",
      labour_power = "labour_force_value.m.mv",
      exploitation = "surplus_value.empe.r.pc", employees = "empe.s.un"),
    population = "employees", period = "year", labour_basis = "abstract",
    trade = c(embodied = "exports_values", price_minus_embodied = "transfers_values"),
    trade_scope = "total", trade_sign = "received_minus_sent",
    trade_money = "exports_values + transfers_values",
    method_selection = "both_charts_then_latest_year_then_coverage")
  result <- list(method = NA_character_, country = country,
    available_methods = methods, labour = empty_labour, trade = empty_trade,
    latest_labour = NULL, latest_trade = NULL,
    labour_unit = "abstract_labour_hour_per_person",
    trade_unit = "abstract_labour_hour", provenance = provenance)
  if (!length(methods)) return(result)

  # Use o contrato para conferir a unidade de origem, antes de calcular.
  # O resultado desta API permanece nas unidades canônicas declaradas acima;
  # apenas a taxa é convertida de razão em porcentagem para apresentação.
  indicator <- function(method, code, unit, legacy_type) {
    missing <- rep(NA_real_, length(years))
    if (!code %in% axes[[3L]]) return(missing)
    rows <- contracts[contracts$method == method & contracts$indicator == code, , drop = FALSE]
    if (!nrow(rows)) return(missing)
    row <- wlv_display_contract_row(contracts, method, code)
    modern <- identical(row$metadata_source[[1L]], "method_metadata")
    compatible <- if (modern) identical(row$canonical_unit[[1L]], unit) else
      identical(row$legacy_type[[1L]], legacy_type)
    if (!compatible)
      stop(sprintf("Unidade incompatível no perfil: %s/%s.", method, code), call. = FALSE)
    value <- as.numeric(countries[method, , code, country, drop = FALSE])
    value[!is.finite(value)] <- NA_real_
    if (identical(unit, "ratio")) value <- value * 100
    value
  }
  get_bilateral <- function(method) {
    if (is.function(bilateral)) return(bilateral(method))
    if (is.null(bilateral) || !method %in% names(bilateral)) return(NULL)
    bilateral[[method]]
  }
  # Uma única parcela ausente mantém o total ausente: na.rm não é permitido.
  complete_sum <- function(value) {
    if (!length(value) || any(!is.finite(value))) NA_real_ else sum(value)
  }
  check_equal <- function(actual, expected, label, scale = pmax(abs(actual), abs(expected))) {
    check <- is.finite(actual) & is.finite(expected)
    if (any(abs(actual[check] - expected[check]) > 1e-7 * pmax(1, scale[check])))
      stop(sprintf("Dados incompatíveis no perfil: %s.", label), call. = FALSE)
  }
  build <- function(method) {
    labour <- data.frame(year = years,
      workday = indicator(method, provenance$labour[["workday"]], result$labour_unit, "value"),
      labour_power = indicator(method, provenance$labour[["labour_power"]], result$labour_unit, "value"),
      surplus = NA_real_,
      exploitation = indicator(method, provenance$labour[["exploitation"]], "ratio", "percent"),
      employees = indicator(method, provenance$labour[["employees"]], "person", "integer"))
    labour$surplus <- labour$workday - labour$labour_power
    rate <- ifelse(labour$labour_power > 0, 100 * labour$surplus / labour$labour_power, NA_real_)
    check_equal(rate, labour$exploitation, paste(method, "taxa de exploração"))
    # A taxa divulgada continua ausente quando não há observação na fonte.
    labour <- labour[order(labour$year), , drop = FALSE]
    trade <- empty_trade
    values <- get_bilateral(method)
    if (!is.null(values)) {
      trade_axes <- dimnames(values)
      if (!is.numeric(values) || length(dim(values)) != 4L ||
          length(trade_axes) != 4L || any(vapply(trade_axes, function(x)
            is.null(x) || anyNA(x) || anyDuplicated(x) > 0L, logical(1L))) ||
          !all(c("exports_values", "transfers_values") %in% trade_axes[[2L]]) ||
          !identical(trade_axes[[3L]], trade_axes[[4L]]))
        stop("Estrutura bilateral do perfil inválida.", call. = FALSE)
      tagged_method <- attr(values, "method", exact = TRUE)
      if (!is.null(tagged_method) && !identical(tagged_method, method))
        stop("Base bilateral incompatível com o perfil.", call. = FALSE)
      trade_years <- suppressWarnings(as.integer(trade_axes[[1L]]))
      if (anyNA(trade_years) || anyDuplicated(trade_years))
        stop("Anos bilaterais do perfil inválidos.", call. = FALSE)
      partners <- setdiff(trade_axes[[4L]], c(country, "WWW"))
      if (country %in% trade_axes[[3L]] && country != "WWW" && length(partners)) {
        trade <- data.frame(year = sort(unique(c(years, trade_years)))); n <- nrow(trade)
        for (column in setdiff(names(empty_trade), "year")) trade[[column]] <- rep(NA_real_, n)
        for (year in trade_axes[[1L]]) {
          i <- match(as.integer(year), trade$year)
          exports <- values[year, "exports_values", country, partners, drop = FALSE]
          imports <- values[year, "exports_values", partners, country, drop = FALSE]
          exports_transfer <- values[year, "transfers_values", country, partners, drop = FALSE]
          imports_transfer <- values[year, "transfers_values", partners, country, drop = FALSE]
          trade$exports_hours[[i]] <- complete_sum(exports)
          trade$imports_hours[[i]] <- complete_sum(imports)
          # A matriz já aplica o fator monetário internacional da própria base.
          trade$export_money_hours[[i]] <- complete_sum(exports + exports_transfer)
          trade$import_money_hours[[i]] <- complete_sum(imports + imports_transfer)
        }
        trade$sent <- trade$exports_hours + trade$import_money_hours
        trade$received <- trade$imports_hours + trade$export_money_hours
        trade$net <- trade$received - trade$sent
        published <- indicator(method, "trade_transfers.s.mv", result$trade_unit, "value")
        check_equal(trade$net, published[match(trade$year, years)],
          paste(method, "transferências líquidas"),
          pmax(abs(trade$sent), abs(trade$received)))
      }
    }
    candidate <- result; candidate$method <- method
    candidate$labour <- labour; candidate$trade <- trade
    candidate$latest_labour <- wlv_country_landing_latest(labour, c("workday", "labour_power"))
    candidate$latest_trade <- wlv_country_landing_latest(trade, c("sent", "received"))
    candidate
  }
  candidates <- lapply(methods, build)
  scores <- lapply(candidates, function(candidate) {
    labour_years <- candidate$labour$year[is.finite(candidate$labour$workday) &
      is.finite(candidate$labour$labour_power)]
    trade_years <- candidate$trade$year[is.finite(candidate$trade$sent) &
      is.finite(candidate$trade$received)]
    both <- intersect(labour_years, trade_years)
    latest <- c(if (length(both)) both else c(labour_years, trade_years), -Inf)
    c(charts = as.integer(length(labour_years) > 0) + as.integer(length(trade_years) > 0),
      latest = max(latest), coverage = length(labour_years) + length(trade_years))
  })
  score <- do.call(rbind, scores)
  candidates[[order(-score[, "charts"], -score[, "latest"], -score[, "coverage"])[[1L]]]]
}
