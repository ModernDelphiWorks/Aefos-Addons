---
type: API Reference
title: FluentSQL — Referência Técnica
description: Ponto de entrada FluentSQL.Query, o contrato IFluentSQL (builder), IFluentSQLFunctions, a enum de drivers e os terminais AsString/Params — transcritos do Source com file:line.
tags: [fluentsql, sql, delphi, api, builder, functions, dialect]
timestamp: 2026-07-11T00:00:00Z
---

# FluentSQL — Referência Técnica

Tudo aqui é transcrito de `.modules\FluentSQL\Source` e `.modules\FluentSQL\Test
Delphi`. O contrato completo está em `Source/Core/FluentSQL.Interfaces.pas`.

## Schema — ponto de entrada

```pascal
uses FluentSQL, FluentSQL.Interfaces;   // FluentSQL.Interfaces expõe dbn* e IFluentSQL

function Query(const ADatabase: TFluentSQLDriver): IFluentSQL;   // canônico
function Func (const ADatabase: TFluentSQLDriver): IFluentSQLFunctions;  // funções avulsas
function Schema(const ADatabase: TFluentSQLDriver): IFluentSchema;       // DDL de schema
function TCQ (const ADatabase: TFluentSQLDriver): IFluentSQL; deprecated;         // NÃO usar
function CreateFluentSQL(const ADatabase: TFluentSQLDriver): IFluentSQL; deprecated; // NÃO usar
```
Fonte: `Source/Core/FluentSQL.pas:235-242`. Corpo de `Query` em `:282-286`. Um
default global pode ser fixado com `TFluentSQL.SetDatabaseDafault(dbn...)`
(`Source/Core/FluentSQL.pas:88,501`; usado em
`Test Delphi/Firebird_tests/test.select.firebird.pas:200,215`) — note o nome
**`SetDatabaseDafault`** (grafia do framework).

Uso típico (todos os testes seguem este formato):
```pascal
LSql := FluentSQL.Query(dbnFirebird)
          .Select
          .All
          .From('CLIENTES')
          .AsString;                 // 'SELECT * FROM CLIENTES'
```
Fonte: `Test Delphi/Firebird_tests/test.select.firebird.pas:82-92`.

## Schema — drivers (dialetos)

```pascal
TFluentSQLDriver = (dbnMSSQL, dbnMySQL, dbnFirebird, dbnSQLite, dbnInterbase,
  dbnDB2, dbnOracle, dbnInformix, dbnPostgreSQL, dbnADS, dbnASA, dbnAbsoluteDB,
  dbnMongoDB, dbnElevateDB, dbnNexusDB);
```
Fonte: `Source/Core/FluentSQL.Interfaces.pas:31-33`. O driver passado a
`FluentSQL.Query` escolhe o serializador; o mesmo encadeamento gera SQL diferente
por banco (ver [joins-paging.md](joins-paging.md) e [dialects.md](dialects.md)).

## Schema — o builder `IFluentSQL`

`Source/Core/FluentSQL.Interfaces.pas:170-317`. Grupos de métodos (a lista canônica
com as sobrecargas exatas está no Source):

- **Comando:** `Select` · `Delete` · `Insert` · `Update(table)` · `Merge`
  (`:200,221,227,235,304`).
- **Colunas/projeção:** `All` · `Column(...)` (4 sobrecargas: nome; tabela+nome;
  `array of const`; `CaseExpr`) · `Distinct` · `Alias(a)` (`:193,196-199,175,202`).
- **Origem:** `From(...)` (4 sobrecargas: expressão; **subquery `IFluentSQL`**;
  `table`; `table, alias`) · `Into(table)` (`:205-208,223`).
- **Junções:** `InnerJoin/LeftJoin/RightJoin/FullJoin(table[, alias])` · `OnCond(...)`
  (`:213-220,179-180`). Ver [joins-paging.md](joins-paging.md).
- **Filtro:** `Where(...)` (string; `array of const`; `IFluentSQLCriteriaExpression`)
  · `AndOpe(...)` · `OrOpe(...)` (`:236-238,172-183`).
- **Operadores tipados** (encadeados após uma coluna): `Equal/NotEqual`,
  `GreaterThan/GreaterEqThan/LessThan/LessEqThan`, `IsNull/IsNotNull`,
  `Like/LikeFull/LikeLeft/LikeRight` (+ `NotLike*`), `InValues/NotIn`,
  `Exists/NotExists` (`:242-291`). Ver [select.md](select.md).
