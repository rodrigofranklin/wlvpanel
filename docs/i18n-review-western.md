# Revisão dos catálogos ocidentais

Revisão realizada em 10 de setembro de 2026 para `fr`, `de`, `it`, `nl`, `ca` e `gl`. Cada catálogo contém 734 rótulos e 399 frases, incluindo as quatro narrativas completas do módulo País.

## Método e alcance

Os rascunhos foram obtidos por tradução automática de textos públicos da interface, com português como fonte dos rótulos e inglês como fonte das frases. O agente fez revisão editorial dirigida dos conceitos marxistas, descrições de indicadores, pressupostos dos métodos, introduções e rótulos principais. Não se trata de revisão por tradutores humanos nativos nem de certificação linguística. As listas extensas de atividades e textos auxiliares passaram por verificações automáticas e amostragem; podem admitir aperfeiçoamentos idiomáticos posteriores.

A revisão consultou textos primários para confirmar os conceitos. As escolhas para a interface são decisões editoriais, e não transcrições das fontes. Em francês, adotou-se a terminologia tradicional *plus-value*; em catalão, a grafia *plusvàlua* atualiza o *plus-vàlua* da tradução consultada.

## Glossário adotado

| Conceito | Francês | Alemão | Italiano | Neerlandês | Catalão | Galego |
|---|---|---|---|---|---|---|
| Trabalho | travail | Arbeit | lavoro | arbeid | treball | traballo |
| Força de trabalho | force de travail | Arbeitskraft | forza-lavoro | arbeidskracht | força de treball | forza de traballo |
| Mais-valor | plus-value | Mehrwert | plusvalore | meerwaarde | plusvàlua | plusvalía |
| Valor / preço | valeur / prix | Wert / Preis | valore / prezzo | waarde / prijs | valor / preu | valor / prezo |
| Lucro | profit | Profit | profitto | winst | benefici | beneficio |
| Produtividade / intensidade | productivité / intensité | Produktivität / Intensität | produttività / intensità | productiviteit / intensiteit | productivitat / intensitat | produtividade / intensidade |
| Trabalho abstrato | travail abstrait | abstrakte Arbeit | lavoro astratto | abstracte arbeid | treball abstracte | traballo abstracto |
| Estoque de capital | stock de capital | Kapitalstock | stock di capitale | kapitaalvoorraad | estoc de capital | stock de capital |

Foram preservadas as distinções entre valor criado e valor transferido, remuneração de todos os ocupados e remuneração exclusivamente salarial, trabalho simples e complexo, além de trabalho produtivo e improdutivo conforme a classificação da base.

A taxa de mais-valor continua sendo uma relação entre mais-valor e capital variável/valor da força de trabalho; não foi confundida com a parcela do mais-valor na jornada nem com a taxa de lucro. A descrição do lucro apropriado mantém a aproximação empírica lucro líquido/estoque de capital e a distingue da taxa marxista mais-valor/(capital constante + capital variável). Nenhuma fórmula ou dado foi recalculado.

## Correções materiais do rascunho

- Substituição de “população ativa”, “quadro de pessoal” e equivalentes quando a fonte tratava da força de trabalho como mercadoria.
- Separação explícita de pessoas ocupadas e assalariados, inclusive no pressuposto metodológico aplicado à China.
- Correção de “capital social/acionário” para estoque de capital e preservação de capital social total quando se trata do capital da sociedade.
- Correção de lucro “adequado”, “destinado” ou “alocado” para lucro apropriado.
- Correção do índice de preços que havia sido interpretado como produto físico armazenado: o objeto registrado em escala canônica é o índice.
- Correção de preços diretos “proporcionais aos preços” para proporcionais ao valor.
- Substituição de bases entendidas como fundamentos ou pedestais por bases/conjuntos de dados, inclusive instruções da página Sobre.
- Preservação das aspas em valor “criado” quando a definição abrange trabalhadores produtivos e improdutivos.
- Tradução integral das narrativas do País com parâmetros. O nome do país aparece antes de dois-pontos, evitando artigos e flexões que dependeriam do gênero ou número de cada país.

## Verificações

A verificação dos 6.798 valores confirmou igualdade dos conjuntos de chaves, valores não vazios, ausência de U+FFFD e marcadores temporários, preservação de HTML, URLs, parâmetros `%s`/`%d`, parâmetros nomeados, tokens de tabela, siglas e espaços externos dos fragmentos. A leitura de volta dos JSON confirmou os textos UTF-8 gravados. Os separadores numéricos são metadados definidos pelo registro de idiomas e não escolhas tradutórias. Os testes reutilizáveis de cobertura e integridade estão em `tests/testthat/test-expanded-language-catalogs.R` e `tests/testthat/test-translation-coverage.R`.

## Fontes primárias consultadas

- Francês: Marx, [*Le Capital*, livro I, capítulo XVIII](https://www.marxists.org/francais/marx/works/1867/Capital-I/kmcapI-18.htm). Confirma força de trabalho, mais-valor e os denominadores das taxas.
- Alemão: Marx, [*Resultate des unmittelbaren Produktionsprozesses*, seção I](https://www.marxists.org/deutsch/archiv/marx-engels/1863/resultate/1-mehrwert.htm). Confirma valor, capital variável, mais-valor e a distinção entre produção e conservação do valor.
- Italiano: Marx, [*Salario, prezzo e profitto*, seções 7–10](https://www.marxists.org/italiano/marx-engels/1865/salpp.htm), e Lenin, [*Tre fonti e tre parti integranti del marxismo*, seção II](https://www.marxists.org/italiano/lenin/1913/3/font-mar.htm). Confirmam força de trabalho, trabalho socialmente necessário, taxa de mais-valor e a relação entre mais-valor e lucro.
- Neerlandês: Marx, [*Het Kapitaal*, capítulo 4](https://www.marxists.org/nederlands/marx-engels/1867/kapitaal/4.htm). Confirma trabalho, força de trabalho, valor e mais-valor.
- Catalão: Marx, [*El capital*, capítulo 5](https://www.marxists.org/catala/marx/capital/me23_192.htm). Confirma processo de trabalho, criação de valor e força de trabalho.
- Galego: Marx, [excertos distribuídos pela CIUG](https://www.ciug.gal/PDF/textos_filosofia/marx.pdf). Referência para a redação galega de trabalho e força de trabalho; os limites conceituais foram também cotejados com as demais fontes primárias.
