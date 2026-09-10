# Plano do explorador Comércio

Plano de 9 de setembro de 2026, atualizado após a decisão de implementar Comércio como módulo do aplicativo atual. O foco principal é explicar transferências de valor via comércio internacional. A primeira etapa está implementada; a conferência final da interface pertence ao encerramento da campanha. Operação, contratos e reprodução estão em [TRADE.md](TRADE.md).

## 1. Direção recomendada

Implementar o explorador como **módulo do Shiny atual, montado somente na primeira abertura de Comércio**, com consultas independentes da interface. A abertura padrão apresenta transferências líquidas nas atividades fornecedoras produtivas, em horas de trabalho abstrato. Comércio monetário e trabalho incorporado oferecem contexto para explicar o saldo por parceiro e setor.

A preparação offline, a leitura de recortes e o cache limitado reduzem o trabalho durante a navegação. Esconder uma aba não basta: montagem e consultas dependem explicitamente da primeira visita e do estado ativo. O módulo não carrega matrizes mundiais na inicialização.

Um processo independente será considerado se medições de bloqueio, concorrência ou manutenção justificarem a separação. O código de consulta permite extrair o módulo mais tarde. A implementação autorizada não depende de iframe nem da capacidade de hospedar um segundo aplicativo.

Não há necessidade identificada de PostgreSQL, infraestrutura distribuída ou uma API HTTP separada na primeira versão. Shiny pode consultar arquivos locais no servidor e enviar aos gráficos apenas os resultados necessários.

## 2. O que aproveitar do Atlas

Foram examinados o site público e os controles reais de composição e evolução temporal, no navegador interno. O explorador oferece composição, mapa, evolução histórica, participação mundial, espaço de produtos e oportunidades de diversificação. Composição e evolução alternam produtos/localizações, origem/destino, ano/período e grau de detalhamento; há busca, notas, download e opções de valor/participação.

Adotar a lógica de exploração:

- Uma pergunta explícita sobre o gráfico, formada pelos filtros: “Para onde o Brasil exportou em 2007?” ou “Quais setores explicam as transferências líquidas do Brasil com a China?”.
- Seleção persistente ao trocar a visualização, em vez de reiniciar a investigação em cada tela.
- Alternância entre composição por setor e por parceiro, com clique para aprofundar e um caminho visível para voltar.
- Cores consistentes, valores e participações nos tooltips, busca no gráfico, tabela equivalente e exportação do recorte.
- Leitura de URLs existentes com base, país, parceiro, ano, métrica, unidade, escopo, visualização e versão; o botão de copiar link foi removido. `trade_version` permite avisar sobre atualização dos dados, mas não fixa nem recupera uma geração histórica. A versão também acompanha o XLSX.

As bases do WLVDB são insumo-produto, com 35/56 setores e serviços. Não possuem o detalhe de milhares de produtos HS do Atlas. Espaço de produtos, ECI/PCI e projeções de crescimento exigem outras definições, fontes e validações; ficam fora do escopo inicial. Uma rede de transações setoriais seria uma visualização diferente do espaço de produtos de Harvard.

