### Module: Download
# Description: download country data; multilateral data; and source code.

## Global #####

middle_bold_bottom <- paste0("vertical-align: middle;",
                             "padding-bottom: 15px;",
                             "padding-right: 10px;",
                             "font-weight: bold;")

panels_width <- paste0("width: calc(100vw - 40px);")

## UI ####

TABPANEL <- tabPanel(
  l("tab_name.download"),
  absolutePanel(
    top = bar_height,
    left = 0,
    right = 0,
    style = paste0("margin:0px !important;",
                   "height: calc(100vh - ",bar_height,"px);",
                   "overflow-y:scroll;",
                   "padding: 10px;",
                   "background-color: ",panel_bgcolor,";"),
    
    ### Panel for download of aggregated data ####
    div(
      style = panels_width,
      class="panel panel-default",
      div(class = "panel-heading", l("dl_agg_title") |> strong()),
      div(
        class = "panel-body",
        
        
        #### Method Selector ####
        withTags(
          table(
            tr(
              td(
                style = middle_bold_bottom,
                l("dl_select_method.label")
              ),
              td(
                selectizeInput(
                  "dl_method",
                  label = NULL,
                  choices = NULL)
              )
            )
          )
        ),
        
        # Only show others selectors if a method is selected
        conditionalPanel(
          "input.dl_method != ''",
          tags$hr(style = "margin-top: 0px !important;"),
          
          
          #### Indicator, country and sector selectors ####
          withTags(
            table(
              ##### Indicator Selector ####
              tr(
                td(
                  style = middle_bold_bottom,
                  l("dl_select_indicator.label")
                ),
                td(
                  style(HTML("#dl_indicator + div>.selectize-dropdown{width: 500px !important;}")),
                  selectizeInput(
                    "dl_indicator",
                    label = NULL,
                    choices = NULL,
                    options = list(
                      optgroupField = "groups",
                      render = I("{option: function(item, escape) {
                      return '<div style=\"padding-left: 3em;text-indent:-1em; color: black;\">' + escape(item.label) +'</div>';}
                  }"))
                  )
                )
              ),
              tr(
                td(
                  colspan = 2,
                  style = paste0("vertical-align: middle;",
                                 "padding-bottom: 15px;",
                                 "text-align: center;",
                                 "font-weight: bold;"),
                  l("dl_select_andor")
                )
              ),
              
              ##### Country Selector ####
              tr(
                td(
                  style = middle_bold_bottom,
                  l("dl_select_country.label")
                ),
                td(
                  selectizeInput(
                    "dl_country",
                    label = NULL,
                    choices = NULL
                  )
                ),
                
                ##### Sector Selector ####
                td(
                  style = paste0(middle_bold_bottom,
                                 "padding-left: 10px;"),
                  conditionalPanel(
                    "input.dl_indicator != ''",
                    l("dl_select_sector_indicator.label") |> strong()),
                  conditionalPanel(
                    "input.dl_indicator == '' &
                      input.dl_country != ''",
                    l("dl_select_sector_country.label") |> strong())
                ),
                td(
                  conditionalPanel(
                    "input.dl_indicator != '' |
                   input.dl_country != ''",
                    style(HTML("#dl_sector + div>.selectize-dropdown{width: 500px !important;}")),
                    selectizeInput(
                      "dl_sector",
                      label = NULL,
                      choices = NULL
                    )
                  )
                )
              )
            )
          )
        ),
        
        #### Download button ####
        uiOutput("dl_download")
      )
    ),
    
    ### Panel for download of multilateral data ####
    div(
      style = panels_width,
      class="panel panel-default",
      div(class = "panel-heading", l("dl_ml_title") |> strong()),
      div(
        class = "panel-body",
        
        #### Method Selector ####
        withTags(
          table(
            tr(
              td(
                style = middle_bold_bottom,
                l("dl_ml_select_method.label")
              ),
              td(
                selectizeInput(
                  "dl_ml_method",
                  label = NULL,
                  choices = NULL)
              )
            )
          )
        ),
        
        # Only show country selector if a method is selected
        conditionalPanel(
          "input.dl_ml_method != ''",
          tags$hr(style = "margin-top: 0px !important;"),
          
          #### Country selector ####
          withTags(
            table(
              tr(
                td(
                  style = middle_bold_bottom,
                  l("dl_ml_select_country.label")
                ),
                td(
                  selectizeInput(
                    "dl_ml_country",
                    label = NULL,
                    choices = NULL
                  )
                )
              )
            )
          ),
          
          # Only show other selectors if a country is selected
          conditionalPanel(
            "input.dl_ml_country != ''",
            tags$hr(style = "margin-top: 0px !important;"),
            
            #### Partner and Indicator selectors ####
            withTags(
              table(
                tr(
                  td(
                    colspan = 2,
                    style = middle_bold_bottom,
                    l("dl_ml_select_and")
                  )
                ),

                ##### Partner selector ####
                tr(
                  td(
                    style = middle_bold_bottom,
                    l("dl_ml_select_partner.label")
                  ),
                  td(
                    selectizeInput(
                      "dl_ml_partner",
                      label = NULL,
                      choices = NULL
                    )
                  )
                )
              )
            ),
            
            ##### Indicator selector ####
            withTags(
              table(
                tr(
                  td(
                    style = middle_bold_bottom,
                    l("dl_ml_select_indicator.label")
                  ),
                  td(
                    style = "padding-right: 5px;",
                    selectizeInput(
                      "dl_ml_ind_cat",
                      label = NULL,
                      choices = NULL,
                      width = 250
                    )
                  ),
                  td(
                    style = "padding-right: 5px;",
                    selectizeInput(
                      "dl_ml_ind_scope",
                      label = NULL,
                      choices = NULL,
                      width = 250
                    )
                  ),
                  td(
                    selectizeInput(
                      "dl_ml_ind_un",
                      label = NULL,
                      choices = NULL,
                      width = 250
                    )
                  )
                )
              )
            )
          )
        ),
        
        #### Download button ####
        uiOutput("dl_ml_download")
      )
    ),
    
    ### Panel for download of multilateral data ####
    div(
      style = panels_width,
      class="panel panel-default",
      div(class = "panel-heading", l("dl_source_title") |> strong()),
      div(
        class = "panel-body",
        l("dl_source_portable_msg"),
        a(href = "https://github.com/rodrigofranklin/wlvdb/archive/refs/heads/master.zip",
          target="_blank",
          "[LINK]"),
        tags$br(),
        l("dl_source_code_msg"),
        a(href = "https://github.com/rodrigofranklin/wlvdb",
          target="_blank",
          "[LINK]")
      )
    )
  )
)

