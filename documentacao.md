# DevLog CLI — Documentação Técnica

> Dart puro · SQLite · Offline-first · Terminal UI com ANSI True Color

---

## Sumário

1. [Visão Geral](#visão-geral)
2. [Requisitos](#requisitos)
3. [Instalação e Configuração](#instalação-e-configuração)
4. [Como Usar](#como-usar)
5. [Arquitetura](#arquitetura)
6. [Camadas e Arquivos](#camadas-e-arquivos)
7. [Schema do Banco de Dados](#schema-do-banco-de-dados)
8. [Sistema de Temas (ANSI True Color)](#sistema-de-temas-ansi-true-color)
9. [Componentes de UI](#componentes-de-ui)
10. [Decisões de Design](#decisões-de-design)
11. [Limitações Conhecidas](#limitações-conhecidas)
12. [Melhorias Futuras](#melhorias-futuras)

---

## Visão Geral

O **DevLog CLI** é um sistema de registro de atividades de desenvolvimento pessoal que roda 100% no terminal. Você registra o que fez, quanto tempo, em qual projeto e categoria — e gera relatórios de produtividade semanais. Funciona também como base de conhecimento pessoal para soluções técnicas e aprendizados.

**Objetivos pedagógicos:**

- SQL puro sem ORM
- Serialização CSV sem biblioteca externa
- Arquitetura offline-first com SQLite
- Terminal UI com escape codes ANSI (sem `dart:html`, sem Flutter)

---

## Requisitos

| Item                    | Versão mínima           |
| ----------------------- | ----------------------- |
| Dart SDK                | 2.19.0                  |
| Sistema Operacional     | Windows, Linux ou macOS |
| `sqlite3.dll` (Windows) | Qualquer versão moderna |

> **Windows:** a `sqlite3.dll` precisa estar na mesma pasta do executável (ou no `PATH`). No Linux/macOS a biblioteca é carregada automaticamente do sistema.

---

## Instalação e Configuração

### Modo desenvolvimento

```bash
# 1. Clone o repositório
git clone https://github.com/notyalC0/DevLogCLI.git
cd DevLogCLI

# 2. Instale as dependências
dart pub get

# 3. Execute
dart run bin/main.dart
```

### Compilando para executável nativo

```bash
dart compile exe bin/main.dart -o devlog.exe

# Windows — copie a DLL junto com o executável
cp sqlite3.dll devlog.exe ../
```

O banco de dados é criado automaticamente em `~/.devlog/devlog.db` na primeira execução.

---

## Como Usar

Ao executar `devlog`, o menu interativo é exibido. Navegue com as teclas `↑` / `↓` e confirme com `Enter`.

### Opções do menu

| Opção                         | O que faz                                                                              |
| ----------------------------- | -------------------------------------------------------------------------------------- |
| Registrar atividade de código | Cria um log com projeto, descrição, duração e categoria                                |
| Salvar aprendizado / solução  | Cria um log do tipo "Solução/Aprendizado" com tags e conteúdo detalhado                |
| Buscar nos logs               | Busca interativa em tempo real por `descricao`, `projeto`, `categoria` e `tags`        |
| Gerar relatório semanal       | Exibe total de horas, breakdown por projeto/categoria e base de conhecimento acumulada |
| Exportar CSV                  | Exporta todos os logs para `~/.devlog/devlog_export.csv`                               |
| Sair                          | Encerra o programa                                                                     |

> **Cancelar qualquer campo:** em qualquer prompt de texto, digite `:q` e pressione `Enter` para cancelar a operação e voltar ao menu.

### Como editar ou deletar um log

1. Abra **Buscar nos logs**.
2. Navegue com `↑`/`↓` até o log desejado e pressione `Enter` — o **painel de detalhe** abre.
3. No detalhe, use `e` para **editar** ou `d` para **deletar**.

> As teclas `e` e `d` só disparam ações dentro do painel de detalhe — na busca elas são tratadas como caracteres normais do termo de busca.

### Formato de duração aceito

| Entrada  | Interpretação |
| -------- | ------------- |
| `45m`    | 45 minutos    |
| `1h`     | 60 minutos    |
| `1h 30m` | 90 minutos    |
| `1h30m`  | 90 minutos    |

### Categorias disponíveis (atividades de código)

| Categoria      | Quando usar                                 |
| -------------- | ------------------------------------------- |
| `Feature`      | Implementação de funcionalidade nova        |
| `Refatoração`  | Mudança interna sem alterar comportamento   |
| `Bugfix`       | Correção de defeito                         |
| `Documentação` | Atualização de docs, comentários ou READMEs |
| `DevOps`       | CI/CD, scripts, configuração de ambiente    |
| `Revisão`      | Code review ou análise de PR                |
| `Reunião`      | Rituais ágeis, calls, alinhamentos          |
| `Experimento`  | Prova de conceito, spike técnico            |
| `Estudo`       | Leitura, curso ou investigação documentada  |

---

## Arquitetura

O projeto segue uma separação em três camadas clássica:

```
┌─────────────────────────────────────┐
│              UI Layer                │
│    menu.dart  ·  components.dart    │
└──────────────────┬──────────────────┘
                   │ usa
┌──────────────────▼──────────────────┐
│            Logic Layer               │
│           log_service.dart          │
└──────────────────┬──────────────────┘
                   │ usa
┌──────────────────▼──────────────────┐
│             Core Layer               │
│  database_helper.dart  ·  theme.dart│
└─────────────────────────────────────┘
```

**Regra de dependência:** camadas superiores dependem de camadas inferiores — nunca o contrário. A `UI` nunca acessa o banco diretamente.

**Injeção de dependência:** `LogService` recebe `DataBaseHelper` pelo construtor, permitindo substituir a implementação do banco em testes sem alterar o service.

---

## Camadas e Arquivos

### `bin/main.dart`

Ponto de entrada. Força `stdout.encoding = utf8` para garantir que caracteres Unicode (bordas de caixa, símbolos) sejam renderizados corretamente no Windows Terminal e no PowerShell.

---

### `lib/core/database_helper.dart`

Encapsula toda a comunicação com o SQLite.

| Método      | Assinatura                                                              | Descrição                                                                        |
| ----------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `init()`    | `void`                                                                  | Abre o banco em `~/.devlog/devlog.db`, cria o diretório e a tabela se necessário |
| `execute()` | `void execute(String sql, [List<Object?> params])`                      | Executa INSERT / UPDATE / DELETE / DDL                                           |
| `select()`  | `List<Map<String, dynamic>> select(String sql, [List<Object?> params])` | Executa SELECT e retorna lista de mapas                                          |
| `close()`   | `void`                                                                  | Descarta a conexão com o banco                                                   |

> O campo `_db` (driver interno do sqlite3) é **privado** — nenhuma camada externa acessa o driver diretamente.

---

### `lib/models/log_entry.dart`

Modelo de dados central.

| Campo            | Tipo Dart | Coluna SQL                    | Obrigatório             |
| ---------------- | --------- | ----------------------------- | ----------------------- |
| `id`             | `int?`    | `id INTEGER PK AUTOINCREMENT` | Não (gerado pelo banco) |
| `timestamp`      | `String`  | `timestamp TEXT`              | Sim                     |
| `projeto`        | `String`  | `projeto TEXT`                | Sim                     |
| `descricao`      | `String`  | `descricao TEXT`              | Sim                     |
| `duracaoMinutos` | `int?`    | `duracao_minutos INTEGER`     | Não                     |
| `categoria`      | `String`  | `categoria TEXT`              | Sim                     |
| `tipo`           | `String`  | `tipo TEXT`                   | Sim                     |
| `conteudo`       | `String?` | `conteudo TEXT`               | Não                     |
| `tags`           | `String?` | `tags TEXT`                   | Não                     |

---

### `lib/logic/log_service.dart`

Contém toda a lógica de acesso a dados. Nunca imprime nada — apenas retorna dados ou lança exceções.

| Método                               | Descrição                                               |
| ------------------------------------ | ------------------------------------------------------- |
| `insert(LogEntry)`                   | INSERT dinâmico via `toMap()`                           |
| `getAll()`                           | Retorna todos os logs                                   |
| `delete(int id)`                     | Remove por ID                                           |
| `update(LogEntry)`                   | UPDATE dinâmico; lança `ArgumentError` se `id` for nulo |
| `search(String query)`               | Busca em `descricao` e `tags` com `LIKE`                |
| `filter({projeto, categoria, tipo})` | Filtros combináveis com cláusula `WHERE` dinâmica       |

---

### `lib/core/theme.dart`

Paleta de cores **Catppuccin-Monokai** em ANSI True Color (24-bit).

| Constante     | Hex       | Uso                           |
| ------------- | --------- | ----------------------------- |
| `Theme.text`  | `#CAD3F5` | Texto base suave              |
| `Theme.mauve` | `#CBA6F7` | Bordas e estrutura            |
| `Theme.pink`  | `#F92672` | Destaque / prompt principal   |
| `Theme.green` | `#A6E22E` | Sucesso, seleção, confirmação |
| `Theme.cyan`  | `#66D9EF` | Tags, aprendizados, info      |
| `Theme.gold`  | `#C8960C` | Avisos, tempo, spinner        |

**Método especial:**

```dart
Theme.color(String text, String hexColor)
```

Embrulha qualquer string em ANSI True Color com base em um hex arbitrário (`#F92672` ou `F92672`).

---

### `lib/ui/components.dart`

Biblioteca de primitivos visuais da UI. Todos os métodos são estáticos na classe `Draw`.

#### `Draw.box(String title, List<String> content)`

Desenha uma caixa Unicode `╭─ TITLE ──╮`. Calcula o padding automaticamente pela string mais longa (descontando escapes ANSI).

#### `Draw.prompt(String question) → String?`

Renderiza a pergunta colorida e lê uma linha do `stdin`. Retorna `null` se o usuário digitar `:q` (cancelamento universal).

#### `Draw.radioMenu(List<String> options, {Map<String,String>? hotkeys, List<String>? hints})`

Menu navegável com `◉`/`◯`, teclas `↑`/`↓` em modo raw do terminal. Suporta linha opcional de dicas (`hints`) renderizada abaixo das opções. Cai em modo numérico se o terminal não suportar raw mode.

#### `Draw.liveSearch(List<LogEntry> allEntries, LogService service)`

Busca interativa com filtragem em tempo real. Exibe até 8 resultados paginados com seleção por `↑`/`↓`. Pressionar `Enter` abre o painel de detalhe (`logDetail`). Os caracteres digitados (incluindo `e` e `d`) são sempre acrescentados ao termo de busca — as ações de editar/deletar **só estão disponíveis no painel de detalhe**.

#### `Draw.logDetail(LogEntry e, {LogService? service}) → bool`

Exibe todas as informações de um `LogEntry` em uma caixa formatada. Retorna `true` se o log foi deletado. Se `service` for fornecido, habilita as teclas `e` (editar) e `d` (deletar) no painel. A edição usa `_editFlow`.

#### `Draw.spinner<T>(Future<T> task, String message)`

Animação de braille `⠋⠙⠹⠸…` enquanto o `Future` não resolve. Substitui pela linha com `✔` verde ao finalizar. Esconde o cursor durante a animação via `\x1B[?25l`.

#### `Draw.logCard(LogEntry e)`

Imprime um card resumido de log. Logs do tipo `Solução/Aprendizado` são destacados em `cyan`; os demais usam o texto base.

#### Helpers de status

```dart
Draw.success(String msg)   // ✔ verde
Draw.error(String msg)     // ✖ rosa
Draw.info(String msg)      // ℹ ciano
Draw.warn(String msg)      // ⚠ dourado
Draw.separator()           // ─────── mauve
```

---

### `lib/ui/menu.dart`

Loop principal de navegação. Expõe `Future<void> runMenu()` chamado pelo `main`.

**Fluxos implementados:**

| Fluxo               | Campos coletados                                     |
| ------------------- | ---------------------------------------------------- |
| Registrar atividade | projeto, descrição, duração, categoria (radio)       |
| Salvar aprendizado  | projeto, título, conteúdo, tags                      |
| Buscar              | busca ao vivo; Enter → detalhe com edição e exclusão |
| Relatório semanal   | automático: atividades + base de conhecimento        |
| Exportar CSV        | automático (sem input)                               |

**Parser de duração** (`_parseDuration`): suporta `45m`, `1h`, `1h 30m`, `1h30m`.

**Export CSV** (`_fluxoExportCSV`): serialização manual conforme RFC 4180 — células com vírgulas, aspas ou quebras de linha são envoltas em aspas duplas, e aspas internas são escapadas como `""`.

**Relatório semanal:** dividido em duas seções — atividades de código (com breakdown por projeto e categoria) e base de conhecimento (lista de soluções/aprendizados com contagem de tags).

---

## Schema do Banco de Dados

```sql
CREATE TABLE IF NOT EXISTS logs (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp        TEXT    NOT NULL,  -- ISO 8601: "2026-04-10T21:00:00.000"
  projeto          TEXT    NOT NULL,
  descricao        TEXT    NOT NULL,
  duracao_minutos  INTEGER,           -- nullable: aprendizados podem não ter duração
  categoria        TEXT    NOT NULL,
  tipo             TEXT    NOT NULL,  -- "Código" | "Solução / Aprendizado"
  conteudo         TEXT,              -- nullable: detalhe ampliado do aprendizado
  tags             TEXT               -- nullable: vírgula-separado, ex: "sql,parser"
);
```

**Decisões de tipo:**

- `timestamp TEXT` — SQLite não tem tipo nativo de data. ISO 8601 garante que ordenação alfabética = cronológica.
- `duracao_minutos INTEGER` — sempre inteiro, parser converte na entrada.
- `tags TEXT` — separado por vírgulas. Tradeoff: simples de implementar, mas não indexável por valor individual.

---

## Sistema de Temas (ANSI True Color)

O terminal precisa suportar ANSI escape codes. Terminais modernos (Windows Terminal, iTerm2, VS Code integrated terminal, a maioria dos emuladores Linux) suportam True Color (24-bit).

**Formato do código ANSI:**

```
\x1B[38;2;R;G;Bm <texto> \x1B[0m
      │  │ └─┴─┴── valores R, G, B (0–255)
      │  └──────── sequência de cor de foreground
      └─────────── ESC
```

**No Windows Console Host legado** (`cmd.exe`), o menu ativa automaticamente o `VirtualTerminalLevel` via registro. No Windows Terminal e PowerShell 7+ funciona nativamente.

---

## Componentes de UI

### Exemplo de caixa gerada

```
╭─ notyalC / DevLog ───────────────────────────────────╮
│                                                      │
│    Semana Atual: 2h 30m                              │
│    Projetos Ativos: DevLogCLI                        │
│    Último: [DevLogCLI] Implementação do menu...      │
│                                                      │
╰──────────────────────────────────────────────────────╯
```

### Exemplo de card de log

```
[#42] 10 Abr 2026 ─ 45m ─ [DevLogCLI]
🏷️  Categoria: Feature  |  Tipo: Código
  ↳ Criação da tabela de logs com schema fixo.

[#38] 08 Abr 2026 ─ [DevLogCLI]
💡 Tipo: Solução / Aprendizado  |  Tags: sql, parser
  ↳ O SQLite não tem tipo nativo de data...
```

---

## Decisões de Design

### Uma tabela vs. duas

Optou-se por **uma tabela** com campo `tipo` discriminante e campos nullable (`conteudo`, `duracao_minutos`). A alternativa de duas tabelas exigiria JOIN em relatórios cruzados, aumentando a complexidade sem ganho real para o volume de dados esperado.

### Dependency Injection no LogService

`LogService` recebe `DataBaseHelper` pelo construtor. Isso permite injetar um banco em memória nos testes sem alterar nada no service.

### Encapsulamento do driver SQLite

O campo `_db` (objeto `Database` do pacote `sqlite3`) é privado dentro de `DataBaseHelper`. O `LogService` — e qualquer outra camada — só enxerga os métodos `execute` e `select`, protegendo o código contra mudanças de implementação do driver.

---

## Limitações Conhecidas

| Limitação                                | Impacto                             | Mitigação                                      |
| ---------------------------------------- | ----------------------------------- | ---------------------------------------------- |
| `LIKE '%query%'` na busca não usa índice | Lento com muitos registros          | FTS5 como melhoria futura                      |
| `tags TEXT` separado por vírgulas        | Não indexável por tag individual    | Tabela `tags` normalizada como melhoria futura |
| `sqlite3.dll` manual no Windows          | Distribuição menos prática          | Incluir a DLL junto ao release                 |
| Sem paginação na listagem                | Muitos resultados poluem o terminal | Adicionar `LIMIT/OFFSET`                       |

---

## Melhorias Futuras

- **FTS5 (Full-Text Search):** módulo nativo do SQLite para substituir o `LIKE`. Cria índice invertido real.
- **Argparse:** suporte a comandos diretos — `devlog add`, `devlog search "sqlite"`, `devlog report` — sem passar pelo menu.
- **Tags normalizadas:** tabela separada `log_tags (log_id, tag)` com índice em cada tag.
- **Paginação:** `LIMIT`/`OFFSET` na listagem e busca (atualmente fixado em 8 resultados).
- **Testes unitários:** `LogService` com banco SQLite in-memory (`:memory:`).
- **Instalador/script de setup:** copia o executável e a DLL para `~/.local/bin` ou `C:\Users\<user>\AppData\Local\devlog`.
- **Filtros compostos na busca:** filtrar por categoria, projeto ou intervalo de datas diretamente na busca interativa.
