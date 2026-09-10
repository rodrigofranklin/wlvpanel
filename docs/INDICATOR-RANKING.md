# Ranking histórico de indicadores

A terceira visualização de Indicadores compara a posição dos países ao longo
de todos os anos disponíveis para uma base. A superfície é o gráfico Plotly
do próprio painel Shiny. Série histórica, Mapa, tabelas e exportações mantêm
suas funções e seleções.

## Dados e leitura

- A origem é a mesma série convertida usada pelos demais componentes:
  `wlv_indicators_series`, com os contratos de unidades do WLVDB.
- Cada ano e base tem um universo próprio de países com valores finitos.
  A seleção de países apenas destaca trajetórias; não recalcula esse universo.
- A posição 1 corresponde ao maior valor. Valores iguais compartilham a
  menor posição do empate, por exemplo 1, 1, 3. A posição não significa
  necessariamente um resultado social ou econômico melhor.
- Mundo, resto do mundo e agregados regionais são excluídos. Países e
  territórios individuais, como Hong Kong e Taiwan, permanecem elegíveis.
- Ausências não viram zero. A linha se interrompe em anos sem observação;
  a quantidade de países por ano é informada no cabeçalho.
- O eixo vertical coloca a posição 1 no topo. As cores representam quintos
  do ranking de cada ano, com a definição explícita na legenda. Os valores
  originais continuam no payload; os rótulos compactos usam quatro algarismos
  significativos e sufixos k, M, G e T quando necessários.

## Referência visual e hover

Referência solicitada: [ranking do Atlas of Economic Complexity](https://atlas.hks.harvard.edu/rankings).
A inspeção em navegador em 10/09/2026 confirmou faixas anuais, contornos em
degraus, posição acima e valor abaixo dos segmentos, nome à direita e
atenuação do restante do gráfico durante o hover. A paleta de cinco cores segue
a identidade WLV: vermelho escuro `#8D2028`, vermelho claro `#CC858A`,
vermelho muito claro `#F2DCDD`, âmbar claro `#FCE7C0` e âmbar `#F6AE2D`.
Ela representa posição relativa,
sem importar o ECI ou as interpretações de complexidade econômica.

As faixas não têm separadores horizontais. A grade vertical anual é tracejada
e permanece visível acima das faixas, com e sem hover.

Passar sobre a célula de qualquer país/ano destaca seu histórico completo.
Os países escolhidos no seletor continuam destacados; sair da área do gráfico
retira apenas o destaque temporário e restaura a saturação de todas as faixas.
Sem hover, selecionados mantêm seus contornos e rótulos, com a mesma cor das
faixas ao redor. Clicar no país sob o mouse o acrescenta ao seletor de comparação,
preservando os demais. Toque e navegação pelas setas também permitem explorar
as posições; Enter ou Espaço acrescenta o país e Escape limpa o destaque.
No empate, a célula prioriza um país já selecionado ou o
primeiro código ISO, e o texto de leitura identifica os demais empatados.

O hover usa somente os dados já enviados ao navegador. Os eventos Shiny
automáticos do Plotly são desativados nesta visualização, evitando requisições
de hover e retransmissão de formas e anotações a cada movimento do mouse.
A seleção por clique usa o mesmo seletor de países das demais visualizações.
O controlador remove os handlers antigos quando a base ou o idioma muda.

## Verificação

Os testes de dados cobrem empates, negativos, ausências, agregados, cobertura
variável e isolamento entre bases. Os testes de gráfico verificam os eixos,
as lacunas e a preservação do universo. A integração verifica português e
inglês. `tests/manual/check-indicator-ranking.cjs` exercita hover real por
coordenadas, seleções, troca de base, teclado e larguras de desktop e celular.
No celular, a rolagem horizontal é limitada ao gráfico para manter os rótulos
anuais legíveis.
