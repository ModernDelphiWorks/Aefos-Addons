---
type: API Reference
title: FluentSQL — INSERT / UPDATE / DELETE
description: DML avulso com FluentSQL — INSERT (Into/SetValue/AddRow), UPDATE (Update/SetValue/Where) e DELETE (Delete/From/Where), com as sobrecargas de SetValue e a formatação de datas. SQL exata dos testes.
tags: [fluentsql, sql, delphi, insert, update, delete, dml]
timestamp: 2026-07-11T00:00:00Z
---

# INSERT / UPDATE / DELETE

Strings exatas dos testes DUnitX de Firebird.

## INSERT

```pascal
// INSERT INTO CLIENTES (ID_CLIENTE, NOME_CLIENTE) VALUES (1, 'MyName')
FluentSQL.Query(dbnFirebird)
  .Insert
  .Into('CLIENTES')
  .SetValue('ID_CLIENTE', 1)
  .SetValue('NOME_CLIENTE', 'MyName')
  .AsString;
```
Fonte: `Test Delphi/Firebird_tests/test.insert.firebird.pas:38-49`. A ordem é
`Insert → Into(table) → SetValue(col, val)…`. Cada `SetValue` acrescenta uma
coluna à lista de colunas e o valor à lista de valores.

**Multi-linha:** `AddRow` fecha a linha corrente e inicia outra
(`Interfaces.pas:222,529`); alternativa a `SetValue` é `Values(col, val)`
(`Interfaces.pas:239-240`).

## UPDATE

```pascal
// UPDATE CLIENTES SET ID_CLIENTE = 1, NOME_CLIENTE = 'MyName' WHERE ID_CLIENTE = 1
FluentSQL.Query(dbnFirebird)
  .Update('CLIENTES')
  .SetValue('ID_CLIENTE', 1)
  .SetValue('NOME_CLIENTE', 'MyName')
  .Where('ID_CLIENTE = 1')
  .AsString;
```
Fonte: `Test Delphi/Firebird_tests/test.update.firebird.pas:58-69`. `Update(table)`
recebe a tabela direto (`Interfaces.pas:235`); `Where` aceita fragmento raw (forma
A) como no SELECT — ver [select.md](select.md) e a errata em [rules.md](rules.md).

### Datas em `SetValue` (formatação)

```pascal
LDate     := EncodeDate(2021, 12, 31);
LDateTime := EncodeDate(2021, 12, 31) + EncodeTime(23, 59, 59, 0);
// … SET DATA_CADASTRO = '12/31/2021', DATA_ALTERACAO = '12/31/2021 23:59:59'
.SetValue('DATA_CADASTRO', LDate)
.SetValue('DATA_ALTERACAO', LDateTime)
```
Fonte: `test.update.firebird.pas:40-56`. `TDate` → `'MM/DD/YYYY'`; `TDateTime` →
`'MM/DD/YYYY HH:NN:SS'`. Note que aqui `SetValue('ID_CLIENTE', '1')` (string) sai
como `'1'` (com aspas), enquanto `SetValue('ID_CLIENTE', 1)` (Integer) sai `1`.

### Sobrecargas de `SetValue`

`Source/Core/FluentSQL.Interfaces.pas:184-192`:
`(col, String)` · `(col, Integer)` · `(col, Extended, decimais)` ·
`(col, Double, decimais)` · `(col, Currency, decimais)` · `(col, array of const)` ·
`(col, TDate)` · `(col, TDateTime)` · `(col, TGUID)`.

## DELETE

```pascal
// DELETE FROM CLIENTES
FluentSQL.Query(dbnFirebird).Delete.From('CLIENTES').AsString;

// DELETE FROM CLIENTES WHERE ID_CLIENTE = 1
FluentSQL.Query(dbnFirebird).Delete.From('CLIENTES').Where('ID_CLIENTE = 1').AsString;
```
Fonte: `Test Delphi/Firebird_tests/test.delete.firebird.pas:40-61`. Ordem:
`Delete → From(table) → [Where(...)]`.

## Executando o DML

FluentSQL só **gera a string**. Para efetivar, passe `.AsString` a uma conexão do
DataEngine (`IDBConnection`) — `delphi-fluentsql-specialist.md:18`. Ao executar via
`IDBConnection.CreateDataSet` (SQL cru, sem bind), garanta que valores no `WHERE`
sejam fragmento raw, não `:pN` — ver [rules.md](rules.md).

## Citations

- `Test Delphi/Firebird_tests/test.insert.firebird.pas:38-49` — INSERT.
- `Test Delphi/Firebird_tests/test.update.firebird.pas:40-69` — UPDATE + datas.
- `Test Delphi/Firebird_tests/test.delete.firebird.pas:40-61` — DELETE.
- `Source/Core/FluentSQL.Interfaces.pas:184-192,222,235,239-240,529` — SetValue/Values/AddRow/Update/Into.
- `delphi-fluentsql-specialist.md:18` — execução via DataEngine.
