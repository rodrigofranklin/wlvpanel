wlv_result_contract_error <- function(message) {
  stop(
    structure(
      list(message = as.character(message), call = NULL),
      class = c("wlv_result_contract_error", "error", "condition")
    )
  )
}

wlv_result_contract_require_namespace <- function(package) {
  if (!requireNamespace(package, quietly = TRUE)) {
    wlv_result_contract_error(sprintf(
      "Package `%s` is required to validate published results.",
      package
    ))
  }
  invisible(TRUE)
}

wlv_result_contract_require_fields <- function(value, fields, document) {
  if (!is.list(value) || is.null(names(value)) || anyNA(names(value)) ||
      any(!nzchar(names(value))) || anyDuplicated(names(value))) {
    wlv_result_contract_error(sprintf(
      "%s must be a JSON object.",
      document
    ))
  }
  missing <- fields[!fields %in% names(value)]
  if (length(missing)) {
    wlv_result_contract_error(sprintf(
      "%s is missing required field(s): %s.",
      document,
      paste(missing, collapse = ", ")
    ))
  }
  invisible(TRUE)
}

wlv_result_contract_scalar_character <- function(value, field) {
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(value)) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` must be one non-empty string.",
      field
    ))
  }
  value
}

wlv_result_contract_timestamp <- function(value, field) {
  value <- wlv_result_contract_scalar_character(value, field)
  if (!grepl(
    "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$",
    value
  )) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` must be an RFC 3339 UTC timestamp.",
      field
    ))
  }
  parsed <- suppressWarnings(as.POSIXct(
    value,
    format = "%Y-%m-%dT%H:%M:%SZ",
    tz = "UTC"
  ))
  if (is.na(parsed) || !identical(
    format(parsed, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    value
  )) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` is not a valid UTC timestamp.",
      field
    ))
  }
  value
}

wlv_result_contract_json_object <- function(value, field) {
  if (!is.list(value) || (length(value) && is.null(names(value))) ||
      (!is.null(names(value)) &&
        (anyNA(names(value)) || any(!nzchar(names(value))) ||
          anyDuplicated(names(value))))) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` must be a JSON object.",
      field
    ))
  }
  value
}

wlv_result_contract_safe_segment <- function(value, field) {
  value <- wlv_result_contract_scalar_character(value, field)
  if (!grepl("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$", value) ||
      value %in% c(".", "..")) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` is not a safe path segment.",
      field
    ))
  }
  value
}

wlv_result_contract_role <- function(value, field) {
  value <- wlv_result_contract_scalar_character(value, field)
  if (!grepl("^[a-z0-9][a-z0-9._-]{0,127}$", value)) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` is not a portable artifact role.",
      field
    ))
  }
  value
}

wlv_result_contract_sha256_value <- function(value, field) {
  value <- wlv_result_contract_scalar_character(value, field)
  if (!grepl("^[0-9a-f]{64}$", value)) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` must be a lowercase SHA-256 digest.",
      field
    ))
  }
  value
}

wlv_result_contract_relative_path <- function(value, field) {
  value <- wlv_result_contract_scalar_character(value, field)
  if (grepl("\\", value, fixed = TRUE) ||
      startsWith(value, "/") ||
      grepl("^[A-Za-z]:", value) ||
      grepl("[<>:\"|?*]", value) ||
      grepl("[[:cntrl:]]", value)) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` must be a portable relative path.",
      field
    ))
  }
  components <- strsplit(value, "/", fixed = TRUE)[[1L]]
  if (!length(components) || any(!nzchar(components)) ||
      any(components %in% c(".", "..")) ||
      any(grepl("[. ]$", components))) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` contains an unsafe path component.",
      field
    ))
  }
  value
}

wlv_result_contract_existing_path <- function(root, relative, field) {
  relative <- wlv_result_contract_relative_path(relative, field)
  if (!dir.exists(root)) {
    wlv_result_contract_error(sprintf(
      "Result contract root does not exist: `%s`.",
      root
    ))
  }
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  components <- strsplit(relative, "/", fixed = TRUE)[[1L]]
  candidate <- do.call(file.path, c(list(root), as.list(components)))
  if (!file.exists(candidate) && !dir.exists(candidate)) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` points to a missing path: `%s`.",
      field,
      relative
    ))
  }
  resolved <- normalizePath(candidate, winslash = "/", mustWork = TRUE)
  compare_root <- root
  compare_candidate <- gsub("\\", "/", candidate, fixed = TRUE)
  compare_resolved <- resolved
  if (.Platform$OS.type == "windows") {
    compare_root <- tolower(compare_root)
    compare_candidate <- tolower(compare_candidate)
    compare_resolved <- tolower(compare_resolved)
  }
  root_prefix <- paste0(compare_root, "/")
  if (!identical(compare_resolved, compare_root) &&
      !startsWith(compare_resolved, root_prefix)) {
    wlv_result_contract_error(sprintf(
      "Result contract field `%s` resolves outside its allowed root.",
      field
    ))
  }
  if (!identical(compare_resolved, compare_candidate)) {
    wlv_result_contract_error(sprintf(
      paste0(
        "Result contract field `%s` resolves through a symbolic-link or ",
        "junction alias instead of its canonical store path."
      ),
      field
    ))
  }
  resolved
}

