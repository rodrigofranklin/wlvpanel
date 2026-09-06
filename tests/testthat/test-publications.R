load_publications_for_test <- function() {
  root <- if (file.exists("modules/publications/main.R")) "." else "../.."
  environment <- new.env(parent = globalenv())
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

testthat::test_that("publication catalogue has source-backed references for exactly the requested authors", {
  exports <- load_publications_for_test()
  catalogue <- exports$catalogue
  testthat::expect_invisible(exports$wlv_validate_publications(catalogue))
  testthat::expect_setequal(vapply(catalogue$members, `[[`, character(1L), "id"), c("franklin", "borges"))
  testthat::expect_gte(length(catalogue$entries), 40L)
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

testthat::test_that("publications change language without losing filters and distinguish author records", {
  exports <- load_publications_for_test()
  language <- shiny::reactiveVal("pt")
  shiny::testServer(exports$wlv_publications_server, args = list(catalogue = exports$catalogue, lang = language), {
    session$setInputs(search = "skilled labour", author = "franklin", year = "2022")
    html <- paste(output$results$html, collapse = "")
    testthat::expect_match(html, "Skilled Labour", fixed = TRUE)
    testthat::expect_match(html, "Acessar publicação", fixed = TRUE)
    language("en")
    session$flushReact()
    testthat::expect_identical(input$author, "franklin")
    testthat::expect_identical(input$year, "2022")
    testthat::expect_identical(input$search, "skilled labour")
    testthat::expect_match(paste(output$results$html, collapse = ""), "Open publication", fixed = TRUE)
    session$setInputs(search = "", author = "", year = "")
    testthat::expect_match(paste(output$results$html, collapse = ""), "View bibliographic record", fixed = TRUE)
    testthat::expect_match(paste(output$results$html, collapse = ""), "complete author list", fixed = TRUE)
    session$setInputs(search = "a-title-that-does-not-exist")
    testthat::expect_match(paste(output$results$html, collapse = ""), "No catalogued reference", fixed = TRUE)
    language("pt")
    session$flushReact()
    testthat::expect_match(paste(output$results$html, collapse = ""), "Nenhuma referência", fixed = TRUE)
  })
})
