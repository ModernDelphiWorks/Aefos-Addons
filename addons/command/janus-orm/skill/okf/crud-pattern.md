---
type: Playbook
title: Janus ORM — Padrão CRUD Canônico
description: O DAOBase<T> genérico sobre TContainerObjectSet<T> e os controllers Horse de referência — o jeito certo de reusar CRUD para todas as entidades.
tags: [janus, orm, delphi, crud, dao, generic, horse]
timestamp: 2026-07-11T00:00:00Z
---

# Padrão CRUD Canônico

**Mapeou a entidade ⇒ CRUD automático.** O antipadrão é 1 DAO por módulo
escrevendo SQL. O certo é **UM `DAOBase<T>` genérico** sobre
`TContainerObjectSet<T>`, reusado para todas as entidades
(`delphi-janus-specialist.md:18`).

## Schema — o DAO genérico de referência

`Examples/Delphi/RESTful/Horse/dao/HorseJanus.DAO.Base.pas`:

```pascal
THorseJanusDAOBase<T: class, constructor> = class
protected
  FConnection     : IDBConnection;
  FJanusContainer : IContainerObjectSet<T>;
public
  procedure insert(Value: T);
  procedure update(Value: T);
  procedure delete(Value: T);
  procedure modify(Value: T);
  function  listAll: TObjectList<T>;
  function  findWhere(AWhere: String): T;
  constructor create(Connection: TFDConnection);
end;

constructor THorseJanusDAOBase<T>.create(Connection: TFDConnection);
begin
  FConnection     := TFactoryFiredac.Create(Connection, dnFirebird);   // DataEngine
  FJanusContainer := TContainerObjectSet<T>.Create(FConnection);       // container Janus
end;
```
Fonte: `.../HorseJanus.DAO.Base.pas:34-58`.

Delegações diretas ao container (linhas 60-102):

```pascal
procedure insert(Value: T);  begin FJanusContainer.Insert(Value); end;
procedure update(Value: T);  begin FJanusContainer.Update(Value); end;
procedure delete(Value: T);  begin FJanusContainer.Delete(Value); end;
procedure modify(Value: T);  begin FJanusContainer.Modify(Value); end;
function  listAll: TObjectList<T>; begin Result := FJanusContainer.Find; end;
```

O `findWhere` retorna **um** (o primeiro da lista), liberando o resto sem
`OwnsObjects`:
```pascal
function findWhere(AWhere: String): T;
begin
  Result := nil;
  list := FJanusContainer.FindWhere(AWhere);
  try
    list.OwnsObjects := False;
    if list.Count > 0 then Result := list.First;
    for i := 1 to list.Count - 1 do list[i].Free;
  finally
    list.Free;
  end;
end;
```
Fonte: `.../HorseJanus.DAO.Base.pas:65-82`.

## Examples — controllers CRUD (Horse)

`Examples/Delphi/RESTful/Horse/controller/HorseJanus.Controller.Master.pas`:

- **List** — `dao.listAll` → `TJanusJson.ObjectListToJsonString<Tmaster>` (linhas 154-177).
- **Find** — `dao.findWhere('master_id = ' + id)` → `ObjectToJsonString` (linhas 127-152).
- **Insert** — `JsonToObject<Tmaster>(Req.Body)` → `dao.insert` → 201 (linhas 100-125).
- **Update** — o **fluxo canônico de update parcial** (linhas 70-98):
  ```pascal
  master := dao.findWhere('master_id = ' + id);   // 1) carrega a linha
  dao.modify(master);                              // 2) snapshot (dirty tracking)
  TJanusJson.JsonToObject(Req.Body, master);       // 3) overlay do JSON
  dao.update(master);                              // 4) UPDATE só dos campos mudados
  ```
- **Delete** — `findWhere` → `dao.delete(master)` → 204 (linhas 43-68).

## PK composta

É NATIVA. Declare múltiplas colunas na PK — o Detail usa
`[PrimaryKey('detail_id; master_id', 'Chave primária')]`
(`.../Janus.Model.Detail.pas:41`) — e o WHERE/Update/Delete usa TODAS as colunas
da chave. Para ler por chave composta, componha o WHERE com todas as colunas via
`FindWhere('detail_id = 1 AND master_id = 10')` (`delphi-janus-specialist.md:22,31`).

> Se a camada acima "acha que o Janus não suporta PK composta", o limite está no
> genérico que assume UMA coluna — não no Janus. Componha o WHERE por todas as
> `[PrimaryKey]` (`delphi-janus-specialist.md:31`).

## Regras de conexão (Find vs NextPacket)

- `Find`/`FindWhere` **auto-conectam** (o adapter faz Connect/Disconnect).
- `NextPacket` **NÃO** auto-conecta — a conexão precisa estar aberta
  (`delphi-janus-specialist.md:19`).
- Em servidor single-process com conexão compartilhada, **mantenha a conexão
  ABERTA** (singleton aberto), não use Factory por-request — ver
  [rules.md](rules.md) errata #5.

## Citations

- `Examples/Delphi/RESTful/Horse/dao/HorseJanus.DAO.Base.pas:34-102` — DAO genérico.
- `Examples/Delphi/RESTful/Horse/controller/HorseJanus.Controller.Master.pas:43-177` — controllers CRUD.
- `Examples/Delphi/RESTful/Horse/models/Janus.Model.Detail.pas:41` — PK composta.
- `delphi-janus-specialist.md:18-22,31` — padrão canônico e PK composta.
