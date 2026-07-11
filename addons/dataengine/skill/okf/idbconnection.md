---
type: API Reference
title: DataEngine — IDBConnection & Transações
description: A superfície completa da interface IDBConnection e o contrato IDBTransaction (StartTransaction/Commit/Rollback, a transação 'DEFAULT' compartilhada), com file:line e as implicações de vida da conexão.
tags: [dataengine, delphi, idbconnection, transaction, firedac, connection-lifecycle]
timestamp: 2026-07-11T00:00:00Z
---

# IDBConnection & Transações

`IDBConnection` é o contrato central do DataEngine — é o que o Janus recebe e o que
o seu código de domínio deve segurar. Ela **estende** `IDBTransaction`
(`Source/Core/DataEngine.FactoryInterfaces.pas:364`), então uma conexão também é o
ponto de controle de transação.

## Schema — `IDBConnection`

`Source/Core/DataEngine.FactoryInterfaces.pas:364-397`:

```pascal
IDBConnection = interface(IDBTransaction)
  ['{5AF37B2C-65D1-4899-AAE9-866390E01DA4}']
  procedure Connect;                                              // :366
  procedure Disconnect;                                           // :367
  procedure ExecuteDirect(const ASQL: String); overload;         // :368
  procedure ExecuteDirect(const ASQL: String; const AParams: TParams); overload; // :369
  procedure ExecuteScript(const AScript: String);                // :370
  procedure AddScript(const AScript: String);                    // :371
  procedure ExecuteScripts;                                      // :372
  procedure ApplyUpdates(const ADataSets: array of IDBDataSet);  // :373
  function  IsConnected: Boolean;                                // :374
  function  CreateQuery: IDBQuery;                               // :375
  function  CreateDataSet(const ASQL: String = ''): IDBDataSet;  // :376
  function  BulkLoader: IDBBulkLoader;                           // :377
  function  GetSQLScripts: String;                               // :378
  function  RowsAffected: UInt32;                                // :379
  function  GetDriver: TDriverName;                              // :380
  function  CommandMonitor: ICommandMonitor;                     // :381
  function  MonitorCallback: TMonitorProc;                       // :382
  function  Options: IOptions;                                   // :383
  function  Cache: IDBCacheProvider;                             // :384
  function  MetadataCache: IDBMetadataCache;                     // :385
  procedure SetCacheProvider(ACache: IDBCacheProvider);          // :386
  procedure SetMetadataCacheProvider(AMetadataCache: IDBMetadataCache); // :387
  procedure SetCommandMonitor(AMonitor: ICommandMonitor);        // :388
  procedure RefreshMetadata(const ATableName: string);           // :389
  function  IsAlive: Boolean;                                    // :390
  function  ResiliencePolicy: IDBResiliencePolicy;               // :391
  procedure SetResiliencePolicy(APolicy: IDBResiliencePolicy);   // :392
  procedure AddObserver(const AObserver: IDBObserver);           // :393
  procedure RemoveObserver(const AObserver: IDBObserver);        // :394
  function  SlowQueryThreshold: Integer;                         // :395
  procedure SetSlowQueryThreshold(const AValue: Integer);        // :396
end;
```

Métodos que o especialista destaca como o núcleo do dia-a-dia
(`delphi-dataengine-specialist.md:16`): `CreateQuery`, `CreateDataSet`, `GetDriver`
— mais `Connect`/`Disconnect`/`IsConnected` e `ExecuteDirect`.

- **`GetDriver: TDriverName`** — devolve o driver ativo; o Janus (e a geração de
  DML) decide o dialeto a partir disso. Na base:
  `FactoryConnection.pas:270-273` → `FDriverConnection.GetDriver`.
- **`IsAlive`** — no FireDAC é `Connected and Ping`
  (`Source/Drivers/DataEngine.DriverFireDac.pas:341-348`); use para health-check
  sem estourar exceção.
- **`Cache` / `MetadataCache` / `ResiliencePolicy`** — infra opcional (cache de
  resultset/metadata, retry) plugável por-conexão.

## Schema — `IDBTransaction`

`Source/Core/DataEngine.FactoryInterfaces.pas:314-325`:

