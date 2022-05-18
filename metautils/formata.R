##Formata SEA Países:

  ogpera <- function(x,sbrubles) {
    if(varst[varst$var==x,]$type == "percent") {
      a <- round(sbrubles*rep(100,length(sbrubles)),2)
    }
    else if (varst[varst$var==x,]$type != "exchange"){
      a <- round(sbrubles/rep(1e6,length(sbrubles)),3)
    }
    else {a <- sbrubles}
    a
  }
  

for (i in lista_variaveis_sea) {
  sea_paises[,,i,] <- ogpera(i,sea_paises[,,i,])
}

for (versao in lista_versoes) {
  for (i in names(sea_sectors[[versao]][1,,1,1])) {
    sea_sectors[[versao]][,i,,] <- ogpera(i,sea_sectors[[versao]][,i,,])
  }
}