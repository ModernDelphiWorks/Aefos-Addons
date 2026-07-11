---
type: API Reference
title: Janus ORM — Referência Técnica
description: Decorators de mapeamento, a interface IContainerObjectSet<M> (contrato de CRUD) e a API TJanusJson, transcritos do código real com file:line.
tags: [janus, orm, delphi, decorators, crud, json, api]
timestamp: 2026-07-11T00:00:00Z
---

# Janus ORM — Referência Técnica

Tudo aqui é transcrito de `.modules\Janus\Examples` e `.modules\Janus\Source`. Os
atributos de mapeamento vêm da unidade `MetaDbDiff.mapping.attributes` (usada em
todo modelo, ex. `Examples/Delphi/RESTful/Horse/models/Janus.Model.Master.pas:31`).

## Schema — Decorators de mapeamento

### Entidade e tabela

```pascal
[Entity]
[Table('master','')]                                   // (nome, schema)
[PrimaryKey('master_id', TAutoIncType.AutoInc,
                         TGeneratorType.SequenceInc,
                         TSortingOrder.NoSort,
                         True, 'Chave primária')]
[Sequence('master')]
[OrderBy('master_id')]
Tmaster = class
```
Fonte: `Examples/Delphi/RESTful/Horse/models/Janus.Model.Master.pas:44-52`.

- `[Entity]` marca a classe como entidade mapeada.
- `[Table('nome','schema')]` — tabela física; schema vazio = default.
- `[PrimaryKey(...)]` — chave primária. Há uma sobrecarga **rica** (auto-inc,
  gerador, ordenação) e uma **simples** `[PrimaryKey('client_id', 'Chave primária')]`
  (`Examples/Delphi/RESTful/Horse/models/Janus.Model.Client.pas:40`).
- `[Sequence('master')]` — sequência/generator do banco para o auto-inc.
- `[OrderBy('master_id')]` — ordenação default do `Find`. Aceita `Desc`:
  `[OrderBy('client_id Desc')]` (`.../Janus.Model.Client.pas:42`).
- `[Indexe('idx_client_name','client_name')]` — índice
  (`.../Janus.Model.Client.pas:41`).

Ao final da unit, registre a entidade:
```pascal
initialization
  TRegisterClass.RegisterEntity(Tmaster);
```
Fonte: `.../Janus.Model.Master.pas:198-199`. **Obrigatório** — sem registrar, o
Janus não conhece a entidade.

### Colunas

```pascal
[Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
[Column('master_id', ftInteger)]
[Dictionary('master_id','Mensagem de validação','-1','','',taCenter)]
property master_id: Integer read Fmaster_id write Fmaster_id;

[Column('description', ftString, 60)]                       // (nome, tipo, tamanho)
property description: Nullable<String> read Fdescription write Fdescription;

[Column('price', ftFloat, 18, 3)]                           // (nome, tipo, prec, escala)
property price: Double read Fprice write Fprice;
```
Fontes: `.../Janus.Model.Master.pas:71-78`, `.../Janus.Model.Detail.pas:74-77`.

- `[Column('nome', ftTipo [, tamanho [, escala]])]` — o tipo é um `TFieldType`
  do RTL (`ftInteger`, `ftString`, `ftFloat`, `ftDateTime`, `ftDate`, `ftBlob`…).
- `[Restrictions([...])]` — `TRestriction.NotNull`, `NoInsert`, `NoUpdate`.
  Colunas calculadas/join usam `NoInsert, NoUpdate`
  (`.../Janus.Model.Master.pas:104-105`).
- `[Dictionary(...)]` — metadados de UI (título, máscara, alinhamento).
- **Nullable:** use `Nullable<T>` para colunas anuláveis
  (`.../Janus.Model.Master.pas:78`, tipo em `Source/Core/Janus.Types.Nullable.pas`).
- **Enum:** `[Enumeration(TEnumType.etInteger, '0, 1, 2, 9')]` mapeia um enum
  Delphi para valores da coluna (`.../Janus.Model.Master.pas:96-98`); há também
  `etBoolean` e `etChar`.
- **Blob:** `[Column('foto', ftBlob)]` sobre uma propriedade `TBlob`
  (`Source/Core/Janus.Types.Blob.pas`; ex. comentado em `.../Janus.Model.Client.pas:60`).

### Campos de join e agregação (read-only)

```pascal
[Restrictions([TRestriction.NoInsert, TRestriction.NoUpdate])]
[Column('client_name', ftString, 60)]
[JoinColumn('client_id', 'client', 'client_id', 'client_name', TJoin.InnerJoin)]
property client_name: String read fclient_name write fclient_name;
```
Fonte: `.../Janus.Model.Master.pas:104-108`. `[JoinColumn(fkLocal, tabela,
pkRemota, colunaTrazida, TJoin.InnerJoin|LeftJoin)]` traz uma coluna de outra
tabela via join, sem materializar o objeto associado.

Agregação no nível da entidade:
`[AggregateField('AGGPRICE', 'SUM(PRICE)', taRightJustify, '#,###,##0.00')]`
(`.../Janus.Model.Detail.pas:42`).

> Associações (`[Association]`, `[ForeignKey]`, `[CascadeActions]`) têm doc
> própria: **[associations.md](associations.md)**.

## Schema — Contrato de CRUD: `IContainerObjectSet<M>`

