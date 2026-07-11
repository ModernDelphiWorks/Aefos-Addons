---
type: API Reference
title: FluentSQL — Dialetos & Fragmentos Específicos
description: A enum TFluentSQLDriver e o mapa de qualificadores/serializadores por banco, ForDialectOnly (ESP-016) para fragmentos opt-in por engine, e o alvo MongoDB (MQL, não SQL).
tags: [fluentsql, sql, delphi, dialect, driver, mongodb, fordialectonly]
timestamp: 2026-07-11T00:00:00Z
---

# Dialetos & Fragmentos Específicos

## A enum de drivers

```pascal
TFluentSQLDriver = (dbnMSSQL, dbnMySQL, dbnFirebird, dbnSQLite, dbnInterbase,
  dbnDB2, dbnOracle, dbnInformix, dbnPostgreSQL, dbnADS, dbnASA, dbnAbsoluteDB,
  dbnMongoDB, dbnElevateDB, dbnNexusDB);
```
Fonte: `Source/Core/FluentSQL.Interfaces.pas:31-33`. Passe o driver a
`FluentSQL.Query(dbn...)`; a mesma cadeia fluente serializa por dialeto (ver a
tabela de paginação em [joins-paging.md](joins-paging.md)).

## Qualificadores & serializadores (Source/Drivers)

Há uma família de units por banco em `.modules\FluentSQL\Source\Drivers`:

| Papel | Padrão de arquivo |
|---|---|
| Qualificador (aspas, paginação) | `FluentSQL.Qualifier<DB>.pas` (Firebird, MSSQL, MySQL, Oracle, PostgreSQL, SQLite, Interbase, DB2, MongoDB) |
| Serialização SELECT | `FluentSQL.Select.<DB>.pas` / `FluentSQL.Select<DB>.pas` |
| Serialização geral | `FluentSQL.Serialize<DB>.pas` |
| Funções por banco | `FluentSQL.Functions<DB>.pas` |
| DDL por banco | `FluentSQL.DDL.Serialize.<DB>.pas` |

Fonte: listagem de `.modules\FluentSQL\Source\Drivers` (arquivos
`FluentSQL.Qualifier*.pas`, `FluentSQL.Select.*`, `FluentSQL.Serialize*`,
`FluentSQL.Functions*`). Ao gerar SQL para **Firebird vivo, use `dbnFirebird`** —
não assuma sintaxe MSSQL (`delphi-fluentsql-specialist.md:21`).

## `ForDialectOnly` — fragmento opt-in por engine (ESP-016)

Anexa SQL **só** quando a serialização é para aquele dialeto; outros engines
omitem. Não é SQL universal (`Source/Core/FluentSQL.Interfaces.pas:35-39,305-308`).

```pascal
// Serializando para PostgreSQL → sufixo aplicado
FluentSQL.Query(dbnPostgreSQL)
  .Insert.Into('T').SetValue('A', 1)
  .ForDialectOnly(dbnPostgreSQL, ' RETURNING ID')
  .AsString;
// → INSERT INTO T (A) VALUES (:p1) RETURNING ID

// Mesma cadeia serializada para outro engine → fragmento omitido
FluentSQL.Query(dbnFirebird)
  .Insert.Into('T').SetValue('A', 1)
  .ForDialectOnly(dbnPostgreSQL, ' RETURNING ID')
  .ForDialectOnly(dbnMySQL, '')
  .AsString;
// → INSERT INTO T (A) VALUES (:p1)
```
Fonte: `Test Delphi/Common_tests/test.core.params.pas:329-350`.

**Sobrecarga `array of const`** — escalares viram parâmetros `:pN`:
```pascal
FluentSQL.Query(dbnFirebird)
  .Select.All.From('T').Where('ID').Equal(1)
  .ForDialectOnly(dbnFirebird, [' OFFSET ', 0])
  .AsString;
// → SELECT * FROM T WHERE (ID = :p1) OFFSET :p2   (Params.Count = 2)
```
Fonte: `test.core.params.pas:355-365`.

## MongoDB — alvo MQL, não SQL

Com `dbnMongoDB` o FluentSQL emite **MQL** (Mongo Query Language), não SQL:

```pascal
// SELECT All → find vazio
FluentSQL.Query(dbnMongoDB).Select.All.From('CLIENTES').AsString;
// → 'clientes.Find( {} )'
```
Fonte: `Test Delphi/Firebird_tests/test.select.firebird.pas:94-104`. Agregações
viram estágios de pipeline (`$group`, `$sum`, `$avg`, `$min`, `$max`):
`Test Delphi/MongoDB_tests/test.dml.mongodb.pas:73-107`. Por isso o produto se
descreve como gerador **"SQL/MQL"** (`Source/Core/FluentSQL.Interfaces.pas:4`).

## Citations

- `Source/Core/FluentSQL.Interfaces.pas:31-39,305-308` — drivers e `ForDialectOnly`/`TDialectOnlyFragment`.
- `.modules\FluentSQL\Source\Drivers` — famílias de qualificador/serializador por banco.
- `Test Delphi/Common_tests/test.core.params.pas:329-365` — `ForDialectOnly` (string e array).
- `Test Delphi/Firebird_tests/test.select.firebird.pas:94-104` — MongoDB `Find( {} )`.
- `Test Delphi/MongoDB_tests/test.dml.mongodb.pas:73-107` — agregações MQL.
- `delphi-fluentsql-specialist.md:21` — usar o qualificador certo (Firebird vivo).
