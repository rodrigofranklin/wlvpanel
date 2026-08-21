# Prepare data for panel
# All computations need to be done here

library(dplyr)
library(magrittr)
library(MazamaSpatialUtils)
library(rworldmap)
source("utils/display_contracts.R")
source("utils/result_contracts.R")

result_run_dirs <- wlv_resolve_result_run_dirs(
  results_root = "results",
  required_artifacts = c(
    "_parameters.csv",
    "_method_solutions.csv",
    "meta_indicators.RDS",
    "sea_countries.fst",
    "sea_countries.fst.meta",
    "sea_sectors.fst",
    "sea_sectors.fst.meta",
    "m_countries.fst",
    "m_countries.fst.meta"
  )
)
result_publication_mode <- attr(
  result_run_dirs,
  "publication_mode",
  exact = TRUE
)
result_release_root <- attr(result_run_dirs, "release_root", exact = TRUE)
result_metadata_root <- if (identical(
  result_publication_mode,
  "immutable_release"
)) {
  result_release_root
} else {
  "results"
}

# The shared CSV remains the legacy presentation catalog. Method-specific
# storage/display semantics are loaded separately below.
meta_indicators <- read.csv2(file.path(
  result_metadata_root,
  "meta_indicators.csv"
))
indicator_editorial_metadata <- wlv_read_indicator_editorial_metadata(
  "config/indicator-editorial-metadata.csv"
)
meta_indicators <- wlv_complete_legacy_indicator_metadata(
  meta_indicators,
  indicator_editorial_metadata
)
meta_indicators <- meta_indicators[order(meta_indicators$groups), ]
wlv_validate_legacy_indicator_identity(meta_indicators)

# Creating language_file ####
# Here, we also need to merge language files of country names, variable names, etc
languages <- read.csv2("data/config/languages.csv")
countries <- read.csv2("data/config/countries.csv")
sectors_wiod13 <- read.csv2("data/config/sectors_wiodr13.csv")
sectors_wiod16 <- read.csv2("data/config/sectors_wiodr16.csv")

# label files
language_file <- read.csv2(paste0("data/config/label_",languages$file[1],".csv"))
for (x in 1:length(languages$language)) {
  l_temp <-  read.csv2(paste0("data/config/label_",languages$file[x],".csv"))
  names(l_temp)[2] <- languages$language[x]
  language_file <- full_join(language_file, l_temp, by = "cod_label")
}

rownames(language_file) <- language_file[,1]
language_file <- language_file[,-c(1,2)]

# Merge countries names
rownames(countries) <- countries[,1]
language_file <- rbind(language_file,countries[,languages$language])

# Merge sectors names
rownames(sectors_wiod13) <- sectors_wiod13[,1]
language_file <- rbind(language_file,sectors_wiod13[,languages$language])
rownames(sectors_wiod16) <- sectors_wiod16[,1]
language_file <- rbind(language_file,sectors_wiod16[,languages$language])

# Indicators names and description. Releases always contain a verified English
# catalog. A language-specific catalog may also be part of the release; during
# migration, a legacy catalog can be used only through this explicit fallback.
wlv_panel_indicator_catalog_path <- function(language_code) {
  filename <- paste0("indicators_", language_code, ".csv")
  candidate <- file.path(result_metadata_root, filename)
  if (file.exists(candidate)) {
    return(candidate)
  }
  if (identical(result_publication_mode, "immutable_release")) {
    legacy_candidate <- file.path("results", filename)
    if (!identical(language_code, "en") && file.exists(legacy_candidate)) {
      warning(
        sprintf(
          paste0(
            "Release `%s` has no `%s`; using the unversioned legacy ",
            "language catalog after release validation."
          ),
          attr(result_run_dirs, "release_id", exact = TRUE),
          filename
        ),
        call. = FALSE
      )
      return(legacy_candidate)
    }
    warning(
      sprintf(
        "Release `%s` has no `%s`; using its verified English catalog.",
        attr(result_run_dirs, "release_id", exact = TRUE),
        filename
      ),
      call. = FALSE
    )
    return(file.path(result_release_root, "indicators_en.csv"))
  }
  english_legacy <- file.path("results", "indicators_en.csv")
  if (file.exists(english_legacy)) {
    warning(
      sprintf(
        "Legacy results have no `%s`; using `indicators_en.csv`.",
        filename
      ),
      call. = FALSE
    )
    return(english_legacy)
  }
  stop(sprintf("No indicator catalog is available for `%s`.", language_code),
    call. = FALSE
  )
}

