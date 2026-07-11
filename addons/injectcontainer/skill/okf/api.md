---
type: API Reference
title: InjectContainer — Referência Técnica
description: A API pública de TInject — métodos de registro (Singleton/SingletonLazy/Factory/SingletonInterface/AddInstance/AddInject), de resolução (Get<T>/GetInterface<I>), Remove<T>, logging/cache e as exceções, transcritos do Source com file:line.
tags: [injectcontainer, di, delphi, api, tinject, reference]
timestamp: 2026-07-11T00:00:00Z
---

# InjectContainer — Referência Técnica

Tudo aqui é transcrito de `.modules\InjectContainer\Source` e do
`Test Delphi\UTesteInject.pas`. A classe pública é
`TInject = class(TInjectContainer)` (`Source/Inject.pas:37`).

## Schema — Métodos de registro

```pascal
// Instância única, criada AGORA (eager). Chave = T.ClassName.
procedure Singleton<T: class, constructor>(
  const AOnCreate: TProc<T> = nil;
  const AOnDestroy: TProc<T> = nil;
  const AOnConstructorParams: TConstructorCallback = nil); overload;

// Instância única, criada no PRIMEIRO Get<T> (lazy). Chave = T.ClassName.
procedure SingletonLazy<T: class>(
  const AOnCreate: TProc<T> = nil; const AOnDestroy: TProc<T> = nil;
  const AOnConstructorParams: TConstructorCallback = nil);

// Nova instância a CADA Get<T>. Chave = T.ClassName.
procedure Factory<T: class, constructor>(
  const AOnCreate: TProc<T> = nil; const AOnDestroy: TProc<T> = nil;
  const AOnConstructorParams: TConstructorCallback = nil);

// Registra T sob o GUID de I (ou sob ATag, se dado). Resolvido por GetInterface<I>.
procedure SingletonInterface<I: IInterface; T: class, constructor>(
  const ATag: string = '';
  const AOnCreate: TProc<T> = nil; const AOnDestroy: TProc<T> = nil;
  const AOnConstructorParams: TConstructorCallback = nil);

// Registra uma instância JÁ construída (o container passa a ser dono dela).
procedure AddInstance<T: class>(const AInstance: TObject);

// Registra OUTRO injector como filho, sob a tag (é a base da hierarquia).
procedure AddInject(const ATag: string; const AInstance: TInject);
```
Fontes: `Source/Inject.pas:79-95` (assinaturas), `:160-250` (implementações).

Notas de semântica confirmadas no Source:

- **`Singleton` é eager**: já materializa a receita via
  `FInjectorFactory.FactorySingleton<T>()` no registro e a guarda em `FInstances`
  (`:173-174`) — mas a **instância** só nasce no primeiro `Get` (o `TServiceData`
  cria o objeto sob demanda em `GetInstance`, `Inject.Service.pas:194-195`).
- **`SingletonLazy` só registra a referência** (`FRepositoryReference.Add`,
  `:204`) — o `TServiceData` é criado no primeiro `Get` (`GetTry` `:345-349`).
  Na prática, tanto `Singleton` quanto `SingletonLazy` só constroem o objeto no
  primeiro `Get` (comprovado por `TestInjectorSington` e `TestInjectorLazyLoad`,
  `UTesteInject.pas:210-227,253-270`).
- **`Factory` devolve objeto novo a cada `Get`**: `TestInjectorFactory` afirma
  `AreNotEqual(obj1, obj2)` (`UTesteInject.pas:101-118`; modo `imFactory` em
  `Inject.Service.pas:198`).
- **`SingletonInterface` usa o GUID como chave**: `GetTypeData(TypeInfo(I)).Guid`
  → `GUIDToString` → chave em `FRepositoryInterface`; se `ATag <> ''`, a tag
  substitui o GUID (`Inject.pas:186-193`). Ver [resolve-by-interface.md](resolve-by-interface.md).
- **`AddInstance`** registra sob `T.ClassName` no modo `imSingleton` com a
  instância pronta (`:223-233`).
- **`AddInject`** registra um `TInject` filho no modo `imSingleton`, keado pela
  tag (`:209-221`) — é assim que o Nidus pendura o núcleo e cada módulo na raiz
  (ver [binds-scopes.md](binds-scopes.md)).

> **Registro duplicado lança** — mas a exceção varia: `Singleton` e `Factory`
> lançam `Exception` genérica (`Format('Class %s registered!', ...)`,
> `:170,243`); `SingletonInterface`, `SingletonLazy`, `AddInstance` e `AddInject`
> lançam `EServiceAlreadyRegistered` (`:192,203,215,228`). Ver as exceções abaixo.

## Schema — Hooks de ciclo de vida

Os três últimos parâmetros de todo registro:

```pascal
TConstructorParams   = TArray<TValue>;              // Inject.Events.pas:24
TConstructorCallback = TFunc<TConstructorParams>;   // Inject.Events.pas:25

AOnCreate:            TProc<T>              // roda logo após criar a instância
AOnDestroy:           TProc<T>             // roda no Remove<T> (antes de descartar)
AOnConstructorParams: TConstructorCallback // fornece MANUALMENTE os params do Create
```
Fontes: `Source/Inject.Events.pas:24-39`; `_AddEvents` `Inject.pas:420-438`;
uso de `OnCreate`/`OnParams` em `Inject.Service.pas:123-145`; disparo de
`OnDestroy` em `Remove<T>` `Inject.pas:404-409`.

