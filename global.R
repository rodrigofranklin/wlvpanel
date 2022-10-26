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

## modules ####
modules_server <- NULL
modules_ui <- NULL
source("modules/panel_setup/main.R")
source("modules/how_to_quote/main.R")
