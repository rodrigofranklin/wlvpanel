# Revisão cruzada dos catálogos do leste europeu

Revisão por agente em 10 de setembro de 2026 dos catálogos `ru`, `uk`, `pl`, `cs`, `ro` e `el`, produzidos por outro agente. Foram lidas as famílias de trabalho/força de trabalho, trabalho abstrato, multiplicadores, cestas, mais-valor, lucro apropriado, transferências, preços diretos e notas metodológicas. Cada catálogo contém 734 rótulos e 399 frases.

## Achados encaminhados e correções conferidas

| Achado | Correção aplicada pelo autor e conferida na releitura |
|---|---|
| A construção “dividido pelo capital variável menos um” permitia ler a subtração como parte do denominador, particularmente em russo, polonês e tcheco. | As sete famílias de fórmulas, incluindo WIOD13 por habilidade, agora declaram que uma unidade é subtraída **do quociente obtido**. |
| *Persons engaged* aparecia como pessoas empenhadas em tcheco e como empregados em romeno, perdendo a abrangência dos ocupados não assalariados. | `pracujících osob` em tcheco e `persoanelor ocupate` em romeno; manteve-se a distinção com os assalariados. |
| A remuneração do trabalho tinha em tcheco uma expressão próxima a substituição/compensação, e em grego uma expressão associável a indenização. | `Odměna za práci` e `Αμοιβή της εργασίας`, preservando as descrições que incluem rendimentos dos não assalariados. |

As correções foram feitas pelo agente responsável pelos seis catálogos, sem alterações concorrentes por este revisor.

## Verificações conceituais

As descrições relidas do lucro apropriado preservam a aproximação empírica e a negação de equivalência com a taxa marxista de lucro, cujo denominador é a soma de capital constante e variável. Nas descrições de produto bruto, valor adicionado permanece distinto de mais-valor. As transferências produtivas preservam os sentidos dos sinais, o valor representado pelo dinheiro e o trabalho abstrato efetivamente incorporado nas mercadorias.

As descrições de redução de trabalho complexo a simples e dos multiplicadores mantêm complexidade e intensidade como critérios distintos. A força de trabalho continua sendo a capacidade cuja reprodução é medida pela cesta de consumo, enquanto o trabalho abstrato designa a atividade expressa em valor. Nas famílias examinadas não foi encontrado deslocamento de transferência de valor para criação de valor.

O critério conceitual segue as distinções de Marx em [O capital, capítulo VIII](https://www.marxists.org/archive/marx/works/1867-c1/ch08.htm), sobre preservação e criação de valor, e [capítulo XVIII](https://www.marxists.org/archive/marx/works/1867-c1/ch18.htm), sobre taxa de mais-valor. As referências primárias nas línguas de cada catálogo e as escolhas terminológicas específicas estão no relatório do agente autor.

## Limites e reprodução

Esta foi uma revisão focada de conceitos e fórmulas por agente, não uma certificação humana nativa nem conferência filológica de todos os textos. Permanecem possíveis questões de estilo, concordância ou terminologia setorial em frases não amostradas. As verificações de cobertura, Unicode, placeholders e HTML são reproduzíveis em `tests/testthat/test-expanded-language-catalogs.R` e `tests/testthat/test-translation-coverage.R`; elas complementam a leitura semântica, mas não a substituem.
