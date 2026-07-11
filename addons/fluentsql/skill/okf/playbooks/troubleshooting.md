---
type: Playbook
title: FluentSQL — Troubleshooting
description: Diagnóstico e correção dos erros mais caros do FluentSQL — :pN não-vinculado ao executar via CreateDataSet, Between/Sum inexistentes no builder, dialeto errado na paginação e LIKE invertido.
tags: [fluentsql, sql, delphi, troubleshooting, debug, parametrization]
timestamp: 2026-07-11T00:00:00Z
---

# Troubleshooting

Sintoma → causa-raiz → fix, com a fonte. Regras completas em [../rules.md](../rules.md).

## Filtro vazio / erro de parâmetro ao executar via `IDBConnection.CreateDataSet`

- **Causa-raiz:** o operador tipado gerou `:p1` (ex.: `.Where('col').Equal('x')` →
  `col = :p1`) e o `CreateDataSet` roda SQL cru **sem** vincular parâmetro → o
  `:p1` fica solto.
- **Onde ver:** `.InValues([1,2,3])` → `IN (:p1, :p2, :p3)`
  (`test.operators.isin.firebird.pas:64-75`); `.Equal(1)` → `(ID = :p1)` no
  contexto de parâmetros (`test.core.params.pas:361-362`).
- **Fix:** condição de valor como **fragmento raw** — `.Where('col = ' +
  QuotedStr(v))` / `.AndOpe('col = ' + QuotedStr(v))`; `.Where(rawPredicate)` não
  parametriza (`test.select.firebird.pas:119-130`).
- **Caso real:** ABC_DAO (DFeFw 2026-06-21). Fonte:
  `delphi-fluentsql-specialist.md:24`. Ver Regra 1 em [../rules.md](../rules.md).
- **Sempre:** inspecione o `.AsString` gerado antes de culpar o banco — inline
  vs. `:pN` varia por tipo/contexto/versão.

## "`.Sum` / `.Average` não compila no builder"

- **Causa-raiz:** não existem em `IFluentSQL`; só em `IFluentSQLFunctions`
  (`Source/Core/FluentSQL.Interfaces.pas:293-303` vs. `:786-787`).
- **Fix:** `LQuery.AsFun.Sum('col')` (ou `Func(dbn...).Sum('col')`) devolve
  `'SUM(col)'`; use com `.Column(<raw>).Alias('x')`
  (`test.dml.mongodb.pas:92-101`). Ver Regra 2.

## "`.Between` não existe"

- **Correto** — não existe operador `Between` público; `fcBetween`/`fcNotBetween`
  existem no enum (`Interfaces.pas:604`) e serializam para `'between'`/`'not between'`
  (`FluentSQL.Operators.pas:239-240`), mas nenhum método de `IFluentSQL`/`IFluentSQLOperators` os expõe.
- **Fix:** fragmento raw em `.Where(...)`/`.AndOpe(...)` para `col BETWEEN a AND b`.
  Fonte: `delphi-fluentsql-specialist.md:23`. Ver Regra 3.

## Paginação saiu na sintaxe do banco errado

- **Causa-raiz:** driver errado em `FluentSQL.Query(dbn...)`. Firebird usa
  `FIRST/SKIP`, MySQL `LIMIT/OFFSET`, MSSQL `ROW_NUMBER()`, Oracle `ROWNUM` — o
  **mesmo** `First/Skip` gera cada um conforme o driver
  (`test.select.firebird.pas:195-266`).
- **Fix:** passe o dialeto do banco alvo. Para Firebird vivo, `dbnFirebird`
  (`delphi-fluentsql-specialist.md:21`). Tabela em [../joins-paging.md](../joins-paging.md).

## `LIKE` casou o lado errado

- **Causa-raiz:** confundir `LikeLeft`/`LikeRight`. `.LikeLeft('V')` → `'%V'`
  (termina com V); `.LikeRight('V')` → `'V%'` (começa com V); `.LikeFull('V')` →
  `'%V%'` (`test.operators.like.firebird.pas:49-86`). Ver Regra 5.

## `dbnMongoDB` gerou `Find( {} )` em vez de SQL

- **Não é bug:** com `dbnMongoDB` o alvo é **MQL**, não SQL
  (`test.select.firebird.pas:94-104`; agregações `$group/$sum` em
  `test.dml.mongodb.pas:73-107`). Use um driver relacional se quer SQL. Ver
  [../dialects.md](../dialects.md).

## Citations

- `delphi-fluentsql-specialist.md:21,23,24` — erratas de campo.
- `Test Delphi/Firebird_tests/test.operators.isin.firebird.pas:64-75`; `test.select.firebird.pas:119-130,94-104,195-266`.
- `Test Delphi/Common_tests/test.core.params.pas:361-362`.
- `Test Delphi/MongoDB_tests/test.dml.mongodb.pas:73-107`.
- `Source/Core/FluentSQL.Interfaces.pas:293-303,604,786-787`.
