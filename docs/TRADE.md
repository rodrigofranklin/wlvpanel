# Comércio: módulo e dados

O módulo Comércio explora principalmente **transferências de valor via comércio internacional**. A abertura padrão mostra transferências líquidas, atividades fornecedoras produtivas e horas de trabalho abstrato. Exportações, importações e saldo comercial oferecem contexto. O usuário pode alternar entre parceiros e setores, aprofundar por clique, consultar mapa, série e tabela e baixar o recorte.

A arquitetura escolhida é um **módulo do Shiny atual com carregamento sob demanda**. Um aplicativo independente continua sendo uma possibilidade futura se medições de concorrência ou bloqueio do processo justificarem sua separação. Não há iframe nem servidor de banco adicional nesta implementação.

## Arquitetura e inicialização

| Arquivo | Responsabilidade |
| --- | --- |
| `modules/trade/main.R` | Interface, reatividade e navegação |
| `modules/trade/text.R` | Português e inglês |
| `modules/trade/charts.R` | Ranking divergente, composição e evolução |
| `utils/trade_data.R` | Consultas e cache independentes da interface |
| `utils/trade_map.R` | Direção, seleção e espessura dos fluxos geográficos |
| `utils/trade_workbooks.R` | XLSX de seleção e série no padrão WLVDB |
| `utils/trade_prepare.R` | Extração offline, contratos e reconciliações |
| `scripts/prepare-trade-data.R` | Lançador da preparação e instalação |
| `www/wlv-trade.css`, `www/wlv-trade.js` | Apresentação, estado e integração do mapa |

Carregar as funções e criar `wlv_trade_data_store()` não lê dados. A aba inicialmente contém o ponto de montagem; servidor e interface são montados na primeira visita a `main_nav == "trade"`. Consultas e gráficos reativos dependem de `active()`. A instância e os filtros são preservados ao sair e voltar.

O store é compartilhado pelas sessões do mesmo processo R. O bilateral pequeno é aberto uma vez após a primeira solicitação. Manifesto e partições setoriais são abertos sob demanda; nenhuma matriz mundial detalhada é lida durante cliques. O cache de detalhes usa recência de acesso e limita-se, por padrão, a **três partições e 64 MiB**, valendo o limite atingido primeiro. O bilateral possui limite separado de 128 MiB. `store$stats()` expõe leituras, acertos, entradas e bytes retidos.

Uma série com filtro setorial consulta uma partição para cada ano; o cache permanece limitado. Consultas são síncronas no processo Shiny. Os recortes pequenos atendem à demanda atual, mas concorrência e responsividade devem ser medidas novamente se a carga aumentar.

## Convenções científicas

Uma linha detalhada representa uma transação do **país vendedor** para o **país comprador**, agrupada pelo **setor fornecedor do produto**. Esse conceito de setor também é usado nas importações: não é o setor comprador nem a nacionalidade de todo o trabalho incorporado nas etapas anteriores.

Para país focal A e parceiro B:

```text
saldo monetário = exportações A→B − exportações B→A
transferência líquida = tau A→B − tau B→A
```

`tau` é a transferência direcional do WLVDB. `tau A→B` positivo indica ganho do vendedor A nessa direção. Transferência líquida positiva indica apropriação de valor pelo país focal; negativa indica cessão. A contribuição das importações para o saldo é **menos** o `tau` inverso. Tabela, cartões e XLSX apresentam essa contribuição invertida, permitindo reproduzir o saldo pela soma das contribuições.

O escopo padrão **produtivas** focaliza transferências associadas a produtos de setores classificados como produtivos pelo método. **Todas** inclui atividades improdutivas; **improdutivas** corresponde à diferença entre total e produtivas no bilateral. A classificação pertence ao fornecedor e é aplicada nas duas direções. Não inferi-la pelo nome ou cor do setor.

Exportações e importações monetárias usam **USD correntes** da fonte normalizada. Transferências em dólares são um equivalente monetário pelo fator anual do comércio:

```text
factor_usd_per_hour = exportações produtivas mundiais em USD
                     / exportações mundiais em horas incorporadas
transfer_usd = transfer_hours × factor_usd_per_hour
```

