---
type: API Reference
title: MetaDbDiff — Diff & Migração de Schema
description: O motor de comparação (modelo↔banco e banco↔banco), as regras de igualdade (DeepEqualsColumn/ForeignKey/Indexe), a ordem da geração de DDL, o wrap de desabilitar/reabilitar FKs+triggers e os dialetos suportados — transcritos do Source com file:line.
tags: [metadbdiff, delphi, schema-diff, ddl, migration, dialects, compare]
timestamp: 2026-07-11T00:00:00Z
---

# Diff & Migração de Schema

O coração do MetaDbDiff: confrontar dois **catálogos** de metadados
(`TCatalogMetadataMIK` — o `Master`/desejado e o `Target`/banco) e emitir os
comandos DDL que transformam o Target no Master. A entrada é `TDatabaseCompare`
(ver [api.md](api.md)); o algoritmo está em `TDatabaseFactory`.

## Dois modos de comparação

`README.md:19-31,120-132`:

1. **Modelo → Banco** (`Model-to-Database`): as classes Pascal decoradas e
   registradas viram o catálogo Master; o banco vivo vira o Target. O catálogo do
   modelo é montado por `TModelMetadata`, que itera
   `TMappingExplorer.GetRepositoryMapping.List.Entitys` e, para cada classe,
   monta `TTableMIK` com colunas/PK/FKs/índices/checks via os getters do explorer
   (`Source/Drivers/MetaDbDiff.Metadata.Model.pas:55-114`).
2. **Banco → Banco** (`Database-to-Database`): dois bancos físicos; ambos os
   catálogos são extraídos pelos extratores de dialeto. É o caminho direto de
   `TDatabaseCompare.Create(AConnMaster, AConnTarget)`
   (`Source/Core/MetaDbDiff.Database.Compare.pas:53-69`).

`ExtractDatabase` (`.Database.Compare.pas:115-122`) chama
`FMetadataMaster.ExtractMetadata(FCatalogMaster)` e o mesmo para o Target — cada
`TMetadataDB*` é resolvido por `TMetadataDBFactory` conforme o driver
(`.Database.Compare.pas:67-68`).

## Ordem da geração de DDL

`GenerateDDLCommands` (`Source/Core/MetaDbDiff.Database.Factory.pas:163-185`):

1. Limpa comandos e emite **desabilitar todas as FKs** e **desabilitar todas as
   triggers** (`ActionEnableForeignKeys(False)`, `ActionEnableTriggers(False)`).
2. `CompareTables` — tabelas e, dentro delas, colunas/PK/índices/checks/triggers.
3. `CompareViews` — views (só se o dialeto suporta; `SupportedFeatures`).
4. `CompareSequences` — sequences.
5. `CompareTablesForeignKeys` — FKs (depois das tabelas existirem).
6. **Reabilitar** FKs e triggers.
7. `ExecuteDDLCommands` — aplica (ou não) conforme `CommandsAutoExecute`.

O wrap disable→…→enable garante que drops/creates não esbarrem em integridade
referencial durante a migração.

## O que é comparado, e as regras de igualdade

### Tabelas — `CompareTables` (`.Database.Factory.pas:212-254`)
- Tabela no Target que **não** está no Master → `DROP TABLE`.
- Tabela no Master que **não** está no Target → `CREATE TABLE`.
- Existe nos dois → compara colunas, PK, índices, checks e triggers.

### Colunas — `CompareColumns` (`.Database.Factory.pas:332-398`)
- Coluna do Target ausente no Master → `DROP COLUMN`.
- Coluna do Master ausente no Target → `ADD COLUMN`.
- Nos dois, mas diferentes (`DeepEqualsColumn=False`) → `ALTER COLUMN`.
- Posição divergente e `ComparerFieldPosition=True` → `ALTER … POSITION`.
- DefaultValue divergente → `ALTER`/`DROP DEFAULT`.

**`DeepEqualsColumn`** (`.Database.Factory.pas:109-132`) considera diferentes se
divergir: `TypeName`, `Size`, `Precision`, `NotNull`, `AutoIncrement`,
`SortingOrder`, `DefaultValue`, `GetFieldTypeValid(FieldType)` ou `CharSet`
(quando o Master tem charset). **`Description` é ignorada** (comentada, `:130-131`).

