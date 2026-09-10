# Geometrias do globo de países

`wlv-countries-110m.geojson` deriva de Natural Earth **Admin 0 — Countries**,
versão **5.1.2**, em domínio público. A base principal contém 177 feições na
escala 1:110.000.000, complementadas por 63 países e territórios ausentes nela,
obtidos da base 1:50.000.000 da mesma versão. O arquivo final contém 240 feições.

- [Fonte 110m](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_110m_admin_0_countries.geojson).
- [Fonte 50m](https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson/ne_50m_admin_0_countries.geojson).
- [Termos de uso do Natural Earth](https://www.naturalearthdata.com/about/terms-of-use/).
- Recebido em: 10/09/2026.
- SHA-256 da fonte 110m: `6866c877d39cba9c357620878839b336d569f8c662d3cfab4cb1dbe2d39c977f`.
- SHA-256 da fonte 50m: `3e458fc036ad0a66411f2c1e6cac49c5d7bfb81cb1123bc513b22511a2b7fdeb`.
- SHA-256 do asset: `b73ffea4bfc1c770027b2476d28dbd00c144f3a69ed3b8cec7e686152f72bcbc`.

Preparação: conservar todas as feições de 110m e acrescentar somente os códigos
ausentes encontrados na base de 50m. O código utiliza `ISO_A3_EH` e, quando este
é `-99`, `ADM0_A3` (com `KOS` convertido em `XKX`). Foram preservados os nomes
em inglês e português e os pontos de rótulo `LABEL_X`/`LABEL_Y`. As coordenadas
WGS84 foram arredondadas a quatro casas decimais. Os anéis de cada componente
foram invertidos quando `d3.geoArea` excedeu um hemisfério, para a convenção
esférica do D3. A orientação, portanto, é a esperada pelo D3, e não RFC 7946.

Países com área projetada inferior a 18 pixels quadrados recebem um ponto
clicável na localização de seu rótulo. Esse ponto usa a geometria e o código do
próprio país; não representa interpolação de dados ou seleção de outro país.
Fronteiras e nomes são os da fonte cartográfica; a presença no mapa não implica
disponibilidade de dados. O painel carrega somente o asset local.
