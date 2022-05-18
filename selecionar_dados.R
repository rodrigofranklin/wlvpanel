########################################################################
##
## Seleciona os dados que serão exibidos no painel (para reduzir uso da
## memória). Todos os dados serão salvos na pasta "dados".
##
## Esse script precisa ser automatizado para facilitar a troca das versões
## presentes no painel (com o intuito de fazermos comparações).
##
########################################################################

## Funções
read_fst_array <- function(file_name) {
  
  ft <- fst::read_fst(file_name)  # single column data.frame
  metaf <- paste0(file_name, ".meta")
  if(file.exists(metaf)) {
  meta_data <- readRDS(metaf)  # retrieve dim
  
  m <- ft[[1]]  
  attr(m, "dim") <- meta_data$dim
  dimensiones <- length(meta_data$dim)
  meta_data <- meta_data[2:(dimensiones+1)]
  # lapply(1:dimensiones,function(d,f) {
  #   dimnames(f)[[d]] <- meta_data[[d]]
  # })
  dimnames(m) <- meta_data
  
  m} else {
    ft
  }
}

## Seleciona versões
#####
method_list <- gsub("results/","",list.dirs("results",recursive = F))
method_parameters <- paste0("results/",method_list, "/_parameters.csv")
method_list <- method_list[file.exists(method_parameters)]

## Carrega os dados de todos os modelos
## E cria as listas das dimensões (que serão utilizadas como inputs)

paises <- read.csv2("dados/paises.csv")

sea_countries <- NULL
sea_sectors <- NULL
lista_anos <- NULL
lista_variaveis_sea <- NULL
lista_paises <- NULL

x <- method_list[3]
for (x in method_list) {

  parameters <- read.csv2(paste0("results/",x,"/_parameters.csv"))

  sea_countries$temp <- read_fst_array(file = paste0("results/",x,"/sea_countries.fst"))

  lista_anos <- 
    unique(c(lista_anos, rownames(sea_countries$temp[,1,])))

  lista_variaveis_sea <- 
    unique(c(lista_variaveis_sea, rownames(sea_countries$temp[1,,])))

  # dimnames(sea_countries$temp)[[3]][
  #   dimnames(sea_countries$temp)[[3]] %in% paises[,3]] <- 
  #   paises[match(names(sea_countries$temp[1,1,]),paises[,3]),3][
  #     dimnames(sea_countries$temp)[[3]] %in% paises[,3]]
  #Converte os nomes de países Exiobase para ISO3
  dimnames(sea_countries$temp)[[3]][
    dimnames(sea_countries$temp)[[3]] %in% paises[,5]] <- 
    paises[match(names(sea_countries$temp[1,1,]),paises[,5]),3][
      dimnames(sea_countries$temp)[[3]] %in% paises[,5]]
  
  lista_paises <- 
    unique(c(lista_paises, names(sea_countries$temp[1,1,])))
  
  names(sea_countries)[names(sea_countries) == "temp"] <- parameters$name
  
  sea_sectors$temp <- read_fst_array(file = paste0("results/",x,"/sea_sectors.fst"))
  # dimnames(sea_sectors$temp)[[4]][
  #   dimnames(sea_sectors$temp)[[4]] %in% paises[,3]] <- 
  #   paises[match(names(sea_sectors$temp[1,1,1,]),paises[,3]),3][
  #     dimnames(sea_sectors$temp)[[4]] %in% paises[,3]]
  dimnames(sea_sectors$temp)[[4]][
    dimnames(sea_sectors$temp)[[4]] %in% paises[,5]] <- 
    paises[match(names(sea_sectors$temp[1,1,1,]),paises[,5]),3][
      dimnames(sea_sectors$temp)[[4]] %in% paises[,5]]
  
  
  
  names(sea_sectors)[names(sea_sectors) == "temp"] <- parameters$name

}

#####
lista_versoes <- names(sea_countries)

## Mescla os bancos de dados das duas versões em um único arquivo.
## Mescla o arquivo sea_paises
#####
sea_paises <- array(data = NA, dim = c(length(lista_versoes),
                                       length(lista_anos),
                                       length(lista_variaveis_sea),
                                       length(lista_paises)),
                    dimnames = list(lista_versoes,
                                    lista_anos,
                                    lista_variaveis_sea,
                                    lista_paises))

for (x in lista_versoes){
  sea_paises[x,
             match(names(sea_countries[[x]][,1,1]), lista_anos),
             match(names(sea_countries[[x]][1,,1]), lista_variaveis_sea),
             match(names(sea_countries[[x]][1,1,]), lista_paises)] <- sea_countries[[x]]
}

# Salvar

