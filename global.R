#####
## global.R:
## Painel para exibição dos dados do Banco de Dados Valor Trabalho Mundial
## - Leitura dos dados
## - Preparação das variáveis para exibição
#####

## Carrega pacotes
source("requ.R")

## Carrega os dados
######
paises <- read.csv2(file = "dados/paises.csv", row.names = 1, check.names = F)
num_paises <- dim(paises)[1]

sea_paises <- readRDS(file = "dados/sea_paises.rds")
m_paises_13 <- readRDS(file = "dados/m_paises_13.rds")
m_paises_16 <- readRDS(file = "dados/m_paises_16.rds")

sea_setores_13 <- readRDS(file = "dados/sea_setores_13.rds")
sea_setores_16 <- readRDS(file = "dados/sea_setores_16.rds")
sea_sectors <- NULL
sea_sectors[["WIOD13"]] <- sea_setores_13
sea_sectors[["WIOD16"]] <- sea_setores_16


m_io_13 <- readRDS(file = "dados/m_io_13.rds")
m_io_16 <- readRDS(file = "dados/m_io_16.rds")


varst <- read_csv2("dados/vars.csv")
setorest <- read_csv2("dados/setores_t.csv")
perfil_sumario <- c("taxa_exploracao","produto_total_pm","produto_total_valores","valor_forca_trabalho_total","lucro","taxa_exploracao_ocupados")
var_groups <- read.csv2("dados/var_groups.csv")
meta_var <- read.csv2("dados/meta_var.csv")

## Cria demais variáveis

lista_anos <- names(sea_paises[1,,1,1])
default_indicator <- "taxa_exploracao"


countries_polygons <- 
  getMap()
countries_polygons <- 
  countries_polygons[countries_polygons$ISO3 %in% paises$Legenda,]

lista_paises <- paises[,3]
names(lista_paises) <- paises[match(paises[,3], lista_paises),1]
lista_paises <- c("",lista_paises)
names(lista_paises)[1] <- "Search a country..."

lista_variaveis_sea <- names(sea_paises[1,1,,1])
names(lista_variaveis_sea) <- (tibble(var=lista_variaveis_sea)%>%left_join(varst, by = "var")%>%select(pt))[[1]]
# lista_variaveis_sea <- c("",lista_variaveis_sea)
# names(lista_variaveis_sea)[1] <- "Search an indicator..."

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
plotaserie <- function(dados,perc=F) {
  ##produz data.frame com cada versão para juntar
  
  if(length(dim(dados))>2){
    dados <- as.data.table(dados)
    print(head(dados))
    ifelse(ncol(dados)==5,
           names(dados) <- c("bd","ano","indicador","pais","valor"),
           names(dados) <- c("bd","ano","pais","valor")
    )
    print(dados$ano)
    dados <- dados %>% mutate(ano = as.Date(paste0("1/1/",ano),
                                            tryFormats="%d/%m/%Y"),
                              across(c(-ano,-valor),as.factor))
  }else{
    bds <- names(dados[,1])
    anos <- names(dados[1,])
    dados <- as.data.table(t(dados))
    dados$ano <- as.Date(paste0("01/01/",anos),
                         tryFormats="%d/%m/%Y")
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
source("metautils/formata.R")
source("panel_setup.R", local = TRUE)
source("panel_country_all_data.R", local = TRUE)
source("panel_indicators.R", local = TRUE)


