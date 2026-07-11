---
type: API Reference
title: MetaDbDiff — Helpers RTTI
description: Os class helpers de TRttiProperty/TRttiType/TRttiField/TObject que leem o mapeamento em runtime (GetColumn, GetPrimaryKey, IsNullable, IsAssociation, GetAssociation, GetCascadeActions, GetNullableValue, GetPropertiesOrdered) — transcritos do Source com file:line.
tags: [metadbdiff, delphi, rtti, helpers, reflection, nullable, association]
timestamp: 2026-07-11T00:00:00Z
---

# Helpers RTTI

`MetaDbDiff.RTTI.Helper.pas` define class helpers que **leem os atributos de
mapeamento** de uma propriedade/tipo em runtime. São a ponte entre os decorators
(ver [mapping-attributes.md](mapping-attributes.md)) e qualquer engine que os
consome (o Janus, um DAO genérico, um gerador). Ponha
`MetaDbDiff.RTTI.Helper` no `uses` para ativá-los.

## `TRttiPropertyHelper` — ler o mapeamento de UMA propriedade

`Source/Core/MetaDbDiff.RTTI.Helper.pas:70-118`.

### Obter o atributo em si

```pascal
LCol := LProp.GetColumn;               // Column ou nil se não mapeada     :169
LAssoc := LProp.GetAssociation;        // TArray<Association> (0..1)         :130
LCasc  := LProp.GetCascadeActions;     // TCascadeActions (default [CascadeNone]) :157
LDict  := LProp.GetDictionary;         // Dictionary ou nil                  :181
LRestr := LProp.GetRestriction;        // Restrictions ou nil                :386
LCalc  := LProp.GetCalcField;          // CalcField ou nil                   :145
```

Cada um varre `Self.GetAttributes` e devolve o primeiro do tipo (ou `nil`/default).
Ex.: `GetColumn` (`:169-179`) — `for LAttribute in Self.GetAttributes do if
LAttribute is Column then Exit(Column(LAttribute))`. Para a coluna, leia
`Column(LProp.GetColumn).ColumnName` etc. (`:718-722`).

### Testes booleanos de restrição/tipo

```pascal
LProp.IsNotNull       // TRestriction.NotNull no set                   :594
LProp.IsNoUpdate      // NoUpdate                                      :607
LProp.IsNoInsert      // NoInsert                                      :545
LProp.IsUnique        // Unique                                        :748
LProp.IsHidden        // Hidden                                        :532
LProp.IsVirtualData   // VirtualData                                   :519
LProp.IsNoValidate    // NoValidate                                    :735
LProp.IsJoinColumn    // tem [JoinColumn]                              :558
LProp.IsCheck         // tem [Check]                                   :485
LProp.IsCalcField     // tem [CalcField]                               :473
LProp.IsAssociation   // tem [Association]                             :450
LProp.IsNullIfEmpty   // tem [NullIfEmpty]                             :631
LProp.IsPrimaryKey(AClass)  // a coluna está na PK da classe           :709
```

`IsPrimaryKey` cruza o nome da coluna (`GetColumn.ColumnName`) contra a PK obtida
via `TMappingExplorer.GetMappingPrimaryKey(AClass)` (`:709-722`).

### Tipos por forma (record/genérico)

Testes por `PropertyType.Handle` + nome do tipo:

```pascal
LProp.IsNullable   // 'Nullable<' … tkRecord                          :620
LProp.IsBlob       // 'TBlob' … tkRecord                              :462
LProp.IsDate       // contém 'TDate'                                  :497
LProp.IsDateTime   // contém 'TDateTime'                              :508
LProp.IsTime       // contém 'TTime'                                  :724
LProp.IsLazy       // 'Lazy' … tkRecord                               :570
LProp.IsList       // 'TObjectList<' ou 'TList<' no ToString          :581
```

### Valor de `Nullable<T>` por reflexão

