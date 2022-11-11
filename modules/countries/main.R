### Module: Countries
# Description: plot indicator on map and shows detailed info of a country

### Global #####

# Create colour pallet from data
mypallet <- function(data, indicator) {
  # If data has positive and negative values, pallet is divergent and centered in 0
  
  qtt <- data |> length()
  
  if (meta_indicators$Reverted[meta_indicators$cod_var==indicator]) {
    negative <- colorRampPalette(colors = c("#0000C8", "#F7FBFF"))(qtt)
    positive <- colorRampPalette(colors = c("#FFF5F0", "#C80000"))(qtt)
  } else {
    negative <- colorRampPalette(colors = c("#C80000", "#FFF5F0"))(qtt)
    positive <- colorRampPalette(colors = c("#F7FBFF", "#0000C8"))(qtt)
  }
  onlypositive <- colorRampPalette(colors = c("#FFF5F0", "#C80000"))(qtt)
  
  
  suppressWarnings({
    maximum <- max(data, na.rm = TRUE) *1.1
    minimum <- min(data, na.rm = TRUE) *1.1
  })
  
  if (minimum < 0 & maximum >0) {
    if (maximum > abs(minimum)) {
      dominium <- c(-maximum,maximum)
    } else {
      dominium <- c(minimum,-minimum)
    }
    colours <- c(negative, positive)
  } else if (maximum < 0) {
    dominium <- c(minimum,0)
    colours <- negative
  } else {
    dominium <- c(0,maximum)
    colours <- onlypositive
  }
  
  if (maximum |> is.infinite()) {
    function (i) "transparent"
  } else {
    colorNumeric(
      colours,
      domain = dominium, 
      na.color="transparent")
  }
}

# Format labels numbers for legend
label_f2s <- function(ind, lng) {
  function(type, cuts, ...) {
    list_f2s(cuts, ind, type, lng)
  }
}

### UI ####

