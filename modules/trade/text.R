wlv_trade_text <- function(key, lang = "pt") {
  entries <- list(
    title = c("Transferências de valor", "Value transfers"),
    intro = c("Explore ganhos e perdas nas relações comerciais entre países.", "Explore gains and losses in trade relations between countries."),
    method = c("Base", "Database"), country = c("País em análise", "Country in focus"),
    year = c("Ano", "Year"), metric = c("Medida", "Measure"), scope = c("Atividades fornecedoras", "Supplying activities"),
    unit = c("Unidade", "Unit"), partner = c("Parceiro comercial", "Trading partner"), sector = c("Setor do produto", "Supplying sector"),
    all_partners = c("Todos os parceiros", "All partners"), all_sectors = c("Todos os setores", "All sectors"),
    transfer = c("Transferências líquidas de valor", "Net value transfers"), exports = c("Exportações", "Exports"),
    imports = c("Importações", "Imports"), balance = c("Saldo comercial", "Trade balance"),
    productive = c("Produtivas", "Productive"), unproductive = c("Improdutivas", "Unproductive"), total = c("Todas", "All"),
    value = c("Horas de trabalho abstrato", "Abstract labour hours"), usd = c("Dólares (US$)", "Dollars (US$)"),
    usd_transfer = c("US$ equivalentes a preços diretos", "Equivalent US$ at direct prices"),
    usd_trade = c("US$ a preços correntes de mercado", "US$ at current market prices"),
    partners = c("Parceiros", "Partners"), sectors = c("Setores", "Sectors"),
    dimension = c("Detalhar por", "Break down by"), rank = c("Ganhos e perdas", "Gains and losses"),
    ranking = c("Ranking", "Ranking"), composition = c("Composição", "Composition"), map = c("Mapa", "Map"),
    series = c("Evolução", "Over time"), table = c("Tabela", "Table"), legend = c("Legenda", "Legend"),
    net = c("Transferência líquida", "Net transfer"), selected_value = c("Valor selecionado", "Selected value"),
    outgoing = c("Pelas exportações", "Through exports"), incoming = c("Pelas importações", "Through imports"),
    gain = c("Recebimento líquido", "Net receipt"), loss = c("Cessão líquida", "Net outflow"), zero = c("Saldo zero", "Zero balance"),
    sign = c("Positivo: o país recebe valor. Negativo: o país cede valor.", "Positive: the country receives value. Negative: the country gives up value."),
    drill = c("Clique em um parceiro para ver seus setores; em um setor, para explorar seus parceiros.", "Click a partner to see its sectors; click a sector to explore its partners."),
    reset = c("Limpar detalhamento", "Clear breakdown"), download = c("Baixar seleção (XLSX)", "Download selection (XLSX)"),
    download_series = c("Baixar série (XLSX)", "Download time series (XLSX)"),
    flows = c("Exibir fluxos", "Show flows"),
    flow_top = c("maiores transferências · espessura proporcional ao valor", "largest transfers · width proportional to value"),
    flow_shown = c("transferências · espessura proporcional ao valor", "transfers · width proportional to value"),
    flow_one = c("transferência · espessura proporcional ao valor", "transfer · width proportional to value"),
    flow_empty = c("Não há fluxos geográficos para esta seleção.", "No geographic flows for this selection."),
    definitions = c("Como interpretar", "How to read"), missing = c("Sem dados", "No data"),
    empty = c("Não há observações para esta seleção.", "No observations are available for this selection."),
    detail_missing = c("O detalhamento setorial desta base e ano ainda não está disponível. A visão por parceiros continua acessível.", "Sector detail is not yet available for this database and year. The partner view remains available."),
    data_error = c("Não foi possível ler os dados de comércio. Verifique a preparação dos arquivos locais.", "Trade data could not be read. Check the prepared local files."),
    partial = c("Há observações ausentes ou incompletas. Elas não são tratadas como zero.", "Some observations are missing or incomplete. They are not treated as zero."),
    map_note = c("As setas indicam quem cede e quem recebe valor; suas curvas são esquemáticas. Resto do mundo (ROW) aparece na tabela e nos totais, pois é um agregado.", "Arrows show who gives up and who receives value; their curves are schematic. Rest of the world (ROW) is included in the table and totals because it is an aggregate."),
    source = c("Fonte: WLVDB", "Source: WLVDB"), coverage = c("Cobertura", "Coverage"),
    complete = c("Completa", "Complete"),
    coverage_partial = c("Parcial", "Partial"),
    version_changed = c("Os dados foram atualizados desde a criação deste link; os valores exibidos usam a versão instalada atualmente.", "Data have changed since this link was created; displayed values use the currently installed version."),
    periods = c("Período disponível", "Available period"), filters = c("Filtros de comércio", "Trade filters"),
    detail = c("Aprofundar a seleção", "Explore the selection"),
    definition_body = c("A transferência compara o valor representado pela receita monetária com o trabalho abstrato incorporado na mercadoria. O saldo líquido soma as contribuições das exportações e das importações, na perspectiva do país em análise. Atividades produtivas correspondem ao recorte de troca desigual; o total também inclui atividades classificadas como improdutivas pelo método.", "A transfer compares the value represented by monetary revenue with the abstract labour embodied in the commodity. The net balance sums export and import contributions from the perspective of the country in focus. Productive activities correspond to the unequal-exchange scope; the total also includes activities classified as unproductive by the method."),
    unit_body = c("As horas são resultados do modelo. Dólares equivalentes das transferências usam a normalização anual do comércio, não a taxa de câmbio. Exportações e importações monetárias são expressas a preços correntes.", "Hours are model results. Equivalent dollars for transfers use annual trade normalization, not the exchange rate. Monetary exports and imports are expressed at current prices."),
    sector_body = c("O setor identifica o fornecedor do produto em cada sentido do comércio. Ele não identifica necessariamente a atividade compradora nem o país de origem de todo o trabalho a montante.", "The sector identifies the supplier of the product in each trade direction. It does not necessarily identify the buying activity or the country of origin of all upstream labour."),
    base_body = c("WIOD13 e WIOD16 têm classificações e coberturas diferentes. As séries não são emendadas. A WIOD13 mantém a cobertura usada pelo painel, até 2007.", "WIOD13 and WIOD16 have different classifications and coverage. Their series are not spliced. WIOD13 retains the panel's coverage, through 2007.")
  )
  if (!key %in% names(entries)) return(key)
  entries[[key]][[if (identical(lang, "en")) 2L else 1L]]
}

wlv_trade_label <- function(language, key, lang = "pt", fallback = key) {
  if (!length(key)) return(character())
  value <- as.character(language[match(key, rownames(language)), if (identical(lang, "en")) "English" else "Português"])
  missing <- is.na(value) | !nzchar(value)
  value[missing] <- rep_len(fallback, length(value))[missing]
  value
}

wlv_trade_number <- function(value, lang = "pt") {
  if (length(value) != 1L || !is.finite(value)) return(wlv_trade_text("missing", lang))
  exponent <- if (abs(value) < 1000) 0L else min(4L, floor(log10(abs(value)) / 3))
  suffixes <- if (identical(lang, "en")) c("", " K", " M", " B", " T") else c("", " mil", " M", " bi", " tri")
  paste0(format(round(value / 1000^exponent, 2L), big.mark = if (identical(lang, "en")) "," else ".", decimal.mark = if (identical(lang, "en")) "." else ",", scientific = FALSE, trim = TRUE), suffixes[[exponent + 1L]])
}
