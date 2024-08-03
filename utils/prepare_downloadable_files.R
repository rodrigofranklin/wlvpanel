#####################################################
#### Prepare files for download.
#####################################################

library(openxlsx)
library(magrittr)

ind_type <- function(x){
  substr(x, nchar(x)-1, nchar(x))
}

# Function to save data to a xlsx file
save_my_xlsx <- function(file_name, header, row_names, my_data, metadata, specs,
                         rows_style_list, styles_list, width_c1, width_c2) {

  ## create and format xlsx file
  wb <- createWorkbook()
  addWorksheet(wb, "data")
  addWorksheet(wb, "metadata")
  addWorksheet(wb, "specs")

  # data
  writeData(wb, "data",
            row_names,
            startRow = 7,
            colNames = FALSE)
  
  writeData(wb, "data",
            my_data,
            startCol = 2,
            startRow = 6,
            rowNames = TRUE)
  
  # header
  writeData(wb, "data",
            header,
            colNames = FALSE)
  
  cols <- ncol(my_data)+2

  # format Header
  freezePane(wb, "data", 7, 3)
  addStyle(wb, "data", rows = 1:4, cols = rep(1,4),
           style = createStyle(halign = "right"))
  addStyle(wb, "data", rows = 1:4, cols = rep(2,4),
           style = createStyle(textDecoration = "bold"))
  addStyle(wb, "data", rows = rep(6,cols) , cols = 1:cols,
           style = createStyle(halign = "center", textDecoration = "bold"))
  
  # format lines
  for (i in 1:length(styles_list)) {
    addStyle(wb, "data", gridExpand = TRUE,
             rows = rows_style_list[i] |> unlist(),
             cols = 3:cols,
             style = createStyle(numFmt = styles_list[i] |> unlist()))
  }
  
  temp_data <- my_data |> round(digits = 2)
  width_vec <- apply(temp_data, 2, function(x) max(nchar(as.character(x))+4, na.rm = TRUE))
  width_vec[is.infinite(width_vec)] <- "4"
  setColWidths(wb, "data", 3:cols, width_vec)
  setColWidths(wb, "data", cols = 1, widths = width_c1)
  setColWidths(wb, "data", cols = 2, widths = width_c2)
  
  # metadata
  writeData(wb, "metadata", metadata)
  
  # Methods specifications
  writeData(wb, "specs", specs)
  
  # save file
  saveWorkbook(wb, file_name, overwrite = TRUE)
}

## Read data
meta_methods <- readRDS("data/meta_methods.RDS")
indicator_en <- read.csv2("data/config/indicators_en.csv")
sea_countries <- readRDS("data/sea_countries.RDS")
sea_sectors <- readRDS("data/sea_sectors.RDS")
language_file <- readRDS("data/language_file.RDS")
m_countries <- readRDS("data/m_countries.RDS")

