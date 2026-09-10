### Global ####

# Colors for graphics lines
mycolors <- c('#E41A1C',
              '#377EB8',
              '#4DAF4A',
              '#984EA3',
              '#FF7F00',
              '#FFFF33',
              '#A65628',
              '#F781BF' )

# Format for y-axis in graphics. Values have already been converted to their
# display unit, so percent ticks receive only a suffix (not another x100).
tickf2s <- function(ind, method, lng) {
  type <- wlv_display_format_type(meta_indicator_contracts, method, ind)
  list(
    tickformat = if (identical(type, "percent")) ".3~f" else ".3s",
    tickprefix = if (identical(type, "usd")) "US$ " else "",
    ticksuffix = switch(
      type,
      percent = "%",
      value = "mv",
      hours = lb("hours", lng),
      ""
    )
  )
}

# Panel for graphics and "loading..."
graph_panel <- function(graph, graph_width, indicator, lng = default_language) {
  div(
    class = "wlv-country-chart panel panel-default",
    div(
      class = "wlv-country-chart-heading",
      actionLink(
        inputId = paste0(indicator, "_title"),
        label = lb(indicator, lng),
        class = "wlv-country-chart-select",
        title = wlv_tr("Ver composição por setor", "View sector breakdown", lng)
      ),
      actionLink(
        inputId = paste0(indicator, "_info"),
        label = tags$span(
          class = "sr-only",
          wlv_tr("Informações: ", "Information: ", lng),
          lb(indicator, lng)
        ),
        icon = icon("info-circle"),
        class = "wlv-country-chart-info"
      )
    ),
    graph
  )
}

# Labels describe display units only; numeric conversion stays in the contract.
country_axis_unit_label <- function(unit, lng = default_language) wlv_unit_label(unit, lng)

# Geographic groups follow the map metadata. Aggregate observations remain
# selectable even when they do not correspond to a country polygon.
wlv_country_regions <- local({
  geography <- rworldmap::getMap(resolution = "low")@data
  regions <- stats::setNames(as.character(geography$REGION), geography$ISO3)
  regions["MEX"] <- "North America" # The bundled source misclassifies Mexico.
  regions[regions == "Australia"] <- "Oceania"
  regions[c("ROW", "WWW")] <- "Aggregates"
  regions
})
wlv_country_region_order <- c("Africa", "North America", "South America", "Asia", "Europe", "Oceania", "Aggregates", "Other")

wlv_country_region_label <- function(region, lng = default_language) {
  labels <- c("Africa" = "África", "Asia" = "Ásia", "Europe" = "Europa",
              "North America" = "América do Norte", "South America" = "América do Sul",
              "Oceania" = "Oceania", "Aggregates" = "Agregados", "Other" = "Outros")
  wlv_tr(unname(labels[region]), region, lng)
}

wlv_country_search_fold <- function(text) {
  tolower(stringi::stri_trans_general(enc2utf8(text), "Latin-ASCII"))
}

wlv_country_search_label <- function(label, query) {
  query <- wlv_country_search_fold(trimws(query))
  if (!nzchar(query)) return(label)
  matches <- gregexpr(query, wlv_country_search_fold(label), fixed = TRUE)[[1L]]
  if (matches[[1L]] < 0L) return(label)
  position <- 1L
  pieces <- list()
  for (index in seq_along(matches)) {
    start <- matches[[index]]
    end <- start + attr(matches, "match.length")[[index]] - 1L
    if (start > position) pieces <- c(pieces, list(substr(label, position, start - 1L)))
    pieces <- c(pieces, list(tags$mark(substr(label, start, end))))
    position <- end + 1L
  }
  if (position <= nchar(label)) pieces <- c(pieces, list(substr(label, position, nchar(label))))
  do.call(tagList, pieces)
}



### UI ####

source("modules/country/landing.R", encoding = "UTF-8")

