---
type: Reference
title: DataEngine — Drivers & TDriverName
description: O enum canônico TDriverName (banco/dialeto), a matriz de fábricas por biblioteca de acesso (FireDAC/UniDAC/Zeos/…), e como os dois eixos se combinam. Transcrito do Source com file:line.
tags: [dataengine, delphi, driver, tdrivername, firedac, unidac, zeos, factory]
timestamp: 2026-07-11T00:00:00Z
---

# Drivers & TDriverName

Há **dois eixos** independentes no DataEngine, e confundi-los é comum:

1. **A biblioteca de acesso** (FireDAC, UniDAC, Zeos, ADO, dbExpress, SQLite3
   direto, …) → decidida pela **fábrica** que você instancia (`TFactoryFireDAC`,
   `TFactoryUniDac`, …).
2. **O banco/dialeto** (Firebird, PostgreSQL, Oracle, …) → decidido pelo
   **`TDriverName`** que você passa à fábrica. É o valor que `GetDriver` devolve e
   que o Janus usa para escolher o gerador de DML.

Ex.: `TFactoryFireDAC.Create(conn, dnFirebird)` = **FireDAC** acessando um
**Firebird** (`Source/Core/Core.Connection.pas:210-213`, consumidor).

## Schema — o enum canônico `TDriverName`

`Source/Core/DataEngine.FactoryInterfaces.pas:50-53`:

```pascal
TDriverName = (dnMSSQL, dnMySQL, dnFirebird, dnSQLite, dnInterbase, dnDB2,
               dnOracle, dnInformix, dnPostgreSQL, dnADS, dnASA,
               dnFirebase, dnFirebird3, dnAbsoluteDB, dnMongoDB,
               dnElevateDB, dnNexusDB, dnMariaDB, dnMemory);
```

E os rótulos-string paralelos (`FactoryInterfaces.pas:437-441`):

```pascal
TStrDriverName: array[dnMSSQL..dnMemory] of string =
  ('MSSQL','MySQL','Firebird','SQLite','Interbase','DB2','Oracle','Informix',
   'PostgreSQL','ADS','ASA','dnFirebase','dnFirebird3','AbsoluteDB','MongoDB',
   'ElevateDB','NexusDB','MariaDB','Memory');
```

> Note `dnFirebird` **e** `dnFirebird3` separados: o Firebird 3+ tem gerador de DML
> próprio no Janus (identity/sequence nativos) — escolha o que casa com a versão do
> servidor.

## Schema — a matriz de fábricas (biblioteca de acesso)

Cada biblioteca de acesso tem uma **fábrica** (`Source/Drivers/DataEngine.Factory*.pas`)
e um **driver** (`Source/Drivers/DataEngine.Driver*.pas`), quase sempre com uma
unit de transação irmã (`…Transaction.pas`):

| Biblioteca de acesso | Fábrica (unit) | Driver (unit) |
|---|---|---|
| FireDAC | `DataEngine.FactoryFireDac` | `DataEngine.DriverFireDac` |
| FireDAC → MongoDB | `DataEngine.FactoryFireDACMongoDB` | `DataEngine.DriverFireDacMongoDB` |
| UniDAC | `DataEngine.FactoryUniDac` | `DataEngine.DriverUniDac` |
| Zeos | `DataEngine.FactoryZeos` | `DataEngine.DriverZeos` |
| ADO | `DataEngine.FactoryADO` | `DataEngine.DriverADO` |
| dbExpress | `DataEngine.FactoryDBExpress` | `DataEngine.DriverDBExpress` |
| SQLite3 (direto) | `DataEngine.FactorySQLite3` | `DataEngine.DriverSQLite3` |
| SQLDB (FPC/Lazarus) | `DataEngine.FactorySQLDB` | `DataEngine.DriverSQLDB` |
| SQLDirect | `DataEngine.FactorySQLDirect` | `DataEngine.DriverSQLDirect` |
| IBExpress (IBX) | `DataEngine.FactoryIBExpress` | `DataEngine.DriverIBExpress` |
| IBObjects | `DataEngine.FactoryIBObjects` | `DataEngine.DriverIBObjects` |
| FIBPlus | `DataEngine.FactoryFIBPlus` | `DataEngine.DriverFIBPlus` |
| ODAC (Oracle) | `DataEngine.FactoryODAC` | `DataEngine.DriverODAC` |
| AbsoluteDB | `DataEngine.FactoryAbsoluteDB` | `DataEngine.DriverAbsoluteDB` |
| ElevateDB | `DataEngine.FactoryElevateDB` | `DataEngine.DriverElevateDB` |
| NexusDB | `DataEngine.FactoryNexusDB` | `DataEngine.DriverNexusDB` |
| WireMongoDB | `DataEngine.FactoryWireMongoDB` | `DataEngine.DriverWireMongoDB` |
| JSON | `DataEngine.FactoryJSON` | `DataEngine.DriverJSON` |
| Memória (in-memory) | `DataEngine.FactoryMemory` | `DataEngine.DriverMemory` |

Fonte: listagem de `.modules\DataEngine\Source\Drivers`. Bulk loaders dedicados
existem para FireDAC/UniDAC/Zeos (`…BulkLoader.pas`).

> **Nem toda combinação fábrica×`TDriverName` é necessariamente exercitada** — o
> `TDriverName` diz o dialeto que o Janus vai gerar; a fábrica diz como o SQL chega
> ao banco. Para um banco/lib fora do caminho batido (o padrão da casa é FireDAC +
> Firebird), **confirme empiricamente** e, se faltar exemplo do autor, é um TODO
> para a equipe do DataEngine (não há `Examples` no repo — ver
> [overview.md](overview.md)).

## Como o dialeto é escolhido no FireDAC

A fábrica repassa o `TDriverName` ao driver e à transação
(`Source/Drivers/DataEngine.FactoryFireDac.pas:47-54`); `GetDriver` sobe pela base
(`Source/Core/DataEngine.FactoryConnection.pas:270-273`). O Janus, ao receber a
`IDBConnection`, consulta `GetDriver` para selecionar o gerador de DML por dialeto
(ex.: desabilita associações em `dnMongoDB`).

## Nota de campo — leitura viva no Firebird (do especialista)

Além do driver certo, a leitura ao vivo contra Firebird legado exige na própria
`TFDConnection`:

- **`CharacterSet=WIN1252`** — charset legado do DB brasileiro; sem ele, VARCHAR
  acentuado estoura na materialização (`delphi-dataengine-specialist.md:19`;
  consumidor: `Source/Core/Core.Connection.pas:118-120,184-186`).

> O requisito de **registrar também o gerador SQLite** para o SELECT do Firebird é
> uma regra do **Janus** (camada de cima), não do DataEngine — ver a skill
> `delphi-janus` (`okf/dialects.md`). Aqui basta a `IDBConnection` correta.

## Citations

- `Source/Core/DataEngine.FactoryInterfaces.pas:50-53,437-441` — `TDriverName` + rótulos.
- `Source/Drivers/DataEngine.Factory*.pas` / `DataEngine.Driver*.pas` — matriz de fábricas/drivers.
- `Source/Drivers/DataEngine.FactoryFireDac.pas:47-54` — repasse do driver.
- `Source/Core/DataEngine.FactoryConnection.pas:270-273` — `GetDriver`.
- `Source/Core/Core.Connection.pas:118-120,210-213` — FireDAC+dnFirebird+WIN1252 (consumidor).
- `delphi-dataengine-specialist.md:11,19` — `TDriverName` canônico + charset.
