# DevLog CLI — Guia de Referência Técnica
> Tech Lead Session — Projeto #1

---

## 📋 Visão Geral

Sistema de registro de atividades de desenvolvimento pessoal, rodando no terminal. Você loga o que fez, quanto tempo levou, em qual projeto, e gera relatórios de produtividade.

**Objetivo:** aprendizado técnico e arquitetural — SQL puro, serialização, parsing manual de args e arquitetura offline-first.

---

## 📌 User Stories

| ID | Como... | Quero... |
|----|---------|----------|
| US-01 | desenvolvedor | registrar um log com descrição, projeto, duração e categoria |
| US-02 | usuário | listar logs filtrados por projeto, categoria ou intervalo de data |
| US-03 | usuário | ver relatório semanal com total de horas por projeto e categoria |
| US-04 | usuário | exportar logs em `.csv` para abrir no Excel/Sheets |
| US-05 | usuário | usar o sistema 100% offline, sem internet |

---

## ✅ Critérios de Aceite

- Todo log deve ter: `id`, `timestamp`, `projeto`, `descrição`, `duração_minutos`, `categoria`
- Filtros devem ser combináveis (projeto + categoria ao mesmo tempo)
- Relatório semanal agrupa por semana ISO (segunda a domingo)
- Export CSV **sem biblioteca externa** — você escreve o serializer
- Nenhuma informação pode ser perdida se o programa fechar no meio de uma operação

---

## 🗄️ Schema (Decisão Tomada)

**Decisão: Caminho A — schema fixo.**
Campos conhecidos e estáveis, necessidade de índices para filtros e `GROUP BY` nos relatórios.

```sql
CREATE TABLE logs (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp        TEXT    NOT NULL,
  projeto          TEXT    NOT NULL,
  descricao        TEXT    NOT NULL,
  duracao_minutos  INTEGER NOT NULL,
  categoria        TEXT    NOT NULL
);
```

> ⚠️ **Próximo passo:** justificar os tipos de `timestamp` e `duracao_minutos` antes de criar o arquivo.

---

## 🔒 Restrições Técnicas

| Restrição | Motivo Pedagógico |
|-----------|-------------------|
| Sem ORM — SQL puro | Entender o que o ORM esconde |
| Sem biblioteca externa de CSV | Entender serialização na prática |
| Sem framework CLI avançado | Parsing de args manual primeiro |
| Persistência local (SQLite) | Arquitetura offline-first |
| Python 3.10+ ou Node.js puro | Sem runtime extra |

---

## 📚 Guia de Estudo

**Prioridade 1 — Antes de qualquer código**
- SQLite: [sqlite.org/lang.html](https://www.sqlite.org/lang.html) — foque em `CREATE TABLE`, `INSERT`, `SELECT` com `WHERE` e `GROUP BY`
- Python: módulo `sqlite3` da stdlib — [docs.python.org/3/library/sqlite3.html](https://docs.python.org/3/library/sqlite3.html)

**Prioridade 2 — Antes de implementar relatórios**
- SQL `GROUP BY` + funções de agregação: `SUM`, `COUNT`
- ISO week date — como semanas são numeradas (segunda a domingo)

**Prioridade 3 — Antes do CSV**
- RFC 4180 — o padrão real do formato CSV (curto, vale a leitura)

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

## ⚖️ Dilemas Técnicos

### Dilema #1 — Schema fixo vs JSON (RESOLVIDO ✅)

| | Caminho A — Schema fixo ✅ | Caminho B — JSON |
|--|---------------------------|-----------------|
| **Vantagem** | Índices, `GROUP BY` eficiente, SQL limpo | Campos opcionais, flexível |
| **Desvantagem** | Menos flexível para campos extras | Sem índice no valor, lento em escala |
| **Quando usar** | Campos conhecidos e estáveis | Formulários dinâmicos, e-commerce variado |

**Decisão final: Caminho A.**

---

## 🚀 Próximos Passos

- [ ] Escrever o `CREATE TABLE` com justificativa dos tipos
- [ ] Justificar: por que `TEXT` para timestamp? Por que `INTEGER` para duração?
- [ ] Criar estrutura de pastas do projeto
- [ ] Implementar US-01: inserção de log via CLI
- [ ] Implementar US-02: listagem com filtros combináveis
- [ ] Implementar US-03: relatório semanal com `GROUP BY` + semana ISO
- [ ] Implementar US-04: serializer CSV manual

---

*Atualizado a cada decisão tomada durante o projeto.*