Referências: [composição](https://atlas.hks.harvard.edu/explore/treemap), [evolução](https://atlas.hks.harvard.edu/explore/overtime), [participação mundial](https://atlas.hks.harvard.edu/explore/marketshare), [espaço de produtos](https://atlas.hks.harvard.edu/explore/productspace).

## 3. Dados disponíveis e limites

Inventário e preparação local: arquivos, documentação e metodologia foram conferidos. As matrizes detalhadas foram agregadas por blocos, com validação contra todos os bilaterais e os principais indicadores setoriais. A primeira geração operacional tem 28 partições, 2.335.480 linhas e 62,9 MB em disco. Medições e limites estão em [TRADE.md](TRADE.md#primeira-geração-preparada).

| Fonte | WIOD13 | WIOD16 | Aplicação |
| --- | --- | --- | --- |
| Países individualizados + ROW | 40 + 1 | 43 + 1 | Parceiros e mapa |
| Setores | 35 | 56 | Composição e detalhe |
| Categorias de demanda final | 5 | 5 | Usos finais |
| Período de cálculo disponível | 1995–2009 | 2000–2014 | Séries por base |
| Período com observações no painel atual | 1995–2007 | 2000–2014 | Cobertura inicial da UI |
| `results/<método>/m_countries.fst` | 1.386.627 bytes | 1.599.514 bytes | Matrizes país × parceiro |
| `results/<método>/sea_sectors.fst` | 8.762.959 bytes | 12.183.591 bytes | Contas setoriais sem parceiro |
| `results/<método>/m_io*.fst` | 952.891.295 bytes | 2.811.044.483 bytes | Detalhamento de valor/transferências |
| Fonte normalizada `m_io.fst` | 236.789.473 bytes | 665.158.796 bytes | Detalhamento monetário |

No painel, `data/m_countries.RDS` reúne as duas bases em 2.680.082 bytes, aproximadamente 2,7 MB decimais. Tamanho comprimido em disco não é uma medição de RAM ou latência.

As sete matrizes bilaterais são `exports_mp`, `exports_productive_mp`, `exports_values`, `transfers_values`, `transfers_productive_values`, `transfers_dp` e `transfers_productive_dp`. Importações usam os mesmos fluxos pela perspectiva do comprador. Saldos comparam os dois sentidos.

O detalhamento pode ser obtido somando as matrizes existentes por país vendedor, setor fornecedor, país comprador e tipo de uso. Isso não exige refazer a solução de Leontief, desde que os resultados existentes e a fonte monetária pertençam à mesma geração validada.

A fonte monetária deve ser `source_data/<método>/normalized/m_io.fst`, compatível com `_source_provenance.csv`. A fonte bruta está em milhões de USD; a normalizada está em USD. Não misturar arquivos apenas porque possuem os mesmos rótulos de países/anos.

Os diretórios `results/channels`, `results/releases` e `results/runs` estão vazios no checkout examinado. Os arquivos inventariados estão nos diretórios por método. Sua existência não comprova uma release publicada íntegra: a preparação do Comércio deve vincular e validar a geração controladora, usando o contrato de publicação atual ou uma importação legada explicitamente identificada e validada.

Fontes locais: [guia de resultados do WLVDB](../../wlvdb/docs/guide-pt.md), [metodologia](../../wlvdb/docs/methodology-pt.md), [catálogo de fontes](../../wlvdb/catalog/sources.csv), [reduções bilaterais](../../wlvdb/scripts/modules/native/reduced_matrix_modules.R), [preparação do painel](../utils/prepare_data.R), [contrato do painel](../RESULT_CONTRACT.md).

## 4. Funcionalidades propostas

| Visão | Pergunta | Visualização | Dados/trabalho |
| --- | --- | --- | --- |
| Composição por parceiros | Com quem o país comercia? | Treemap e ranking | Bilaterais já preparados |
| Composição por setores | O que o país exporta/importa? | Treemap setorial | Contas setoriais; recorte por parceiro precisa extração |
| Mapa | Onde estão os parceiros, ganhos e perdas? | Mapa com escala adequada à métrica | Bilaterais; reutilizar convenções cartográficas do painel |
| Evolução | Como o comércio mudou? | Linhas/áreas por parceiro ou setor, valor ou participação | Séries; evitar áreas empilhadas comuns para saldos com sinal |
| Transferências | Quanto o país recebe/cede e de quem? | Barras divergentes, mapa e decomposição | Diferença entre os sentidos, com sinal explícito |
| Relação bilateral | O que circula entre dois países? | Dois sentidos lado a lado e decomposição setorial | Extração parceiro × setor |
| Participação mundial | Qual a participação nas exportações mundiais deste setor? | Linhas/ranking | Denominador definido na mesma base, universo e ano |
| Usos | A exportação vai para produção ou uso final? | Barras; Sankey opcional para fluxos adequados | Extração do bloco intermediário/final |
| Relações intersetoriais | Que setor fornece a qual atividade ou uso final? | Matriz de calor e fluxo selecionado | Segunda etapa, recortes mais detalhados |

Primeira etapa implementada: transferências em ranking divergente, composição por parceiros/setores, mapa, evolução e tabela, com filtros de parceiro e setor e exportação. O percurso central é país → parceiro → setores que explicam a transferência. A conferência visual e da navegação integra o fechamento da implementação.

Usos intermediários/finais e participação mundial podem entrar em seguida. O detalhe completo setor fornecedor × setor comprador e métricas novas de concentração/diversificação ficam para uma etapa posterior.

## 5. Organização da interface

O explorador ocupa a área útil da aba, usando a identidade visual e os idiomas do WLVD. A navegação interna alterna ranking, composição, mapa, evolução e tabela. O destaque inicial é o saldo de apropriação/cessão e suas contribuições nas exportações e importações.

Controles básicos sempre visíveis: base, país focal, fluxo/métrica e ano ou período. A métrica organiza opções válidas: exportações, importações, saldo comercial e transferências líquidas; unidades monetárias e trabalho incorporado aparecem onde fazem sentido. “Transferências a preços de mercado” não é uma combinação disponível equivalente às demais.

Parceiro, setor, classificação produtiva e uso aparecem conforme a pergunta e a disponibilidade do recorte. O rótulo do setor informa se descreve o produto/fornecedor ou a atividade compradora. A vista principal alterna Parceiros/Setores e deixa claro o total ao qual as participações se referem.

O gráfico vem com título contextual, unidade e cobertura. Tabela, download, definições e proveniência ficam acessíveis sem ocupar a área principal com texto técnico. Estado sem observações deve ser diferente de zero; uma seleção incompatível deve oferecer uma escolha válida.

No celular, reduzir controles a painéis recolhíveis e favorecer ranking quando o treemap ficar ilegível. Navegação por teclado, alternativa tabular e sinais que não dependam apenas de cor são requisitos da conferência da interface.

## 6. Como servir os dados

```mermaid
flowchart LR
  A[Fontes e resultados compatíveis do WLVDB] --> B[Preparação e validação fora das consultas]
  B --> C[Versão de dados de Comércio em disco]
  P[Painel: abrir aba Comércio] --> S[Módulo Shiny montado na primeira visita]
  S --> Q[Consulta do recorte e cache limitado]
  Q --> C
  Q --> V[Dados pequenos para gráfico e tabela]
```

### Preparação

Foi criada uma camada derivada com versão própria e vínculo à fonte/resultado, sem alterar as matrizes originais. A preparação é retomável e processa blocos com memória limitada.

A partição RDS contém versão, método, ano, fator de conversão e a tabela:

`country, partner, sector, productive, exports_usd, embodied_hours, transfer_hours, transfer_usd`.

O manifesto guarda países e ROW, setores, condição produtiva, unidades e proveniência. Importações usam a direção inversa dos mesmos fluxos. A classificação produtiva pertence ao setor fornecedor e ao método. Usos intermediários e finais são somados nesta etapa.

Os totais país-parceiro já existem no bilateral pequeno do painel e atendem às séries sem filtro setorial. Setor comprador e demandas finais separadas ficam para uma camada futura.

Uma seleção país/ano tem até 1.400 combinações parceiro × setor na WIOD13 e 2.408 na WIOD16, excluindo o próprio país e incluindo ROW. A primeira geração, com os 28 método-anos efetivamente disponíveis no painel, contém 2.335.480 linhas internacionais. Os gráficos recebem agregados muito menores.

### Consulta

- Os bilaterais pequenos são carregados uma vez na primeira utilização, compartilhados entre sessões do mesmo processo.
- O detalhe utiliza partições RDS por método/ano. Ler uma partição atende várias visualizações da mesma seleção.
- O FST atual armazena arrays achatados; seu leitor reconstitui o objeto inteiro. Não tratar esse layout como tabela pronta para filtrar por país ou setor. Preparar recortes consultáveis.
- Se novos filtros e volumes justificarem, comparar com Parquet consultado por DuckDB local. As medições iniciais permitem usar RDS sem um serviço de banco.
- Devolver apenas agregados, dados de gráficos e páginas de tabela. Downloads grandes devem ter caminho próprio, limite de concorrência e reutilização de resultado pronto.
- Cache de partições com limite em bytes/entradas, chaveado por versão, método, ano e SHA. Métricas, escopos e unidades derivam da mesma partição. Rótulos são traduzidos na apresentação.
- Uma requisição antiga não deve substituir a seleção mais recente. Não consultar com filtros incompletos; evitar disparar várias leituras enquanto a pessoa ajusta um período.

### Integração e implantação

O módulo é registrado na navegação do painel e montado uma vez por sessão, na primeira abertura. A interface e os filtros permanecem preservados ao voltar; consultas e gráficos exigem a aba ativa. O idioma acompanha o painel. O link reproduz os filtros e informa a versão que originou a seleção; se ela divergir da geração instalada, a interface avisa e usa os dados atuais.

O store compartilhado do processo lê o bilateral na primeira solicitação e mantém até três partições setoriais, limitadas também a 64 MiB. Uma consulta anual não abre a matriz mundial. Uma evolução com filtro setorial pode ler várias partições, conservando o limite de cache.

`data/trade/` é operacional e ignorado pelo Git: o deploy de código deve ser acompanhado da preparação ou instalação dos dados correspondentes. O mesmo processo Shiny atende os demais módulos; aumento de carga exige medir concorrência e responsividade.

Preparar a geração completa, validar e promover seu manifesto após copiar as partições imutáveis. Cada processo fixa uma versão coerente; não sobrescrever partições que sessões existentes possam usar. Reiniciar o processo após a instalação permite adotar a geração nova.

Fontes técnicas: [escopos Shiny](https://shiny.posit.co/r/articles/improve/scoping/), [cache Shiny](https://shiny.posit.co/r/articles/improve/caching/), [tarefas demoradas](https://shiny.posit.co/r/articles/improve/nonblocking/), [leitura FST](https://www.fstpackage.org/reference/write_fst.html).

## 7. Regras científicas que afetam os gráficos

1. Uma célula direcional de transferência positiva representa ganho do vendedor. Transferência líquida de um país/par bilateral é saída menos entrada na orientação das matrizes. Não confundir esse sinal com o sentido físico/monetário da seta.
2. O helper histórico de downloads forma `TT` como `TR - TS` em `utils/download_requests.R`. O novo módulo usa o contrato explícito saídas menos entradas, reconciliado com os indicadores setoriais canônicos. Não compartilha aquela transformação histórica de saldo.
3. Transferências em equivalente monetário usam o fator anual do comércio. Ele difere do fator de preços diretos da produção. Unidades vêm do contrato da geração; não inferir multiplicadores a partir do nome da variável.
4. Treemaps e Sankeys comuns não comportam valores negativos como áreas/larguras. Separar sinais, usar barras divergentes ou explicitar magnitudes e sinal. Preservar negativos de demanda final documentados; não truncar ou ocultar para acomodar o gráfico.
5. A participação de um item em um saldo líquido que pode se aproximar de zero não é uma participação usual de composição. Mostrar valores e decomposição de ganhos/perdas, com denominadores explícitos quando houver porcentagens.
6. Importações setoriais nas contas atuais identificam o setor fornecedor do produto, incluindo usos finais. Um filtro de setor comprador precisa da matriz detalhada.
7. A origem do produto não identifica a nacionalidade de todo o trabalho incorporado a montante. Uma decomposição internacional da origem do trabalho ou de valor adicionado nas cadeias exige metodologia adicional; não rotular um Sankey de transações como se já medisse isso.
8. USD correntes não representa crescimento real. Horas abstratas são resultados do modelo, não volume físico de mercadorias.
9. ROW é agregado; WWW é total. Não desenhar ROW como um país individual nem somar WWW novamente. “Outros parceiros” do agrupamento visual deve ser diferente de ROW.
10. Não emendar WIOD13 e WIOD16 nem comparar seus setores como equivalentes sem concordância explícita. A cobertura de 2008–2009 da WIOD13 permanece uma decisão metodológica registrada, não um simples ajuste de slider.
11. Manter ausência, não aplicabilidade e cobertura parcial distintas de zero. Cancelamento aritmético não comprova completude dos dados.

## 8. Sequência de implementação e critérios de aceite

1. **Contrato e extrator — implementados:** geração normalizada vinculada à proveniência efetiva, inclusive EU KLEMS, contratos históricos autenticados na importação legada e 28 partições anuais preparadas. Sete bilaterais e seis indicadores setoriais reconciliados.
2. **Percurso de transferências — implementado e conferido:** país → parceiro → setor, ranking divergente, composição com sinais, tabela, download e compartilhamento do estado.
3. **Cobertura e vistas — implementadas e conferidas:** WIOD13 1995–2007, WIOD16 2000–2014, mapa, evolução, ROW e três escopos produtivos.
4. **Integração — módulo sob demanda:** primeira visita monta a interface; consultas exigem a aba ativa; idioma e filtros são preservados. Navegação, gráficos, exportação, idioma e comportamento móvel conferidos com dados locais.
5. **Validação operacional:** leituras RDS anuais locais de 0,02–0,03 s, sem rede/renderização e possivelmente com cache do sistema. Testes cobrem integridade, ausência, sinais e cache. A conferência final deve observar abertura e navegação; concorrência de produção será medida conforme a demanda.
6. **Segunda etapa futura:** usos separados e participação mundial; depois detalhe por setor comprador, novos indicadores ou rede de transações, conforme utilidade observada.

Critérios essenciais: agregados conciliados com o WLVDB; exportação e gráfico coerentes; sinal/unidade inequívocos; versão única em cada resposta; nenhuma leitura de matriz mundial durante cliques comuns; nenhum carregamento de dados de Comércio antes de abrir a aba; cache limitado; respostas antigas descartadas; painel utilizável durante a consulta; filtros acessíveis e preservados entre vistas.

Como metas iniciais para o ensaio, buscar atualização em cache abaixo de 0,5 s e consulta comum sem cache abaixo de 2 s no servidor de destino, separando tempo de rede/renderização. São objetivos de projeto a medir, não desempenho demonstrado. O formato de armazenamento e os limites de memória/concorrência serão definidos pelos resultados desse ensaio.

Decisões incorporadas: módulo do aplicativo atual, carregamento sob demanda, transferências como foco principal e parceiro × setor na primeira etapa. Separação dos usos e eventual processo independente dependem da utilidade e das medições futuras; não bloqueiam esta implementação.
