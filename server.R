function(input, output, session) {
  
  RV <- reactiveValues("a" = 1)
  

  # Call server function of all modules
  lapply(
    names(modules_server),
    function (i, IP = input, OP = output, RV = RV, session = session) {
      modules_server[[i]](IP, OP, RV, session)
  })
  
  # all labels and languages
  lapply(rownames(language_file), function(i) {
    output[[paste0("label.",i)]] <- renderText(lb(i, input$l))
  })
}
