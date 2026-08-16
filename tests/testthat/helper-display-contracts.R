wlvpanel_test_candidates <- c(
  getwd(),
  file.path(getwd(), "..", "..")
)
wlvpanel_test_root <- wlvpanel_test_candidates[
  file.exists(file.path(
    wlvpanel_test_candidates,
    "utils",
    "display_contracts.R"
  ))
][[1L]]
wlvpanel_test_root <- normalizePath(
  wlvpanel_test_root,
  winslash = "/",
  mustWork = TRUE
)
sys.source(
  file.path(wlvpanel_test_root, "utils", "display_contracts.R"),
  envir = environment()
)

wlvpanel_legacy_metadata <- function() {
  data.frame(
    value = c("price", "share", "output"),
    type = c("index", "percent", "usd"),
    groups = "test",
    reverted = FALSE,
    stringsAsFactors = FALSE
  )
}

wlvpanel_method_metadata <- function(
    multiplier = c(1, 100, 1),
    price_unit = "index") {
  data.frame(
    code = c("price", "share", "output"),
    canonical_unit = c("index", "ratio", "usd"),
    display_unit = c(price_unit, "percent", "usd"),
    display_multiplier = multiplier,
    index_base_year = c("2000", NA, NA),
    index_storage_base = c(1, NA, NA),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

wlvpanel_write_metadata <- function(value) {
  path <- tempfile("wlvpanel-method-metadata-", fileext = ".RDS")
  saveRDS(value, path)
  path
}
