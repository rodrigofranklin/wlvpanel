TABPANEL <- tabPanel(l("tab_name.how_to_quote"), value = "cite",
  tags$main(class = "wlv-page wlv-reading",
    tags$h1(l("tab_name.how_to_quote")), tags$p(class = "wlv-lead", l("text.quote")),
    tags$div(class = "wlv-card wlv-citation",
      tags$p("Franklin, R. S. P., Borges, R. E. S., Sánchez, C., & Montibeler, E. E. (2022). ",
        "Skilled Labour and the Reduction Problem: Questioning the Exploitation Rate Equalization Hypothesis. ",
        tags$em("World Review of Political Economy"), ", 13(3), 362–390."),
      tags$a(href = "https://doi.org/10.13169/worlrevipoliecon.13.3.0362",
        target = "_blank", rel = "noopener", "DOI: 10.13169/worlrevipoliecon.13.3.0362"))
  )
)
modules_ui[[length(modules_ui) + 1L]] <- TABPANEL