- **`OnParams` tem prioridade sobre a auto-injeção.** Se você registra um
  `OnConstructorParams`, o container **usa o array que ele devolve** e **NÃO**
  chama `_ResolverParams` (a auto-injeção só roda quando `FInjectorEvents.Count = 0`
  — `Inject.pas:350,387`; escolha em `Inject.Service.pas:123-133`). O Nidus usa
  exatamente isso para passar deps explícitas, ex.:
  `Result := [TValue.From<TTracker>(Self.Get<TTracker>)]`
  (`Nidus.Inject.pas:92-97`).
- **`OnCreate`** é o lugar de pós-configurar a instância recém-criada — o Nidus
  injeta serviços por setter aí (`Value.IncludeProvider(...)`,
  `Nidus.Inject.pas:128-135`).

## Schema — Métodos de resolução

```pascal
function Get<T: class, constructor>(const ATag: string = ''): T;   // por NOME de classe
function GetInterface<I: IInterface>(const ATag: string = ''): I;  // por GUID de interface
```
Fontes: `Source/Inject.pas:257-289` (`Get`), `:291-325` (`GetInterface`).

- **`Get<T>`** resolve pela chave `= ATag` ou `T.ClassName`. Tenta o próprio
  injector (`GetTry`) e, se não achar, faz um **scan de 1 nível dos injectors
  filhos** (`for LItem in GetInstances.Values ... if LItem.AsInstance is TInject`,
  `:274-285`). **Assimetria importante:** se não achar em lugar nenhum, `Get<T>`
  **retorna `nil` silenciosamente** — a linha que lançaria `EServiceNotFound`
  está **comentada** (`:287-288`).
- **`GetInterface<I>`** faz o mesmo com o GUID, mas se não achar **LANÇA**
  `EServiceNotFound.Create('Interface %s not found!')` (`:324`). Guarde essa
  diferença: classe some em silêncio (nil), interface estoura.
- **Tag**: em ambos, passar `ATag <> ''` sobrescreve a chave — é como registrar/
  resolver o mesmo par por um rótulo próprio (`TestInjectorInterfaceTag`,
  `UTesteInject.pas:156-173`).

## Schema — `Remove<T>` e utilitários

```pascal
procedure Remove<T: class>(const ATag: string = '');           // dispara OnDestroy e limpa dos 4 repos
function  GetInstances: TObjectDictionary<string, TServiceData>;
procedure EnableLogging(const ALogCallback: TProc<string> = nil);
procedure DisableLogging;
procedure ClearCache;                                          // limpa o cache RTTI
```
Fontes: `Source/Inject.pas:395-418` (`Remove` — chama `OnDestroy`, remove de
`FRepositoryReference`/`FRepositoryInterface`/`FInjectorEvents`/`FInstances`),
`:252-255,657-676`. O Nidus expõe `Remove` via
`TNidusInject.ExtractInject<T>` (`Nidus.Inject.pas:181-189`).

## Schema — Exceções

```pascal
EInjectException          = class(Exception);        // base
EServiceAlreadyRegistered = class(EInjectException); // registro duplicado (interface/lazy/instance/inject)
EServiceNotFound          = class(EInjectException); // GetInterface<I> não encontrou o GUID
ECircularDependency       = class(EInjectException); // ciclo detectado em _ResolverParams
```
Fonte: `Source/Inject.pas:30-33`. `ECircularDependency` traz a cadeia:
`Format('Circular dependency detected: %s', [chain])`
(`_CheckCircularDependency` `:519-549`).

## Performance & thread-safety

- **Thread-safe por design.** O injector global é protegido por
  `GInjectorLock: TCriticalSection` (`:145-158`); o cache RTTI tem seu próprio
  `FRttiCacheLock` (`:566-627`).
- **Cache RTTI** de tipos e métodos `Create` por classe, para não re-refletir a
  cada resolução (`FTypeCache`/`FMethodCache`, `_GetCachedType` `:566`,
  `_GetCachedMethod` `:590`). `ClearCache` esvazia (`:672-676`).
- **Logging opcional** via callback (`EnableLogging(TProc<string>)`, `:657-662`).

## Citations

- `Source/Inject.pas:79-104` — assinaturas públicas de registro/resolução.
- `Source/Inject.pas:160-250` — implementações de registro.
- `Source/Inject.pas:257-325` — `Get<T>` / `GetInterface<I>` (scan de filhos + assimetria nil vs raise).
- `Source/Inject.pas:395-418` — `Remove<T>` + `OnDestroy`.
- `Source/Inject.pas:30-33,519-549` — exceções + detecção de ciclo.
- `Source/Inject.Service.pas:187-216` — `GetInstance`/`GetInterface` (singleton cacheia, factory recria).
- `Source/Inject.Events.pas:24-39` — params/callbacks/eventos.
- `Test Delphi/UTesteInject.pas:101-270` — testes por modo (fonte de uso correto).
- `Nidus.Inject.pas:92-135` — `OnParams`/`OnCreate` no consumo real.
</content>