wlv_result_contract_read_json <- function(path, document) {
  wlv_result_contract_require_namespace("jsonlite")
  tryCatch(
    jsonlite::fromJSON(
      path,
      simplifyVector = FALSE,
      simplifyDataFrame = FALSE,
      simplifyMatrix = FALSE
    ),
    error = function(error) {
      wlv_result_contract_error(sprintf(
        "Cannot parse %s `%s`: %s",
        document,
        path,
        conditionMessage(error)
      ))
    }
  )
}

wlv_result_contract_sha256_file <- function(path) {
  wlv_result_contract_require_namespace("openssl")
  connection <- file(path, open = "rb")
  on.exit(close(connection), add = TRUE)
  unname(unclass(as.character(openssl::sha256(connection))))
}

wlv_result_contract_verify_file <- function(
    path,
    expected_sha256,
    expected_size = NULL,
    label = basename(path)) {
  expected_sha256 <- wlv_result_contract_sha256_value(
    expected_sha256,
    paste0(label, ".sha256")
  )
  information <- file.info(path)
  if (!nrow(information) || is.na(information$isdir) || information$isdir) {
    wlv_result_contract_error(sprintf(
      "Published artifact `%s` is not a regular file.",
      label
    ))
  }
  if (!is.null(expected_size)) {
    if (!is.numeric(expected_size) || length(expected_size) != 1L ||
        is.na(expected_size) || !is.finite(expected_size) ||
        expected_size < 0 || expected_size > 9007199254740991 ||
        expected_size != floor(expected_size)) {
      wlv_result_contract_error(sprintf(
        "Published artifact `%s` has an invalid declared size.",
        label
      ))
    }
    if (!identical(as.numeric(information$size), as.numeric(expected_size))) {
      wlv_result_contract_error(sprintf(
        paste0(
          "Published artifact `%s` has size %s bytes; the manifest declares ",
          "%s bytes."
        ),
        label,
        format(information$size, scientific = FALSE),
        format(expected_size, scientific = FALSE)
      ))
    }
  }
  observed_sha256 <- wlv_result_contract_sha256_file(path)
  size_after_hash <- file.info(path)$size
  if (is.na(size_after_hash) ||
      !identical(as.numeric(size_after_hash), as.numeric(information$size))) {
    wlv_result_contract_error(sprintf(
      "Published artifact `%s` changed while its checksum was being verified.",
      label
    ))
  }
  if (!identical(observed_sha256, expected_sha256)) {
    wlv_result_contract_error(sprintf(
      paste0(
        "SHA-256 mismatch for published artifact `%s` ",
        "(expected %s, observed %s)."
      ),
      label,
      expected_sha256,
      observed_sha256
    ))
  }
  invisible(TRUE)
}

