---
type: API Reference
title: MetaDbDiff — Atributos de Mapeamento
description: Catálogo completo dos decorators de mapeamento ORM do MetaDbDiff (Entity, Table, Column, PrimaryKey, ForeignKey, Association, JoinColumn, Dictionary, Restrictions, OrderBy, Sequence, Indexe, Check, Enumeration, CascadeActions, validações) com assinatura, enums e caveats — transcritos do Source com file:line.
tags: [metadbdiff, delphi, attributes, decorators, mapping, column, primarykey, association]
timestamp: 2026-07-11T00:00:00Z
---

# Atributos de Mapeamento

Todos os decorators vivem em `MetaDbDiff.Mapping.Attributes.pas` (ponha essa unit
no `uses` da entidade, `Source/Modules/A01/A01_Entity.pas:10`). Os enums que eles
usam vivem em `MetaDbDiff.Types.Mapping.pas`. Cada atributo é uma classe que
descende de `TCustomAttribute`.

## Enums de domínio

`Source/Core/MetaDbDiff.Types.Mapping.pas:28-59`:

```pascal
TRuleAction   = (None, Cascade, SetNull, SetDefault);                 // :28
TSortingOrder = (NoSort, Ascending, Descending);                      // :29
TMultiplicity = (OneToOne, OneToMany, ManyToOne, ManyToMany);         // :30
TJoin         = (InnerJoin, LeftJoin, RightJoin, FullJoin);           // :32
TAutoIncType  = (NotInc, AutoInc);                                    // :33
TGeneratorType= (NoneInc, SequenceInc, TableInc, GuidInc,
                 Guid38Inc, Guid36Inc, Guid32Inc);                    // :34-40
TRestriction  = (NotNull, NoInsert, NoUpdate, NoValidate, Unique,
                 Hidden, VirtualData);   TRestrictions = set of …     // :41-48
TCascadeAction= (CascadeNone, CascadeAutoInc, CascadeInsert,
                 CascadeUpdate, CascadeDelete); TCascadeActions=set   // :49-54
TEnumType     = (etChar, etString, etInteger, etBoolean);             // :57
```

## Estrutura & tabela

### `[Entity]`
Marca a classe como entidade mapeada. Construtor vazio ou `(nome, schema)`
(`.Attributes.pas:49-58,850-859`). Uso: `[Entity]`
(`Source/Modules/A01/A01_Entity.pas:24`).

### `[Table]`
`Table.Create` tem 3 overloads: `()`, `(AName)`, `(AName, ADescription)`
(`.Attributes.pas:106-116,491-507`). Uso: `[Table('A01_FON', '')]`
(`A01_Entity.pas:25`).

### `[View]` / `[Trigger]` / `[Sequence]`
- `[View('nome','desc')]` — para mapear views (`.Attributes.pas:118-128`).
- `[Trigger('nome','tabela','desc')]` (`.Attributes.pas:130-142`).
- `[Sequence('nome', AInitial=0, AIncrement=1)]` — generator/sequence do banco
  para o auto-inc (`.Attributes.pas:144-155,879-884`).

### `[OrderBy]`
`[OrderBy('COL Asc')]` — ordenação default. Recebe a string bruta de colunas
(`.Attributes.pas:421-427,950-953`).

## Colunas

### `[Column]`
Três overloads (`.Attributes.pas:157-183,627-651`):

```pascal
[Column('nome', ftTipo, 'desc')]                        // sem tamanho
[Column('nome', ftTipo, ASize, 'desc')]                 // com tamanho
[Column('nome', ftTipo, APrecision, AScale, 'desc')]    // precisão + escala
```

O tipo é um `TFieldType` do RTL (`ftInteger`, `ftString`, `ftFloat`, `ftCurrency`,
`ftDateTime`, `ftDate`, `ftBlob`, `ftMemo`…). Uso real:
`[Column('A01_CATEGORIA', ftString, 3)]` (`A01_Entity.pas:35`),
`[Column('A01_DATACADASTRO', ftDateTime)]` (`A01_Entity.pas:47`).