indicator_file <- read.csv2(
  wlv_panel_indicator_catalog_path(languages$file[1])
)
for (x in 1:length(languages$language)) {
  I_temp <- read.csv2(wlv_panel_indicator_catalog_path(languages$file[x]))
  names(I_temp)[2] <- languages$language[x]
  indicator_file <- full_join(indicator_file, I_temp, by = "cod_label")
}

rownames(indicator_file) <- indicator_file[,1]
indicator_file <- indicator_file[,-c(1,2)]
language_file <- rbind(language_file,indicator_file)
language_file <- wlv_complete_indicator_language_file(
  language_file,
  indicator_editorial_metadata
)
wlv_validate_indicator_language_labels(
  language_file,
  meta_indicators$value,
  languages$language
)

language_file |> saveRDS("data/language_file.RDS")

# Merge data from all methods ####

## function to read data
read_fst_array <- function(file_name) {
  
  ft <- fst::read_fst(file_name)  # single column data.frame
  metaf <- paste0(file_name, ".meta")
  if(file.exists(metaf)) {
    meta_data <- readRDS(metaf)  # retrieve dim
    
    m <- ft[[1]]  
    attr(m, "dim") <- meta_data$dim
    dimensiones <- length(meta_data$dim)
    meta_data <- meta_data[2:(dimensiones+1)]
    dimnames(m) <- meta_data
    
    m} else {
      ft
    }
}

## Select methods published by the configured release channel. When no release
## marker exists, `wlv_resolve_result_run_dirs()` returns the explicit legacy
## `results/<method>` fallback with a warning.
method_list <- names(result_run_dirs)

## Load data from all methods
## and create lists of arrays dimensions
sea_countries <- NULL
sea_sectors <- NULL
m_countries <- NULL
list_years <- NULL
list_sea_variables <- NULL
list_countries <- NULL
meta_methods <- NULL
meta_indicator_contract_parts <- list()

for (x in method_list) {

  method_result_dir <- unname(result_run_dirs[[x]])

  # Resolve presentation semantics before loading large arrays. Legacy results
  # with incomplete presentation metadata are excluded explicitly; modern
  # partial/corrupt contracts still abort preparation.
  parameters <- read.csv2(file.path(method_result_dir, "_parameters.csv"))
  method_metadata_path <- file.path(method_result_dir, "meta_indicators.RDS")
  method_indicators <- if (file.exists(method_metadata_path)) {
    method_metadata <- readRDS(method_metadata_path)
    if (!is.data.frame(method_metadata) || !"code" %in% names(method_metadata)) {
      stop(
        sprintf("Method `%s` has invalid indicator metadata.", x),
        call. = FALSE
      )
    }
    as.character(method_metadata$code)
  } else {
    method_solutions <- read.csv2(
      file.path(method_result_dir, "_method_solutions.csv")
    )
    as.character(method_solutions$names)
  }
  method_code <- as.character(parameters$code[[1]])
  if (!nzchar(method_code)) {
    stop(sprintf("Method directory `%s` has no display method code.", x),
      call. = FALSE
    )
  }
  method_display_contract <- wlv_read_supported_method_display_contract(
    path = method_metadata_path,
    method_dir = x,
    method = method_code,
    indicators = method_indicators,
    legacy_metadata = meta_indicators,
    warn_legacy = TRUE
  )
  if (is.null(method_display_contract)) {
    next
  }

  # load data
  
  sea_countries$temp <- read_fst_array(
    file = file.path(method_result_dir, "sea_countries.fst")
  )
  sea_sectors$temp <- read_fst_array(
    file = file.path(method_result_dir, "sea_sectors.fst")
  )
  m_countries$temp <- read_fst_array(
    file = file.path(method_result_dir, "m_countries.fst")
  )

  country_indicators <- dimnames(sea_countries$temp)[[2]]
  sector_indicators <- dimnames(sea_sectors$temp)[[2]]
  if (!identical(country_indicators, sector_indicators)) {
    stop(
      sprintf(
        "Method `%s` has different country and sector indicator axes.",
        x
      ),
      call. = FALSE
    )
  }
  meta_indicator_contract_parts[[length(meta_indicator_contract_parts) + 1L]] <-
    method_display_contract
  
  # Convert ISO-2 to ISO-3
  temp_iso <- dimnames(sea_countries$temp)[[3]]
  temp_iso[nchar(temp_iso) <3] <- 
    iso2ToIso3(temp_iso[nchar(temp_iso) <3])
  dimnames(sea_countries$temp)[[3]][temp_iso |> is.na() |> not()] <- 
    temp_iso[temp_iso |> is.na() |> not()]
  
  temp_iso <- dimnames(sea_sectors$temp)[[4]]
  temp_iso[nchar(temp_iso) <3] <- 
    iso2ToIso3(temp_iso[nchar(temp_iso) <3])
  dimnames(sea_sectors$temp)[[4]][temp_iso |> is.na() |> not()] <- 
    temp_iso[temp_iso |> is.na() |> not()]

  temp_iso <- dimnames(m_countries$temp)[[3]]
  temp_iso[nchar(temp_iso) <3] <- 
    iso2ToIso3(temp_iso[nchar(temp_iso) <3])
  dimnames(m_countries$temp)[[3]][temp_iso |> is.na() |> not()] <- 
    temp_iso[temp_iso |> is.na() |> not()]
  dimnames(m_countries$temp)[[4]][temp_iso |> is.na() |> not()] <- 
    temp_iso[temp_iso |> is.na() |> not()]
  
    
  # fill lists
  list_years <- 
    unique(c(list_years, rownames(sea_countries$temp[,1,])))
  
  list_sea_variables <- 
    unique(c(list_sea_variables, rownames(sea_countries$temp[1,,])))

  list_countries <- 
    unique(c(list_countries, names(sea_countries$temp[1,1,])))

  # Rename method
  names(sea_countries)[names(sea_countries) == "temp"] <- parameters$code
  names(sea_sectors)[names(sea_sectors) == "temp"] <- parameters$code
  names(m_countries)[names(m_countries) == "temp"] <- parameters$code
  
  # Save methods parameters
  meta_methods <- rbind(meta_methods,parameters)
}