# This is an ordinary page: country selection is independent of the map, and
# navigation, charts, comparisons and sector tables stay in the document flow.
country_panel <- tags$main(
  id = "wlv-country-page",
  class = "wlv-country-page wlv-explore-page",
  `aria-labelledby` = "country_page_title",
  htmltools::includeCSS("www/wlv-country.css"),
  htmltools::includeScript("www/wlv-country.js"),
  div(class = "wlv-explore-content",
  tags$header(class = "wlv-country-page-heading wlv-explore-heading", tags$h1(id = "country_page_title", l("tab_name.country"))),
  wlv_country_landing_ui(),
  conditionalPanel(
    "output.show_country_panel != '' && output.co_entry_expanded == 'true'",
    id = "wlv-country-content",
  div(
    id = "wlv-country-detail",
    class = "wlv-country-detail",
    role = "region",
    `aria-labelledby` = "co_panel_title",
    tabindex = "-1",
    div(
      class = "wlv-country-header",
      div(
        class = "wlv-country-heading",
        actionButton("co_catalogue_back", "Voltar à visão geral", icon = icon("arrow-up")),
        tags$h2(textOutput("co_panel_title", inline = TRUE))
      ),
      div(
        class = "wlv-country-year",
        sliderInput(
          "co_panel_year", label = textOutput("co_panel_year_label", inline = TRUE),
          min = 1995, max = 2016, value = default_year,
          ticks = FALSE, animate = FALSE, sep = ""
        )
      )
    ),
    div(
      class = "wlv-country-body",
      div(class = "wlv-country-main",
      div(
        class = "wlv-country-overview",
        div(
          class = "wlv-country-profile panel panel-default",
          div(class = "panel-heading", tags$h3(textOutput("co_panel_profile_label", inline = TRUE))),
          div(class = "wlv-country-table-scroll", dataTableOutput("co_panel_profile"))
        ),
        div(
          class = "wlv-country-downloads panel panel-default",
          div(class = "panel-heading", tags$h3(l("tab_name.download"))),
          div(class = "wlv-country-download-list",
            div(
              class = "wlv-country-download-block",
              tags$h4(icon("flag"), l("co_panel_download_country")),
              uiOutput("country_link", class = "wlv-country-download-links")
            ),
            div(
              class = "wlv-country-download-block",
              tags$h4(icon("chart-pie"), l("co_panel_download_sector")),
              uiOutput("sector_data_link", class = "wlv-country-download-links")
            )
          )
        )
      ),
        div(
          class = "wlv-country-series",
          lapply(seq_along(groups), function(group_index) {
            group <- groups[[group_index]]
            content_id <- paste0("wlv-country-group-", group_index)
            tags$section(
              class = "wlv-country-group",
              tags$h3(
                class = "wlv-country-group-heading",
                tags$button(
                  id = paste0(content_id, "-toggle"), type = "button",
                  class = "wlv-country-group-toggle collapsed",
                  `data-toggle` = "collapse", `data-target` = paste0("#", content_id),
                  `aria-controls` = content_id, `aria-expanded` = "false",
                  icon("chevron-right", class = "wlv-country-group-chevron"),
                  l(paste0("group.", group))
                )
              ),
              div(
                id = content_id, class = "wlv-country-group-content collapse",
                `aria-labelledby` = paste0(content_id, "-toggle"),
                `aria-hidden` = "true", inert = "",
                div(
                  class = "wlv-country-chart-grid",
                  lapply(meta_indicators$value[meta_indicators$groups == group], function(indicator) {
                    uiOutput(paste0(indicator, "_plot"), class = "wlv-country-chart-slot")
                  })
                )
              )
            )
          })
        )
      ),
        tags$section(
          id = "wlv-country-sectors",
          class = "wlv-country-sectors panel panel-default",
          tabindex = "-1",
          div(
            class = "panel-heading",
            tags$h3(l("co_panel_sector_title"))
          ),
          div(
            class = "panel-body",
            selectInput(
              "co_panel_sector_select",
              label = textOutput("co_panel_sector_select_label", inline = TRUE),
              choices = character(), width = "100%"
            ),
            uiOutput("co_sector_panel", class = "wlv-country-sector-tabs")
          )
        )
    )
  )))
)

