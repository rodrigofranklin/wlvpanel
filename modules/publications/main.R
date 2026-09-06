wlv_publications_text <- function(key, lang = "pt") {
  dictionary <- list(title = c("Publicações", "Publications"),
    intro = c("Publicações de Rodrigo Straessli Pinto Franklin e Rodrigo Emmanuel Santana Borges, incluindo coautorias.",
      "Publications by Rodrigo Straessli Pinto Franklin and Rodrigo Emmanuel Santana Borges, including coauthored works."),
    coverage = c("Referências reunidas de editoras, repositórios e dos registros públicos dos autores no ORCID. As fontes consultadas não permitem assegurar uma bibliografia exaustiva.",
      "References collected from publishers, repositories and the authors' public ORCID records. These sources do not establish an exhaustive bibliography."),
    search = c("Buscar por título, autoria ou tema", "Search by title, author or topic"),
    author = c("Membro do projeto", "Project member"), year = c("Ano", "Year"),
    all_authors = c("Todos os membros", "All members"), all_years = c("Todos os anos", "All years"),
    count = c("referências encontradas", "references found"),
    empty = c("Nenhuma referência cadastrada corresponde a esta busca.", "No catalogued reference matches this search."),
    read = c("Acessar publicação", "Open publication"), source = c("Fonte verificada", "Verified source"),
    record = c("Ver registro bibliográfico", "View bibliographic record"),
    author_record = c("Registro do autor no ORCID", "Author's ORCID record"),
    incomplete_authorship = c("Obra vinculada ao ORCID de %s; a fonte não informa a lista completa de autoria.",
      "Work linked to %s's ORCID; the source does not provide the complete author list."),
    project = c("Publicações no site do projeto", "Publications on the project website"),
    team = c("Equipe do projeto", "Project team"),
    article = c("Artigo", "Journal article"), conference = c("Trabalho em congresso", "Conference paper"),
    dissertation = c("Dissertação", "Master's dissertation"), thesis = c("Tese", "Doctoral thesis"),
    report = c("Relatório de pesquisa", "Research report"), software = c("Software", "Software"),
    book = c("Livro", "Book"), chapter = c("Capítulo", "Book chapter"))
  dictionary[[key]][[if (identical(lang, "en")) 2L else 1L]]
}

wlv_validate_publications <- function(catalogue) {
  stopifnot(identical(catalogue$schema, "wlv-publications/1"),
    catalogue$coverage %in% c("partial", "complete"), length(catalogue$members) > 0L)
  members <- vapply(catalogue$members, `[[`, character(1L), "id")
  ids <- vapply(catalogue$entries, `[[`, character(1L), "id")
  stopifnot(!anyDuplicated(members), !anyDuplicated(ids))
  for (entry in catalogue$entries) {
    stopifnot(is.character(entry$title), length(entry$title) == 1L, nzchar(entry$title),
      length(entry$authors) > 0L, all(nzchar(unlist(entry$authors))),
      length(entry$members) > 0L, all(unlist(entry$members) %in% members),
      is.numeric(entry$year), length(entry$year) == 1L, is.finite(entry$year), entry$year %% 1L == 0L,
      entry$type %in% c("article", "conference", "dissertation", "thesis", "report", "software", "book", "chapter"),
      grepl("^https://", entry$url), length(entry$sources) > 0L,
      all(grepl("^https://", unlist(entry$sources))))
  }
  invisible(catalogue)
}

wlv_publications_filter <- function(entries, search = "", author = "", year = "") {
  normalise <- function(value) {
    converted <- iconv(tolower(enc2utf8(value)), from = "UTF-8", to = "ASCII//TRANSLIT", sub = "")
    gsub("[[:space:]]+", " ", converted)
  }
  search <- if (is.null(search)) "" else trimws(normalise(search))
  terms <- if (nzchar(search)) strsplit(search, " ", fixed = TRUE)[[1L]] else character()
  entries <- Filter(function(entry) {
    author_ok <- is.null(author) || !nzchar(author) || author %in% unlist(entry$members)
    year_ok <- is.null(year) || !nzchar(year) || identical(as.character(entry$year), as.character(year))
    text <- normalise(paste(entry$title, paste(unlist(entry$authors), collapse = " "), entry$venue))
    author_ok && year_ok && all(vapply(terms, grepl, logical(1L), x = text, fixed = TRUE))
  }, entries)
  if (!length(entries)) return(entries)
  entries[order(-vapply(entries, `[[`, numeric(1L), "year"), vapply(entries, `[[`, character(1L), "title"))]
}

