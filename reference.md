# DevLog CLI — Guia de Referência Técnica
> Tech Lead Session — Projeto #1

---

## 📋 Visão Geral

Sistema de registro de atividades de desenvolvimento pessoal, rodando no terminal. Você loga o que fez, quanto tempo levou, em qual projeto, e gera relatórios de produtividade. Funciona também como base de conhecimento pessoal — soluções, aprendizados e changelog vivo de projetos.

**Objetivo:** aprendizado técnico e arquitetural — SQL puro, serialização, parsing manual de args e arquitetura offline-first.

**Linguagem:** Dart puro (CLI) + SQLite via pacote `sqlite3`

---

## 📌 User Stories

| ID | Como... | Quero... |
|----|---------|----------|
| US-01 | desenvolvedor | registrar um log com descrição, projeto, duração e categoria |
| US-02 | usuário | listar logs filtrados por projeto, categoria ou intervalo de data |
| US-03 | usuário | ver relatório semanal com total de horas por projeto e categoria |
| US-04 | usuário | exportar logs em `.csv` para abrir no Excel/Sheets |
| US-05 | usuário | usar o sistema 100% offline, sem internet |
| US-06 | usuário | registrar soluções e aprendizados para consulta futura |

---

## ✅ Critérios de Aceite

- Todo log deve ter: `id`, `timestamp`, `projeto`, `descrição`, `duração_minutos`, `categoria`, `tipo`
- Filtros devem ser combináveis (projeto + categoria + tipo ao mesmo tempo)
- Relatório semanal agrupa por semana ISO (segunda a domingo)
- Export CSV **sem biblioteca externa** — você escreve o serializer
- Nenhuma informação pode ser perdida se o programa fechar no meio de uma operação

---

## 🗄️ Schema (Decisão Tomada)

**Decisão: Caminho A — schema fixo com campos opcionais.**
Campos conhecidos e estáveis, necessidade de índices para filtros e `GROUP BY` nos relatórios. Campo `tipo` diferencia atividade de conhecimento.

```sql
CREATE TABLE IF NOT EXISTS logs (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp        TEXT    NOT NULL,
  projeto          TEXT    NOT NULL,
  descricao        TEXT    NOT NULL,
  duracao_minutos  INTEGER,
  categoria        TEXT    NOT NULL,
  tipo             TEXT    NOT NULL,
  conteudo         TEXT,
  tags             TEXT
);
```

**Tipos justificados:**
- `timestamp TEXT` — SQLite não tem tipo nativo de data. ISO 8601 permite ordenação alfabética = cronológica
- `duracao_minutos INTEGER` — duração sempre inteira, já convertida pra minutos
- `tags TEXT` — separadas por vírgula. Tradeoff: simples de implementar, sem índice no valor

---

## 🏗️ Estrutura de Pastas

```
bin/
  main.dart

lib/
  core/
    database_helper.dart  ✅
    theme.dart            🔜
  models/
    log_entry.dart        ✅
  logic/
    log_service.dart      ✅
  ui/
    menu.dart             🔜
    components.dart       🔜
```

---

## 📦 Arquivos Implementados

### `models/log_entry.dart` ✅
Modelo de dados com `fromMap` e `toMap`. Campo `id` nullable para suportar insert sem id.

### `core/database_helper.dart` ✅
- Abre conexão SQLite em `~/.devlog/devlog.db`
- Cria a pasta `.devlog` se não existir
- Cria tabela `logs` com `IF NOT EXISTS`

### `logic/log_service.dart` ✅
Métodos implementados:
- `insert(LogEntry)` — insert dinâmico via `toMap()`
- `getAll()` — retorna todos os logs como `List<LogEntry>`
- `delete(int id)` — deleta por id
- `update(LogEntry)` — update dinâmico, valida id antes
- `search(String query)` — busca em `descricao` e `tags` via `LIKE`
- `filter({projeto, categoria, tipo})` — filtros combináveis com `WHERE` dinâmico

---

## 🔒 Restrições Técnicas

