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
<<<<<<< HEAD
      top = 100,
      right = "1.5%",
      width = "22%",
      height = "28%",
      class = "panel panel-default",
      style =
        "background-color: rgba(255,255,255,0.2);
        z-index: 504;
        padding: 0;
        box-shadow: 0 0 10px rgba(0,0,0,0.2);
        border-radius: 2px;
        font-size: 10px",
      uiOutput("select.countrytrade"),
      radioButtons(inputId = "transacoes_agregacao", choices = "trade_aggregation_country", label = ""),
      uiOutput("select.basetrade"),
      sliderInput("anotrade","YEAR",min = 1995, max = 2014, value = 2009, ticks = F, animate=F)
    ),
    absolutePanel(
      width="75%",
      top=50,
      height="88%",
      left="1.5%",
      style = "z-index: 100",
      shinycssloaders::withSpinner(d3tree3Output("exportacoes_monetarias"))
    ),
    absolutePanel(
      width="75%",
      top="53%",
      height="88%",
      left="1.5%",
      style = "z-index: 100;",
      d3tree3Output("exportacoes_valores")
      ),
    absolutePanel(
      width="75%",
      top = "105%",
      height="88%",
      left="1.5%",
      style = "z-index: 100;",
      d3tree3Output("exportacoes_transferencias")
    )
    
  ),
  tabPanel(
    l("Download"),
    br(),br(),
    a("WLVD Portable / BDMVT portátil",href = "https://cloud.worldlabourvalues.org/s/5oDfapMJJdDMnSn")
  ),
  tabPanel(
    l("como.citar"),
    br(),br(),
    p(l("DESC.como.citar")),
    p("FRANKLIN, R.;BORGES, R,; SÁNCHEZ, C.; MONTIBELER, E. Skilled labour and the reduction problem: questioning the exploitation rate equalization hypoyhesis. World Review of Political Economy (in press), 2022.")
  )
  

)  

=======
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
>>>>>>> 08b9429 (Reconstrução do painel priorizando organização e otimização (painel_oo):)
  
  # Call tabPanels of all modules
  lapply(modules_ui, \(i) i)

))