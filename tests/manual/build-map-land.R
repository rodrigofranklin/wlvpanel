# Preparação do único asset estático do mapa-base, dentro de uma campanha.
# sf é necessário apenas para regenerar este asset, não para executar o painel.
campaign <- Sys.getenv("WLV_CAMPAIGN_ROOT")
stopifnot(nzchar(campaign), dir.exists(campaign))
source_url <- "https://naturalearth.s3.amazonaws.com/110m_physical/ne_110m_land.zip"
directory <- file.path(campaign, "scratch", "natural-earth-land")
dir.create(directory, showWarnings = FALSE)
archive <- file.path(directory, "ne_110m_land.zip")
if (!file.exists(archive)) download.file(source_url, archive, mode = "wb")
members <- unzip(archive, list = TRUE)$Name
stopifnot(!any(grepl("(^[/\\\\]|(^|[/\\\\])\\.\\.([/\\\\]|$))", members)))
unzip(archive, exdir = directory)
land <- sf::st_read(file.path(directory, "ne_110m_land.shp"), quiet = TRUE)
stopifnot(sf::st_is_longlat(land), nrow(land) > 100L)
asset <- sf::st_sf(id = seq_len(nrow(land)), geometry = sf::st_geometry(land))
sf::st_write(asset, "www/wlv-land-110m.geojson", driver = "GeoJSON",
  layer_options = c("RFC7946=YES", "COORDINATE_PRECISION=4"),
  delete_dsn = TRUE, quiet = TRUE)
sha256 <- function(path) {
  connection <- file(path, "rb")
  on.exit(close(connection))
  paste(openssl::sha256(connection))
}
jsonlite::write_json(list(source = source_url,
  archive_sha256 = sha256(archive),
  features = nrow(land),
  source_version = trimws(readLines(file.path(directory, "ne_110m_land.VERSION.txt"))),
  asset_bytes = file.info("www/wlv-land-110m.geojson")$size,
  asset_sha256 = sha256("www/wlv-land-110m.geojson")),
  file.path(campaign, "results", "map-land-source.json"), auto_unbox = TRUE, pretty = TRUE)
cat("Local basemap asset created.\n")
