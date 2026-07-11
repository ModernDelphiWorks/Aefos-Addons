---
type: Playbook
title: FluentSQL — Quickstart
description: Do FluentSQL.Query(dbn...) a um SELECT paginado por dialeto, WHERE seguro e INSERT/UPDATE/DELETE, com execução via DataEngine. Cada passo cita a fonte.
tags: [fluentsql, sql, delphi, quickstart, select, dml, paging]
timestamp: 2026-07-11T00:00:00Z
---

# Quickstart — do builder à SQL executada

Baseado em `.modules\FluentSQL\Test Delphi` (uso correto, com a SQL esperada) e no
Source. Cada passo cita a fonte.

## 1. Abra uma query no dialeto do banco

```pascal
uses FluentSQL, FluentSQL.Interfaces;   // dbn* e IFluentSQL vêm de FluentSQL.Interfaces

LSql := FluentSQL.Query(dbnFirebird)     // TCQ/CreateFluentSQL são deprecated
          .Select.All.From('CLIENTES')
          .AsString;                     // 'SELECT * FROM CLIENTES'
```
Fonte: `Test Delphi/Firebird_tests/test.select.firebird.pas:82-92`;
`Source/Core/FluentSQL.pas:235,282-286` (entrada), `:238,240` (deprecados).
Drivers disponíveis em [../dialects.md](../dialects.md).

## 2. Projete colunas, funções e CASE

```pascal
// SELECT COUNT(ID_CLIENTE) AS IDCOUNT FROM CLIENTES
FluentSQL.Query(dbnFirebird).Select
  .Column('ID_CLIENTE').Count.Alias('IDCOUNT').From('CLIENTES').AsString;
```
Para `SUM`/`AVG` (fora do builder) use `.AsFun.Sum('col')` — [../rules.md](../rules.md)
Regra 2. Funções e CASE em [../select.md](../select.md).

## 3. Monte o WHERE — escolha a forma certa

```pascal
// Forma A (raw, NÃO parametriza) — use para SQL executada via CreateDataSet
...From('CLIENTES').Where('ID_CLIENTE = 1').AsString;
//                   → WHERE ID_CLIENTE = 1

// Forma B (operador tipado) — pode emitir :pN
...From('CLIENTES').Where('VALOR').Equal(10).AsString;
//                   → WHERE (VALOR = 10)   (mas veja a nuance :pN)
```
Fontes: `test.select.firebird.pas:119-130`,
`test.operators.equal.firebird.pas:100-124`. **Encadeie** com
`.AndOpe(...)`/`.OrOpe(...)`; use `IN`/`EXISTS` com subquery. Tudo em
[../select.md](../select.md). ⚠️ Regra 1 em [../rules.md](../rules.md): para
execução sem bind, prefira a forma A.

## 4. Pagine por dialeto — o mesmo código, SQL diferente

```pascal
// Firebird → SELECT FIRST 3 SKIP 0 * FROM CLIENTES AS CLI ORDER BY CLI.ID_CLIENTE
FluentSQL.Query(dbnFirebird).Select.All.First(3).Skip(0)
  .From('CLIENTES', 'CLI').OrderBy('CLI.ID_CLIENTE').AsString;

// MySQL → … ORDER BY ID_CLIENTE LIMIT 3 OFFSET 0
FluentSQL.Query(dbnMySQL).Select.All.First(3).Skip(0)
  .From('CLIENTES').OrderBy('ID_CLIENTE').AsString;
```
Fonte: `test.select.firebird.pas:195-266`. Tabela completa (FB/MySQL/Oracle/MSSQL)
em [../joins-paging.md](../joins-paging.md).

## 5. INSERT / UPDATE / DELETE

```pascal
// INSERT INTO CLIENTES (ID_CLIENTE, NOME_CLIENTE) VALUES (1, 'MyName')
FluentSQL.Query(dbnFirebird).Insert.Into('CLIENTES')
  .SetValue('ID_CLIENTE', 1).SetValue('NOME_CLIENTE', 'MyName').AsString;

// UPDATE CLIENTES SET NOME_CLIENTE = 'MyName' WHERE ID_CLIENTE = 1
FluentSQL.Query(dbnFirebird).Update('CLIENTES')
  .SetValue('NOME_CLIENTE', 'MyName').Where('ID_CLIENTE = 1').AsString;

// DELETE FROM CLIENTES WHERE ID_CLIENTE = 1
FluentSQL.Query(dbnFirebird).Delete.From('CLIENTES').Where('ID_CLIENTE = 1').AsString;
```
Fontes: `test.insert.firebird.pas:38-49`, `test.update.firebird.pas:58-69`,
`test.delete.firebird.pas:40-61`. Sobrecargas e datas em [../dml.md](../dml.md).

## 6. Execute — via DataEngine

FluentSQL só gera a string. Passe `.AsString` a uma conexão do DataEngine
(`IDBConnection`) para executar (`delphi-fluentsql-specialist.md:18`). Ao usar
`IDBConnection.CreateDataSet` (SQL cru, sem bind), garanta WHERE em fragmento raw
(Regra 1).

## Checklist final

- [ ] Entrada por `FluentSQL.Query(dbn...)` (nunca `TCQ`/`CreateFluentSQL`).
- [ ] Dialeto = banco alvo (Firebird vivo → `dbnFirebird`).
- [ ] WHERE de valor executado via `CreateDataSet` = **fragmento raw** (Regra 1).
- [ ] `SUM`/`AVG` via `.AsFun` (Regra 2); `BETWEEN` via raw (Regra 3).
- [ ] Confira o `.AsString` gerado (inline vs. `:pN`) antes de executar.

## Citations

- `Test Delphi/Firebird_tests/test.select.firebird.pas:82-266`.
- `Test Delphi/Firebird_tests/test.operators.equal.firebird.pas:100-124`.
- `Test Delphi/Firebird_tests/test.insert.firebird.pas:38-49`; `test.update.firebird.pas:58-69`; `test.delete.firebird.pas:40-61`.
- `Source/Core/FluentSQL.pas:235,238,240,282-286`.
- `delphi-fluentsql-specialist.md:18`.
