shared_result_fixture_candidates <- c(
  getwd(),
  file.path(getwd(), "..", "..")
)
shared_result_fixture_project_root <- shared_result_fixture_candidates[
  file.exists(file.path(
    shared_result_fixture_candidates,
    "utils",
    "result_contracts.R"
  ))
][[1L]]
shared_result_fixture_project_root <- normalizePath(
  shared_result_fixture_project_root,
  winslash = "/",
  mustWork = TRUE
)
shared_result_fixture_environment <- new.env(parent = baseenv())
sys.source(
  file.path(
    shared_result_fixture_project_root,
    "utils",
    "result_contracts.R"
  ),
  envir = shared_result_fixture_environment
)

shared_result_fixture_inventory <- function(root) {
  lines <- readLines(
    file.path(root, "SHA256SUMS"),
    encoding = "UTF-8",
    warn = FALSE
  )
  testthat::expect_true(length(lines) > 0L)
  testthat::expect_true(all(grepl("^[0-9a-f]{64}  [^/].+$", lines)))
  expected_hashes <- substr(lines, 1L, 64L)
  expected_paths <- substring(lines, 67L)
  actual_paths <- list.files(
    root,
    recursive = TRUE,
    all.files = TRUE,
    full.names = FALSE,
    include.dirs = FALSE,
    no.. = TRUE
  )
  actual_paths <- sort(
    setdiff(chartr("\\", "/", actual_paths), "SHA256SUMS"),
    method = "radix"
  )
  testthat::expect_identical(expected_paths, actual_paths)
  observed_hashes <- vapply(
    file.path(root, expected_paths),
    shared_result_fixture_environment$wlv_result_contract_sha256_file,
    character(1L)
  )
  testthat::expect_identical(unname(observed_hashes), expected_hashes)
  invisible(TRUE)
}

testthat::test_that("WLVPanel consumes the shared static v1 fixture", {
  fixture <- file.path(
    shared_result_fixture_project_root,
    "tests",
    "fixtures",
    "result-contract-v1"
  )
  expected_run <- normalizePath(
    file.path(fixture, "runs", "example", "run-fixture-v1"),
    winslash = "/",
    mustWork = TRUE
  )
  expected_release <- normalizePath(
    file.path(fixture, "releases", "release-fixture-v1"),
    winslash = "/",
    mustWork = TRUE
  )

  observed <- shared_result_fixture_environment$wlv_resolve_result_run_dirs(
    fixture,
    channel = "stable",
    required_artifacts = "payload.txt"
  )

  testthat::expect_identical(names(observed), "example")
  testthat::expect_identical(observed[["example"]], expected_run)
  testthat::expect_identical(
    attr(observed, "publication_mode"),
    "immutable_release"
  )
  testthat::expect_identical(attr(observed, "channel"), "stable")
  testthat::expect_identical(
    attr(observed, "release_id"),
    "release-fixture-v1"
  )
  testthat::expect_identical(attr(observed, "release_root"), expected_release)
  testthat::expect_true(file.exists(file.path(
    attr(observed, "release_root"),
    "indicators_en.csv"
  )))
  testthat::expect_true(file.exists(file.path(
    attr(observed, "release_root"),
    "meta_indicators.csv"
  )))

  shared_result_fixture_inventory(fixture)
  payload_path <- file.path(observed[["example"]], "payload.txt")
  payload <- readBin(
    payload_path,
    what = "raw",
    n = file.info(payload_path)$size
  )
  payload <- rawToChar(payload)
  Encoding(payload) <- "UTF-8"
  testthat::expect_false(is.na(iconv(
    payload,
    from = "UTF-8",
    to = "UTF-8",
    sub = NA
  )))
  testthat::expect_match(payload, "publicação imutável", fixed = TRUE)
})
