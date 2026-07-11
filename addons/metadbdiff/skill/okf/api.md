---
type: API Reference
title: MetaDbDiff — API do Motor
description: As unidades públicas do MetaDbDiff — registro de entidade (TRegisterClass), leitura cacheada do mapeamento (TMappingExplorer), comparação de schema (TDatabaseCompare) e registro de drivers de DDL (TSQLDriverRegister) — transcritas do Source com file:line, mais a nota sobre o facade do README.
tags: [metadbdiff, delphi, api, register, explorer, compare, drivers]
timestamp: 2026-07-11T00:00:00Z
---

# MetaDbDiff — API do Motor

Tudo aqui é transcrito de `.modules\MetaDbDiff\Source`. Esta doc cobre a
**superfície programática** (as classes que você chama); o catálogo de atributos
está em [mapping-attributes.md](mapping-attributes.md), os helpers RTTI em
[rtti-helpers.md](rtti-helpers.md) e o algoritmo de comparação em
[schema-diff.md](schema-diff.md).

## Schema — `TRegisterClass`: registrar entidades

Para que o motor conheça uma classe, registre-a (normalmente no `initialization`
da unit da entidade):

```pascal
TRegisterClass.RegisterEntity(TA01_FON);   // OBRIGATÓRIO
TRegisterClass.RegisterView(TMinhaView);
TRegisterClass.RegisterTrigger(TMinhaTrigger);
```
Fonte: `Source/Core/MetaDbDiff.Mapping.Register.pas:44-46,110-126`. Uso real:
`Source/Modules/A01/A01_Entity.pas:59-60`.

- `RegisterEntity` é idempotente — só adiciona se ainda não estiver na lista
  (`.Register.pas:110-113`).
- **Gotcha (consumo único):** `GetAllEntityClass` **esvazia a lista** após
  devolvê-la (`finally FEntitys.Clear;`, `.Register.pas:71-82`). Quem consome o
  registro é o `TMappingExplorer.GetRepositoryMapping`, que constrói o
  repositório **uma vez** e o cacheia
  (`Source/Core/MetaDbDiff.Mapping.Explorer.pas:433-439`). Consequência: registre
  **todas** as entidades **antes** do primeiro diff. Ver [rules.md](rules.md).

## Schema — `TMappingExplorer`: ler o mapeamento (cacheado)

`Source/Core/MetaDbDiff.Mapping.Explorer.pas:42-93`. Fachada `class` estática que
traduz uma `TClass` decorada em objetos de mapeamento, **cacheando por
`ClassName`**. Métodos principais (todos `class function ...(const AClass: TClass)`):

```pascal
GetMappingTable        : TTableMapping;              // :355
GetMappingColumn       : TColumnMappingList;         // :223
GetMappingPrimaryKey   : TPrimaryKeyMapping;         // :153
GetMappingForeignKey   : TForeignKeyMappingList;     // :264
GetMappingAssociation  : TAssociationMappingList;    // :341
GetMappingJoinColumn   : TJoinColumnMappingList;     // :292
GetMappingIndexe       : TIndexeMappingList;         // :278
GetMappingCheck        : TCheckMappingList;          // :209
GetMappingSequence     : TSequenceMapping;           // :181
GetMappingOrderBy      : TOrderByMapping;            // :327
GetMappingEnumeration  : TEnumerationMappingList;    // :236
GetMappingTrigger      : TTriggerMappingList;        // :369
GetMappingView         : TViewMapping;               // :383
GetRepositoryMapping   : TMappingRepository;         // :433 (consome o registro 1x)
```

Cada getter segue o mesmo padrão: se já está no dicionário de cache, retorna;
senão, pega o `TRttiType` via `TRttiContext.GetType(AClass)`, chama o
`TMappingPopular` correspondente e guarda no cache
(ex. `GetMappingPrimaryKey`, `.Explorer.pas:153-165`). O contexto RTTI e todos os
dicionários são criados no `initialization` da unit
(`TMappingExplorer.ExecuteCreate`, `.Explorer.pas:99-123,441-446`).

> Para ler o mapeamento **sem** passar pelo explorer (direto na propriedade), use
> os helpers RTTI de [rtti-helpers.md](rtti-helpers.md).

## Schema — `TDatabaseCompare`: comparar & migrar

`Source/Core/MetaDbDiff.Database.Compare.pas:32-44`. É a entrada real do diff
**banco↔banco** (e a base do fluxo modelo↔banco). Recebe duas conexões
DataEngine já resolvidas:

```pascal
uses
  DataEngine.FactoryInterfaces,           // IDBConnection, TDriverName
  MetaDbDiff.Database.Compare,
  MetaDbDiff.DDL.Generator.Firebird;      // registra o dialeto no uses (ver drivers)

var
  LCompare: TDatabaseCompare;             // é um TInterfacedObject (IDatabaseCompare)
begin
  LCompare := TDatabaseCompare.Create(FConnMaster, FConnTarget);
  try
    LCompare.CommandsAutoExecute := False;   // só GERAR o DDL, não aplicar
    LCompare.ComparerFieldPosition := False; // ignorar reordenação de colunas
    LCompare.BuildDatabase;                  // extrai catálogos + gera comandos
    for LCmd in LCompare.GetCommandList do
      Memo1.Lines.Add(LCmd.BuildCommand(LCompare.GeneratorCommand));
  finally
    LCompare.Free;
  end;
end;
```

