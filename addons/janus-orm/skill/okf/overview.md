---
type: Framework Overview
title: Janus ORM — Visão Geral
description: O que é o Janus, sua arquitetura sobre o DataEngine, fontes da verdade e quando usar.
tags: [janus, orm, delphi, dataengine, overview]
timestamp: 2026-07-11T00:00:00Z
---

# Janus ORM — Visão Geral

O **Janus** é um framework ORM (Object-Relational Mapping) moderno para Delphi,
autor **Isaque Pinheiro** (ModernDelphiWorks), licença MIT
(`Examples/Delphi/RESTful/Horse/models/Janus.Model.Master.pas:2-11`). Ele mapeia
classes Delphi decoradas com atributos para tabelas relacionais e entrega CRUD,
associações, cascade e serialização JSON automaticamente.

## Arquitetura em uma frase

Janus decora entidades → gera DML por dialeto → executa contra uma conexão
abstrata `IDBConnection` (fornecida pelo **DataEngine**) → materializa objetos.
O ORM NÃO fala com o driver diretamente; ele fala com o DataEngine, que envolve
FireDAC/UniDAC/Zeos/etc. atrás de `IDBConnection`.

```
Entidade decorada  ─▶  TContainerObjectSet<T>  ─▶  Session/CommandExecutor
        │                      │                          │
   [Table]/[Column]      contrato de CRUD          gera DML + executa
   [Association]/…    (IContainerObjectSet<M>)     via IDBConnection
                                                          │
                                                    DataEngine (FireDAC/…)
                                                          │
                                                     Banco (Firebird/…)
```

O container é criado sobre uma conexão do DataEngine. No Example Horse, a fábrica
`TFactoryFiredac.Create(Connection, dnFirebird)` produz o `IDBConnection` e o
container é `TContainerObjectSet<T>.Create(FConnection)`
(`Examples/Delphi/RESTful/Horse/dao/HorseJanus.DAO.Base.pas:56-57`).

## Camadas do Source (para investigar)

- **Container/ObjectSet** (`Source/Objectset`): a API pública de CRUD —
  `IContainerObjectSet<M>` (`Source/Objectset/Janus.Container.ObjectSet.Interfaces.pas:29`),
  `TContainerObjectSet<T>`, `TManagerObjectSet`, adapters.
- **Session** (`Source/Core/Janus.Session.Abstract.pas`): `PopularObjectSet`
  materializa o `IDBDataSet` em `TObjectList<M>` (linha 365) e dispara
  `FillAssociation` por linha (linha 378).
- **Command** (`Source/Core/Janus.Command.*`): Selecter/Inserter/Updater/Deleter
  + `Janus.Command.Executor.pas` (associações 1:1 e 1:N — `ExecuteOneToOne`
  linha 319, `ExecuteOneToMany` linha 354, `FillAssociation` linha 201).
- **DML Generator** (`Source/Core/Janus.DML.Generator.*`): um gerador por
  dialeto (Firebird, Firebird3, SQLite, PostgreSQL, Oracle, MSSQL, MySQL,
  InterBase, MongoDB, …). Ver [dialects.md](dialects.md).
- **JSON** (`Source/Core/Janus.Json.pas`): `TJanusJson` — objeto ⇄ JSON
  (linha 49). Ver [api.md](api.md).
- **Middleware-Horse** (`Source/Middleware-Horse/Horse.Janus.pas`): integração
  REST com o Horse.

## Fontes da verdade (estude ANTES de afirmar)

1. **Examples do próprio framework** — `.modules\Janus\Examples`, em especial:
   - `Examples\Delphi\RESTful\Horse` — CRUD REST completo (models + DAO genérico
     + controllers). É a referência de uso correto ponta a ponta.
   - `Examples\Delphi\Data\Uso TManagerObjectSet` e `…\Uso TManagerDataSet` —
     uso desktop do ORM.
   - `Examples\Delphi\JSON` — `TJanusJson` isolado.
2. **Source do framework** — `.modules\Janus\Source` (unidades-chave acima).
3. **Modelo legado** (em migração): transcreva `[Association]`/`[ForeignKey]`/
   `[CascadeActions]`/`[JoinColumn]` VERBATIM do legado, mas reconcilie as
   COLUNAS ao **DDL vivo** — o modelo assumido costuma divergir do banco real
   (`delphi-janus-specialist.md:12`, `:27`).

## Quando usar

- Precisa de CRUD sobre um banco relacional em Delphi sem escrever SQL à mão para
  cada entidade → decore a entidade e ganhe CRUD genérico
  (`delphi-janus-specialist.md:18`).
- Precisa de associações (mestre-detalhe, lookup), cascade e serialização JSON
  integradas.
- Quer trocar de banco por dialeto sem reescrever a camada de dados.

## Quando NÃO usar / limites

- JSON avulso fora do ORM: o ecossistema usa **JsonFlow**, não `TJanusJson`
  (`delphi-janus-specialist.md:20`).
- Acesso a dados de baixo nível fica no **DataEngine** (o Janus só orquestra).

## Citations

- `Examples/Delphi/RESTful/Horse/dao/HorseJanus.DAO.Base.pas:54-58` — criação do
  container sobre a conexão do DataEngine.
- `Source/Objectset/Janus.Container.ObjectSet.Interfaces.pas:29-46` — contrato de CRUD.
- `Source/Core/Janus.Session.Abstract.pas:365-389` — materialização de objetos.
- `Source/Core/Janus.Command.Executor.pas:201-352` — preenchimento de associações.
- `delphi-janus-specialist.md:9-27` — fontes da verdade e conhecimento essencial.