wlv_result_contract_validate_schema <- function(
    value,
    expected_schema,
    expected_version,
    document) {
  wlv_result_contract_require_fields(
    value,
    c("schema", "schema_version"),
    document
  )
  schema <- wlv_result_contract_scalar_character(
    value$schema,
    paste0(document, ".schema")
  )
  version <- wlv_result_contract_scalar_character(
    value$schema_version,
    paste0(document, ".schema_version")
  )
  if (!identical(schema, expected_schema)) {
    wlv_result_contract_error(sprintf(
      "%s uses unsupported schema `%s`; expected `%s`.",
      document,
      schema,
      expected_schema
    ))
  }
  if (!identical(version, expected_version)) {
    wlv_result_contract_error(sprintf(
      "%s uses unsupported schema version `%s`; expected major version `%s`.",
      document,
      version,
      expected_version
    ))
  }
  invisible(TRUE)
}

wlv_result_contract_validate_output_contract <- function(value, document) {
  wlv_result_contract_require_fields(value, c("id", "version"), document)
  if (!setequal(names(value), c("id", "version"))) {
    wlv_result_contract_error(sprintf(
      "%s has fields outside the supported output-contract schema.",
      document
    ))
  }
  id <- wlv_result_contract_scalar_character(value$id, paste0(document, ".id"))
  version <- wlv_result_contract_scalar_character(
    value$version,
    paste0(document, ".version")
  )
  if (!identical(id, "wlvpanel-output")) {
    wlv_result_contract_error(sprintf(
      "%s uses unsupported output contract `%s`; expected `wlvpanel-output`.",
      document,
      id
    ))
  }
  if (!identical(version, "1.0.0")) {
    wlv_result_contract_error(sprintf(
      paste0(
        "%s uses incompatible output contract version `%s`; ",
        "this panel supports exactly version `1.0.0`."
      ),
      document,
      version
    ))
  }
  invisible(TRUE)
}

wlv_result_contract_validate_artifact_inventory <- function(
    artifacts,
    artifact_root,
    document,
    field_prefix,
    manifest_filename,
    required_artifacts = character()) {
  if (!is.list(artifacts) || !is.null(names(artifacts))) {
    wlv_result_contract_error(sprintf(
      "%s `artifacts` must be an array.",
      document
    ))
  }
  artifact_paths <- character(length(artifacts))
  for (index in seq_along(artifacts)) {
    artifact <- artifacts[[index]]
    label <- sprintf("%s.artifacts[%s]", field_prefix, index)
    wlv_result_contract_require_fields(
      artifact,
      c("path", "role", "size_bytes", "sha256"),
      label
    )
    if (!setequal(names(artifact), c("path", "role", "size_bytes", "sha256"))) {
      wlv_result_contract_error(sprintf(
        "%s has fields outside the supported artifact schema.",
        label
      ))
    }
    relative <- wlv_result_contract_relative_path(
      artifact$path,
      paste0(label, ".path")
    )
    if (identical(relative, manifest_filename)) {
      wlv_result_contract_error(sprintf(
        "%s cannot include itself in its artifact inventory.",
        document
      ))
    }
    wlv_result_contract_role(artifact$role, paste0(label, ".role"))
    artifact_path <- wlv_result_contract_existing_path(
      artifact_root,
      relative,
      paste0(label, ".path")
    )
    wlv_result_contract_verify_file(
      artifact_path,
      artifact$sha256,
      artifact$size_bytes,
      label = relative
    )
    artifact_paths[[index]] <- relative
  }
  if (anyDuplicated(artifact_paths)) {
    wlv_result_contract_error(sprintf(
      "%s contains duplicate artifact paths.",
      document
    ))
  }
  fst_paths <- artifact_paths[grepl("[.]fst$", artifact_paths)]
  meta_paths <- artifact_paths[grepl("[.]fst[.]meta$", artifact_paths)]
  missing_meta <- if (length(fst_paths)) {
    setdiff(paste0(fst_paths, ".meta"), artifact_paths)
  } else {
    character()
  }
  orphan_meta <- setdiff(sub("[.]meta$", "", meta_paths), artifact_paths)
  if (length(missing_meta) || length(orphan_meta)) {
    wlv_result_contract_error(sprintf(
      "%s contains an incomplete FST/sidecar pair.",
      document
    ))
  }
  if (!identical(artifact_paths, sort(artifact_paths, method = "radix"))) {
    wlv_result_contract_error(sprintf(
      "%s artifact paths must be sorted in radix order.",
      document
    ))
  }
  missing_required <- setdiff(required_artifacts, artifact_paths)
  if (length(missing_required)) {
    wlv_result_contract_error(sprintf(
      "%s is missing required artifact(s): %s.",
      document,
      paste(missing_required, collapse = ", ")
    ))
  }
  actual_paths <- list.files(
    artifact_root,
    recursive = TRUE,
    all.files = TRUE,
    full.names = FALSE,
    include.dirs = FALSE,
    no.. = TRUE
  )
  actual_paths <- gsub("\\\\", "/", actual_paths)
  actual_paths <- setdiff(actual_paths, manifest_filename)
  undeclared <- setdiff(actual_paths, artifact_paths)
  missing <- setdiff(artifact_paths, actual_paths)
  if (length(undeclared) || length(missing)) {
    details <- c(
      if (length(undeclared)) {
        sprintf("undeclared: %s", paste(undeclared, collapse = ", "))
      },
      if (length(missing)) {
        sprintf("missing: %s", paste(missing, collapse = ", "))
      }
    )
    wlv_result_contract_error(sprintf(
      "%s artifact inventory does not match its immutable directory (%s).",
      document,
      paste(details, collapse = "; ")
    ))
  }
  invisible(artifact_paths)
}

