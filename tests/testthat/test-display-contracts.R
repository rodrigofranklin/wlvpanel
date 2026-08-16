test_that("method-specific index and percent scales are applied exactly once", {
  legacy <- wlvpanel_legacy_metadata()
  w13_path <- wlvpanel_write_metadata(
    wlvpanel_method_metadata(c(1, 100, 1), "index")
  )
  w16_path <- wlvpanel_write_metadata(
    wlvpanel_method_metadata(c(100, 100, 1), "index_point")
  )
  on.exit(unlink(c(w13_path, w16_path)), add = TRUE)
  contracts <- wlv_bind_display_contracts(list(
    wlv_read_method_display_contract(
      w13_path, "wiodr13", "WIOD13", legacy$value, legacy
    ),
    wlv_read_method_display_contract(
      w16_path, "wiodr16", "WIOD16", legacy$value, legacy
    )
  ))

  expect_identical(
    wlv_display_values(1, "WIOD13", "price", contracts),
    1
  )
  expect_identical(
    wlv_display_values(1, "WIOD16", "price", contracts),
    100
  )
  percent <- c(0, 0.125, 1, NA_real_, -0.25)
  expect_identical(
    wlv_display_values(percent, "WIOD16", "share", contracts),
    c(0, 12.5, 100, NA_real_, -25)
  )
  expect_identical(
    wlv_excel_num_format("WIOD16", "share", contracts),
    '0.00"%"'
  )
})

test_that("method directory and public method code remain explicit", {
  legacy <- wlvpanel_legacy_metadata()
  path <- wlvpanel_write_metadata(wlvpanel_method_metadata())
  on.exit(unlink(path), add = TRUE)
  contract <- wlv_read_method_display_contract(
    path,
    method_dir = "wiodr13",
    method = "WIOD13",
    indicators = legacy$value,
    legacy_metadata = legacy
  )
  expect_identical(unique(contract$method_dir), "wiodr13")
  expect_identical(unique(contract$method), "WIOD13")
  expect_error(
    wlv_display_values(1, "wiodr13", "price", contract),
    "No unique display contract",
    fixed = TRUE
  )
})

test_that("a wholly absent sidecar uses the warned legacy fallback", {
  legacy <- wlvpanel_legacy_metadata()
  missing <- tempfile("wlvpanel-absent-metadata-", fileext = ".RDS")
  expect_warning(
    contract <- wlv_read_method_display_contract(
      missing,
      "legacy",
      "LEGACY",
      legacy$value,
      legacy
    ),
    "display_multiplier = 1",
    fixed = TRUE
  )
  expect_true(all(contract$display_multiplier == 1))
  expect_true(all(contract$metadata_source == "legacy_fallback"))
  expect_identical(
    wlv_display_values(0.125, "LEGACY", "share", contract),
    12.5
  )
  expect_identical(
    wlv_display_values(2, "LEGACY", "price", contract),
    2
  )
})

