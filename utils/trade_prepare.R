# Preparação offline do Comércio. Não é carregada na inicialização do painel.
wlv_trade_prepare_sha <- function(path) digest::digest(file = path, algo = "sha256")

wlv_trade_prepare_meta <- function(path, rank) {
  meta <- readRDS(paste0(path, ".meta"))
  if (!is.list(meta) || length(meta) != rank + 1L ||
      length(meta$dim) != rank || anyNA(meta$dim) || any(meta$dim < 1L) ||
      any(meta$dim != as.integer(meta$dim)) ||
      !all(vapply(seq_len(rank), function(i) {
        axis <- meta[[i + 1L]]
        length(axis) == meta$dim[[i]] && !anyNA(axis) && !anyDuplicated(axis)
      }, logical(1L)))) stop("Metadados FST inválidos: ", path, call. = FALSE)
  if (fst::metadata_fst(path)$nrOfRows != prod(meta$dim)) {
    stop("Tamanho FST incompatível com seus eixos: ", path, call. = FALSE)
  }
  meta[-1L] <- lapply(meta[-1L], function(x) unname(as.character(x)))
  meta
}

wlv_trade_prepare_array <- function(path, rank) {
  meta <- wlv_trade_prepare_meta(path, rank)
  array(fst::read_fst(path)[[1L]], meta$dim, meta[-1L])
}

# Cada bloco contém todos os anos, mas somente algumas colunas de destino.
# A soma conserva NA: dados ausentes nunca viram zero durante a preparação.
wlv_trade_prepare_reduce <- function(path, meta, countries, indicators = NULL,
                                     chunk_columns = 16L) {
  rank <- length(meta$dim)
  if (!(rank %in% c(3L, 4L)) || length(chunk_columns) != 1L ||
      is.na(chunk_columns) || chunk_columns < 1L) stop("Bloco inválido.")
  years <- meta[[2L]]
  inputs <- meta[[rank]]
  outputs <- meta[[rank + 1L]]
  output_countries <- sub("[.].*$", "", outputs)
  if (any(!output_countries %in% countries) || anyDuplicated(countries)) {
    stop("Países de destino incompatíveis.")
  }
  metrics <- if (rank == 3L) "exports_usd" else indicators
  if (!length(metrics) || (rank == 4L && any(!metrics %in% meta[[3L]]))) {
    stop("Indicadores detalhados ausentes.")
  }
  reduced <- lapply(metrics, function(x) array(0, c(length(years), length(inputs),
    length(countries)), list(years, inputs, countries)))
  names(reduced) <- metrics
  stride <- prod(meta$dim[-rank])
  for (start in seq.int(1L, length(outputs), by = as.integer(chunk_columns))) {
    end <- min(start + chunk_columns - 1L, length(outputs))
    columns <- seq.int(start, end)
    values <- fst::read_fst(path, from = 1 + stride * (start - 1),
      to = stride * end)[[1L]]
    block <- array(values, c(meta$dim[-rank], length(columns)))
    for (metric in metrics) {
      current <- if (rank == 3L) block else block[, match(metric, meta[[3L]]), , , drop = FALSE]
      dim(current) <- c(length(years) * length(inputs), length(columns))
      for (country in unique(output_countries[columns])) {
        selected <- which(output_countries[columns] == country)
        reduced[[metric]][, , country] <- reduced[[metric]][, , country] +
          matrix(rowSums(current[, selected, drop = FALSE]), nrow = length(years))
      }
    }
  }
  reduced
}

wlv_trade_prepare_compare <- function(actual, expected, label,
                                      relative_tolerance = 1e-9, absolute_tolerance = 0.01) {
  if (length(actual) != length(expected) || any(!is.finite(actual)) ||
      any(!is.finite(expected))) stop("Cobertura incompleta: ", label, call. = FALSE)
  delta <- abs(as.numeric(actual) - as.numeric(expected))
  scale <- pmax(abs(as.numeric(actual)), abs(as.numeric(expected)), 1)
  allowed <- absolute_tolerance + relative_tolerance * scale
  if (any(delta > allowed)) stop(sprintf(
    "Reconciliação falhou: %s (diferença máxima %.9g).", label, max(delta)), call. = FALSE)
  data.frame(check = label, observations = length(delta), maximum_absolute_difference = max(delta),
    maximum_relative_difference = max(delta / scale), stringsAsFactors = FALSE)
}

