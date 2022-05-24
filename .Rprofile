  pacotes <-  c("ggplot2","zoo","readxl","tidyverse","dplyr","tidyr","plotly","lubridate","readODS",
                "shiny","shinydashboard","dashboardthemes","treemap","rnaturalearth","plotly","data.table","doParallel")
pacotesnovos <- pacotes[ !( pacotes %in% utils::installed.packages()[ , "Package" ] ) ]
if( length( pacotesnovos ) ) utils::install.packages( pacotesnovos )
 

 sapply(pacotes, function (x) {
   suppressPackageStartupMessages(require(x[[1]],character.only = T))}) 
rm(pacotes)

cat(
"

        Bemvindo ao Painel de Valores Trabalho Mundiais\n
    Bienvenido al Panel de Datos de Valores-Trabajo Mundiales\n
           Welcome to World Labour Values Datapanel\n\n\n")

