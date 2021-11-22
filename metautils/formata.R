##Formata SEA Países:

  ogpera <- function(x,qual = 0) {
    if(qual == 0) {
      sbrubles <- sea_paises[,,x,]
      }
    else if (qual == 1) {
                       
      sbrubles <- sea_sectors$WIOD13[,x,,]
      } else {
        sbrubles <- sea_sectors$WIOD16[,x,,]
      }
    print(str(sbrubles))
    if(varst[x,]$type == "percent") {
      a <- round(sbrubles*rep(100,length(sbrubles)),2)
    }
    else if (varst[x,]$type != "exchange"){
      a <- round(sbrubles/rep(1e6,length(sbrubles)),3)
    }
    else {a <- sbrubles}
    a
  }
  

for (i in 1:length(names(sea_paises[1,1,,1]))) {
  
  sea_paises[,,i,] <- ogpera(i)
  sea_sectors$WIOD13[,i,,] <- ogpera(i,1)
  if(i<24){sea_sectors$WIOD16[,i,,] <- ogpera(i,2)}
}




