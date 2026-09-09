# Referência compartilhada, apresentada ao final da página Sobre.
wlv_citation_section <- function() {
  tags$section(id = "wlv-citation", class = "wlv-about-citation",
    tags$h2(l("tab_name.how_to_quote")), tags$p(l("text.quote")),
    tags$div(class = "wlv-citation",
      tags$p("Franklin, R. S. P., Borges, R. E. S., Sánchez, C., & Montibeler, E. E. (2022). ",
        "Skilled Labour and the Reduction Problem: Questioning the Exploitation Rate Equalization Hypothesis. ",
        tags$em("World Review of Political Economy"), ", 13(3), 362–390."),
      tags$a(href = "https://doi.org/10.13169/worlrevipoliecon.13.3.0362",
        target = "_blank", rel = "noopener", "DOI: 10.13169/worlrevipoliecon.13.3.0362"))
  )
}
