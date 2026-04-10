# Changelog

Todas as mudanças notáveis neste projeto são documentadas aqui.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/).
Versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/).

---

## [Não lançado]

_(Melhorias planejadas para a próxima versão — ver [documentacao.md](documentacao.md#melhorias-futuras))_

---

## [1.1.0] — 2026-04-14

### Adicionado

#### UI — Busca e Detalhe

- `Draw.liveSearch` — busca interativa em tempo real: filtra enquanto o usuário digita, exibe até 8 resultados com seleção por `↑`/`↓`; `Enter` abre o painel de detalhe; `Esc`/`q` voltam ao menu
- `Draw.logDetail` — painel de detalhe completo de um `LogEntry` com todas as colunas; quando `service` é fornecido, habilita `e` para editar e `d` para deletar
- `Draw._editFlow` — fluxo de edição campo a campo com `:q` para cancelar alteração individual sem perder os outros campos

#### UI — Componentes

- `Draw.radioMenu` agora aceita parâmetro `hints` para exibir uma linha de dica contextual abaixo das opções
- `Draw.hotkeyBar` — barra inferior com atalhos formatados (`key · descrição`)
- `Draw.dottedLine` — divisor pontilhado para separar seções no terminal
- `Draw.statCards` — linha de cards com estatísticas (usa classe `StatCard` em vez de records para compatibilidade com Dart 2.x)
- `renderer.dart` — singleton `Screen.instance` que encapsula `Console` do `dart_console`; toda a UI referencia `Screen.instance` em vez de instanciar `Console` diretamente

#### Categorias

- 9 categorias em `kCategorias`: `Feature`, `Refatoração`, `Bugfix`, `Documentação`, `DevOps`, `Revisão`, `Reunião`, `Experimento`, `Estudo`

#### Menu

- Relatório semanal dividido em duas seções: **Atividades de código** (breakdown por projeto e categoria) e **Base de conhecimento** (logs de Solução/Aprendizado com contagem de tags)
- Cancelamento universal com `:q` em todos os campos de texto — digitar `:q` + Enter cancela o fluxo atual sem salvar

### Corrigido

- **`liveSearch` interceptava `e` e `d` como atalhos** durante a digitação, tornando impossível buscar termos que contivessem essas letras. As ações de editar/deletar foram movidas exclusivamente para o painel `logDetail` (acessível via `Enter`).
- Hint de navegação adicionado na tela de busca: `↳ Enter no resultado → detalhe · editar e deletar disponíveis no detalhe`
- Alt-screen (`enterAlt`/`exitAlt`) garante que o terminal não cresça entre renderizações
- Barra de atalhos do `liveSearch` atualizada: exibe apenas `↑↓ navegar · ent detalhes · q voltar`

---

## [1.0.0] — 2026-04-10

### Adicionado

#### Core

- `DataBaseHelper` — conexão SQLite em `~/.devlog/devlog.db` com criação automática do diretório e da tabela
- `Theme` — paleta de cores **Catppuccin-Monokai** em ANSI True Color (24-bit) com constantes `text`, `mauve`, `pink`, `green`, `cyan`, `gold`
- `Theme.color(text, hexColor)` — método auxiliar para colorir qualquer string com hex arbitrário

#### Modelos

- `LogEntry` — modelo de dados com `fromMap` e `toMap`; campo `id` nullable para suporte a INSERT sem id pré-definido

#### Lógica

- `LogService.insert` — INSERT dinâmico via `toMap()`
- `LogService.getAll` — retorna todos os logs
- `LogService.delete` — remove por ID
- `LogService.update` — UPDATE dinâmico com validação de `id`
- `LogService.search` — busca em `descricao` e `tags` com `LIKE`
- `LogService.filter` — filtros combináveis por `projeto`, `categoria` e `tipo`

#### UI — Componentes (`Draw`)

- `Draw.box` — caixa Unicode `╭─ TITLE ──╮` com padding automático e suporte a ANSI nas linhas de conteúdo
- `Draw.prompt` — label colorida + leitura de `stdin`
- `Draw.radioMenu` — menu navegável com `◉`/`◯` e teclas de seta; fallback numérico para terminais sem raw mode
- `Draw.spinner<T>` — animação de braille com `Timer.periodic`; troca para `✔` ao resolver o `Future`
- `Draw.logCard` — card formatado de `LogEntry` com destaque ciano para logs de aprendizado
- `Draw.separator`, `Draw.success`, `Draw.error`, `Draw.info`, `Draw.warn` — helpers de status

#### UI — Menu

- Dashboard inicial com stats da semana atual (total de horas, projetos ativos, último log)
- Fluxo de registro de atividade de código com seleção interativa de categoria
- Fluxo de registro de aprendizado/solução com campos `conteudo` e `tags`
- Fluxo de busca com exibição de cards e contador de resultados
- Relatório semanal com breakdown por projeto e por categoria
- Exportação CSV manual (RFC 4180) para `~/.devlog/devlog_export.csv`

#### Entrypoint

- `bin/main.dart` com `stdout.encoding = utf8` para correta renderização de Unicode no Windows

### Técnico

- Encapsulamento de `_db` como campo privado em `DataBaseHelper`; `LogService` acessa apenas os métodos públicos `execute` e `select`
- Constraint do SDK ajustado para `>=2.19.0 <4.0.0` para compatibilidade com o Dart embarcado no Flutter SDK 2.x
- `sqlite3` fixado em `>=1.0.0 <2.0.0` (a versão 2.x requer Dart 3+)
- `sqlite3.dll` incluída na raiz do projeto para execução no Windows
