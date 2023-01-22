function(input, output, session) {
  
  RV <- reactiveValues()

  # Call server function of all modules
  lapply(
    names(modules_server),
    function (i, IP = input, OP = output, REACTIVES = RV, SESSION = session) {
      modules_server[[i]](IP, OP, REACTIVES, SESSION)
  })

  
  # all labels and languages
  lapply(rownames(language_file), function(i) {
    output[[paste0("label.",i)]] <- renderText(lb(i, input$l))
  })
  
  # Debug area. Shown in "How to quote" tab
  output$debug <- renderText({
    # input$setup_close_button
    # RV$bases() |> paste(collapse = "|")
  })
}
