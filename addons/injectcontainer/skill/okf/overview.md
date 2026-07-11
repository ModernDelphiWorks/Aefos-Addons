---
type: Framework Overview
title: InjectContainer — Visão Geral
description: O que é o InjectContainer, sua arquitetura interna (TInject/TInjectContainer/TServiceData/TInjectFactory), o injector global, fontes da verdade e quando usar.
tags: [injectcontainer, di, dependency-injection, delphi, container, overview]
timestamp: 2026-07-11T00:00:00Z
---

# InjectContainer — Visão Geral

O **InjectContainer** é um framework de **injeção de dependência (DI)** de alta
performance e thread-safe para Delphi, autor **Isaque Pinheiro**
(ModernDelphiWorks), licença MIT (`Source/Inject.pas:1-12`; `boss.json`). Ele
registra serviços (classes/interfaces) num container e os **resolve** sob demanda,
**injetando automaticamente as dependências de construtor** por RTTI. É o motor de
DI **por baixo do Nidus** (`delphi-injectcontainer-specialist.md:7`).

## Arquitetura em uma frase

Você **registra** um serviço num injector (`Singleton`/`SingletonLazy`/`Factory`/
`SingletonInterface`) → o injector guarda uma **receita** (`TServiceData`) em um de
dois repositórios (por **nome de classe** ou por **GUID de interface**) → ao
**resolver** (`Get<T>`/`GetInterface<I>`), o injector materializa o objeto via
RTTI, **resolvendo cada parâmetro do construtor** contra ele mesmo, e devolve a
instância (a mesma, se singleton; nova, se factory).

```
Registro                         Resolução
--------                         ---------
Singleton<T>        \            Get<T>            -> por NOME de classe
SingletonLazy<T>     >  TInject  GetInterface<I>   -> por GUID de interface
Factory<T>          /   (repos)         |
SingletonInterface<I,T>                 v
AddInstance<T> / AddInject       _ResolverParams (RTTI) injeta o Create
                                        |
                                 TServiceData.GetInstance / GetInterface
```

## Peças do Source (para investigar)

- **`Inject.pas`** — a API pública: `TInject = class(TInjectContainer)`
  (`:37`). Métodos de registro (`Singleton` `:160`, `SingletonLazy` `:198`,
  `Factory` `:235`, `SingletonInterface` `:179`, `AddInstance` `:223`,
  `AddInject` `:209`), de resolução (`Get<T>` `:257`, `GetInterface<I>` `:291`,
  os protegidos `GetTry` `:327` / `GetInterfaceTry` `:358` — declarados sob
  `protected` em `Inject.pas:65-67`), `Remove<T>` `:395`,
  a injeção de construtor `_ResolverParams` `:440`, o guard de ciclo
  `_CheckCircularDependency` `:519`, o cache RTTI `_GetCachedType`/`_GetCachedMethod`
  `:566`/`:590` e o **injector global** `GetInjector` `:145`.
- **`Inject.Container.pas`** — a base `TInjectContainer` com os quatro
  repositórios: `FRepositoryReference` (nome→classe), `FRepositoryInterface`
  (GUID→classe+GUID), `FInstances` (nome/GUID→`TServiceData`, dono das instâncias)
  e `FInjectorEvents` (`:29-55`).
- **`Inject.Service.pas`** — `TServiceData`: a "receita" de um serviço. Guarda o
  modo (`TInjectionMode = (imSingleton, imFactory)` `:26`), a classe, a instância
  e o `TValue` da interface; `GetInstance<T>` `:187` (cacheia se singleton, cria
  se factory) e `GetInterface<I>` `:202` (cacheia o `TValue`).
- **`Inject.Factory.pas`** — `TInjectFactory`: cria os `TServiceData` via RTTI
  (`FactorySingleton` `:62`, `Factory` `:38`, `FactoryInterface` `:49`).
- **`Inject.Events.pas`** — os hooks: `TConstructorParams = TArray<TValue>`
  (`:24`), `TConstructorCallback = TFunc<TConstructorParams>` (`:25`) e
  `TInjectEvents` (`OnCreate`/`OnDestroy`/`OnParams`, `:27-39`).

## O injector global

