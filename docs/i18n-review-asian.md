# Revisão dos catálogos asiáticos

Revisão realizada por agente em 10 de setembro de 2026. Abrange `ja`, `ko`, `hi`, `bn`, `id`, `vi` e `th`, cada qual com 734 rótulos e 399 frases. Não constitui revisão humana ou certificação por falantes nativos.

## Método e escopo

A fonte foi o catálogo UTF-8 consolidado, com referências em português, inglês, castelhano e mandarim. Os rascunhos foram obtidos por tradução automática pública, em lotes com proteção de HTML, nomes, códigos, unidades e placeholders. Essa proteção, sozinha, não assegura gramática nem correção conceitual: a revisão encontrou e corrigiu problemas que não seriam detectados pela contagem de chaves.

Foram redigidos diretamente pelo agente os principais rótulos teóricos, as quatro narrativas completas da página País, as descrições de remuneração, cestas de consumo, multiplicadores do trabalho, transferências de valor e saldo comercial, além da distinção entre lucro apropriado e a taxa marxista de lucro. A revisão cruzada por outro agente trouxe correções adicionais para vietnamita e tailandês, pessoas ocupadas versus assalariados, ordem das unidades e títulos de navegação. O restante do catálogo recebeu tradução automática com revisão de integridade e amostragem semântica; não se afirma conferência linguística especializada de cada frase.

Os arquivos de implementação são `config/locales/{ja,ko,hi,bn,id,vi,th}.json`. A validação reproduzível fica em `tests/testthat/test-expanded-language-catalogs.R` e `tests/testthat/test-translation-coverage.R`. A auditoria final verificou 7.931 entradas: cobertura exata, leitura e regravação UTF-8 sem perdas, ausência de marcadores residuais, preservação de HTML, placeholders e códigos, e posição da subtração nas fórmulas. Os poucos nomes longos idênticos ao inglês são topônimos, como Brunei Darussalam, Papua New Guinea e Saint Barthélemy.

## Glossário adotado

| Idioma | Trabalho | Força de trabalho | Mais-valor | Lucro |
|---|---|---|---|---|
| Japonês | 労働 | 労働力 | 剰余価値 | 利潤 |
| Coreano | 노동 | 노동력 | 잉여가치 | 이윤 |
| Hindi | श्रम | श्रम-शक्ति | बेशी मूल्य | मुनाफ़ा |
| Bengali | শ্রম | শ্রমশক্তি | উদ্বৃত্ত মূল্য | মুনাফা |
| Indonésio | kerja | tenaga kerja | nilai lebih | laba |
| Vietnamita | lao động | sức lao động | giá trị thặng dư | lợi nhuận |
| Tailandês | แรงงาน | พลังแรงงาน | มูลค่าส่วนเกิน | กำไร |

| Idioma | Valor | Preço | Trabalho abstrato | Produtividade / intensidade |
|---|---|---|---|---|
| Japonês | 価値 | 価格 | 抽象的労働 | 生産性 / 強度 |
| Coreano | 가치 | 가격 | 추상적 노동 | 생산성 / 강도 |
| Hindi | मूल्य | कीमत | अमूर्त श्रम | उत्पादकता / तीव्रता |
| Bengali | মূল্য | দাম | বিমূর্ত শ্রম | উৎপাদনশীলতা / তীব্রতা |
| Indonésio | nilai | harga | kerja abstrak | produktivitas / intensitas |
| Vietnamita | giá trị | giá cả | lao động trừu tượng | năng suất / cường độ |
| Tailandês | มูลค่า | ราคา | แรงงานนามธรรม | ผลิตภาพ / ความเข้มข้น |

O indonésio `tenaga kerja` também ocorre em contextos estatísticos amplos. Nos indicadores de valor da força de trabalho, o contexto explicita sua reprodução; pessoas ocupadas são `orang yang bekerja`. Em coreano, usam-se `취업자` para ocupados e `피고용자` para assalariados; em japonês, `就業者` e `雇用者`.

## Decisões conceituais

