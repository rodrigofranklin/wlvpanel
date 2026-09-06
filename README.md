# WLVD — painel de valores-trabalho

O painel abre em português. O botão **English** no cabeçalho troca o idioma
com um clique; no modo inglês, o mesmo botão mostra **Português**. As sete
abas são **Sobre**, **Mapa**, **País**, **Indicadores**, **Download**,
**Publicações** e **Como citar**. A engrenagem ao lado do idioma permite
selecionar as bases disponíveis nos módulos e consultar seus métodos.
As seleções válidas são mantidas durante a troca de idioma.

O layout se adapta à largura da tela. No celular, a navegação fica no menu
do cabeçalho; filtros, comparações, mapas, séries, tabelas, informações e
downloads continuam disponíveis. O módulo **País** tem seleção própria e
preserva seu estado ao navegar: cliques no Mapa não abrem mais o perfil.
O perfil inclui um atalho para os
setores e um seletor próprio de indicador setorial. Tabelas largas têm
rolagem horizontal dentro de sua região.

O módulo **Indicadores** recupera `panel_indicators.R` do commit `ebe8168`,
removido em `c3246bd`: catálogo inicial por grupos com busca, séries por país/base,
mapa por ano/base, tabelas de todos os países e dos selecionados, seleção por
linha ou clique no mapa e exportação CSV da seleção. Os seletores ficam à
direita no desktop; as tabelas DT exibem todas as linhas, sem paginação.
O catálogo acrescenta filtro por subgrupo: como os metadados antigos só têm
grupos, usa a família do código até o primeiro ponto. Uma futura coluna
`subgroups` ou `subgroup` terá precedência. A busca ignora maiúsculas e acentos.
As conversões seguem os contratos de apresentação atuais; bases com unidades
incompatíveis aparecem em gráficos separados nesse módulo.