test_that("complete historical metadata falls back but ambiguous schemas fail", {
  legacy <- wlvpanel_legacy_metadata()
  historical <- wlvpanel_legacy_method_metadata()
  historical_path <- wlvpanel_write_metadata(historical)
  on.exit(unlink(historical_path), add = TRUE)
  expect_warning(
    contract <- wlv_read_method_display_contract(
      historical_path, "historical", "HISTORICAL", legacy$value, legacy
    ),
    "legacy method metadata",
    fixed = TRUE
  )
  expect_true(all(contract$metadata_source == "legacy_fallback"))
  expect_true(all(contract$display_multiplier == 1))
  expect_identical(contract$legacy_type, legacy$type)

  incomplete <- historical
  incomplete$observation <- NULL
  incomplete_path <- wlvpanel_write_metadata(incomplete)
  on.exit(unlink(incomplete_path), add = TRUE)
  expect_error(
    wlv_read_method_display_contract(
      incomplete_path, "historical", "HISTORICAL", legacy$value, legacy
    ),
    "incomplete schema",
    fixed = TRUE
  )

  modern_defaults <- list(
    canonical_unit = rep(NA_character_, nrow(historical)),
    display_unit = rep(NA_character_, nrow(historical)),
    display_multiplier = rep(1, nrow(historical)),
    index_base_year = rep(NA_character_, nrow(historical)),
    index_storage_base = rep(NA_real_, nrow(historical))
  )
  for (column in names(modern_defaults)) {
    partial <- historical
    partial[[column]] <- modern_defaults[[column]]
    partial_path <- wlvpanel_write_metadata(partial)
    on.exit(unlink(partial_path), add = TRUE)
    expect_error(
      wlv_read_method_display_contract(
        partial_path, "historical", "HISTORICAL", legacy$value, legacy
      ),
      "partial modern schema",
      fixed = TRUE
    )
  }

  padded <- historical
  for (column in names(modern_defaults)) {
    padded[[column]] <- modern_defaults[[column]]
  }
  padded_path <- wlvpanel_write_metadata(padded)
  on.exit(unlink(padded_path), add = TRUE)
  expect_error(
    wlv_read_method_display_contract(
      padded_path, "historical", "HISTORICAL", legacy$value, legacy
    ),
    "invalid units or multipliers",
    fixed = TRUE
  )

  for (corrupt in list(
    rbind(historical, historical[1L, , drop = FALSE]),
    historical[-1L, , drop = FALSE],
    rbind(
      historical,
      transform(historical[1L, , drop = FALSE], code = "unexpected")
    )
  )) {
    corrupt_path <- wlvpanel_write_metadata(corrupt)
    on.exit(unlink(corrupt_path), add = TRUE)
    expect_error(
      wlv_read_method_display_contract(
        corrupt_path, "historical", "HISTORICAL", legacy$value, legacy
      ),
      "invalid or non-exact coverage",
      fixed = TRUE
    )
  }
})

test_that("present metadata fails closed on schema, duplicates and coverage", {
  legacy <- wlvpanel_legacy_metadata()
  incomplete <- wlvpanel_method_metadata()
  incomplete$display_unit <- NULL
  path <- wlvpanel_write_metadata(incomplete)
  on.exit(unlink(path), add = TRUE)
  expect_error(
    wlv_read_method_display_contract(
      path, "demo", "DEMO", legacy$value, legacy
    ),
    "partial modern schema",
    fixed = TRUE
  )

  duplicate <- rbind(
    wlvpanel_method_metadata(),
    wlvpanel_method_metadata()[1L, , drop = FALSE]
  )
  duplicate_path <- wlvpanel_write_metadata(duplicate)
  on.exit(unlink(duplicate_path), add = TRUE)
  expect_error(
    wlv_read_method_display_contract(
      duplicate_path, "demo", "DEMO", legacy$value, legacy
    ),
    "duplicate codes",
    fixed = TRUE
  )

  partial_path <- wlvpanel_write_metadata(
    wlvpanel_method_metadata()[-1L, , drop = FALSE]
  )
  on.exit(unlink(partial_path), add = TRUE)
  expect_error(
    wlv_read_method_display_contract(
      partial_path, "demo", "DEMO", legacy$value, legacy
    ),
    "non-exact coverage",
    fixed = TRUE
  )

  wrong_type <- wlvpanel_method_metadata()
  wrong_type$display_multiplier <- as.character(
    wrong_type$display_multiplier
  )
  wrong_type_path <- wlvpanel_write_metadata(wrong_type)
  on.exit(unlink(wrong_type_path), add = TRUE)
  expect_error(
    wlv_read_method_display_contract(
      wrong_type_path, "demo", "DEMO", legacy$value, legacy
    ),
    "invalid field types",
    fixed = TRUE
  )

  contradictory_index <- wlvpanel_method_metadata()
  contradictory_index$index_storage_base[[3L]] <- 1
  contradictory_path <- wlvpanel_write_metadata(contradictory_index)
  on.exit(unlink(contradictory_path), add = TRUE)
  expect_error(
    wlv_read_method_display_contract(
      contradictory_path, "demo", "DEMO", legacy$value, legacy
    ),
    "invalid index bases",
    fixed = TRUE
  )
})

