wlv_publications_text <- function(key, lang = "pt") {
  dictionary <- list(title = c("Publicações", "Publications"),
    search = c("Buscar por título, autoria ou tema", "Search by title, author or topic"),
    author = c("Membro do projeto", "Project member"), year = c("Ano", "Year"),
    all_authors = c("Todos os membros", "All members"), all_years = c("Todos os anos", "All years"),
    count = c("referências encontradas", "references found"),
    empty = c("Nenhuma referência cadastrada corresponde a esta busca.", "No catalogued reference matches this search."),
    read = c("Acessar publicação", "Open publication"),
    unavailable = c("Texto online temporariamente indisponível", "Online text temporarily unavailable"),
    record = c("Ver registro bibliográfico", "View bibliographic record"),
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

wlv_publications_author_key <- function(value) {
  converted <- iconv(tolower(enc2utf8(value)), from = "UTF-8", to = "ASCII//TRANSLIT", sub = "")
  trimws(gsub("[[:space:]]+", " ", converted))
}

wlv_validate_publications <- function(catalogue) {
  stopifnot(identical(catalogue$schema, "wlv-publications/1"),
    identical(catalogue$scope, "wlvd-research-and-selected-books"),
    catalogue$coverage %in% c("partial", "complete"), length(catalogue$members) > 0L)
  members <- vapply(catalogue$members, `[[`, character(1L), "id")
  ids <- vapply(catalogue$entries, `[[`, character(1L), "id")
  stopifnot(!anyDuplicated(members), !anyDuplicated(ids))
  author_ids <- unlist(lapply(catalogue$members, function(member) {
    stopifnot(is.character(member$name), length(member$name) == 1L, nzchar(member$name))
    aliases <- unique(wlv_publications_author_key(c(member$name, unlist(member$aliases))))
    stopifnot(all(nzchar(aliases)))
    stats::setNames(rep(member$id, length(aliases)), aliases)
  }), use.names = TRUE)
  stopifnot(!anyDuplicated(names(author_ids)))
  for (entry in catalogue$entries) {
    stopifnot(is.character(entry$title), length(entry$title) == 1L, nzchar(entry$title),
      length(entry$authors) > 0L, all(nzchar(unlist(entry$authors))),
      length(entry$members) > 0L, all(unlist(entry$members) %in% members),
      is.numeric(entry$year), length(entry$year) == 1L, is.finite(entry$year), entry$year %% 1L == 0L,
      entry$type %in% c("article", "conference", "dissertation", "thesis", "report", "software", "book", "chapter"),
      grepl("^https://", entry$url), length(entry$sources) > 0L,
      all(grepl("^https://", unlist(entry$sources))),
      is.list(entry$project_relation),
      is.character(entry$project_relation$evidence), length(entry$project_relation$evidence) == 1L,
      is.character(entry$project_relation$source), length(entry$project_relation$source) == 1L,
      entry$project_relation$kind %in% c("methodology", "application", "theoretical_context"),
      nzchar(entry$project_relation$evidence),
      grepl("^https://", entry$project_relation$source))
    stopifnot(is.null(entry$url_status) || entry$url_status %in% c("available", "unavailable"))
    expected_members <- unname(author_ids[wlv_publications_author_key(unlist(entry$authors))])
    stopifnot(!anyNA(expected_members), !anyDuplicated(unlist(entry$members)),
      setequal(unlist(entry$members), expected_members))
    if (identical(entry$project_relation$kind, "theoretical_context")) {
      stopifnot(identical(entry$type, "book"), identical(entry$inclusion_basis, "explicit_user_selection"))
    }
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
    shiny::tags$head(htmltools::includeCSS("www/wlv-publications.css")),
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
      authors <- authors[order(wlv_publications_author_key(names(authors)))]
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
      shiny::tagList(shiny::tags$h1(txt("title")),
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
            shiny::tags$h2(if (identical(entry$url_status, "unavailable")) entry$title else
              shiny::tags$a(href = entry$url, target = "_blank", rel = "noopener noreferrer", entry$title)),
            shiny::tags$p(class = "wlv-publication-authors", if (identical(entry$authorship_complete, FALSE))
              sprintf(txt("incomplete_authorship"), paste(unlist(entry$authors), collapse = "; "))
              else paste(unlist(entry$authors), collapse = "; ")),
            shiny::tags$p(shiny::tags$em(entry$venue)),
            if (!is.null(entry$note)) shiny::tags$p(entry$note[[lang()]]),
            shiny::div(class = "wlv-publication-links",
              if (identical(entry$url_status, "unavailable")) shiny::tags$span(txt("unavailable")) else
                shiny::tags$a(href = entry$url, target = "_blank", rel = "noopener noreferrer", txt(if (isTRUE(entry$record_only)) "record" else "read")))))
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
