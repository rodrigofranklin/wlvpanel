#####
## global.R:
## Painel para exibição dos dados do Banco de Dados Valor Trabalho Mundial
## - Leitura dos dados
## - Preparação das variáveis para exibição
#####
shinyOptions(cache = cachem::cache_disk("dados/labourvaluesdatapanel-cache/")) 

## Carrega pacotes
source("requ.R")

# ##Registra um cluster
# if(.Platform$OS.type == "unix") {
#   my.cluster <-  makeCluster(detectCores() - 1,type="FORK",outfile="dados/logs/parallelworkers.log",
#                              envir=globalenv())
# } else {
#   assign("my.cluster",parallel::makeCluster(
#     parallel::detectCores() - 1, 
#     type = "PSOCK"), envir=globalenv())
# }

## Carrega os dados
######
bascomind <- "WIOD13"
paises <- read.csv2(
  file = "dados/paises.csv", 
  row.names = 1, 
  check.names = F, 
  encoding = "UTF-8")

num_paises <- dim(paises)[1]

sea_paises <- readRDS(file = "dados/sea_paises.rds")

m_paises_13 <- readRDS(file = "dados/m_paises_13.rds")
m_paises_16 <- readRDS(file = "dados/m_paises_16.rds")

sea_sectors <- readRDS("dados/sea_sectors.rds")

m_io_13 <- readRDS(file = "dados/m_io_13.rds")
m_io_16 <- readRDS(file = "dados/m_io_16.rds")

varst <- read.csv2("dados/vars.csv", encoding = "UTF-8")
setorest <- read.csv2("dados/setores_t.csv", encoding = "UTF-8")
setolang <- read.csv2("dados/setolang.csv")
var_groups <- read.csv2("dados/var_groups.csv", encoding = "UTF-8")
meta_var <- read.csv2("dados/meta_var.csv", encoding = "UTF-8")

perfil_sumario <- meta_var[!is.na(meta_var$order),]
perfil_sumario <- perfil_sumario[order(perfil_sumario$order),1]

## Cria demais variáveis

lista_anos <- names(sea_paises[1,,1,1])
default_indicator <- "surplus_value.empe.r.pc"


countries_polygons <- 
  getMap()
countries_polygons <- 
  countries_polygons[countries_polygons$ISO3 %in% paises$Legenda,]

lista_paises <- paises[,2]
names(lista_paises) <- rownames(paises)
lista_paises <- c("",lista_paises)
names(lista_paises)[1] <- "Search a country..."

lista_variaveis_sea <- names(sea_paises[1,1,,1])
names(lista_variaveis_sea) <- (tibble(var=lista_variaveis_sea)%>%left_join(varst, by = "var")%>%select(pt))[[1]]

ano_min <- as.numeric(lista_anos[1])
ano_max <- as.numeric(last(lista_anos))

agregado <- function(matriz, ano, var, pais) {
  matriz[as.character(ano), var, pais, ]
}

limitar_colunas <- function(matriz, colunas) {
  matriz[, colunas]
}

encontrar_pais <- function(matriz, pais, fun) {
  matriz[1,1, , ] %>% 
    fun() %>% 
    str_which(pais)
}

## Funções a reutilizar
abrevia <- function(frase, tmax = 22) {
  escmax <- function(frase,minim = tmax) {
    f <- substr(frase,start = 1, stop = min(nchar(frase),minim))
    f
  }
  f <- escmax(frase)
  f <- unlist(strsplit(f,' ',fixed = T))
  f <- c(f,"...")
  f <- paste(sapply(f,escmax,minim=4),collapse =". ")
  f
}
plotaserie <- function(dados,perc=F) {
  ##produz data.frame com cada versão para juntar
  
  if(length(dim(dados))>2){
    dados <- as.data.table(dados)
    ifelse(ncol(dados)==5,
           names(dados) <- c("bd","ano","indicador","pais","valor"),
           names(dados) <- c("bd","ano","pais","valor")
    )
    dados <- dados %>% mutate(ano = as.Date(paste0(ano,"/01/01"),
                                            tryFormats="%Y/%m/%d"),
                              across(c(-ano,-valor),as.factor))
  }else{
    bds <- names(dados[,1])
    anos <- names(dados[1,])
    dados <- as.data.table(t(dados))
    dados$ano <- as.Date(paste0(anos,"/01/01"),
                         tryFormats="%Y/%m/%d")
    dados <- dados%>%pivot_longer(-ano,names_to = "bd",values_to="valor")%>%
      mutate(bd=as.factor(bd))
  }
  
  ifelse(ncol(dados)==3,
         p <- ggplot(dados,aes(x=ano,y=valor,col=bd)),
         p <- ggplot(dados,aes(x=ano,y=valor,col=pais,linetype=bd)))
  p <- p+geom_line(size = 1)  +
    geom_line(size = 1) +
    geom_point(colour = "white", pch = 21, size = 1.5)+
    theme_classic() +
    theme(axis.title = element_blank(),
          axis.line = element_blank(),
          axis.ticks = element_blank(),
          axis.text = element_text(size = 8, colour = "grey60"),
          legend.position='none')
  

  ps <- ggplotly(p)

}

milhares <- function(x){prettyNum(x,big.mark = ".",decimal.mark = ",")}

tabmil <- function(x) {
  x <- as.data.table(x,keep.rownames="var") %>%
    mutate(across(where(is.numeric),milhares))
}

# The single argument to this function, points, is a data.frame in which:
#   - column 1 contains the longitude in degrees
#   - column 2 contains the latitude in degrees
coords2country = function(points)
{  
  countriesSP <- getMap(resolution='low')
  #countriesSP <- getMap(resolution='high') #you could use high res map from rworldxtra if you were concerned about detail
  
  # convert our list of points to a SpatialPoints object
  
  # pointsSP = SpatialPoints(points, proj4string=CRS(" +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0"))
  
  #setting CRS directly to that from rworldmap
  pointsSP = SpatialPoints(points, proj4string=CRS(proj4string(countriesSP)))  
  
  
  # use 'over' to get indices of the Polygons object containing each point 
  indices = over(pointsSP, countriesSP)
  
  
  # return the ADMIN names of each country
  #indices$ADMIN
  indices$ISO3 
  #indices$ISO3 # returns the ISO3 code 
  #indices$continent   # returns the continent (6 continent model)
  #indices$REGION   # returns the continent (7 continent model)
}

# source("country_tp_panel.R", local = TRUE)
source("panel_setup.R", local = TRUE)
source("metautils/formata.R")
source("panel_country_all_data.R", local = TRUE)
source("panel_indicators.R", local = TRUE)


