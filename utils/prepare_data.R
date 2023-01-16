# Prepare data for panel
# All computations need to be done here

library(dplyr)
library(magrittr)
library(MazamaSpatialUtils)
library(rworldmap)

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

# Indicators names and description
indicator_file <- read.csv2(paste0("data/config/indicators_",languages$file[1],".csv"))
for (x in 1:length(languages$language)) {
  I_temp <-  read.csv2(paste0("data/config/indicators_",languages$file[1],".csv"))
  names(I_temp)[2] <- languages$language[x]
  indicator_file <- full_join(indicator_file, I_temp, by = "cod_label")
}

rownames(indicator_file) <- indicator_file[,1]
indicator_file <- indicator_file[,-c(1,2)]
language_file <- rbind(language_file,indicator_file)

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

## Select methods that has parameters
method_list <- gsub("results/","",list.dirs("results",recursive = F))
method_parameters <- paste0("results/",method_list, "/_parameters.csv")
method_list <- method_list[file.exists(method_parameters)]

## Load data from all methods
## and create lists of arrays dimensions
sea_countries <- NULL
sea_sectors <- NULL
m_countries <- NULL
list_years <- NULL
list_sea_variables <- NULL
list_countries <- NULL
meta_methods <- NULL

for (x in method_list) {

  # load data
  parameters <- read.csv2(paste0("results/",x,"/_parameters.csv"))
  
  sea_countries$temp <- read_fst_array(file = paste0("results/",x,"/sea_countries.fst"))
  sea_sectors$temp <- read_fst_array(file = paste0("results/",x,"/sea_sectors.fst"))
  m_countries$temp <- read_fst_array(file = paste0("results/",x,"/m_countries.fst"))
  
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

# write data
sea_countries_merge |> saveRDS("data/sea_countries.RDS")
sea_sectors |> saveRDS("data/sea_sectors.RDS")
m_countries |> saveRDS("data/m_countries.RDS")
meta_methods |> saveRDS("data/meta_methods.RDS")

sea_countries <- sea_countries_merge

# Prepare geospatial data
countries_polygons <- 
  getMap()

sp_data <- countries_polygons@data[,c("ISO3","NAME")]
sp_data$layerId <- NA
sp_data$data <- NA

countries_polygons@data <- sp_data

countries_sp <- NULL
countries_sp[list_methods] <- 
  lapply(
    list_methods,
    function(i) {
      # Select all countries that has any data for the first indicator
      has_data <- sea_countries[i,,1,] |> colSums(na.rm = TRUE)
      has_data <- has_data[has_data !=0 ]
      mydata <- countries_polygons[countries_polygons@data$ISO3 %in%
                                    names(has_data),]
      mydata@data$layerId <- 
        paste0(i,".",mydata@data$ISO3)
      mydata
    })

countries_sp |> saveRDS("data/countries_sp.RDS")

# Meta indicators
# We need to get this information directly from methods. But, for now,
# we are going to get this from a .csv

meta_indicators <- read.csv2("data/config/meta_indicators.csv")
meta_indicators <- meta_indicators[order(meta_indicators$groups),]
meta_indicators |> saveRDS("data/meta_indicators.RDS")