wlv_result_contract_validate_run <- function(
    manifest,
    run_dir,
    release_entry,
    required_artifacts = character()) {
  document <- sprintf("Run manifest for method `%s`", release_entry$method)
  wlv_result_contract_validate_schema(
    manifest,
    expected_schema = "wlv-run-manifest",
    expected_version = "1",
    document = document
  )
  wlv_result_contract_require_fields(
    manifest,
    c(
      "run_id", "result_id", "created_at_utc", "parent_run_id", "method",
      "output_contract", "result", "execution", "artifacts"
    ),
    document
  )
  if (!setequal(
    names(manifest),
    c(
      "schema", "schema_version", "run_id", "result_id", "created_at_utc",
      "parent_run_id", "method", "output_contract", "result", "execution",
      "artifacts"
    )
  )) {
    wlv_result_contract_error(sprintf(
      "%s has fields outside the supported run-manifest schema.",
      document
    ))
  }
  run_id <- wlv_result_contract_safe_segment(manifest$run_id, "run_manifest.run_id")
  result_id <- wlv_result_contract_sha256_value(
    manifest$result_id,
    "run_manifest.result_id"
  )
  method <- wlv_result_contract_safe_segment(manifest$method, "run_manifest.method")
  wlv_result_contract_timestamp(
    manifest$created_at_utc,
    "run_manifest.created_at_utc"
  )
  if (!is.null(manifest$parent_run_id)) {
    wlv_result_contract_safe_segment(
      manifest$parent_run_id,
      "run_manifest.parent_run_id"
    )
  }
  wlv_result_contract_json_object(manifest$result, "run_manifest.result")
  wlv_result_contract_json_object(manifest$execution, "run_manifest.execution")
  if (!identical(run_id, release_entry$run_id) ||
      !identical(result_id, release_entry$result_id) ||
      !identical(method, release_entry$method)) {
    wlv_result_contract_error(sprintf(
      "Run manifest identity does not match release entry for method `%s`.",
      release_entry$method
    ))
  }
  wlv_result_contract_validate_output_contract(
    manifest$output_contract,
    sprintf("Output contract for method `%s`", method)
  )
  wlv_result_contract_validate_artifact_inventory(
    artifacts = manifest$artifacts,
    artifact_root = run_dir,
    document = "Run manifest",
    field_prefix = "run_manifest",
    manifest_filename = "run_manifest.json",
    required_artifacts = required_artifacts
  )
  invisible(TRUE)
}

