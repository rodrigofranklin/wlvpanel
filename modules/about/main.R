TABPANEL <- tabPanel(l("tab_name.about"), value = "about",
  tags$main(class = "wlv-page wlv-about",
    tags$section(class = "wlv-hero",
      tags$p(class = "wlv-eyebrow", l("about.eyebrow")),
      tags$h1(l("about.title")), tags$p(class = "wlv-lead", l("about.intro")),
      tags$div(class = "wlv-actions",
        actionButton("about_map", l("about.map"), class = "btn-primary", icon = icon("globe")),
        actionButton("about_indicators", l("about.indicators"), icon = icon("chart-line")))),
    tags$h2(l("about.read")),
    tags$div(class = "wlv-card-grid",
      tags$section(class = "wlv-card", tags$span(class = "wlv-card-number", "01"),
        tags$h3(l("tab_name.countries")), tags$p(l("about.map_text"))),
      tags$section(class = "wlv-card", tags$span(class = "wlv-card-number", "02"),
        tags$h3(l("tab_name.indicators")), tags$p(l("about.indicators_text"))),
      tags$section(class = "wlv-card", tags$span(class = "wlv-card-number", "03"),
        tags$h3(l("tab_name.download")), tags$p(l("about.download_text")))),
    tags$section(class = "wlv-card wlv-reading", tags$h2(l("about.methods")),
      tags$p(l("about.methods_text")), tags$p(l("about.project")),
      tags$a(href = "https://worldlabourvalues.org", target = "_blank", rel = "noopener", l("about.website")))
  )
)
modules_ui[[length(modules_ui) + 1L]] <- TABPANEL
