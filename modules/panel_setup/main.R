setup_panel <- tagList(
  tags$div(style = "display:none", `aria-hidden` = "true",
    selectInput("l", NULL, choices = c("Português", "English"), selected = default_language, selectize = FALSE)),
  tags$button(id = "language_toggle", class = "btn wlv-language", type = "button",
    lang = "en", `aria-label` = "Switch to English", "English"),
  tags$details(id = "wlv-settings", class = "wlv-settings",
    tags$summary(id = "settings_toggle", `aria-label` = "Configurações", icon("gear")),
    div(class = "wlv-settings-panel",
      tags$h2(l("app.bases")),
      selectizeInput("bases", label = l("app.bases"), choices = list_methods,
        selected = intersect(init_bases, list_methods), multiple = TRUE, width = "100%",
        options = list(plugins = list("remove_button"))),
      actionButton("info_bases", label = l("app.method_info"), icon = icon("circle-info"))))
)
SERVER <- function(IP, OP, RV, SESSION) {
  RV$bases <- reactive({
    selected <- intersect(IP$bases, list_methods)
    if (length(selected)) selected else intersect(init_bases, list_methods)
  })
  observeEvent(IP$bases, {
    if (!length(IP$bases)) updateSelectizeInput(SESSION, "bases", selected = intersect(init_bases, list_methods))
  }, ignoreNULL = FALSE)
  OP$bases_info_text <- renderUI({
      lapply(seq_len(nrow(meta_methods)), function(i) {
        tags$section(class = "wlv-method-info",
          tags$h3(meta_methods$code[i]),
          tags$p(tags$strong(lb("ps.base_source", IP$l)), " ", meta_methods$source[i]),
          tags$p(lb(paste0("DESC.", meta_methods$code[i]), IP$l)))
      })
  })
  observeEvent(IP$info_bases, {
    showModal(modalDialog(
      title = l("app.method_info"), size = "l", easyClose = TRUE,
      uiOutput("bases_info_text"), footer = modalButton(l("app.close"))
    ))
  })
}
modules_server[[length(modules_server) + 1L]] <- SERVER
