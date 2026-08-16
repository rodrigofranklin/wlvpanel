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
    "incomplete schema",
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