wlv_trade_prepare_partition <- function(reduced, year, countries, sector_contract, method,
                                        version, reference) {
  inputs <- dimnames(reduced$exports_usd)[[2L]]
  input_country <- sub("[.].*$", "", inputs)
  input_sector <- sub("^[^.]+[.]", "", inputs)
  sectors <- as.character(sector_contract$sector.source)
  expected_inputs <- paste(rep(countries, each = length(sectors)),
    rep(sectors, times = length(countries)), sep = ".")
  if (!identical(inputs, expected_inputs) || anyNA(sector_contract$productive) ||
      any(!sector_contract$productive %in% c(0, 1))) stop("Classificação setorial incompatível.")
  data <- data.frame(country = rep(input_country, length(countries)),
    partner = rep(countries, each = length(inputs)),
    sector = rep(input_sector, length(countries)),
    productive = rep(as.logical(sector_contract$productive), length(countries)^2),
    exports_usd = as.vector(reduced$exports_usd[year, , ]),
    embodied_hours = as.vector(reduced$values[year, , ]),
    transfer_hours = as.vector(reduced$transfers_values[year, , ]),
    stringsAsFactors = FALSE)
  data <- data[data$country != data$partner, , drop = FALSE]
  rownames(data) <- NULL
  if (any(!is.finite(as.matrix(data[c("exports_usd", "embodied_hours", "transfer_hours")])))) {
    stop("Detalhe internacional contém valores ausentes ou não finitos: ", method, "/", year)
  }
  # Inverso do balance_factor do WLVDB: USD / hora abstrata.
  factor <- sum(reference[year, "exports_productive_mp", , ]) /
    sum(reference[year, "exports_values", , ])
  if (!is.finite(factor) || factor <= 0) stop("Fator anual do comércio inválido.")
  data$transfer_usd <- data$transfer_hours * factor
  list(schema_version = 1L, version = version, method = method, year = year,
    factor_usd_per_hour = factor, data = data)
}

wlv_trade_prepare_validate_partition <- function(partition, reference, sector_reference) {
  data <- partition$data
  year <- partition$year
  countries <- dimnames(reference)[[3L]]
  sectors <- dimnames(sector_reference)[[3L]]
  pair_index <- match(data$country, countries) +
    (match(data$partner, countries) - 1L) * length(countries)
  sum_groups <- function(values, groups, size) {
    answer <- numeric(size)
    sums <- rowsum(values, groups, reorder = FALSE)
    answer[as.integer(rownames(sums))] <- sums[, 1L]
    answer
  }
  checks <- list()
  add <- function(actual, expected, label) {
    checks[[length(checks) + 1L]] <<- wlv_trade_prepare_compare(actual, expected,
      paste(partition$method, year, label, sep = "/"))
  }
  for (entry in list(c("exports_usd", "exports_mp"), c("embodied_hours", "exports_values"),
      c("transfer_hours", "transfers_values"), c("transfer_usd", "transfers_dp"),
      c("exports_usd", "exports_productive_mp"),
      c("transfer_hours", "transfers_productive_values"),
      c("transfer_usd", "transfers_productive_dp"))) {
    selected <- if (grepl("productive", entry[[2L]], fixed = TRUE)) data$productive else rep(TRUE, nrow(data))
    add(sum_groups(data[[entry[[1L]]]][selected], pair_index[selected], length(countries)^2),
      as.vector(reference[year, entry[[2L]], , ]), entry[[2L]])
  }
  origin_group <- match(data$sector, sectors) + (match(data$country, countries) - 1L) * length(sectors)
  destination_group <- match(data$sector, sectors) + (match(data$partner, countries) - 1L) * length(sectors)
  size <- length(sectors) * length(countries)
  for (entry in list(c("exports_usd", "exports.s.us", "imports.s.us"),
                    c("embodied_hours", "exports.s.mv", "imports.s.mv"))) {
    add(sum_groups(data[[entry[[1L]]]], origin_group, size),
      as.vector(sector_reference[year, entry[[2L]], sectors, countries]), entry[[2L]])
    add(sum_groups(data[[entry[[1L]]]], destination_group, size),
      as.vector(sector_reference[year, entry[[3L]], sectors, countries]), entry[[3L]])
  }
  for (productive_only in c(FALSE, TRUE)) {
    selected <- if (productive_only) data$productive else rep(TRUE, nrow(data))
    indicator <- if (productive_only) "trade_transfers.p.s.mv" else "trade_transfers.s.mv"
    balance <- sum_groups(data$transfer_hours[selected], origin_group[selected], size) -
      sum_groups(data$transfer_hours[selected], destination_group[selected], size)
    add(balance, as.vector(sector_reference[year, indicator, sectors, countries]), indicator)
  }
  do.call(rbind, checks)
}