- **⚠️ Caveat `size` vs `scale`:** no overload de precisão/escala, o construtor
  faz **`FSize := AScale`** (`.Attributes.pas:642-651`) — isto é, `Size` acaba
  igual à `Scale`, não ao `Precision`. Para colunas numéricas
  (`[Column('price', ftFloat, 18, 3)]`) trate `Precision=18`, `Scale=3` e não
  confie em `Size` para o total. Ver [rules.md](rules.md).

### `[Restrictions]`
`[Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]` — conjunto de
restrições (`.Attributes.pas:361-367,655-658`). Valores: `NotNull`, `NoInsert`,
`NoUpdate`, `NoValidate`, `Unique`, `Hidden`, `VirtualData`
(`Types.Mapping.pas:41-47`). Colunas de join/calculadas usam `NoInsert, NoUpdate`.
Uso: `[Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]`
(`A01_Entity.pas:34`).

### `[Dictionary]`
Metadados de UI/validação (título, mensagem, default, formato, máscara,
alinhamento, origem). Muitos overloads (`.Attributes.pas:369-419,527-624,1044-1072`).
Uso: `[Dictionary('A01_CATEGORIA', 'Codigo…', '', '', '', taLeftJustify)]`
(`A01_Entity.pas:36`).

### `[Enumeration]`
`[Enumeration(TEnumType.etInteger, '0, 1, 2, 9')]` — mapeia um enum Delphi para
os valores da coluna; valida cada valor (só `A-Z`/`0-9`, maiúsculo) no construtor
(`.Attributes.pas:429-439,987-1028`). `TEnumType = etChar | etString | etInteger
| etBoolean` (`Types.Mapping.pas:57`).

### `[CalcField]` / `[AggregateField]`
- `[CalcField('nome', ftTipo, ASize=0, AHidden=False)]` — campo calculado de
  dataset (`.Attributes.pas:207-220`).
- `[AggregateField('AGG', 'SUM(PRICE)', taRightJustify, '#,##0.00')]` — agregação
  no nível da entidade (`.Attributes.pas:188-202`).

## Chaves & índices

### `[PrimaryKey]`
Overloads (`.Attributes.pas:272-299,794-846`):

```pascal
[PrimaryKey('COL', 'descrição')]                                  // simples
[PrimaryKey('COL', TAutoIncType.AutoInc,
            TSortingOrder.NoSort, AUnique, 'desc')]               // com auto-inc
[PrimaryKey('COL', TAutoIncType.AutoInc, TGeneratorType.SequenceInc,
            TSortingOrder.NoSort, AUnique, 'desc')]               // + gerador
```

- **PK composta é nativa:** passe as colunas separadas por `,` ou `;` numa única
  string — o construtor as separa com `ExtractStrings` em `TArray<String>`
  (`.Attributes.pas:826-840`). Ex.: `[PrimaryKey('DETAIL_ID; MASTER_ID', 'PK')]`.
- Uso real (simples, PK natural sem gerador):
  `[PrimaryKey('A01_CATEGORIA', 'Chave primaria…')]` (`A01_Entity.pas:26`).

### `[Indexe]`
`[Indexe('IDX_NOME', 'COL1;COL2', TSortingOrder.NoSort, AUnique, 'desc')]`
(`.Attributes.pas:301-319,907-937`). Colunas também separadas por `,`/`;`.

### `[Check]`
`[Check('CK_NOME', 'condição SQL', 'desc')]` (`.Attributes.pas:321-331,941-946`).

## Relacionamentos

> A **posição** dos atributos de relacionamento importa: `[Association]` vai na
> **propriedade-objeto** (nav), `[ForeignKey]` na **coluna FK escalar**. Errar
> isso é bug clássico (herdado do padrão que o Janus exercita) — ver
> [rules.md](rules.md) e, no runtime, o addon delphi-janus.