Esse fator é o inverso do `balance_factor` do WLVDB e difere do fator para preços diretos da produção. Não multiplicar novamente os USD normalizados por um milhão. Horas abstratas não representam volume físico; dólares correntes não medem crescimento real.

Valores negativos, inclusive ajustes de demanda final, são preservados. Barras e mapa usam sinais; o treemap mantém envios e recebimentos em regiões contíguas por cor, unidas sem molduras ou cabeçalhos internos. A largura de cada região é proporcional à soma das magnitudes de seu sinal; os blocos dentro dela representam cada categoria. Uma legenda externa identifica envios em vermelho e recebimentos em âmbar. As porcentagens usam a soma dos valores absolutos como denominador, não o saldo líquido. O ranking agrupa categorias pequenas conservando ganhos e perdas separadamente. Zero observado, ausência e cobertura parcial são estados diferentes.

`coverage` indica a disponibilidade dos componentes necessários ao cálculo: `complete` quando todos estão presentes, `partial` quando apenas alguns estão presentes e `missing` quando nenhum está disponível. Não mede a participação na cobertura mundial do comércio. A tabela da interface omite essa coluna; avisos de dados ausentes ou incompletos continuam visíveis quando aplicáveis. Os XLSX mantêm o campo para documentar a completude de cada observação.

No mapa, setas opcionais mostram as **transferências líquidas**: um saldo positivo desenha parceiro → país focal; negativo, país focal → parceiro. A espessura é linear na magnitude, com máximo de 14 px na seleção atual. Exibem-se até 12 parceiros geográficos por magnitude (ou o parceiro filtrado); o texto acima do mapa informa esse recorte. Curvas ligam centroides e são esquemáticas, sem representar rotas comerciais. `ROW`, valores zero e observações ausentes não geram setas. A camada acompanha zoom, deslocamento e redimensionamento; clicar em uma seta seleciona seu parceiro.

`ROW` permanece como agregado, sem polígono próprio. `WWW` não é parceiro nem é somado novamente. Transações domésticas são excluídas. As bases não são emendadas: WIOD13 tem 35 setores e WIOD16 tem 56, sem concordância automática entre eles.

## Contrato de armazenamento

`data/trade/` contém arquivos operacionais **ignorados pelo Git**. O deploy somente do código não instala os dados: preparar ou transferir uma geração validada junto com o manifesto e seu catálogo bilateral correspondente.

```text
data/trade/
  manifest.rds
  trade-v1-<identificador>/
    manifest.rds
    WIOD13-1995.rds
    ...
    WIOD16-2014.rds
```

O manifesto raiz aponta para uma geração imutável. Seu schema é `1L` e inclui versão, cobertura, eixos por método, proveniência, SHA-256 de fontes e partições, número de linhas e validações. `bilateral_sha256` vincula o detalhe ao `data/m_countries.RDS` do painel. O leitor fixa catálogo e manifesto no processo e verifica hash, identidade e grade antes de inserir dados no cache. Reiniciar o processo após promover novos dados permite adotar a geração nova; não sobrescrever partições usadas por sessões antigas.

Cada partição é uma lista com `schema_version`, `version`, `method`, `year`, `factor_usd_per_hour` e a tabela `data`:

| Coluna | Significado |
| --- | --- |
| `country` | País vendedor/origem |
| `partner` | País comprador/destino |
| `sector` | Código do setor fornecedor |
| `productive` | Classificação lógica do fornecedor |
| `exports_usd` | Exportação direcional em USD correntes |
| `embodied_hours` | Trabalho abstrato incorporado na transação |
| `transfer_hours` | `tau` em horas; positivo = ganho do vendedor |
| `transfer_usd` | `tau` em equivalente monetário anual do comércio |

A grade país × parceiro distinto × setor é completa. Linhas de valor zero não são omitidas. Uma linha ausente nunca equivale a zero.

## Preparação e instalação

O lançador aceita `--db-root <diretório-wlvdb>` e `--install`. Sem `--db-root`, usa o projeto irmão `../wlvdb`. Sem `--install`, somente prepara e valida na campanha. São preparados os dois métodos e todos os anos observados no painel; não existem argumentos CLI para método ou ano nesta versão.