if (!length(meta_indicator_contract_parts)) {
  stop("No result method has usable display metadata.", call. = FALSE)
}

list_methods <- names(sea_countries)

## Merge all data
sea_countries_merge <- array(data = NA, dim = c(length(list_methods),
                                                length(list_years),
                                                length(list_sea_variables),
                                                length(list_countries)),
                             dimnames = list(list_methods,
                                             list_years,
                                             list_sea_variables,
                                             list_countries))

for (x in list_methods){
  sea_countries_merge[x,
                      match(names(sea_countries[[x]][,1,1]), list_years),
                      match(names(sea_countries[[x]][1,,1]), list_sea_variables),
                      match(names(sea_countries[[x]][1,1,]), list_countries)] <- 
    sea_countries[[x]]
}

# Eliminates data from years 2008 and 2009 of WIOD13 for lack of capital stock data
sea_countries_merge["WIOD13",c("2008","2009"),,] <- NA
sea_sectors[["WIOD13"]][c("2008","2009"),,,] <- NA
m_countries[["WIOD13"]][c("2008","2009"),,,] <- NA

# write data
sea_countries_merge |> saveRDS("data/sea_countries.RDS")
sea_sectors |> saveRDS("data/sea_sectors.RDS")
m_countries |> saveRDS("data/m_countries.RDS")
meta_methods |> saveRDS("data/meta_methods.RDS")
meta_indicator_contracts <- wlv_bind_display_contracts(
  meta_indicator_contract_parts
)
wlv_validate_display_contract_coverage(
  meta_indicator_contracts,
  wlv_method_indicator_availability(sea_sectors, indicator_axis = 2L)
)
meta_indicator_contracts |> saveRDS("data/meta_indicator_contracts.RDS")

sea_countries <- sea_countries_merge

# Prepare geospatial data
countries_polygons <- 
  getMap()

sp_data <- countries_polygons@data[,c("ISO3","NAME")]
sp_data$layerId <- NA
sp_data$data <- NA
sp_data$raw_data <- NA

countries_polygons@data <- sp_data

countries_sp <- NULL
countries_sp[list_methods] <- 
  lapply(
    list_methods,
    function(i) {
      # Select countries with at least one observation in any year/indicator.
      method_data <- sea_countries[i,,,, drop = FALSE]
      has_data <- wlv_observed_axis_labels(method_data, 4L)
      mydata <- countries_polygons[countries_polygons@data$ISO3 %in%
                                    has_data,]
      mydata@data$layerId <- 
        paste0(i,".",mydata@data$ISO3)
      mydata
    })

countries_sp |> saveRDS("data/countries_sp.RDS")

# The global metadata remains legacy for labels, grouping and colour direction.
# Unit and display fields live in `meta_indicator_contracts`, keyed by method.
meta_indicators |> saveRDS("data/meta_indicators.RDS")

method_description <- NULL
method_description$first <- meta_methods$description
method_description$second <- meta_methods$description
method_description <- method_description |> as.data.frame()
rownames(method_description) <- paste0("DESC.",meta_methods$code)
colnames(method_description) <- colnames(language_file)

language_file <- rbind(language_file, method_description)
language_file |> saveRDS("data/language_file.RDS")