test_that("modern display units never inherit legacy presentation types", {
  codes <- c(
    "ratio.r.pc", "exchange.r.us", "future.s.un",
    "percent.r.pc", "persons.s.un"
  )
  legacy <- data.frame(
    value = codes,
    type = c("percent", "usd", "integer", "percent", "integer"),
    stringsAsFactors = FALSE
  )
  metadata <- data.frame(
    code = codes,
    canonical_unit = c(
      "ratio", "local_currency_per_usd", "ratio", "ratio", "person"
    ),
    display_unit = c(
      "ratio", "local_currency_per_usd", "future_unit", "percent", "person"
    ),
    display_multiplier = c(1, 1, 1, 100, 1),
    index_base_year = rep(NA_character_, length(codes)),
    index_storage_base = rep(NA_real_, length(codes)),
    stringsAsFactors = FALSE
  )
  path <- wlvpanel_write_metadata(metadata)
  on.exit(unlink(path), add = TRUE)
  contracts <- wlv_read_method_display_contract(
    path, "modern", "MODERN", codes, legacy
  )

  expect_true(all(is.na(contracts$legacy_type)))
  expect_identical(
    vapply(
      codes,
      function(indicator) {
        wlv_display_format_type(contracts, "MODERN", indicator)
      },
      character(1L),
      USE.NAMES = FALSE
    ),
    c("neutral", "neutral", "neutral", "percent", "integer")
  )
  expect_identical(
    vapply(
      codes,
      function(indicator) {
        wlv_excel_num_format("MODERN", indicator, contracts)
      },
      character(1L),
      USE.NAMES = FALSE
    ),
    c("#,##0.00", "#,##0.00", "#,##0.00", '0.00"%"', "#,##0")
  )
  expect_identical(
    wlv_display_values(0.125, "MODERN", "ratio.r.pc", contracts),
    0.125
  )

  corrupted <- contracts
  corrupted$legacy_type[[1L]] <- "percent"
  expect_error(
    wlv_validate_display_contracts(corrupted),
    "must not carry legacy presentation types",
    fixed = TRUE
  )
})

test_that("consolidated contracts reject mixed sources and inconsistent units", {
  legacy <- wlvpanel_legacy_metadata()
  path <- wlvpanel_write_metadata(wlvpanel_method_metadata())
  on.exit(unlink(path), add = TRUE)
  contracts <- wlv_read_method_display_contract(
    path, "modern", "MODERN", legacy$value, legacy
  )

  mixed <- contracts
  mixed$metadata_source[[1L]] <- "legacy_fallback"
  mixed$legacy_type[[1L]] <- "index"
  mixed$canonical_unit[[1L]] <- NA_character_
  mixed$display_unit[[1L]] <- NA_character_
  mixed$index_base_year[[1L]] <- NA_character_
  mixed$index_storage_base[[1L]] <- NA_real_
  expect_error(
    wlv_validate_display_contracts(mixed),
    "exactly one display metadata source",
    fixed = TRUE
  )

  missing_unit <- contracts
  missing_unit$display_unit[[2L]] <- NA_character_
  expect_error(
    wlv_validate_display_contracts(missing_unit),
    "inconsistent unit metadata",
    fixed = TRUE
  )

  fallback <- wlv_legacy_display_contract(
    "legacy", "LEGACY", legacy$value, legacy, warn = FALSE
  )
  expect_silent(wlv_bind_display_contracts(list(contracts, fallback)))
  fallback$canonical_unit[[1L]] <- "ratio"
  expect_error(
    wlv_validate_display_contracts(fallback),
    "inconsistent unit metadata",
    fixed = TRUE
  )
})