# Country charts are rendered concurrently. Put their shared core in the
# initial document so no widget runs before the first dynamic bundle finishes.
country_panel <- htmltools::attachDependencies(
  country_panel,
  plotly::plotly_build(plotly::plot_ly(type = "scatter", mode = "lines"))$dependencies,
  append = TRUE
)

country_panel <- tagList(country_panel,
  tags$script(HTML("
    $(function () {
      function visible(element) { return !!element && element.getClientRects().length > 0; }
      function showSectors(event) {
        event.preventDefault();
        var sector = document.getElementById('wlv-country-sectors');
        sector.scrollIntoView({behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start'});
        sector.focus({preventScroll: true});
      }
      $(document).on('click', '.wlv-country-sector-jump', showSectors);
      $(document).on('click', '.wlv-country-chart-select', function (event) {
        if (window.matchMedia('(max-width: 900px)').matches) showSectors(event);
      });
      $(document).on('keydown.wlvCountry', function (event) {
        var info = document.getElementById('wlv-country-info');
        if (event.key === 'Escape' && !event.isDefaultPrevented()) {
          if (visible(info)) document.getElementById('info_close_button').click();
        }
        if (event.key === 'Tab' && visible(info)) {
          var focusable = Array.from(info.querySelectorAll('a[href],button,input,select,textarea,[tabindex]'))
            .filter(function (item) { return item.tabIndex >= 0 && !item.disabled && visible(item); });
          var first = focusable[0], last = focusable[focusable.length - 1];
          if (event.shiftKey && (document.activeElement === first || !info.contains(document.activeElement))) {
            event.preventDefault(); last.focus();
          } else if (!event.shiftKey && (document.activeElement === last || !info.contains(document.activeElement))) {
            event.preventDefault(); first.focus();
          }
        }
      });
      var info = document.getElementById('wlv-country-info-overlay');
      var infoFocus = null;
      var infoWasVisible = visible(info);
      if (info) new MutationObserver(function () {
        var infoIsVisible = visible(info);
        if (infoIsVisible === infoWasVisible) return;
        infoWasVisible = infoIsVisible;
        if (infoIsVisible) {
          infoFocus = document.activeElement;
          requestAnimationFrame(function () { document.getElementById('info_close_button').focus(); });
        } else if (infoFocus && visible(infoFocus)) infoFocus.focus({preventScroll: true});
      }).observe(info, {attributes: true, attributeFilter: ['style', 'class', 'hidden']});
    });
  "))
)

co_info_panel <- conditionalPanel(
  # Antes da primeira resposta do servidor, o output ainda é undefined.
  # Abra somente para o estado explícito enviado por renderText().
  "output.show_info_panel === '1'",
  id = "wlv-country-info-overlay",
  class = "wlv-country-info-overlay",
  div(
    id = "wlv-country-info",
    class = "wlv-country-info panel panel-default",
    role = "dialog",
    `aria-modal` = "true",
    `aria-labelledby` = "co_info_indicator",
    div(
      class = "panel-heading",
      tags$h3(textOutput("co_info_indicator", inline = TRUE)),
      actionButton(
        "info_close_button",
        label = tags$span(class = "sr-only", textOutput("co_info_close_label", inline = TRUE)),
        icon = icon("times"), class = "wlv-country-close"
      )
    ),
    div(class = "panel-body", uiOutput("co_info_text"))
  )
)
### Server ####

country_panel_server <-  function(IP, OP, RV, SESSION) {
  OP$co_panel_year_label <- renderText(wlv_tr("Ano de referência", "Reference year", IP$l))
  OP$co_panel_profile_label <- renderText(wlv_tr("Perfil do país", "Country profile", IP$l))
  OP$co_panel_sector_select_label <- renderText(wlv_tr("Indicador por setor", "Indicator by sector", IP$l))
  OP$co_info_close_label <- renderText(wlv_tr("Fechar informações", "Close information", IP$l))
  
  ## Country controls are independent of map filters and its drawing lifecycle.
  country_availability <- reactive({
    methods <- intersect(RV$bases(), dimnames(sea_countries)[[1L]])
    req(length(methods))
    data <- sea_countries[methods, , , , drop = FALSE]
    countries <- dimnames(data)[[4L]][apply(data, 4L, function(x) any(!is.na(x)))]
    years <- as.numeric(dimnames(data)[[2L]][apply(data, 2L, function(x) any(!is.na(x)))])
    req(length(countries), length(years))
    list(countries = countries, years = years)
  })
  observe({
    countries <- country_availability()$countries
    current <- isolate(IP$co_select_country)
    fallback <- if ("BRA" %in% countries) "BRA" else countries[[1L]]
    selected <- if (is.null(current) || !length(current)) {
      fallback
    } else if (current %in% countries) {
      current
    } else {
      fallback
    }
    labels <- lb(paste0("ISO3.", countries), IP$l)
    choices <- stats::setNames(countries, labels)
    choices <- choices[order(labels)]
    updateSelectizeInput(
      SESSION, "co_select_country", label = wlv_tr("País", "Country", IP$l),
      choices = choices, selected = selected,
      server = FALSE,
      options = list(placeholder = lb("co_select_country.placeholder", IP$l))
    )
  })
  catalogue_countries <- reactive({
    codes <- country_availability()$countries
    regions <- unname(wlv_country_regions[codes])
    regions[is.na(regions) | !nzchar(regions)] <- "Other"
    labels <- lb(paste0("ISO3.", codes), IP$l)
    rows <- data.frame(code = codes, label = labels, region = regions, stringsAsFactors = FALSE)
    rows[order(rows$label), , drop = FALSE]
  })
  observe({
    regions <- intersect(wlv_country_region_order, unique(catalogue_countries()$region))
    labels <- wlv_country_region_label(regions, IP$l)
    region <- isolate(IP$co_catalogue_region)
    if (!length(region) || !region %in% regions) region <- ""
    choices <- stats::setNames(regions, labels)
    updateSelectInput(SESSION, "co_catalogue_region", label = wlv_tr("Continente", "Continent", IP$l),
      choices = c(stats::setNames("", wlv_tr("Todos os continentes", "All continents", IP$l)), choices), selected = region)
    updateTextInput(SESSION, "co_catalogue_search", label = wlv_tr("Buscar país", "Search countries", IP$l))
    updateActionButton(SESSION, "co_catalogue_back", label = wlv_tr("Voltar à visão geral", "Back to overview", IP$l))
  })
  OP$co_country_catalogue <- renderUI({
    rows <- catalogue_countries()
    region <- IP$co_catalogue_region
    query <- trimws(if (is.null(IP$co_catalogue_search)) "" else IP$co_catalogue_search)
    if (length(region) && nzchar(region)) rows <- rows[rows$region == region, , drop = FALSE]
    if (nzchar(query)) rows <- rows[grepl(wlv_country_search_fold(query), wlv_country_search_fold(rows$label), fixed = TRUE), , drop = FALSE]
    if (!nrow(rows)) return(div(class = "wlv-country-empty panel panel-default", role = "status",
      wlv_tr("Nenhum país encontrado.", "No countries found.", IP$l)))
    regions <- intersect(wlv_country_region_order, unique(rows$region))
    div(class = "wlv-country-catalogue-groups", lapply(regions, function(region) {
      countries <- rows[rows$region == region, , drop = FALSE]
      tags$section(class = "wlv-country-catalogue-group panel panel-default",
        tags$h2(class = "panel-heading", wlv_country_region_label(region, IP$l)),
        tags$ul(class = "wlv-country-catalogue-list", lapply(seq_len(nrow(countries)), function(index) {
          tags$li(tags$button(type = "button", class = "wlv-country-catalogue-link",
            `data-wlv-country` = countries$code[[index]],
            wlv_country_search_label(countries$label[[index]], query),
            icon("arrow-right", class = "wlv-country-catalogue-arrow", `aria-hidden` = "true")))
        }))
      )
    }))
  })
  observeEvent(IP$co_catalogue_country, {
    country <- IP$co_catalogue_country
    if (length(country) == 1L && country %in% country_availability()$countries) {
      updateSelectizeInput(SESSION, "co_select_country", selected = country)
    }
  }, ignoreInit = TRUE)
  show_country_panel <- reactive({
    country <- IP$co_select_country
    if (wlv_nonempty_selection(country) && country %in% country_availability()$countries) country else ""
  })
  co_panel_sector_indicator <- reactiveVal(default_indicator)
  co_panel_year <- reactiveVal(default_year)
  OP$show_country_panel <- renderText(show_country_panel())
  outputOptions(OP,"show_country_panel", suspendWhenHidden = FALSE)
  wlv_country_landing_server(IP, OP, RV, SESSION, country_availability, show_country_panel)
  
  ## Change input controls accordingly bases selected in setup panel ####
  observe({
    year_max <- max(country_availability()$years)
    year_min <- min(country_availability()$years)
    req(length(year_min) == 1L, length(year_max) == 1L)
    year <- suppressWarnings(as.numeric(co_panel_year()))
    if (length(year) != 1L || !is.finite(year)) year <- default_year
    year <- max(year_min, min(year_max, year))
    updateSliderInput(
      inputId = "co_panel_year",
      max = year_max,
      min = year_min,
      value = year)
  })
  observeEvent(IP$co_panel_year, co_panel_year(IP$co_panel_year))

  observe({
    methods <- RV$bases()
    indicators <- meta_indicators$value[vapply(
      meta_indicators$value,
      function(indicator) length(wlv_methods_with_indicator(
        method_indicator_availability, methods, indicator
      )) > 0L,
      logical(1L)
    )]
    selected <- co_panel_sector_indicator()
    if (!length(selected) || !selected %in% indicators) {
      selected <- if (default_indicator %in% indicators) default_indicator else indicators[1L]
      if (length(selected) && !is.na(selected)) co_panel_sector_indicator(selected)
    }
    updateSelectInput(
      SESSION, "co_panel_sector_select",
      choices = stats::setNames(indicators, lb(indicators, IP$l)),
      selected = selected
    )
  })
  observeEvent(IP$co_panel_sector_select, {
    if (wlv_nonempty_selection(IP$co_panel_sector_select)) {
      co_panel_sector_indicator(IP$co_panel_sector_select)
    }
  })
  
  ## Graph panel ####
  # create uiOutput with graphs for all indicators
  lapply(meta_indicators$value, \(indicator) {
    OP[[paste0(indicator,"_plot")]] <- renderUI({
      country <- IP$co_select_country
      # An empty selection preserves hidden widgets until a country is chosen.
      req(wlv_nonempty_selection(country), cancelOutput = TRUE)
      # reactive data
      selected_methods <- RV$bases()
      year_max <- max(country_availability()$years)
      year_min <- min(country_availability()$years)
      lng <- IP$l
      graph_width <- 375

      methods <- wlv_methods_with_indicator(
        method_indicator_availability,
        selected_methods,
        indicator
      )
      if (!length(methods)) return()
      
      # get data
      years <- year_min:year_max
      canonical_data <- sea_countries[
        methods,
        years |> as.character(),
        indicator,
        country,
        drop = FALSE
      ]

      comparable_unit <- tryCatch(
        wlv_assert_comparable_display_units(
          methods,
          indicator,
          meta_indicator_contracts
        ),
        wlv_incompatible_display_units = identity
      )
      if (inherits(comparable_unit, "wlv_incompatible_display_units")) {
        graph <- div(
          class = "alert alert-warning",
          style = paste0(
            "height: 220px; margin: 0px; padding: 55px 15px;",
            "text-align: center;"
          ),
          tags$strong(wlv_tr("Unidades de apresentação incompatíveis", "Incompatible display units", lng)),
          tags$br(),
          conditionMessage(comparable_unit)
        )
        return(graph_panel(graph, graph_width, indicator, lng))
      }

      data <- matrix(
        NA_real_,
        nrow = length(methods),
        ncol = length(years),
        dimnames = list(methods, as.character(years))
      )
      for (x in seq_along(methods)) {
        data[x, ] <- wlv_display_values(
          as.numeric(canonical_data[methods[x], , indicator, country]),
          methods[x],
          indicator,
          meta_indicator_contracts
        )
      }

      # NULL if has no data
      if (!any(!is.na(data))) return()
      
      # labels for axis x
      break_years <- unique(years[round(seq(1, length(years), length.out = min(4L, length(years))))])
      
      # Initialize graph area
      axis_format <- tickf2s(indicator, methods[[1L]], lng)
      graph <- plot_ly(
        type = "scatter",
        mode = "lines+markers",
        marker = list(size = 5, line = list(color = "white", width = 2.5)),
        hoverinfo = "text+x",
        height = 220) |>
        plotly::layout(hovermode = "x", autosize = TRUE,
               font = list(family = "'Source Sans 3', sans-serif", color = "#292B2E"),
               separators = paste0(lb("decimal.mark", lng), lb("big.mark", lng)),
               xaxis = list(title = "",
                            showgrid = FALSE,
                            range = c(year_min, year_max),
                            tickvals = break_years),
               yaxis = list(title = country_axis_unit_label(comparable_unit, lng),
                            showgrid = FALSE,
                            zeroline = TRUE,
                            zerolinecolor = "#E6E6E6",
                            zerolinewidth = 1,
                            tickformat = axis_format$tickformat,
                            tickprefix = axis_format$tickprefix,
                            ticksuffix = axis_format$ticksuffix),
               legend = list(title = "", 
                             orientation = "h", 
                             y="-0.1", 
                             x="-0.1",
                             font = list(size = "10")),
               margin = list(l = 48, t = 6, r = 12, b = 50, pad = 0)) |>
        wlv_plotly_config(lng, displaylogo = FALSE,
               displayModeBar = FALSE,
               responsive = TRUE)
      
      # add methods trace
      for (x in seq_along(methods)) {
        text_data <- data[x,]
        if (any(!is.na(text_data))) {
          text_data <- list_display_f2s(
            text_data,
            indicator,
            methods[x],
            lng
          )
          graph <- graph |>
            add_trace(
              x = years,
              y = data[x,],
              text = text_data,
              name = methods[x],
              color = I(mycolors[match(methods[x], selected_methods)]))
        }
      }

      # Indicator Graph Panel
      graph_panel(graph, graph_width, indicator, lng)
    }) %>%bindCache(
      indicator,
      RV$bases(),
      min(country_availability()$years),
      max(country_availability()$years),
      IP$l,
      lb(c(indicator, "hours", "big.mark", "decimal.mark"), IP$l),
      IP$co_select_country,
      display_contract_version
    )
  
    observeEvent(IP[[paste0(indicator,"_info")]],{
      co_info_indicator(indicator)
      show_info_panel(1)
    })
    
    observeEvent(IP[[paste0(indicator,"_title")]], ignoreInit = TRUE, {
      co_panel_sector_indicator(indicator)
    })
  })  
  
  ## Info Panel ####
  # Open/close system for info_panel
  show_info_panel <- reactiveVal(0)
  OP$show_info_panel <- renderText(show_info_panel())
  outputOptions(OP,"show_info_panel", suspendWhenHidden = FALSE)
  observeEvent(IP$info_close_button, show_info_panel(0))
  observeEvent(IP$main_nav, {
    if (!identical(IP$main_nav, "country")) show_info_panel(0)
  })

  # Select indicator
  co_info_indicator <- reactiveVal("")
  OP$co_info_indicator <- renderText({
    lng <- IP$l
    indicator <- co_info_indicator()
    lb(indicator,lng)})
  
  # Indicator informations
  OP$co_info_text <- renderUI({
    lng <- IP$l
    indicator <- co_info_indicator()
    methods <- RV$bases()
    
    # merge observations from all methods
    temp_obs <- lb(paste0("obs.",methods,".",indicator), lng)
    temp_obs[temp_obs |> is.na()] <- ""
    if (temp_obs |> unique() |> length() == 1){
      observations <- temp_obs[1]
    } else {
      observations <- paste0(methods,": ", temp_obs, collapse = "; ")
    }
    
    tagList(
      p(strong(lb("co_info_Description", lng)),
        lb(paste0("desc.",indicator), lng),
        style = "text-align: justifY;"),
      p(strong(lb("co_info_Observations", lng)),
        observations,
        style = "text-align: justifY;"))
  })
  
  ## Profile Panel ####
  
  # Title
  OP$co_panel_title <- renderText(lb(paste0("ISO3.",IP$co_select_country), IP$l))
  outputOptions(OP,"co_panel_title", suspendWhenHidden = FALSE)
  
  # Table
  OP$co_panel_profile <- renderDataTable({
    # Reactive data
    methods <- RV$bases()
    country <- IP$co_select_country
    year <- IP$co_panel_year |> as.character()
    lng <- IP$l
    
    # DT cannot render NULL into a hidden container (it reads data.lazyRender
    # before checking for NULL). Preserve the widget for an empty selection.
    req(
      wlv_nonempty_selection(country), length(year) == 1L,
      year %in% dimnames(sea_countries)[[2L]], cancelOutput = TRUE
    )
    
    # create table with profile data
    profile_table <- methods |> as.data.frame(row.names = methods)
    for (i in profile_indicators) {
      canonical_values <- sea_countries[methods, year, i, country]
      indicator_methods <- wlv_methods_with_indicator(
        method_indicator_availability,
        methods,
        i
      )
      profile_table[[i]] <- vapply(
        seq_along(methods),
        function(method_index) {
          method <- methods[[method_index]]
          if (!method %in% indicator_methods) {
            return("-")
          }
          as.character(f2s(
            canonical_values[[method_index]],
            i,
            method,
            lng
          ))
        },
        character(1L)
      )
    }
    profile_table <- profile_table[,-1] |> t()
    rownames(profile_table) <- lb(profile_indicators, lng)
    
    profile_table |> datatable(
      rownames = TRUE,
      class = "profile_table",
      options = list(
        ordering = FALSE,
        searching = FALSE,
        paging = FALSE,
        columnDefs = list(
          list(className = 'dt-right', targets = c(1:length(methods))),
          list(className = 'dt-left', targets = 0)),
        info = FALSE,
        lengthChange = FALSE))
  }, server = FALSE)
  outputOptions(OP,"co_panel_profile", suspendWhenHidden = FALSE)
  
  ## Download links ####
  # A language-independent selection plan enables each link. Export matrices
  # and translated workbook metadata are composed only after an actual click.
  country_download_plans <- reactive({
    methods <- RV$bases()
    country <- IP$co_select_country
    if (!wlv_nonempty_selection(country)) return(list())
    stats::setNames(lapply(methods, function(method) {
      wlv_aggregated_download_plan(
        method, country = country, countries = sea_countries, sectors = sea_sectors,
        metadata = meta_indicators, methods = meta_methods, contracts = meta_indicator_contracts
      )
    }), methods)
  })
  sector_download_plans <- reactive({
    methods <- RV$bases()
    country <- IP$co_select_country
    indicator <- co_panel_sector_indicator()
    if (!wlv_nonempty_selection(country) || !wlv_nonempty_selection(indicator)) return(list())
    stats::setNames(lapply(methods, function(method) {
      wlv_aggregated_download_plan(
        method, country = country, indicator = indicator, countries = sea_countries,
        sectors = sea_sectors, metadata = meta_indicators, methods = meta_methods,
        contracts = meta_indicator_contracts
      )
    }), methods)
  })
  download_links <- function(requests, prefix) {
    available <- names(requests)[!vapply(requests, is.null, logical(1L))]
    if (!length(available)) return(tags$span(
      class = "wlv-country-download-empty",
      wlv_tr("Nenhum arquivo disponível para esta seleção.", "No file available for this selection.", IP$l)
    ))
    do.call(tagList, lapply(available, function(method) {
      downloadLink(
        paste0(prefix, method), tagList(icon("download"), method),
        class = "wlv-country-download-link"
      )
    }))
  }
  OP$country_link <- renderUI(download_links(country_download_plans(), "co_country_file_"))
  OP$sector_data_link <- renderUI(download_links(sector_download_plans(), "co_sector_file_"))
  outputOptions(OP,"country_link", suspendWhenHidden = FALSE)
  outputOptions(OP,"sector_data_link", suspendWhenHidden = FALSE)
  lapply(meta_methods$code, function(method) {
    country_data <- reactive(wlv_aggregated_download_data(country_download_plans()[[method]]))
    sector_data <- reactive(wlv_aggregated_download_data(sector_download_plans()[[method]]))
    OP[[paste0("co_country_file_", method)]] <- wlv_request_download_handler(function()
      wlv_aggregated_download_localize(country_data(), language_file, IP$l))
    OP[[paste0("co_sector_file_", method)]] <- wlv_request_download_handler(function()
      wlv_aggregated_download_localize(sector_data(), language_file, IP$l))
  })
  
  ## Sector table ####
  OP$co_panel_sector_indicator <- renderText({
    lng <- IP$l
    indicator <- co_panel_sector_indicator()
    lb(indicator,lng)})
  outputOptions(OP, "co_panel_sector_indicator", suspendWhenHidden = FALSE)
  OP$co_panel_year_text <- renderText(IP$co_panel_year)

  # TabsetPanel
  OP$co_sector_panel <- renderUI({
    country <- IP$co_select_country
    req(wlv_nonempty_selection(country), cancelOutput = TRUE)
    methods <- RV$bases()
    do.call("tabsetPanel", c(
      list(id = "co_panel_sector_method"),
      lapply(methods, function(method) {
        tabPanel(method, dataTableOutput(paste0("co_panel_sector_", method)), value = method)
      })
    ))
  })

  # Each TabPanel
  lapply(meta_methods$code, function(method){
    OP[[paste0("co_panel_sector_",method)]] <- renderDataTable({
        lng <- IP$l
        year <- IP$co_panel_year |> as.character()
        country <- IP$co_select_country
        indicator <- co_panel_sector_indicator()
        
        temp_sectors <- sea_sectors[[method]]
        req(
          wlv_nonempty_selection(country), wlv_nonempty_selection(indicator),
          length(year) == 1L, cancelOutput = TRUE
        )
        if (year %in% names(temp_sectors[,1,1,1]) &
            country %in% names(temp_sectors[1,1,1,]) &
            indicator %in% names(temp_sectors[1,,1,1])) {
          canonical_sectors <- temp_sectors[year, indicator, , country]
          mydt <- vapply(
            canonical_sectors,
            function(value) {
              as.character(f2s(value, indicator, method, lng))
            },
            character(1L)
          )
        } else {
          mydt <- rep("-", times = temp_sectors[1,1,,1] |> length())
        }
        names(mydt) <-
          lb(paste0(meta_methods$source[meta_methods$code==method],
                    ".",names(temp_sectors[1,1,,1])), lng)
        
        mydt |> as.data.frame() |> datatable(
          rownames = TRUE,
          colnames = c(""),
          width = "100%",
          fillContainer = FALSE,
          options = list(
            ordering = TRUE,
            class = "compact",
            searching = FALSE,
            paging = FALSE,
            scrollY = "50vh",
            scrollCollapse = TRUE,
            info = FALSE,
            columnDefs = list(list(className = 'text-nowrap', targets = 1)),
            lengthChange = FALSE))
    }, server = FALSE)
  })

}
