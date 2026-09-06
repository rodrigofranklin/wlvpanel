do.call(navbarPage, c(list(
  id = "main_nav", selected = "map", theme = shinytheme("simplex"),
  collapsible = TRUE, windowTitle = "WLVD | World Labour Values Database",
  title = tags$span(class = "wlv-brand", "WLVD", tags$small(l("app.title"))),
  header = tagList(
    tags$head(
      tags$meta(name = "viewport", content = "width=device-width, initial-scale=1"),
      tags$link(rel = "icon", href = "favicon.ico"),
      tags$link(rel = "stylesheet", href = "wlv-panel.css"),
      tags$script(src = "wlv-panel.js")
    ),
    tags$a(href = "#wlv-content", class = "wlv-skip", l("app.skip")),
    setup_panel,
    tags$div(id = "wlv-content", tabindex = "-1"),
    tags$div(class = "wlv-busy", role = "status", `aria-live` = "polite", l("app.loading"))
  ),
  footer = tags$footer(class = "wlv-footer",
    "World Labour Values Task Force", tags$span("CC BY-NC-SA 4.0"))
), modules_ui))