Da raiz do **wlvpanel**, em PowerShell 7.5 ou superior, usar uma campanha própria. O wrapper cria/retoma a campanha e configura `TEMP`, `TMP`, `TMPDIR` e `WLV_CAMPAIGN_ROOT` antes de iniciar R:

```powershell
.\scripts\run-experiment.ps1 `
  -Id trade-refresh-20260909 `
  -Executable Rscript.exe `
  -ArgumentList @('--vanilla', 'scripts/prepare-trade-data.R', '--db-root', 'D:/Trabalho/Code/wlvdb', '--install') `
  -Purpose 'Preparar e validar os dados operacionais de Comércio'
```

Para somente preparar, omitir `'--install'`. Dependências: `fst`, `digest`, `jsonlite`, `openssl` e, para instalar, `fs`. O script não instala pacotes automaticamente.

A preparação usa `source_data/<método>/normalized/m_io.fst` e resultados `m_io*.fst`, pelos diretórios resolvidos pelo contrato de publicação. Uma release presente e inválida é rejeitada. A ausência de marcadores permite importação legada explicitamente identificada no manifesto.

Antes da extração, verificam-se geração normalizada, USD, artefatos autenticados e proveniência efetiva com EU KLEMS. Os resultados locais de agosto de 2026 têm contratos anteriores ao catálogo atual: `contract_validation = "legacy_manifested_contract_snapshot"` identifica o uso de `_unit_contract.csv` e `_normalization_contract.csv` históricos, autenticados pelo manifesto da fonte. Não se aplica o catálogo novo aos números antigos. Divergência na fonte, no hash efetivo ou na reconciliação interrompe a preparação.

O extrator lê arrays FST achatados em blocos contíguos de **16 colunas de destino**, agrega todos os anos e descarta o bloco. Não carrega a matriz mundial inteira nem relê tudo a cada ano. Usos intermediários e finais são somados; o modelo econômico não é recalculado.

Os sete agregados bilaterais são conferidos contra resultados e painel atual. Também se reconciliam exportações/importações setoriais em USD e horas e transferências setoriais totais/produtivas. Hashes são verificados novamente antes de concluir. A geração pronta fica em `temp/<id>/results/trade-data/<versão>/`; instalar copia e verifica arquivos imutáveis e promove o manifesto por rename. Uma tentativa interrompida reutiliza partições somente quando idênticas à reconstrução.

Gerações operacionais antigas não são removidas automaticamente: processos ativos podem estar fixados nelas. Após verificar a instalação, seguir a política de campanhas para limpar cópias intermediárias. Conferir alvos com `scripts/manage-campaigns.ps1 -Action Clean` antes de `-Apply`. A campanha compartilhada de implementação é encerrada pelo responsável pela integração.

## Consultas, XLSX e reprodução

A interface segue o fundo, a tipografia, os painéis e os controles das páginas
analíticas do painel. No desktop, os filtros ficam à direita; no celular,
aparecem recolhidos acima do conteúdo. O gráfico **Ganhos e perdas** ordena
as barras de cima para baixo pelo saldo crescente: do maior envio líquido
(mais negativo) ao maior recebimento líquido (mais positivo). Os grupos
**Outros** entram nessa mesma ordem; a escolha das categorias exibidas
continua baseada na magnitude. O espaçamento vertical depende do número de
linhas do rótulo, limitado a três com nome completo no hover. A composição
mantém todas as categorias e usa um mosaico compacto com porcentagens e tons
de vinho para envios e âmbar para recebimentos, com legenda externa e sem
caixas de agrupamento, mantendo as cores espacialmente agrupadas por sinal. Títulos em HTML ficam fora
da área dos gráficos para evitar cortes em telas menores.

Exemplo R, com temporários já direcionados à campanha:

```r
source("utils/trade_data.R", encoding = "UTF-8")
store <- wlv_trade_data_store()
store$stats()  # zero leituras até este ponto
bilateral <- store$bilateral("WIOD16")
detail <- store$detail("WIOD16", 2007)
sectors <- wlv_trade_snapshot(
  bilateral, country = "BRA", year = 2007, partner = "CHN",
  metric = "transfer", scope = "productive", unit = "value",
  dimension = "sector", detail = detail
)
store$stats()
```