Os mapas dos módulos **Mapa** e **Indicadores** usam **Equal Earth**, uma projeção que preserva a proporção
das áreas na representação mundial. A escolha está alinhada ao incentivo
da Assembleia Geral da ONU ao uso de projeções equivalentes, particularmente
Equal Earth, registrado em [4 de setembro de 2026](https://press.un.org/en/2026/ga12779.doc.htm).
O painel não é um mapa oficial da ONU. A projeção não altera os valores,
nomes ou limites territoriais dos dados existentes.

O Leaflet foi mantido com um CRS Equal Earth esférico próprio e desenho
vetorial local, sem biblioteca adicional, chave ou tiles externos. O mundo completo
inclui os polos e a Antártida. No módulo Mapa, clique/toque mantém o tooltip
temático; perfis, séries nacionais e setoriais ficam em **País**, acessível por
seletor textual. O mapa de Indicadores conserva o clique para comparação.
Zoom, arrasto e navegação por teclado continuam disponíveis; o botão
**Mundo / World** restaura a visão global.

O mapa principal ocupa toda a área útil, sem moldura. Os indicadores aparecem
em uma barra lateral no desktop e em um seletor no topo no mobile, seguindo
a organização do e-mar. Ano e base são controles flutuantes, e a legenda é
retrátil. No mobile há quatro botões inferiores: **Legenda**, **Ano**,
**Base** e **Mundo**. O ano é limitado às observações da base/indicador ativos;
ao mudar de base, um ano fora da cobertura é ajustado ao ano disponível mais
próximo. A animação respeita esse intervalo.

As geometrias permanecem no navegador. Cada base temática é enviada uma vez
por instância do mapa; ano, indicador, idioma e bases já visitadas reutilizam
os mesmos polígonos e recebem apenas atributos/cores/textos e legenda.
O enquadramento é preservado ao mudar filtros, idioma ou tamanho da janela.
O mundo é enquadrado somente na primeira exibição ou pelo botão **Mundo**;
não há recentralização automática depois de zoom ou pan.

O fundo local vem de **Natural Earth Land 4.1.0**, escala 1:110 milhões,
em domínio público. Os países temáticos continuam vindo do arquivo operacional
`data/countries_sp.RDS`, preparado com `rworldmap::getMap()`; não foram
substituídos por limites da ONU. Fontes, licenças e limites de reuso de bases
oficiais estão em [docs/CARTOGRAPHY.md](docs/CARTOGRAPHY.md). Os hashes do fundo
estão em [www/wlv-land-110m.LICENSE.md](www/wlv-land-110m.LICENSE.md), e o
contrato de atualização em [tests/manual/MAP-UPDATES.md](tests/manual/MAP-UPDATES.md).
As atualizações do mapa de Indicadores também aguardam a geometria antes de
aplicar o estado mais recente. Quando uma base não tem observações no ano
escolhido, o mapa principal informa como retomar a comparação.
O mapa de **Indicadores** usa o mesmo helper Equal Earth, mantendo sua
instância, seleção, geometrias e mensagens incrementais independentes.

As traduções versionadas ficam em `config/translations.json`,
`config/indicator-translations.json` e `config/method-translations.json`.
Elas complementam o arquivo operacional `data/language_file.RDS`; não
modificam valores, métodos nem os dados de origem. A aplicação e o lançador
local configuram UTF-8 no Windows antes de carregar os módulos.

Downloads XLSX são gerados **sob demanda** a partir dos dados locais, inclusive
no módulo País. Os botões habilitam quando a combinação selecionada tem
observações, sem depender de XLSX pré-gerados. Seleções incompletas ou sem
dados exibem orientação. Os arquivos mantêm as abas `data`, `metadata` e
`specs`, com os contratos de apresentação. O CSV do módulo Indicadores é gerado a partir
da seleção, com valores nas unidades exibidas, códigos de país e método.
Os seletores de Download atualizam suas opções sem recriar o componente;
respostas de um contexto anterior não restauram uma escolha antiga após
troca de idioma. `tests/manual/check-download-races.cjs` verifica
idioma seguido imediatamente por edição e download.

**Publicações** reúne referências de Rodrigo Straessli Pinto Franklin e
Rodrigo Emanuel Santana Borges, com busca, filtro por autor/ano e links às
fontes. O catálogo local versionado fica em `config/publications.json`;
não depende de consultas externas durante o uso. Sua cobertura e a procedência
dos registros são indicadas no módulo. Atualizações bibliográficas não
alteram os dados estatísticos.
As fontes consultadas, os critérios de identidade/deduplicação e as lacunas
estão em [docs/PUBLICATIONS.md](docs/PUBLICATIONS.md).

## Execução e organização local

`D:\Trabalho\Code\wlvpanel` é o checkout principal. Os dados locais necessários
ao painel ficam em `data/` e `results/`, ignorados pelo Git. Não mantenha cópias
irmãs como `wlvpanel-runtime`.

Para abrir o painel a partir dos arquivos canônicos, com as dependências já
instaladas:

```powershell
Rscript --vanilla scripts/run-local-panel.R
```

Por padrão, o servidor escuta em `127.0.0.1:3838` e não abre o navegador sozinho.
`WLVPANEL_PORT` permite selecionar outra porta. Para acesso pela rede local,
defina `$env:WLVPANEL_HOST = '0.0.0.0'` antes de iniciar o servidor e abra
`http://<IPv4-da-máquina>:<porta>` no outro dispositivo. O firewall deve permitir
essa porta TCP a partir da rede local. Os dispositivos precisam alcançar a
mesma rede; o computador deve permanecer ligado e com o servidor em execução.
A abertura normal usa o cache
operacional em `data/`; ele tem limite de 256 MiB e expiração de sete dias.

Experimentos, testes manuais, logs, screenshots e worktrees temporárias ficam
exclusivamente em `temp/<id>/`. Os comandos abaixo requerem PowerShell 7.5 ou
posterior e não dependem dos scripts de outro projeto.

```powershell
./scripts/run-experiment.ps1 -Id contratos-001 -Executable Rscript `
  -ArgumentList @('--vanilla', 'tests/testthat.R') -Purpose 'Testes dos contratos'
```

O lançador cria a campanha, registra o commit, configura `TEMP`, `TMP`, `TMPDIR`
e `WLV_CAMPAIGN_ROOT`, salva o log em UTF-8 e registra sucesso ou falha.
Durante uma campanha, o painel direciona cache e downloads gerados para
`scratch/cache/` e `results/download/` dentro dela.

Uma campanha de várias etapas pode ser criada com
`scripts/manage-campaigns.ps1 -Action New -Id <id>`. Use `worktrees/`, `scratch/`,
`logs/` e `results/`. Os utilitários de preparação que escrevem em `data/` devem
ser executados numa worktree da campanha quando a preparação for experimental;
não sobrescreva os dados operacionais do checkout principal.

Depois de revisar os resultados e encerrar os processos:

```powershell
./scripts/manage-campaigns.ps1 -Action Complete -Id contratos-001
./scripts/manage-campaigns.ps1 -Action Clean
./scripts/manage-campaigns.ps1 -Action Clean -Apply
```

`Fail` encerra uma tentativa abandonada; `Status` lista campanhas. `-Preserve`
em `New`, `Complete` ou `Fail` conserva uma campanha necessária. `Clean` é uma
simulação; `-Apply` exclui somente campanhas encerradas e não preservadas.
Campanhas ativas, locks, links, repositórios desconhecidos e worktrees alteradas
bloqueiam exclusões. Revise os alvos exatos e limpe ao terminar a tarefa.

`temp/cleanup-20260905/` guarda somente o inventário da consolidação local e os
poucos arquivos diferentes recuperados da antiga cópia. As fontes e resultados
operacionais foram conferidos por SHA-256. As instruções permanentes estão em
`AGENTS.md`; o contrato dos resultados está em `RESULT_CONTRACT.md`.

## Verificação da interface

Além dos testes de contratos em `tests/testthat/`, os scripts abaixo exercitam
os dados reais e as interações. Execute-os com `WLV_CAMPAIGN_ROOT` apontando
para uma campanha ativa, e `TEMP`, `TMP` e `TMPDIR` para seu `scratch/`:

```powershell
Rscript --vanilla tests/manual/check-map-updates.R
Rscript --vanilla tests/manual/smoke-country-panel.R
Rscript --vanilla tests/manual/check-download-interactions.R
Rscript --vanilla tests/manual/check-panel-translations.R
node --test tests/manual/test-map-update.cjs tests/manual/test-equal-earth.cjs tests/manual/test-map-years.cjs tests/manual/test-indicators-map-js.cjs
```

`tests/manual/smoke-browser.cjs` usa Playwright e um painel local já em
execução. `WLVPANEL_PORT` seleciona a porta (38129 por padrão), e
`NODE_PATH` pode apontar para a instalação existente do Playwright. O teste
verifica as sete abas em larguras de 1440, 1024, 768, 390 e 320 px, troca de
idioma, XLSX agregados/bilaterais/multilaterais reais e filtros de publicações;
screenshots e resultados ficam na campanha.

`tests/manual/check-plotly-loading.cjs` verifica a abertura do país após trocar
o idioma, atrasando uma única carga da biblioteca de gráficos em sete segundos.
Usa as mesmas variáveis de ambiente do teste de navegador.

`tests/manual/check-map-interface.cjs` (também acessível pelo lançador
`check-equal-earth-browser.cjs`) verifica projeção, pan livre, reframe manual,
gestos touch, idiomas, anos por base, controles mobile, clique temático e
atualizações sem retransmissão de geometria em 1440/320/360/390 px.
`check-indicators-browser.cjs` cobre o catálogo, DT, CSV, seletores à direita,
Equal Earth e seleção por clique; `check-country-page.cjs` cobre País,
gráficos, detalhes técnicos, XLSX e navegação em desktop/mobile.
Use Playwright e o servidor local da mesma forma que no smoke
test, com todas as saídas direcionadas à campanha. O teste numérico
`test-equal-earth.cjs` compara pontos com PROJ, ida e volta da projeção e
preservação de área. Para conferir manualmente, abra Mapa, altere ano/base e
idioma, toque no Brasil para ver o tooltip, use a legenda e o zoom, restaure
**Mundo** e repita numa tela estreita; confira também o mapa em Indicadores
e os detalhes no módulo País.

`tests/manual/check-map-tooltip.cjs` verifica a legibilidade e contenção dos
tooltips em 1440 e 320 px, inclusive ao trocar o idioma com o tooltip aberto.
Usa o mesmo servidor, Playwright e diretórios de campanha do teste Equal Earth.

Equal Earth preserva áreas na esfera de referência, não ângulos nem
distâncias. As bases generalizadas são adequadas à comparação mundial;
ampliá-las não acrescenta detalhe e pequenos territórios podem exigir o
seletor textual em País ou Indicadores. O uso aqui não equivale a uma medição geodésica no elipsoide
WGS84 nem a uma certificação de limites pela ONU.
