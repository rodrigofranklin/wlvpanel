# Downloads do Comércio no mesmo formato data/metadata/specs do painel.
# O gerador canônico save_my_xlsx é carregado somente ao solicitar o download.
wlv_trade_workbook_text <- function(key, lang = "pt") {
  texts <- list(
    title = c("Comércio internacional", "International trade"),
    series = c("Série histórica", "Time series"), selection = c("Seleção", "Selection"),
    country = c("País", "Country"), method = c("Base", "Database"),
    measure = c("Medida", "Measure"), scope = c("Atividades fornecedoras", "Supplying activities"),
    unit = c("Unidade", "Unit"), period = c("Período", "Period"), year = c("Ano", "Year"),
    partner = c("Parceiro", "Partner"), sector = c("Setor do produto", "Product sector"),
    all_partners = c("Todos os parceiros", "All partners"), all_sectors = c("Todos os setores", "All sectors"),
    total = c("Todas", "All"), productive = c("Produtivas", "Productive"),
    unproductive = c("Improdutivas", "Unproductive"),
    transfer = c("Transferência líquida de valor", "Net value transfer"),
    exports = c("Exportações", "Exports"), imports = c("Importações", "Imports"),
    balance = c("Saldo comercial", "Trade balance"),
    value_unit = c("Horas de trabalho abstrato", "Abstract labour hours"),
    usd_unit = c("USD correntes", "Current USD"),
    transfer_usd_unit = c("USD equivalentes pelo fator anual do comércio", "USD equivalent using the annual trade factor"),
    label = c("Descrição", "Description"), code = c("Código", "Code"),
    export_contribution = c("Contribuição das exportações", "Export contribution"),
    import_contribution = c("Contribuição das importações", "Import contribution"),
    coverage = c("Cobertura", "Coverage"), complete = c("Completa", "Complete"),
    partial = c("Parcial", "Partial"), missing = c("Ausente", "Missing"),
    field = c("Campo", "Field"), definition = c("Definição", "Definition"),
    value = c("Valor", "Value"), transform = c("Relação com os dados da consulta", "Relationship to query data"),
    version = c("Versão dos dados", "Data version"), created = c("Exportado em UTC", "Exported at UTC"),
    source = c("Fonte", "Source"), publication = c("Publicação dos resultados", "Result publication"),
    legacy = c("Importação legada validada", "Validated legacy import"),
    snapshot = c("Contrato histórico autenticado pelo manifesto da fonte", "Historical contract authenticated by the source manifest"),
    rows = c("Observações exportadas", "Exported observations"),
    basis = c("Perspectiva setorial", "Sector perspective"),
    basis_value = c("Setor fornecedor do produto nas duas direções", "Supplying product sector in both directions"),
    missing_note = c("Célula vazia significa dado indisponível; zero observado permanece zero.", "A blank cell means unavailable data; an observed zero remains zero."),
    sign_transfer = c("Positivo: apropriação de valor pelo país focal. Negativo: cessão.", "Positive: value appropriated by the focal country. Negative: value ceded."),
    sign_balance = c("Positivo: superávit comercial. Negativo: déficit.", "Positive: trade surplus. Negative: trade deficit."),
    sign_flow = c("Fluxo bruto na direção selecionada, preservando ajustes negativos.", "Gross flow in the selected direction, preserving negative adjustments."),
    units_note = c("Valores armazenados sem arredondamento visual ou multiplicador adicional.", "Stored values have no visual rounding or additional multiplier."),
    code_note = c("Identificador original do parceiro ou setor; na série, o ano.", "Original partner or sector identifier; the year for time series."),
    series_code_note = c("Identificador da medida em cada linha da série; os anos estão nas colunas.", "Measure identifier on each time-series row; years are columns."),
    label_note = c("Rótulo da categoria na seleção exportada.", "Category label in the exported selection."),
    year_note = c("Ano da observação, sem combinar bases ou períodos.", "Observation year, without joining databases or periods."),
    coverage_note = c("Completude do recorte: completa, parcial ou ausente.", "Selection completeness: complete, partial or missing."),
    outgoing_note = c("Transferência direcional nas exportações; nas demais medidas, exportações brutas.", "Directional transfer on exports; gross exports for other measures."),
    incoming_note = c("Nas medidas de saldo, é o negativo da transferência/fluxo direcional das importações.", "For balance measures, this is the negative of the directional import transfer/flow."),
    raw_note = c("outgoing é igual à contribuição das exportações. incoming é o negativo da contribuição das importações nos saldos e igual a ela nos fluxos brutos.", "outgoing equals export contribution. incoming is the negative of import contribution for balances, and equals it for gross flows."),
    observation_metadata = c("Cobertura das observações", "Observation coverage"),
    observed = c("Componentes observados", "Observed components"), expected = c("Componentes esperados", "Expected components")
  )
  value <- texts[[key]]
  if (is.null(value)) key else value[[if (identical(lang, "en")) 2L else 1L]]
}

