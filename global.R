##
##
##

## load required packages ####
source("requirements.R")
source("utils/display_contracts.R")

## Define disk caching
shinyOptions(cache = cachem::cache_disk("data/labourvaluesdatapanel-cache/")) 

## load data ####
language_file <- readRDS("data/language_file.RDS")
sea_countries <- readRDS("data/sea_countries.RDS")
sea_sectors <- readRDS("data/sea_sectors.RDS")
meta_methods <- readRDS("data/meta_methods.RDS")
meta_indicators <- readRDS("data/meta_indicators.RDS")
groups <- meta_indicators$groups |> unique()
countries_sp  <- readRDS("data/countries_sp.RDS")
list_methods <- meta_methods$code
if (file.exists("data/meta_indicator_contracts.RDS")) {
  meta_indicator_contracts <- readRDS("data/meta_indicator_contracts.RDS")
  wlv_validate_display_contracts(meta_indicator_contracts)
} else {
  meta_indicator_contracts <- wlv_bind_display_contracts(lapply(
    list_methods,
    function(method) {
      wlv_legacy_display_contract(
        method_dir = method,
        method = method,
        indicators = as.character(meta_indicators$value),
        legacy_metadata = meta_indicators,
        warn = TRUE
      )
    }
  ))
}
display_contract_version <- wlv_display_contract_version(
  meta_indicator_contracts
)

## Theme definition ####

# theme <- "yeti"
# bar_height <- 45
# item_color <- "white"
# bg_color <- "black"

theme <- "simplex"
bar_height <- 41
item_color <- "darkgrey"
bg_color <- "white"
panel_bgcolor <- "rgba(252,252,252,1)"

## Initial setup ####
default_year <- 2007
default_indicator <- "surplus_value.empe_p.r.pc"
default_language <- "English"
profile_indicators <- c("surplus_value.empe_p.r.pc",
                        "gdp.s.mv",
                        "gdp.s.us",
                        "labour_force_value.m.mv",
                        "abstract_labour.empe.m.mv")
init_bases <- c("WIOD13", "WIOD16")

## functions ####
# Label function to be used on UI side: create textOutput for labels calls
l <- function(lab_code) {
  textOutput(paste0("label.",lab_code), inline = TRUE)
}

# Label function to be used on server side: need to specify input$l
lb <- function(lab_code,lang = default_language){
  language_file[lab_code,lang]
}

# Format a value that has already been converted to its display unit.
display_f2s <- function(x, ind, method, lang = "English") {
  if (!is.numeric(x) || length(x) != 1L) {
    stop("`display_f2s` requires one numeric value.", call. = FALSE)
  }
  if (is.na(x)) {
    x
  } else {
    # reduce order of magnitude
    x.abs <-  x |> abs()
    suffix <- ""
    if (x.abs >= 1000000000000) {
      x <- x/1000000000000
      suffix <- "T"
    } else if (x.abs >= 1000000000) {
      x <- x/1000000000
      suffix <- "G"
    } else if (x.abs >= 1000000) {
      x <- x/1000000
      suffix <- "M"
    } else if (x.abs >= 1000) {
      x <- x/1000
      suffix <- "K"
    }
    
    # Method-specific display units are authoritative when available.
    type <- wlv_display_format_type(
      meta_indicator_contracts,
      method,
      ind
    )

    # defines nsmall
    x.abs <-  x |> abs()
    if (x.abs >=100) {
      x <- round(x, 0)
      ns <- 0
    } else if (x.abs >= 10) {
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
    switch(
      type,
      "index" = paste0(x, suffix),
      "usd" = paste0("US$ ", x, suffix),
      "value" = paste0(x, suffix, "mv"),
      "hours" = paste0(x, suffix, lb("hours", lang)),
      "integer" = paste0(x, suffix),
      "percent" = paste0(x, suffix, "%"),
      paste0(x, suffix)
    )
  }
}

# Canonical values cross the presentation boundary exactly once here.
f2s <- function(x, ind, method, lang = "English") {
  display_f2s(
    wlv_display_values(
      x,
      method,
      ind,
      meta_indicator_contracts,
      meta_indicators
    ),
    ind,
    method,
    lang
  )
}

list_f2s <- function(z, ind, method, lng) {
  lapply(
    seq_along(z),
    function(i, w = z, name = ind) {
      f2s(w[i], name, method, lang = lng)
    }
  )
}

list_display_f2s <- function(z, ind, method, lng) {
  lapply(
    seq_along(z),
    function(i, w = z, name = ind) {
      display_f2s(w[i], name, method, lang = lng)
    }
  )
}

## modules ####
modules_server <- NULL
modules_ui <- NULL
source("modules/panel_setup/main.R")
source("modules/countries/main.R")
# source("modules/trade/main.R")
source("modules/download/main.R")
source("modules/how_to_quote/main.R")