wlv_result_contract_release_entry <- function(
    entry,
    results_root,
    required_artifacts = character()) {
  wlv_result_contract_require_fields(
    entry,
    c("method", "run_id", "result_id", "manifest_path", "manifest_sha256"),
    "Release run entry"
  )
  if (!setequal(
    names(entry),
    c("method", "run_id", "result_id", "manifest_path", "manifest_sha256")
  )) {
    wlv_result_contract_error(
      "Release run entry has fields outside the supported schema."
    )
  }
  method <- wlv_result_contract_safe_segment(entry$method, "release.runs.method")
  run_id <- wlv_result_contract_safe_segment(entry$run_id, "release.runs.run_id")
  result_id <- wlv_result_contract_sha256_value(
    entry$result_id,
    "release.runs.result_id"
  )
  manifest_path <- wlv_result_contract_relative_path(
    entry$manifest_path,
    "release.runs.manifest_path"
  )
  expected_path <- paste("runs", method, run_id, "run_manifest.json", sep = "/")
  if (!identical(manifest_path, expected_path)) {
    wlv_result_contract_error(sprintf(
      paste0(
        "Release entry for method `%s` has non-canonical manifest path `%s`; ",
        "expected `%s`."
      ),
      method,
      manifest_path,
      expected_path
    ))
  }
  manifest_file <- wlv_result_contract_existing_path(
    results_root,
    manifest_path,
    "release.runs.manifest_path"
  )
  wlv_result_contract_verify_file(
    manifest_file,
    entry$manifest_sha256,
    label = manifest_path
  )
  normalized_entry <- list(
    method = method,
    run_id = run_id,
    result_id = result_id
  )
  run_manifest <- wlv_result_contract_read_json(manifest_file, "run manifest")
  run_dir <- dirname(manifest_file)
  wlv_result_contract_validate_run(
    run_manifest,
    run_dir,
    normalized_entry,
    required_artifacts = required_artifacts
  )
  run_dir
}

wlv_result_contract_validate_release <- function(
    release,
    release_id,
    channel,
    sequence,
    release_dir,
    results_root,
    required_artifacts = character()) {
  document <- sprintf("Release manifest `%s`", release_id)
  wlv_result_contract_validate_schema(
    release,
    expected_schema = "wlv-release-manifest",
    expected_version = "1",
    document = document
  )
  wlv_result_contract_require_fields(
    release,
    c(
      "release_id", "channel", "sequence", "created_at_utc", "metadata",
      "runs", "artifacts"
    ),
    document
  )
  if (!setequal(
    names(release),
    c(
      "schema", "schema_version", "release_id", "channel", "sequence",
      "created_at_utc", "metadata", "runs", "artifacts"
    )
  )) {
    wlv_result_contract_error(sprintf(
      "%s has fields outside the supported release-manifest schema.",
      document
    ))
  }
  observed_release_id <- wlv_result_contract_safe_segment(
    release$release_id,
    "release.release_id"
  )
  if (!identical(observed_release_id, release_id)) {
    wlv_result_contract_error(sprintf(
      "Release manifest identity `%s` does not match marker release `%s`.",
      observed_release_id,
      release_id
    ))
  }
  observed_channel <- wlv_result_contract_channel(release$channel)
  observed_sequence <- wlv_result_contract_scalar_character(
    release$sequence,
    "release.sequence"
  )
  if (!identical(observed_channel, channel) ||
      !identical(observed_sequence, sequence)) {
    wlv_result_contract_error(
      "Release manifest channel or sequence does not match its marker."
    )
  }
  wlv_result_contract_timestamp(
    release$created_at_utc,
    "release.created_at_utc"
  )
  wlv_result_contract_json_object(release$metadata, "release.metadata")
  if (!is.list(release$runs) || !is.null(names(release$runs)) ||
      !length(release$runs)) {
    wlv_result_contract_error("Release manifest `runs` must be a non-empty array.")
  }
  wlv_result_contract_validate_artifact_inventory(
    artifacts = release$artifacts,
    artifact_root = release_dir,
    document = "Release manifest",
    field_prefix = "release_manifest",
    manifest_filename = "release_manifest.json",
    required_artifacts = c("indicators_en.csv", "meta_indicators.csv")
  )
  run_dirs <- vapply(
    release$runs,
    wlv_result_contract_release_entry,
    character(1L),
    results_root = results_root,
    required_artifacts = required_artifacts,
    USE.NAMES = FALSE
  )
  methods <- vapply(
    release$runs,
    function(entry) as.character(entry$method),
    character(1L)
  )
  if (anyDuplicated(methods)) {
    wlv_result_contract_error("Release manifest contains duplicate methods.")
  }
  if (!identical(methods, sort(methods, method = "radix"))) {
    wlv_result_contract_error(
      "Release manifest runs must be sorted by method in radix order."
    )
  }
  names(run_dirs) <- methods
  run_dirs
}

