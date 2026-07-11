---
type: API Reference
title: Janus ORM — Dialetos de DML & Leitura Viva
description: Os geradores de DML por banco e os requisitos práticos para ler/escrever ao vivo contra Firebird (registro do gerador SQLite, charset WIN1252).
tags: [janus, orm, delphi, dml, dialect, firebird, sqlite, liveread]
timestamp: 2026-07-11T00:00:00Z
---

# Dialetos de DML & Leitura Viva

## Schema — geradores de DML por dialeto

O Janus gera a SQL por dialeto; há um gerador por banco em `Source/Core`:

| Dialeto | Unit |
|---|---|
| Firebird 2.5 | `Janus.DML.Generator.Firebird.pas` |
| Firebird 3+ | `Janus.DML.Generator.Firebird3.pas` |
| SQLite | `Janus.DML.Generator.SQLite.pas` |
| PostgreSQL | `Janus.DML.Generator.PostgreSQL.pas` |
| Oracle | `Janus.DML.Generator.Oracle.pas` |
| MSSQL | `Janus.DML.Generator.MSSQL.pas` |
| MySQL | `Janus.DML.Generator.MySQL.pas` |
| InterBase | `Janus.DML.Generator.InterBase.pas` |
| ElevateDB | `Janus.DML.Generator.ElevateDB.pas` |
| NexusDB | `Janus.DML.Generator.NexusDB.pas` |
| Absolute DB | `Janus.DML.Generator.AbsoluteDB.pas` |
| ADS | `Janus.DML.Generator.ADS.pas` |
| MongoDB / NoSQL | `Janus.DML.Generator.MongoDB.pas` · `Janus.DML.Generator.NoSQL.pas` |

Fonte: listagem de `.modules\Janus\Source\Core` (arquivos `Janus.DML.Generator.*.pas`).

O dialeto ativo é escolhido pelo `TDriverName` passado à fábrica do DataEngine —
no Example Horse, `TFactoryFiredac.Create(Connection, dnFirebird)`
(`Examples/Delphi/RESTful/Horse/dao/HorseJanus.DAO.Base.pas:56`). O executor
consulta `FConnection.GetDriver` (ex.: desabilita associações em `dnMongoDB`,
`Source/Core/Janus.Command.Executor.pas:207`).

## Como registrar o gerador

Basta colocar a unit do gerador no `uses` da conexão. No Example, o data module
usa `Janus.DML.Generator.Firebird` (`Examples/Delphi/RESTful/Horse/providers/DM.Connection.pas:31`).
O gerador se auto-registra ao ser referenciado.

## Leitura VIVA contra Firebird — requisitos (descobertos na marra)

Estes três pontos vêm da experiência de campo do especialista
(`delphi-janus-specialist.md:24-27`) e são o que mais trava leitura ao vivo:

1. **Registre TAMBÉM o gerador SQLite.** O SELECT do Firebird remapeia
   internamente para o gerador SQLite; se `Janus.DML.Generator.SQLite` não estiver
   no `uses` da conexão (junto do Firebird), a leitura dá **Access Violation**
   (`delphi-janus-specialist.md:25`).
2. **`CharacterSet=WIN1252` na conexão.** O charset legado do DB brasileiro; sem
   ele, strings acentuadas estouram `"Out of memory"`
   (`delphi-janus-specialist.md:26`).
3. **Reconcilie a entidade ao DDL VIVO.** Entidades vindas do modelo legado
   (ORMBr) frequentemente divergem do DDL real — colunas a mais/menos derrubam a
   leitura. Mapeie verbatim do legado, mas confira contra o banco
   (`delphi-janus-specialist.md:27`, `:12`).

> Nota de projeto (ERP do dono): para o read live foram necessários (1) registrar
> `Janus.DML.Generator.SQLite`; (2) `CharacterSet=WIN1252`; e observou-se que
> **DATE-bind** ainda falhava — para JSON avulso usa-se JsonFlow. Confirme
> empiricamente no seu ambiente antes de assumir.

## Citations

- `Source/Core/Janus.DML.Generator.*.pas` — geradores por dialeto.
- `Source/Core/Janus.Command.Executor.pas:207` — decisão por driver (NoSQL/MongoDB).
- `Examples/Delphi/RESTful/Horse/dao/HorseJanus.DAO.Base.pas:56` — driver na fábrica.
- `Examples/Delphi/RESTful/Horse/providers/DM.Connection.pas:31` — uses do gerador.
- `delphi-janus-specialist.md:24-27` — requisitos de leitura viva Firebird.
