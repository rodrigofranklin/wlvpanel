wlvpanel_result_contract_candidates <- c(
  getwd(),
  file.path(getwd(), "..", "..")
)
wlvpanel_result_contract_root <- wlvpanel_result_contract_candidates[
  file.exists(file.path(
    wlvpanel_result_contract_candidates,
    "utils",
    "result_contracts.R"
  ))
][[1L]]
wlvpanel_result_contract_root <- normalizePath(
  wlvpanel_result_contract_root,
  winslash = "/",
  mustWork = TRUE
)
sys.source(
  file.path(wlvpanel_result_contract_root, "utils", "result_contracts.R"),
  envir = environment()
)

wlvpanel_contract_sha256 <- function(path) {
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  unname(unclass(as.character(openssl::sha256(connection))))
}

wlvpanel_contract_write_json <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(
    value,
    path,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  invisible(path)
}

wlvpanel_contract_fixture <- function(
    results_root,
    release_id,
    sequence,
    method = "wiodr16",
    channel = "stable",
    output_version = "1.0.0",
    run_schema = "wlv-run-manifest") {
  run_id <- paste0("run-", release_id)
  run_relative <- paste("runs", method, run_id, sep = "/")
  run_dir <- file.path(results_root, "runs", method, run_id)
  dir.create(run_dir, recursive = TRUE, showWarnings = FALSE)

  artifact_path <- file.path(run_dir, "payload.bin")
  writeBin(charToRaw(paste0("payload-", release_id)), artifact_path)
  result_id <- wlvpanel_contract_sha256(artifact_path)
  artifact <- list(
    path = "payload.bin",
    role = "test_payload",
    size_bytes = unname(file.info(artifact_path)$size),
    sha256 = wlvpanel_contract_sha256(artifact_path)
  )
  run_manifest <- list(
    schema = run_schema,
    schema_version = "1",
    run_id = run_id,
    result_id = result_id,
    created_at_utc = "2026-08-20T12:00:00Z",
    parent_run_id = NULL,
    method = method,
    output_contract = list(
      id = "wlvpanel-output",
      version = output_version
    ),
    result = structure(list(), names = character()),
    execution = structure(list(), names = character()),
    artifacts = list(artifact)
  )
  run_manifest_path <- file.path(run_dir, "run_manifest.json")
  wlvpanel_contract_write_json(run_manifest, run_manifest_path)

  release_dir <- file.path(results_root, "releases", release_id)
  dir.create(release_dir, recursive = TRUE, showWarnings = FALSE)
  release_artifact_values <- list(
    "indicators_en.csv" = "cod_label;label\nvalue;Value\n",
    "meta_indicators.csv" = "value;groups;type;reverted\nvalue;test;usd;FALSE\n"
  )
  release_artifacts <- lapply(names(release_artifact_values), function(name) {
    path <- file.path(release_dir, name)
    writeBin(charToRaw(release_artifact_values[[name]]), path)
    list(
      path = name,
      role = "panel_metadata",
      size_bytes = unname(file.info(path)$size),
      sha256 = wlvpanel_contract_sha256(path)
    )
  })
  sequence <- sprintf("%020d", as.integer(sequence))
  release_manifest_path <- file.path(release_dir, "release_manifest.json")
  release_manifest <- list(
    schema = "wlv-release-manifest",
    schema_version = "1",
    release_id = release_id,
    channel = channel,
    sequence = sequence,
    created_at_utc = "2026-08-20T12:01:00Z",
    metadata = list(description = "test release"),
    runs = list(list(
      method = method,
      run_id = run_id,
      result_id = result_id,
      manifest_path = paste0(run_relative, "/run_manifest.json"),
      manifest_sha256 = wlvpanel_contract_sha256(run_manifest_path)
    )),
    artifacts = release_artifacts
  )
  wlvpanel_contract_write_json(release_manifest, release_manifest_path)

  marker_dir <- file.path(results_root, "channels", channel)
  marker_path <- file.path(
    marker_dir,
    paste0(sequence, "-", release_id, ".json")
  )
  marker <- list(
    schema = "wlv-channel-marker",
    schema_version = "1",
    channel = channel,
    sequence = sequence,
    release_id = release_id,
    release_manifest_path = paste0(
      "releases/",
      release_id,
      "/release_manifest.json"
    ),
    release_manifest_sha256 = wlvpanel_contract_sha256(release_manifest_path),
    published_at_utc = "2026-08-20T12:02:00Z"
  )
  wlvpanel_contract_write_json(marker, marker_path)

  list(
    results_root = results_root,
    run_dir = normalizePath(run_dir, winslash = "/", mustWork = TRUE),
    artifact_path = artifact_path,
    run_manifest_path = run_manifest_path,
    release_dir = normalizePath(release_dir, winslash = "/", mustWork = TRUE),
    release_artifact_path = file.path(release_dir, "meta_indicators.csv"),
    release_manifest_path = release_manifest_path,
    marker_path = marker_path,
    method = method,
    release_id = release_id
  )
}