TABPANEL <- tabPanel(
  l("tab_name.countries"),

  # Style for a bordeless map
  tags$style(type = "text/css", "#map {z-index: 1; background: #D4DADC}"),
  tags$style(type = "text/css", ".container-fluid {padding-left:0px;padding-right:0px;}"),
  tags$style(type = "text/css", ".navbar {margin-bottom: 0px;}"),
  tags$style(type = "text/css", ".container-fluid .navbar-header .navbar-brand {margin-left: 0px;}"),
  tags$style(type = "text/css", ".leaflet-control-container .leaflet-top.leaflet-left {position: absolute; left: 330px;}"),
  
  leafletOutput("map", width = "100%", height = paste0("calc(100vh - ", bar_height, "px)")),
  
  # Panel of Inputs
  absolutePanel(
    id = "inputs_panel",
    top = bar_height + 10,
    left = 10,
    style = paste0("z-index: 2;
      font-size: 10px;
      padding: 10px 10px 0px 10px;
      color: black;
      background-color: rgba(0,0,0,0.1);"),
    ## This style is the same of the leaflet's layers control box
    # background-color: ", bg_color, ";"),
    # border: 2px solid rgba(0,0,0,0.2);
    # background-clip: padding-box;
    # border-radius: 5px;

    selectizeInput(
      "co_select_country",
      label = NULL,
      choices = NULL),
    
    selectizeInput(
      "co_select_indicator",
      label = NULL,
      choices = NULL),
    
    sliderInput(
      "co_select_year",
      label = NULL,
      min = 1995, 
      max = 2016, 
      value = 2009, 
      ticks = F, 
      animate = F, 
      sep = "")
  )
)

modules_ui[[modules_ui |> length() +1]] <- TABPANEL

### Server ####

SERVER <- function(IP, OP, RV, SESSION) {
 
  ## Change input controls accordingly bases selected in setup panel ####
  observe({
    methods <- RV$bases()
    lng <- IP$l
    
    temp_data <- sea_countries[methods,,,]
    
    years <- temp_data[1,,1,1] |> names()
    years <- years[temp_data[,,1,1] |> colSums(na.rm = TRUE) !=0]
    
    indicators <- temp_data[1,1,,1] |> names()
    indicators <- indicators[temp_data[,1,,1] |> colSums(na.rm = TRUE) !=0]
    
    countries <- temp_data[1,1,1,] |> names()
    countries <- countries[temp_data[,1,1,] |> colSums(na.rm = TRUE) !=0]
    
    names(countries) <- lb(paste0("ISO3.",countries), lng)
    
    updateSelectizeInput(
      inputId = "co_select_country",
      choices = countries,
      server = FALSE, # needed for placeholder to work...
      options = list(
        placeholder = lb("co_select_country.placeholder", lng),
        onInitialize = I('function() { this.setValue(""); }')
      ))
    
    updateSelectInput(
      inputId = "co_select_indicator",
      choices = lists_indicators)
    
    year <- NULL
    year_max <- years |> max()
    year_min <- years |> min()
    if (IP$co_select_year |> isolate() > year_max) {
      year <- year_max
    } else if (IP$co_select_year |> isolate() < year_min) {
      year <- year_min
    }
    
    updateSliderInput(
      inputId = "co_select_year",
      max = year_max,
      min = year_min,
      value = year)
  })
  
  ## Base map ####
  OP$map <- renderLeaflet({
    leaflet(
      options = leafletOptions(
        zoomControl = FALSE,
        boxZoom = TRUE,
        doubleClickZoom = FALSE,
        maxZoom = 10,
        minZoom = 2,
        maxBoundsViscosity = 1,
        preferCanvas = TRUE,
        worldCopyJump = FALSE
      )) |>
      addMapPane("base", zIndex = 5) |>
      addMapPane("polygons", zIndex = 10) |>
      addMapPane("labels", zIndex = 15) |>
      addProviderTiles(
        providers$CartoDB.PositronNoLabels,
        options = providerTileOptions(
          maxZoom = 10,
          pane = "base"
        )
      ) |>
      addProviderTiles(
        providers$CartoDB.PositronOnlyLabels,
        options = providerTileOptions(
          maxZoom = 10,
          pane = "labels"
        )
      ) |>
      setMaxBounds(-180,-180,180,180)
  })
  outputOptions(OP, "map", suspendWhenHidden = FALSE) 
  
  ## Change layers #####
  # 1) Change layers control after setup selection
  # 2) Hide unchosed layers
  observe({
    methods <- RV$bases()
    proxy <- leafletProxy("map")

    proxy |>
      addLayersControl(
        baseGroups = c(methods),
        position = c("topleft"),
        options = layersControlOptions(collapsed = FALSE))
    
    lapply(
      list_methods[(list_methods %in% methods) |> not()],
      \(i) proxy |> hideGroup(i))
  })
  
  ## Change data ####
  # Select data for each layer considering:
  # 1) methods selected in setup
  # 2) indicator
  # 3) year
  map_data <- reactive({
    methods <- RV$bases()
    indicator <- IP$co_select_indicator
    year <- IP$co_select_year
    
    req(indicator)
    req(year)

    temp_all_data <- lapply(methods, function(i){
      temp_data <- countries_sp[[i]]
      temp_data@data$data <-
        sea_countries[i,
                      year |> as.character(),
                      indicator,
                      temp_data@data$ISO3 |> as.character()]
      temp_data
    })
    names(temp_all_data) <- methods
    temp_all_data
  })
  
  ## Change colour pallets ####
  # Creates colour pallets for each layer considering:
  # 1) methods selected in setup
  # 2) map_data
  pallet <- reactive({
    methods <- RV$bases()
    indicator <- IP$co_select_indicator
    map_data <- map_data()

    temp_all_pallet <- lapply(methods, function(i){
      temp_pallet <- mypallet(map_data[[i]]@data$data, indicator)
      temp_pallet
    })
    names(temp_all_pallet) <- methods
    temp_all_pallet
  })
  
  ## Labels for mouse hover ####
  labels <- reactive({
    method <- IP$map_groups
    req(method)
    map_data <- map_data()[[method]]@data
    lng <- IP$l
    indicator <- IP$co_select_indicator
    
    sprintf(
      "<p style='
      text-align: center;
      border-style: none none solid;
      border-width: 1px;
      font-weight: bold'>
      %s</p>%s : %s",
      lb(paste0("ISO3.",map_data$ISO3),lng),
      lb(indicator,lng),
      list_f2s(map_data$data, indicator, lng = lng)) |>
      lapply(htmltools::HTML)
  })
  
  ## Plot polygons ####
  # Plot polygons for each layer, based on map_data and pallet
  observe({
    methods <- RV$bases()
    map_data <- map_data()
    pallet <- pallet()
    labels <- labels()
    proxy <- leafletProxy("map")
    
    lapply(methods,
           function(method) {
             layer_data <- map_data[[method]]

             proxy   |>
               addPolygons(
                 data = layer_data,
                 layerId = layer_data@data$layerId,
                 fillColor = ~pallet[[method]](layer_data@data$data),
                 label = labels,
                 fillOpacity = 0.6,
                 group = method,
                 color = "#EBD6D8",
                 weight = 1,
                 options = pathOptions(pane = "polygons"),
                 highlightOptions = highlightOptions(
                   color = "red",
                   fillOpacity = 0.7,
                   bringToFront = TRUE))
           })
  })
  
  ## Legend control ####
  # Change legend with layer
  observe({
    method <- IP$map_groups
    methods <- RV$bases()
    map_data <- map_data()
    pallet <- pallet()
    indicator <- IP$co_select_indicator
    lng <- IP$l
    
    req(method)
    req(map_data)
    req(indicator)
    
    proxy <- leafletProxy("map")
    proxy |> 
      clearControls()
    if (method %in% methods |> not()) return()
    if (map_data[[method]]@data$data |> sum(na.rm = TRUE) != 0)
      proxy |>
      addLegend("bottomright",
                values = map_data[[method]]@data$data,
                pal = pallet[[method]],
                labFormat = label_f2s(indicator, lng))

    # De-active loading panel
    OP$loading <- renderText("")
  })
  
  ## Select country ####
  observeEvent(IP$map_shape_click, {
    country <- IP$map_shape_click
    country <- sub(".*\\.","",country[1])
    updateSelectizeInput(
      inputId = "co_select_country",
      selected = country)
  })
}

modules_server[[modules_server |> length() +1]] <- SERVER