# Usa o verificador atual do WLVDB para a geração normalizada e o hash efetivo
# (incluindo EU KLEMS), sem carregar o runtime nem executar o modelo econômico.
wlv_trade_prepare_provenance <- function(db_root, result_dir, method_dir, publication_mode) {
  verifier <- new.env(parent = baseenv())
  sys.source(file.path(db_root, "scripts/lib/source_manifest.R"), verifier)
  source_root <- file.path(db_root, "source_data", method_dir, "normalized")
  manifest <- verifier$wlv_read_source_manifest(file.path(source_root, "_source_manifest.csv"))
  contract_catalog <- read.csv2(file.path(db_root, "catalog/unit-contracts.csv"),
    stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  contract <- contract_catalog[contract_catalog$contract == manifest$contract_id[[1L]], , drop = FALSE]
  if (nrow(contract) != 1L || !identical(as.character(contract$source), method_dir)) stop("Contrato de fonte inválido.")
  contract_paths <- file.path(db_root, c(contract$units, contract$aggregations))
  current_contract_matches <- identical(verifier$wlv_source_contract_sha256(contract_paths), manifest$contract_sha256[[1L]])
  if (current_contract_matches) {
    verifier$wlv_verify_source_manifest(manifest, source_root, contract_paths,
      expected_contract_id = contract$contract, expected_contract_version = as.character(contract$schema_version))
  } else {
    if (!identical(publication_mode, "legacy")) stop("Contrato atual diverge de uma release imutável.")
    # Importação legada explícita: a geração antiga conserva o contrato completo
    # em _unit_contract.csv, autenticado pelo próprio manifesto. Não reinterpretar
    # seus valores por um catálogo que evoluiu após a geração.
    if (!all(c("_unit_contract.csv", "_normalization_contract.csv") %in% manifest$artifact)) stop("Geração legada sem contratos preservados.")
    paths <- verifier$wlv_source_resolve_artifacts(source_root, manifest$artifact)
    for (j in seq_along(paths)) {
      record <- verifier$wlv_source_file_record(paths[[j]])
      if (!identical(record$sha256, manifest$sha256[[j]]) ||
          !identical(record$size_bytes, manifest$size_bytes[[j]])) stop("Fonte legada não corresponde ao manifesto: ", paths[[j]])
    }
  }
  normalization <- read.csv2(file.path(source_root, "_normalization_contract.csv"),
    stringsAsFactors = FALSE, fileEncoding = "UTF-8")
  monetary <- normalization[normalization$artifact == "m_io" & normalization$variable == "*", ]
  if (nrow(monetary) != 1L || monetary$canonical_unit != "current_usd") stop("Matriz monetária não está em USD normalizados.")
  actual <- verifier$wlv_read_result_source_provenance(result_dir)
  years <- as.integer(wlv_trade_prepare_meta(file.path(source_root, "m_io.fst"), 3L)[[2L]])
  # Os dois métodos suportados usam a depreciação EU KLEMS do ano seguinte.
  auxiliary <- c(file.path(db_root, "source_data/euklems", paste0("ekk_", years, ".fst")),
    file.path(db_root, "source_data/euklems", paste0("ekdeprate_", years + 1L, ".fst")))
  expected <- verifier$wlv_source_provenance(manifest, method_dir, additional_paths = auxiliary)
  if (!identical(actual, expected)) stop("Fonte normalizada/EU KLEMS e resultado pertencem a gerações diferentes.")
  paths <- c(file.path(source_root, manifest$artifact), file.path(source_root, "_source_manifest.csv"), auxiliary)
  list(provenance = actual, manifest = manifest, paths = paths,
    contract_validation = if (current_contract_matches) "current_catalog" else "legacy_manifested_contract_snapshot")
}

wlv_trade_prepare_inventory <- function(paths, root) {
  paths <- unique(normalizePath(paths, winslash = "/", mustWork = TRUE))
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  data.frame(file = substring(paths, nchar(root) + 2L),
    bytes = as.numeric(file.info(paths)$size),
    sha256 = vapply(paths, wlv_trade_prepare_sha, character(1L)), stringsAsFactors = FALSE)
}

wlv_trade_prepare_verify_inventory <- function(inventory, root) {
  for (i in seq_len(nrow(inventory))) {
    path <- file.path(root, inventory$file[[i]])
    if (!file.exists(path) || file.info(path)$size != inventory$bytes[[i]] ||
        !identical(wlv_trade_prepare_sha(path), inventory$sha256[[i]])) {
      stop("Arquivo mudou durante a preparação: ", inventory$file[[i]], call. = FALSE)
    }
  }
  invisible(TRUE)
}

wlv_prepare_trade_data <- function(db_root, panel_root, output_root,
                                   methods = c("wiodr13", "wiodr16"), chunk_columns = 16L) {
  if (any(!methods %in% c("wiodr13", "wiodr16")) || anyDuplicated(methods)) stop("Métodos não suportados.")
  started <- proc.time()[["elapsed"]]
  contracts <- new.env(parent = baseenv())
  sys.source(file.path(panel_root, "utils/result_contracts.R"), contracts)
  runs <- contracts$wlv_resolve_result_run_dirs(file.path(db_root, "results"))
  if (any(!methods %in% names(runs))) stop("Método ausente na geração selecionada.")
  panel_countries <- readRDS(file.path(panel_root, "data/m_countries.RDS"))
  panel_sectors <- readRDS(file.path(panel_root, "data/sea_sectors.RDS"))
  panel_inputs <- c("data/m_countries.RDS", "data/sea_sectors.RDS", "utils/trade_prepare.R", "scripts/prepare-trade-data.R")
  panel_inventory <- wlv_trade_prepare_inventory(file.path(panel_root, panel_inputs), panel_root)
  source_inputs <- character()
  configurations <- list()
  for (method_dir in methods) {
    message("Verificando fonte e geração: ", method_dir)
    method <- if (method_dir == "wiodr13") "WIOD13" else "WIOD16"
    run <- runs[[method_dir]]
    source <- file.path(db_root, "source_data", method_dir, "normalized/m_io.fst")
    result <- list.files(run, "^m_io.*[.]fst$", full.names = TRUE)
    if (length(result) != 1L) stop("Esperada uma matriz mundial por método.")
    provenance <- wlv_trade_prepare_provenance(db_root, run, method_dir, attr(runs, "publication_mode"))
    source_inputs <- c(source_inputs, provenance$paths,
      list.files(run, full.names = TRUE)[basename(list.files(run, full.names = TRUE)) %in% c(
        basename(result), paste0(basename(result), ".meta"), "_source_provenance.csv", "_sectors.csv",
        "m_countries.fst", "m_countries.fst.meta", "sea_sectors.fst", "sea_sectors.fst.meta")])
    reference <- wlv_trade_prepare_array(file.path(run, "m_countries.fst"), 4L)
    source_meta <- wlv_trade_prepare_meta(source, 3L)
    result_meta <- wlv_trade_prepare_meta(result, 4L)
    if (!identical(source_meta[-1L], result_meta[-c(1L, 3L)])) stop("Eixos incompatíveis entre preço e valor.")
    current <- panel_countries[[method]]
    if (is.null(current)) stop("Método ausente nos dados atuais do painel.")
    years <- dimnames(current)[[1L]][vapply(seq_len(dim(current)[1L]),
      function(i) any(is.finite(current[i, , , ])), logical(1L))]
    wlv_trade_prepare_compare(reference[years, dimnames(current)[[2L]], dimnames(current)[[3L]], dimnames(current)[[4L]]],
      current[years, , , ], paste(method, "painel/geração"))
    configurations[[method]] <- list(method_dir = method_dir, source = source, result = result,
      source_meta = source_meta, result_meta = result_meta, reference = reference, years = years,
      sector_contract = read.csv2(file.path(run, "_sectors.csv"), stringsAsFactors = FALSE, fileEncoding = "UTF-8"),
      provenance = provenance$provenance, contract_validation = provenance$contract_validation)
  }
  source_inventory <- wlv_trade_prepare_inventory(source_inputs, db_root)
  version <- paste0("trade-v1-", substr(digest::digest(list(source_inventory, panel_inventory),
    algo = "sha256"), 1L, 20L))
  generation <- file.path(output_root, version)
  manifest_path <- file.path(generation, "manifest.rds")
  if (file.exists(manifest_path)) {
    existing <- readRDS(manifest_path)
    if (!identical(existing$version, version)) stop("Versão existente incompatível.")
    wlv_trade_prepare_verify_inventory(existing$partitions[c("file", "bytes", "sha256")], generation)
    message("Geração validada já preparada: ", generation)
    return(invisible(generation))
  }
  dir.create(generation, recursive = TRUE, showWarnings = FALSE)
  manifest <- list(schema_version = 1L, version = version,
    created_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    publication_mode = attr(runs, "publication_mode"), release_id = attr(runs, "release_id"),
    source_inventory = source_inventory, panel_inventory = panel_inventory,
    bilateral_sha256 = panel_inventory$sha256[panel_inventory$file == "data/m_countries.RDS"],
    provenance = list(publication_mode = attr(runs, "publication_mode"),
      release_id = attr(runs, "release_id"), sources = lapply(configurations, `[[`, "provenance"),
      contract_validation = lapply(configurations, `[[`, "contract_validation")),
    source_provenance = lapply(configurations, `[[`, "provenance"),
    methods = list(), partitions = NULL, validation = NULL,
    units = list(exports_usd = "current_usd", embodied_hours = "abstract_labour_hours",
      transfer_hours = "abstract_labour_hours", transfer_usd = "current_usd_trade_equivalent"),
    transfer_sign = "positive_directional_value_is_seller_gain; net=outgoing-incoming",
    sector_semantics = "supplying_product_sector_in_both_directions",
    coverage = "complete_international_grid; domestic_excluded; ROW_included; WWW_excluded")
  for (method in names(configurations)) {
    cfg <- configurations[[method]]
    countries <- dimnames(cfg$reference)[[3L]]
    sectors <- as.character(cfg$sector_contract$sector.source)
    message("Agregando blocos de preço e valor: ", method)
    method_started <- proc.time()[["elapsed"]]
    reduced <- c(wlv_trade_prepare_reduce(cfg$source, cfg$source_meta, countries, chunk_columns = chunk_columns),
      wlv_trade_prepare_reduce(cfg$result, cfg$result_meta, countries,
        indicators = c("values", "transfers_values"), chunk_columns = chunk_columns))
    manifest$methods[[method]] <- list(years = cfg$years, countries = countries, sectors = sectors,
      productive = as.logical(cfg$sector_contract$productive), files = setNames(character(length(cfg$years)), cfg$years))
    for (year in cfg$years) {
      partition <- wlv_trade_prepare_partition(reduced, year, countries, cfg$sector_contract, method, version, cfg$reference)
      checks <- wlv_trade_prepare_validate_partition(partition, cfg$reference, panel_sectors[[method]])
      relative <- paste0(method, "-", year, ".rds")
      path <- file.path(generation, relative)
      # Uma tentativa interrompida pode reutilizar apenas partições idênticas.
      if (file.exists(path)) {
        if (!identical(readRDS(path), partition)) stop("Partição existente diverge; preserve a tentativa para diagnóstico: ", path)
      } else saveRDS(partition, path, compress = "gzip")
      if (!identical(readRDS(path), partition)) stop("Falha de verificação RDS: ", path)
      manifest$methods[[method]]$files[[year]] <- relative
      manifest$partitions <- rbind(manifest$partitions, data.frame(method = method, year = year, file = relative,
        sha256 = wlv_trade_prepare_sha(path), bytes = file.info(path)$size, rows = nrow(partition$data)))
      manifest$validation <- rbind(manifest$validation, checks)
      message("  ", method, "/", year, ": ", nrow(partition$data), " linhas; reconciliação aprovada")
    }
    manifest$methods[[method]]$preparation_seconds <- proc.time()[["elapsed"]] - method_started
    rm(reduced)
    gc(FALSE)
  }
  # Hashes novamente: nenhuma fonte mutável pode trocar de geração no meio.
  wlv_trade_prepare_verify_inventory(source_inventory, db_root)
  wlv_trade_prepare_verify_inventory(panel_inventory, panel_root)
  manifest$preparation_seconds <- proc.time()[["elapsed"]] - started
  saveRDS(manifest, manifest_path)
  if (!identical(readRDS(manifest_path), manifest)) stop("Manifesto não preservado na gravação.")
  message("Geração validada: ", generation, "; ", round(manifest$preparation_seconds, 2), " s")
  invisible(generation)
}
