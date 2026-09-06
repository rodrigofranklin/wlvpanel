# Run through scripts/run-experiment.ps1: no browser is opened.
campaign <- Sys.getenv("WLV_CAMPAIGN_ROOT", unset = "")
if (!nzchar(campaign)) stop("Launch this smoke through run-experiment.ps1.", call. = FALSE)
version <- paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L], sep = ".")
library_path <- file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", version)
if (.Platform$OS.type == "windows" && dir.exists(library_path)) .libPaths(c(library_path, .libPaths()))
root <- normalizePath(".", winslash = "/", mustWork = TRUE)
started <- FALSE
app <- shiny::shinyAppDir(root)
original_start <- app$onStart
app$onStart <- function() {
  if (is.function(original_start)) original_start()
  started <<- TRUE
  later::later(function() shiny::stopApp(), delay = 1)
}
shiny::runApp(app, host = "127.0.0.1", port = 38127, launch.browser = FALSE)
stopifnot(started, dir.exists(file.path(campaign, "scratch/cache")),
          dir.exists(file.path(campaign, "results/download")))
cat("PANEL_STARTUP_SMOKE_OK\n")
