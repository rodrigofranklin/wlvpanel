# Catálogo de publicações

O escopo solicitado é a produção de **Rodrigo Straessli Pinto Franklin** e
**Rodrigo Emmanuel Santana Borges**, incluindo coautorias. A grafia Emmanuel
segue os registros bibliográficos; a consulta também considerou a variante
Emanuel informada pelo usuário. A inclusão de uma obra não implica que ela
seja um resultado específico do World Labour Values.

O catálogo local em `config/publications.json` contém metadados e links,
sem PDFs, imagens, resumos ou dependência de serviços externos para abrir
ou filtrar a página. A consulta das fontes ocorreu em 6 de setembro de 2026.

As identidades foram verificadas pelos nomes completos, coautorias e ORCID:

- [Franklin: 0000-0003-2698-2826](https://orcid.org/0000-0003-2698-2826).
- [Borges: 0000-0003-2076-1424](https://orcid.org/0000-0003-2076-1424).

As buscas por autor no Crossref foram limitadas aos nomes completos; as
assinaturas abreviadas foram aproveitadas somente quando o DOI também
constava no ORCID correspondente. As páginas de editoras, revistas,
anais e repositórios universitários complementam esses registros. Cada
entrada conserva os links que sustentam sua identificação.

Os [registros públicos de Borges](https://pub.orcid.org/v3.0/0000-0003-2076-1424/works)
também contêm capítulos e trabalhos em eventos sem DOI. A interface os
identifica como registros do autor, distinguindo o acesso ao texto da
consulta à referência bibliográfica. Oito registros não apresentam uma
lista de autoria no ORCID; neles, a página informa somente o vínculo com
o perfil, sem apresentar uma autoria completa presumida.

A [página de publicações do projeto](https://worldlabourvalues.org/publicacoes.html)
e a [página de livros](https://worldlabourvalues.org/livros.html) continham
somente os títulos das seções no HTML consultado. Não foi encontrada uma
bibliografia embutida em Mendeley ou outro serviço nessas páginas. O link
Lattes no perfil de Borges aponta para o mesmo identificador do perfil de
Franklin e não foi utilizado para resolver a identidade de Borges.

Foi feita deduplicação por DOI e por título, ano e tipo. Edições em livro,
artigos e versões em eventos permanecem distintas. A duplicação do artigo
de 2017 sobre metas de inflação em um registro editorial de 2021 foi
consolidada e explicada em nota. Datas de publicação on-line que diferem
do fascículo também são indicadas. O artigo da Revista Econômica do
Nordeste publicado em agosto de 2026 está vinculado ao fluxo de 2027;
o catálogo usa 2026, seguindo a data de publicação informada pela revista.

Um capítulo marcado “no prelo” e um registro SciELO que aponta para uma
submissão não foram incluídos entre os trabalhos publicados. O JSON
registra essas exclusões e o registro duplicado do artigo sobre mortalidade
materna. Não foi possível confirmar exaustividade: currículos, ORCID e
depósitos de DOI podem ser incompletos. Nenhuma sincronização periódica é
executada pelo painel.

Para acrescentar ou corrigir uma referência, atualize o JSON com autoria,
ano, tipo, veículo e fonte verificável. Preserve o DOI original, mantenha
o aviso de autoria incompleta quando necessário e rode
`tests/testthat/test-publications.R`. A suíte testa identidade dos autores,
fontes, duplicações de DOI, busca sem acentos, filtros e troca de idioma.
