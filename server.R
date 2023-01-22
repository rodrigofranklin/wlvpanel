function(input, output, session) {
  
  RV <- reactiveValues()

  # Call server function of all modules
  lapply(
    modules_server,
    function (i, IP = input, OP = output, REACTIVES = RV, SESSION = session) {
      i(IP, OP, REACTIVES, SESSION)
  })

  # all labels and languages
  lapply(rownames(language_file), function(i) {
    output[[paste0("label.",i)]] <- renderText(lb(i, input$l))
  })
  
  # Debug area. Shown in "How to quote" tab
  RV$debug <- reactiveVal(NA)
  output$debug <- renderText({
    if (RV$debug() |> is.na()) return()
    RV$debug()
  })
}
}
