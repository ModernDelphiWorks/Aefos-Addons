---
type: API Reference
title: FluentSQL — SELECT (colunas, WHERE, operadores, CASE, funções, subqueries)
description: Como montar SELECT com FluentSQL — projeção, From, WHERE com operadores tipados vs. fragmento raw, AndOpe/OrOpe, CASE WHEN, funções, GROUP BY/HAVING/ORDER BY e IN/EXISTS com subquery. Cada forma com a SQL exata dos testes.
tags: [fluentsql, sql, delphi, select, where, operators, case, subquery]
timestamp: 2026-07-11T00:00:00Z
---

# SELECT

Todas as SQLs abaixo são as **strings exatas** asseridas nos testes DUnitX
(`Test Delphi/Firebird_tests`). A cadeia começa em `FluentSQL.Query(dbn...)`.

## Projeção — `All`, `Column`, `Distinct`, `Alias`

```pascal
// SELECT * FROM CLIENTES AS CLI
FluentSQL.Query(dbnFirebird).Select.All.From('CLIENTES').Alias('CLI').AsString;

// SELECT ID_CLIENTE, NOME_CLIENTE FROM CLIENTES
FluentSQL.Query(dbnFirebird).Select
  .Column('ID_CLIENTE').Column('NOME_CLIENTE').From('CLIENTES').AsString;
```
Fontes: `test.select.firebird.pas:82-92,162-173`. `Column` tem 4 sobrecargas
(nome; `tabela, nome`; `array of const`; `CaseExpr`) — `Interfaces.pas:196-199`.
`Distinct` prefixa a projeção (ver [joins-paging.md](joins-paging.md) para
`DISTINCT` + paginação).

## `From` — tabela, alias e subquery

`From` aceita `table`, `table, alias`, uma **subquery `IFluentSQL`** e uma
expressão (`Interfaces.pas:205-208`). Alias também via `.Alias('X')` logo após o
`From` (`test.select.firebird.pas:90`).

## WHERE — duas formas (a distinção é CRÍTICA)

**Forma A — fragmento raw** (string literal, **não parametriza**):
```pascal
// SELECT * FROM CLIENTES WHERE ID_CLIENTE = 1
FluentSQL.Query(dbnFirebird).Select.All.From('CLIENTES')
  .Where('ID_CLIENTE = 1').AsString;
```
Fonte: `test.select.firebird.pas:119-130`.

**Forma B — coluna + operador tipado** (encadeia a comparação):
```pascal
// SELECT * FROM CLIENTES WHERE (VALOR = 10)
FluentSQL.Query(dbnFirebird).Select.All.From('CLIENTES')
  .Where('VALOR').Equal(10).AsString;

// SELECT * FROM CLIENTES WHERE (NOME = 'VALUE')
...Where('NOME').Equal('''VALUE''').AsString;
```
Fontes: `test.operators.equal.firebird.pas:100-124`. Note que a forma B **envolve
a condição em parênteses**. Overloads de `Equal`: `String/Extended/Integer/TDate/
TDateTime/TGUID` (`Interfaces.pas:242-247`); datas viram `'MM/DD/YYYY'` /
`'MM/DD/YYYY HH:NN:SS'` (`test.operators.equal.firebird.pas:57-85`).

> ⚠️ **A forma B pode emitir `:pN` (parâmetro), não valor inline**, dependendo do
> contexto/versão — em `test.core.params.pas:361-362`, `.Where('ID').Equal(1)`
> gera `WHERE (ID = :p1)`. Para SQL executada via `IDBConnection.CreateDataSet`
> (roda SQL cru, **sem** bind de `:pN`), isso quebra o filtro — use a **forma A**
> (fragmento raw). É a errata de campo mais cara: ver [rules.md](rules.md).

### Operadores disponíveis (após uma coluna)

`Interfaces.pas:242-291`:
`Equal · NotEqual · GreaterThan · GreaterEqThan · LessThan · LessEqThan · IsNull ·
IsNotNull · Like · LikeFull · LikeLeft · LikeRight · NotLike · NotLikeFull ·
NotLikeLeft · NotLikeRight · InValues · NotIn · Exists · NotExists`.

**LIKE** (semântica dos afixos, `test.operators.like.firebird.pas`):
- `.LikeFull('VALUE')` → `LIKE '%VALUE%'` (:49-59)
- `.LikeLeft('VALUE')` → `LIKE '%VALUE'` (:62-73)
- `.LikeRight('VALUE')` → `LIKE 'VALUE%'` (:75-86)
- `NotLike*` → `NOT LIKE …` (:88-125)

> ⚠️ **NÃO existe operador `Between`** no builder — `fcBetween`/`fcNotBetween`
> existem no enum `TFluentSQLOperatorCompare` (`Interfaces.pas:604`) e até
> serializam para `'between'`/`'not between'` (`FluentSQL.Operators.pas:239-240`),
> mas **nenhum método público em `IFluentSQL`/`IFluentSQLOperators` os expõe**.
> Para `col BETWEEN a AND b`, use a forma A (fragmento raw). Ver [rules.md](rules.md).

## Encadeando condições — `AndOpe` / `OrOpe`

```pascal
// SELECT * FROM CLIENTES WHERE (ID_CLIENTE = 1) AND (ID >= 10) AND (ID <= 20)
FluentSQL.Query(dbnFirebird).Select.All.From('CLIENTES')
  .Where('ID_CLIENTE = 1')
  .AndOpe('ID').GreaterEqThan(10)
  .AndOpe('ID').LessEqThan(20)
  .AsString;

// SELECT * FROM CLIENTES WHERE (ID_CLIENTE = 1) AND ((ID >= 10) OR (ID <= 20))
...Where('ID_CLIENTE = 1')
  .AndOpe('ID').GreaterEqThan(10)
  .OrOpe('ID').LessEqThan(20)
  .AsString;
```
Fonte: `test.select.firebird.pas:132-160`. O agrupamento por parênteses sai da
árvore de expressão (`AndOpe`/`OrOpe` — `Interfaces.pas:172-183`).