- **`Create(AConnMaster, AConnTarget)`** conecta as duas conexões e falha cedo se
  qualquer uma não conectar; resolve o driver a partir de
  `AConnMaster.GetDriver` (`.Database.Compare.pas:53-69`). `Master` = a estrutura
  desejada (fonte da verdade); `Target` = o banco que será ajustado.
- **`BuildDatabase`** (herdado, `Source/Core/MetaDbDiff.Database.Factory.pas:93-107`)
  cria os catálogos `TCatalogMetadataMIK`, chama `ExtractDatabase` e
  `GenerateDDLCommands`, e libera os catálogos no fim.
- **`GetCommandList: TArray<TDDLCommand>`** devolve os comandos gerados; cada um
  vira SQL via `TDDLCommand.BuildCommand(FGeneratorCommand)`
  (`.Database.Abstract.pas:97-105`, `.Database.Compare.pas:90`).
- **`GeneratorCommand: IDDLGeneratorCommand`** é o gerador do dialeto ativo
  (`.Database.Abstract.pas:92-95`).

### Propriedades (contrato `IDatabaseCompare`)

`Source/Core/MetaDbDiff.Database.Interfaces.pas:34-47`,
`Source/Core/MetaDbDiff.Database.Abstract.pas:60-84`:

- **`CommandsAutoExecute: Boolean`** — default **`True`**
  (`.Database.Abstract.pas:77`). Com `True`, `ExecuteDDLCommands` abre transação
  no target, faz `AddScript`/`ExecuteScripts`/`Commit` (rollback em exceção) —
  ou seja, **aplica o DDL no banco** (`.Database.Compare.pas:78-113`). Ponha
  **`False`** para só coletar o script via `GetCommandList` sem tocar no banco.
- **`ComparerFieldPosition: Boolean`** — default **`False`**
  (`.Database.Abstract.pas:80`). Se `True`, também gera `ALTER … POSITION` quando
  a ordem das colunas diverge (`.Database.Factory.pas:393-397`).

## Schema — `TSQLDriverRegister`: drivers de DDL

`Source/Core/MetaDbDiff.DDL.Register.pas:34-48`. Singleton
(`GetInstance`, `:82-88`) que mapeia `TDriverName → IDDLGeneratorCommand`. Cada
unit `MetaDbDiff.DDL.Generator.<Dialeto>` se **auto-registra** ao ser incluída no
`uses`. Se o dialeto não estiver registrado, `GetDriver` **levanta exceção**
pedindo para adicionar a unit ao `uses` (`.DDL.Register.pas:69-72`) — é o erro
"driver não registrado" (ver [rules.md](rules.md)).

`TDriverName` (do DataEngine) enumera os bancos:
`dnMSSQL, dnMySQL, dnFirebird, dnSQLite, dnInterbase, dnDB2, dnOracle,
dnInformix, dnPostgreSQL, dnADS, dnASA, dnFirebase, dnFirebird3, dnAbsoluteDB,
dnMongoDB, dnElevateDB, dnNexusDB, dnMariaDB, dnMemory`
(`DataEngine.FactoryInterfaces.pas:50-53`). Os geradores DDL **entregues** cobrem:
Firebird, Firebird3, Interbase, MSSQL, MySQL, Oracle, PostgreSQL, SQLite,
AbsoluteDB (`Source/Drivers/MetaDbDiff.DDL.Generator.*`). Ver
[schema-diff.md](schema-diff.md).

## ⚠️ Nota — o facade do README ainda não existe nesta cópia

O `README.md:66-114` documenta uma API de fachada:

```pascal
FComparer := TMetaDbComparer.Create(FConn);          // IMetaDbComparer
FDelta    := FComparer.CompareModelToDatabase;        // IMetaDbDelta
if FDelta.HasDifferences then
  FSQLScript := FDelta.GenerateDDLScript;
```

Essas units/tipos (`MetaDbDiff.Comparer`, `MetaDbDiff.Interfaces`,
`TMetaDbComparer`, `IMetaDbComparer`, `IMetaDbDelta`) **não estão presentes** no
`Source` desta cópia (busca por `*Comparer*`/facade não retornou unit). O que
existe e funciona é `TDatabaseCompare` descrito acima. Trate o exemplo do README
como **API pretendida/documentada**, não como o caminho atual — confirme com a
equipe do framework antes de codar contra ele. Ver TODO em [rules.md](rules.md).

## Citations

- `Source/Core/MetaDbDiff.Mapping.Register.pas:44-126` — `TRegisterClass`.
- `Source/Core/MetaDbDiff.Mapping.Explorer.pas:42-93,99-123,153-165,433-446` — `TMappingExplorer`.
- `Source/Core/MetaDbDiff.Database.Compare.pas:32-122` — `TDatabaseCompare`.
- `Source/Core/MetaDbDiff.Database.Factory.pas:93-107,393-397` — `BuildDatabase`, position.
- `Source/Core/MetaDbDiff.Database.Abstract.pas:40-125` — propriedades e `GetCommandList`.
- `Source/Core/MetaDbDiff.Database.Interfaces.pas:34-47` — `IDatabaseCompare`.
- `Source/Core/MetaDbDiff.DDL.Register.pas:34-88` — `TSQLDriverRegister`.
- `DataEngine.FactoryInterfaces.pas:50-53` — `TDriverName`.
- `README.md:66-114` — facade documentado (ausente no Source atual).
- `Source/Modules/A01/A01_Entity.pas:59-60` — registro real.
