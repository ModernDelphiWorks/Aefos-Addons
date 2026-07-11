---
type: API Reference
title: FluentSQL — Joins & Paginação por Dialeto
description: Joins (InnerJoin/LeftJoin/RightJoin/FullJoin + OnCond) e paginação First/Skip renderizada por dialeto — FIRST/SKIP (Firebird), LIMIT/OFFSET (MySQL), ROW_NUMBER (MSSQL), ROWNUM (Oracle). Com a SQL exata dos testes.
tags: [fluentsql, sql, delphi, join, paging, pagination, dialect]
timestamp: 2026-07-11T00:00:00Z
---

# Joins & Paginação por Dialeto

## Joins

O builder oferece `InnerJoin` · `LeftJoin` · `RightJoin` · `FullJoin`, cada um com
sobrecarga `(table)` e `(table, alias)` (`Source/Core/FluentSQL.Interfaces.pas:213-220`).
A condição de junção vem em seguida por **`OnCond(...)`**.

```pascal
FluentSQL.Query(dbnFirebird)
  .Select.All
  .From('CLIENTES', 'C')
  .InnerJoin('PEDIDOS', 'P')
  .OnCond('P.IDCLIENTE = C.ID_CLIENTE')
  .AsString;
// → ... INNER JOIN PEDIDOS AS P ON (P.IDCLIENTE = C.ID_CLIENTE)
```

Fundamentação de serialização (o formato é
`<TIPO> JOIN <tabela> ON <condição>`):
`Source/Core/FluentSQL.Joins.pas:184-202` (`SerializeJoinType` mapeia
`jtINNER/jtLEFT/jtRIGHT/jtFULL` → `INNER/LEFT/RIGHT/FULL`). `OnCond` roteia para a
expressão da junção ativa via `AndOpe` (`Source/Core/FluentSQL.pas:407-409`), e
`_CreateJoin` cria a junção e aponta a expressão de condição
(`Source/Core/FluentSQL.pas:685-698`). `InnerJoin(table, alias)` chama
`InnerJoin(table).Alias(alias)` (`:976-980`).

> ⚠️ **TODO / confirmar empiricamente:** existem testes DUnitX de join para
> **MongoDB** (`$lookup`/`$unwind`) em `Test Delphi/MongoDB_tests/test.dml.mongodb.pas:211-276`,
> mas **não há teste asserindo o join RELACIONAL** `INNER JOIN … ON …` (o exemplo
> acima é derivado do Source, não asserido). A **string SQL exata** (incl.
> parênteses da condição e posição do alias) deve ser confirmada rodando um caso
> real. Pedir à equipe do FluentSQL: um teste `test.joins.*` relacional com a SQL
> esperada por dialeto.

## Paginação — `First(n)` / `Skip(n)` renderizada por dialeto

O **mesmo** `.First(n).Skip(n)` gera SQL diferente conforme o driver — é o valor
central do FluentSQL. Todas as strings abaixo são asseridas em
`Test Delphi/Firebird_tests/test.select.firebird.pas`:

| Dialeto | Cadeia | SQL gerada | Fonte |
|---|---|---|---|
| **Firebird** | `.First(3).Skip(0)` | `SELECT FIRST 3 SKIP 0 * FROM CLIENTES AS CLI ORDER BY CLI.ID_CLIENTE` | `:195-208` |
| **Firebird + Distinct** | `.Distinct.Column(...).First(3).Skip(0)` | `SELECT DISTINCT FIRST 3 SKIP 0 CLI.ID_CLIENTE FROM …` | `:210-224` |
| **MySQL** | `.First(3).Skip(0)` | `… ORDER BY ID_CLIENTE LIMIT 3 OFFSET 0` | `:240-252` |
| **Oracle** | `.First(3).Skip(0)` | `SELECT * FROM (SELECT T.*, ROWNUM AS ROWINI FROM (… ORDER BY ID_CLIENTE) T) WHERE ROWNUM <= 3 AND ROWINI > 0` | `:254-266` |
| **MSSQL** | `.First(3).Skip(3)` | `SELECT * FROM (SELECT *, ROW_NUMBER() OVER(ORDER BY CURRENT_TIMESTAMP) AS ROWNUMBER FROM CLIENTES) AS CLIENTES WHERE (ROWNUMBER > 3 AND ROWNUMBER <= 6) ORDER BY ID_CLIENTE` | `:226-238` |

Observações:
- **A ordem `First`/`Skip` no encadeamento não importa** para o resultado — o
  teste Firebird escreve `.First(3).Skip(0)` e o MSSQL `.Skip(0).First(3)` e ambos
  paginam corretamente (`:76-79,204`).
- **MSSQL projetando colunas** encaixa a coluna dentro do `ROW_NUMBER()` subquery
  (`Test2SelectPagingMSSQL`, `:63-79`).
- `Distinct` sai **antes** de `FIRST/SKIP` no Firebird (`:214`).

`First`/`Skip` são do contrato `IFluentSQL` (`Interfaces.pas:234,241`); a lógica
de paginação por dialeto vive nos qualificadores/serializadores
(`Source/Drivers/FluentSQL.Select.<DB>.pas`, `FluentSQL.Qualifier<DB>.pas`).

## Citations

- `Test Delphi/Firebird_tests/test.select.firebird.pas:63-79,195-266` — paginação por dialeto (FB/MSSQL/Oracle/MySQL).
- `Source/Core/FluentSQL.Interfaces.pas:213-220,234,241` — joins e First/Skip no contrato.
- `Source/Core/FluentSQL.Joins.pas:184-202` — serialização `<TIPO> JOIN … ON …`.
- `Source/Core/FluentSQL.pas:407-409,685-698,976-980` — `OnCond`, `_CreateJoin`, `InnerJoin(table, alias)`.