### create files for each method ####
for (method_code in meta_methods$code) {
  method_name <- meta_methods$name[meta_methods$code==method_code]
  sourcedata <- meta_methods$source[meta_methods$code==method_code]
  specs <- meta_methods[meta_methods$code==method_code,
                        c("name","code","source","description")]
  
  # select only countries and indicators with data
  temp_data <- sea_countries[method_code,,,]
  years <- temp_data[,1,1] |> names()
  years <- years[temp_data[,1,1] |> is.na() |> not()]
  countries <- temp_data[,1,] |> colnames()
  countries <- countries[temp_data[,1,] |> colSums(na.rm = TRUE) !=0]
  indicators <- temp_data[,,1] |> colnames()
  indicators <- indicators[temp_data[,,1] |> colSums(na.rm = TRUE) !=0]
  indicators <- indicators[order(indicators)]
  sectors <- names(sea_sectors[[method_code]][1,1,,1])
  countries_sectors <- names(sea_sectors[[method_code]][1,1,1,])
  
  # meta_indicators
  indicators_names <- language_file[indicators,"English"]
  indicators_descriptions <- language_file[paste0("desc.",indicators),"English"]
  indicators_observations <- language_file[paste0("obs.",method_code,".",indicators),"English"]
  meta_indicators <- cbind(indicators,
                           indicators_names,
                           indicators_descriptions,
                           indicators_observations) |> data.frame()
  colnames(meta_indicators) <- c("Code", "Name", "Description", "Observations")
  types <- indicators |> ind_type()
  rows_list <- NULL
  rows_list$percentage <- which(types=="pc")+6
  rows_list$float <- which(types %in% c("us", "cu", "du", "mv", "hr", "id")) + 6
  rows_list$int <- which(types=="un")+6
  
  styles_list <- NULL
  styles_list$percentage <- "PERCENTAGE"
  styles_list$float <- "#,##0.00"
  styles_list$int <- "#,##0"

  # countries and sectors names
  countries_names <- language_file[paste0("ISO3.",countries),"English"]
  sectors_names <- language_file[paste0(sourcedata,".",sectors),"English"]

  ##### Country files (aggregated and sectors) ####
  for (country_code in countries) {
    ### Aggregated data
    country_data <- 
      t(sea_countries[method_code,
                      years,
                      indicators,
                      country_code])
    country_name <- language_file[paste0("ISO3.",country_code),"English"]
    
    file_name <-  paste0(
      "data/download/",
      country_code,".",
      method_code,".xlsx")
    
    header <- rbind(c("Country:",country_name),
                    c("Computation method:",method_name),
                    c("Main source:",sourcedata),
                    NA, NA,
                    c("indicator", "code"))

    save_my_xlsx(file_name, header, indicators_names, country_data, 
                 meta_indicators, specs, rows_list, styles_list, 35, 35)

    if (country_code %in% countries_sectors |> not()) {
      next
    }
    
    ### Sectors data
    sectors_data <- 
      sea_sectors[[method_code]][,order(names(sea_sectors[[method_code]][1,,1,1])),
                                 ,country_code]
    
    indicators_sectors <- colnames(sectors_data)
    indicators_sectors_names <- language_file[indicators_sectors,"English"]
    
    ### Data by sectors 
    for (sector_code in sectors) {
      sector_name <- language_file[paste0(sourcedata,".", sector_code),"English"]
      
      sector_data <- t(sectors_data[,,sector_code])

      file_name <-  paste0(
        "data/download/",
        country_code,".",
        sector_code,".",
        method_code,".xlsx")
      
      header <- rbind(c("Country:",country_name),
                      c("Sector:",sector_name),
                      c("Computation method:",method_name),
                      c("Main source:",sourcedata),
                      NA,
                      c("indicator", "code"))
      
      save_my_xlsx(file_name, header, indicators_sectors_names, sector_data, 
                   meta_indicators, specs, rows_list, styles_list, 35, 35)
    }

    ### Country and indicator files (sectorial data) ####
    for (indicator_code in indicators_sectors) {
      
      indicator_name <- language_file[indicator_code,"English"]
      
      sector_data <- t(sectors_data[,indicator_code,])
      
      file_name <-  paste0(
        "data/download/",
        country_code,".",
        indicator_code,".",
        method_code,".xlsx")
      
      header <- rbind(c("Country:",country_name),
                      c("Indicator:",indicator_name),
                      c("Computation method:",method_name),
                      c("Main source:",sourcedata),
                      NA,
                      c("sector", "code"))
      
      id_type <- ind_type(indicator_code)
      if (id_type=="pc") {
        id_style <- "PERCENTAGE"
      } else if (id_type %in% c("us", "cu", "du", "mv", "hr", "id")) {
        id_style <- "#,##0.00"
      } else {
        id_style <- "#,##0"
      }
      
      rows <- NULL
      rows$list <- 1:nrow(sector_data)+6
      
      save_my_xlsx(file_name, header, sectors_names, sector_data, 
                   meta_indicators[meta_indicators$Code == indicator_code,],
                   specs, rows, id_style, 35, 8)
    }
  }
  
  #### Indicator files ####
  for (indicator_code in indicators) {
    indicator_data <- t(sea_countries[method_code,
                                      years,
                                      indicator_code,
                                      countries])
    
    indicator_name <- language_file[indicator_code,"English"]
    
    file_name <-  paste0(
      "data/download/",
      indicator_code,".",
      method_code,".xlsx")
    
    header <- rbind(c("Indicator:",indicator_name),
                    c("Computation method:",method_name),
                    c("Main source:",sourcedata),
                    NA, NA,
                    c("Country", "ISO3"))
    
    id_type <- ind_type(indicator_code)
    if (id_type=="pc") {
      id_style <- "PERCENTAGE"
    } else if (id_type %in% c("us", "cu", "du", "mv", "hr", "id")) {
      id_style <- "#,##0.00"
    } else {
      id_style <- "#,##0"
    }
    
    rows <- NULL
    rows$list <- 1:nrow(sector_data)+6
    
    save_my_xlsx(file_name, header, countries_names, indicator_data, 
                 meta_indicators[meta_indicators$Code == indicator_code,],
                 specs, rows, id_style, "auto", 6)

    ### Sectorial data
    sectors_data <- 
      sea_sectors[[method_code]][,indicator_code,,]
    
    ### Sector and indicator files ####
    for (sector_code in sectors) {
      
      sector_name <- language_file[paste0(sourcedata,".", sector_code),"English"]
      
      sector_data <- t(sectors_data[,sector_code,])
      
      file_name <-  paste0(
        "data/download/",
        indicator_code,".",
        sector_code,".",
        method_code,".xlsx")
      
      header <- rbind(c("Indicator:",indicator_name),
                      c("Sector:",sector_name),
                      c("Computation method:",method_name),
                      c("Main source:",sourcedata),
                      NA,
                      c("Country", "ISO3"))
      
      id_type <- ind_type(indicator_code)
      if (id_type=="pc") {
        id_style <- "PERCENTAGE"
      } else if (id_type %in% c("us", "cu", "du", "mv", "hr", "id")) {
        id_style <- "#,##0.00"
      } else {
        id_style <- "#,##0"
      }
      
      rows <- NULL
      rows$list <- 1:nrow(sector_data)+6
      
      save_my_xlsx(file_name, header, countries_names, sector_data, 
                   meta_indicators[meta_indicators$Code == indicator_code,],
                   specs, rows, id_style, "auto", 6)
    }
  }
}


