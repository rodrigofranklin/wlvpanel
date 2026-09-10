# Avaliação de eficiência percebida

Avaliação local de 10 de setembro de 2026, após a inclusão dos 23 idiomas. O código
da aplicação não foi alterado nesta avaliação. Foram acrescentadas ferramentas
de medição; a prévia habitual permaneceu em execução e os testes usaram outro
processo, com cache e downloads isolados.

A implementação posterior das quatro otimizações e sua comparação antes/depois
estão em [Resultados de desempenho](PERFORMANCE-RESULTS.md).

Há oportunidades concretas para diminuir trabalho repetido e volume de
mensagens, preservando interface, dados e interações. Ainda não há um ganho
percentual demonstrado: esta avaliação mede o estado atual e identifica trabalho
repetido e oportunidades de otimização;
uma comparação antes/depois depende de implementar e validar cada alteração.

## O que foi medido

Foram realizadas três passagens em cada cenário, em Chromium sem janela visível:

- Desktop: 1440 × 1000 px, conexão local e CPU sem limitação artificial.
- Cenário limitado: 390 × 1000 px, 4 Mbit/s de download, latência configurada de
  80 ms e CPU desacelerada quatro vezes pelo Chromium.

Cada passagem começa com um contexto de navegador novo, recarrega a página com
o cache do navegador disponível e percorre Mapa, País, Indicadores, uma série,
Comércio, dois downloads, Publicações, retorno a Sobre e troca para francês.
O mesmo processo R é reutilizado; a primeira passagem pode aquecer caches de
dados compartilhados. Não é um teste de produção, de concorrência ou de um
modelo específico de celular.

Os tempos abaixo são medianas. A abertura inicial espera o evento `load`, a aba
esperada e a ausência de atividade Shiny por 150 ms. As outras interações esperam
seu conteúdo esperado e a mesma janela de estabilidade; os downloads esperam a
conclusão do arquivo. Essa janela está incluída nos tempos. O conteúdo pode
aparecer antes de a medição terminar.

| Etapa | Desktop local | Cenário limitado |
|---|---:|---:|
| Primeira abertura de Sobre | 2,86 s | 20,56 s |
| Recarregar com cache do navegador | 2,43 s | 2,83 s |
| Abrir Mapa logo após recarregar | 0,41 s | 9,55 s |
| Abrir País em seguida | 0,24 s | 1,04 s |
| Abrir catálogo de Indicadores | 0,51 s | 1,21 s |
| Abrir a primeira série do catálogo | 0,63 s | 2,01 s |
| Primeira abertura de Comércio | 1,18 s | 1,91 s |
| Trocar para francês, em Sobre, após percorrer as abas | 1,38 s | 2,57 s |

As etapas são sequenciais: no cenário limitado, a abertura de Mapa recebe também
mensagens da inicialização ainda pendentes. Os 9,55 s não podem ser atribuídos
inteiramente ao desenho do mapa. Na primeira abertura de Sobre, o intervalo
observado foi de 2,78–6,24 s no desktop e 16,65–20,57 s no cenário limitado.
Três observações por cenário são uma referência inicial, não uma estimativa
estatística da população de usuários. Não ocorreram erros JavaScript nem erros
visíveis de renderização nos caminhos examinados.

## Achados e ordem recomendada

### 1. Evitar atualizações repetidas de telas que não estão em uso

Na rodada desktop, na troca para francês feita em Sobre depois de visitar as demais abas, chegaram
aproximadamente **314 kB de conteúdo WebSocket decodificado**, em 142 mensagens.
Entre as saídas estavam a lista de indicadores do Mapa, com 76 kB, e os dois
gráficos da abertura de País, com cerca de 56 kB. Esses componentes estavam em
abas ocultas. Os tamanhos são de conteúdo serializado, não bytes comprimidos
efetivamente transmitidos pela rede.

O código mantém várias saídas e observadores ativos quando ocultos:
`modules/countries/map.R:325`, `:426`, `:480`,
`modules/countries/country_panel.R:695` e `:740`, e
`modules/country/landing.R:202`.

**Oportunidade:** reutilizar dados e geometria existentes, atualizar somente
textos ou propriedades alterados e eliminar recomputações repetidas das telas
inativas. Separar a preparação numérica de sua apresentação traduzida também
evita repetir cálculos quando só o idioma muda.

