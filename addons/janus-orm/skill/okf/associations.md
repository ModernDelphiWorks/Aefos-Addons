---
type: API Reference
title: Janus ORM — Associações, FK & Cascade
description: Como mapear [Association], [ForeignKey], [JoinColumn] e [CascadeActions]; multiplicidade a partir da FK; e como o Janus preenche as associações.
tags: [janus, orm, delphi, association, foreignkey, cascade, joincolumn]
timestamp: 2026-07-11T00:00:00Z
---

# Associações, FK & Cascade

O Janus resolve relacionamentos por meio de atributos na **propriedade-objeto**
(o navegador), não na coluna FK escalar. Errar essa posição é o bug mais caro do
framework — ver [rules.md](rules.md) e [troubleshooting.md](playbooks/troubleshooting.md).

## Schema — os quatro atributos

### `[ForeignKey]` — na coluna FK escalar

```pascal
[Column('client_id', ftInteger)]
[ForeignKey('FK_IDCLIENT', 'client_id', 'client', 'client_id')]
property client_id: Nullable<Integer> read Fclient_id write Fclient_id;
```
Fonte: `Examples/Delphi/RESTful/Horse/models/Janus.Model.Master.pas:91-94`.
Assinatura: `[ForeignKey(nome, colunaLocal, tabelaRef, colunaRef [, onUpdate, onDelete])]`.
A forma com regras de integridade referencial:
```pascal
[ForeignKey('FK_IDMASTER', 'master_id', 'master', 'master_id',
            TRuleAction.Cascade, TRuleAction.Cascade)]
```
Fonte: `.../Janus.Model.Detail.pas:60`. `TRuleAction` = `None | Cascade | …` (na
DDL gerada, ON UPDATE / ON DELETE).

### `[Association]` — na propriedade-OBJETO (nav)

```pascal
// 1:1 — objeto único
[Association(TMultiplicity.OneToOne, 'client_id', 'client', 'client_id')]
property client: Tclient read Fclient write Fclient;

// 1:N — coleção
[Association(TMultiplicity.OneToMany, 'master_id', 'detail', 'master_id')]
[CascadeActions([TCascadeAction.CascadeAutoInc,
                 TCascadeAction.CascadeInsert,
                 TCascadeAction.CascadeUpdate,
                 TCascadeAction.CascadeDelete])]
property detail: TObjectList<Tdetail> read Fdetail write Fdetail;
```
Fonte: `.../Janus.Model.Master.pas:110-118`. Assinatura:
`[Association(TMultiplicity, colunaLocal, tabelaRef, colunaRef)]`.

`TMultiplicity` = `OneToOne | ManyToOne | OneToMany | ManyToMany`
(usado em `Source/Core/Janus.Command.Executor.pas:221-227`).

### `[JoinColumn]` — trazer 1 coluna sem materializar o objeto

```pascal
[Column('client_name', ftString, 60)]
[JoinColumn('client_id', 'client', 'client_id', 'client_name', TJoin.InnerJoin)]
[Restrictions([TRestriction.NoInsert, TRestriction.NoUpdate])]
property client_name: String read fclient_name write fclient_name;
```
Fonte: `.../Janus.Model.Master.pas:104-108`. Use quando quer só um rótulo
(`client_name`) e não o objeto `client` inteiro — mais barato que uma associação.

## Regra de OURO — multiplicidade vem da cardinalidade da FK

**Uma FK escalar única ⇒ `OneToOne` + propriedade objeto único** (`Tclient`), NÃO
`TObjectList<>`. Só use `TObjectList<>` (`OneToMany`) quando o lado remoto tem
muitos por um (`detail` por `master`). Não copie a multiplicidade do `[Association]`
do legado cegamente — derive-a da FK (`delphi-janus-specialist.md:32`).

## Como o Janus preenche as associações (Source)

`FillAssociation` (`Source/Core/Janus.Command.Executor.pas:201-230`) roda por
objeto materializado e, para cada associação mapeada:

- Ignora tudo se o driver é NoSQL/MongoDB (linha 207).
- Se `Lazy` → injeta factory preguiçosa e segue (linha 216-220).
- `OneToOne`/`ManyToOne` → `ExecuteOneToOne` (linha 221-223).
- `OneToMany`/`ManyToMany` → `ExecuteOneToMany` (linha 225-227).

`ExecuteOneToOne` (linha 319) e `ExecuteOneToMany` (linha 354) usam
`AProperty.PropertyType.AsInstance.MetaclassType` (linha 328 / 373) para
instanciar o objeto associado. **Isso exige que a propriedade seja de tipo
CLASSE.** Se o `[Association]` estiver numa `string`/`Integer`/`Nullable<>`, o
`AsInstance` lança `EInvalidCast` — a causa-raiz do bug em [rules.md](rules.md).

Só entidades **com** `[Association]` entram em `FillAssociation`. Entidades sem
associação (lookups simples, single-PK sem nav) leem normalmente e nunca
exercitam esse caminho (`delphi-janus-specialist.md:30`, `:36`).

## Cascade

`[CascadeActions([...])]` no lado da coleção controla o que se propaga do mestre
para os detalhes: `CascadeAutoInc`, `CascadeInsert`, `CascadeUpdate`,
`CascadeDelete` (`.../Janus.Model.Master.pas:114-117`).

> **Master-detail agrupado NEM sempre quer cascade Janus.** No ERP do dono, stacks
> CRUD independentes por entidade (master single-PK + detalhes composite-PK)
> preferiram NÃO usar cascade e converter cada nível pelo DAO genérico. Decida
> pelo caso; cascade é opcional (nota de projeto, não do framework).

## Citations

- `Examples/Delphi/RESTful/Horse/models/Janus.Model.Master.pas:91-118` — FK, Association, JoinColumn, Cascade.
- `Examples/Delphi/RESTful/Horse/models/Janus.Model.Detail.pas:58-66` — FK com TRuleAction.
- `Source/Core/Janus.Command.Executor.pas:201-230` — FillAssociation.
- `Source/Core/Janus.Command.Executor.pas:319-352,354-387` — ExecuteOneToOne/Many + AsInstance.MetaclassType.
- `delphi-janus-specialist.md:32,36` — multiplicidade a partir da FK; associação na prop-objeto.
