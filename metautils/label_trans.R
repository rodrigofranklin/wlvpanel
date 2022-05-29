1#traducao automática dos elementos
##Translated  var /colnames  Dictionary
library(magrittr)
library(googlesheets4)
library(tidyverse)

#1) Abre a base - portugues
base <- read_csv2("dados/label_pt-br.csv")

nomplan <- paste0(Sys.Date(),"-labvalpanel")
#Lista de id  iomas
idiomas <- c("en","es","fr","zh-CN")

coltrad <- function(xaxa) {
  b <- base%>% 
    transmute(a = 
             paste0('=googletranslate(B:B;"pt";"',xaxa,'")')) 
  renom <- paste0("label_",xaxa)
    b <- rename_with(b,~ gsub("a",renom,.x),starts_with("a"))
}
#2) Envia para a tradução automática do Google
base <- bind_cols(base,lapply( idiomas,coltrad))


base %<>% mutate(across(contains("label_"),gs4_formula))

gs4_create(nomplan,sheets = base)

trad <- gs4_get(gs4_find(nomplan)) %>% read_sheet()
#4) Separa nos arquivos correspondentes

subsave <- function(idiom,x) {
  a <- x%>%
    select(1,contains(paste0("_",idiom)))
  names(a) <- names(x)[1:2]
  write_csv2(a,paste0("dados/label_",idiom,".csv"))
}
  
lapply(idiomas,subsave,trad)
#5) Salva em csv separado por ponto e vírgula