saveRDS(sea_paises, file = "dados/sea_paises.rds")
saveRDS(sea_sectors, file = "dados/sea_sectors.rds")

#### Salvar arquivos xlsx



############
############ DAQUI PARA BAIXO NÃO TEM RELEVÂNCIA
############ É NECESSÁRIO, PRIMEIRO, DEFINIR COMO VAI FICAR O TREEMAP
############

### Seleciona os dados das matrizes insumo-produtos
## m_io_13
m_io_resultados_13 <- 
  readRDS(file = paste0("resultados/",versao_resultado_13,"/m_io.rds"))
m_io_fonte_13 <- 
  readRDS(file = paste0("sourcedata/",versao_13,"/m_io.rds"))
m_io_filtros_13 <- 
  readRDS(file = paste0("resultados/",versao_resultado_13,"/m_io_filtros.rds"))

lista_anos <- names(m_io_resultados_13[,1,1,1])
lista_variaveis_io <- c("exportacoes_pm", "exportacoes_valores", 
                     "transferencias_valores")
lista_input <- names(m_io_resultados_13[1,1,,1])
lista_output <- names(m_io_resultados_13[1,1,1,])

num_anos <- length(lista_anos)
num_variaveis_io <- length(lista_variaveis_io)
num_input <- length(lista_input)
num_output <- length(lista_output)

m_io_13 <- array(data = NA, dim = c(num_anos,
                                    num_variaveis_io,
                                    num_input,
                                    num_output),
                 dimnames = list(lista_anos,
                                 lista_variaveis_io,
                                 lista_input,
                                 lista_output))

m_io_13[,"exportacoes_pm",,] <- m_io_fonte_13[lista_anos,,] * 
  rep(m_io_filtros_13["comercio",,], each = num_anos)

m_io_13[,"exportacoes_valores",,] <- 
  m_io_resultados_13[lista_anos,"valores",,] * 
  rep(m_io_filtros_13["comercio",,], each = num_anos)

m_io_13[,"transferencias_valores",,] <- 
  m_io_resultados_13[lista_anos,"transferencias_valores",,]

## m_io_16
m_io_resultados_16 <- 
  readRDS(file = paste0("resultados/",versao_resultado_16,"/m_io.rds"))
m_io_fonte_16 <- 
  readRDS(file = paste0("sourcedata/",versao_16,"/m_io.rds"))
m_io_filtros_16 <- 
  readRDS(file = paste0("resultados/",versao_resultado_16,"/m_io_filtros.rds"))

lista_anos <- names(m_io_resultados_16[,1,1,1])
lista_input <- names(m_io_resultados_16[1,1,,1])
lista_output <- names(m_io_resultados_16[1,1,1,])

num_anos <- length(lista_anos)
num_input <- length(lista_input)
num_output <- length(lista_output)

m_io_16 <- array(data = NA, dim = c(num_anos,
                                    num_variaveis_io,
                                    num_input,
                                    num_output),
                 dimnames = list(lista_anos,
                                 lista_variaveis_io,
                                 lista_input,
                                 lista_output))

m_io_16[,"exportacoes_pm",,] <- m_io_fonte_16[lista_anos,,] * 
  rep(m_io_filtros_16["comercio",,], each = num_anos)

m_io_16[,"exportacoes_valores",,] <- 
  m_io_resultados_16[lista_anos,"valores",,] * 
  rep(m_io_filtros_16["comercio",,], each = num_anos)

m_io_16[,"transferencias_valores",,] <- 
  m_io_resultados_16[lista_anos,"transferencias_valores",,]


## Salva informações na pasta do painel
#####

saveRDS(sea_paises, file = "R/utils/painel/dados/sea_paises.rds")
saveRDS(m_io_13, file = "R/utils/painel/dados/m_io_13.rds")
saveRDS(m_io_16, file = "R/utils/painel/dados/m_io_16.rds")

## Copiando demais arquivos

current.folder <- "C:/Where my files currently live"
new.folder <- "H:/Where I want my files to be copied to"
# find the files that you want
lista_arquivos <- 
  c(paste0("resultados/", versao_resultado_13,"/m_paises.rds"),
    paste0("resultados/", versao_resultado_13,"/sea_setores.rds"),
    paste0("resultados/", versao_resultado_16,"/m_paises.rds"),
    paste0("resultados/", versao_resultado_16,"/sea_setores.rds"))
lista_destino <- 
  c("R/utils/painel/dados/m_paises_13.rds",
    "R/utils/painel/dados/sea_setores_13.rds",
    "R/utils/painel/dados/m_paises_16.rds",
    "R/utils/painel/dados/sea_setores_16.rds")
# copy the files to the new folder
file.copy(lista_arquivos, lista_destino, overwrite = TRUE)
