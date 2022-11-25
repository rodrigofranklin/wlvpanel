### Global ####

# Format labels numbers for legend
axis_f2s <- function(ind, lng) {
  function(cuts) {
    list_f2s(cuts, ind, NA, lng)
  }
}

# Panel for graphics and "loading..."
graph_panel <- function (graph, graph_width, indicator) {
  tags$table(
    style = "display: inline-table;",
    tags$tr(
      tags$td(
        valign = "text-top",
        style = paste0("width: ", graph_width-20,"px;",
                       "height: 40px !important;",
                       "padding-left: 5px;"),
        actionLink(
          inputId = paste0(indicator,"_title"),
          label = l(indicator),
          style = paste0("font-size: 14px;",
                         "font-weight: bold;",
                         "color: gray;")),
      ),
      tags$td(
        valign = "top",
        style = paste0("text-align: right;",
                       "padding-right: 3px;"),
        actionLink(
          inputId = paste0(indicator,"_info"),
          label = NULL,
          style = paste0("top: 3px;",
                         "right: 3px",
                         "font-size:14px;",
                         "color: gray;"),
          icon = icon("info-circle"))
      )
    ),
    tags$tr(
      tags$td(
        colspan = 2,
        width = graph_width,
        graph
      )
    )
  ) |> div(
    width = graph_width,
    class = "panel panel-default",
    style = paste0("display: inline-block;",
                   "height: 264px;",
                   "margin-right: 15px;"))
}



### UI ####

