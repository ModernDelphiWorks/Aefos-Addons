---
type: API Reference
title: DataEngine — Referência Técnica (fábricas & execução de SQL)
description: As fábricas (TFactoryFireDAC), a base TFactoryConnection, e as três formas de executar SQL — CreateDataSet, CreateQuery e ExecuteDirect — transcritas do Source com file:line.
tags: [dataengine, delphi, factory, sql, createdataset, createquery, executedirect, api]
timestamp: 2026-07-11T00:00:00Z
---

# DataEngine — Referência Técnica

Tudo aqui é transcrito de `.modules\DataEngine\Source` e do consumo real no ERP.
A superfície de `IDBConnection`/transações tem doc própria em
[idbconnection.md](idbconnection.md); o dataset em [idbdataset.md](idbdataset.md);
os drivers/`TDriverName` em [drivers.md](drivers.md).

## Schema — a fábrica FireDAC (ponto de entrada mais comum)

`Source/Drivers/DataEngine.FactoryFireDac.pas:27-37`:

```pascal
TFactoryFireDAC = class(TFactoryConnection)
public
  constructor Create(const AConnection: TFDConnection;
    const ADriver: TDriverName); overload;                          // :29-30
  constructor Create(const AConnection: TFDConnection; const ADriver: TDriverName;
    const AMonitor: ICommandMonitor); overload;                     // :31-32
  constructor Create(const AConnection: TFDConnection; const ADriver: TDriverName;
    const AMonitorCallback: TMonitorProc); overload;                // :33-34
  destructor Destroy; override;
  procedure AddTransaction(const AKey: String; const ATransaction: TComponent); override;
end;
```

O construtor compõe a transação + o driver sobre a `TFDConnection` recebida e
**não** inicia auto-transação (`:47-56`):

```pascal
FDriverTransaction := TDriverFireDACTransaction.Create(AConnection, FMonitorCallback);
FDriverConnection  := TDriverFireDAC.Create(AConnection, FDriverTransaction,
                                            ADriver, FMonitorCallback);
FAutoTransaction := False;
```

Uso real (consumidor/ERP), `Source/Core/Core.Connection.pas:210-213`:

```pascal
class function TCreateConn.CreateDBConnection(const AConnection: TFDConnection): IDBConnection;
begin
  Result := TFactoryFireDAC.Create(AConnection, dnFirebird);
end;
```

> `AddTransaction` da fábrica FireDAC valida o tipo: só aceita `TFDTransaction`,
> senão levanta `'Invalid transaction type. Expected TFDTransaction.'`
> (`FactoryFireDac.pas:72-79`).

Há uma fábrica por driver (`TFactoryUniDac`, `TFactoryZeos`, `TFactorySQLite3`,
`TFactoryADO`, `TFactoryMemory`, …) — matriz completa em [drivers.md](drivers.md).

## Schema — a base `TFactoryConnection`

Toda fábrica herda de `TFactoryConnection` (abstrata,
`Source/Core/DataEngine.FactoryConnection.pas:26-76`), que implementa
`IDBConnection`/`IDBTransaction` delegando para `FDriverConnection`/
`FDriverTransaction`. É onde vive a **semântica de transação automática** de
`ExecuteDirect`/`ExecuteScript` (abre/inicia/commita/desfaz sozinho quando você
não está numa transação) — ver [idbconnection.md](idbconnection.md).

## Schema — três formas de executar SQL

### 1. `CreateDataSet(const ASQL: String = ''): IDBDataSet` — leitura ad-hoc

Contrato em `Source/Core/DataEngine.FactoryInterfaces.pas:376`. Na base delega ao
driver (`FactoryConnection.pas:126-129`). No FireDAC, cria uma query, seta o texto
e executa (`Source/Drivers/DataEngine.DriverFireDac.pas:327-339`):

```pascal
function TDriverFireDAC.CreateDataSet(const ASQL: String): IDBDataSet;
begin
  LDBQuery := TDriverQueryFireDAC.Create(...);
  LDBQuery.CommandText := ASQL;
  Result := LDBQuery.ExecuteQuery;     // já executa
end;
```