###### MULTILATERAL RELATIONS ####

# we can compute indicators of all combinations between:
# categories: 
#  - Export (CX), Import (CM) e Net (CN) of commodities trades;
#  - Transfer sent (TS), Transfers received (TR) and Net Transfers (TT) of Value
#
# Scope: Total (T), just Productive sectors (P) or just Unproductive sectors (U)
#
# Measure unit: Market Prices (MP), Direct Prices (DP) or Magnitude of Value (MV)

indicator_cat <- c("CX","CM","CN","TS","TR","TT")
indicator_scope <- c("T","P","U")
indicator_un <- c("MP","DP","MV")

indicators <- paste0(indicator_cat, ".",indicator_scope |> rep(each = indicator_cat|> length()))
indicators <- paste0(indicators, ".",indicator_un |> rep(each = indicators|> length()))
indicators <- indicators[order(indicators)]

# there are no value transfers measured by market prices
indicators <- indicators[-grep("T....MP",indicators)]
indicators_names <- indicators
indicators_names <- sub("\\.DP"," in Direct Prices (USD)", indicators_names)
indicators_names <- sub("\\.MP"," in Market Prices (USD)", indicators_names)
indicators_names <- sub("\\.MV"," in Magnitude of Value", indicators_names)
indicators_names <- sub("\\.P"," of Productive Sectors", indicators_names)
indicators_names <- sub("\\.U"," of Unproductive Sectors", indicators_names)
indicators_names <- sub("\\.U"," of Unproductive Sectors", indicators_names)
indicators_names <- sub("\\.T","", indicators_names)
indicators_names <- sub("TS","Value Transfers from exports", indicators_names)
indicators_names <- sub("TR","Value Transfers from imports", indicators_names)
indicators_names <- sub("TT","Net Value Transfers", indicators_names)
indicators_names <- sub("CX","Total Exports", indicators_names)
indicators_names <- sub("CM","Total Imports", indicators_names)
indicators_names <- sub("CN","Net Trade", indicators_names)

