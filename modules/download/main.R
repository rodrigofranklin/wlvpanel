### Module: Download
# Dados agregados, dados multilaterais e código-fonte.
source("utils/download_workbooks.R", encoding = "UTF-8")
source("utils/download_requests.R", encoding = "UTF-8")

# The historical bilateral array is loaded once, only when that selector is used.
wlv_download_multilateral_data <- local({
  values <- NULL
  function() {
    if (is.null(values) && file.exists("data/m_countries.RDS")) {
      values <<- readRDS("data/m_countries.RDS")
    }
    values
  }
})

# Os rótulos ficam associados aos inputs e são traduzidos sem recriar os campos.
TABPANEL <- tabPanel(
  l("tab_name.download"),
  value = "download",
  htmltools::includeScript("www/wlv-download.js"),
  div(class = "wlv-explore-page wlv-download-page",
    div(class = "wlv-explore-content",
    tags$header(class = "wlv-explore-heading", tags$h1(l("tab_name.download"))),
    div(class = "wlv-download-grid",
      div(class = "panel panel-default",
        div(class = "panel-heading", strong(l("dl_agg_title"))),
        div(class = "panel-body",
          selectizeInput("dl_method", l("dl_select_method.label"), choices = NULL),
          conditionalPanel("input.dl_method && input.dl_method !== ''",
            div(class = "wlv-download-fields",
              selectizeInput("dl_indicator", l("dl_select_indicator.label"),
                choices = NULL, options = list(optgroupField = "groups")),
              selectizeInput("dl_country", l("dl_select_country.label"), choices = NULL),
              conditionalPanel("input.dl_indicator || input.dl_country",
                selectizeInput("dl_sector", l("dl_select_sector_country.label"), choices = NULL)
              )
            ),
            p(class = "wlv-download-hint", l("dl_select_andor"))
          ),
          uiOutput("dl_download")
        )
      ),
      div(class = "panel panel-default",
        div(class = "panel-heading", strong(l("dl_ml_title"))),
        div(class = "panel-body",
          selectizeInput("dl_ml_method", l("dl_ml_select_method.label"), choices = NULL),
          conditionalPanel("input.dl_ml_method && input.dl_ml_method !== ''",
            selectizeInput("dl_ml_country", l("dl_ml_select_country.label"), choices = NULL),
            conditionalPanel("input.dl_ml_country && input.dl_ml_country !== ''",
              p(class = "wlv-download-hint", l("dl_ml_select_and")),
              selectizeInput("dl_ml_partner", l("dl_ml_select_partner.label"), choices = NULL),
              tags$fieldset(
                tags$legend(l("dl_ml_select_indicator.label")),
                div(class = "wlv-download-fields",
                  selectizeInput("dl_ml_ind_cat", l("dl_ml_ind_cat_placeholder"), choices = NULL),
                  selectizeInput("dl_ml_ind_scope", l("dl_ml_ind_scope_placeholder"), choices = NULL),
                  selectizeInput("dl_ml_ind_un", l("dl_ml_ind_un_placeholder"), choices = NULL)
                )
              )
            )
          ),
          uiOutput("dl_ml_download")
        )
      )
    ),
    div(class = "panel panel-default",
      div(class = "panel-heading", strong(l("dl_source_title"))),
      div(class = "panel-body",
        p(a(href = "https://github.com/rodrigofranklin/wlvdb/archive/refs/heads/master.zip",
          target = "_blank", rel = "noopener noreferrer", l("dl_source_portable_msg"))),
        p(a(href = "https://github.com/rodrigofranklin/wlvdb",
          target = "_blank", rel = "noopener noreferrer", l("dl_source_code_msg")))
      )
    )
  )
  )
)
modules_ui[[length(modules_ui) + 1L]] <- TABPANEL

# Mantém somente seleções que continuam válidas na nova lista de opções.
wlv_download_selection <- function(selected, choices) {
  if (length(selected) == 1L && !is.na(selected) && selected %in% choices) selected else ""
}

