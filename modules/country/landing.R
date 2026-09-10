# The entry uses one method at a time; comparisons remain in the detailed page.
source("utils/country_landing_data.R", encoding = "UTF-8")
source("utils/country_landing_charts.R", encoding = "UTF-8")

wlv_country_landing_ui <- function() {
  tagList(
    htmltools::includeCSS("www/wlv-country-entry.css"),
    htmltools::includeScript("www/wlv-country-geo.js"),
    htmltools::includeScript("www/wlv-country-globe.js"),
    htmltools::includeScript("www/wlv-country-localization.js"),
    tags$section(id = "wlv-country-entry", class = "wlv-country-entry", `data-state` = "loading",
      `aria-label` = "Visão geral do país",
      div(class = "wlv-entry-loading", role = "status", `aria-live` = "polite",
        tags$p(class = "wlv-entry-loading-label", "Carregando o país…"),
        div(class = "wlv-entry-placeholder", `aria-hidden` = "true",
          div(class = "wlv-entry-placeholder-story",
            tags$span(class = "wlv-entry-placeholder-name"),
            tags$span(), tags$span(), tags$span(), tags$span(),
            div(class = "wlv-entry-placeholder-facts")),
          div(class = "wlv-entry-placeholder-charts", tags$span(), tags$span()),
          div(class = "wlv-entry-placeholder-globe"))),
      div(class = "wlv-entry-content", inert = NA, `aria-hidden` = "true", `aria-busy` = "true",
      div(class = "wlv-entry-topline",
        div(class = "wlv-entry-country",
          selectizeInput("co_select_country", "País", choices = NULL, width = "100%",
            options = list(allowEmptyOption = FALSE))),
        div(class = "wlv-entry-method",
          selectInput("co_entry_method", "Base de dados", choices = NULL))),
      div(class = "wlv-entry-grid",
        div(class = "wlv-entry-story",
          uiOutput("co_entry_description", `aria-live` = "polite"),
          uiOutput("co_entry_facts"),
          actionButton("co_entry_more", "Mostre-me mais", icon = icon("arrow-right"), class = "wlv-entry-more btn-primary"),
          tags$p(class = "wlv-entry-source", textOutput("co_entry_source", inline = TRUE))),
        div(class = "wlv-entry-charts",
          tags$section(class = "wlv-entry-chart", `aria-labelledby` = "co_entry_labour_title",
            tags$h2(textOutput("co_entry_labour_title", inline = TRUE)),
            tags$p(class = "wlv-entry-unit", textOutput("co_entry_labour_unit", inline = TRUE)),
            uiOutput("co_entry_labour_chart")),
          tags$section(class = "wlv-entry-chart", `aria-labelledby` = "co_entry_trade_title",
            tags$h2(textOutput("co_entry_trade_title", inline = TRUE)),
            tags$p(class = "wlv-entry-unit", textOutput("co_entry_trade_unit", inline = TRUE)),
            uiOutput("co_entry_trade_chart"),
            tags$details(class = "wlv-entry-formulas",
              tags$summary(textOutput("co_entry_formulas_label", inline = TRUE)),
              uiOutput("co_entry_formulas")))),
        tags$aside(class = "wlv-entry-world",
          tags$h2(textOutput("co_entry_globe_title", inline = TRUE)),
          div(id = "wlv-country-globe"))),
      tags$details(id = "wlv-country-catalogue", class = "wlv-entry-catalogue",
        tags$summary(textOutput("co_entry_catalogue_label", inline = TRUE)),
        div(class = "wlv-country-catalogue-filters panel panel-default",
          textInput("co_catalogue_search", "Buscar país", width = "100%"),
          selectizeInput("co_catalogue_region", "Continente", choices = c("Todos os continentes" = ""), selected = "", width = "100%",
            options = list(allowEmptyOption = TRUE, onInitialize = I("function() { var option = this.options['']; if (option) { this.settings.placeholder = option.label; this.updatePlaceholder(); } }")))),
        uiOutput("co_country_catalogue"))))
  )
}