`GetNullableValue(AInstance)` (`:338-368`) lê os campos internos `FHasValue` e
`FValue` do record `Nullable<>`: se `FHasValue=False`, devolve `Variant(Null)`;
senão, o `FValue`. `IsNullValue(AObject)` (`:696-707`) combina isso com
`IsNotNull`/`IsNullable`/`IsNullIfEmpty` para decidir se o valor efetivo é nulo
(usado na serialização/geração de SQL para omitir a coluna). ⚠️ depende dos nomes
de campo `FHasValue`/`FValue` do `Nullable<T>` — se o tipo mudar, quebra.

### Enums → valor da coluna

`GetEnumToFieldValue(AInstance, AFieldType)` (`:247-289`) converte o valor ordinal
da propriedade enum no valor mapeado por `[Enumeration]`, respeitando
`ftFixedChar`/`ftString`/`ftInteger`/`ftBoolean`; consulta
`TMappingExplorer.GetMappingEnumeration`. `GetEnumIntegerValue`/`GetEnumStringValue`
fazem o caminho inverso (valor da coluna → ordinal, `:201-245`).

### Cascade helper

`IsNotCascade` (`:434-448`) — `True` se a associação tem `TCascadeAction.CascadeNone`
no conjunto de `GetCascadeActions`.

## `TRttiTypeHelper` — ler o mapeamento de UM tipo

`Source/Core/MetaDbDiff.RTTI.Helper.pas:55-61`.

```pascal
LType.GetPrimaryKey     // TArray<TCustomAttribute> — todos os [PrimaryKey]  :781
LType.GetAggregateField // TArray<TCustomAttribute> — todos os [AggregateField] :763
LType.IsList            // 'TObjectList<'/'TList<' no nome                    :799
LType.GetPropertiesOrdered  // props declaradas, base→derivada (ordem estável) :882
```

- `GetPrimaryKey` acumula **todos** os atributos `PrimaryKey` do tipo (suporta a
  declaração de PK composta como vários `[PrimaryKey]`) — leia
  `PrimaryKey(LAttr).Columns` para as colunas (`:781-797`).
- `GetPropertiesOrdered` (`:882-898`) sobe a hierarquia (`BaseType`) e concatena
  na ordem base→derivada via `TArrayHelper.ConcatReverse<T>` (`:900-917`) — útil
  para gerar SQL com colunas em ordem determinística.

## `TRttiFieldHelper` e `TObjectHelper`

- `TRttiFieldHelper.IsLazy` (`:869`), `GetLazyValue` (`:834`, resolve o `T` de
  `Lazy<T>`), `GetTypeValue` (`:851`, resolve o `T` de `TObjectList<T>`/`TList<T>`).
- `TObjectHelper.MethodCall(AMethodName, AParameters)` (`:812-830`) — invoca um
  método por RTTI (usado para instanciar/`Create` objetos de lista, ex.
  `GetObjectTheList`, `:370-384`).

## Padrão de uso típico

```pascal
uses MetaDbDiff.RTTI.Helper, MetaDbDiff.Mapping.Attributes;

LType := LContext.GetType(TA01_FON);
for LProp in LType.GetPropertiesOrdered do
begin
  LCol := LProp.GetColumn;
  if LCol = nil then Continue;                 // não mapeada → pula
  if LProp.IsPrimaryKey(TA01_FON) then …;      // faz parte da PK?
  if LProp.IsNullable and LProp.IsNullValue(AInstance) then …; // valor nulo?
end;
```

## Citations

- `Source/Core/MetaDbDiff.RTTI.Helper.pas:55-118` — declaração dos helpers.
- `Source/Core/MetaDbDiff.RTTI.Helper.pas:130-179,338-368,462-707` — getters/testes de propriedade.
- `Source/Core/MetaDbDiff.RTTI.Helper.pas:709-722` — `IsPrimaryKey` cruza com o explorer.
- `Source/Core/MetaDbDiff.RTTI.Helper.pas:763-798,882-917` — helpers de tipo e ordenação.
- `Source/Core/MetaDbDiff.RTTI.Helper.pas:812-878` — `MethodCall`, field/lazy helpers.
- `delphi-metadbdiff-specialist.md:17` — `GetColumn`/`GetPrimaryKey`/`Columns` como pontos de entrada.
