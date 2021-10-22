## Panel: country_indicator ------------

# Global

estudo_tx_exp <- function(dados){
  ##Opção 1
  # dados <- sea_paises_source[1,,c("jornada_trabalho_media","valor_forca_trabalho_media"),
  #                            13]
  # 
  # anos <- names(dados[!is.na(rowSums(dados)),1])
  # dados <- data.frame(dados[anos,])
  # dados$ano <- anos
  # dados <- dados[,c(3,1,2)]
  # 
  # dados$min_line <- pmin(dados$jornada_trabalho_media, dados$valor_forca_trabalho_media)
  # 
  # p <- ggplot(dados, aes(x = ano, y = jornada_trabalho_media, group = 1)) +
  #   geom_line(colour = "blue", size = 0.5) +
  #   geom_point(colour = "blue") +
  #   geom_line(aes(y = valor_forca_trabalho_media), colour = "red", size = 0.5) +
  #   geom_point(aes(y = valor_forca_trabalho_media), colour = "red") +
  #   theme_bw() +
  #   theme(axis.title = element_blank(),
  #         legend.position='bottom')
  # 
  # dados$ano <- as.Date(paste0("01/01/",anos),
  #                      tryFormats="%d/%m/%Y")
  # data <- dados
  # 
  # ints <- intersects(data[,2], data[,3]) # because the first column is for Dates
  # intervals <- findInterval(1:nrow(data), c(0, ints$x))
  # 
  # for (i in seq_along(table(intervals))) {
  #   xstart <- ifelse(i == 1, 1, ints$x[i-1])
  #   ystart <- ifelse(i == 1, data[1,2], ints$y[i-1])
  #   xend <- ints$x[i]
  #   yend <- ints$y[i]
  #   x <- seq(nrow(data))[intervals == i]
  #   
  #   p <- p + 
  #     geom_polygon(
  #       data = data.frame(x = c(xstart, x, xend, rev(x)), 
  #                         y = c(ystart, data[x,2], yend, rev(data[x,3]))),
  #       aes(x= x, y = y), alpha = 0.3)
  # }
  # 
  # xstart <- ints[dim(ints)[1],1]
  # ystart <- ints[dim(ints)[1],2]
  # xend <- nrow(data)
  # yend <- data[dim(data)[1],2]
  # x <- seq(nrow(data))[intervals == max(intervals)]
  # p <- p + 
  #   geom_polygon(
  #     data = data.frame(x = c(xstart, x, xend, rev(x)), 
  #                       y = c(ystart, data[x,2], yend, rev(data[x,3]))),
  #     aes(x= x, y = y), alpha = 0.3, fill = "blue")
  # 
  # 
  # ggplotly(p)
  
  ##Opção 2
    # anos <- names(dados[!is.na(rowSums(dados)),1])
  # dados <- as.data.table(dados[anos,])
  # dados$ano <- anos
  # dados$min_line <- pmin(dados$jornada_trabalho_media, dados$valor_forca_trabalho_media)
  # 
  # ggplot(dados, aes(x = ano, y = jornada_trabalho_media, group = 1)) +
  #   geom_line(colour = "blue", size = 0.5) +
  #   geom_point(colour = "blue") +
  #   geom_line(aes(y = valor_forca_trabalho_media), colour = "red", size = 0.5) +
  #   geom_point(aes(y = valor_forca_trabalho_media), colour = "red") +
  #   geom_ribbon(
  #     aes(ymin = min_line, ymax = jornada_trabalho_media),
  #     fill = "red", alpha = 0.3) +
  #   theme_bw() +
  #   theme(axis.title = element_blank(),
  #         legend.position='bottom') +
  #   geom_ribbon(
  #     aes(ymin = valor_forca_trabalho_media , ymax = min_line),
  #     fill = "blue", alpha = 0.3)

  ##Opção 3
  # anos <- names(dados[!is.na(rowSums(dados)),1])
  # dados <- as.data.table(dados[anos,])
  # dados$ano <- anos
  # dados$mais_valor <- dados$jornada_trabalho_media - dados$valor_forca_trabalho_media
  # 
  # p <- ggplot(dados, aes(x = ano, y = jornada_trabalho_media, group = 1)) +
  #   geom_line(colour = "blue", size = 0.5) +
  #   geom_point(colour = "blue") +
  #   geom_line(aes(y = valor_forca_trabalho_media), colour = "red", size = 0.5) +
  #   geom_point(aes(y = valor_forca_trabalho_media), colour = "red") +
  #   geom_ribbon(
  #     # data=subset(dados, 0 < dados$mais_valor),
  #     aes(ymin = valor_forca_trabalho_media, ymax = jornada_trabalho_media),
  #     fill = "red", alpha = 0.3) +
  #   theme_bw() +
  #   theme(axis.title = element_blank(),
  #         legend.position='bottom')

  # anos <- names(dados[!is.na(rowSums(dados)),1])
  # dados <- as.data.table(dados[anos,])
  # dados$ano <- as.Date(paste0("01/01/",anos),
  #                      tryFormats="%d/%m/%Y")
  # dados$min_line <- pmin(dados$jornada_trabalho_media, dados$valor_forca_trabalho_media)
  # 
  # dados <- melt(dados, id.vars=c("ano","min_line"), 
  #               variable.name="var", value.name="valor")
  # 
  # p <- ggplot(data=dados, aes(x=ano, y=valor, fill=var, col=var)) +
  #   geom_ribbon(aes(ymax=valor, ymin=min_line)) +
  #   geom_line(aes(y = valor)) +
  #   geom_point()+
  #   theme_bw() +
  #   theme(axis.title = element_blank(),
  #         legend.position='bottom')
  
  ps <- ggplotly(p)

}


### Country indicator panel com transparência
country_tp_panel <- conditionalPanel(
  "output.pais != ''",
  
  absolutePanel(
      top = 45,
      left = 0,
      height = "calc(100vh - 45px)",
      width = "40%",
      style = "
        background-color: rgba(0,0,0,0.4);
        z-index: 100;
      ",

      # close button
      absolutePanel(
        right = 0,
        actionLink(
          "close_button",
          label = NULL,
          style = "padding: 10px; font-size: 14px; color: white; right:0",
          icon = icon("times")
        )
      ),

      paises[5, 1] %>%
        div(style = "
            position: relative;
            top: 70px;
            font-size: 38px;
            font-weight: bold;
            text-align: center;
        "),

      plotlyOutput("studie") %>%
        div(
          style = "
            position: relative;
            top: 30vh;
          ",
        ),

      # Show_me_more Button
      actionButton(
        "show_me_more",
        label = "Show me more",
      ) %>%
        div(style = "
            position: relative;
            top: 300px;
            font-size: 24px;
            text-align: center;
        ")
    )
)


##

panel_country_tp_server <- function(input, output, sea_paises) {

  # Botão para fechar painel e voltar para o mapa
  observeEvent(
    input$close_button,
    {updateSelectInput(inputId = "pais", selected = "")
      show_panel(show_panel() * -1)}
    
  )
  
  show_panel <- reactiveVal(0)
  
  observeEvent(input$show_me_more, ignoreInit = TRUE, {
    show_panel(1)
  })
  
  output$studie <- renderPlotly({
    dados <- sea_paises[1,,c("jornada_trabalho_media","valor_forca_trabalho_media"),input$pais]
    estudo_tx_exp(dados)
  })
}