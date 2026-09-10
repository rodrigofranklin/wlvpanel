# Resultado das quatro otimizações

Implementação e verificação local em 10 de setembro de 2026, a partir da
[avaliação de eficiência](PERFORMANCE-REVIEW.md). As mudanças preservam dados,
layout, idiomas, controles, animações e disponibilidade inicial das abas.

## Mudanças aplicadas

1. **Traduções iniciais:** HTML e WebSocket usam o mesmo pacote imutável por
   idioma e processo R, identificado por hash do conteúdo. O servidor omite o
   envio quando o navegador já recebeu aquele pacote. Trocas de idioma e
   recuperação de um cliente desatualizado continuam enviando o conteúdo completo.
2. **País e Mapa:** o perfil numérico e as curvas de País são reutilizados;
   trocar de idioma atualiza textos, números formatados, legendas e atributos
   de acessibilidade nos mesmos elementos. O Mapa conserva a lista de indicadores
   e transmite apenas camadas alteradas. A preparação antecipada e as regras de
   suspensão das saídas foram mantidas, para não transferir espera ao próximo clique.
3. **Downloads:** disponibilidade, preparação numérica e tradução dos metadados
   foram separadas. Os botões de dados agregados e pares bilaterais deixam de
   montar as matrizes de exportação para consultar sua disponibilidade.
   Matrizes numéricas podem ser reutilizadas entre idiomas; seleção e idioma
   são capturados juntos no clique, preservando a correspondência entre nome
   e conteúdo do arquivo.
4. **Setas do Comércio:** grupos SVG, caminhos e eventos são reutilizados durante
   movimento e zoom. Coordenadas e propriedades são atualizadas sem recriar os
   elementos. Remoção de fluxos, mapas sem dimensões e destruição do componente
   continuam liberando o estado correspondente.

O cache pertence ao processo com dados imutáveis ou à sessão com a seleção
numérica completa. Reiniciar o processo reconstrói o estado; o hash das traduções
inclui o conteúdo efetivamente entregue ao navegador.

## Ganhos observados

| Medida | Antes | Depois |
|---|---:|---:|
| Dicionário francês repetido após o HTML | 97.705 bytes | 0 |
| WebSocket na troca para francês, incluindo 2,5 s seguintes | 313.835 bytes | 182.074–182.076 bytes |
| Grupos de setas removidos/criados em um deslocamento real | 12 / 12 | 0 / 0 |
| Troca para francês, desktop, mediana | 0,96 s | 0,61 s |
| Troca para francês, cenário limitado, mediana | 1,42 s | 1,12 s |
| Primeira abertura, desktop, mediana | 2,29 s | 2,04 s |
| Primeira abertura, cenário limitado, mediana | 15,55 s | 14,79 s |

A troca de idioma reduziu o conteúdo de mensagens em aproximadamente **42%**
nos dois perfis. A janela de 2,5 segundos após a troca inclui mensagens que
chegam depois do primeiro estado estável, evitando que a classificação por etapa
seja confundida com uma economia de tráfego. Os 12 grupos e seus caminhos
continuam presentes durante o deslocamento; somente a geometria é atualizada.

O teste de recuperação confirmou um único reenvio quando o navegador informa
uma versão antiga e nenhum reenvio quando a versão coincide. Esses ganhos de
trabalho e conteúdo evitados são mais diretos que os tempos locais, sujeitos
à variação da máquina e às limitações descritas abaixo.

## Equivalência verificada

- A suíte R passou, incluindo disponibilidade de downloads com dados ausentes,
  zeros e infinitos, seleção durante download, localização e geometria nos 23
  idiomas. A única exclusão é um teste de distinção entre maiúsculas e minúsculas
  em caminhos, inaplicável no Windows.
- O navegador verificou 266 combinações de aba, idioma e largura para os 19
  idiomas adicionados, com 38 downloads reais, além do controle dos quatro
  idiomas originais em 1440, 390 e 320 pixels e 12 cenários de idioma inicial.
  Não ocorreram erros JavaScript nem erros visíveis nas saídas verificadas.
- Os 38 arquivos localizados mantiveram os mesmos números entre idiomas.
  Também passaram os testes de mudanças rápidas na seleção dos downloads,
  controles e tooltips dos mapas, rolagem e restauração de abas em 1440, 1024,
  390 e 320 pixels, incluindo cookies inválidos e bloqueados.
- Foram comparadas 24 telas reais: Sobre, Mapa, País e Comércio em português,
  francês e bengali, nas larguras de 1440 e 390 pixels. Textos já observáveis,
  seleções e geometria numérica permaneceram idênticos. Os novos atributos de
  tradução tornam mais rótulos do Mapa observáveis pelo teste, sem mudar sua
  aparência ou conteúdo.
- 21 capturas ficaram idênticas pixel a pixel. Nas outras três, apenas 14 pixels
  no total diferiram, em um nível por canal RGB; não houve mudança de layout.
- 15 XLSX reais foram comparados antes/depois: cinco tipos de exportação nos
  três idiomas, totalizando **12.696 células e 270 componentes internos**.
  Células, tipos, coordenadas, metadados, planilhas e formatação coincidiram.
  A única diferença permitida é a data de criação do arquivo.
- A abertura de País passou pela entrega deliberadamente atrasada de mensagens,
  incluindo gráfico final retido, movimento reduzido e falha da geografia.
  O conteúdo continua aparecendo completo, com a mesma condição de prontidão.
- Testes isolados confirmaram identidade dos elementos e foco nos gráficos
  localizados, filas de mensagens, estado dos controles e reutilização das setas
  durante 20 movimentos, além de teclado, cliques, tooltips e ciclo de vida.

## Método e limites

As medições usam Chromium sem janela visível e R/Shiny locais. Cada cenário tem
três passagens: desktop de 1440 pixels sem limitação artificial e viewport de
390 pixels com CPU quatro vezes desacelerada, 4 Mbit/s e latência configurada
de 80 ms. O navegador começa com contexto novo e depois recarrega com cache;
o processo R é compartilhado entre passagens.

Uma tentativa incompleta revelou uma corrida no roteiro de teste: a visibilidade
de links podia ser consultada durante a animação do menu. O roteiro passou a
esperar o término da animação antes de abrir e clicar; a aplicação não foi
alterada para isso. Por essa razão, os tempos de navegação mobile entre abas
não devem ser comparados diretamente com a referência anterior. Abertura,
troca de idioma e contagem de mensagens continuam sendo medidas separadamente.

Tamanhos de WebSocket são JSON decodificado, não bytes comprimidos no fio.
Os tempos são observações locais de três passagens, não garantias de produção
ou de desempenho em um modelo específico de celular.

As evidências ficam em `temp/efficiency-results-20260910/`: as pastas
`results/before/` e `results/after/` guardam as medições, capturas e planilhas;
`results/checks/` e `logs/checks/` registram as regressões. O arquivo
`results/evidence-index.json` mapeia os caminhos originais para as cópias
preservadas e verifica cada uma por SHA-256. Caches de execução, downloads
intermediários e temporários dos navegadores são removidos ao encerrar a campanha.