modules_ui[[modules_ui |> length() +1]] <- TABPANEL

## Server ####

SERVER <- function(IP, OP, RV, SESSION) {
  
  choices_ml_ind <- reactiveValues()

  # Fill methods and multilateral indicators
  observe({
    methods <- RV$bases()
    lng <- IP$l

    updateSelectizeInput(
      inputId = "dl_method",
      choices = methods,
      server = FALSE, # needed for placeholder to work...
      options = list(
        placeholder = lb("dl_select_method.placeholder", lng),
        onInitialize = I('function() { this.setValue(""); }')
      )
    )

    updateSelectizeInput(
      inputId = "dl_ml_method",
      choices = methods,
      server = FALSE, # needed for placeholder to work...
      options = list(
        placeholder = lb("dl_select_method.placeholder", lng),
        onInitialize = I('function() { this.setValue(""); }')
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
    updateSelectizeInput(
      inputId = "dl_ml_ind_cat",
      choices = choices_ml_ind_cat)
    
    choices_ml_ind_scope <- c("", "T.", "P.", "U.")
    names(choices_ml_ind_scope) <- c(
      lb("dl_ml_ind_scope_placeholder", lng),
      lb("dl_ml_ind_T", lng),
      lb("dl_ml_ind_P", lng),
      lb("dl_ml_ind_U", lng))
    choices_ml_ind$scope <- choices_ml_ind_scope
    updateSelectizeInput(
      inputId = "dl_ml_ind_scope",
      choices = choices_ml_ind_scope)
    
    choices_ml_ind_un <- c("", "MP", "DP", "MV")
    names(choices_ml_ind_un) <- c(
      lb("dl_ml_ind_un_placeholder", lng),
      lb("dl_ml_ind_MP", lng),
      lb("dl_ml_ind_DP", lng),
      lb("dl_ml_ind_MV", lng))
    choices_ml_ind$un <- choices_ml_ind_un
    updateSelectizeInput(
      inputId = "dl_ml_ind_un",
      choices = choices_ml_ind_un)
    
  })
  
  # Selector's behaviour
  observeEvent(IP$dl_method,{
    method <- IP$dl_method
    lng <- IP$l
    selected_country <- IP$dl_country |> isolate()
    selected_indicator <- IP$dl_indicator |> isolate()
    selected_sector <- IP$dl_sector |> isolate()
    
    
    req(method)

    temp_data <- sea_countries[method,,,, drop = FALSE]

    countries <- wlv_observed_axis_labels(temp_data, 4L)
    indicators <- wlv_observed_axis_labels(temp_data, 3L)

    names(countries) <- lb(paste0("ISO3.",countries), lng)
    countries <- countries[order(names(countries))]
    
    updateSelectizeInput(
      inputId = "dl_country",
      choices = countries,
      server = FALSE, # needed for placeholder to work...
      selected = selected_country,
      options = list(
        placeholder = lb("dl_select_country.placeholder", lng),
        onInitialize = I('function() { this.setValue(""); }')
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
      selected = selected_indicator,
      options = list(
        placeholder = lb("co_select_indicator.placeholder", lng)))
    
    sectors <- names(sea_sectors[[method]][1,1,,1])
    names(sectors) <- lb(paste0(meta_methods$source[meta_methods$code==method],
                                ".",sectors),lng)
    
    updateSelectizeInput(
      inputId = "dl_sector",
      choices = sectors,
      server = FALSE,
      selected = selected_sector,
      options = list(
        placeholder = lb("dl_select_sector.placeholder", lng),
        onInitialize = I('function() { this.setValue(""); }')
      ))
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

  observeEvent(IP$dl_ml_method,{
    method <- IP$dl_ml_method
    lng <- IP$l
    choices <- choices_ml_ind
    selected_country <- IP$dl_ml_country |> isolate()
    selected_partner <- IP$dl_ml_partner |> isolate()
    
    req(method)
    
    countries <- sea_sectors[[method]][1,1,1,] |> names()
    names(countries) <- lb(paste0("ISO3.",countries), lng)
    countries <- countries[order(names(countries))]
    
    updateSelectizeInput(
      inputId = "dl_ml_country",
      choices = countries,
      server = FALSE, # needed for placeholder to work...
      selected = selected_country,
      options = list(
        placeholder = lb("dl_select_country.placeholder", lng),
        onInitialize = I('function() { this.setValue(""); }')
      ))
    
    updateSelectizeInput(
      inputId = "dl_ml_partner",
      choices = countries,
      server = FALSE,
      selected = selected_partner,
      options = list(
        placeholder = lb("dl_select_country.placeholder", lng),
        onInitialize = I('function() { this.setValue(""); }')
      ))
  })
  
  observeEvent(IP$dl_ml_country, {
    country <- IP$dl_ml_country
    partner <- IP$dl_ml_partner |> isolate()
    method <- IP$dl_ml_method |> isolate()
    lng <- IP$l
    req(method)
    
    partners <- sea_sectors[[method]][1,1,1,] |> names()
    names(partners) <- lb(paste0("ISO3.",partners), lng)
    partners <- partners[order(names(partners))]
    partners <- partners[partners!=country]
    
    updateSelectizeInput(
      inputId = "dl_ml_partner",
      choices = partners,
      selected = partner)
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
      updateSelectizeInput(
        inputId = "dl_ml_ind_un",
        choices = choices_ml_ind$un[choices_ml_ind$un != "MP"],
        selected = selected)
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
      updateSelectizeInput(
        inputId = "dl_ml_ind_cat",
        choices = choices_ml_ind$cat[-grep("T..", choices_ml_ind$cat)],
        selected = selected)
    }
    
  })
  
  # Download button - aggragated
  OP$dl_download <- renderUI({
    method <- IP$dl_method
    indicator <- IP$dl_indicator
    country <- IP$dl_country
    sector <- IP$dl_sector

    sector_countries <- if (
      wlv_nonempty_selection(method) && method %in% names(sea_sectors)
    ) {
      wlv_sector_country_codes(sea_sectors, method)
    } else {
      character()
    }
    file_name <- wlv_aggregated_download_href(
      method,
      country,
      indicator,
      sector,
      sector_countries
    )
    if (!wlv_download_href_available(file_name, download_directory)) {
      file_name <- ""
    }
    disable <- if (nzchar(file_name)) NULL else TRUE
    
    tags$a(href = if (nzchar(file_name)) file_name else NULL,
           download = NA,
           tags$button(
             class = "btn btn-default",
             disabled = disable,
             icon("download"),
             "Download"))
  })

  # Download button - multilateral
  OP$dl_ml_download <- renderUI({
    method <- IP$dl_ml_method
    country <- IP$dl_ml_country
    partner <- IP$dl_ml_partner
    ind_cat <- IP$dl_ml_ind_cat
    ind_scope <- IP$dl_ml_ind_scope
    ind_un <- IP$dl_ml_ind_un
    
    file_name <- ""
    disable <- TRUE
    
    if (
      wlv_nonempty_selection(country) &&
        wlv_nonempty_selection(partner) &&
        wlv_nonempty_selection(method)
    ) {
      file_name <- paste0("download/",country,".",partner,".",method,".xlsx")
    } else if (
      wlv_nonempty_selection(country) &&
        wlv_nonempty_selection(ind_cat) &&
        wlv_nonempty_selection(ind_scope) &&
        wlv_nonempty_selection(ind_un) &&
        wlv_nonempty_selection(method)
    ) {
      file_name <- paste0("download/",country,".",ind_cat,ind_scope,ind_un,".",
                          method,".xlsx")
    }
    if (!wlv_download_href_available(file_name, download_directory)) {
      file_name <- ""
    }
    disable <- if (nzchar(file_name)) NULL else TRUE
    
    tags$a(href = if (nzchar(file_name)) file_name else NULL,
           download = NA,
           tags$button(
             class = "btn btn-default",
             disabled = disable,
             icon("download"),
             "Download"))
  })
}

modules_server[[modules_server |> length() +1]] <- SERVER