Toda operação de dados passa por esta interface
(`Source/Objectset/Janus.Container.ObjectSet.Interfaces.pas:29-46`):

```pascal
IContainerObjectSet<M: class, constructor> = interface
  ['{427CBF16-5FD5-4144-9699-09B08335D545}']
  function ExistSequence: Boolean;
  function ModifiedFields: TDictionary<String, TDictionary<String, String>>;
  function Find: TObjectList<M>; overload;                 // todos
  function Find(const AID: Int64): M; overload;            // por PK (numérica)
  function Find(const AID: String): M; overload;           // por PK (string)
  function FindWhere(const AWhere: String;
                     const AOrderBy: String = ''): TObjectList<M>;
  procedure Insert(const AObject: M);
  procedure Update(const AObject: M);
  procedure Delete(const AObject: M);
  procedure Modify(const AObject: M);                      // snapshot p/ update parcial
  procedure LoadLazy(const AOwner, AObject: TObject);
  procedure NextPacket(const AObjectList: TObjectList<M>); overload;
  function  NextPacket: TObjectList<M>; overload;
  function  NextPacket(const APageSize, APageNext: Integer): TObjectList<M>; overload;
  function  NextPacket(const AWhere, AOrderBy: String;
                       const APageSize, APageNext: Integer): TObjectList<M>; overload;
end;
```

Semântica confirmada no código/errata:

- **`Find` / `FindWhere` auto-conectam.** O adapter do objectset envolve
  `Connect`/`Disconnect` em torno da leitura. **`NextPacket` NÃO auto-conecta**
  (`delphi-janus-specialist.md:19`, ver [rules.md](rules.md)).
- **`Modify` + `Update` = update parcial.** Carregue a linha atual (`FindWhere`
  pela PK) → `Modify(snapshot)` → aplique o overlay do JSON → `Update`. É
  exatamente o fluxo do controller de referência
  (`Examples/Delphi/RESTful/Horse/controller/HorseJanus.Controller.Master.pas:82-87`).
- **`NextPacket(pageSize, pageNext)`** = paginação; há sobrecarga com `AWhere` e
  `AOrderBy`.
- Padrão de uso do `FindWhere` para "um por PK" (a lista tem 0..n; pegue o
  primeiro): `Examples/Delphi/RESTful/Horse/dao/HorseJanus.DAO.Base.pas:65-82`.

> O padrão de reuso deste contrato (um `DAOBase<T>` genérico) está em
> **[crud-pattern.md](crud-pattern.md)**.

## Schema — Serialização JSON: `TJanusJson`

`Source/Core/Janus.Json.pas:49`. API pública (linhas 67-83):

```pascal
class function  ObjectToJsonString(AObject: TObject; ...): String;
class function  ObjectListToJsonString(AObjectList: TObjectList<TObject>; ...): String; overload;
class function  ObjectListToJsonString<T: class, constructor>(AObjectList: TObjectList<T>; ...): String; overload;
class function  JsonToObject<T: class, constructor>(const AJson: String): T; overload;
class function  JsonToObject<T: class>(AObject: T; ...): Boolean; overload;
class function  JsonToObjectList<T: class, constructor>(const AJson: String): TObjectList<T>;
class procedure JsonToObject(const AJson: String; AObject: TObject); overload;   // overlay num objeto existente
// utilitários TJSONValue/TJSONArray/TJSONObject: linhas 79-83
```

Config global — propriedades públicas (linhas 84-85): `UseISO8601DateFormat` e
`FormatSettings` controlam datas/números na (de)serialização (os getters/setters
privados ficam em `:60-63`).

### Examples

Serializar um → JSON, lista → JSON, e overlay do body sobre um objeto carregado
(`.../HorseJanus.Controller.Master.pas`):

```pascal
// listar
Res.Send(TJanusJson.ObjectListToJsonString<Tmaster>(masterList));   // :166

// obter um
Res.Send(TJanusJson.ObjectToJsonString(master));                    // :141

// criar: JSON -> objeto novo
master := TJanusJson.JsonToObject<Tmaster>(Req.Body);               // :106

// atualizar: overlay do JSON sobre a linha carregada (update parcial)
dao.modify(master);
TJanusJson.JsonToObject(Req.Body, master);                          // :84-85
dao.update(master);
```

> Para JSON **avulso** (fora do ORM), o ecossistema do dono usa **JsonFlow**, não
> `TJanusJson` (`delphi-janus-specialist.md:20`).

## Citations

- `Examples/Delphi/RESTful/Horse/models/Janus.Model.Master.pas:44-121,198-199` — decorators.
- `Examples/Delphi/RESTful/Horse/models/Janus.Model.Client.pas:38-42` — PK simples, índice, OrderBy Desc.
- `Examples/Delphi/RESTful/Horse/models/Janus.Model.Detail.pas:39-77` — PK composta, ForeignKey, AggregateField.
- `Source/Objectset/Janus.Container.ObjectSet.Interfaces.pas:29-46` — `IContainerObjectSet<M>`.
- `Source/Core/Janus.Json.pas:49-83` — `TJanusJson`.
- `Examples/Delphi/RESTful/Horse/controller/HorseJanus.Controller.Master.pas:82-87,106,141,166` — uso do JSON no CRUD.
- `delphi-janus-specialist.md:18-22` — semântica de Find/NextPacket/Modify/JSON.
