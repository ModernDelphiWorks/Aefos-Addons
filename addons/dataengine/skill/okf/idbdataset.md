---
type: API Reference
title: DataEngine — IDBDataSet / IDBResultSet
description: O dataset/resultset abstrato do DataEngine — Open/Close/Next/Eof, o gotcha do NotEof que AUTO-AVANÇA o cursor, e o acesso a campos (GetFieldValue/FieldByName/Fields), com file:line.
tags: [dataengine, delphi, idbdataset, idbresultset, noteof, cursor, fields]
timestamp: 2026-07-11T00:00:00Z
---

# IDBDataSet / IDBResultSet

`IDBDataSet` é o cursor/resultset abstrato do DataEngine. `IDBResultSet` é um
**apelido do mesmo tipo** — `IDBResultSet = IDBDataSet`
(`Source/Core/DataEngine.FactoryInterfaces.pas:79-80`). Use o nome que for mais
legível; são idênticos.

## Schema — a superfície que você realmente usa

Da interface `IDBDataSet` (`Source/Core/DataEngine.FactoryInterfaces.pas:82-263`,
recorte do essencial):

```pascal
procedure Open;                                   // :160
procedure Close;                                  // :159
procedure Next;                                   // :168
procedure Prior; First; Last;                     // :169,174,175
function  Eof: Boolean;                           // :188
function  NotEof: Boolean;                        // :189  <-- LER O GOTCHA ABAIXO
function  GetFieldValue(const AFieldName: string): Variant;   // :190
function  FieldByName(const AFieldName: String): TField;      // :206
function  FindField(const AFieldName: string): TField;        // :207
function  Fields: TFields;                        // :203
function  FieldCount: UInt16;                     // :184
function  RecordCount: UInt32;                    // :186
function  State: TDataSetState;                   // :185
function  IsEmpty: Boolean;                       // :216
function  Locate(const KeyFields: String; const KeyValues: Variant;
                 Options: TLocateOptions): Boolean;           // :182
function  Lookup(const KeyFields: String; const KeyValues: Variant;
                 const ResultFields: String): Variant;        // :183
function  AsDataSet: TDataSet;                     // :222  <-- escotilha para o TDataSet nativo
property  FieldValues[const FieldName: string]: Variant read _GetFieldValue write _SetFieldValue; // :238
```

Também expõe edição (`Append`/`Insert`/`Edit`/`Post`/`Delete`/`Cancel`), cache
(`ApplyUpdates`/`CancelUpdates`), filtro (`Filter`/`Filtered`), bookmarks e todos
os eventos `Before*/After*` — é uma fachada quase completa de `TDataSet`. Para
leitura, o subconjunto acima basta.

## ⚠️ GOTCHA CENTRAL — `NotEof` AUTO-AVANÇA o cursor

`NotEof` **não** é só `not Eof`. Na base do driver
(`Source/Core/DataEngine.DriverConnection.pas:672-679`):

```pascal
function TDriverDataSetBase.NotEof: Boolean;
begin
  if FNotEofStarted then
    Next                 // <-- do 2º NotEof em diante, ANDA sozinho
  else
    FNotEofStarted := True;
  Result := not Eof;
end;
```

Ou seja: a partir da 2ª chamada, `NotEof` chama `Next` internamente. Portanto o
laço idiomático **NÃO** leva `Next`:

```pascal
// CERTO — NotEof já anda
while ADataSet.NotEof do
begin
  // ... lê a linha corrente ...
end;

// ERRADO — pula uma linha a cada iteração (NotEof anda + você anda de novo)
while ADataSet.NotEof do
begin
  // ...
  ADataSet.Next;   // <-- NÃO faça isto
end;
```

Isto está documentado na casa e citado verbatim no consumidor
(`Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas:11-12,64`):

```
// NAO chamar Next: IDBDataSet.NotEof AVANCA o cursor (gotcha da casa) — o laco
// `while NotEof do` ja anda sozinho.
```

> **Contraponto — `Eof` NÃO anda.** Se você preferir o laço clássico
> `while not ADataSet.Eof do begin … ADataSet.Next; end;`, aí SIM você mesmo
> precisa do `Next`. O erro caro é **misturar** `NotEof` com `Next`. Escolha um
> estilo: `NotEof` sem `Next`, **ou** `not Eof` com `Next`.

## Examples — os dois padrões de leitura reais (consumidor)

### Loop completo (serializar todas as linhas)

`Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas:54-70`:

```pascal
while ADataSet.NotEof do                    // NotEof anda sozinho
begin
  LObj := TJSONObject.Create;
  for LFor := 0 to ADataSet.FieldCount - 1 do
  begin
    LField := ADataSet.Fields[LFor];
    LObj.AddPair(LField.FieldName, _FieldToJson(LField));
  end;
  LArr.Add(LObj);
end;
```

### Uma única linha (scalar / primeira linha)

`Source/Shared/Estoque/Shared.Estoque.PeriodoLock.pas:44-59`:

```pascal
LDs := AConn.CreateDataSet(' SELECT EST_PERIODO_STATUS AS ST FROM EST_PERIODO WHERE ...');
try
  LDs.Open;
  if LDs.NotEof then                        // testa (e posiciona na 1ª) sem laço
  begin
    LVal := LDs.GetFieldValue('ST');
    if not (VarIsNull(LVal) or VarIsEmpty(LVal)) then
      Result := Trim(VarToStr(LVal));
  end;
finally
  LDs.Close;
end;
```

E o scalar puro (sem sequer testar `NotEof`, quando o SELECT sempre volta 1 linha),
`Source/Shared/Dao/Shared.Entity.Dao.pas:542-549`:

```pascal
LDataSet := _Connection.CreateDataSet('SELECT GEN_ID(' + AGenerator + ', 1) AS NEW_ID FROM RDB$DATABASE');
try
  LDataSet.Open;
  Result := LDataSet.GetFieldValue('NEW_ID');
finally
  LDataSet.Close;
end;
```

## Acesso a campos — `GetFieldValue` vs `FieldByName` vs `Fields`

- `GetFieldValue('COL'): Variant` — o mais direto para ler um valor; teste
  `VarIsNull`/`VarIsEmpty` (o consumidor faz — PeriodoLock:54).
- `FieldByName('COL'): TField` — quando você quer o `TField` (tipar via
  `AsInteger`/`AsString`, ou usar o `TFieldHelper.*Def` de
  [api.md](api.md)).
- `Fields[i]: TField` + `FieldCount` — iteração genérica por coluna
  (SnapshotRead:68-70).
- `AsDataSet: TDataSet` (`:222`) — escotilha para entregar o `TDataSet` nativo a
  um controle/relatório que exige `TDataSet`. Use com parcimônia: quebra o
  desacoplamento.

## Citations

- `Source/Core/DataEngine.FactoryInterfaces.pas:79-80,82-263` — `IDBResultSet = IDBDataSet` + a superfície.
- `Source/Core/DataEngine.DriverConnection.pas:672-679` — `NotEof` auto-avança (a implementação).
- `Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas:11-12,54-70` — loop `NotEof` (consumidor + comentário do gotcha).
- `Source/Shared/Estoque/Shared.Estoque.PeriodoLock.pas:44-59` — leitura de 1 linha (consumidor).
- `Source/Shared/Dao/Shared.Entity.Dao.pas:542-549` — scalar-read (consumidor).
- `delphi-dataengine-specialist.md:17` — `IDBDataSet`/`IDBResultSet` e o `NotEof`.