wlv_publications_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::tags$head(shiny::tags$link(rel = "stylesheet", href = "wlv-publications.css")),
    shiny::tags$main(class = "wlv-page wlv-publications",
      shiny::uiOutput(ns("heading")),
      shiny::div(class = "wlv-publications-filters",
        shiny::textInput(ns("search"), wlv_publications_text("search"), value = ""),
        shiny::selectInput(ns("author"), wlv_publications_text("author"), choices = character(), selectize = FALSE),
        shiny::selectInput(ns("year"), wlv_publications_text("year"), choices = character(), selectize = FALSE)),
      shiny::uiOutput(ns("results"))
    ))
}

wlv_publications_server <- function(id, catalogue, lang) {
  shiny::moduleServer(id, function(input, output, session) {
    txt <- function(key) wlv_publications_text(key, lang())
    shiny::observe({
      authors <- vapply(catalogue$members, `[[`, character(1L), "id")
      names(authors) <- vapply(catalogue$members, `[[`, character(1L), "name")
      years <- sort(unique(vapply(catalogue$entries, `[[`, numeric(1L), "year")), decreasing = TRUE)
      shiny::updateTextInput(session, "search", label = txt("search"))
      shiny::updateSelectInput(session, "author", label = txt("author"),
        choices = c(stats::setNames("", txt("all_authors")), authors),
        selected = shiny::isolate(input$author))
      shiny::updateSelectInput(session, "year", label = txt("year"),
        choices = c(stats::setNames("", txt("all_years")), stats::setNames(as.character(years), years)),
        selected = shiny::isolate(input$year))
    })
    output$heading <- shiny::renderUI({
      shiny::tagList(shiny::tags$h1(txt("title")), shiny::tags$p(class = "wlv-lead", txt("intro")),
        if (identical(catalogue$coverage, "partial")) shiny::tags$p(class = "wlv-publications-coverage", txt("coverage")),
        shiny::tags$p(class = "wlv-publications-sources",
          shiny::tags$a(href = catalogue$project_source, target = "_blank", rel = "noopener noreferrer", txt("project")),
          shiny::tags$a(href = catalogue$team_source, target = "_blank", rel = "noopener noreferrer", txt("team"))))
    })
    selected <- shiny::reactive(wlv_publications_filter(catalogue$entries, input$search, input$author, input$year))
    output$results <- shiny::renderUI({
      records <- selected()
      shiny::tagList(
        shiny::tags$p(class = "wlv-publications-count", role = "status", paste(length(records), txt("count"))),
        if (!length(records)) shiny::tags$p(txt("empty")),
        shiny::tags$ol(class = "wlv-publications-list", lapply(records, function(entry) {
          shiny::tags$li(shiny::tags$article(class = "wlv-publication", `data-publication-id` = entry$id,
            shiny::tags$p(class = "wlv-publication-meta", paste(entry$year, txt(entry$type), sep = " · ")),
            shiny::tags$h2(shiny::tags$a(href = entry$url, target = "_blank", rel = "noopener noreferrer", entry$title)),
            shiny::tags$p(class = "wlv-publication-authors", if (identical(entry$authorship_complete, FALSE))
              sprintf(txt("incomplete_authorship"), paste(unlist(entry$authors), collapse = "; "))
              else paste(unlist(entry$authors), collapse = "; ")),
            shiny::tags$p(shiny::tags$em(entry$venue)),
            if (!is.null(entry$note)) shiny::tags$p(entry$note[[lang()]]),
            shiny::div(class = "wlv-publication-links",
              shiny::tags$a(href = entry$url, target = "_blank", rel = "noopener noreferrer", txt(if (isTRUE(entry$record_only)) "record" else "read")),
              shiny::tags$a(href = entry$sources[[1L]], target = "_blank", rel = "noopener noreferrer",
                txt(if (identical(entry$source_kind, "author_record")) "author_record" else "source")))))
        })))
    })
  })
}

wlv_publications_catalogue <- jsonlite::fromJSON("config/publications.json", simplifyVector = FALSE)
wlv_validate_publications(wlv_publications_catalogue)
TABPANEL <- shiny::tabPanel(l("tab_name.publications"), value = "publications", wlv_publications_ui("publications"))
modules_ui[[length(modules_ui) + 1L]] <- TABPANEL
modules_server[[length(modules_server) + 1L]] <- function(IP, OP, RV, SESSION) {
  wlv_publications_server("publications", wlv_publications_catalogue,
    shiny::reactive(if (identical(IP$l, "English")) "en" else "pt"))
}