meta_indicators <- cbind(indicators, indicators_names) |> data.frame()
names(meta_indicators) <- c("Code", "Name")

rows <- NULL
rows$list <- 1:length(indicators)+6
id_style <- "#,##0.00"

meta_indicators |> saveRDS("data/meta_trade_indicators.RDS")

### create files for each method ####
for (method_code in meta_methods$code) {
  method_name <- meta_methods$name[meta_methods$code==method_code]
  sourcedata <- meta_methods$source[meta_methods$code==method_code]
  
  temp_data <- m_countries[[method_code]]
  countries <- temp_data[1,1,,1] |> names()
  countries_names <- language_file[paste0("ISO3.",countries),"English"]
  
  countries_data <- array(data = NA, dim = c(temp_data[,1,1,1] |> length(),
                                             indicators |> length(),
                                             countries |>length(),
                                             countries |>length()),
                          dimnames = list(temp_data[,1,1,1] |> names(),
                                          indicators,
                                          countries,
                                          countries))

  countries_data[,"CX.T.MV",,] <- temp_data[,"exports_values",,]
  countries_data[,"CX.T.MP",,] <- temp_data[,"exports_mp",,]
  countries_data[,"CX.P.MP",,] <- temp_data[,"exports_productive_mp",,]
  countries_data[,"TS.T.MV",,] <- temp_data[,"transfers_values",,]
  countries_data[,"TS.T.DP",,] <- temp_data[,"transfers_dp",,]
  countries_data[,"TS.P.MV",,] <- temp_data[,"transfers_productive_values",,]
  countries_data[,"TS.P.DP",,] <- temp_data[,"transfers_productive_dp",,]

  balance_factor <-
    countries_data[,"CX.P.MP",,] |> apply(1, sum) /
    countries_data[,"CX.T.MV",,] |> apply(1, sum)
  
  countries_data[,"CX.T.DP",,] <- 
    countries_data[,"CX.T.MV",,] * 
    balance_factor |> rep(times = countries |>length() * countries |>length())

  countries_data[,"CX.P.MV",,] <- countries_data[,"CX.T.MV",,]
  countries_data[,"CX.P.DP",,] <- countries_data[,"CX.T.DP",,]

  countries_data[,"CM.T.MV",,] <- countries_data[,"CX.T.MV",,] |> aperm(c(1,3,2))
  countries_data[,"CM.P.MV",,] <- countries_data[,"CX.P.MV",,] |> aperm(c(1,3,2))
  countries_data[,"CM.T.DP",,] <- countries_data[,"CX.T.DP",,] |> aperm(c(1,3,2))
  countries_data[,"CM.P.DP",,] <- countries_data[,"CX.P.DP",,] |> aperm(c(1,3,2))
  countries_data[,"CM.T.MP",,] <- countries_data[,"CX.T.MP",,] |> aperm(c(1,3,2))
  countries_data[,"CM.P.MP",,] <- countries_data[,"CX.P.MP",,] |> aperm(c(1,3,2))
  countries_data[,"TR.T.MV",,] <- countries_data[,"TS.T.MV",,] |> aperm(c(1,3,2))
  countries_data[,"TR.P.MV",,] <- countries_data[,"TS.P.MV",,] |> aperm(c(1,3,2))
  countries_data[,"TR.T.DP",,] <- countries_data[,"TS.T.DP",,] |> aperm(c(1,3,2))
  countries_data[,"TR.P.DP",,] <- countries_data[,"TS.P.DP",,] |> aperm(c(1,3,2))
  
  countries_data[,"CX.U.MV",,] <- 0
  countries_data[,"CX.U.DP",,] <- 0
  countries_data[,"CX.U.MP",,] <- countries_data[,"CX.T.MP",,] - countries_data[,"CX.P.MP",,]
  countries_data[,"CM.U.MV",,] <- 0
  countries_data[,"CM.U.DP",,] <- 0
  countries_data[,"CM.U.MP",,] <- countries_data[,"CM.T.MP",,] - countries_data[,"CM.P.MP",,]
  countries_data[,"TS.U.MV",,] <- countries_data[,"TS.T.MV",,] - countries_data[,"TS.P.MV",,]
  countries_data[,"TS.U.DP",,] <- countries_data[,"TS.T.DP",,] - countries_data[,"TS.P.DP",,]
  countries_data[,"TR.U.MV",,] <- countries_data[,"TR.T.MV",,] - countries_data[,"TR.P.MV",,]
  countries_data[,"TR.U.DP",,] <- countries_data[,"TR.T.DP",,] - countries_data[,"TR.P.DP",,]
  
  countries_data[,"CN.T.MV",,] <- countries_data[,"CX.T.MV",,] - countries_data[,"CM.T.MV",,]
  countries_data[,"CN.P.MV",,] <- countries_data[,"CX.P.MV",,] - countries_data[,"CM.P.MV",,]
  countries_data[,"CN.U.MV",,] <- countries_data[,"CX.U.MV",,] - countries_data[,"CM.U.MV",,]
  countries_data[,"CN.T.DP",,] <- countries_data[,"CX.T.DP",,] - countries_data[,"CM.T.DP",,]
  countries_data[,"CN.P.DP",,] <- countries_data[,"CX.P.DP",,] - countries_data[,"CM.P.DP",,]
  countries_data[,"CN.U.DP",,] <- countries_data[,"CX.U.DP",,] - countries_data[,"CM.U.DP",,]
  countries_data[,"CN.T.MP",,] <- countries_data[,"CX.T.MP",,] - countries_data[,"CM.T.MP",,]
  countries_data[,"CN.P.MP",,] <- countries_data[,"CX.P.MP",,] - countries_data[,"CM.P.MP",,]
  countries_data[,"CN.U.MP",,] <- countries_data[,"CX.U.MP",,] - countries_data[,"CM.U.MP",,]
  countries_data[,"TT.T.MV",,] <- countries_data[,"TR.T.MV",,] - countries_data[,"TS.T.MV",,]
  countries_data[,"TT.P.MV",,] <- countries_data[,"TR.P.MV",,] - countries_data[,"TS.P.MV",,]
  countries_data[,"TT.U.MV",,] <- countries_data[,"TR.U.MV",,] - countries_data[,"TS.U.MV",,]
  countries_data[,"TT.T.DP",,] <- countries_data[,"TR.T.DP",,] - countries_data[,"TS.T.DP",,]
  countries_data[,"TT.P.DP",,] <- countries_data[,"TR.P.DP",,] - countries_data[,"TS.P.DP",,]
  countries_data[,"TT.U.DP",,] <- countries_data[,"TR.U.DP",,] - countries_data[,"TS.U.DP",,]
  
  for (country_code in countries) {
    country_name <- language_file[paste0("ISO3.",country_code),"English"]
    
    # Country - Country files
    for (partner_code in countries) {
      if (partner_code == country_code) next
      partner_data <- countries_data[,,country_code,partner_code] |> t()
      partner_name <- language_file[paste0("ISO3.",partner_code),"English"]
      
      file_name <-  paste0(
        "data/download/",
        country_code,".",
        partner_code,".",
        method_code,".xlsx")
      
      header <- rbind(c("Country:",country_name),
                      c("Partner:",partner_name),
                      c("Computation method:",method_name),
                      c("Main source:",sourcedata),
                      NA,
                      c("indicator", "code"))

      save_my_xlsx(file_name, header, indicators_names, partner_data, 
                   meta_indicators, specs, rows, id_style, 35, 8.57)
    }
    
    # Country - indicators files
    for (indicator_code in indicators) {
      trade_data <- countries_data[,indicator_code,country_code,] |> t()
      indicator_name <- meta_indicators$Name[meta_indicators$Code==indicator_code]
      
      file_name <-  paste0(
        "data/download/",
        country_code,".",
        indicator_code,".",
        method_code,".xlsx")
      
      header <- rbind(c("Country:",country_name),
                      c("Indicator:",indicator_name),
                      c("Computation method:",method_name),
                      c("Main source:",sourcedata),
                      NA,
                      c("Country", "ISO3"))
      
      save_my_xlsx(file_name, header, countries_names, trade_data, 
                   meta_indicators[meta_indicators$Code == indicator_code,],
                   specs, rows, id_style, "auto", 6)
    }
  }
}