testthat::test_that("the highest append-only channel marker selects its release", {
  root <- tempfile("wlvpanel-results-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  low <- wlvpanel_contract_fixture(root, "release-low", 1L)
  high <- wlvpanel_contract_fixture(root, "release-high", 2L)

  observed <- wlv_resolve_result_run_dirs(root, channel = "stable")

  testthat::expect_identical(observed[[1L]], high$run_dir)
  testthat::expect_identical(names(observed), high$method)
  testthat::expect_identical(attr(observed, "publication_mode"), "immutable_release")
  testthat::expect_identical(attr(observed, "release_id"), high$release_id)
  testthat::expect_identical(attr(observed, "release_root"), high$release_dir)
  testthat::expect_false(identical(observed[[1L]], low$run_dir))
})

testthat::test_that("WLV_RELEASE_CHANNEL configures the selected channel", {
  root <- tempfile("wlvpanel-results-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  preview <- wlvpanel_contract_fixture(
    root,
    "release-preview",
    1L,
    channel = "experiment/preview"
  )
  old_channel <- Sys.getenv("WLV_RELEASE_CHANNEL", unset = NA_character_)
  on.exit({
    if (is.na(old_channel)) {
      Sys.unsetenv("WLV_RELEASE_CHANNEL")
    } else {
      Sys.setenv(WLV_RELEASE_CHANNEL = old_channel)
    }
  }, add = TRUE)
  Sys.setenv(WLV_RELEASE_CHANNEL = "experiment/preview")

  observed <- wlv_resolve_result_run_dirs(root)

  testthat::expect_identical(observed[[1L]], preview$run_dir)
  testthat::expect_identical(attr(observed, "channel"), "experiment/preview")
})

testthat::test_that("legacy method directories require an explicit warning", {
  root <- tempfile("wlvpanel-legacy-results-")
  method_dir <- file.path(root, "wiodr13")
  dir.create(method_dir, recursive = TRUE)
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  writeLines("code;description\nWIOD13;Legacy", file.path(method_dir, "_parameters.csv"))

  testthat::expect_warning(
    observed <- wlv_resolve_result_run_dirs(root, channel = "stable"),
    "legacy mutable"
  )

  testthat::expect_identical(names(observed), "wiodr13")
  testthat::expect_identical(attr(observed, "publication_mode"), "legacy")
  testthat::expect_identical(
    observed[[1L]],
    normalizePath(method_dir, winslash = "/", mustWork = TRUE)
  )
})

testthat::test_that("schema and output-contract incompatibilities are rejected", {
  root_schema <- tempfile("wlvpanel-results-schema-")
  on.exit(unlink(root_schema, recursive = TRUE, force = TRUE), add = TRUE)
  wlvpanel_contract_fixture(
    root_schema,
    "release-schema",
    1L,
    run_schema = "unknown-run-manifest"
  )
  testthat::expect_error(
    wlv_resolve_result_run_dirs(root_schema),
    "unsupported schema `unknown-run-manifest`",
    class = "wlv_result_contract_error"
  )

  for (version in c("1.1.0", "2.0.0")) {
    root_version <- tempfile("wlvpanel-results-version-")
    on.exit(unlink(root_version, recursive = TRUE, force = TRUE), add = TRUE)
    wlvpanel_contract_fixture(
      root_version,
      paste0("release-version-", gsub("[.]", "-", version)),
      1L,
      output_version = version
    )
    testthat::expect_error(
      wlv_resolve_result_run_dirs(root_version),
      sprintf("incompatible output contract version `%s`", version),
      class = "wlv_result_contract_error"
    )
  }
})

testthat::test_that("path containment remains case-sensitive outside Windows", {
  if (.Platform$OS.type == "windows") {
    testthat::skip("Windows paths are intentionally compared case-insensitively.")
  }
  root <- tempfile("wlvcase", tmpdir = tempdir())
  external <- file.path(dirname(root), toupper(basename(root)))
  dir.create(root)
  if (!dir.create(external)) {
    testthat::skip("The test filesystem is not case-sensitive.")
  }
  on.exit(unlink(c(root, external), recursive = TRUE, force = TRUE), add = TRUE)
  writeBin(charToRaw("outside"), file.path(external, "payload.bin"))
  linked <- file.symlink(external, file.path(root, "link"))
  if (!isTRUE(linked)) {
    testthat::skip("This runner cannot create symbolic links.")
  }

  testthat::expect_error(
    wlv_result_contract_existing_path(root, "link/payload.bin", "artifact"),
    "resolves outside its allowed root",
    class = "wlv_result_contract_error"
  )
})

testthat::test_that("internal run and release store aliases are rejected", {
  for (component in c("runs", "releases")) {
    root <- tempfile(paste0("wlvpanel-results-alias-", component, "-"))
    on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
    wlvpanel_contract_fixture(
      root,
      paste0("release-alias-", component),
      1L
    )

    canonical_path <- file.path(root, component)
    sibling_path <- file.path(root, paste0(component, "-sibling"))
    testthat::expect_true(file.rename(canonical_path, sibling_path))
    linked <- if (.Platform$OS.type == "windows") {
      Sys.junction(sibling_path, canonical_path)
    } else {
      file.symlink(sibling_path, canonical_path)
    }
    if (!isTRUE(linked)) {
      testthat::skip("This runner cannot create directory aliases.")
    }

    testthat::expect_error(
      wlv_resolve_result_run_dirs(root),
      "alias instead of its canonical store path",
      class = "wlv_result_contract_error"
    )
  }
})

testthat::test_that("the complete checksum chain is verified", {
  artifact_root <- tempfile("wlvpanel-results-artifact-")
  on.exit(unlink(artifact_root, recursive = TRUE, force = TRUE), add = TRUE)
  artifact_fixture <- wlvpanel_contract_fixture(
    artifact_root,
    "release-artifact",
    1L
  )
  artifact_bytes <- readBin(
    artifact_fixture$artifact_path,
    what = "raw",
    n = file.info(artifact_fixture$artifact_path)$size
  )
  artifact_bytes[[length(artifact_bytes)]] <- as.raw(
    bitwXor(as.integer(artifact_bytes[[length(artifact_bytes)]]), 1L)
  )
  writeBin(artifact_bytes, artifact_fixture$artifact_path)
  testthat::expect_error(
    wlv_resolve_result_run_dirs(artifact_root),
    "SHA-256 mismatch.*payload[.]bin",
    class = "wlv_result_contract_error"
  )

  release_artifact_root <- tempfile("wlvpanel-results-release-artifact-")
  on.exit(unlink(release_artifact_root, recursive = TRUE, force = TRUE), add = TRUE)
  release_artifact_fixture <- wlvpanel_contract_fixture(
    release_artifact_root,
    "release-metadata",
    1L
  )
  release_artifact_bytes <- readBin(
    release_artifact_fixture$release_artifact_path,
    what = "raw",
    n = file.info(release_artifact_fixture$release_artifact_path)$size
  )
  release_artifact_bytes[[length(release_artifact_bytes)]] <- as.raw(
    bitwXor(
      as.integer(release_artifact_bytes[[length(release_artifact_bytes)]]),
      1L
    )
  )
  writeBin(
    release_artifact_bytes,
    release_artifact_fixture$release_artifact_path
  )
  testthat::expect_error(
    wlv_resolve_result_run_dirs(release_artifact_root),
    "SHA-256 mismatch.*meta_indicators[.]csv",
    class = "wlv_result_contract_error"
  )
})

testthat::test_that("release and run manifest corruption is rejected", {
  release_root <- tempfile("wlvpanel-results-release-")
  on.exit(unlink(release_root, recursive = TRUE, force = TRUE), add = TRUE)
  release_fixture <- wlvpanel_contract_fixture(
    release_root,
    "release-corrupt",
    1L
  )
  connection <- file(release_fixture$release_manifest_path, open = "ab")
  writeBin(charToRaw(" "), connection)
  close(connection)
  testthat::expect_error(
    wlv_resolve_result_run_dirs(release_root),
    "SHA-256 mismatch.*release_manifest[.]json",
    class = "wlv_result_contract_error"
  )

  run_root <- tempfile("wlvpanel-results-run-")
  on.exit(unlink(run_root, recursive = TRUE, force = TRUE), add = TRUE)
  run_fixture <- wlvpanel_contract_fixture(run_root, "run-corrupt", 1L)
  connection <- file(run_fixture$run_manifest_path, open = "ab")
  writeBin(charToRaw(" "), connection)
  close(connection)
  testthat::expect_error(
    wlv_resolve_result_run_dirs(run_root),
    "SHA-256 mismatch.*run_manifest[.]json",
    class = "wlv_result_contract_error"
  )
})

testthat::test_that("required panel artifacts must be in the verified inventory", {
  root <- tempfile("wlvpanel-results-required-")
  on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
  wlvpanel_contract_fixture(root, "release-required", 1L)

  testthat::expect_error(
    wlv_resolve_result_run_dirs(
      root,
      required_artifacts = c("payload.bin", "sea_countries.fst")
    ),
    "missing required artifact.*sea_countries[.]fst",
    class = "wlv_result_contract_error"
  )
})
