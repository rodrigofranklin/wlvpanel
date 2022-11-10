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
f2s <-  function (x, ind = NULL, type = NULL) {
  if (x |> is.na()) {
    x
  } else {
    # type <- indicadores$tipo[indicadores$nome == ind]
    suffix <- ""
    if (x > 1000000000) {
      x <- x/1000000000
      suffix <- " billions"
    } else if (x > 1000000) {
      x <- x/1000000
      suffix <- " millions"
    }
    x <- round(x, 2)
    # if (ind |> is.null() | tipo == "numeral") {
      x <-
        paste0(format(x, big.mark = ".", decimal.mark = ",", nsmall = 2), suffix)
    # } else if (tipo == "moeda") {
    #   x <- 
    #     paste0("R$ ", x |> format(big.mark = ".", decimal.mark = ",", nsmall = 2), sufixo)
    # } else if (tipo == "percentual") {
    #   x <- 
    #     paste0(x |> format(big.mark = ".", decimal.mark = ",", nsmall = 2), "%", sufixo)
    # } else if (tipo == "inteiro") {
    #   x <- 
    #     paste0(format(x, big.mark = ".", big.interval = 3, decimal.mark=",", nsmall = 0), sufixo)
    # }
    x
  }
}

list_f2s <- function(z, ind, type = NULL) {
  lapply(
    1:length(z), 
    function(i, w = z, name = ind){
      f2s(w[i], name)
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