Os downloads da seleção e da série são **XLSX**, produzidos com o gerador de apresentação canônico `save_my_xlsx`, em ambiente isolado e somente ao solicitar o download. As folhas `data`, `metadata` e `specs` seguem os estilos, cabeçalhos, filtros, congelamento de painéis e formatos numéricos do WLVDB. Na seleção, a folha de dados contém rótulo, código, ano, valor da medida, contribuições das exportações e importações e cobertura. Na série, os anos ficam nas colunas e as três medidas nas linhas, com cobertura anual em linha própria. Metadados documentam o significado das colunas; especificações registram base, filtros, unidade, convenção de sinal, versão e proveniência. Números são preservados sem arredondamento dos dados; observações ausentes permanecem vazias.

`export_contribution` é igual a `outgoing`. `import_contribution` é `-incoming` nas transferências e no saldo comercial; nas métricas de fluxo bruto permanece `incoming`. `sign_convention` acompanha a medida: `outgoing_minus_incoming; positive_receipt_for_focal_country` para transferências, `outgoing_minus_incoming; positive_trade_surplus` para saldo, `outgoing` para exportações e `incoming` para importações. Assim, `value` de um fluxo bruto não é confundido com um saldo.

O botão de copiar link foi removido. URLs existentes com filtros `trade_*` continuam sendo lidas. Se a versão instalada diferir de `trade_version`, a interface avisa que os dados foram atualizados e mostra os valores da geração atual. Esse parâmetro identifica a mudança, mas não recupera nem fixa uma geração histórica.

Testes de Comércio, incluindo os helpers do projeto:

```powershell
.\scripts\run-experiment.ps1 `
  -Id trade-tests-20260909 `
  -Executable Rscript.exe `
  -ArgumentList @('--vanilla', 'tests/testthat.R') `
  -Purpose 'Validar consultas, extração e gráficos de Comércio'
```

Para a suíte completa, usar `@('--vanilla', 'tests/testthat.R')`. Os testes cobrem sinais, inversão do país focal, produtividade, unidades, ausência versus zero, grade, integridade, cache, extração parcial, gráficos com valores negativos, fluxos e XLSX. `node tests/manual/test-trade-js.cjs` verifica os filtros móveis, a compatibilidade de URLs e o ciclo de vida do mapa e das setas. A preparação real gera `results/trade-reconciliation.csv` na campanha.

A integração foi conferida no navegador com dados locais: abertura sob demanda, Brasil–China, clique do parceiro para os setores, troca de idioma sem perda da seleção, mapa, composição, tabela, séries e exportações. Em 10 de setembro, foram conferidos rótulos setoriais sem sobreposição, títulos HTML, treemap compacto, setas de transferência e downloads XLSX com dados reais. Um link WIOD13/Estados Unidos/Brasil/2005 em dólares restaurou os filtros em tela de 390 px; o recorte de produtos químicos carregou a série setorial 1995–2007. A suíte R completa passou sem falhas; os avisos Plotly nos testes correspondem a observações ausentes inseridas deliberadamente e eventos de gráficos ainda não montados nas sessões simuladas. O teste específico de sensibilidade a maiúsculas de caminhos é omitido no Windows.

## Primeira geração preparada

Em 9 de setembro de 2026 foi instalada `trade-v1-ad7c8551d26eef34c25f`, com **28 partições**, **2.335.480 linhas** e **62.930.662 bytes** de partições. Cobertura: WIOD13 1995–2007 e WIOD16 2000–2014. A restrição de 2008–2009 na WIOD13 acompanha a decisão existente do painel sobre dados de capital.

A preparação levou 53 segundos localmente. Foram aprovadas 364 reconciliações, comparando 689.941 números; diferença absoluta máxima de 0,000366 e relativa de aproximadamente `3e-11`. WIOD13/2007 ocupa 1,56 MB em disco e 3,45 MB como tabela em memória; WIOD16/2014 ocupa 2,85 MB e 6,37 MB. Leituras de 0,02–0,03 s podem aproveitar cache do sistema operacional e não incluem renderização, rede ou concorrência.

A primeira etapa está implementada; o encerramento da campanha registra a conferência final da interface. Usos intermediários/finais separados, relações entre setores comprador e vendedor, participação mundial e indicadores de complexidade permanecem fora desta etapa.
