---
type: Playbook
title: Janus ORM — Quickstart
description: Do modelo decorado a um CRUD REST funcional no padrão canônico, seguindo o Example Horse passo a passo.
tags: [janus, orm, delphi, quickstart, crud, horse]
timestamp: 2026-07-11T00:00:00Z
---

# Quickstart — do modelo ao CRUD REST

Baseado em `.modules\Janus\Examples\Delphi\RESTful\Horse` (referência ponta a
ponta). Cada passo cita a fonte.

## 1. Decore a entidade

```pascal
uses
  MetaDbDiff.mapping.attributes, MetaDbDiff.Types.Mapping,
  MetaDbDiff.Mapping.Register, Janus.Types.Nullable;

[Entity]
[Table('client','')]
[PrimaryKey('client_id', 'Chave primária')]
[OrderBy('client_id Desc')]
Tclient = class
private
  Fclient_id: Integer;
  Fclient_name: String;
public
  [Restrictions([TRestriction.NoUpdate, TRestriction.NotNull])]
  [Column('client_id', ftInteger)]
  property client_id: Integer read Fclient_id write Fclient_id;

  [Column('client_name', ftString, 40)]
  property client_name: String read Fclient_name write Fclient_name;
end;

initialization
  TRegisterClass.RegisterEntity(Tclient);   // OBRIGATÓRIO
```
Modelo real: `Examples/.../models/Janus.Model.Client.pas:37-68`. Detalhes de cada
atributo em [../api.md](../api.md); associações em [../associations.md](../associations.md).

## 2. Configure a conexão (DataEngine) e registre o dialeto

Coloque o gerador do banco no `uses` da conexão e abra-a:
```pascal
uses Janus.DML.Generator.Firebird;   // + Janus.DML.Generator.SQLite p/ ler ao vivo
...
FDConnection1.Connected := True;
```
Fonte: `Examples/.../providers/DM.Connection.pas:31,54`. Para leitura viva no
Firebird veja os 3 requisitos em [../dialects.md](../dialects.md) (gerador
SQLite + `CharacterSet=WIN1252` + reconciliar ao DDL).

## 3. Reuse o DAO genérico

Não escreva um DAO por entidade — instancie o genérico com o tipo:
```pascal
FConnection     := TFactoryFiredac.Create(Connection, dnFirebird);
FJanusContainer := TContainerObjectSet<T>.Create(FConnection);
```
Fonte: `Examples/.../dao/HorseJanus.DAO.Base.pas:54-58`. A API completa
(`Insert/Update/Delete/Modify/Find/FindWhere/NextPacket`) está em
[../api.md](../api.md); o padrão em [../crud-pattern.md](../crud-pattern.md).

## 4. Escreva os handlers CRUD

```pascal
// LIST
masterList := dao.listAll;
Res.Send(TJanusJson.ObjectListToJsonString<Tmaster>(masterList));

// INSERT
master := TJanusJson.JsonToObject<Tmaster>(Req.Body);
dao.insert(master);
Res.Send(TJanusJson.ObjectToJsonString(master)).Status(201);

// UPDATE (parcial — fluxo canônico)
master := dao.findWhere('master_id = ' + id);
dao.modify(master);                          // snapshot
TJanusJson.JsonToObject(Req.Body, master);   // overlay
dao.update(master);

// DELETE
master := dao.findWhere('master_id = ' + id);
dao.delete(master);
Res.Status(204);
```
Fonte: `Examples/.../controller/HorseJanus.Controller.Master.pas:43-177`.

## 5. Associações & PK composta (quando precisar)

- Mestre-detalhe: `[Association(TMultiplicity.OneToMany, …)]` na coleção +
  `[CascadeActions([...])]` (`Janus.Model.Master.pas:113-118`).
- PK composta: `[PrimaryKey('detail_id; master_id', …)]` e leia por WHERE com
  todas as colunas (`Janus.Model.Detail.pas:41`).

## Checklist final

- [ ] `TRegisterClass.RegisterEntity(T)` na `initialization`.
- [ ] `[Association]`/`[ForeignKey]` na **prop-objeto**, não na FK escalar (Regra 6).
- [ ] Gerador de DML no `uses` da conexão (+ SQLite se ler ao vivo Firebird).
- [ ] Conexão **aberta e mantida** em servidor single-process (Regra 5).
- [ ] Update via `Modify` → overlay → `Update`.

## Citations

- `Examples/.../models/Janus.Model.Client.pas:37-68`, `Janus.Model.Master.pas:44-121`.
- `Examples/.../dao/HorseJanus.DAO.Base.pas:34-102`.
- `Examples/.../controller/HorseJanus.Controller.Master.pas:43-177`.
- `Examples/.../providers/DM.Connection.pas:31,54`.