### `[ForeignKey]` — na coluna FK escalar
```pascal
[ForeignKey(AName, AFromColumns, ATableNameRef, AToColumns,
            ARuleDelete=None, ARuleUpdate=None, ADescription='')]
```
`.Attributes.pas:249-270,752-790`. `FromColumns`/`ToColumns` aceitam múltiplas
colunas separadas por `,`/`;` (FK composta). As regras `ARuleDelete`/`ARuleUpdate`
são `TRuleAction` (`None | Cascade | SetNull | SetDefault`,
`Types.Mapping.pas:28`) e viram `ON DELETE`/`ON UPDATE` no DDL.

### `[Association]` — na propriedade-objeto (nav)
```pascal
[Association(AMultiplicity, AColumnsName, ATableNameRef, AColumnsNameRef,
             ALazy=False)]
```
`.Attributes.pas:223-239,678-716`. `TMultiplicity = OneToOne | OneToMany |
ManyToOne | ManyToMany` (`Types.Mapping.pas:30`). As colunas locais e remotas
aceitam listas (`,`/`;`) → associação por chave composta. `ALazy=True` sinaliza
carregamento preguiçoso.

### `[CascadeActions]` — no lado da coleção
`[CascadeActions([TCascadeAction.CascadeInsert, TCascadeAction.CascadeUpdate,
TCascadeAction.CascadeDelete, TCascadeAction.CascadeAutoInc])]`
(`.Attributes.pas:241-247,980-983`). `CascadeNone` = sem propagação
(`Types.Mapping.pas:49-54`).

### `[JoinColumn]` — trazer 1 coluna sem materializar o objeto
```pascal
[JoinColumn(AColumnName, ARefTableName, ARefColumnName, ARefColumnNameSelect,
            AJoin=TJoin.InnerJoin [, AAliasColumn [, AAliasRefTable]])]
```
`.Attributes.pas:334-359,720-748`. O construtor **força lowercase** em todos os
nomes e, se o alias da tabela ref vier vazio, usa o próprio nome da tabela
(`.Attributes.pas:724-733`). `TJoin = InnerJoin | LeftJoin | RightJoin |
FullJoin` (`Types.Mapping.pas:32`).

## Validações (constraints em runtime)

Atributos que carregam `Validate(...)` (`.Attributes.pas:449-487`):

- `[NotNullConstraint]` — `Validate(ADisplayLabel, AValue)` levanta `EFieldNotNull`
  se string vazia (`:449-453,662-674`).
- `[MinimumValueConstraint(AValue)]` / `[MaximumValueConstraint(AValue)]` —
  faixa numérica (`:455-469,863-875,1121-1133`).
- `[NotEmpty]` — valida por `TypeKind` (string/float/int) (`:474-478,1137-1161`).
- `[Size(Max, Min=0)]` — comprimento de string (`:480-487,1165-1178`).
- `[NullIfEmpty]` — marcador (`:471-472`).

## Atributos REST/servidor (metadados de exposição)

`[Resource('nome')]`, `[SubResource('nome')]`, `[NotServerUse]`, `[RESTReadOnly]`,
`[RESTAllowGET]`, `[RESTAllowPOST]`, `[RESTAllowPUT]`, `[RESTAllowDELETE]`
(`.Attributes.pas:60-104`). Controlam se/como a entidade é exposta por uma camada
REST que consome o mapeamento (o cache `TRESTAllowVerbCache` está em
`.Attributes.pas:39-42`; leitura em `TMappingExplorer.GetRESTAllowVerbs`).

## Citations

- `Source/Core/MetaDbDiff.Mapping.Attributes.pas:39-487` — declaração de todos os atributos.
- `Source/Core/MetaDbDiff.Mapping.Attributes.pas:627-716,752-846,907-1028` — construtores (parsing de colunas, size/scale, enum).
- `Source/Core/MetaDbDiff.Types.Mapping.pas:28-59` — enums de domínio.
- `Source/Modules/A01/A01_Entity.pas:24-58` — uso real dos atributos numa entidade.