| Restrição | Motivo Pedagógico |
|-----------|-------------------|
| Sem ORM — SQL puro | Entender o que o ORM esconde |
| Sem biblioteca externa de CSV | Entender serialização na prática |
| Sem framework CLI avançado | Parsing de args manual primeiro |
| Persistência local (SQLite) | Arquitetura offline-first |
| Dart puro, sem Flutter | Foco em CLI e lógica pura |

---

## ⚖️ Dilemas Técnicos

### Dilema #1 — Schema fixo vs JSON (RESOLVIDO ✅)

| | Caminho A — Schema fixo ✅ | Caminho B — JSON |
|--|---------------------------|-----------------|
| **Vantagem** | Índices, `GROUP BY` eficiente, SQL limpo | Campos opcionais, flexível |
| **Desvantagem** | Menos flexível para campos extras | Sem índice no valor, lento em escala |
| **Quando usar** | Campos conhecidos e estáveis | Formulários dinâmicos, e-commerce variado |

**Decisão final: Caminho A.**

### Dilema #2 — Uma tabela vs duas (RESOLVIDO ✅)

| | Caminho A — Uma tabela ✅ | Caminho B — Duas tabelas |
|--|--------------------------|--------------------------|
| **Vantagem** | Query simples, filtro por `tipo` | Sem campos nullable, schema limpo |
| **Desvantagem** | Campos nullable (`duracao`, `conteudo`) | JOIN necessário em relatórios cruzados |
| **Quando usar** | Entidades similares com pequenas variações | Entidades muito distintas |

**Decisão final: Caminho A — validação dos campos nullable feita na aplicação.**

### Dilema #3 — Dependency Injection (RESOLVIDO ✅)

`LogService` recebe `DatabaseHelper` pelo construtor — não instancia internamente.
Motivo: permite trocar a implementação do banco (ex: banco em memória pra testes) sem alterar o service.

---

## 🐛 Dívidas Técnicas

- `dataBaseHelper.db.execute` — acesso direto ao field `db` de fora da classe quebra encapsulamento. Refatorar `DatabaseHelper` para expor métodos ao invés do field raw.

---

## 🔮 Melhorias Futuras

- **FTS5 (Full Text Search)** — módulo nativo do SQLite para busca eficiente em texto. Substituiria o `LIKE '%query%'` do método `search`, que não usa índice e varre todas as linhas.

---

## 📚 Guia de Estudo

**Prioridade 1 — Concluído**
- SQLite: [sqlite.org/lang.html](https://www.sqlite.org/lang.html)
- Dart `sqlite3`: [pub.dev/packages/sqlite3](https://pub.dev/packages/sqlite3)

**Prioridade 2 — Antes de implementar relatórios**
- SQL `GROUP BY` + funções de agregação: `SUM`, `COUNT`
- ISO week date — como semanas são numeradas (segunda a domingo)

**Prioridade 3 — Antes do CSV**
- RFC 4180 — o padrão real do formato CSV

**Prioridade 4 — Antes do theme.dart**
- ANSI escape codes — cores e formatação no terminal

---

## 🤖 Como Usar a IA Estrategicamente

**✅ Válido**
- *"Aqui está meu schema SQL. O que está errado na modelagem considerando os filtros?"*
- *"Escrevi essa query. Ela funciona mas parece lenta. O que você vê?"*
- *"Aqui está minha lógica de serialização CSV. Tem edge case que esqueci?"*

**❌ Evitar**
- *"Como faço o relatório semanal?"* — você tenta primeiro.
- *"Me dá o schema completo."* — você propõe, a IA revisa.

> **Regra:** você traz o código ou a lógica, a IA aponta o problema.

---

## 🚀 Próximos Passos

- [x] Schema definido e justificado
- [x] Estrutura de pastas definida
- [x] `log_entry.dart` implementado
- [x] `database_helper.dart` implementado
- [x] `log_service.dart` implementado
- [ ] `theme.dart` — sistema de cores ANSI
- [ ] `components.dart` — elementos visuais reutilizáveis
- [ ] `menu.dart` — navegação e input do usuário
- [ ] `main.dart` — entry point e wiring
- [ ] US-03: relatório semanal com `GROUP BY` + semana ISO
- [ ] US-04: serializer CSV manual

---

*Atualizado a cada decisão tomada durante o projeto.*
