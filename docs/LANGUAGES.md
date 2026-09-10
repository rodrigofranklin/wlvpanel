# Idiomas e escolha inicial

O painel possui 23 idiomas, com os nomes exibidos em sua própria língua:

| Código | Idioma no menu |
| --- | --- |
| pt | Português |
| en | English |
| es | Castellano |
| zh | 中文 (chinês simplificado) |
| fr | Français |
| de | Deutsch |
| it | Italiano |
| nl | Nederlands |
| ca | Català |
| gl | Galego |
| ru | Русский |
| uk | Українська |
| pl | Polski |
| cs | Čeština |
| ro | Română |
| el | Ελληνικά |
| ja | 日本語 |
| ko | 한국어 |
| hi | हिन्दी |
| bn | বাংলা |
| id | Bahasa Indonesia |
| vi | Tiếng Việt |
| th | ไทย |

As traduções são locais: a troca não depende de um serviço de tradução externo.
Os catálogos de rótulos mantêm os códigos existentes; os catálogos de frases
complementam textos dinâmicos em R e JavaScript. Os testes conferem cobertura,
placeholders de formatação, Unicode e preservação de dados nas exportações.

O registro `config/languages.json` centraliza os nomes, códigos e separadores
numéricos. Os 19 catálogos adicionais ficam em `config/locales/`; cada arquivo
contém rótulos por código e frases completas por sua chave inglesa. O navegador
recebe apenas as frases do idioma ativo. O menu possui rolagem, navegação por
setas, Home/End e busca pelo início do nome ao digitar.

As narrativas da aba País usam frases completas com campos nomeados, permitindo
reordenar ano, país e valores conforme a gramática de cada língua. Os valores
continuam sendo calculados pelos mesmos dados e fórmulas. Abreviações de grandes
valores nos novos idiomas podem usar potências de dez, evitando a ambiguidade
entre as escalas curta e longa de milhões e bilhões.

## Revisão teórica das traduções

Os rascunhos dos 19 novos idiomas foram submetidos a agentes de IA com foco em
teoria marxista e a revisão cruzada. A revisão confere distinções entre trabalho
e força de trabalho, mais-valor e lucro, valor e preço, trabalho produtivo e
improdutivo, além das descrições de fórmulas. Isso não equivale a uma certificação
por tradutores humanos ou especialistas nativos. As fontes e decisões estão em:

- [Francês, alemão, italiano, neerlandês, catalão e galego](i18n-review-western.md).
- [Russo, ucraniano, polonês, tcheco, romeno e grego](i18n-review-eastern.md).
- [Japonês, coreano, hindi, bengali, indonésio, vietnamita e tailandês](i18n-review-asian.md).

As verificações independentes de outro agente estão nos relatórios de revisão
cruzada dos grupos [ocidental](i18n-cross-review-eastern.md),
[oriental europeu](i18n-cross-review-asian.md) e
[asiático](i18n-cross-review-western.md).

## Validação da implementação

Em 10 de setembro de 2026, a suíte R completa passou, com apenas o teste
exclusivo de sistemas com caminhos sensíveis a maiúsculas dispensado no Windows.
Após os últimos ajustes de redação, os testes de cobertura e integridade dos
catálogos também passaram novamente.

A navegação real em Shiny verificou 266 combinações de idioma, aba e largura:
19 idiomas × sete abas × desktop/celular (1440/390 px), sem erros JavaScript,
erros visíveis de renderização ou transbordamento horizontal. O menu também
passou em 320 px, incluindo teclado e persistência da escolha. Foram conferidos
12 cenários de idioma inicial por navegador, país, cookie e endereço explícito.
Os controles Plotly em hindi e bengali foram confirmados no navegador.

Foram baixadas 38 planilhas reais, uma de Indicadores e uma de Comércio em cada
novo idioma. A comparação por coordenada confirmou que as 537 células numéricas
do exemplo de Indicadores e as 172 do exemplo de Comércio eram idênticas entre
os 19 idiomas. Isso valida as exportações examinadas, em complemento aos testes
de cálculo e contrato de dados. Os testes reutilizáveis ficam em `tests/`; os
rascunhos e artefatos temporários da campanha foram descartados ao concluir.

## Idioma inicial pela localização aproximada do IP

O aplicativo pode usar o país estimado pelo proxy da hospedagem. Por exemplo,
a [geolocalização por IP da Cloudflare](https://developers.cloudflare.com/network/ip-geolocation/)
acrescenta `CF-IPCountry` à requisição. Para usá-lo, habilite a geolocalização
no domínio e configure o processo R com:

```powershell
$env:WLVPANEL_COUNTRY_HEADER = 'CF-IPCountry'
```

Outras hospedagens podem fornecer seu próprio cabeçalho ISO 3166-1 de duas
letras; basta configurar seu nome nessa variável. Use somente um cabeçalho
que o proxy confiável sobrescreva, com a origem protegida contra acesso direto.
Nenhum valor de `X-Forwarded-For` é usado para inferir o país. O resolvedor
não consulta serviços adicionais nem armazena endereços IP.

O país serve como uma aproximação de idioma, que pode ser inadequada para
visitantes em viagem, com VPN ou em países multilíngues. A prioridade é:

1. Idioma explícito no endereço (`?lang=pt`, `en`, `es`, `zh`, `fr`, `ja` etc.).
2. Preferência manual salva no cookie `wlv_language` por até um ano.
3. País informado pelo cabeçalho configurado.
4. Idioma disponível preferido no cabeçalho `Accept-Language` do navegador.
5. Português, quando nenhum sinal disponível for reconhecido.

O [cabeçalho Accept-Language](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Accept-Language)
é negociado respeitando seus pesos e excluindo idiomas com peso zero. Códigos
regionais como `es-MX` e `zh-TW` são normalizados para os idiomas disponíveis;
o painel utiliza o mesmo catálogo chinês simplificado em ambos os casos.
O mesmo vale para os novos idiomas, como `fr-CA`, `uk-UA` e `bn-BD`. O país
estimado não identifica a língua regional de alguém: catalão e galego, por
exemplo, também podem ser escolhidos pelo navegador ou pelo menu.

Na prévia em `127.0.0.1`, o IP local não permite localizar o visitante; sem um
cabeçalho configurado, o painel usa a preferência do navegador. Não é necessário
pedir permissão de GPS ou obter a localização exata.
