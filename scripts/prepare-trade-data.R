#!/usr/bin/env Rscript
# Exemplo (temporários já configurados pela campanha):
# Rscript --vanilla scripts/prepare-trade-data.R --db-root D:/Trabalho/Code/wlvdb
# A geração validada é escrita em WLV_CAMPAIGN_ROOT/results/trade-data.
# Use --install para copiar a geração imutável e promover data/trade/manifest.rds.
options(encoding = "UTF-8")
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", "Portuguese_Brazil.utf8"))
script <- grep("^--file=", commandArgs(), value = TRUE)
root <- normalizePath(file.path(dirname(sub("^--file=", "", script)), ".."), winslash = "/", mustWork = TRUE)
arguments <- commandArgs(trailingOnly = TRUE)
db_root <- file.path(root, "../wlvdb")
install <- FALSE
i <- 1L
while (i <= length(arguments)) {
  if (arguments[[i]] == "--install") { install <- TRUE; i <- i + 1L; next }
  if (arguments[[i]] != "--db-root" || i == length(arguments)) stop("Opção inválida; use --db-root <path> [--install].")
  db_root <- arguments[[i + 1L]]; i <- i + 2L
}
db_root <- normalizePath(db_root, winslash = "/", mustWork = TRUE)
campaign <- Sys.getenv("WLV_CAMPAIGN_ROOT")
if (!nzchar(campaign) || !file.exists(file.path(campaign, ".campaign.json"))) stop("Use uma campanha registrada em temp/<id>.")
campaign <- normalizePath(campaign, winslash = "/", mustWork = TRUE)
if (tolower(dirname(campaign)) != tolower(file.path(root, "temp")) ||
    !startsWith(tolower(normalizePath(tempdir(), winslash = "/")), paste0(tolower(campaign), "/"))) {
  stop("Defina WLV_CAMPAIGN_ROOT e TEMP/TMP/TMPDIR dentro de temp/<id> antes de iniciar R.")
}
for (package in c("fst", "digest", "jsonlite", "openssl")) {
  if (!requireNamespace(package, quietly = TRUE)) stop("Pacote necessário: ", package)
}
record <- jsonlite::fromJSON(file.path(campaign, ".campaign.json"))
if (!identical(record$status, "active")) stop("A campanha precisa estar ativa.")
source(file.path(root, "utils/trade_prepare.R"), encoding = "UTF-8")
generation <- wlv_prepare_trade_data(db_root, root, file.path(campaign, "results/trade-data"))
manifest <- readRDS(file.path(generation, "manifest.rds"))
if (install) {
  if (!requireNamespace("fs", quietly = TRUE)) stop("Pacote necessário para promoção atômica: fs")
  destination <- file.path(root, "data/trade", manifest$version)
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  files <- c(manifest$partitions$file, "manifest.rds")
  for (name in files) {
    path <- file.path(destination, name)
    if (file.exists(path)) {
      if (wlv_trade_prepare_sha(path) != wlv_trade_prepare_sha(file.path(generation, name))) stop("Geração instalada diverge: ", path)
    } else if (!file.copy(file.path(generation, name), path)) stop("Falha na instalação: ", path)
  }
  wlv_trade_prepare_verify_inventory(manifest$partitions[c("file", "bytes", "sha256")], destination)
  # O manifesto raiz aponta somente para os arquivos imutáveis já instalados.
  promoted <- manifest
  promoted$partitions$file <- paste(manifest$version, manifest$partitions$file, sep = "/")
  for (method in names(promoted$methods)) {
    promoted$methods[[method]]$files[] <- paste(manifest$version, promoted$methods[[method]]$files, sep = "/")
  }
  staged <- file.path(root, "data/trade", paste0(".manifest-", manifest$version, ".rds"))
  saveRDS(promoted, staged)
  if (!identical(readRDS(staged), promoted)) stop("Manifesto de promoção inválido.")
  # libuv/fs substitui o arquivo de destino por rename no mesmo diretório.
  target <- file.path(root, "data/trade/manifest.rds")
  fs::file_move(staged, target)
  if (!identical(readRDS(target), promoted)) stop("Falha na promoção do manifesto.")
  message("Comércio instalado em ", dirname(target))
}
write.csv(manifest$validation, file.path(campaign, "results/trade-reconciliation.csv"), row.names = FALSE, fileEncoding = "UTF-8")
print(data.frame(version = manifest$version, partitions = nrow(manifest$partitions),
  rows = sum(manifest$partitions$rows), bytes = sum(manifest$partitions$bytes), seconds = manifest$preparation_seconds))