test_that("structural availability filters method-specific indicators", {
  method_array <- function(indicators) {
    array(
      NA_real_,
      dim = c(2L, length(indicators), 1L, 1L),
      dimnames = list(
        year = c("2000", "2001"),
        indicator = indicators,
        sector = "S1",
        country = "A"
      )
    )
  }
  arrays <- list(
    WIOD13 = method_array(c("common", "w13_only", "zero_only")),
    WIOD16 = method_array(c("common", "w16_only"))
  )
  arrays$WIOD13[, "zero_only", , ] <- 0
  availability <- wlv_method_indicator_availability(arrays, 2L)
  selected <- c("WIOD13", "WIOD16")

  expect_identical(
    wlv_methods_with_indicator(availability, selected, "w13_only"),
    "WIOD13"
  )
  expect_identical(
    wlv_methods_with_indicator(availability, selected, "w16_only"),
    "WIOD16"
  )
  expect_identical(
    wlv_methods_with_indicator(availability, selected, "common"),
    selected
  )
  expect_identical(
    wlv_methods_with_indicator(availability, selected, "zero_only"),
    "WIOD13"
  )

  contracts <- data.frame(
    method_dir = availability$method,
    method = availability$method,
    indicator = availability$indicator,
    canonical_unit = "ratio",
    display_unit = "ratio",
    display_multiplier = 1,
    index_base_year = NA_character_,
    index_storage_base = NA_real_,
    metadata_source = "method_metadata",
    legacy_type = NA_character_,
    stringsAsFactors = FALSE
  )
  expect_invisible(
    wlv_validate_display_contract_coverage(contracts, availability)
  )

  missing <- contracts[
    !(contracts$method == "WIOD13" & contracts$indicator == "w13_only"),
    ,
    drop = FALSE
  ]
  condition <- tryCatch(
    wlv_validate_display_contract_coverage(missing, availability),
    error = identity
  )
  expect_s3_class(condition, "wlv_display_contract_coverage_error")
  expect_match(conditionMessage(condition), "WIOD13/w13_only", fixed = TRUE)

  unexpected <- rbind(
    contracts,
    transform(
      contracts[1L, , drop = FALSE],
      method_dir = "WIOD16",
      method = "WIOD16",
      indicator = "w13_only"
    )
  )
  condition <- tryCatch(
    wlv_validate_display_contract_coverage(unexpected, availability),
    error = identity
  )
  expect_s3_class(condition, "wlv_display_contract_coverage_error")
  expect_match(conditionMessage(condition), "WIOD16/w13_only", fixed = TRUE)
})

test_that("observation axes preserve cancellation, zeros and later slices", {
  values <- array(
    NA_real_,
    dim = c(1L, 2L, 2L, 2L),
    dimnames = list(
      method = "METHOD",
      year = c("2000", "2001"),
      indicator = c("cancel", "zero"),
      country = c("A", "B")
    )
  )
  values["METHOD", , "cancel", "A"] <- c(-1, 1)
  values["METHOD", , "zero", "A"] <- c(0, 0)
  values["METHOD", , "cancel", "B"] <- c(3, 4)

  expect_identical(sum(values["METHOD", , , "A"], na.rm = TRUE), 0)
  expect_identical(
    wlv_observed_axis_labels(values, 2L),
    c("2000", "2001")
  )
  expect_identical(
    wlv_observed_axis_labels(values, 3L),
    c("cancel", "zero")
  )
  expect_identical(wlv_observed_axis_labels(values, 4L), c("A", "B"))
  expect_true(wlv_has_observations(
    values["METHOD", , , "A", drop = FALSE]
  ))
  expect_true(wlv_has_observations(
    values["METHOD", , "zero", "A", drop = FALSE]
  ))
  expect_false(wlv_has_observations(
    values["METHOD", , "zero", "B", drop = FALSE]
  ))
})

test_that("method directory mapping is one-to-one", {
  legacy <- wlvpanel_legacy_metadata()
  path <- wlvpanel_write_metadata(wlvpanel_method_metadata())
  on.exit(unlink(path), add = TRUE)
  first <- wlv_read_method_display_contract(
    path, "source", "METHOD-A", legacy$value, legacy
  )
  second <- wlv_read_method_display_contract(
    path, "source", "METHOD-B", legacy$value, legacy
  )
  expect_error(
    wlv_bind_display_contracts(list(first, second)),
    "one-to-one method directory mapping",
    fixed = TRUE
  )
})

