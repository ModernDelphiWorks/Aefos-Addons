---
type: Playbook
title: DataEngine — Quickstart
description: De uma TFDConnection a leituras e comandos via IDBConnection, no padrão canônico da casa (fábrica + singleton aberto + NotEof sem Next). Cada passo cita a fonte.
tags: [dataengine, delphi, quickstart, idbconnection, createdataset, executedirect]
timestamp: 2026-07-11T00:00:00Z
---

# Quickstart — do driver nativo ao acesso desacoplado

Baseado no Source do DataEngine e no cabeamento real do ERP
(`Source/Core/Core.Connection.pas`). Cada passo cita a fonte.

## 1. Configure a `TFDConnection` nativa

```pascal
FConnection := TFDConnection.Create(nil);
FConnection.DriverName := 'FB';
FConnection.LoginPrompt := False;
FConnection.Params.Clear;
FConnection.Params.Add('DriverID=FB');
FConnection.Params.Add('Server=' + Host);
FConnection.Params.Add('Port=' + IntToStr(Port));
FConnection.Params.Add('Database=' + Database);
FConnection.Params.Add('User_Name=' + User);
FConnection.Params.Add('Password=' + Pass);
FConnection.Params.Add('CharacterSet=WIN1252');   // Firebird legado BR — obrigatório p/ acento
```
Fonte: `Source/Core/Core.Connection.pas:107-123` (consumidor). O charset WIN1252
evita "Out of memory" em VARCHAR acentuado (`delphi-dataengine-specialist.md:19`).

## 2. Embrulhe numa `IDBConnection` pela fábrica

```pascal
uses
  DataEngine.FactoryInterfaces,   // IDBConnection, TDriverName
  DataEngine.FactoryFireDac;      // TFactoryFireDAC

FDBConnection := TFactoryFireDAC.Create(FConnection, dnFirebird);   // IDBConnection
```
Fonte: `Source/Core/Core.Connection.pas:210-213`;
`Source/Drivers/DataEngine.FactoryFireDac.pas:47-56`. A fábrica é o único ponto que
toca FireDAC — daqui pra frente é só `IDBConnection`. Escolha `dnFirebird` vs
`dnFirebird3` pela versão do servidor (ver [../drivers.md](../drivers.md)).

## 3. Abra e MANTENHA aberta (servidor single-process)

```pascal
FConnection.Connected := True;   // DEC-047 — abrir 1× e manter pelo processo
```
Fonte: `Source/Core/Core.Connection.pas:130-136`. NÃO use Factory por-request
(vaza e trava — [../rules.md](../rules.md) Regra 4).

## 4. Leia um valor (scalar-read ad-hoc)

```pascal
LDataSet := FDBConnection.CreateDataSet(
  'SELECT GEN_ID(GEN_X_ID, 1) AS NEW_ID FROM RDB$DATABASE');
try
  LDataSet.Open;                          // o CreateDataSet já abre; reabrir é OK (PR #56)
  Result := LDataSet.GetFieldValue('NEW_ID');
finally
  LDataSet.Close;
end;
```
Fonte: `Source/Shared/Dao/Shared.Entity.Dao.pas:535-550` (consumidor).

## 5. Itere um resultset — `NotEof` SEM `Next`

```pascal
LDs := FDBConnection.CreateDataSet('SELECT COD, NOME FROM TABELA WHERE ...');
try
  LDs.Open;
  while LDs.NotEof do            // NotEof ANDA sozinho — NÃO chame Next aqui
  begin
    Cod  := LDs.GetFieldValue('COD');
    Nome := LDs.FieldByName('NOME').AsString;
    // ... processa a linha ...
  end;
finally
  LDs.Close;
end;
```
Fonte: `Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas:54-70`,
`…/Shared.Estoque.PeriodoLock.pas:44-59`. O porquê: `NotEof` chama `Next` interno
(`DriverConnection.pas:672-679`) — ver [../idbdataset.md](../idbdataset.md).

## 6. Execute um comando (sem resultset)

```pascal
FDBConnection.ExecuteDirect('UPDATE TABELA SET STATUS = 1 WHERE ID = 10');
```
A base gerencia a transação sozinha quando você não está numa: Connect →
StartTransaction → executa → Commit/Rollback (`FactoryConnection.pas:180-208`). Para
controle explícito, use `StartTransaction`/`Commit`/`Rollback` você mesmo
(`FactoryInterfaces.pas:317-319`).

## 7. Query parametrizada (entrada externa)

```pascal
LQ := FDBConnection.CreateQuery;
LQ.CommandText := 'SELECT * FROM CLIENTE WHERE ID = :id';
LQ.ParamByName('id').AsInteger := AId;
LDs := LQ.ExecuteQuery;   // já aberto
```
Fonte: `Source/Core/DataEngine.FactoryInterfaces.pas:265-285`. Prefira `CreateQuery`
+ params a concatenar valores em `CreateDataSet`.

## Checklist final

- [ ] `CharacterSet=WIN1252` na `TFDConnection` (Firebird BR).
- [ ] `IDBConnection` pela **fábrica** (`TFactoryFireDAC`), nunca FireDAC direto no domínio.
- [ ] Conexão **aberta e mantida** (singleton) em servidor single-process (Regra 4).
- [ ] Loop de leitura com `NotEof` **sem** `Next` (Regra 1).
- [ ] Entrada externa → `CreateQuery` + `ParamByName`, não string concatenada.

## Citations

- `Source/Core/Core.Connection.pas:107-136,210-213` — cabeamento (consumidor).
- `Source/Drivers/DataEngine.FactoryFireDac.pas:47-56` — fábrica.
- `Source/Core/DataEngine.FactoryConnection.pas:180-208` — `ExecuteDirect` auto-txn.
- `Source/Core/DataEngine.FactoryInterfaces.pas:265-285,317-319,376` — `IDBQuery`, txn, `CreateDataSet`.
- `Source/Core/DataEngine.DriverConnection.pas:672-679` — `NotEof` auto-avança.
- `Source/Shared/Dao/Shared.Entity.Dao.pas:535-550`; `Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas:54-70` — padrões reais.
