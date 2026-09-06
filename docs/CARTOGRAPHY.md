# Cartografia do wlvpanel

Fontes consultadas em **06/09/2026**. Esta nota distingue a projeção, as bases
geográficas e o contexto institucional que motivou a alteração do mapa.

## Projeção e motivação

Os módulos **Mapa** e **Indicadores** utilizam **Equal Earth**, uma projeção pseudocilíndrica de área
equivalente desenvolvida em 2018 por Bojan Šavrič, Tom Patterson e Bernhard Jenny.
Ela preserva proporções de área no modelo de referência, característica útil
para a comparação visual de países e continentes. Como toda projeção plana,
apresenta distorções: equivalência de área não significa preservação de formas,
distâncias ou direções. A [documentação técnica do PROJ](https://proj.org/en/stable/operations/projections/eqearth.html)
descreve suas formas esférica e elipsoidal e seu uso em mapas mundiais; a
[página dos autores](https://shadedrelief.com/ee_proj/) explica o projeto e
remete ao artigo original, DOI `10.1080/13658816.2018.1504949`.

A [cobertura oficial da Assembleia Geral, GA/12779, de 04/09/2026](https://press.un.org/en/2026/ga12779.doc.htm)
informa a aprovação do projeto **A/80/L.104**, intitulado *Correct the map*,
por 164 votos favoráveis, um contrário e seis abstenções. Segundo essa fonte,
o texto incentiva o uso mais amplo de projeções equivalentes, particularmente
Equal Earth, em contextos nos quais importa comparar o tamanho dos continentes.
A fonte é uma cobertura de imprensa da ONU, identificada como não sendo o
registro oficial da reunião. `A/80/L.104` é o identificador do projeto nela
citado; esta nota não atribui um número definitivo `A/RES` não verificado.

A escolha do painel está alinhada a esse incentivo. Isso não torna o wlvpanel
um produto da ONU, não representa endosso da ONU ao painel ou aos seus resultados
e não converte seus limites territoriais em cartografia oficial da Organização.
A [FAQ do UN Geospatial, pergunta 5](https://www.un.org/geospatial/about/faqs)
ainda informa que o Secretariado não prescreve uma única projeção para seus
mapas. Uma recomendação para comparar áreas não determina uma projeção universal
para navegação, mapas locais ou todos os produtos cartográficos.

## Implementação e atualização incremental

Leaflet permanece responsável pelas camadas vetoriais e pelas interações. Um
CRS próprio em JavaScript implementa a forma **esférica** de Equal Earth, com
transformações direta e inversa baseadas nas equações publicadas e documentadas
no [código de referência do PROJ](https://github.com/OSGeo/PROJ/blob/master/src/projections/eqearth.cpp).
Não há bundle D3, execução de PROJ no navegador ou serviço externo de tiles.
O zoom por retângulo usa o plano projetado, com adaptação isolada do handler
Leaflet 1.x. Seu aviso BSD de terceiros acompanha
[`www/wlv-equal-earth.LICENSE.md`](../www/wlv-equal-earth.LICENSE.md).
A forma esférica utilizada para visualização não deve ser identificada como
uma implementação do CRS elipsoidal EPSG:8857, nem usada para medir áreas
geodésicas a partir de pixels.

A geometria temática continua sendo carregada inicialmente e reutilizada pelo
cliente. Mudanças de ano, método, idioma ou seleção atualizam os atributos das
feições já existentes: cores, conteúdo dos tooltips, legenda e destaque. A
reprojeção da visualização não exige que Shiny reenvie os polígonos. A camada de
terra é um GeoJSON servido pelo próprio aplicativo. Zoom e pan operam sobre
essas camadas locais, e não solicitam imagens a provedores externos.

O enquadramento mundial ocorre na primeira exibição ou por ação explícita no
botão Mundo. Zoom e pan são livres; troca de filtros, idioma e tamanho da
janela preserva a vista. O módulo Mapa dedica-se à comparação temática,
com tooltips; perfis e dados setoriais estão no módulo País. Indicadores
mantém sua seleção de países por clique e pelo seletor textual.

Os valores estatísticos, códigos dos países, cores e integração com a seleção
do painel permanecem independentes da projeção. A mudança cartográfica não
recalcula os indicadores nem altera a série temporal das geometrias. O mapa
próprio do módulo **Indicadores** deve ser verificado separadamente: compartilhar
dados ou funções JavaScript não substitui a verificação de seu fluxo de uso.

## Duas fontes de geometria local

### Terra de fundo

`www/wlv-land-110m.geojson` contém a camada física **Natural Earth Land**,
escala 1:110 milhões. Sua preparação está em
`tests/manual/build-map-land.R`; a procedência registrada, a versão 4.1.0
identificada no pacote recebido e os hashes do ZIP e do GeoJSON constam de
[`www/wlv-land-110m.LICENSE.md`](../www/wlv-land-110m.LICENSE.md).
Esse arquivo tem 127 feições e coordenadas WGS84 arredondadas a quatro casas
decimais. A atualização da projeção preserva esse asset.

Os [termos do Natural Earth](https://www.naturalearthdata.com/about/terms-of-use/)
declaram seus dados vetoriais e raster em domínio público e permitem
modificação e distribuição, inclusive eletrônica e comercial. Não exigem
permissão ou atribuição. O painel mantém o crédito por transparência sobre a
fonte. A página original do conjunto é
[Natural Earth — Land 1:110 milhões](https://www.naturalearthdata.com/downloads/110m-physical-vectors/110m-land/).

### Países temáticos

A receita atual em `utils/prepare_data.R` carrega `rworldmap`, chama `getMap()`
sem argumentos, conserva os campos `ISO3` e `NAME`, acrescenta campos do painel,
seleciona os países com observações por método e grava `data/countries_sp.RDS`.
Esses polígonos são uma camada distinta do asset físico Land descrito acima.

No [manual primário do rworldmap 1.3-8](https://search.r-project.org/CRAN/refmans/rworldmap/help/getMap.html),
o padrão de `getMap()` é `resolution = "coarse"`, não `"low"`.
A documentação de
[`countriesCoarse`](https://search.r-project.org/CRAN/refmans/rworldmap/html/countriesCoarse.html)
descreve uma base derivada de Natural Earth 1.4.0, predominantemente em
1:110 milhões, acrescida de países de 1:50 milhões e de Tuvalu de 1:10 milhões.
Também descreve ajustes em nomes, códigos e estrutura dos polígonos realizados
pelo pacote.

Isso documenta a **receita e a origem declarada pelo pacote**, sem autenticar
retroativamente a versão ou os bytes que produziram o RDS operacional. A mera
presença do arquivo e de uma chamada `getMap()` não demonstra quando ele foi
gerado, com qual versão instalada ou se recebeu outras transformações. Esta
alteração não regenera o RDS nem lhe atribui um hash de fonte não verificado.

A [documentação do pacote rworldmap](https://search.r-project.org/CRAN/refmans/rworldmap/html/rworldmap-package.html)
declara **GPL (>= 2)**. Essa declaração sobre o pacote deve ser distinguida dos
termos de domínio público dos dados originais Natural Earth: não se deve chamar
o pacote inteiro de domínio público, nem inferir que a licença GPL do pacote
substitui os termos da fonte geográfica original. Ao redistribuir o pacote ou
material dele extraído, devem ser mantidos e examinados seus avisos aplicáveis.

## Bases da ONU avaliadas e não incorporadas

O [UN Geospatial](https://www.un.org/geospatial/mapsgeo) publica mapas e
geosserviços, incluindo Clear Map. Existe também a base oficial
[UN Geodata simplified](https://geoportal.un.org/arcgis/home/item.html?id=fa74ef8499094e41bf0d025006e37fc9),
cujo proprietário indicado nos metadados é `United_Nations_Geospatial`.
Ela inclui polígonos de países `BNDA_simplified`, linhas de limites
`BNDL_simplified`, corpos de água e agregações regionais. Os metadados descrevem
generalização a partir de uma base de 1:25 milhões para mapas mundiais e indicam
Eckert IV no serviço consultado. Disponibilidade de uma base oficial e escolha
da projeção são decisões separadas.

As [permissões cartográficas do UN Geospatial](https://www.un.org/geospatial/es/mandates/public)
informam que os mapas pertencem à ONU. Orientam solicitar permissão para
republicar mapas sem modificação; derivados são de responsabilidade de quem
os produz e devem remover o nome da ONU e o número do mapa. Ao hospedar uma
cópia, a orientação é atribuir a fonte ao UN Geospatial e fornecer um link.
Essas condições não equivalem a uma declaração geral de domínio público.

O documento de autoria da ONU
[*Terms of Use of the UN Geodata*](https://developers.google.com/earth-engine/datasets/papers/BNDA_terms_of_use.pdf),
reproduzido pelo distribuidor Google Earth Engine, proíbe uso comercial dos
geodados, define o acesso como revogável e intransferível e restringe o uso
externo à finalidade identificada pela seção responsável quando concede acesso.
Também trata de atribuição e de dados alterados ou combinados com outras bases.
Os avisos específicos do conjunto e do modo de distribuição precisam ser
considerados antes de uma eventual incorporação futura.

Não foram importadas geometrias, tiles, mapas prontos, emblemas ou logotipos da
ONU para esta implementação. A solução mantém fontes locais já utilizadas,
com seus créditos próprios. O incentivo à projeção não autoriza atribuir à ONU
a fonte de uma geometria Natural Earth.

## Limitações e verificação

- **Extensão mundial:** a visualização usa longitudes de −180° a +180°,
  centradas em Greenwich, e inclui latitudes até os polos. O antimeridiano é
  uma costura da representação plana. Partes de um país situadas dos dois lados
  aparecem nas bordas opostas; a projeção não deve conectá-las por um polígono
  que atravesse o centro do mapa. Nos polos, a latitude atinge um limite finito;
  não há a divergência vertical da projeção Mercator.
- **Generalização:** países e ilhas pequenos podem ter áreas muito reduzidas
  na visão mundial. Aumentar o zoom facilita a interação, mas não acrescenta
  detalhe à geometria original. As diferenças de escala e época das duas
  fontes podem produzir pequenos desalinhamentos costeiros. A seleção textual
  de países continua importante para acesso a territórios pequenos.
- **Limites territoriais:** reprojetar não atualiza fronteiras, resolve disputas
  ou harmoniza as bases. Os nomes, códigos e polígonos temáticos são aqueles da
  preparação de dados do painel, sujeitos à limitação de procedência do RDS
  descrita acima.
- **Validação funcional:** verificar troca de ano, método e idioma, clique e
  seleção de país, tooltip, legenda, zoom/pan, teclado e larguras mobile. Fazer
  a mesma passagem no módulo Indicadores quando código compartilhado mudar.
  Na inspeção de rede, confirmar que as mudanças de atributos não incluem
  nova geometria e que não há requisições a servidores de tiles. Os comandos
  de teste e a suíte aplicável estão no [README](../README.md).

Experimentos, screenshots e logs de verificação devem permanecer em campanha
criada por `scripts/manage-campaigns.ps1`, dentro de `temp/<id>/`, e seguir o
encerramento e a limpeza previstos no `AGENTS.md`.