**Condição para preservar a experiência:** manter seleções, prontidão e conteúdo
correto na primeira abertura e no retorno. A abertura de País depende atualmente
de saídas ocultas para concluir seu carregamento. Simplesmente suspender tudo
poderia travá-la ou transferir a espera para o próximo clique. A configuração
deve respeitar o comportamento documentado de
[outputOptions](https://shiny.posit.co/r/reference/shiny/latest/outputoptions.html).

### 2. Remover a duplicação inicial das traduções

Uma sessão nova em francês confirmou, por comparação exata, que o primeiro
`wlv-language` repete os mesmos rótulos e frases presentes no HTML inicial:
**97.705 bytes de JSON decodificado**, com 734 rótulos e 399 frases.
O envio ocorre em `ui.R:3–7` e novamente em `server.R:4–7`; o JavaScript já
inicializa seus dicionários a partir da página.

**Oportunidade:** suprimir apenas a mensagem inicial quando idioma e versão forem
idênticos ao conteúdo já recebido. O mecanismo deve continuar enviando mudanças
de idioma e recuperando o estado após reconexão. Este é um primeiro ajuste
pequeno, com equivalência mais simples de comprovar.

Também há espaço para separar as frases usadas pelo navegador das usadas somente
pelo R. A inspeção encontrou 61 chaves literalmente utilizadas nos JavaScript,
mas isso não é um inventário completo das chamadas dinâmicas. Uma redução exige
lista explícita e testes de cobertura; todos os 23 idiomas devem permanecer.

### 3. Tornar a preparação dos downloads mais barata

Os arquivos XLSX já são gravados somente ao clicar. Entretanto, decidir se certos
links aparecem já monta matrizes e metadados traduzidos para cada base, inclusive
em partes ocultas de País (`country_panel.R:700–741` e
`utils/download_requests.R:61–74`).

**Oportunidade:** separar a consulta de disponibilidade da preparação completa e
reutilizar matrizes numéricas entre idiomas. Uma única fonte bilateral imutável
também evitaria a segunda leitura e cópia de `m_countries.RDS` mantida pelo módulo
Download além do armazenamento de País/Comércio. O benefício de CPU e memória
ainda não foi medido isoladamente.

**Condição:** os botões devem continuar disponíveis exatamente nos mesmos casos,
inclusive zeros válidos e dados ausentes; planilhas devem manter células,
metadados, folhas, unidades e formatos. As verificações de downloads existentes
já oferecem uma base para essa comparação.

### 4. Reutilizar elementos gráficos durante a interação

Um único deslocamento do mapa de Comércio removeu os **12 grupos SVG de setas**
e criou 12 novos; nenhum grupo original foi mantido. Isso confirmou o caminho
de `www/wlv-trade.js:100–106`, acionado nos eventos de movimento e zoom.

**Oportunidade:** conservar os grupos e atualizar suas coordenadas e atributos,
mantendo curvas, ordem, espessura, tooltips, teclado e cliques. O agrupamento por
frame já existe; o ganho de fluidez ainda precisa de uma comparação antes/depois.
O ranking também encadeia até três `restyle` e um `relayout` ao alternar o país
destacado (`www/wlv-indicator-ranking.js:233–251`); uma atualização conjunta é
suportada pela [API do Plotly](https://plotly.com/javascript/plotlyjs-function-reference/#plotlyupdate),
mas seu ganho não foi medido nesta avaliação.

### 5. Aperfeiçoar a entrega dos arquivos, considerando o que já funciona

A primeira abertura desktop transferiu aproximadamente **5,36 MB por HTTP**, já
com gzip. Na recarga, a transferência HTTP caiu para cerca de **95 kB**. Assim,
compressão e cache do navegador já funcionam no ambiente medido. A comunicação
WebSocket continua separada: cerca de 712 kB decodificados por inicialização
desktop, incluindo conteúdo de abas ocultas.

Na amostra desktop, os maiores recursos HTTP foram o fundo, com 1,85 MB, o Plotly,
com 1,14 MB, a foto de Franklin, com 0,60 MB, e a logo, com 0,45 MB. O Plotly é
carregado já em Sobre. Isso aponta o peso da entrega inicial; adiar dependências
sem preservar a resposta da próxima aba apenas deslocaria a espera.

CSS e JavaScript próprios são incorporados ao HTML para impedir mistura entre
versões. Arquivos com URL por hash e snapshot imutável permitiriam cache separado
sem perder essa garantia. O HTML inicial português tinha cerca de 395 kB
descomprimidos e 95 kB comprimidos; esses são limites de tamanho, não uma economia
já obtida. A implementação deve preservar ordem de carregamento e passar pelo
teste de assets antigos. Referências:
[htmlDependency](https://rstudio.github.io/htmltools/reference/htmlDependency.html)
e [cache HTTP com URLs versionadas](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Caching).

## O que não se mostrou prioritário

A tradução faz uma varredura global de rótulos após mutações no documento. Na
rodada instrumentada, houve 18 consultas na abertura e 11 na troca para francês,
mas a soma do tempo da consulta foi de apenas 0,7 ms e 0,4 ms, respectivamente.
Essa medida exclui o processamento posterior de cada rótulo. Durante dois
segundos parado em Sobre não houve nova varredura. Existe uma oportunidade de
reduzir consultas, mas não evidência para classificá-las como o principal gargalo.

O globo já desenha sob demanda, as fotos já têm carregamento preguiçoso, as fontes
já são WOFF2 com `font-display: swap` e apenas o idioma ativo é enviado ao cliente.
Esses mecanismos devem ser preservados. A avaliação não recomenda reduzir a
qualidade das imagens, simplificar mapas, remover animações ou alterar os fluxos.

## Critério de aceite para uma implementação

Começar pela duplicação inicial dos dicionários e pela separação de preparação
numérica e apresentação; em seguida, tratar atualizações ocultas e elementos
gráficos conforme as medições. Cada mudança deve passar por comparação visual,
manutenção de seleções/foco/rolagem, primeira visita e retorno, todos os idiomas,
reconexão e igualdade das exportações. Também deve melhorar a etapa pretendida
sem piorar a etapa seguinte ou apenas transferir a espera para outro clique.
Caches adicionais precisam de chaves com a versão dos dados e todos os parâmetros;
o [bindCache](https://shiny.posit.co/r/reference/shiny/latest/bindcache.html) exige
cálculos puros e determinantes completos.

As ferramentas reutilizáveis estão em `tests/manual/measure-user-performance.cjs`,
`measure-client-work.cjs`, `measure-language-delivery.cjs` e
`summarize-user-performance.cjs`. A campanha preserva somente as evidências JSON
em `temp/efficiency-evidence-20260910/results/`, com propósito registrado no
manifesto. `performance-summary.json` contém as medianas e distingue bytes HTTP
de conteúdo WebSocket. Os deltas de CPU da recarga no arquivo bruto foram
descartados da análise, pois o Chromium reinicia esses contadores na navegação;
a ferramenta foi ajustada para futuras execuções.
