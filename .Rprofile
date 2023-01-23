Sys.umask("002")
library(utils)
#automatizado baseado em requ.R
pacotes <-  gsub(")","",read.delim("requirements.R",sep = "(", header = F)[[2]])

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

