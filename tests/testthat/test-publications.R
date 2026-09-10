load_publications_for_test <- function() {
  root <- if (file.exists("modules/publications/main.R")) "." else "../.."
  environment <- new.env(parent = environment())
  expressions <- parse(file.path(root, "modules/publications/main.R"), encoding = "UTF-8")
  for (expression in expressions) {
    if (is.call(expression) && identical(expression[[1L]], as.name("<-")) && is.symbol(expression[[2L]]) &&
        is.call(expression[[3L]]) && identical(expression[[3L]][[1L]], as.name("function"))) {
      eval(expression, envir = environment)
    }
  }
  environment$catalogue <- jsonlite::fromJSON(file.path(root, "config/publications.json"), simplifyVector = FALSE)
  environment
}

testthat::test_that("publication catalogue documents research links and explicitly selected books", {
  exports <- load_publications_for_test()
  catalogue <- exports$catalogue
  testthat::expect_invisible(exports$wlv_validate_publications(catalogue))
  testthat::expect_setequal(vapply(catalogue$members, `[[`, character(1L), "id"),
    c("franklin", "borges", "vidal", "montibeler", "sanchez", "barreto", "mendes"))
  testthat::expect_identical(catalogue$scope, "wlvd-research-and-selected-books")
  testthat::expect_setequal(vapply(catalogue$entries, `[[`, character(1L), "id"), c(
    "vidal-2024-china", "franklin-borges-2022-transferencia", "franklin-2022-skilled-labour",
    "franklin-2021-heterogeneous-labour", "franklin-borges-2020-transferencias",
    "franklin-2025-teoria-dependencia", "borges-2022-fixed-capital",
    "barreto-2023-saude", "borges-franklin-2024-exiobase", "barreto-2024-dependencia-ceis"))
  testthat::expect_identical(catalogue$coverage, "partial")
  dois <- Filter(Negate(is.null), lapply(catalogue$entries, `[[`, "doi"))
  testthat::expect_equal(anyDuplicated(tolower(unlist(dois))), 0L)
  testthat::expect_true(all(vapply(catalogue$entries, function(entry)
    any(unlist(entry$members) %in% c("franklin", "borges")), logical(1L))))
  invalid <- catalogue
  invalid$entries[[1L]]$members <- list("unverified-person")
  testthat::expect_error(exports$wlv_validate_publications(invalid))
  invalid <- catalogue
  invalid$entries[[1L]]$url <- "javascript:alert(1)"
  testthat::expect_error(exports$wlv_validate_publications(invalid))
  invalid <- catalogue
  invalid$entries[[1L]]$project_relation <- NULL
  testthat::expect_error(exports$wlv_validate_publications(invalid))
  invalid <- catalogue
  invalid$entries[[1L]]$inclusion_basis <- NULL
  testthat::expect_error(exports$wlv_validate_publications(invalid))
})

testthat::test_that("every coauthor can filter their papers, including byline aliases", {
  exports <- load_publications_for_test()
  catalogue <- exports$catalogue
  expected <- list(
    vidal = "vidal-2024-china",
    montibeler = c("vidal-2024-china", "franklin-2022-skilled-labour",
      "franklin-2021-heterogeneous-labour", "borges-2022-fixed-capital"),
    sanchez = c("franklin-2022-skilled-labour", "franklin-2021-heterogeneous-labour", "borges-2022-fixed-capital"),
    barreto = c("barreto-2023-saude", "barreto-2024-dependencia-ceis"),
    mendes = c("barreto-2023-saude", "barreto-2024-dependencia-ceis"))
  for (author in names(expected)) {
    records <- exports$wlv_publications_filter(catalogue$entries, author = author)
    testthat::expect_setequal(vapply(records, `[[`, character(1L), "id"), expected[[author]])
  }
  invalid <- catalogue
  china <- which(vapply(invalid$entries, function(entry) identical(entry$id, "vidal-2024-china"), logical(1L)))
  invalid$entries[[china]]$members <- list("franklin", "borges")
  testthat::expect_error(exports$wlv_validate_publications(invalid))
  invalid <- catalogue
  invalid$members[[length(invalid$members) + 1L]] <- list(id = "duplicate-sanchez", name = "César Sánchez")
  testthat::expect_error(exports$wlv_validate_publications(invalid))
  invalid <- catalogue
  invalid$entries[[china]]$authors <- c(invalid$entries[[china]]$authors, "Unregistered Author")
  testthat::expect_error(exports$wlv_validate_publications(invalid))
})

