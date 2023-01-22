##
##
##

## load required packages
source("requirements.R")

## load data
language_file <- readRDS("data/language_file.RDS")
sea_countries <- readRDS("data/sea_countries.RDS")
sea_sectors <- readRDS("data/sea_sectors.RDS")
meta_methods <- readRDS("data/meta_methods.RDS")

## Initial setup
default_language <- colnames(language_file)[2]

## functions
# Label function: create textOutput for labels calls
l <- function(lab_code) {
  textOutput(paste0("label.",lab_code), inline = TRUE)
}

lb <- function(lab_code,lang){
  language_file[lab_code,lang]
}

## modules
modules_server <- NULL
modules_ui <- NULL
source("modules/panel_setup/main.R")
source("modules/how_to_quote/main.R")
