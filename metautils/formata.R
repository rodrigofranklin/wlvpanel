##Formata SEA Países:

  ogpera <- function(x,qual = 0) {
    sbrubles <- ifelse(qual == 0, sea_paises[,,x,],
                       ifelse(qual == 1,sea_sectors$WIOD13[,x,,],
                   sea_sectors$WIOD16[,x,,]))
    if(varst[x,]$type == "percent") {
      round(sbrubles*rep(100,length(sbrubles)),2)
    }
    else if (varst[x,]$type != "exchange"){
      round(sbrubles/rep(1e6,length(sbrubles)),3)
    }
    else {sbrubles}
  }
  

for (i in 1:length(names(sea_paises[1,1,,1]))) {
  
  sea_paises[,,i,] <- ogpera(i)
  sea_sectors$WIOD13[,i,,] <- ogpera(i,1)
  sea_sectors$WIOD16[,i,,] <- ogpera(i,2)
}




