function(input, output, session) {
  RV <- reactiveValues()
  lapply(modules_server, function(module) module(input, output, RV, session))
  observe({
    lang <- wlv_language(input$l)
    labels <- setNames(as.list(lb(rownames(language_file), lang)), rownames(language_file))
    session$sendCustomMessage("wlv-language", list(lang = lang, labels = labels))
  })
  observeEvent(input$about_map, updateNavbarPage(session, "main_nav", selected = "map"))
  observeEvent(input$about_indicators, updateNavbarPage(session, "main_nav", selected = "indicators"))
}
