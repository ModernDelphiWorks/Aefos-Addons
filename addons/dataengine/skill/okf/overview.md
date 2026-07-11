---
type: Framework Overview
title: DataEngine — Visão Geral
description: O que é o DataEngine, sua arquitetura (fábrica → driver → conexão desacoplada), fontes da verdade e quando usar.
tags: [dataengine, delphi, data-access, idbconnection, firedac, overview]
timestamp: 2026-07-11T00:00:00Z
---

# DataEngine — Visão Geral

O **DataEngine** é uma camada de **acesso a dados desacoplada** para Delphi (e
Lazarus), autor **Isaque Pinheiro** (ModernDelphiWorks), licença MIT
(`Source/Core/DataEngine.FactoryInterfaces.pas:1-12`). Ele expõe **interfaces**
(`IDBConnection`, `IDBDataSet`/`IDBResultSet`, `IDBQuery`, `IDBTransaction`) e
esconde o driver concreto (FireDAC, UniDAC, Zeos, ADO, dbExpress, SQLite3, …) atrás
delas. O consumidor programa contra a interface; a troca de banco/driver é uma
questão de qual **fábrica** e qual `TDriverName` você usa.

## Arquitetura em uma frase

Você tem uma conexão nativa (ex.: `TFDConnection`) → embrulha numa **fábrica**
(`TFactoryFireDAC`) que devolve `IDBConnection` → chama `CreateDataSet`/`CreateQuery`/
`ExecuteDirect` para executar SQL → itera um `IDBDataSet` abstrato. O código do
domínio nunca vê FireDAC.

```
TFDConnection (nativo)
     │  embrulhado por
     ▼
TFactoryFireDAC.Create(conn, dnFirebird)  ─▶  IDBConnection
     │                                              │
     │  compõe                              CreateDataSet / CreateQuery
     ▼                                       ExecuteDirect / StartTransaction
TDriverFireDAC + TDriverFireDACTransaction          │
     │                                               ▼
     └────────────────────────────────────▶  IDBDataSet / IDBResultSet
                                                (Open · NotEof · GetFieldValue)
```

A fábrica FireDAC compõe um `TDriverFireDACTransaction` + um `TDriverFireDAC` sobre
a `TFDConnection` recebida (`Source/Drivers/DataEngine.FactoryFireDac.pas:47-56`); a
base abstrata `TFactoryConnection` implementa `IDBConnection`/`IDBTransaction`
delegando ao driver (`Source/Core/DataEngine.FactoryConnection.pas:26-76`).

## Quem consome o DataEngine

- **O Janus ORM** constrói `TContainerObjectSet<T>.Create(IDBConnection)` e itera o
  resultset por baixo — o Janus fala com o DataEngine, não com FireDAC
  (`delphi-dataengine-specialist.md:7`, `:18`).
- **O ERP (backend)** resolve uma `IDBConnection` singleton via
  `TFactoryFireDAC.Create(AConnection, dnFirebird)`
  (`Source/Core/Core.Connection.pas:210-213`, código consumidor) e a usa tanto pelo
  Janus quanto em leituras/escritas SQL avulsas (ex.:
  `Source/Shared/Dao/Shared.Entity.Dao.pas:542-549`).
- **Integrações prontas:** `Horse.DataEngine` (pool + tenant por request,
  `Source/Integrations/Horse.DataEngine.pas:26-49`) e `DataEngine.FluentSQL`
  (DDL fluente sobre `IDBConnection`, `Source/Integrations/DataEngine.FluentSQL.pas:51-57`).

## Camadas do Source (para investigar)

- **Contratos** (`Source/Core/DataEngine.FactoryInterfaces.pas`): TODAS as
  interfaces públicas + o enum `TDriverName` (linha 50) e utilitários (`TFieldHelper`,
  `TMonitorParam`, `TFetchOptions`).
- **Base de conexão** (`Source/Core/DataEngine.FactoryConnection.pas`):
  `TFactoryConnection` abstrata — o esqueleto de `IDBConnection` (Connect/Disconnect/
  ExecuteDirect/StartTransaction) que todas as fábricas herdam.