test_that("display array conversion is keyed and leaves canonical arrays intact", {
  legacy <- wlvpanel_legacy_metadata()
  path <- wlvpanel_write_metadata(
    wlvpanel_method_metadata(c(100, 100, 1), "index_point")
  )
  on.exit(unlink(path), add = TRUE)
  contracts <- wlv_read_method_display_contract(
    path, "wiodr16", "WIOD16", legacy$value, legacy
  )
  canonical <- array(
    c(1, 0.125, 20, 2, -0.25, 30),
    dim = c(1L, 3L, 2L),
    dimnames = list(
      year = "2000",
      indicator = legacy$value,
      country = c("A", "B")
    )
  )
  snapshot <- canonical
  displayed <- wlv_display_array(
    canonical,
    "WIOD16",
    "indicator",
    contracts
  )
  expect_identical(canonical, snapshot)
  expect_identical(
    as.numeric(displayed[, "price", ]),
    as.numeric(canonical[, "price", ]) * 100
  )
  expect_identical(
    as.numeric(displayed[, "share", ]),
    as.numeric(canonical[, "share", ]) * 100
  )
  expect_identical(
    as.numeric(displayed[, "output", ]),
    as.numeric(canonical[, "output", ])
  )
  expect_identical(
    as.numeric(displayed[, "share", "A"]),
    wlv_display_values(
      as.numeric(canonical[, "share", "A"]),
      "WIOD16",
      "share",
      contracts
    )
  )
})

test_that("multi-method comparisons reject incompatible display units", {
  legacy <- wlvpanel_legacy_metadata()
  w13_path <- wlvpanel_write_metadata(
    wlvpanel_method_metadata(c(1, 100, 1), "index")
  )
  w16_path <- wlvpanel_write_metadata(
    wlvpanel_method_metadata(c(100, 100, 1), "index_point")
  )
  on.exit(unlink(c(w13_path, w16_path)), add = TRUE)
  contracts <- wlv_bind_display_contracts(list(
    wlv_read_method_display_contract(
      w13_path, "wiodr13", "WIOD13", legacy$value, legacy
    ),
    wlv_read_method_display_contract(
      w16_path, "wiodr16", "WIOD16", legacy$value, legacy
    )
  ))
  expect_error(
    wlv_assert_comparable_display_units(
      c("WIOD13", "WIOD16"), "price", contracts
    ),
    class = "wlv_incompatible_display_units"
  )
  expect_identical(
    wlv_assert_comparable_display_units(
      c("WIOD13", "WIOD16"), "share", contracts
    ),
    "percent"
  )
})

test_that("display contract cache versions cover all semantic fields", {
  legacy <- wlvpanel_legacy_metadata()
  path <- wlvpanel_write_metadata(wlvpanel_method_metadata())
  on.exit(unlink(path), add = TRUE)
  contracts <- wlv_read_method_display_contract(
    path, "source", "METHOD", legacy$value, legacy
  )
  version <- wlv_display_contract_version(contracts)

  expect_identical(
    wlv_display_contract_version(contracts[nrow(contracts):1L, ]),
    version
  )

  mutations <- list(
    method_dir = transform(contracts, method_dir = "other-source"),
    method = transform(contracts, method = "OTHER-METHOD"),
    indicator = within(contracts, indicator[[3L]] <- "other-output"),
    canonical_unit = within(
      contracts,
      canonical_unit[[2L]] <- "future_ratio"
    ),
    display_unit = within(contracts, display_unit[[3L]] <- "future_unit"),
    display_multiplier = within(contracts, display_multiplier[[2L]] <- 50),
    index_base_year = within(contracts, index_base_year[[1L]] <- "1995"),
    index_storage_base = within(contracts, index_storage_base[[1L]] <- 100)
  )
  for (changed in mutations) {
    expect_false(identical(wlv_display_contract_version(changed), version))
  }

  fallback <- wlv_legacy_display_contract(
    "legacy", "LEGACY", legacy$value, legacy, warn = FALSE
  )
  fallback_version <- wlv_display_contract_version(fallback)
  fallback$legacy_type[[1L]] <- "future_type"
  expect_false(identical(
    wlv_display_contract_version(fallback),
    fallback_version
  ))
  expect_false(identical(fallback_version, version))
})
