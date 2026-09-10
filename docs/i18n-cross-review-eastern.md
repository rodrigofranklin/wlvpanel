# Revisão cruzada dos catálogos ocidentais

Realizada em 10 de setembro de 2026 pelo agente responsável pelos idiomas orientais sobre os catálogos `fr`, `de`, `it`, `nl`, `ca` e `gl`. A revisão foi independente da produção inicial desses seis catálogos, mas foi feita por modelo; não constitui revisão humana nativa.

## Escopo e resultado

Foram lidas as definições de trabalho abstrato, força de trabalho, remuneração, valor, valor adicionado, mais-valor, lucro apropriado, estoque de capital, preços diretos, cesta de consumo, multiplicador do trabalho complexo e transferências comerciais. Também foram confrontados os prefácios WIOD, as narrativas parametrizadas de País e os esclarecimentos sobre normalização das transferências em dólares.

As distinções teóricas examinadas permanecem coerentes: força de trabalho não vira população economicamente ativa; ocupados não são reduzidos a assalariados; mais-valor não vira lucro; valor adicionado permanece distinto de mais-valor; produtividade não substitui intensidade; transferência e apropriação de valor não são apresentadas como criação de valor.

As 19 observações de taxa de mais-valor de cada idioma — 114 entradas — apresentam explicitamente `(numerador / denominador) − 1`. A leitura das sete famílias distintas confirmou o denominador de cada variante: valor da força de trabalho por qualificação, capital variável dos empregados ou remuneração dos ocupados, com o recorte produtivo quando previsto. A subtração não entra no denominador. A integridade dos catálogos é verificada por `tests/testthat/test-expanded-language-catalogs.R`.

A descrição da taxa de lucro apropriado mantém lucro líquido/estoque de capital como aproximação e distingue essa medida de mais-valor/(capital constante + capital variável). As aspas em valor “criado” foram preservadas nas medidas abrangendo trabalhadores produtivos e improdutivos. Não houve alteração de cálculo nesta revisão.

## Achados resolvidos pelo responsável pelos catálogos

| Idioma e campo | Achado | Resolução verificada |
|---|---|---|
| Francês, `desc.labour_force_value.s.mv` | A expressão “capital total de la société” poderia ser lida como capital de uma empresa. | Substituída por “capital total de l’ensemble de la société”, explicitando a sociedade como totalidade. |
| Alemão, `desc.gdp.s.mv` e `desc.gdp.s.du` | A repetição “geschaffene Wertschöpfung” enfraquecia a distinção entre o método do valor adicionado e o valor criado. | O resultado passou a ser descrito como todo o valor criado pelos residentes; o método continua referido à Wertschöpfung. |
| Alemão, `desc.trade_transfers.s.mv` | Mistura de voz ativa e passiva na descrição de recebimento e envio. | Os dois lados usam construção passiva paralela, preservando os sinais e o ponto de vista do país. |

Foi ainda indicada uma fonte de Marx em italiano, [*Salario, prezzo e profitto*](https://www.marxists.org/italiano/marx-engels/1865/salpp.htm), para complementar o cotejo originalmente documentado com Lenin. O glossário e as demais referências estão em `docs/i18n-review-western.md`.

## Limites

Não restaram achados conceituais abertos na amostra examinada. A inspeção não foi uma leitura nativa integral das 6.798 entradas: listas extensas de atividades, topônimos e toda a redação auxiliar não receberam cotejo linha a linha. As quatro narrativas completas preservam os parâmetros e usam o país antes de dois-pontos, evitando artigos ou flexões dependentes do nome. A verificação visual do conjunto da aplicação cabe à campanha principal.