- Mais-valor não foi tratado como valor adicionado, lucro, vantagem ou aumento genérico de valor. Valor adicionado tem termos próprios, como `付加価値`, `부가가치`, `সংযোজিত মূল্য`, `nilai tambah`, `giá trị gia tăng` e `มูลค่าเพิ่ม`. No hindi, adotou-se `मूल्य वर्धन` para valor adicionado e `बेशी मूल्य` para mais-valor.
- Redução de trabalho complexo a simples descreve uma conversão teórica, sem afirmar diminuição física do trabalho. As descrições dos multiplicadores mencionam complexidade e intensidade; não dizem que o multiplicador é a própria intensidade nem que a força de trabalho duplica.
- Nas sete famílias de taxas, a apresentação `(numerador / denominador) − 1` mantém a subtração fora do denominador. As versões por habilidade preservam o valor da força de trabalho correspondente; as variantes produtivas preservam a restrição do denominador.
- O lucro apropriado permanece uma aproximação empírica. Sua descrição conserva a negação de equivalência com a taxa de lucro marxista e explicita o denominador como a soma do capital constante e variável.
- Transferir valor não significa criá-lo. As descrições preservam o sinal positivo como recebimento e o negativo como envio, a diferença entre valor representado por preços e trabalho abstrato incorporado, e os casos produtivo e improdutivo.
- Produtivo/improdutivo não significa eficiente/ineficiente. Em vietnamita adotou-se `sản xuất / phi sản xuất` com referência à classificação do método. Em tailandês foram removidas formulações que restringiam todos os casos à produção de mais-valor; os textos remetem à classificação produtiva do método e, onde necessário, à criação de valor. Isso preserva a abrangência de ocupados não assalariados das fontes.
- Remuneração do trabalho inclui rendimentos de autônomos e outros não assalariados. Esses trabalhadores não foram descritos como necessariamente sem pagamento. A cesta de preços mede preços; a cesta de valor mede tempo de trabalho socialmente necessário para a reprodução.
- As quatro narrativas de País são frases inteiras. A ordem de `{year}`, `{country}` e dos demais placeholders pode variar por idioma. A escala de bilhão permanece 10⁹: `十億`, `십억`, `अरब`, `বিলিয়ন`, `miliar`, `tỷ`, `พันล้าน`.

## Fontes primárias consultadas e limites de acesso

As fontes servem de referência terminológica e conceitual, sem transferir para a WLVD decisões metodológicas que são próprias do projeto.

- **Japonês:** Marx, [O capital, volume I, índice da tradução de Miyazaki](https://www.marxists.org/nihon/marx-engels/capital/contents/index.htm), com distinção explícita entre compra e venda da força de trabalho, produção de mais-valor, capital constante e variável; consultado também o [capítulo VIII](https://www.marxists.org/nihon/marx-engels/capital/chapter08/index.htm).
- **Coreano:** Marx, [Salário, preço e lucro](https://www.marxists.org/korean/marx/value-price-profit/index.htm), especialmente as [seções 8–11](https://www.marxists.org/korean/marx/value-price-profit/ch08.htm), que distinguem trabalho, força de trabalho, valor, preço, mais-valor e suas formas de distribuição.
- **Hindi:** [Introdução de Engels a Trabalho assalariado e capital](https://www.marxists.org/hindi/marx-engels/1847/introwagelabor.htm), com discussão direta de `श्रम` e `श्रम-शक्ति`; a edição de [O capital, volume I](https://www.marxists.org/hindi/marx-engels/capital/Capital_volume1.pdf) identifica `बेशी मूल्य` e sua taxa. O PDF não foi conferido integralmente.
- **Bengali:** Marx, [Manuscritos econômico-filosóficos de 1844](https://www.marxists.org/bangla/archive/marx-engels/1844/epm/epm_seg2.htm); foram localizadas as [edições de O capital](https://www.marxists.org/bangla/archive/marx-engels/index.htm) e [Do socialismo utópico ao socialismo científico, de Engels](https://www.marxists.org/bangla/archive/marx-engels/1880/utopia/index.htm). A extração de texto do PDF de Engels usa codificação legada e não permitiu conferência lexical integral; essa limitação não foi tratada como validação do catálogo.
- **Indonésio:** Marx, [Upah Harga dan Laba](https://www.marxists.org/indonesia/archive/marx-engels/1865/upah-harga-laba.htm), tradução de 1958. A grafia histórica `kerdja` foi atualizada para `kerja`; a oposição entre trabalho e capacidade de trabalhar, e entre `nilai-lebih` e `laba`, orienta o glossário.
- **Vietnamita:** Marx e Engels, [Obras completas, volume 16, edição oficial vietnamita](https://tulieuvankien.dangcongsan.vn/upload/3000006/20251024/9af27b6eb9dae02800d18c4d81816b7aMac_-_Angghen_TT_-_Tap_16.pdf), que inclui *Tiền công, giá cả và lợi nhuận*. A camada textual legada e falhas de renderização impediram uma conferência integral; foram usadas a identificação da edição e a terminologia comparada, sem alegar revisão nativa.
- **Tailandês:** foi identificada a tradução de Marx, [แรงงานรับจ้างและทุน — Trabalho assalariado e capital](https://books.google.com/books?id=TxNCEQAAQBAJ), com acesso restrito à prévia. Não se atribui a essa prévia a validação de todas as escolhas tailandesas. A distinção entre trabalho produtivo em geral e trabalho produtivo no capitalismo foi conferida também no [capítulo XVI de O capital, volume I](https://www.marxists.org/archive/marx/works/1867-c1/ch16.htm).

As limitações mais relevantes para uma futura revisão humana são fluência idiomática de descrições longas, nomenclatura setorial e nuances da classificação produtiva em tailandês. Nenhuma mudança de cálculo, definição de série, fonte ou escala numérica foi introduzida pelos catálogos.