wlv_download_action <- function(href, lang, status_id, download_id = NULL, awaiting = FALSE) {
  if (!is.null(download_id)) {
    downloadButton(download_id, lb("app.download", lang))
  } else if (nzchar(href)) {
    tags$a(href = href, download = NA, class = "btn btn-primary",
      icon("download"), lb("app.download", lang))
  } else {
    tagList(
      tags$button(type = "button", class = "btn btn-default", disabled = TRUE,
        `aria-describedby` = status_id, icon("download"), lb("app.download", lang)),
      tags$p(id = status_id, class = "wlv-download-hint", role = "status",
        if (awaiting) {
          wlv_tr("Complete uma seleção válida para baixar os dados.", "Complete a valid selection to download the data.", lang)
        } else lb("app.no_file", lang))
    )
  }
}

## Server ####

download_server <- function(IP, OP, RV, SESSION) {
  # Option refreshes carry labels and availability, never an old selected value.
  # Rebuilding a server-side Selectize on language changes emits a transient
  # empty value and can restore stale selections after the user's next action.
  updateSelectizeInput <- function(session = SESSION, inputId, label = NULL,
      choices = NULL, selected = NULL, options = list(), server = FALSE) {
    if (is.null(choices)) {
      return(shiny::updateSelectizeInput(session, inputId, label = label,
        selected = selected, options = options, server = FALSE))
    }
    choice_rows <- if (is.data.frame(choices)) {
      lapply(seq_len(nrow(choices)), function(i) as.list(choices[i, , drop = FALSE]))
    } else {
      labels <- names(choices)
      if (is.null(labels)) labels <- as.character(choices)
      lapply(seq_along(choices), function(i) list(
        value = as.character(choices[[i]]), label = labels[[i]]
      ))
    }
    dependencies <- switch(inputId,
      dl_country = "dl_method", dl_indicator = "dl_method", dl_sector = "dl_method",
      dl_ml_country = "dl_ml_method", dl_ml_partner = c("dl_ml_method", "dl_ml_country"),
      dl_ml_ind_cat = "dl_ml_ind_un", dl_ml_ind_un = "dl_ml_ind_cat", character()
    )
    expected <- stats::setNames(lapply(dependencies, function(id) {
      value <- isolate(IP[[id]])
      if (is.null(value)) "" else value
    }), dependencies)
    session$sendCustomMessage("wlv-download-choices", list(
      id = inputId, choices = choice_rows, label = label,
      placeholder = options$placeholder, expected = expected
    ))
  }
  
  choices_ml_ind <- reactiveValues()

  # Fill methods and multilateral indicators
  observe({
    methods <- RV$bases()
    lng <- IP$l

    updateSelectizeInput(
      inputId = "dl_method",
      choices = methods,
      selected = wlv_download_selection(isolate(IP$dl_method), methods),
      server = FALSE, # needed for placeholder to work...
      options = list(
        placeholder = lb("dl_select_method.placeholder", lng)
      )
    )

    updateSelectizeInput(
      inputId = "dl_ml_method",
      choices = methods,
      selected = wlv_download_selection(isolate(IP$dl_ml_method), methods),
      server = FALSE, # needed for placeholder to work...
      options = list(
        placeholder = lb("dl_select_method.placeholder", lng)
      )
    )
    
    choices_ml_ind_cat <- c("", "CX.", "CM.", "CN.", "TS.", "TR.", "TT.")
    names(choices_ml_ind_cat) <- c(
      lb("dl_ml_ind_cat_placeholder", lng),
      lb("dl_ml_ind_CX", lng),
      lb("dl_ml_ind_CM", lng),
      lb("dl_ml_ind_CN", lng),
      lb("dl_ml_ind_TS", lng),
      lb("dl_ml_ind_TR", lng),
      lb("dl_ml_ind_TT", lng))
    choices_ml_ind$cat <- choices_ml_ind_cat
    if (identical(isolate(IP$dl_ml_ind_un), "MP")) {
      choices_ml_ind_cat <- choices_ml_ind_cat[!grepl("^T", choices_ml_ind_cat)]
    }
    updateSelectizeInput(
      inputId = "dl_ml_ind_cat",
      choices = choices_ml_ind_cat,
      selected = wlv_download_selection(isolate(IP$dl_ml_ind_cat), choices_ml_ind_cat))
    
    choices_ml_ind_scope <- c("", "T.", "P.", "U.")
    names(choices_ml_ind_scope) <- c(
      lb("dl_ml_ind_scope_placeholder", lng),
      lb("dl_ml_ind_T", lng),
      lb("dl_ml_ind_P", lng),
      lb("dl_ml_ind_U", lng))
    choices_ml_ind$scope <- choices_ml_ind_scope
    updateSelectizeInput(
      inputId = "dl_ml_ind_scope",
      choices = choices_ml_ind_scope,
      selected = wlv_download_selection(isolate(IP$dl_ml_ind_scope), choices_ml_ind_scope))
    
    choices_ml_ind_un <- c("", "MP", "DP", "MV")
    names(choices_ml_ind_un) <- c(
      lb("dl_ml_ind_un_placeholder", lng),
      lb("dl_ml_ind_MP", lng),
      lb("dl_ml_ind_DP", lng),
      lb("dl_ml_ind_MV", lng))
    choices_ml_ind$un <- choices_ml_ind_un
    if (any(grepl("^T", isolate(IP$dl_ml_ind_cat)))) {
      choices_ml_ind_un <- choices_ml_ind_un[choices_ml_ind_un != "MP"]
    }
    updateSelectizeInput(
      inputId = "dl_ml_ind_un",
      choices = choices_ml_ind_un,
      selected = wlv_download_selection(isolate(IP$dl_ml_ind_un), choices_ml_ind_un))
    
  })
  
  # Selector's behaviour
  observeEvent(list(IP$dl_method, IP$l), {
    method <- IP$dl_method
    lng <- IP$l
    selected_country <- IP$dl_country |> isolate()
    selected_indicator <- IP$dl_indicator |> isolate()
    selected_sector <- IP$dl_sector |> isolate()
    
    
    req(method, method %in% dimnames(sea_countries)[[1L]])

    temp_data <- sea_countries[method,,,, drop = FALSE]

    countries <- wlv_observed_axis_labels(temp_data, 4L)
    indicators <- wlv_observed_axis_labels(temp_data, 3L)

    names(countries) <- lb(paste0("ISO3.",countries), lng)
    countries <- countries[order(names(countries))]
    
    updateSelectizeInput(
      inputId = "dl_country",
      choices = countries,
      server = FALSE, # needed for placeholder to work...
      selected = wlv_download_selection(selected_country, countries),
      options = list(
        placeholder = lb("dl_select_country.placeholder", lng)
      ))
    
    
    indicators <- meta_indicators[
      meta_indicators$value %in% indicators,
      c("value","groups")]
    indicators$groups <- lb(paste0("group.",indicators$groups),lng)
    indicators$label <- lb(indicators$value,lng)
    updateSelectizeInput(
      inputId = "dl_indicator",
      choices = indicators,
      server = TRUE,
      selected = wlv_download_selection(selected_indicator, indicators$value),
      options = list(
        placeholder = lb("co_select_indicator.placeholder", lng)))
    
    sectors <- names(sea_sectors[[method]][1,1,,1])
    names(sectors) <- lb(paste0(meta_methods$source[meta_methods$code==method],
                                ".",sectors),lng)
    
    updateSelectizeInput(
      inputId = "dl_sector",
      choices = sectors,
      server = FALSE,
      selected = wlv_download_selection(selected_sector, sectors),
      options = list(
        placeholder = lb("dl_select_sector.placeholder", lng)
      ))
  })

  observe({
    key <- if (wlv_nonempty_selection(IP$dl_indicator)) {
      "dl_select_sector_indicator.label"
    } else "dl_select_sector_country.label"
    updateSelectizeInput(inputId = "dl_sector", label = lb(key, IP$l))
  })
  
  observeEvent(IP$dl_indicator, {
    indicator <- IP$dl_indicator
    country <- IP$dl_country |> isolate()
    sector <- IP$dl_sector |> isolate()
    method <- IP$dl_method |> isolate()

    req(method)
    sector_countries <- wlv_sector_country_codes(sea_sectors, method)
    if (
      wlv_nonempty_selection(indicator) &&
        wlv_nonempty_selection(country) &&
        !country %in% sector_countries
    ) {
      updateSelectizeInput(inputId = "dl_country", selected = "")
      return()
    }
    
    if (
      wlv_nonempty_selection(indicator) &&
        wlv_nonempty_selection(country) &&
        wlv_nonempty_selection(sector)
    ) {
      updateSelectizeInput(
        inputId = "dl_sector",
        selected = ""
      )

      updateSelectizeInput(
        inputId = "dl_country",
        selected = ""
      )
    }
  })

  observeEvent(IP$dl_country, {
    country <- IP$dl_country
    indicator <- IP$dl_indicator |> isolate()
    sector <- IP$dl_sector |> isolate()
    method <- IP$dl_method |> isolate()
    req(country)
    req(method)

    sector_countries <- wlv_sector_country_codes(sea_sectors, method)
    if (!country %in% sector_countries) {
      if (wlv_nonempty_selection(indicator)) {
        updateSelectizeInput(inputId = "dl_indicator", selected = "")
      }
      if (wlv_nonempty_selection(sector)) {
        updateSelectizeInput(inputId = "dl_sector", selected = "")
      }
      return()
    }
    
    if (
      wlv_nonempty_selection(indicator) &&
        wlv_nonempty_selection(country)
    )
      updateSelectizeInput(
        inputId = "dl_sector",
        selected = ""
      )
  })

  observeEvent(IP$dl_sector, {
    sector <- IP$dl_sector
    indicator <- IP$dl_indicator |> isolate()
    country <- IP$dl_country |> isolate()
    method <- IP$dl_method |> isolate()
    req(sector)
    req(method)

    sector_countries <- wlv_sector_country_codes(sea_sectors, method)
    if (
      wlv_nonempty_selection(country) &&
        !country %in% sector_countries
    ) {
      updateSelectizeInput(inputId = "dl_country", selected = "")
      return()
    }
    
    if (
      wlv_nonempty_selection(indicator) &&
        wlv_nonempty_selection(sector)
    )
      updateSelectizeInput(
        inputId = "dl_country",
        selected = ""
      )
  })

  observeEvent(list(IP$dl_ml_method, IP$l), {
    method <- IP$dl_ml_method
    lng <- IP$l
    selected_country <- IP$dl_ml_country |> isolate()
    
    req(method, method %in% names(sea_sectors))
    
    countries <- sea_sectors[[method]][1,1,1,] |> names()
    names(countries) <- lb(paste0("ISO3.",countries), lng)
    countries <- countries[order(names(countries))]
    
    updateSelectizeInput(
      inputId = "dl_ml_country",
      choices = countries,
      server = FALSE, # needed for placeholder to work...
      selected = wlv_download_selection(selected_country, countries),
      options = list(
        placeholder = lb("dl_select_country.placeholder", lng)
      ))
  })
  
  observeEvent(list(IP$dl_ml_country, IP$dl_ml_method, IP$l), {
    country <- IP$dl_ml_country
    partner <- IP$dl_ml_partner |> isolate()
    method <- IP$dl_ml_method |> isolate()
    lng <- IP$l
    req(method, method %in% names(sea_sectors))
    
    partners <- sea_sectors[[method]][1,1,1,] |> names()
    names(partners) <- lb(paste0("ISO3.",partners), lng)
    partners <- partners[order(names(partners))]
    partners <- partners[!partners %in% country]
    
    updateSelectizeInput(
      inputId = "dl_ml_partner",
      choices = partners,
      selected = wlv_download_selection(partner, partners),
      options = list(placeholder = lb("dl_select_country.placeholder", lng)))
  })
  
  observeEvent(IP$dl_ml_partner, {
    partner <- IP$dl_ml_partner
    country <- IP$dl_ml_country |> isolate()
    method <- IP$dl_ml_method |> isolate()
    lng <- IP$l
    req(method)
    
    if (partner == "") return()
    
    updateSelectizeInput(
      inputId = "dl_ml_ind_cat",
      selected = "")
    
    updateSelectizeInput(
      inputId = "dl_ml_ind_scope",
      selected = "")
    
    updateSelectizeInput(
      inputId = "dl_ml_ind_un",
      selected = "")
  })
  
  observeEvent(IP$dl_ml_ind_cat, {
    ind_cat <- IP$dl_ml_ind_cat
    selected <- IP$dl_ml_ind_un |> isolate()
    
    req(ind_cat)
    
    if (ind_cat != "") {
      updateSelectizeInput(
        inputId = "dl_ml_partner",
        selected = "")
    }
    
    if (grep("T", ind_cat) |> identical(integer(0))) {
      updateSelectizeInput(
        inputId = "dl_ml_ind_un",
        choices = choices_ml_ind$un,
        selected = selected)
    } else {
      allowed_units <- choices_ml_ind$un[choices_ml_ind$un != "MP"]
      updateSelectizeInput(
        inputId = "dl_ml_ind_un",
        choices = allowed_units,
        selected = wlv_download_selection(selected, allowed_units))
    }
  })
  
  observeEvent(IP$dl_ml_ind_scope, {
    ind_scope <- IP$dl_ml_ind_scope

    req(ind_scope)
    
    if (ind_scope != "") {
      updateSelectizeInput(
        inputId = "dl_ml_partner",
        selected = "")
    }
  })

  observeEvent(IP$dl_ml_ind_un, {
    ind_un <- IP$dl_ml_ind_un
    selected <- IP$dl_ml_ind_cat |> isolate()
    
    req(ind_un)
    
    if (ind_un != "") {
      updateSelectizeInput(
        inputId = "dl_ml_partner",
        selected = "")
    }
    
    if (ind_un != "MP") {
      updateSelectizeInput(
        inputId = "dl_ml_ind_cat",
        choices = choices_ml_ind$cat,
        selected = selected)
    } else {
      allowed_categories <- choices_ml_ind$cat[!grepl("^T", choices_ml_ind$cat)]
      updateSelectizeInput(
        inputId = "dl_ml_ind_cat",
        choices = allowed_categories,
        selected = wlv_download_selection(selected, allowed_categories))
    }
    
  })
  
  aggregate_plan <- reactive({
    wlv_aggregated_download_plan(IP$dl_method, IP$dl_country, IP$dl_indicator,
      IP$dl_sector, countries = sea_countries, sectors = sea_sectors,
      metadata = meta_indicators, methods = meta_methods, contracts = meta_indicator_contracts)
  })
  multilateral_plan <- reactive({
    req(wlv_nonempty_selection(IP$dl_ml_method), wlv_nonempty_selection(IP$dl_ml_country))
    wlv_multilateral_download_plan(IP$dl_ml_method, IP$dl_ml_country,
      IP$dl_ml_partner, IP$dl_ml_ind_cat, IP$dl_ml_ind_scope, IP$dl_ml_ind_un,
      values = wlv_download_multilateral_data(), methods = meta_methods)
  })
  # These numeric reactives are lazy and independent of the selected language.
  # Showing a button evaluates only the plan; an actual click composes the XLSX.
  aggregate_data <- reactive(wlv_aggregated_download_data(aggregate_plan()))
  multilateral_data <- reactive(wlv_multilateral_download_data(multilateral_plan()))
  OP$dl_file <- wlv_request_download_handler(function()
    wlv_aggregated_download_localize(aggregate_data(), language_file, IP$l))
  OP$dl_ml_file <- wlv_request_download_handler(function()
    wlv_multilateral_download_localize(multilateral_data(), language_file, IP$l))
  OP$dl_download <- renderUI({
    available <- !is.null(aggregate_plan())
    awaiting <- !wlv_nonempty_selection(IP$dl_method) ||
      !(wlv_nonempty_selection(IP$dl_country) || wlv_nonempty_selection(IP$dl_indicator))
    wlv_download_action("", IP$l, "dl-download-status",
      download_id = if (available) "dl_file" else NULL, awaiting = awaiting)
  })
  OP$dl_ml_download <- renderUI({
    awaiting <- !(wlv_nonempty_selection(IP$dl_ml_method) && wlv_nonempty_selection(IP$dl_ml_country) &&
      (wlv_nonempty_selection(IP$dl_ml_partner) || (wlv_nonempty_selection(IP$dl_ml_ind_cat) &&
        wlv_nonempty_selection(IP$dl_ml_ind_scope) && wlv_nonempty_selection(IP$dl_ml_ind_un))))
    available <- !awaiting && !is.null(multilateral_plan())
    wlv_download_action("", IP$l, "dl-ml-download-status",
      download_id = if (available) "dl_ml_file" else NULL, awaiting = awaiting)
  })
}

modules_server[[length(modules_server) + 1L]] <- download_server
