# Mapa-base Natural Earth

`wlv-land-110m.geojson` deriva de **Natural Earth Land, escala 1:110.000.000**.
O arquivo `ne_110m_land.VERSION.txt` do pacote recebido identifica a versão
**4.1.0**. O asset contém 127 feições, com coordenadas WGS84 arredondadas a
quatro casas decimais, e ocupa 131.098 bytes. Os atributos originais foram
substituídos por identificadores numéricos; a geometria foi preservada nessa
precisão.

- Fonte: [Natural Earth — Land](https://www.naturalearthdata.com/downloads/110m-physical-vectors/110m-land/).
- Pacote: [ne_110m_land.zip](https://naturalearth.s3.amazonaws.com/110m_physical/ne_110m_land.zip).
- Licença: domínio público, conforme os [termos do Natural Earth](https://www.naturalearthdata.com/about/terms-of-use/).
- Recebido em: 06/09/2026.
- SHA-256 do ZIP: `1926c621afd6ac67c3f36639bb1236134a48d82226dc675d3e3df53d02d2a3de`.
- SHA-256 do GeoJSON: `3af75c7744608499f616dda0574787aeb46d2c31819f81aa0764b0f693806319`.

Regeneração: `tests/manual/build-map-land.R`, com uma campanha ativa do
wlvpanel. O pacote R `sf` é usado apenas nessa preparação. A execução do
painel utiliza diretamente o asset local e não solicita tiles externos.
