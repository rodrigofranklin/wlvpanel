#!/usr/bin/env Rscript
# Launch the canonical local checkout without installing packages or opening a browser.
if (.Platform$OS.type == "windows") {
  invisible(Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8"))
}
options(encoding = "UTF-8")
script <- grep("^--file=", commandArgs(), value = TRUE)
if (length(script) != 1L) stop("Cannot locate the panel launcher.", call. = FALSE)
root <- normalizePath(file.path(dirname(sub("^--file=", "", script)), ".."),
                      winslash = "/", mustWork = TRUE)
version <- paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1L]][1L], sep = ".")
local_library <- file.path(Sys.getenv("LOCALAPPDATA"), "R", "win-library", version)
if (.Platform$OS.type == "windows" && dir.exists(local_library)) {
  .libPaths(c(local_library, .libPaths()))
}
port <- suppressWarnings(as.integer(Sys.getenv("WLVPANEL_PORT", unset = "3838")))
if (is.na(port) || port < 1024L || port > 65535L) stop("Invalid WLVPANEL_PORT.", call. = FALSE)
host <- Sys.getenv("WLVPANEL_HOST", unset = "127.0.0.1")
shiny::runApp(appDir = root, host = host, port = port, launch.browser = FALSE)
