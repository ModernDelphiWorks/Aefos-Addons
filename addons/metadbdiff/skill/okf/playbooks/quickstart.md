---
type: Playbook
title: MetaDbDiff — Quickstart
description: Do modelo decorado ao script DDL — decorar uma entidade com os atributos, registrá-la e rodar um diff modelo→banco, seguindo o Source e o uso real do projeto passo a passo.
tags: [metadbdiff, delphi, quickstart, mapping, schema-diff, ddl]
timestamp: 2026-07-11T00:00:00Z
---

# Quickstart — do modelo decorado ao DDL

Baseado no uso real (`Source/Modules/A01/A01_Entity.pas`) e no motor
(`.modules\MetaDbDiff\Source`). Cada passo cita a fonte.

## 1. Decore a entidade

```pascal
uses
  Classes, DB, SysUtils,
  MetaDbDiff.Mapping.Attributes,
  MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register;

type
  [Entity]
  [Table('A01_FON', '')]
  [PrimaryKey('A01_CATEGORIA', 'Chave primaria da categoria de servico')]
  TA01_FON = class
  private
    FA01_CATEGORIA: string;
    FA01_DESCRICAO: string;
  public
    [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
    [Column('A01_CATEGORIA', ftString, 3)]
    [Dictionary('A01_CATEGORIA', 'Codigo da categoria', '', '', '', taLeftJustify)]
    property A01_CATEGORIA: string read FA01_CATEGORIA write FA01_CATEGORIA;

    [Restrictions([TRestriction.NotNull])]
    [Column('A01_DESCRICAO', ftString, 30)]
    property A01_DESCRICAO: string read FA01_DESCRICAO write FA01_DESCRICAO;
  end;
```
Modelo real: `Source/Modules/A01/A01_Entity.pas:24-58`. O catálogo completo de
atributos (PK composta, FK, associação, índice, enum, cascade) está em
[../mapping-attributes.md](../mapping-attributes.md). **Reconcilie cada `[Column]`
ao DDL vivo** (Regra 1 em [../rules.md](../rules.md)).

## 2. Registre a entidade (OBRIGATÓRIO)

```pascal
initialization
  TRegisterClass.RegisterEntity(TA01_FON);
```
Fonte: `Source/Modules/A01/A01_Entity.pas:59-60`,
`Source/Core/MetaDbDiff.Mapping.Register.pas:110-113`. Sem registrar, a entidade
**não** entra no catálogo do modelo — e como o registro é consumido uma única vez,
registre **todas** antes do primeiro diff (Regra 5).

## 3. (Opcional) Leia o mapeamento por RTTI

Se você constrói um DAO/gerador genérico, leia os atributos direto:
```pascal
uses MetaDbDiff.RTTI.Helper;
...
LType := LContext.GetType(TA01_FON);
for LProp in LType.GetPropertiesOrdered do
begin
  LCol := LProp.GetColumn;                     // nil = não mapeada
  if (LCol <> nil) and LProp.IsPrimaryKey(TA01_FON) then
    …;                                          // faz parte da PK
end;
```
API completa em [../rtti-helpers.md](../rtti-helpers.md).

## 4. Rode o diff modelo→banco e obtenha o DDL

```pascal
uses
  DataEngine.FactoryInterfaces,               // IDBConnection, TDriverName
  MetaDbDiff.Database.Compare,
  MetaDbDiff.DDL.Generator.Firebird,          // registra o dialeto (Regra 6)
  MetaDbDiff.Metadata.Firebird;               // extrator do banco alvo

var
  LCompare: TDatabaseCompare;
  LCmd: TDDLCommand;
begin
  LCompare := TDatabaseCompare.Create(FConnMaster, FConnTarget);
  try
    LCompare.CommandsAutoExecute := False;    // só GERAR — não aplica no banco
    LCompare.ComparerFieldPosition := False;
    LCompare.BuildDatabase;                    // extrai catálogos + gera comandos
    for LCmd in LCompare.GetCommandList do
      Memo1.Lines.Add(LCmd.BuildCommand(LCompare.GeneratorCommand));
  finally
    LCompare.Free;
  end;
end;
```
Fonte: `Source/Core/MetaDbDiff.Database.Compare.pas:53-113`,
`Source/Core/MetaDbDiff.Database.Abstract.pas:97-105`. O algoritmo (o que é
comparado e como) está em [../schema-diff.md](../schema-diff.md).

> Para **aplicar** de fato, deixe `CommandsAutoExecute := True` (default) — aí
> `BuildDatabase` migra o Target numa transação (Regra 8). Para só inspecionar,
> `False`.

## 5. Escolha o dialeto certo

Inclua no `uses` o gerador do seu banco: `MetaDbDiff.DDL.Generator.<Dialeto>` —
disponíveis: Firebird, Firebird3, Interbase, MSSQL, MySQL, Oracle, PostgreSQL,
SQLite, AbsoluteDB (`Source/Drivers/*`). Sem a unit, `GetDriver` falha (Regra 6).

## Checklist final

- [ ] `MetaDbDiff.Mapping.Attributes` no `uses` da entidade.
- [ ] `TRegisterClass.RegisterEntity(T)` no `initialization` de **cada** entidade.
- [ ] `[Column]` reconciliado ao DDL vivo (Regra 1); atenção a `size`/`scale`
      em numéricos (Regra 3).
- [ ] Unit do dialeto (`MetaDbDiff.DDL.Generator.<X>`) no `uses` do diff (Regra 6).
- [ ] `CommandsAutoExecute := False` se você só quer o script (Regra 8).

## Citations

- `Source/Modules/A01/A01_Entity.pas:10,24-60` — decoração + registro reais.
- `Source/Core/MetaDbDiff.Mapping.Register.pas:110-113` — `RegisterEntity`.
- `Source/Core/MetaDbDiff.Database.Compare.pas:53-113` — `TDatabaseCompare` + execução.
- `Source/Core/MetaDbDiff.Database.Abstract.pas:60-105` — propriedades + `GetCommandList`.
- `Source/Drivers/*` — geradores/extratores por dialeto.
