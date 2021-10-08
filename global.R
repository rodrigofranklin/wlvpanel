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

m_io_13 <- readRDS(file = "dados/m_io_13.rds")
m_io_16 <- readRDS(file = "dados/m_io_16.rds")


varst <- read_csv2("dados/vars.csv")
setorest <- read_csv2("dados/setores_t.csv")
perfil_sumario <- c("taxa_exploracao","produto_total_pm","produto_total_valores","valor_forca_trabalho_total","lucro","taxa_exploracao_ocupados")
var_groups <- read.csv2("dados/var_groups.csv")
meta_var <- read.csv2("dados/meta_var.csv")

## Cria demais variáveis

lista_versoes <- names(sea_paises[,1,1,1])
lista_anos <- names(sea_paises[1,,1,1])

lista_paises <- paises[,3]
names(lista_paises) <- paises[match(paises[,3], lista_paises),1]
lista_paises <- c("",lista_paises)
names(lista_paises)[1] <- "Search a country..."

lista_variaveis_sea <- names(sea_paises[1,1,,1])
names(lista_variaveis_sea) <- (tibble(var=lista_variaveis_sea)%>%left_join(varst)%>%select(pt))[[1]]
lista_variaveis_sea <- c("",lista_variaveis_sea)
names(lista_variaveis_sea)[1] <- "Search an indicator..."

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

graphPanel <- function (indicator, panel_top, panel_left) {
  absolutePanel(
    class = "panel panel-default",
    top = panel_top,
    width = "34%",
    height = 250,
    style = paste0("left: calc(",panel_left,")"),
    tags$table(
      style = "
        ",
      width = "100%",
      tags$tr(
        tags$td(
          width = "100%",
          actionLink(
            inputId = paste0(indicator,"_title"),
            label = varst$pt[varst$var == indicator],
            style = "
              font-size:14px; 
              font-weight: bold;
              color: gray;
            "
          )
        ),
        tags$td(
          actionLink(
            inputId = paste0(indicator,"_info"),
            label = NULL,
            style = "
              text-align: right;
              font-size:14px; 
              color: gray;
            ",
            icon = icon("info-circle")
          )
        )
      )
    ) %>%
      div(class = "panel-heading",
          style = "background-image:none;
                  background: white;
                  padding: 3px 5px;
                  "),
    plotlyOutput(indicator, height = 220, width = "32vw") %>%
      div(class = "panel-body",
          style = "
            padding:0px;
            text-align: center;
          ")
  )
}

# Inicia variáveis
top <- 285 # posição a partir da qual os gráficos serão plotados
country_graphs <- NULL # tagList com todos os gráficos e títulos de grupos

# Cria todos os outputs para os gráficos do país
for (x in var_groups$cod_group) {
  
  # Título do gráfico
  country_graphs <-  tagList(
    country_graphs,
    var_groups$group_name[var_groups$cod_group == x] %>%
      absolutePanel(
        top = top,
        style = "
            font-size: 18px;
            font-weight: bold;
          "
      )
  )
  
  # altera posição para próximo gráfico
  top <- top + 25
  
  # Os gráficos podem ficar em duas colunas.
  # Define os dados para a coluna da direita.
  left <- "20px"
  graph_position <- 1
  
  # Gráficos do grupo
  for (y in meta_var$cod_var[meta_var$cod_group == x]) {
    
    # inclui um gráfico
    country_graphs <- tagList(
      country_graphs,
      graphPanel(y, top, left)
    )
    
    # altera posição para próximo gráfico
    if (graph_position != 1) {
      top <- top + 270
      left <- "20px"
    } else {
      left <- "34% + 40px"
    }
    graph_position <- graph_position * -1
  }
  
  # altera topo para próximo grupo
  if (graph_position == 1) {
    top <- top + 25
  } else {
    top <- top + 275
  }
}
# Fim da criação dos gráficos do país
