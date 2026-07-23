---
type: Playbook
title: MetaDbDiff — Troubleshooting
description: Diagnóstico e correção dos erros mais caros do MetaDbDiff — driver de DDL não registrado, facade TMetaDbComparer inexistente, size/scale trocados, entidade que não entra no diff e migração aplicada sem querer.
tags: [metadbdiff, delphi, troubleshooting, debug, ddl, dialects]
timestamp: 2026-07-11T00:00:00Z
---

# Troubleshooting

Sintoma → causa-raiz → fix, com a fonte. Regras completas em [../rules.md](../rules.md).

## Exceção "O driver ??? não está registrado, adicione a unit ormbr.ddl.generator…"

- **Causa-raiz:** a unit do gerador de DDL do seu banco não está no `uses` — o
  `TSQLDriverRegister` só conhece um dialeto se a unit correspondente foi incluída
  (auto-registro no `uses`).
- **Fix:** adicione `MetaDbDiff.DDL.Generator.<Dialeto>` (ex.:
  `MetaDbDiff.DDL.Generator.Firebird`) e, para extrair metadata do banco,
  também `MetaDbDiff.Metadata.<Dialeto>`.
- Fonte: `Source/Core/MetaDbDiff.DDL.Register.pas:69-72`. Regra 6.

## Compilador não acha `TMetaDbComparer` / `MetaDbDiff.Comparer`

- **Causa-raiz:** você copiou o quick-start do `README.md`
  (`TMetaDbComparer.Create` → `CompareModelToDatabase` → `GenerateDDLScript`), mas
  essas units/tipos **não existem** nesta cópia do Source — é um facade
  documentado/pretendido, não presente.
- **Fix:** use o caminho real — `TDatabaseCompare.Create(FConnMaster, FConnTarget)`
  → `CommandsAutoExecute := False` → `BuildDatabase` → `GetCommandList` (ver
  [../api.md](../api.md) e o [../playbooks/quickstart.md](quickstart.md)).
- Fonte: `README.md:66-114` (facade) vs `Source/Core/MetaDbDiff.Database.Compare.pas`
  (real). Regra 7.

## O diff acusa `ALTER COLUMN` num numérico que "não mudou"

- **Causa provável nº 1 (size/scale):** no `[Column('c', ftFloat, APrecision,
  AScale)]`, o construtor faz `Size := Scale` — se o catálogo do banco traz um
  `Size` diferente do `Scale` do modelo, `DeepEqualsColumn` marca diferença
  (compara `Size` **e** `Precision`).
- **Fix:** garanta que precisão/escala do `[Column]` batem com o DDL vivo; entenda
  que `Column.Size` reflete a **escala** nesse overload.
- **Outras causas de falso-`ALTER`:** `NotNull`, `DefaultValue`, `AutoIncrement`,
  `SortingOrder` ou `CharSet` divergentes (`DeepEqualsColumn`). `Description` **não**
  entra no diff.
- Fonte: `Source/Core/MetaDbDiff.Mapping.Attributes.pas:642-651`,
  `Source/Core/MetaDbDiff.Database.Factory.pas:109-132`. Regras 3 e 10.

## Uma entidade não aparece no diff / catálogo do modelo vem incompleto

- **Causa A (não registrada):** faltou `TRegisterClass.RegisterEntity(T)` no
  `initialization` da unit da entidade — ou a unit não está no `uses` do projeto,
  então o `initialization` nunca roda.
- **Causa B (registro tardio):** o registro é **consumido uma vez** —
  `GetAllEntityClass` limpa a lista e `GetRepositoryMapping` cacheia o repositório.
  Registrar depois do primeiro acesso não entra.
- **Fix:** registre **todas** as entidades (units no `uses`) **antes** do primeiro
  `BuildDatabase`.
- Fonte: `Source/Core/MetaDbDiff.Mapping.Register.pas:71-82,110-113`,
  `Source/Core/MetaDbDiff.Mapping.Explorer.pas:433-439`,
  `Source/Drivers/MetaDbDiff.Metadata.Model.pas:55-62`. Regra 5.

## O comparer aplicou mudanças no banco sem eu pedir

- **Causa-raiz:** `CommandsAutoExecute` nasce **`True`** — `BuildDatabase` abre
  transação no Target e executa o DDL.
- **Fix:** `LCompare.CommandsAutoExecute := False;` **antes** de `BuildDatabase` se
  você só quer inspecionar o script via `GetCommandList`.
- Fonte: `Source/Core/MetaDbDiff.Database.Abstract.pas:77`,
  `Source/Core/MetaDbDiff.Database.Compare.pas:84-99`. Regra 8.

## Não gerou `ALTER TABLE … ADD FOREIGN KEY` no SQLite

- **Não é bug.** Ao criar tabela nova em SQLite, as FKs não são emitidas em
  comando separado (o SQLite declara FK inline no `CREATE TABLE`); o guard
  `if FDriverName <> dnSQLite` pula o `ActionCreateForeignKey` avulso.
- Fonte: `Source/Core/MetaDbDiff.Database.Factory.pas:418-420`. Regra 9.

## `[Association]`/`[ForeignKey]` estoura em runtime (EInvalidCast)

- O MetaDbDiff só **descreve** os atributos; o erro é exercitado pelo **engine de
  runtime (Janus)** quando o `[Association]` está na coluna FK escalar em vez da
  prop-objeto. Diagnóstico + caso real (sistêmico, ~127 ocorrências) estão no
  addon **delphi-janus** (troubleshooting.md daquele addon). Aqui: derive a
  multiplicidade da FK e ponha `[Association]` na prop-objeto (Regra 4).

## Citations

- `Source/Core/MetaDbDiff.DDL.Register.pas:69-72` — driver não registrado.
- `Source/Core/MetaDbDiff.Mapping.Attributes.pas:642-651` — size/scale.
- `Source/Core/MetaDbDiff.Database.Factory.pas:109-132,418-420` — diff de coluna, SQLite.
- `Source/Core/MetaDbDiff.Mapping.Register.pas:71-82,110-113` — registro consumido 1×.
- `Source/Core/MetaDbDiff.Database.Abstract.pas:77` · `Database.Compare.pas:84-99` — auto-execute.
- `README.md:66-114` — facade ausente no Source atual.
