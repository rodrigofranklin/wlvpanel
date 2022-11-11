##
##
##

## load required packages ####
source("requirements.R")

## load data ####
language_file <- readRDS("data/language_file.RDS")
sea_countries <- readRDS("data/sea_countries.RDS")
sea_sectors <- readRDS("data/sea_sectors.RDS")
meta_methods <- readRDS("data/meta_methods.RDS")
meta_indicators <- readRDS("data/meta_indicators.RDS")
lists_indicators <- readRDS("data/lists_indicators.RDS")

countries_sp  <- readRDS("data/countries_sp.RDS")

## Theme definition ####

# theme <- "yeti"
# bar_height <- 45
# item_color <- "white"
# bg_color <- "black"

theme <- "simplex"
bar_height <- 41
item_color <- "darkgrey"
bg_color <- "white"

## Initial setup ####
default_language <- colnames(language_file)[2]
base1 <- "WIOD13"
base2 <- "WIOD16"
base3 <- "WIOD13"
base4 <- "WIOD16"


## functions ####
# Label function to be used on UI side: create textOutput for labels calls
l <- function(lab_code) {
  textOutput(paste0("label.",lab_code), inline = TRUE)
}

# Label function to be used on server side: need to specify input$l
lb <- function(lab_code,lang = default_language){
  language_file[lab_code,lang]
}

# Format numbers accordingly indicators meta-data (format to show)
f2s <-  function (x, ind = NULL, type = NULL, lang = "English") {
  if (x |> is.na()) {
    x
  } else {
    # reduce order of magnitude
    suffix <- ""
    if (x >= 1000000000000) {
      x <- x/1000000000000
      suffix <- " T"
    } else if (x >= 1000000000) {
      x <- x/1000000000
      suffix <- " G"
    } else if (x >= 1000000) {
      x <- x/1000000
      suffix <- " M"
    } else if (x >= 1000) {
      x <- x/1000
      suffix <- " K"
    }
    
    # defines nsmall
    if (x >=100) {
      x <- round(x, 0)
      ns <- 0
    } else if (x >= 10) {
      x <- round(x, 1)
      ns <- 1
    } else {
      x <- round(x, 2)
      ns <- 2
    }
    
    # Format number
    x <- format(x, 
                big.mark = lb("big.mark", lang), 
                decimal.mark = lb("decimal.mark", lang), 
                nsmall = ns)

    # add suffix and prefix
    type <- meta_indicators$type[meta_indicators$cod_var == ind]
    switch (type,
            "index" = paste0(x, suffix),
            "usd" = paste0("US$ ", x, suffix),
            "value" = paste0(x, suffix, " mv"),
            "hours" = paste0(x, suffix, " ", lb("hours", lang)),
            "integer" = paste0(x, suffix),
            "percent" = paste0(x, suffix, "%"))
  }
}

list_f2s <- function(z, ind, type = NULL, lng) {
  lapply(
    1:length(z), 
    function(i, w = z, name = ind){
      f2s(w[i], name, lang = lng)
    }
  )
}

## modules ####
modules_server <- NULL
modules_ui <- NULL
source("modules/panel_setup/main.R")
source("modules/countries/main.R")
source("modules/trade/main.R")
source("modules/how_to_quote/main.R")