⚠️ **O dataset volta ABERTO.** `ExecuteQuery` → `_InternalExecuteQuery` faz
`LDataSet.Open` internamente (`DriverFireDac.pas:434`) antes de embrulhar em
`TDriverDataSetFireDAC`. Você **pode** chamar `.Open` de novo (o padrão do ERP
faz — ver abaixo), mas era exatamente o `.Open` explícito ad-hoc que batia no AV
histórico (corrigido no PR #56 — ver [rules.md](rules.md)).

Uso real (consumidor/ERP) — scalar-read de um generator,
`Source/Shared/Dao/Shared.Entity.Dao.pas:535-550`:

```pascal
LDataSet := _Connection.CreateDataSet(
  'SELECT GEN_ID(' + AGenerator + ', 1) AS NEW_ID FROM RDB$DATABASE');
try
  LDataSet.Open;
  Result := LDataSet.GetFieldValue('NEW_ID');
finally
  LDataSet.Close;
end;
```

### 2. `CreateQuery: IDBQuery` — query parametrizada / reusável

Contrato em `FactoryInterfaces.pas:375`; a interface `IDBQuery` em `:265-285`:

```pascal
IDBQuery = interface
  procedure ExecuteDirect;
  function  ExecuteQuery: IDBDataSet;      // :271 — abre e devolve o resultset
  function  RowsAffected: UInt32;
  procedure Prepare; procedure Unprepare;
  function  ParamByName(const AValue: string): TParam;    // :275
  property  CommandText: String read _GetCommandText write _SetCommandText;   // :281
  property  Params: TParams read _GetParams;              // :282
  property  FetchOptions: TFetchOptions ...;
  property  SlowQueryThreshold: Integer ...;
end;
```

Fluxo: `q := conn.CreateQuery; q.CommandText := 'SELECT … WHERE id = :id';
q.ParamByName('id').AsInteger := 10; ds := q.ExecuteQuery;`. Prefira `CreateQuery`
(params ligados) a concatenar valores em `CreateDataSet` quando houver entrada
externa.

### 3. `ExecuteDirect(const ASQL[, AParams])` — comando sem resultset

Contrato em `FactoryInterfaces.pas:368-369`. Na base
(`FactoryConnection.pas:180-208`) ele **gerencia a transação sozinho** quando você
ainda não está numa: `Connect` (se preciso) → `StartTransaction` → executa →
`Commit`/`Rollback` → `Disconnect` (se ele mesmo conectou). Há também
`ExecuteScript`/`AddScript`/`ExecuteScripts` (`:210-268`) para DDL/scripts.

## Schema — utilitários úteis do contrato

- `TFieldHelper` (`FactoryInterfaces.pas:66-77`) — `AsStringDef`, `AsIntegerDef`,
  `AsDateTimeDef`, `AsDoubleDef`, `AsCurrencyDef`, `AsBooleanDef`, `ValueDef`:
  leitura de `TField` com default seguro contra `null`/exceção.
- `TFetchMode` / `TFetchOptions` (`:58-64`) — `fmAll` | `fmManual` | `fmOnDemand`
  + `BatchSize`, para controlar fetch preguiçoso.
- `TMonitorParam` / `TMonitorProc` / `IDBObserver` (`:25-47`) — observabilidade de
  comandos (start/end/error/metric); `SetCommandMonitor`/`AddObserver` na conexão.
- `IDBBulkLoader` (`:287-300`) — carga em lote (`conn.BulkLoader`).

## Examples (consumidor real — o DataEngine não traz `Examples` próprio)

- Cabeamento fábrica+conexão: `Source/Core/Core.Connection.pas:107-136,210-217`.
- Scalar-read ad-hoc: `Source/Shared/Dao/Shared.Entity.Dao.pas:535-550`.
- Loop de resultset: `Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas:54-70`
  e `…/Shared.Estoque.PeriodoLock.pas:44-59` — ver [idbdataset.md](idbdataset.md).

## Citations

- `Source/Drivers/DataEngine.FactoryFireDac.pas:27-88` — fábrica FireDAC + validação de txn.
- `Source/Core/DataEngine.FactoryConnection.pas:26-76,126-129,180-268` — base + execução de SQL.
- `Source/Drivers/DataEngine.DriverFireDac.pas:327-339,434` — `CreateDataSet` FireDAC (abre internamente).
- `Source/Core/DataEngine.FactoryInterfaces.pas:66-77,265-300,368-376` — helpers, `IDBQuery`, execução.
- `Source/Core/Core.Connection.pas:210-217` — consumidor resolvendo a `IDBConnection`.
- `Source/Shared/Dao/Shared.Entity.Dao.pas:535-550` — scalar-read canônico do ERP.
- `delphi-dataengine-specialist.md:16-18` — assinaturas essenciais de `IDBConnection`.