wlv_trade_workbook_equal <- function(actual, expected, label) {
  actual <- unname(actual); expected <- unname(expected)
  if (length(actual) != length(expected) || !identical(is.na(actual), is.na(expected)) ||
      any(is.infinite(actual)) || any(is.infinite(expected)))
    stop("Comércio XLSX: cobertura divergente em ", label, call. = FALSE)
  available <- !is.na(actual)
  if (any(abs(actual[available] - expected[available]) >
      1e-12 * pmax(abs(expected[available]), 1)))
    stop("Comércio XLSX: valores divergentes em ", label, call. = FALSE)
  invisible(TRUE)
}

wlv_trade_workbook_payload <- function(rows, selection = list(), context = list(),
    lang = "pt", provenance = NULL, kind = c("selection", "series")) {
  kind <- match.arg(kind)
  lang <- if (lang %in% c("en", "English")) "en" else "pt"
  tr <- function(key) wlv_trade_workbook_text(key, lang)
  if (!is.data.frame(rows) || !nrow(rows) || nrow(rows) > 1048570L ||
      !all(c("year", "value", "outgoing", "incoming", "coverage") %in% names(rows)) ||
      !all(vapply(rows[c("year", "value", "outgoing", "incoming")],
        function(x) is.numeric(x) && !any(is.infinite(x)), logical(1L))) ||
      anyNA(rows$year) || any(rows$year != as.integer(rows$year)) ||
      anyNA(rows$coverage) || any(!rows$coverage %in% c("complete", "partial", "missing")))
    stop("Comércio XLSX: observações inválidas.", call. = FALSE)
  take <- function(key, fallback = NULL) {
    value <- selection[[key]]
    if (is.null(value) && key %in% names(rows)) {
      candidates <- unique(as.character(rows[[key]]))
      candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
      if (length(candidates) == 1L) value <- candidates
    }
    if (is.null(value) || !length(value) || !nzchar(as.character(value[[1L]]))) fallback else as.character(value[[1L]])
  }
  metric <- take("metric", "transfer"); scope <- take("scope", "productive")
  if (!metric %in% c("transfer", "balance", "exports", "imports") ||
      !scope %in% c("total", "productive", "unproductive")) stop("Comércio XLSX: medida ou escopo inválido.")
  # A unidade de seleção é o código canônico; rows$unit pode ser traduzida.
  unit_code <- selection$unit
  if (is.null(unit_code) && "unit" %in% names(rows) &&
      length(unique(rows$unit)) == 1L && unique(rows$unit) %in% c("value", "usd")) unit_code <- unique(rows$unit)
  if (is.null(unit_code) || length(unit_code) != 1L || !unit_code %in% c("value", "usd"))
    stop("Comércio XLSX: informe selection$unit como value ou usd.")
  unit <- context$unit_label
  if (is.null(unit)) unit <- tr(if (unit_code == "value") "value_unit" else if (metric == "transfer") "transfer_usd_unit" else "usd_unit")
  is_balance <- metric %in% c("transfer", "balance")
  calculated <- switch(metric, exports = rows$outgoing, imports = rows$incoming,
    rows$outgoing - rows$incoming)
  wlv_trade_workbook_equal(rows$value, calculated, "value")
  export <- rows$outgoing; import <- if (is_balance) -rows$incoming else rows$incoming
  if ("export_contribution" %in% names(rows)) wlv_trade_workbook_equal(rows$export_contribution, export, "export_contribution")
  if ("import_contribution" %in% names(rows)) wlv_trade_workbook_equal(rows$import_contribution, import, "import_contribution")
  if (any(rows$coverage == "complete" & !is.finite(rows$value))) stop("Comércio XLSX: dado ausente marcado como completo.")
  ids <- if (kind == "series") as.character(rows$year) else if ("id" %in% names(rows)) as.character(rows$id) else if ("key" %in% names(rows)) as.character(rows$key) else NULL
  labels <- if (kind == "series") as.character(rows$year) else if ("label" %in% names(rows)) as.character(rows$label) else ids
  if (is.null(ids) || anyNA(ids) || any(!nzchar(ids)) || anyNA(labels) || any(!nzchar(labels)) ||
      anyDuplicated(paste(rows$year, ids, sep = "\034"))) stop("Comércio XLSX: identificadores ausentes ou duplicados.")
  order_index <- if (kind == "series") order(rows$year) else seq_len(nrow(rows))
  rows <- rows[order_index, , drop = FALSE]; ids <- ids[order_index]; labels <- labels[order_index]
  values <- cbind(year = rows$year, value = rows$value,
    export_contribution = export[order_index], import_contribution = import[order_index])
  rownames(values) <- ids
  colnames(values) <- c(tr("year"), tr(metric), tr(if (is_balance) "export_contribution" else "exports"),
    tr(if (is_balance) "import_contribution" else "imports"))
  method <- take("method", ""); country <- take("country", "")
  country_name <- context$country_label
  if (is.null(country_name)) country_name <- take("country_name", country)
  years <- range(rows$year)
  period <- if (years[[1L]] == years[[2L]]) as.character(years[[1L]]) else paste(years, collapse = "–")
  title <- context$title
  if (is.null(title)) title <- paste(tr("title"), tr(kind), sep = ": ")
  header <- cbind(c(tr(kind), tr("country"), tr("method"), tr("unit")),
    c(title, country_name, paste(method, period, sep = " · "), unit))
  metadata <- data.frame(
    Code = c("label", "id", "year", "value", "export_contribution", "import_contribution", "coverage"),
    Label = c(tr("label"), tr("code"), colnames(values), tr("coverage")),
    Definition = c(tr("label_note"), tr(if (kind == "series") "series_code_note" else "code_note"), tr("year_note"),
      tr(if (metric == "transfer") "sign_transfer" else if (metric == "balance") "sign_balance" else "sign_flow"),
      tr("outgoing_note"), tr("incoming_note"), tr("coverage_note")),
    Unit = c(NA_character_, NA_character_, tr("year"), rep(unit, 3L), NA_character_),
    Relationship = c("label", "id", "year", switch(metric, exports = "outgoing", imports = "incoming", "outgoing - incoming"),
      "outgoing", if (is_balance) "-incoming" else "incoming", "coverage"),
    stringsAsFactors = FALSE, check.names = FALSE)
  names(metadata) <- c(tr("code"), tr("label"), tr("definition"), tr("unit"), tr("transform"))
  info <- if (is.null(provenance)) list() else provenance
  details <- if (is.list(info$provenance)) info$provenance else info
  version <- if (!is.null(info$version)) as.character(info$version) else take("data_version", "bilateral")
  specs <- data.frame(field = c(tr("method"), tr("country"), tr("period"), tr("measure"), tr("scope"),
      tr("unit"), tr("partner"), tr("sector"), tr("basis"), tr("version"), tr("rows"), tr("created"),
      tr("source"), "sign_convention", tr("definition"), tr("coverage"), tr("transform")),
    value = c(method, paste(country_name, country, sep = " / "), period, tr(metric), tr(scope), unit,
      if (!is.null(context$partner_label)) context$partner_label else take("partner", take("selected_partner", tr("all_partners"))),
      if (!is.null(context$sector_label)) context$sector_label else take("sector", take("selected_sector", tr("all_sectors"))),
      tr("basis_value"), version, nrow(rows), format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      "WLVDB / WIOD. https://github.com/rodrigofranklin/wlvdb",
      switch(metric, transfer = "outgoing_minus_incoming; positive_receipt_for_focal_country", balance = "outgoing_minus_incoming; positive_trade_surplus", exports = "outgoing", imports = "incoming"),
      tr("raw_note"), tr("missing_note"), tr("units_note")), stringsAsFactors = FALSE)
  append_spec <- function(field, value) {
    if (!is.null(value) && length(value) == 1L && !is.na(value) && nzchar(value))
      specs[nrow(specs) + 1L, ] <<- c(field, as.character(value))
  }
  append_spec(tr("publication"), if (identical(details$publication_mode, "legacy")) tr("legacy") else details$publication_mode)
  append_spec("bilateral_sha256", info$bilateral_sha256)
  if (is.list(details$contract_validation)) append_spec("contract_validation",
    if (identical(details$contract_validation[[method]], "legacy_manifested_contract_snapshot")) tr("snapshot") else details$contract_validation[[method]])
  if (is.list(details$sources) && is.data.frame(details$sources[[method]])) {
    source <- details$sources[[method]]
    for (field in intersect(c("source_generation_id", "contract_id", "contract_version", "contract_sha256", "manifest_sha256"), names(source))) append_spec(field, as.character(source[[field]][[1L]]))
  }
  names(specs) <- c(tr("field"), tr("value"))
  coverage <- vapply(as.character(rows$coverage), tr, character(1L))
  observation_meta <- data.frame(id = ids, year = rows$year, coverage = as.character(rows$coverage),
    observed = if ("observed" %in% names(rows)) rows$observed else NA_integer_,
    expected = if ("expected" %in% names(rows)) rows$expected else NA_integer_, stringsAsFactors = FALSE)
  list(header = header, labels = labels, ids = ids, values = values, coverage = coverage,
    metadata = metadata, specs = specs, observation_metadata = observation_meta,
    original = rows, unit = unit, metric = metric, kind = kind, lang = lang)
}

