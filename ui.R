do.call("navbarPage", c(
  theme = shinytheme(theme),
  collapsible = TRUE,
  windowTitle = "World Labour Values Database",
  title = "WLVD",

  # Common features
  header = tagList(setup_panel),
  
  # Credits and lincense
  footer = tagList(
    absolutePanel(
      fixed = TRUE,
      style = "background-color: rgba(255,255,255,0.6);
            z-index: 100;
            pointer-events: none;
            padding: 0px",
      bottom = 0,
      left = 0,
      width = 300,
      height = 20,
      withTags(table(tr(td(
        img(
          src = "https://worldlabourvalues.org/images/a_batallar_ideas.png",
          height = 20,
          style = "filter: grayscale(80%)"
        )
      ),
      td(
        style = "font-size: 11px; font-family: Arial, Helvetica, sans-serif;",
        "World Labour Values Task Force | ",
        span("©", style = "display: inline-block;
                        text-align: right;
                        margin: 0px;
                        -moz-transform: scaleX(-1);
                        -o-transform: scaleX(-1);
                        -webkit-transform: scaleX(-1);
                        transform: scaleX(-1);
                        filter: FlipH;
                        -ms-filter: 'FlipH'"
        ),
        " CC-BY-NC SA 4.0"
  )))))),
  
  # Call tabPanels of all modules
  lapply(modules_ui, \(i) i)

))