wlv_entry_number <- function(value, lang, digits = 0L) {
  if (length(value) != 1L || !is.finite(value)) return("—")
  formatC(value, format = "f", digits = digits,
    big.mark = wlv_number_marks(lang)$grouping,
    decimal.mark = wlv_number_marks(lang)$decimal)
}

wlv_country_landing_server <- function(IP, OP, RV, SESSION, availability, country) {
  tr <- function(pt, en) wlv_tr(pt, en, IP$l)
  expanded <- reactiveVal(FALSE)
  OP$co_entry_expanded <- renderText(if (expanded()) "true" else "false")
  outputOptions(OP, "co_entry_expanded", suspendWhenHidden = FALSE)
  observeEvent(IP$co_entry_more, { req(nzchar(country())); expanded(TRUE) })
  observeEvent(IP$co_catalogue_back, {
    expanded(FALSE)
    SESSION$sendCustomMessage("wlv-country-overview", list())
  })
  observeEvent(IP$co_globe_country, {
    code <- IP$co_globe_country
    if (length(code) == 1L && code %in% availability()$countries) {
      updateSelectizeInput(SESSION, "co_select_country", selected = code)
    }
  }, ignoreInit = TRUE)
  previous_country <- NULL
  observeEvent(IP$co_select_country, {
    code <- IP$co_select_country
    # Translating selectize choices can re-emit the same value. Only an actual
    # country change should close the details, not a label/options refresh.
    if (length(code) == 1L && nzchar(code) && code %in% availability()$countries) {
      if (!is.null(previous_country) && !identical(code, previous_country)) expanded(FALSE)
      previous_country <<- code
    }
  }, ignoreInit = FALSE)
  methods <- reactive(intersect(RV$bases(), dimnames(sea_countries)[[1L]]))
  selected_method <- reactive({
    available <- methods(); req(length(available))
    req(nzchar(country()))
    current <- IP$co_entry_method
    if (length(current) == 1L && current %in% available) return(current)
    # Prefer the latest usable country observation, without joining methods.
    code <- country()
    latest <- vapply(available, function(method) {
      if (!nzchar(code)) return(-Inf)
      x <- sea_countries[method, , , code, drop = FALSE]
      years <- as.numeric(dimnames(x)[[2L]])[apply(x, 2L, function(v) any(is.finite(v)))]
      if (length(years)) max(years) else -Inf
    }, numeric(1L))
    available[[which.max(latest)]]
  })
  observe({
    updateSelectInput(SESSION, "co_entry_method", label = tr("Base de dados", "Dataset"),
      choices = methods(), selected = selected_method())
  })
  # Country choices can invalidate while being relabelled. Only a changed
  # numeric selection prepares another profile; process-owned data are immutable.
  entry_value <- reactiveVal(NULL)
  entry_selection <- NULL
  observe({
    code <- country(); req(nzchar(code))
    selection <- list(country = code, method = selected_method())
    if (identical(selection, entry_selection)) return()
    value <- wlv_country_landing_data(sea_countries, meta_indicator_contracts,
      code, selection$method, bilateral = wlv_trade_store$bilateral)
    entry_selection <<- selection
    entry_value(value)
  }, priority = 50)
  entry <- reactive({ value <- entry_value(); req(!is.null(value)); value })
  observe({
    codes <- availability()$countries
    SESSION$sendCustomMessage("wlv-country-globe", list(
      countries = lapply(seq_along(codes), function(i) list(code = codes[[i]], label = lb(paste0("ISO3.", codes[[i]]), IP$l))),
      selected = country(), lang = IP$l))
  })
  OP$co_entry_labour_title <- renderText(tr("A jornada e o mais-valor", "The working year and surplus value"))
  OP$co_entry_labour_unit <- renderText(tr("Horas anuais de trabalho abstrato por assalariado", "Annual abstract labour hours per employee"))
  OP$co_entry_trade_title <- renderText(tr("O valor que cruza as fronteiras", "Value across borders"))
  OP$co_entry_trade_unit <- renderText(tr("Bilhões de horas de trabalho abstrato por ano", "Billion abstract labour hours per year"))
  OP$co_entry_globe_title <- renderText(tr("Explore outro país", "Explore another country"))
  OP$co_entry_catalogue_label <- renderText(tr("Ver lista de países e agregados", "Browse countries and aggregates"))
  # A fit-content summary has zero width until this label arrives. Do not let
  # Shiny suspend the text that gives its own disclosure control a visible size.
  outputOptions(OP, "co_entry_catalogue_label", suspendWhenHidden = FALSE)
  OP$co_entry_formulas_label <- renderText(tr("Como os fluxos são calculados", "How the flows are calculated"))
  observe({
    updateActionButton(SESSION, "co_entry_more", label = tr("Mostre-me mais", "Show me more"))
  })
  OP$co_entry_formulas <- renderUI(tagList(
    tags$p(tags$strong(tr("Enviado", "Sent")), " = ", tr("horas das exportações + horas representadas pelo dinheiro pago nas importações.", "export hours + hours represented by money paid for imports.")),
    tags$p(tags$strong(tr("Recebido", "Received")), " = ", tr("horas das importações + horas representadas pelo dinheiro recebido nas exportações.", "import hours + hours represented by money received for exports.")),
    tags$p(tr("Saldo líquido = recebido − enviado. O dinheiro é convertido em horas pelo fator internacional anual da própria base.", "Net balance = received − sent. Money is converted into hours using the dataset’s annual international factor."))))
  OP$co_entry_description <- renderUI({
    data <- entry(); lang <- IP$l; labour <- data$latest_labour; trade <- data$latest_trade
    name <- lb(paste0("ISO3.", country()), lang)
    region <- unname(wlv_country_regions[country()])
    location <- if (length(region) == 1L && !is.na(region) && !region %in% c("Aggregates", "Other"))
      paste0(wlv_country_region_label(region, lang), ". ") else ""
    intro <- tags$p(class = "wlv-entry-intro", tags$strong(name), " · ", location,
      tr("Um retrato do trabalho, de sua remuneração e das trocas de valor com o mundo.", "A portrait of labour, its compensation and exchanges of value with the world."))
    labour_text <- if (!is.null(labour) && nrow(labour)) tags$p(wlv_fill_template(
      tr("Em {year}, a jornada anual média equivale a {workday} horas de trabalho abstrato por assalariado. Desse total, {labour_power} horas repõem o valor da força de trabalho e {surplus} horas correspondem ao mais-valor.",
        "In {year}, the average working year amounts to {workday} abstract labour hours per employee. Of these, {labour_power} hours replace the value of labour power and {surplus} hours correspond to surplus value."),
      list(year = tags$strong(labour$year), workday = tags$strong(wlv_entry_number(labour$workday, lang)),
        labour_power = tags$strong(wlv_entry_number(labour$labour_power, lang)), surplus = tags$strong(wlv_entry_number(labour$surplus, lang))))) else
      tags$p(tr("As séries de jornada e valor da força de trabalho não estão disponíveis nesta base para esta seleção.", "Working time and labour power value series are unavailable for this selection in this dataset."))
    trade_text <- if (!is.null(trade) && nrow(trade)) tags$p(wlv_fill_template(
      if (trade$net == 0) tr("No comércio internacional, em {year}, o valor enviado e o recebido se equilibraram.",
        "In international trade, in {year}, value sent and received were balanced.") else if (trade$net > 0)
        tr("No comércio internacional, em {year}, {country} recebeu, em termos líquidos, {hours} bilhões de horas de trabalho abstrato.",
          "In international trade, in {year}, {country} received a net {hours} billion abstract labour hours.") else
        tr("No comércio internacional, em {year}, {country} enviou, em termos líquidos, {hours} bilhões de horas de trabalho abstrato.",
          "In international trade, in {year}, {country} sent a net {hours} billion abstract labour hours."),
      list(year = tags$strong(trade$year), country = name, hours = tags$strong(wlv_entry_number(abs(trade$net) / 1e9, lang, 2L))))) else
      tags$p(tr("A decomposição dos fluxos comerciais não está disponível nesta base para esta seleção.", "The trade flow breakdown is unavailable for this selection in this dataset."))
    tagList(intro, labour_text, trade_text)
  })
  OP$co_entry_facts <- renderUI({
    data <- entry(); labour <- data$latest_labour; trade <- data$latest_trade
    rate <- wlv_country_landing_latest(data$labour, "exploitation")
    div(class = "wlv-entry-facts",
      div(class = "wlv-entry-fact",
        tags$span(tr("Taxa de exploração", "Rate of exploitation")),
        tags$strong(if (is.null(rate)) "—" else paste0(wlv_entry_number(rate$exploitation, IP$l, 1L), "%")),
        tags$small(if (is.null(rate)) tr("Sem dados", "No data") else paste0(rate$year, " · ", tr("mais-valor / força de trabalho", "surplus value / labour power")))),
      div(class = paste("wlv-entry-fact", if (!is.null(trade) && trade$net > 0) "is-received" else "is-sent"),
        tags$span(tr("Transferência líquida de valor", "Net value transfer")),
        tags$strong(if (is.null(trade)) "—" else paste0(if (trade$net > 0) "+" else if (trade$net < 0) "−" else "", wlv_entry_number(abs(trade$net) / 1e9, IP$l, 2L))),
        tags$small(if (is.null(trade)) tr("Sem dados", "No data") else paste0(trade$year, " · ", tr("bilhões de horas · recebido − enviado", "billion hours · received − sent")))))
  })
  OP$co_entry_source <- renderText({
    data <- entry()
    paste0(tr("Fonte: WLVD · ", "Source: WLVD · "), data$method,
      tr(". Cada indicador destaca seu último ano disponível.", ". Each indicator highlights its latest available year."))
  })
  labour_chart <- reactive({
    data <- entry()$labour
    wlv_country_landing_chart_prepare(data$year, data$workday, data$labour_power,
      id = "co-entry-labour")
  })
  trade_chart <- reactive({
    data <- entry()$trade
    wlv_country_landing_chart_prepare(data$year, data$sent / 1e9, data$received / 1e9,
      id = "co-entry-trade")
  })
  chart_labels <- function(kind, lang) {
    if (kind == "labour") wlv_tr(c("Jornada de trabalho", "Valor da força de trabalho"),
      c("Working time", "Value of labour power"), lang) else
      wlv_tr(c("Valor bruto enviado", "Valor bruto recebido"),
        c("Gross value sent", "Gross value received"), lang)
  }
  OP$co_entry_labour_chart <- renderUI({
    state <- labour_chart(); lang <- isolate(IP$l)
    wlv_country_landing_chart(prepared = state, labels = chart_labels("labour", lang),
      kind = "labour", lang = lang)
  })
  OP$co_entry_trade_chart <- renderUI({
    state <- trade_chart(); lang <- isolate(IP$l)
    wlv_country_landing_chart(prepared = state, labels = chart_labels("trade", lang),
      kind = "trade", lang = lang)
  })
  observeEvent(IP$l, {
    lang <- IP$l
    charts <- lapply(c("labour", "trade"), function(kind) {
      state <- if (kind == "labour") labour_chart() else trade_chart()
      text <- wlv_country_landing_chart_text(state, chart_labels(kind, lang), kind, lang)
      c(list(output = paste0("co_entry_", kind, "_chart")), text)
    })
    SESSION$sendCustomMessage("wlv-country-chart-text", list(
      lang = wlv_language_locale(lang), charts = charts))
  }, ignoreInit = TRUE)
  # The first view is revealed together, including when this tab starts hidden.
  # Its loading treatment must never suspend the outputs needed to finish it.
  for (id in c("co_entry_description", "co_entry_facts", "co_entry_source",
               "co_entry_labour_chart", "co_entry_trade_chart",
               "co_entry_labour_title", "co_entry_labour_unit",
               "co_entry_trade_title", "co_entry_trade_unit",
               "co_entry_globe_title", "co_entry_catalogue_label", "co_entry_formulas_label")) {
    outputOptions(OP, id, suspendWhenHidden = FALSE)
  }
}