wlv_result_contract_legacy_run_dirs <- function(results_root) {
  if (!dir.exists(results_root)) {
    return(setNames(character(), character()))
  }
  directories <- list.dirs(results_root, recursive = FALSE, full.names = TRUE)
  root <- normalizePath(results_root, winslash = "/", mustWork = TRUE)
  directories <- directories[
    normalizePath(directories, winslash = "/", mustWork = TRUE) != root
  ]
  directories <- directories[file.exists(file.path(directories, "_parameters.csv"))]
  if (!length(directories)) {
    return(setNames(character(), character()))
  }
  directories <- normalizePath(directories, winslash = "/", mustWork = TRUE)
  names(directories) <- basename(directories)
  directories
}

wlv_result_contract_channel <- function(channel = NULL) {
  if (is.null(channel)) {
    channel <- Sys.getenv("WLV_RELEASE_CHANNEL", unset = "stable")
    if (!nzchar(channel)) {
      channel <- "stable"
    }
  }
  channel <- wlv_result_contract_relative_path(channel, "channel")
  segments <- strsplit(channel, "/", fixed = TRUE)[[1L]]
  if (nchar(channel, type = "chars") > 128L ||
      any(!grepl("^[a-z0-9][a-z0-9._-]*$", segments))) {
    wlv_result_contract_error(
      "Result release channel must be a normalized lowercase identifier."
    )
  }
  channel
}

wlv_result_contract_latest_marker <- function(results_root, channel) {
  channels_candidate <- file.path(results_root, "channels")
  if (!dir.exists(channels_candidate)) {
    return(NULL)
  }
  channels_root <- wlv_result_contract_existing_path(
    results_root,
    "channels",
    "channel store root"
  )
  channel_candidate <- file.path(channels_root, channel)
  if (!dir.exists(channel_candidate)) {
    return(NULL)
  }
  channel_dir <- wlv_result_contract_existing_path(
    channels_root,
    channel,
    "channel"
  )
  json_files <- list.files(
    channel_dir,
    pattern = "[.]json$",
    full.names = FALSE
  )
  candidates <- json_files[grepl(
    "^[0-9]{20}-[A-Za-z0-9][A-Za-z0-9._-]*[.]json$",
    json_files
  )]
  invalid <- setdiff(json_files, candidates)
  if (length(invalid)) {
    wlv_result_contract_error(sprintf(
      "Channel `%s` contains invalid marker filename(s): %s.",
      channel,
      paste(invalid, collapse = ", ")
    ))
  }
  if (!length(candidates)) {
    return(NULL)
  }
  sequences <- substr(candidates, 1L, 20L)
  highest <- sort(unique(sequences), decreasing = TRUE, method = "radix")[[1L]]
  selected <- candidates[sequences == highest]
  if (length(selected) != 1L) {
    wlv_result_contract_error(sprintf(
      "Channel `%s` has more than one marker at sequence `%s`.",
      channel,
      highest
    ))
  }
  list(
    path = wlv_result_contract_existing_path(
      channel_dir,
      selected,
      "channel marker filename"
    ),
    filename = selected,
    sequence = highest,
    release_id = sub(
      "^[0-9]{20}-(.*)[.]json$",
      "\\1",
      selected
    )
  )
}