wlv_write_trade_xlsx <- function(file, rows, selection = list(), context = list(),
    lang = "pt", provenance = NULL, kind = c("selection", "series"),
    helper_path = "utils/download_workbooks.R") {
  if (!requireNamespace("openxlsx", quietly = TRUE)) stop("O pacote openxlsx é necessário.")
  payload <- wlv_trade_workbook_payload(rows, selection, context, lang, provenance, kind)
  tr <- function(key) wlv_trade_workbook_text(key, payload$lang)
  canonical <- new.env(parent = asNamespace("openxlsx"))
  sys.source(helper_path, envir = canonical, keep.source = FALSE)
  # Captura o workbook canônico antes da gravação, para complementá-lo em uma
  # única serialização, preservando os estilos definidos pelo gerador existente.
  canonical$saveWorkbook <- function(wb, file, overwrite = TRUE) {
    canonical$workbook <- wb
    invisible(NULL)
  }
  is_series <- identical(payload$kind, "series")
  layout_values <- payload$values
  layout_labels <- payload$labels
  layout_ids <- payload$ids
  if (is_series) {
    # Os downloads históricos do painel colocam anos nas colunas. Isso evita
    # repetir o ano como descrição, código e variável em três colunas da série.
    layout_values <- t(payload$values[, 2:4, drop = FALSE])
    colnames(layout_values) <- as.character(payload$original$year)
    layout_labels <- colnames(payload$values)[2:4]
    layout_ids <- c("value", "export_contribution", "import_contribution")
    rownames(layout_values) <- layout_ids
  }
  # Usa os mesmos cabeçalhos, folhas, origem da tabela, panes e formatação
  # numérica dos demais downloads. Nenhuma escala científica é reaplicada.
  canonical$save_my_xlsx(file, payload$header, layout_labels, layout_values,
    payload$metadata, payload$specs, rows_style_list = list(seq_len(nrow(layout_values)) + 6L),
    styles_list = list("#,##0.00"), width_c1 = 44, width_c2 = 15)
  wb <- canonical$workbook
  data_rows <- seq_len(nrow(layout_values)) + 6L
  data_columns <- ncol(layout_values) + 2L + as.integer(!is_series)
  displayed <- data.frame(layout_labels, layout_ids, layout_values,
    stringsAsFactors = FALSE, check.names = FALSE)
  names(displayed) <- c(tr("label"), tr("code"), colnames(layout_values))
  if (!is_series) displayed[[tr("coverage")]] <- payload$coverage
  openxlsx::writeData(wb, "data", displayed, startRow = 6L, withFilter = TRUE, keepNA = FALSE)
  header_style <- openxlsx::createStyle(textDecoration = "bold", halign = "center", valign = "center", wrapText = TRUE,
    border = "bottom", borderColour = "#B7B7B7")
  openxlsx::addStyle(wb, "data", header_style, rows = 6L, cols = seq_len(data_columns), gridExpand = TRUE, stack = TRUE)
  if (is_series) {
    width <- apply(layout_values, 2L, function(x) max(18,
      nchar(format(round(x, 2L), big.mark = ",", scientific = FALSE, trim = TRUE)) + 2L, na.rm = TRUE))
    openxlsx::setColWidths(wb, "data", seq_len(ncol(layout_values)) + 2L, width)
    openxlsx::setColWidths(wb, "data", 2L, 24)
    coverage_row <- max(data_rows) + 2L
    openxlsx::writeData(wb, "data", matrix(c(tr("coverage"), "coverage", payload$coverage), nrow = 1L),
      startRow = coverage_row, colNames = FALSE)
  } else {
    openxlsx::addStyle(wb, "data", openxlsx::createStyle(numFmt = "0"), rows = data_rows, cols = 3L, gridExpand = TRUE, stack = TRUE)
    openxlsx::setColWidths(wb, "data", 3L, 10)
    openxlsx::setColWidths(wb, "data", 4:6, 25)
    openxlsx::setColWidths(wb, "data", data_columns, 17)
  }
  openxlsx::setRowHeights(wb, "data", 6L, 34)
  openxlsx::addStyle(wb, "data", openxlsx::createStyle(wrapText = TRUE, valign = "center"), rows = data_rows, cols = 1L, gridExpand = TRUE, stack = TRUE)
  openxlsx::setRowHeights(wb, "data", data_rows, pmax(18, ceiling(nchar(layout_labels, type = "width") / 40) * 15))
  # As especificações extensas não ocupam a folha principal.
  for (sheet in c("metadata", "specs")) {
    columns <- if (sheet == "metadata") 5L else 2L
    table <- if (sheet == "metadata") payload$metadata else payload$specs
    openxlsx::writeData(wb, sheet, table, withFilter = TRUE, keepNA = FALSE)
    openxlsx::addStyle(wb, sheet, header_style, rows = 1L, cols = seq_len(columns), gridExpand = TRUE)
    openxlsx::addStyle(wb, sheet, openxlsx::createStyle(wrapText = TRUE, valign = "top"),
      rows = seq_len(nrow(table)) + 1L, cols = seq_len(columns), gridExpand = TRUE, stack = TRUE)
    widths <- if (sheet == "metadata") c(25, 30, 72, 38, 35) else c(30, 108)
    openxlsx::setColWidths(wb, sheet, seq_len(columns), widths)
    heights <- apply(table, 1L, function(row) max(24, max(ceiling(nchar(as.character(row), type = "width") / (widths - 3)), na.rm = TRUE) * 15))
    openxlsx::setRowHeights(wb, sheet, seq_len(nrow(table)) + 1L, heights)
    openxlsx::setRowHeights(wb, sheet, 1L, 30)
    openxlsx::freezePane(wb, sheet, firstActiveRow = 2L, firstActiveCol = 2L)
  }
  meta_start <- nrow(payload$metadata) + 5L
  openxlsx::writeData(wb, "metadata", tr("observation_metadata"), startRow = meta_start - 1L)
  observation_meta <- payload$observation_metadata
  names(observation_meta) <- c(tr("code"), tr("year"), tr("coverage"), tr("observed"), tr("expected"))
  openxlsx::writeData(wb, "metadata", observation_meta, startRow = meta_start)
  openxlsx::addStyle(wb, "metadata", header_style, rows = meta_start, cols = 1:5, gridExpand = TRUE)
  for (sheet in names(wb)) openxlsx::showGridLines(wb, sheet, showGridLines = FALSE)
  # openxlsx cria relações de drawing/VML vazias por padrão. Elas não podem
  # apontar para partes ausentes do ZIP: leitores OOXML estritos as rejeitam.
  # Preserve qualquer desenho real que o gerador canônico venha a fornecer.
  for (i in seq_along(wb$worksheets)) {
    if (!length(wb$drawings[[i]])) {
      wb$worksheets_rels[[i]] <- wb$worksheets_rels[[i]][!grepl('/relationships/drawing"', wb$worksheets_rels[[i]], fixed = TRUE)]
      wb$worksheets[[i]]$drawing <- character()
    }
    if (!length(wb$vml[[i]])) {
      wb$worksheets_rels[[i]] <- wb$worksheets_rels[[i]][!grepl('/relationships/vmlDrawing"', wb$worksheets_rels[[i]], fixed = TRUE)]
      wb$worksheets[[i]]$legacyDrawing <- character()
    }
  }
  openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
  # Verificação do arquivo final. NA permanece célula vazia e zero é numérico.
  actual <- openxlsx::read.xlsx(file, sheet = "data", rows = data_rows,
    cols = seq_len(data_columns), colNames = FALSE, skipEmptyRows = FALSE, skipEmptyCols = FALSE,
    na.strings = character())
  if (nrow(actual) != nrow(layout_values) || ncol(actual) != data_columns ||
      !identical(as.character(actual[[1L]]), layout_labels) ||
      !identical(as.character(actual[[2L]]), layout_ids)) stop("Comércio XLSX: textos divergentes após gravação.")
  for (i in seq_len(ncol(layout_values))) wlv_trade_workbook_equal(as.numeric(actual[[i + 2L]]), layout_values[, i], colnames(layout_values)[[i]])
  if (is_series) {
    actual_coverage <- openxlsx::read.xlsx(file, sheet = "data", rows = coverage_row,
      cols = seq_len(data_columns), colNames = FALSE, skipEmptyCols = FALSE)
    actual_coverage <- as.character(unlist(actual_coverage[, seq_len(ncol(layout_values)) + 2L, drop = FALSE], use.names = FALSE))
    imported <- as.numeric(unlist(actual[3L, seq_len(ncol(layout_values)) + 2L], use.names = FALSE))
    year_headers <- openxlsx::read.xlsx(file, sheet = "data", rows = 6L,
      cols = seq_len(ncol(layout_values)) + 2L, colNames = FALSE)
    if (!identical(as.character(unlist(year_headers, use.names = FALSE)), as.character(payload$original$year))) stop("Comércio XLSX: anos divergentes após gravação.")
  } else {
    actual_coverage <- as.character(actual[[data_columns]])
    imported <- as.numeric(actual[[6L]])
  }
  if (!identical(actual_coverage, unname(payload$coverage))) stop("Comércio XLSX: cobertura divergente após gravação.")
  restored_incoming <- imported * if (payload$metric %in% c("transfer", "balance")) -1 else 1
  wlv_trade_workbook_equal(restored_incoming, payload$original$incoming, "incoming")
  invisible(list(file = file, rows = nrow(rows), sheets = names(wb), start_row = 7L,
    data_columns = names(displayed)))
}