testthat::test_that("verified references with unavailable sources do not send readers to broken links", {
  exports <- load_publications_for_test()
  language <- shiny::reactiveVal("pt")
  shiny::testServer(exports$wlv_publications_server, args = list(catalogue = exports$catalogue, lang = language), {
    session$setInputs(search = "panorama ampliado", author = "borges", year = "2024")
    html <- paste(output$results$html, collapse = "")
    testthat::expect_match(html, "Trabalho e exploração", fixed = TRUE)
    testthat::expect_match(html, "Texto online temporariamente indisponível", fixed = TRUE)
    testthat::expect_false(grepl("href=", html, fixed = TRUE))
    language("en")
    session$flushReact()
    testthat::expect_match(paste(output$results$html, collapse = ""), "Online text temporarily unavailable", fixed = TRUE)
  })
})

testthat::test_that("the requested book retains publisher metadata and the exact catalogue link", {
  exports <- load_publications_for_test()
  book <- exports$wlv_publications_filter(exports$catalogue$entries,
    search = "teoria dependencia", author = "franklin", year = "2025")
  testthat::expect_length(book, 1L)
  book <- book[[1L]]
  testthat::expect_identical(book$title, "Teoria da dependência: guia para uma análise do mercado mundial")
  testthat::expect_identical(unlist(book$authors), "Rodrigo Straessli Pinto Franklin")
  testthat::expect_identical(book$type, "book")
  testthat::expect_identical(book$publisher, "EDUFES")
  testthat::expect_identical(book$isbn, "978-85-7772-611-0")
  testthat::expect_identical(book$url, "https://www.edufes.ufes.br/items/show/777")
  testthat::expect_identical(book$project_relation$kind, "theoretical_context")
  testthat::expect_true(book$project_relation$source %in% unlist(book$sources))
})

testthat::test_that("publication search combines title, author, accent-insensitive words and year", {
  exports <- load_publications_for_test()
  filter <- exports$wlv_publications_filter
  entries <- exports$catalogue$entries
  selected <- filter(entries, search = "analise transferencia china", author = "franklin", year = "2024")
  testthat::expect_identical(vapply(selected, `[[`, character(1L), "id"), "vidal-2024-china")
  testthat::expect_length(filter(entries, search = "nonexistent-publication-title"), 0L)
  testthat::expect_true(all(vapply(filter(entries, author = "borges", year = "2022"),
    function(entry) entry$year == 2022 && "borges" %in% entry$members, logical(1L))))
  testthat::expect_length(filter(entries, search = "", author = "", year = ""), length(entries))
  ordered <- filter(entries)
  testthat::expect_true(all(diff(vapply(ordered, `[[`, numeric(1L), "year")) <= 0))
})

testthat::test_that("publications change language without losing filters and omit the former biography notices", {
  exports <- load_publications_for_test()
  language <- shiny::reactiveVal("pt")
  shiny::testServer(exports$wlv_publications_server, args = list(catalogue = exports$catalogue, lang = language), {
    session$setInputs(search = "skilled labour", author = "franklin", year = "2022")
    html <- paste(output$results$html, collapse = "")
    heading <- paste(output$heading$html, collapse = "")
    testthat::expect_false(grepl("incluindo coautorias|ORCID|bibliografia exaustiva", heading))
    testthat::expect_match(html, "Skilled Labour", fixed = TRUE)
    testthat::expect_match(html, "Acessar publicação", fixed = TRUE)
    testthat::expect_false(grepl("Fonte verificada", html, fixed = TRUE))
    language("en")
    session$flushReact()
    testthat::expect_identical(input$author, "franklin")
    testthat::expect_identical(input$year, "2022")
    testthat::expect_identical(input$search, "skilled labour")
    testthat::expect_match(paste(output$results$html, collapse = ""), "Open publication", fixed = TRUE)
    testthat::expect_false(grepl("Verified source", paste(output$results$html, collapse = ""), fixed = TRUE))
    session$setInputs(search = "", author = "", year = "")
    testthat::expect_false(grepl("View bibliographic record|complete author list", paste(output$results$html, collapse = "")))
    session$setInputs(search = "a-title-that-does-not-exist")
    testthat::expect_match(paste(output$results$html, collapse = ""), "No catalogued reference", fixed = TRUE)
    language("pt")
    session$flushReact()
    testthat::expect_match(paste(output$results$html, collapse = ""), "Nenhuma referência", fixed = TRUE)
  })
})
