# Guia de Contribuição

Obrigado por querer contribuir com o DevLog CLI! Este guia descreve como o projeto está organizado e como trabalhar nele de forma consistente.

---

## Índice

1. [Filosofia do Projeto](#filosofia-do-projeto)
2. [Setup do Ambiente](#setup-do-ambiente)
3. [Estrutura de Pastas](#estrutura-de-pastas)
4. [Regras de Arquitetura](#regras-de-arquitetura)
5. [Convenções de Código](#convenções-de-código)
6. [Fluxo de Contribuição](#fluxo-de-contribuição)
7. [Como Testar](#como-testar)
8. [O que Não Fazer](#o-que-não-fazer)

---

## Filosofia do Projeto

O DevLog CLI é um projeto de **aprendizado técnico intencional**. Isso significa:

- **SQL puro** — sem ORM. Toda query é escrita à mão.
- **CSV manual** — sem biblioteca de serialização. O serializer deve implementar RFC 4180 diretamente.
- **Dart puro** — sem Flutter, sem framework CLI externo. Parsing de argumentos e UI são feitos na mão.
- **Offline-first** — nenhuma operação requer rede.

Antes de adicionar uma dependência nova, pergunte: _"O que eu perco de aprendizado se usar essa biblioteca?"_

---

## Setup do Ambiente

```bash
# Requisitos
# - Dart SDK >= 2.19.0
# - sqlite3.dll no PATH (Windows) ou libsqlite3 instalado (Linux/macOS)

git clone https://github.com/notyalC0/DevLogCLI.git
cd DevLogCLI

dart pub get
dart run bin/main.dart
```

Para compilar o executável:

```bash
dart compile exe bin/main.dart -o devlog.exe
```

---

## Estrutura de Pastas

```
bin/
  main.dart               ← Entrypoint: configura encoding e chama runMenu()

lib/
  core/
    database_helper.dart  ← Driver SQLite encapsulado (acesso privado ao _db)
    theme.dart            ← Paleta ANSI True Color Catppuccin-Monokai

  models/
    log_entry.dart        ← Modelo de dados puro (sem lógica de negócio)

  logic/
    log_service.dart      ← Toda a lógica de acesso a dados

  ui/
    components.dart       ← Primitivos visuais (Draw.box, Draw.spinner, etc.)
    menu.dart             ← Fluxos de navegação e entrada do usuário
    renderer.dart         ← Singleton Screen.instance que encapsula Console
```

---

## Regras de Arquitetura

### 1. Sentido das dependências

```
UI → Logic → Core
```

- A UI **pode** importar `Logic` e `Core`.
- A `Logic` **pode** importar `Core`.
- A `Core` **não importa** nada das camadas superiores.
- A `UI` **nunca** acessa o banco diretamente — sempre via `LogService`.

### 2. `DataBaseHelper` é a única classe que conhece o sqlite3

O campo `_db` é privado. Nenhuma outra classe importa `package:sqlite3`. Se precisar de uma nova operação SQL, adicione um método em `DataBaseHelper`.

### 3. `LogService` não tem lógica de UI

`LogService` nunca chama `stdout.writeln` ou lê `stdin`. Ele apenas retorna dados ou lança exceções.

### 4. `Draw` não tem lógica de negócio

Os métodos de `Draw` exibem dados — não decidem o que exibir. A decisão fica em `menu.dart`.

---

## Convenções de Código

### Nomenclatura

| Símbolo         | Convenção        | Exemplo                        |
| --------------- | ---------------- | ------------------------------ |
| Classes         | `UpperCamelCase` | `LogService`, `DataBaseHelper` |
| Funções/métodos | `lowerCamelCase` | `insert`, `radioMenu`          |
| Constantes      | `lowerCamelCase` | `Theme.pink`, `_kBoxInner`     |
| Campos privados | prefixo `_`      | `_db`, `_visualLen`            |

### Formatação

Use o formatter padrão do Dart:

```bash
dart format .
```

Linha máxima: **80 caracteres** (padrão do `dart format`).

### Comentários

- Use `///` para docstrings.
- Use `//` para comentários inline explicando decisões não óbvias.
- Não comente o óbvio: `// incrementa i` sobre `i++` é ruído.

---

## Fluxo de Contribuição

1. **Crie uma branch** a partir de `main`:

   ```bash
   git checkout -b feat/nome-da-feature
   # ou
   git checkout -b fix/descricao-do-bug
   ```

2. **Faça as alterações** seguindo as regras de arquitetura acima.

3. **Rode a análise estática** antes de commitar:

   ```bash
   dart analyze
   dart format --set-exit-if-changed .
   ```

4. **Escreva uma entrada no `changelog.md`** em `[Não lançado]`.

5. **Abra um Pull Request** com:
   - Título objetivo: `feat: adiciona paginação na listagem` ou `fix: corrige parser de duração para formato 1h30m`
   - Descrição explicando _por que_ a mudança é necessária
   - Se quebra compatibilidade, indique claramente

### Prefixos de commit (Conventional Commits)

| Prefixo     | Quando usar                               |
| ----------- | ----------------------------------------- |
| `feat:`     | Nova funcionalidade                       |
| `fix:`      | Correção de bug                           |
| `refactor:` | Mudança interna sem alterar comportamento |
| `docs:`     | Mudança apenas em documentação            |
| `chore:`    | Atualização de dependências, config, CI   |
| `test:`     | Adição ou correção de testes              |

---

## Como Testar

Ainda não há testes automatizados (v1.0.0). Para validar manualmente:

```bash
# 1. Análise estática (obrigatório)
dart analyze

# 2. Execute e percorra todos os fluxos do menu
dart run bin/main.dart

# Checklist manual:
# [ ] Registrar atividade com duração nos formatos: 45m, 1h, 1h 30m, 1h30m
# [ ] Registrar atividade e cancelar um campo com :q
# [ ] Registrar aprendizado com tags
# [ ] Buscar por palavra que existe (incluindo termos com 'e' e 'd')
# [ ] Buscar por palavra que não existe
# [ ] Abrir detalhe de um log (Enter na busca)
# [ ] Editar um log pelo painel de detalhe (tecla e)
# [ ] Deletar um log pelo painel de detalhe (tecla d)
# [ ] Gerar relatório semanal — verificar seções Atividades e Base de Conhecimento
# [ ] Exportar CSV e abrir o arquivo gerado em ~/.devlog/devlog_export.csv
# [ ] Tentar registrar atividade com projeto vazio (deve mostrar aviso e voltar)
```

**Testes automatizados (planejado):**

A estrutura de DI já está preparada para testes. O ideal é injetar um `DataBaseHelper` apontando para `:memory:` no `LogService`:

```dart
// Exemplo de setup futuro
final db = DataBaseHelper();
db.initMemory(); // método a implementar
final service = LogService(db);
```

---

## O que Não Fazer

- **Não exponha `_db`** de `DataBaseHelper`. Se precisar de uma operação, adicione um método.
- **Não adicione lógica de negócio em `menu.dart`**. Mova para `LogService` ou um helper em `logic/`.
- **Não use `print()`** fora de `DataBaseHelper.init()`. Use `Draw.info`, `Draw.error`, etc.
- **Não quebre a regra de dependência** entre camadas — UI → Logic → Core.
- **Não adicione dependências desnecessárias** sem justificativa documentada no PR.