## `IN` / `NOT IN` — lista e subquery

```pascal
// lista (parametrizada): WHERE (VALOR IN (:p1, :p2, :p3))
...Where('VALOR').InValues([1, 2, 3]).AsString;
...Where('VALOR').InValues(['VALUE.1', 'VALUE,2', 'VALUE3']).AsString;

// subquery: WHERE (ID IN (SELECT IDCLIENTE FROM PEDIDOS))
...Where('ID').InValues(FluentSQL.Query(dbnFirebird)
                          .Select.Column('IDCLIENTE').From('PEDIDOS').AsString)
   .AsString;
```
Fonte: `test.operators.isin.firebird.pas:51-159`. `InValues(TArray<Double>)` e
`InValues(TArray<String>)` geram `:pN`; a sobrecarga `InValues(String)` embute o
fragmento (a subquery) cru. `NotIn` é análogo.

## `EXISTS` / `NOT EXISTS` — subquery correlacionada

```pascal
// WHERE (EXISTS (SELECT IDCLIENTE FROM PEDIDOS WHERE (PEDIDOS.IDCLIENTE = CLIENTES.IDCLIENTE)))
...Where.Exists(FluentSQL.Query(dbnFirebird)
                  .Select.Column('IDCLIENTE').From('PEDIDOS')
                  .Where('PEDIDOS.IDCLIENTE').Equal('CLIENTES.IDCLIENTE').AsString)
   .AsString;
```
Fonte: `test.operators.exists.firebird.pas:38-72`. Note `.Where.Exists(...)` (o
`Where` sem argumento abre a seção; `Exists`/`NotExists` recebem a subquery como
string). `Interfaces.pas:290-291`.

## Funções na projeção e no WHERE

```pascal
// SELECT COUNT(ID_CLIENTE) AS IDCOUNT FROM CLIENTES
...Select.Column('ID_CLIENTE').Count.Alias('IDCOUNT').From('CLIENTES').AsString;
// UPPER / LOWER / MIN / MAX análogos
...Column('NOME_CLIENTE').Upper.Alias('NOME')...
// SUBString(NOME_CLIENTE FROM 1 FOR 2)
...Column('NOME_CLIENTE').SubString(1, 2).Alias('NOME')...
// EXTRACT(YEAR FROM NASCTO)  — projeção
...Select.Column.Year('NASCTO').From('CLIENTES').AsString;
// EXTRACT(MONTH FROM NASCTO) = 9  — no WHERE
...Where.Month('NASCTO').Equal('9')...
// '-' || NOME  — concatenação (Firebird)
...Select.Column.Concat(['''-''', 'NOME'])...
```
Fonte: `test.functions.firebird.pas:66-255`. Funções do builder:
`Count/Lower/Upper/Min/Max/SubString/Date/Day/Month/Year/Concat`
(`Interfaces.pas:293-303`). Para `Sum`/`Average` (fora do builder) use
`.AsFun.Sum('col')` — ver [api.md](api.md) e [rules.md](rules.md).

## `CASE WHEN`

```pascal
// (CASE TIPO_CLIENTE WHEN 0 THEN 'FISICA' WHEN 1 THEN 'JURIDICA' ELSE 'PRODUTOR' END) AS TIPO_PESSOA
...Select.Column('ID_CLIENTE').Column('NOME_CLIENTE').Column('TIPO_CLIENTE')
   .CaseExpr
     .When('0').IfThen(TFluentSQLFunctions.QFunc('FISICA'))
     .When('1').IfThen(TFluentSQLFunctions.QFunc('JURIDICA'))
               .ElseIf('''PRODUTOR''')
   .EndCase
   .Alias('TIPO_PESSOA')
   .From('CLIENTES').AsString;
```
Fonte: `test.select.firebird.pas:175-193`. `QFunc('X')` adiciona aspas → `'X'`.
Cadeia de CASE em `IFluentSQLCriteriaCase` (`Interfaces.pas:149-168`):
`When → IfThen → ElseIf → EndCase`.

## `ORDER BY`

```pascal
// SELECT * FROM CLIENTES ORDER BY ID_CLIENTE
...From('CLIENTES').OrderBy('ID_CLIENTE').AsString;
```
Fonte: `test.select.firebird.pas:106-117`. `Desc` inverte a direção
(`Interfaces.pas:201`).

## Citations

- `Test Delphi/Firebird_tests/test.select.firebird.pas:82-193` — projeção, WHERE, AndOpe/OrOpe, CASE, ORDER BY.
- `Test Delphi/Firebird_tests/test.operators.equal.firebird.pas:57-193` — Equal/NotEqual por tipo.
- `Test Delphi/Firebird_tests/test.operators.like.firebird.pas:49-125` — LIKE afixos.
- `Test Delphi/Firebird_tests/test.operators.isin.firebird.pas:51-159` — IN lista/subquery.
- `Test Delphi/Firebird_tests/test.operators.exists.firebird.pas:38-72` — EXISTS.
- `Test Delphi/Firebird_tests/test.functions.firebird.pas:66-255` — funções.
- `Source/Core/FluentSQL.Interfaces.pas:242-303,604` — operadores/funções; `fcBetween`/`fcNotBetween` no enum mas sem método público (só via raw).
- `Test Delphi/Common_tests/test.core.params.pas:361-362` — Equal(1) → `:p1`.