O container mantém um **injector singleton de processo**: `GPInjector: PInject` +
`GInjectorLock: TCriticalSection`, criados na `initialization` da unit
(`Inject.pas:678-681`) e liberados na `finalization` (`:683-699`). Acesso
thread-safe via `function GetInjector: TInject` (`:145-158`). O Nidus **estende**
esse global com o seu próprio: `GNidusInject: PNidusInject`, um
`TNidusInject = class(TInject)` (`Nidus.Inject.pas:26-31,50,191-194`).

## Como o Nidus usa (o principal consumidor)

- O Nidus cria um injector-raiz `GNidusInject` e, dentro dele, registra o núcleo
  como um **injector-filho** nomeado `'Nidus'`:
  `AddInject(C_NIDUS, TCoreInject.Create)` (`Nidus.Inject.pas:177`).
- `TCoreInject` registra os serviços do núcleo: `TTracker`/`TRouteManager` como
  `SingletonLazy`, `TModernObject` como `Singleton`, e Bind/Route/Module
  services/providers como `Factory` (`Nidus.Inject.pas:72-173`).
- Cada **módulo Nidus** ganha **seu próprio injector** (`TNidusInject`), também
  adicionado como filho da raiz via `AddInject(AModule.ClassName, LInjector)`
  (`Nidus.Tracker.pas:236-261`). Os `TBind<T>` de um módulo chamam os métodos do
  injector (`Singleton`/`Factory`/`SingletonInterface`/…) via `IncludeInject`
  (`Nidus.Bind.pas:124-160`).

Essa relação root ↔ filho é a base dos escopos — ver [binds-scopes.md](binds-scopes.md).

## Fontes da verdade (estude ANTES de afirmar)

1. **Source do framework** — `.modules\InjectContainer\Source`, chave `Inject.pas`
   (`delphi-injectcontainer-specialist.md:10`).
2. **Test do framework** — `.modules\InjectContainer\Test Delphi\UTesteInject.pas`:
   cada `[Test]` é um exemplo de uso correto (Singleton, LazyLoad, Factory,
   Interface, Interface+Tag, RefCount, Auto-Inject de params).
3. **Consumo pelo Nidus** — `.modules\Nidus\Source\Core\Nidus.Inject.pas`,
   `Nidus.Tracker.pas`, `Binds\Nidus.Bind.pas`
   (`delphi-injectcontainer-specialist.md:11`).

## Quando usar

- Precisa desacoplar criação de uso: registre a implementação uma vez e resolva
  onde precisar, sem `TConcreto.Create` espalhado.
- Precisa de **injeção automática de construtor**: declare um `Create(dep1; dep2)`
  e o container preenche os params por RTTI (`UTesteInject.pas:229-251`).
- Precisa alternar implementação por **interface** (GUID) sem acoplar ao concreto
  (`SingletonInterface<I,T>` — `UTesteInject.pas:120-138`).
- Está construindo/depurando um app **Nidus** — o container é a camada por baixo
  de todos os `Binds`.

## Quando NÃO usar / limites

- **Regras de módulo (Binds/ExportedBinds/Imports/Routes)** são do **Nidus**, não
  do container puro — use o addon **delphi-nidus** para elas. Aqui explicamos só o
  mecanismo de container que as sustenta.
- Não há `FactoryInterface`: dependência consumida como **interface** só existe
  como `SingletonInterface<I>` (ver [resolve-by-interface.md](resolve-by-interface.md)
  e `delphi-nidus-specialist.md:33`).

## Citations

- `Source/Inject.pas:37-104` — declaração pública de `TInject`.
- `Source/Inject.pas:145-158,678-699` — injector global + lifecycle.
- `Source/Inject.Container.pas:29-55` — os quatro repositórios do container.
- `Source/Inject.Service.pas:26,187-216` — `TServiceData` e modos de injeção.
- `Source/Inject.Factory.pas:38-71` — fábrica dos `TServiceData`.
- `Source/Inject.Events.pas:24-39` — params/callbacks/eventos.
- `.modules/Nidus/Source/Core/Nidus.Inject.pas:26-31,72-194` — Nidus estende o container.
- `.modules/Nidus/Source/Core/Nidus.Tracker.pas:236-261` — 1 injector por módulo.
- `delphi-injectcontainer-specialist.md:7-19` — fontes da verdade e conhecimento essencial.
</content>