**Equivalência de tipos — `GetFieldTypeValid`** (`.Database.Factory.pas:187-202`):
normaliza famílias de tipo antes de comparar, evitando falsos-diffs:
- `ftCurrency/ftFloat/ftBCD/ftExtended/ftSingle/ftFMTBcd` → `ftCurrency`
- `ftString/ftFixedChar/ftWideString/ftFixedWideChar/ftGuid` → `ftString`
- `ftInteger/ftShortint/ftSmallint/ftLargeint` → `ftInteger`
- `ftMemo/ftFmtMemo/ftWideMemo` → `ftMemo`

### Primary key — `ComparePrimaryKey` (`.Database.Factory.pas:636-676`)
- Nomes de PK diferentes (e Target tem PK) → `DROP PRIMARY KEY`.
- Alguma coluna da PK do Master falta na PK do Target → recria a PK.

### Foreign keys — `CompareForeignKeys` (`.Database.Factory.pas:474-507`)
- Só roda se `TSupportedFeature.ForeignKeys` está nas features do dialeto.
- FK do Target ausente no Master → `DROP FK`.
- FK divergente (`DeepEqualsForeignKey`/`FromColumns`/`ToColumns`) → drop + create.
- **⚠️ SQLite:** ao criar tabela nova, as FKs **não** são geradas separadamente —
  `if FDriverName <> dnSQLite` guarda o `ActionCreateForeignKey` da tabela nova
  (`.Database.Factory.pas:418-420`).

`DeepEqualsForeignKey` (`.Database.Factory.pas:141-152`) compara `FromTable`,
`OnDelete`, `OnUpdate` (`Description` ignorada).

### Índices — `CompareIndexes` (`.Database.Factory.pas:607-634`)
Drop dos ausentes; recria quando `DeepEqualsIndexe`/colunas divergem
(`Unique` + composição de colunas, `:154-161,558-605`).

### Sequences, views, checks, triggers
`CompareSequences` (`:678-699`), `CompareViews` (`:280-307`), `CompareChecks`
(`:309-330`), `CompareTriggers` (`:256-278`) — todas guardadas por
`SupportedFeatures` do dialeto. (Alguns ramos de trigger estão comentados no
Source — funcionalidade parcial; confirme empiricamente.)

## Aplicar ou só gerar

`ExecuteDDLCommands` (`.Database.Compare.pas:78-113`): com
`CommandsAutoExecute=True` (default), abre transação no Target, faz
`AddScript(LCommand)` para cada comando não-vazio, `ExecuteScripts` + `Commit`
(e `Rollback` + exceção detalhada em falha). Com `False`, os comandos só ficam
disponíveis em `GetCommandList` — você serializa cada um com
`LCmd.BuildCommand(GeneratorCommand)` e faz o que quiser com o SQL.

## Dialetos (drivers de DDL + metadata)

Um par **gerador de DDL** (`Source/Drivers/MetaDbDiff.DDL.Generator.<X>.pas`) +
**extrator de metadata** (`Source/Drivers/MetaDbDiff.Metadata.<X>.pas`) por banco.
Entregues nesta cópia: **Firebird, Firebird3, Interbase, MSSQL, MySQL, Oracle,
PostgreSQL, SQLite, AbsoluteDB**. O gerador se auto-registra no
`TSQLDriverRegister` ao entrar no `uses` — inclua a unit do seu banco
(`MetaDbDiff.DDL.Generator.Firebird` etc.), senão `GetDriver` levanta exceção
(ver [api.md](api.md) e [rules.md](rules.md)).

Cada gerador implementa `IDDLGeneratorCommand`
(`Source/Core/MetaDbDiff.DDL.Generator.pas:35-77`): `GenerateCreateTable`,
`GenerateCreateColumn`, `GenerateCreatePrimaryKey`, `GenerateCreateForeignKey`,
`GenerateCreateIndexe`, `GenerateAlterColumn`, `GenerateDropTable`, …,
`GenerateEnableForeignKeys`, `GenerateEnableTriggers`, além de `SupportedFeatures`
— o conjunto de recursos que aquele banco expõe (`:70-72`).

## Citations

- `Source/Core/MetaDbDiff.Database.Factory.pas:93-107,163-202,212-676` — algoritmo + regras de igualdade.
- `Source/Core/MetaDbDiff.Database.Compare.pas:53-122` — extração + execução transacional.
- `Source/Core/MetaDbDiff.DDL.Generator.pas:35-77` — contrato do gerador de DDL.
- `Source/Drivers/*` — 9 pares gerador/extrator por dialeto.
- `Source/Drivers/MetaDbDiff.Metadata.Model.pas:55-114` — catálogo do lado do modelo.
- `README.md:19-31,120-132` — os dois modos de comparação.
