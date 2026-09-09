# Atualização incremental do mapa

## Projeção Equal Earth

O mapa principal mantém as camadas vetoriais do Leaflet e utiliza o CRS esférico implementado
em `www/wlv-equal-earth.js`. `mapFactory` aplica esse CRS antes de criar o
widget, pois o binding R normaliza o argumento `crs` para uma lista interna
de projeções. Indicadores usa o mesmo helper com uma instância independente.
O enquadramento inicial e o botão Mundo usam a caixa projetada dos vértices
dos polígonos temáticos visíveis da base selecionada. Terra de fundo,
bases ocultas, oceano e grade não ampliam essa caixa. Não há margem extra;
a proporção da janela deixa espaço
apenas no eixo que não limita a escala. `fitBounds` com apenas os cantos
geográficos não representa corretamente a extensão em Equal Earth.
O primeiro enquadramento do mapa aguarda os polígonos temáticos enviados
por proxy; novas mensagens de atributos não disparam outro enquadramento.

Zoom, pan, cliques e tooltips continuam sob controle do Leaflet. A preparação
das coordenadas é feita uma vez no navegador; mudar atributos não repete a
projeção nem a preparação da geometria. O botão Mundo/World restaura a visão
global. O ResizeObserver preserva centro e zoom depois da primeira exibição;
zoom e pan não provocam correções automáticas do enquadramento.
Fontes, contexto ONU e licenças: `docs/CARTOGRAPHY.md`.

O aplicativo solicita `preferCanvas`, mas o binding Leaflet instalado
(1.3.1+HEAD.ba6f97f) utiliza SVG para os panes nomeados. A atualização funciona
nos dois renderizadores e não depende da existência de um elemento DOM por
país. Verifique o renderizador efetivo ao atualizar essa dependência.

## Contrato de mensagens

A referência é `shiny/mapa/server.R` e `shiny/mapa/www/app.js` do e-mar,
commit `ee5424c068ed03a73de3c3d2deb2425be9a010f0`: manter os polígonos no
Leaflet e enviar cores e textos quando os filtros mudam.

No wlvpanel, `modules/countries/map.R` envia a geometria de cada base somente
na primeira utilização dentro da sessão. O cálculo reativo trabalha com os
atributos dos países, sem copiar os objetos espaciais. A mensagem
`wlv-map-update` contém o mapa e uma lista de `{id, color, label}`.
`wlv-map-years` informa os anos disponíveis e o contexto de base/indicador.
O cliente conserva seu ano mais recente e o ajusta à cobertura, sem aplicar
um valor antigo capturado pelo servidor. A animação usa os mesmos limites.

`www/wlv-map.js` encontra as feições pelo gerenciador do Leaflet. Isso também
atualiza as bases ocultas, que não aparecem em `map.eachLayer()`. Mantém os
eventos de clique, os tooltips existentes, o realce, o centro e o zoom. A fila
espera o carregamento de geometrias e desenha somente o último estado recebido
no próximo quadro. Um novo evento `map_wlv_ready` invalida o cache de geometria
do servidor quando o widget é recriado.

Os filtros têm rótulos visíveis e preservam indicador, base e ano válidos
quando o idioma muda. O tamanho é observado pelo navegador; a troca de aba e
o redimensionamento corrigem o canvas sem recentralizar o mapa. A escala mínima
permite visualizar o mundo inteiro em telas estreitas.

O mapa-base usa `www/wlv-land-110m.geojson`, um vetor local de 131 KB do
Natural Earth (127 feições), desenhado uma vez sob as camadas temáticas.
Essa base substitui os tiles CartoDB que passaram a responder com uma exigência
de chave de API. O painel não depende de um servidor externo para o fundo do
mapa. A proveniência e os hashes estão em `www/wlv-land-110m.LICENSE.md`.
`tests/manual/build-map-land.R` permite regenerar o asset em uma campanha;
somente essa preparação utiliza `sf`.

## Verificação

Execute dentro de uma campanha do wlvpanel, criada com
`scripts/manage-campaigns.ps1`. Antes dos processos, configure `TEMP`, `TMP`
e `TMPDIR` para `scratch/` e `WLV_CAMPAIGN_ROOT` para a raiz dessa campanha.

```powershell
node --test tests/manual/test-map-update.cjs tests/manual/test-equal-earth.cjs
Rscript --vanilla tests/manual/check-map-updates.R
```

O teste JavaScript verifica preservação de geometria e realce, reaproveitamento
de tooltip, bases ocultas, dados ausentes e mensagens que chegam antes da
geometria. O teste R usa as mensagens reais de `map_server` em
`shiny::testServer`, incluindo ano por base, indicador, idioma, clique sem
alterar o módulo País, cache
de bases e recriação do widget. Ele grava `results/map-update-check.json`
dentro da campanha.
Também verifica a presença de uma única base GeoJSON, o limite de 150 KB,
o enquadramento inicial do mundo e a ausência de chamadas a tiles externos.

`tests/manual/check-map-legend.cjs` abre a aba Mapa explicitamente e verifica
títulos longos reais em português e inglês. A legenda desktop cresce para
exibir título, unidade e escala completos, sem rolagem interna, em 1440 × 900,
1366 × 768 e 1024 × 600. Em 390 × 844 e 320 × 568, preserva a folha mobile
com altura limitada e permite alcançar todos os rótulos. As capturas e o
relatório `map-legend.json` ficam em `results/` da campanha ativa.

Na verificação de 06/09/2026, as duas bases iniciais (WIOD13 e WIOD16, 83
feições ao todo) exigiram 465.113 bytes no envio de polígonos do desenho
anterior e 24.034 bytes no envio de atributos: redução de 94,83%. A comparação
usa o mesmo conjunto de geometrias, cores e rótulos em JSON sem compressão.
Não mede latência de rede nem tempo total de resposta e exclui a carga inicial
e as mensagens da legenda.

Na verificação de navegador, guarde uma referência como
`map.layerManager.getLayer('shape', 'WIOD16.BRA')` e confirme a mesma identidade
depois de mudar ano ou idioma. `WLVMap.stats('map')` expõe a quantidade de
aplicações, o número de feições na última aplicação e a duração dessa aplicação
no cliente em milissegundos.

`tests/manual/check-equal-earth-browser.cjs` também inspeciona as mensagens
WebSocket e interações reais em desktop/mobile; `tests/manual/smoke-browser.cjs`
cobre as demais abas. Ambos precisam do servidor local e do Playwright,
com porta selecionada por `WLVPANEL_PORT`. Resultados e screenshots ficam em
`results/` da campanha. O teste numérico usa referências independentes do
PROJ esférico (`+proj=eqearth +R=1`), além de verificações de ida e volta,
área e limites mundiais.