```pascal
IDBTransaction = interface
  ['{F08CB640-4403-4E7B-A6B2-4D1D8607190A}']
  function  _GetTransaction(const AKey: String): TComponent;
  procedure StartTransaction(const ALevel: TDBIsolationLevel = ilDefault);  // :317
  procedure Commit;                                            // :318
  procedure Rollback;                                          // :319
  procedure AddTransaction(const AKey: String; const ATransaction: TComponent); // :320
  procedure UseTransaction(const AKey: String);                // :321
  function  TransactionActive: TComponent;                     // :322
  function  InTransaction: Boolean;                            // :323
  property  Transaction[const AKey: String]: TComponent read _GetTransaction;
end;
```

`TDBIsolationLevel` = `ilDefault | ilReadUncommitted | ilReadCommitted |
ilRepeatableRead | ilSerializable | ilSnapshot` (`:56`). No FireDAC, o mapeamento
para o nível nativo é em `DataEngine.DriverFireDacTransaction.pas:47-58` (note:
`ilSerializable`/`ilSnapshot` caem para `xiReadCommitted` hoje).

## A transação `'DEFAULT'` compartilhada (leia com atenção)

A fábrica FireDAC cria — se a `TFDConnection` ainda não tiver uma — **uma única**
`TFDTransaction` chamada `'DEFAULT'`, e a registra como a transação ativa
(`Source/Drivers/DataEngine.DriverFireDacTransaction.pas:62-75`):

```pascal
if FConnection.Transaction = nil then
begin
  FTransaction := TFDTransaction.Create(nil);
  FTransaction.Connection := FConnection;
  FConnection.Transaction := FTransaction;
end;
FConnection.Transaction.Name := 'DEFAULT';
FTransactionList.Add('DEFAULT', FConnection.Transaction);
FTransactionActive := FConnection.Transaction;
```

- **`StartTransaction`** na base tenta `UseTransaction('DEFAULT')`, conecta se
  preciso (marcando `FAutoTransaction`), e inicia
  (`FactoryConnection.pas:315-332`).
- **`InTransaction`** só é `True` se conectado E a transação FireDAC está `.Active`
  (`FactoryConnection.pas:280-286` → `DriverFireDacTransaction.pas:108-111`, que só
  retorna `.Active`). ⚠️ Isso **não distingue** "transação explícita do dev" de
  "incidentalmente Active" — é a raiz da errata #2 em [rules.md](rules.md).
- **`Commit`/`Rollback`** na base, se `FAutoTransaction`, também **desconectam**
  (`FactoryConnection.pas:106-111,298-303`).

## Ciclo de vida da conexão (o que mais dói em servidor)

O adapter do objectset do Janus só faz `Connect`/`Disconnect` numa conexão que
chegou **desconectada**, e o `Disconnect` **fecha fisicamente** a `TFDConnection`.
Em servidor single-process com conexão compartilhada, a regra da casa (DEC-047) é
**abrir 1× e MANTER aberta** (`Source/Core/Core.Connection.pas:130-136`,
consumidor):

```pascal
FDBConnection := TCreateConn.CreateDBConnection(FConnection);
// DEC-047 — open and KEEP open for the process lifetime.
FConnection.Connected := True;
```

Não troque isso por uma Factory por-request (vaza `TFDConnection` e trava) — ver
[rules.md](rules.md) errata #3 e o troubleshooting.

## Citations

- `Source/Core/DataEngine.FactoryInterfaces.pas:314-325,364-397,56` — `IDBConnection`, `IDBTransaction`, isolamento.
- `Source/Core/DataEngine.FactoryConnection.pas:106-111,270-332` — Commit/GetDriver/StartTransaction/InTransaction.
- `Source/Drivers/DataEngine.DriverFireDacTransaction.pas:47-58,62-75,108-111` — a `'DEFAULT'` compartilhada + `_InTransaction`.
- `Source/Drivers/DataEngine.DriverFireDac.pas:341-348` — `IsAlive`.
- `Source/Core/Core.Connection.pas:130-136,210-213` — abrir-e-manter (consumidor).
- `delphi-dataengine-specialist.md:16,23` — núcleo da API + a errata da txn compartilhada.
