# Entrada da aba País

A aba abre com o Brasil (ou o primeiro país disponível), um seletor pesquisável,
um resumo do último ano disponível de cada indicador, duas séries comparadas e
um globo que permite escolher outro país. “Mostre-me mais” abre o perfil existente
e rola suavemente até os detalhes, incluindo comparações entre bases, gráficos
setoriais e downloads. O catálogo de países e agregados continua acessível no
rodapé da entrada.

## Dados e unidades

A entrada usa uma base por vez. A seleção inicial prefere a base com observação
mais recente para o país; a escolha explícita do usuário permanece ao trocar de
país. O ano destacado em cada indicador pertence à própria série, sem completar
lacunas com outra base.

- Jornada: `abstract_labour.empe.m.mv`.
- Valor da força de trabalho: `labour_force_value.m.mv`.
- Mais-valor por assalariado: jornada menos valor da força de trabalho.
- Taxa de exploração: `surplus_value.empe.r.pc`, apresentada em porcentagem e
  conferida contra `100 * mais-valor / valor da força de trabalho`.

As duas curvas de trabalho usam **horas anuais de trabalho abstrato por
assalariado**. Horas concretas trabalhadas não são intercambiáveis com essa
unidade. As unidades canônicas são verificadas no contrato dos indicadores.

Na matriz bilateral, `exports_values` representa horas nas mercadorias exportadas;
`transfers_values` é o dinheiro convertido em horas menos essas horas nas
mercadorias. Assim:

```text
dinheiro recebido nas exportações = Σ(exportações + transferências), saídas
dinheiro enviado nas importações = Σ(exportações + transferências), entradas
enviado bruto = horas das exportações + dinheiro enviado nas importações
recebido bruto = horas das importações + dinheiro recebido nas exportações
saldo líquido = recebido bruto − enviado bruto
```

O dinheiro usa o fator internacional anual já aplicado pela base. O saldo é
conferido contra `trade_transfers.s.mv`. As somas excluem o próprio país e o
agregado mundial; uma parcela ausente impede apresentar uma soma parcial como
total. O gráfico comercial apresenta bilhões de horas abstratas anuais: a área
vermelha clara indica envio líquido e a área âmbar clara indica recebimento
líquido.

## Visualização e interação

A entrada começa com uma indicação discreta de carregamento. O conteúdo permanece
invisível e sem interação até os seletores, textos, gráficos e estado do globo
estarem disponíveis; a revelação usa uma transição breve, respeitando a preferência
por movimento reduzido. Os outputs continuam sendo calculados durante essa espera.
Uma falha ao carregar a geometria libera a página com a alternativa do seletor e
um botão para tentar novamente. O modal de informações só abre após uma solicitação
explícita, sem aparecer enquanto seu estado inicial ainda é desconhecido.

Os gráficos são SVG locais, com linhas contínuas suavizadas em vermelho e âmbar.
As áreas entre as curvas têm preenchimento sólido claro. No gráfico do trabalho,
o mais-valor positivo aparece em vermelho claro e o negativo em âmbar claro; a
legenda dessa área diz apenas “Mais-valor”. Anos ausentes dentro das séries
interrompem linhas e áreas; extremos inteiramente vazios são omitidos. Cada ano
possui valores acessíveis por foco e tooltip.
Os rótulos dos eixos ficam em HTML com 14 px, conservando a legibilidade quando
as curvas SVG se ajustam à coluna. Legendas e textos auxiliares usam pelo menos
14 px; em telas estreitas os anos e os indicadores-resumo recebem mais espaço.

O globo usa projeção ortográfica, fronteiras Natural Earth e uma cópia isolada de
d3-geo. Todos os recursos são locais; as licenças ficam junto dos assets. Pode ser
girado por arraste com mouse ou toque e pelos botões de rotação. Clicar em um país
disponível o seleciona e anima o globo até centralizá-lo. O botão de centralização
retorna ao país selecionado. O globo não usa navegação por teclado, mira ou texto
“No centro”. Países menores têm alvos ampliados discretos. Países sem dados
permanecem identificáveis e não alteram a seleção. Os agregados estão no seletor
e catálogo.

## Verificação

Os testes de dados e gráficos ficam em `tests/testthat/test-country-landing-*.R`.
`tests/manual/check-country-entry.cjs` verifica os fluxos reais no Shiny, incluindo
seleção pelo globo, rotação, bases, saldos, ausência de dados, idioma, detalhes e
larguras 1440, 390 e 320 px. O teste existente `check-country-page.cjs` cobre as
funções do perfil detalhado. Execute em uma campanha criada pelo gerenciador,
com `WLV_CAMPAIGN_ROOT`, `TEMP`, `TMP` e `TMPDIR` configurados.
`tests/manual/check-country-loading.cjs` retém respostas reais do servidor para
verificar o primeiro carregamento, um gráfico atrasado, falha na geometria e
movimento reduzido, incluindo a ausência do modal vazio desde os primeiros frames.
