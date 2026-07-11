---
type: Framework Overview
title: FluentSQL — Visão Geral
description: O que é o FluentSQL, sua arquitetura (só gera SQL/MQL; executa no DataEngine), a relação com o Janus, fontes da verdade e quando usar.
tags: [fluentsql, sql, delphi, dsl, dialect, overview]
timestamp: 2026-07-11T00:00:00Z
---

# FluentSQL — Visão Geral

O **FluentSQL** é uma biblioteca fluente **database-agnostic** de geração de
scripts **SQL/MQL** para Delphi e Lazarus, autor **Isaque Pinheiro**
(ModernDelphiWorks), licença MIT
(`Source/Core/FluentSQL.Interfaces.pas:2-11`). Você encadeia métodos e obtém a **string
SQL** pronta; um **qualificador por dialeto** cuida das diferenças de sintaxe
(paginação, aspas de identificador, etc.).

## Arquitetura em uma frase

FluentSQL **constrói uma AST** de query e a **serializa por dialeto** em uma
string — ele **não executa** nada. Para rodar o SQL gerado, passe o resultado de
`.AsString` a uma conexão do **DataEngine** (`IDBConnection`)
(`delphi-fluentsql-specialist.md:18`).

```
FluentSQL.Query(dbnFirebird)   ─▶  builder IFluentSQL  ─▶  AST (IFluentSQLAST)
        │                                │                        │
   escolhe o dialeto            encadeia Select/From/...    serializador por dialeto
   (TFluentSQLDriver)            operadores/funções          (FluentSQL.Serialize*)
                                         │                        │
                                    .AsString  ◀──────────────────┘
                                         │
                                 string SQL/MQL pronta
                                         │
                            DataEngine (IDBConnection) → Banco
```

O ponto de entrada é a função de unit **`FluentSQL.Query(ADatabase): IFluentSQL`**
(`Source/Core/FluentSQL.pas:235,282-286`). `TCQ` e `CreateFluentSQL` são
**`deprecated` — use `FluentSQL.Query`** (`Source/Core/FluentSQL.pas:238,240`).

## Relação com o Janus

O **Janus referencia `FluentSQL.Query` internamente** (substituiu o `TCQ`
deprecado) — `delphi-fluentsql-specialist.md:17`; o `deprecated 'Use
''FluentSQL.Query'' instead'` em `Source/Core/FluentSQL.pas:238` confirma o
caminho. Divisão de trabalho no ecossistema do dono: **Janus** faz o CRUD
automático de entidades mapeadas; **FluentSQL** é o caminho para **SQL avulso**
(relatórios, filtros ad-hoc, DDL) que foge do CRUD gerado
(`delphi-fluentsql-specialist.md:7`).

## Camadas do Source (para investigar)

- **Contrato** (`Source/Core/FluentSQL.Interfaces.pas`): `IFluentSQL` (o builder,
  linhas 170-317), `IFluentSQLFunctions` (funções, 780-819), `IFluentSQLOperators`
  (631-683), a enum de drivers `TFluentSQLDriver` (31-33) e as estruturas de
  seção (Select/Where/Join/OrderBy/Insert/Update/Delete/Merge).
- **Builder** (`Source/Core/FluentSQL.pas`): `TFluentSQL` implementa `IFluentSQL`;
  seções em `TSection` (48-57); joins em `_CreateJoin` (685-698).
- **Seções** (`Source/Core`): `FluentSQL.Select.pas`, `FluentSQL.Where.pas`,
  `FluentSQL.Joins.pas`, `FluentSQL.OrderBy.pas`, `FluentSQL.Insert.pas`,
  `FluentSQL.Update.pas`, `FluentSQL.Delete.pas`, `FluentSQL.Cases.pas`,
  `FluentSQL.Functions.pas`, `FluentSQL.Operators.pas`, `FluentSQL.Params.pas`.
- **Qualificadores por dialeto** (`Source/Drivers`): `FluentSQL.Qualifier<DB>.pas`
  e `FluentSQL.Select.<DB>.pas` / `FluentSQL.Serialize<DB>.pas` — um por banco
  (Firebird, MSSQL, MySQL, Oracle, PostgreSQL, SQLite, Interbase, DB2, MongoDB…).
  Ver [dialects.md](dialects.md).

## Fontes da verdade (estude ANTES de afirmar)

1. **Testes do próprio framework** — `.modules\FluentSQL\Test Delphi`, um diretório
   por dialeto (`Firebird_tests`, `MSSQL_tests`, `Oracle_tests`, `MySQL_tests`,
   `PostgreSQL_tests`, `SQLite_tests`, `MongoDB_tests`, …). Cada teste DUnitX traz
   a **cadeia fluente + a SQL exata esperada** — é a referência de uso correto.
2. **Source do framework** — `.modules\FluentSQL\Source` (Core + Drivers).
3. **Especialista curado** — `delphi-fluentsql-specialist.md` (errata de campo).

## Quando usar

- Precisa de **SQL avulso/ad-hoc** que o CRUD do Janus não gera (relatórios,
  filtros dinâmicos, agregações, subqueries) — `delphi-fluentsql-specialist.md:7`.
- Quer o **mesmo código** gerando SQL para bancos diferentes trocando só o driver.
- Precisa de paginação portável (FIRST/SKIP vs. LIMIT/OFFSET vs. ROW_NUMBER vs.
  ROWNUM) sem escrever cada dialeto à mão. Ver [joins-paging.md](joins-paging.md).

## Quando NÃO usar / limites

- **Não executa** SQL — só gera a string. A execução é do DataEngine
  (`delphi-fluentsql-specialist.md:18`).
- CRUD de entidade mapeada → **Janus** (FluentSQL é para o SQL que foge do CRUD).
- Filtros executados via `IDBConnection.CreateDataSet` (SQL cru, sem bind de
  parâmetro) exigem cuidado: operadores tipados podem emitir `:pN`. Ver
  [rules.md](rules.md).

## Citations

- `Source/Core/FluentSQL.Interfaces.pas:2-11` — cabeçalho/licença MIT, autor.
- `Source/Core/FluentSQL.pas:235,282-286` — `FluentSQL.Query` (entrada canônica).
- `Source/Core/FluentSQL.pas:238,240,293-299` — `TCQ`/`CreateFluentSQL` deprecados.
- `Source/Core/FluentSQL.Interfaces.pas:31-33` — enum `TFluentSQLDriver`.
- `delphi-fluentsql-specialist.md:7,17,18` — SQL avulso, relação com Janus, execução via DataEngine.