wlv_resolve_result_run_dirs <- function(
    results_root = "results",
    channel = NULL,
    required_artifacts = character()) {
  if (!is.character(results_root) || length(results_root) != 1L ||
      is.na(results_root) || !nzchar(results_root)) {
    wlv_result_contract_error("`results_root` must be one non-empty path.")
  }
  if (!is.character(required_artifacts) || anyNA(required_artifacts) ||
      any(!nzchar(required_artifacts)) || anyDuplicated(required_artifacts)) {
    wlv_result_contract_error("`required_artifacts` must contain unique file paths.")
  }
  if (length(required_artifacts)) {
    required_artifacts <- vapply(
      required_artifacts,
      wlv_result_contract_relative_path,
      character(1L),
      field = "required_artifacts"
    )
  }
  channel <- wlv_result_contract_channel(channel)
  marker_location <- wlv_result_contract_latest_marker(results_root, channel)
  if (is.null(marker_location)) {
    warning(
      sprintf(
        paste0(
          "No immutable result release marker was found for channel `%s`; ",
          "falling back to the legacy mutable `results/<method>` layout."
        ),
        channel
      ),
      call. = FALSE
    )
    legacy <- wlv_result_contract_legacy_run_dirs(results_root)
    attr(legacy, "publication_mode") <- "legacy"
    attr(legacy, "channel") <- channel
    return(legacy)
  }
  marker <- wlv_result_contract_read_json(
    marker_location$path,
    "channel marker"
  )
  document <- sprintf("Channel marker `%s`", marker_location$filename)
  wlv_result_contract_validate_schema(
    marker,
    expected_schema = "wlv-channel-marker",
    expected_version = "1",
    document = document
  )
  wlv_result_contract_require_fields(
    marker,
    c(
      "channel", "sequence", "release_id", "release_manifest_path",
      "release_manifest_sha256", "published_at_utc"
    ),
    document
  )
  if (!setequal(
    names(marker),
    c(
      "schema", "schema_version", "channel", "sequence", "release_id",
      "release_manifest_path", "release_manifest_sha256", "published_at_utc"
    )
  )) {
    wlv_result_contract_error(sprintf(
      "%s has fields outside the supported channel-marker schema.",
      document
    ))
  }
  marker_channel <- wlv_result_contract_channel(marker$channel)
  sequence <- wlv_result_contract_scalar_character(marker$sequence, "marker.sequence")
  release_id <- wlv_result_contract_safe_segment(
    marker$release_id,
    "marker.release_id"
  )
  wlv_result_contract_timestamp(
    marker$published_at_utc,
    "marker.published_at_utc"
  )
  if (!identical(marker_channel, channel)) {
    wlv_result_contract_error(sprintf(
      "Marker channel `%s` does not match selected channel `%s`.",
      marker_channel,
      channel
    ))
  }
  if (!grepl("^[0-9]{20}$", sequence) ||
      !identical(sequence, marker_location$sequence)) {
    wlv_result_contract_error(sprintf(
      "Marker sequence does not match filename `%s`.",
      marker_location$filename
    ))
  }
  if (!identical(release_id, marker_location$release_id)) {
    wlv_result_contract_error(sprintf(
      "Marker release ID does not match filename `%s`.",
      marker_location$filename
    ))
  }
  release_manifest_path <- wlv_result_contract_relative_path(
    marker$release_manifest_path,
    "marker.release_manifest_path"
  )
  expected_release_path <- paste(
    "releases",
    release_id,
    "release_manifest.json",
    sep = "/"
  )
  if (!identical(release_manifest_path, expected_release_path)) {
    wlv_result_contract_error(sprintf(
      paste0(
        "Marker has non-canonical release manifest path `%s`; expected `%s`."
      ),
      release_manifest_path,
      expected_release_path
    ))
  }
  release_manifest_file <- wlv_result_contract_existing_path(
    results_root,
    release_manifest_path,
    "marker.release_manifest_path"
  )
  wlv_result_contract_verify_file(
    release_manifest_file,
    marker$release_manifest_sha256,
    label = release_manifest_path
  )
  release <- wlv_result_contract_read_json(
    release_manifest_file,
    "release manifest"
  )
  run_dirs <- wlv_result_contract_validate_release(
    release,
    release_id,
    channel = channel,
    sequence = sequence,
    release_dir = dirname(release_manifest_file),
    results_root = results_root,
    required_artifacts = required_artifacts
  )
  attr(run_dirs, "publication_mode") <- "immutable_release"
  attr(run_dirs, "channel") <- channel
  attr(run_dirs, "release_id") <- release_id
  attr(run_dirs, "release_root") <- dirname(release_manifest_file)
  attr(run_dirs, "marker_path") <- normalizePath(
    marker_location$path,
    winslash = "/",
    mustWork = TRUE
  )
  run_dirs
}
