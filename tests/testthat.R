if (.Platform$OS.type == "windows") {
  invisible(Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8"))
}
options(encoding = "UTF-8")
library(testthat)

test_dir("tests/testthat", reporter = "summary")