## Country Panel ####
country_panel <- conditionalPanel(
  "output.show_country_panel != ''",
  
  tags$style(type = "text/css", ".profile_table {
      line-height: 0.5 !important;
      border-style: none !important;
      border-color: red !important;
    }"),
  
  # Close button
  actionButton(
    inputId = "close_country_panel",
    label = NULL,
    icon = icon("times"),
    style = paste0("border-radius: 50%;",
                  "color: white;",
                  "font-size: 12px;",
                  "position: absolute;",
                  "top: ", bar_height + 15,"px;",
                  "left: calc(50vw - 17px);",
                  "z-index: 501;",
                  "background-color:", item_color,";")),
  
  # The panel, properly
  absolutePanel(
    style = paste0("z-index:500;",
                   "padding: 0px 10px 10px 10px;",
                   "top:",bar_height+32,"px;",
                   "height: calc(100vh - ", bar_height+32,"px);",
                   "left: 10px;",
                   "width: calc(100vw - 20px);",
                   "background-color:  ", panel_bgcolor,";",
                   "border: solid;",
                   "border-width: 1px;",
                   "border-top-right-radius: 3px;",
                   "border-top-left-radius: 3px;",
                   "border-color: rgb(221, 221, 221);"),
    withTags(
      table(
        width = "100%",
        tr(
          td(
            width = "100%",
            valign = "text-top",
            style = paste0("font-size: 33px;"),
            textOutput("co_panel_title", inline = TRUE)
          ),
          td(
            style = "padding: 10px 0px 0px 0px;",
            sliderInput(
              "co_panel_year",
              label = NULL,
              min = 1995, 
              max = 2016, 
              value = 2009, 
              ticks = F, 
              animate = F, 
              sep = "")
          )
        ),
        tr(
          td(
            colspan = 2,
            absolutePanel(
              width = "calc(100vw - 32px)",
              height = paste0("calc(100vh - ", bar_height+99,"px)"),
              style = paste0("overflow-y:scroll;"),
              table(
                width = "100%",
                tr(
                  td(
                    style = "padding: 0px 18px 0px 0px;",
                    colspan = 2,
                    # Profile table
                    div(
                      style = "width: 100%; border-radius: 0px !important;",
                      class = "panel panel-default",
                      dataTableOutput("co_panel_profile") |>
                        div(
                          class = "panel-body",
                          style = paste0("background-image:none;",
                                         "background: white;",
                                         "padding: 0px;")))
                  ),
                  td(
                    width = 350,
                    valign = "top",
                    style = paste0("padding-right: 10px !important;"),
                    # Download area
                    div(
                      class = "panel panel-default",
                      tags$table(
                        tags$tr(
                          tags$td(
                            icon("flag", 
                                 style = "font-size: 28px; color: gray"),
                            rowspan = 2),
                          tags$td(
                            style = paste0("padding: 0px 15px;",
                                           "font-weight: bold;",
                                           "font-size: 16px"),
                            l("co_panel_download_country"),
                            width = "100%")
                        ),
                        tags$tr(
                          tags$td(
                            uiOutput("country_link"),
                            style = "text-align: center;font-size: 12px")
                        )
                      ) |> 
                        div(class = "panel-heading",
                            style = paste0("background-image:none;",
                                           "background: white;",
                                           "font-size: 16px;",
                                           "padding: 5px 15px !important;")),
                      tags$table(
                        tags$tr(
                          tags$td(
                            icon("chart-pie", 
                                 style = "font-size: 28px; color: gray"),
                            rowspan = 2
                          ),
                          tags$td(
                            style = paste0("padding: 0px 15px;",
                                           "font-weight: bold;",
                                           "font-size: 16px"),
                            l("co_panel_download_sector"),
                            width = "100%")
                        ),
                        tags$tr(
                          tags$td(
                            uiOutput("sector_data_link"),
                            style = "text-align: center;font-size: 12px"))
                      )|>
                        div(class = "panel-heading",
                            style = paste0("background-image:none;",
                                           "background: white;",
                                           "font-size: 16px;",
                                           "padding: 5px 15px !important;"))
                    ) 
                  )
                ),
                tr(
                  td(
                    # Graphs
                    width = 790,
                    lapply(groups, \(z){
                      tagList(
                        # Group title
                        l(paste0("group.",z)) |> 
                          div(style = paste0("font-size: 18px;",
                                              "font-weight: bold;")),
                        tags$hr(style = paste0("margin-top: 0px;",
                                               "margin-right: 18px;",
                                               "text-align: left;")),
                        conditionalPanel(
                          'output["gdp.s.mv_plot"] == "1"',
                          "TESTE"
                        ),
                        lapply(meta_indicators$value[meta_indicators$groups==z], \(i){
                          # Indicator graphs
                          uiOutput(paste0(i,"_plot"),
                                   inline = TRUE,
                                   container = tags$span)
                        }),
                        tags$br(),tags$br()
                      )
                    })
                  ),
                  td(
                    # Sectorial data table
                    colspan = 2,
                    valign="top",
                    style = "padding-right: 10px;",
                    div(
                      style ="position: sticky; top: 0px;",
                      p(
                        l("co_panel_sector_title"),
                        " - ", 
                        textOutput("co_panel_year", inline = TRUE),
                        style = paste0("text-align: center;",
                                       "font-weight: bold;",
                                       "font-size: 24px"),
                        
                        div(
                          class = "panel panel-default",
                          textOutput("co_panel_sector_indicator") |>
                            div(class = "panel-heading",
                                style = paste0("background-image:none;",
                                               "background: white;",
                                               "font-size:16px;",
                                               "font-weight: bold;",
                                               "padding: 3px 5px;")),
                          uiOutput("co_sector_panel",
                                   inline = TRUE) |>
                            div(
                                   class = "panel-body",
                                   style = "padding: 0px; width:400px;")
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

### Server ####

country_panel_server <-  function(IP, OP, RV, SESSION) {
  
  ## Open/close system for country_panel ####
  show_country_panel <- reactiveVal("")
  OP$show_country_panel <- renderText(show_country_panel())
  outputOptions(OP,"show_country_panel", suspendWhenHidden = FALSE)
  observeEvent(IP$co_select_country, show_country_panel(IP$co_select_country))
  observeEvent(IP$close_country_panel, 
               updateSelectizeInput(inputId = "co_select_country", selected = ""))
  
  ## Change input controls accordingly bases selected in setup panel ####
  observe({
    year_max <- RV$yearmax()
    year_min <- RV$yearmin()
    year <- NULL
    if (IP$co_panel_year |> isolate() > year_max) {
      year <- year_max
    } else if (IP$co_panel_year |> isolate() < year_min) {
      year <- year_min
    }
    updateSliderInput(
      inputId = "co_panel_year",
      max = year_max,
      min = year_min,
      value = year)
  })
  
  ## Graph panel ####
  # create uiOutput with graphs for all indicators
  lapply(meta_indicators$value, \(indicator) {
    OP[[paste0(indicator,"_plot")]] <- renderUI({
      # reactive data
      methods <- RV$bases() |> isolate()
      year_max <- RV$yearmax() |> isolate()
      year_min <- RV$yearmin() |> isolate()
      lng <- IP$l |> isolate()
      country <- IP$co_select_country
      graph_width <- 375
      
      # loading...
      graph <- div(
        style = "height: 220px; text-align: center; padding: 80px;",
        img(src = "/spinner.gif"))
      if (country == "") 
        return(graph_panel(graph, graph_width, indicator))

      years <- year_min:year_max
      data <- sea_countries[methods,years |> as.character(),indicator,country]
      if (data |> sum(na.rm = TRUE) == 0) return() # NULL if has no data
      
      # prepare data.frame for ggplot
      data <- data |> t() |> as.data.frame()
      data$year <- years
      data <- data |> 
        pivot_longer(-year, 
                     names_to = "method", 
                     values_to = "value")
      
      # labels for axis x
      if((length(years) %% 2) != 0) {
        half <- (length(years)+1)/2
        break_years <- c(years |> min(),
                         years[half],
                         years |> max())
      } else {
        half <- (length(years))/2
        break_years <- c(years |> min(),
                         years[half-1],
                         years[half+2],
                         years |> max())
      }
      
      # include horizontal line
      if (min(data$value, na.rm = TRUE)<0 & max(data$value, na.rm = TRUE)>0) {
        hline <- geom_hline(yintercept=0, size = 0.1, color = "grey80")
      } else {
        hline <- NULL
      }
      
      # data for tooltips
      data$data <- list_f2s(data$value,indicator,NA,lng)
      
      # the graph, properly
      graph <- (data |>
                  ggplot(aes(x=year,y=value,col=method, text=data)) +
                  geom_line(size = 0.5, na.rm = TRUE)  +
                  geom_point(aes(fill=method), colour = "white", size = 1, stroke = 0.5)+
                  hline +
                  scale_x_continuous(breaks = break_years) +
                  scale_y_continuous(labels = axis_f2s(indicator, lng))+
                  theme_classic() +
                  theme(plot.margin = unit(c(0,0,0,0), "cm"),
                        panel.spacing = unit(0, "mm"),
                        axis.title = element_blank(),
                        axis.line = element_blank(),
                        axis.ticks = element_blank(),
                        axis.text = element_text(size = 8, 
                                                 colour = "grey60"))) |>
        ggplotly(tooltip = c("year","data"), width = graph_width, height = 220) |>
        layout(hovermode = "x",
               legend = list(title = "", 
                             orientation = "h", 
                             y="-0.1", 
                             x="-0.1",
                             font = list(size = "10")),
               margin = list(l = "0", t = "0", r = "10", pad = "0")) |>
        config(displaylogo = FALSE,
               displayModeBar = FALSE)
      
      # Indicator Graph Panel
      graph_panel(graph, graph_width, indicator)

    })
  
    # outputOptions(OP,paste0(indicator,"_plot"), suspendWhenHidden = FALSE)
    
    observeEvent(IP[[paste0(indicator,"_info")]],{
      info_indicator(indicator)
      show_info_panel(1)
    })
    
    observeEvent(IP[[paste0(indicator,"_title")]], ignoreInit = TRUE, {
      updateSelectInput(inputId = "indicator", selected = indicator)
    })
  })  
  
  ## Info Panel ####
  # Open/close system for info_panel
  show_info_panel <- reactiveVal(0)
  OP$show_info_panel <- renderText(show_info_panel())
  outputOptions(OP,"show_info_panel", suspendWhenHidden = FALSE)
  observeEvent(IP$info_close_button, show_info_panel(0))
  # onclick(id = "info_background", show_info_panel(0))
  
  # Select indicator
  info_indicator <- reactiveVal("")
  OP$info_indicator <- renderText({
    
  })
  
  ## Profile Panel ####
  
  # Title
  OP$co_panel_title <- renderText(lb(paste0("ISO3.",IP$co_select_country), IP$l))
  outputOptions(OP,"co_panel_title", suspendWhenHidden = FALSE)
  
  # Table
  OP$co_panel_profile <- renderDataTable({
    # Reactive data
    methods <- RV$bases() |> isolate()
    country <- IP$co_select_country
    year <- IP$co_panel_year |> as.character()
    lng <- IP$l
    
    if (country == "") return()
    
    # create table with profile data
    profile_table <- methods |> as.data.frame(row.names = methods)
    for (i in profile_indicators) {
      profile_table[[i]] <- sea_countries[methods, year, i, country] |>
        list_f2s(i,lng = lng) |>
        unlist()
    }
    profile_table <- profile_table[,-1] |> t()
    rownames(profile_table) <- lb(profile_indicators, lng)
    
    profile_table
  },
  server = F,
  rownames = TRUE,
  class = "profile_table",
  options = list(
    ordering = FALSE,
    searching = FALSE,
    paging = FALSE,
    columnDefs = list(list(className = 'dt-left', targets = 0),
                      list(className = 'dt-right', targets = "_all")),
    paging = FALSE,
    info = FALSE,
    lengthChange = FALSE)
  )
  outputOptions(OP,"co_panel_profile", suspendWhenHidden = FALSE)
  
  ## Download links ####
  OP$country_link <- renderUI({
    methods <- RV$bases()
    country <- IP$co_select_country
    country_link <- NULL
    if (country =="") return()

    for (method in methods) {
      if (sea_countries[method,,,country] |> sum(na.rm = TRUE) >0)
        country_link <- tagList(
          country_link,
          tags$a(method, href = paste0("download/COUNTRY.",country,".", method, ".xlsx")),
          "|")
    }
    country_link[1:(length(country_link)-1)]
  })
  outputOptions(OP,"country_link", suspendWhenHidden = FALSE)
  
  OP$sector_data_link <- renderUI({
    methods <- RV$bases()
    country <- IP$co_select_country
    sector_data_link <- NULL
    if (country =="") return()
    
    for (method in methods) {
      if (sea_countries[method,,,country] |> sum(na.rm = TRUE) >0)
        sector_data_link <- tagList(
          sector_data_link,
          tags$a(method, href = paste0("download/SECTORS.",country,".", method, ".xlsx")),
          "|")
    }
    sector_data_link[1:(length(sector_data_link)-1)]
  })
  outputOptions(OP,"sector_data_link", suspendWhenHidden = FALSE)
  
  ## Sectoral tabel ####
  OP$co_panel_year <- renderText(IP$co_panel_year)
  OP$co_panel_sector_indicator <- renderText("TESTE")

  
  OP$co_sector_panel <- renderUI({
    lng <- IP$l |> isolate()
    year <- IP$co_panel_year |> as.character()
    country <- IP$co_select_country
    indicator <- "surplus_value.empe.r.pc"
    methods <- RV$bases() |> isolate()
    method <- methods[1]
    
    # do.call("tabsetPanel", c(
    #   lapply(methods, \(method){
    #     tabPanel(method,{
    #       data <- sea_sectors[[method]][year,indicator,,country]
    #       mydt <- data |> list_f2s(indicator, NULL, lng) |> unlist()
    #       names(mydt) <- 
    #         lb(paste0(meta_methods$source[meta_methods$code==method],
    #                   ".",names(data)), lng)
    #       
    #       mydt |> as.data.frame() |> datatable(
    #         rownames = TRUE,
    #         colnames = c(""),
    #         height = "calc(100vw - 850px)",
    #         fillContainer = FALSE,
    #         options = list(
    #           ordering = TRUE,
    #           class = "compact",
    #           searching = FALSE,
    #           paging = FALSE,
    #           scrollY= "calc(100vh - 280px)",
    #           info = FALSE,
    #           lengthChange = FALSE))
    #     })
    #   })
    # ))
    
    RV$debug(method)
    
    tabsetPanel(
      tabPanel(
        methods[1],{
          data <- sea_sectors[[method]][year,indicator,,country]
          mydt <- data |> list_f2s(indicator, NULL, lng) |> unlist()
          names(mydt) <-
            lb(paste0(meta_methods$source[meta_methods$code==method],
                      ".",names(data)), lng)
          
          mydt |> as.data.frame() |> datatable(
            rownames = TRUE,
            colnames = c(""),
            height = "calc(100vw - 850px)",
            fillContainer = FALSE,
            options = list(
              ordering = TRUE,
              class = "compact",
              searching = FALSE,
              paging = FALSE,
              scrollY= "calc(100vh - 280px)",
              info = FALSE,
              lengthChange = FALSE))
        }
      )
    )
  })
}