- **Agrupamento/ordem:** `GroupBy([col])` · `Having(...)` · `OrderBy([col])` ·
  `Desc` (`:209-212,225-226,201`).
- **Paginação:** `First(n)` · `Skip(n)` (`:234,241`). Ver [joins-paging.md](joins-paging.md).
- **Conjunto:** `Union` · `UnionAll` · `Intersect` (`:231-233`).
- **Funções no builder:** `Count · Lower · Min · Max · Upper · SubString(start,len)
  · Date · Day · Month · Year · Concat([...])` (`:293-303`). **`Sum` e `Average`
  NÃO estão aqui** — ver abaixo e [rules.md](rules.md).
- **CASE:** `CaseExpr(...)` → `IFluentSQLCriteriaCase` (`:176-178`). Ver
  [select.md](select.md).
- **Valores (DML):** `SetValue(...)` (9 sobrecargas) · `Values(...)` · `AddRow`
  (`:184-192,239-240,222`). Ver [dml.md](dml.md).
- **Dialeto-only:** `ForDialectOnly(dialect, sql)` / `ForDialectOnly(dialect,
  array of const)` (`:306-308`). Ver [dialects.md](dialects.md).
- **Cache (opcional, ESP-032):** `WithCache(provider)` · `WithTTL(seconds)`
  (`:310-312`).
- **Terminais:** `AsString: String` (renderiza) · `Params: IFluentSQLParams`
  (parâmetros coletados) · `AsFun: IFluentSQLFunctions` (`:314-316`).

## Schema — funções (`IFluentSQLFunctions`)

`Source/Core/FluentSQL.Interfaces.pas:780-819`. Retornam a **string raw** da função
(ex.: `'SUM(salary)'`), para compor com `Column`/`Where`:

```pascal
// Agregação
Count · Sum · Min · Max · Average
// String
Upper · Lower · Length · Trim · LTrim · RTrim · SubString(v, from, for) · Concat([...])
// Nulo / conversão
Coalesce([...]) · Cast(expr, type)
// Data
Date(v[, fmt]) · Day · Month · Year · CurrentDate · CurrentTimestamp
// Numérico
Round(v, dec) · Floor · Ceil · Modulus(v, div) · Abs
```

Duas formas de acesso:
- **`Func(dbn...)`** — objeto de funções avulso (`Source/Core/FluentSQL.pas:242,277-280`).
- **`.AsFun`** — sobre uma query já em construção (`Interfaces.pas:314`).

`Sum`/`Average` (ausentes no builder) obtêm-se assim:
```pascal
LSQL := FluentSQL.Query(dbnMongoDB);
LSQL.Select('department')
    .Column(LSQL.AsFun.Sum('salary')).Alias('total_salary')
    .Column(LSQL.AsFun.Average('salary')).Alias('avg_salary')
    ...
```
Fonte: `Test Delphi/MongoDB_tests/test.dml.mongodb.pas:92-101`. (`Min`/`Max`
existem nas DUAS interfaces; ali usam `.Column('salary').Min` do builder.)

## Terminais e parâmetros

- **`AsString`** materializa a SQL/MQL final (todo teste termina em `.AsString`).
- **`Params`** devolve `IFluentSQLParams` — os valores vinculados a `:pN` quando a
  serialização parametriza (`Interfaces.pas:65-72,316`;
  `Test Delphi/Common_tests/test.core.params.pas:335-337,362-365`). Ver a errata de
  parametrização em [rules.md](rules.md).

## Citations

- `Source/Core/FluentSQL.pas:88,235-242,282-286,293-299,501` — entrada, `Func`, `Schema`, deprecados, default.
- `Source/Core/FluentSQL.Interfaces.pas:31-33` — `TFluentSQLDriver`.
- `Source/Core/FluentSQL.Interfaces.pas:170-317` — `IFluentSQL` (builder).
- `Source/Core/FluentSQL.Interfaces.pas:780-819` — `IFluentSQLFunctions`.
- `Test Delphi/Firebird_tests/test.select.firebird.pas:82-92,200,215` — uso base + default.
- `Test Delphi/MongoDB_tests/test.dml.mongodb.pas:92-101` — `AsFun.Sum/Average`.
- `Test Delphi/Common_tests/test.core.params.pas:335-337,362-365` — `Params`.