- **Base de driver** (`Source/Core/DataEngine.DriverConnection.pas`):
  `TDriverConnection`, `TDriverQuery`, `TDriverDataSetBase` — a mecânica comum de
  dataset/query (inclusive o `NotEof` que auto-avança, linha 672).
- **Drivers concretos** (`Source/Drivers/DataEngine.Driver*.pas`) + **fábricas**
  (`Source/Drivers/DataEngine.Factory*.pas`): um par por banco/engine. Ver
  [drivers.md](drivers.md).
- **Infra** (`Source/Core`): cache (`CacheManager`, `RedisCacheProvider`,
  `SQLiteCacheProvider`), pool (`PoolConnection`, `PoolCoordinator.Redis`),
  metadata, migration, observability, async, bulk loader, snapshot.
- **Integrações** (`Source/Integrations`): `Horse.DataEngine`,
  `DataEngine.FluentSQL`.

## Fontes da verdade (estude ANTES de afirmar)

1. **Source do framework** — `.modules\DataEngine\Source`. A porta de entrada é
   `Source/Core/DataEngine.FactoryInterfaces.pas` (todas as interfaces + `TDriverName`);
   depois `FactoryConnection.pas`, `DriverConnection.pas` e o driver do seu banco
   (`Drivers/DataEngine.DriverFireDac.pas`).
2. **Consumo real (ERP/backend)** — como o dono realmente cabeia e usa o DataEngine:
   `Source/Core/Core.Connection.pas` (fábrica + charset + manter aberta),
   `Source/Shared/Dao/Shared.Entity.Dao.pas` (scalar-read avulso),
   `Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas` e
   `…/Shared.Estoque.PeriodoLock.pas` (loop `NotEof`).
3. ⚠️ **NÃO há pasta `Examples`** no repositório do DataEngine hoje (o especialista
   registra "quando existir" — `delphi-dataengine-specialist.md:10`). Portanto o uso
   correto é demonstrado pelo Source + pelos consumidores reais acima, não por um
   Examples do framework. Se precisar de um exemplo canônico do próprio autor, é um
   **TODO** para a equipe do DataEngine.

> **Convenção de citação:** caminhos `Source/...` e `Drivers/...` são relativos a
> `.modules\DataEngine`; caminhos `Source/Core/Core.Connection.pas`,
> `Source/Shared/...` e `Source/Modules/...` são **código consumidor** no ERP
> (backend). Cada citação diz de qual raiz veio quando há ambiguidade.

## Quando usar

- Você quer acessar banco em Delphi sem acoplar o domínio ao FireDAC/UniDAC/Zeos —
  programe contra `IDBConnection`/`IDBDataSet` e troque o driver pela fábrica.
- Você usa o Janus (ou FluentSQL): eles já assentam sobre `IDBConnection`.
- Você precisa de SQL ad-hoc pontual (um `GEN_ID`, um `SELECT` de status) fora do
  ORM — `CreateDataSet(sql)` + `Open` + `GetFieldValue` (ver [api.md](api.md)).

## Quando NÃO usar / limites

- Não é um ORM: mapeamento de entidade/CRUD genérico é o **Janus** (sobre o
  DataEngine). O DataEngine só entrega conexão/dataset/execução.
- Não é o dono do JSON: JSON avulso no ecossistema é **JsonFlow**
  (`delphi-dataengine-specialist.md` — herdado da regra do Janus).

## Citations

- `Source/Core/DataEngine.FactoryInterfaces.pas:44-397` — todas as interfaces
  públicas + `TDriverName` (50).
- `Source/Core/DataEngine.FactoryConnection.pas:26-76` — base `TFactoryConnection`.
- `Source/Drivers/DataEngine.FactoryFireDac.pas:47-56` — a fábrica FireDAC compõe
  driver + transação.
- `Source/Core/DataEngine.DriverConnection.pas:37,127,172` — bases
  `TDriverConnection`/`TDriverQuery`/`TDriverDataSetBase`.
- `Source/Core/Core.Connection.pas:210-213` — consumidor (ERP) resolvendo a
  `IDBConnection`.
- `delphi-dataengine-specialist.md:7-19` — fontes da verdade e conhecimento essencial.
