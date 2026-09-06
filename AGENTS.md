# Organização local e campanhas do painel

- Escreva em português com acentos e preserve Unicode/UTF-8.
- Todos os experimentos, testes manuais, benchmarks, campanhas, worktrees temporárias, cópias do aplicativo, screenshots, dados de teste e logs devem ficar em `temp/<id>/`, dentro do checkout principal do **wlvpanel**. A pasta é ignorada pelo Git.
- Nunca crie cópias irmãs como `wlvpanel-runtime` ou `wlvpanel-*`, nem use a raiz dos discos, AppData, temporários externos ou a pasta temporária do wlvdb para experimentos do painel.
- Crie a campanha com `scripts/manage-campaigns.ps1 -Action New -Id <id>`. Use `worktrees/`, `scratch/`, `logs/` e `results/` dentro dela. Para executar comandos com temporários e log corretamente configurados, use `scripts/run-experiment.ps1`.
- Defina `TEMP`, `TMP` e `TMPDIR` antes de iniciar R, Python ou outros processos. Configure também todos os caminhos explícitos de saída. `WLV_CAMPAIGN_ROOT` identifica a campanha; o painel direciona o cache e os downloads gerados para ela quando essa variável está presente.
- Ferramentas reutilizáveis pertencem a `scripts/`, `utils/` ou `tests/manual/`. Não acrescente saídas geradas a `run_logs/`, ao código versionado ou à raiz do projeto.
- Retome a tentativa existente quando possível. Não duplique dados e resultados sem necessidade. Cada campanha deve registrar finalidade, commit e estado em `.campaign.json`.
- Ao concluir ou abandonar uma campanha, encerre seus processos, revise o que precisa permanecer e marque `Complete` ou `Fail`. Preserve somente os resultados e evidências necessários. Limpar os artefatos dispensáveis faz parte do encerramento da tarefa; não espere outra solicitação do usuário.
- Confira `scripts/manage-campaigns.ps1 -Action Clean` e aplique com `-Apply`. O comando remove somente campanhas encerradas e não preservadas. Use `-Preserve` apenas quando houver motivo registrado para manter a campanha.
- Nunca use `git clean -fdx`, exclusão por prefixo, caminhos fora de `temp/` ou limpeza que siga links. Campanhas ativas, arquivos preservados, links, locks, repositórios desconhecidos e worktrees alteradas devem bloquear a exclusão.
- Antes de descartar uma cópia com código diferente, incorpore o trabalho útil ou preserve seus arquivos/patches com origem e hash. Não substitua o código principal por uma cópia antiga do runtime.
- `data/`, `results/`, os arquivos versionados, bibliotecas R e `.git/` do checkout principal são recursos operacionais e não fazem parte da limpeza de campanhas. O cache operacional pode ser regenerado, mas não deve ser removido durante o uso do painel.
- O wlvdb é outro projeto. Não modificar nem limpar sua campanha 054, seus resultados ou fontes ao trabalhar no painel.
- Antes de movimentações ou exclusões recursivas no Windows, confira os caminhos absolutos e seus ancestrais. Use PowerShell de ponta a ponta com `-LiteralPath`, sem atravessar junctions/symlinks; verifique os arquivos preservados e o estado final do Git.
