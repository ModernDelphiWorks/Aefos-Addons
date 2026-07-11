---
type: API Reference
title: Nidus — Referência da API
description: A superfície pública do Nidus — TBind (escopos), TNidus/GetNidus, as sobrescritas do TModule e o TRouteHandlerHorse — transcrita do Source com file:line.
tags: [nidus, delphi, api, tnidus, tbind, getnidus, routehandler]
timestamp: 2026-07-11T00:00:00Z
---

# Referência da API

Tudo aqui é transcrito de `.modules\Nidus\Source` e do exemplo funcional.

## `GetNidus` — a fachada

`GetNidus: TNidus` resolve a instância única do Nidus do injector global
(`Nidus.pas:96,106-109`). É por ela que você resolve dependências e configura o
app.

```pascal
function GetNidus: TNidus;
begin
  Result := GNidusInject^.Get<TNidus>;
end;
```

### Resolver dependências

```pascal
function Get<T: class, constructor>(ATag: string = ''): T;      // classe concreta
function GetInterface<I: IInterface>(ATag: string = ''): I;     // por GUID de interface
```
Fonte: `Nidus.pas:89-90,141-156,217-232`. Ambos delegam ao `TBindService` e
levantam a exceção se o bind não existe. Uso no controller de handler:
`GetNidus.Get<TNFeController>` (`modulos/nfe/nfe.route.handler.pas:61`).

⚠️ **`GetInterface<I>` é refcontado** — guarde o resultado num campo de vida
longa se for reusar em requests futuras (ver [rules.md](rules.md), Regra 5).

⚠️ **Em guard, `Get`/`GetInterface` resolvem no injector ROOT** (não no injector
do módulo). Ver [guards-pipes.md](guards-pipes.md) e [rules.md](rules.md), Regra 4.

### Configurar o app (fluent, retornam `TNidus`)

```pascal
function Start(const AModule: TModule; const AInitialRoutePath: string = '/'): TNidus;
function UseGuard(const AGuardCallback: TGuardCallback): TNidus;   // guard global
function UsePipes(const AValidationPipe: IValidationPipe): TNidus; // pipe de validação
function UseCache(const ACache: IModuleCache): TNidus; overload;   // cache de módulo
function UseCache(const ACache: IModuleCache; const AModules: array of TClass): TNidus; overload;
function UsePools<T: class, constructor>(const AMaxSize: Integer = 256): TNidus;  // object pool
procedure RegisterRouteHandler(const ARouteHandler: TRouteHandlerClass);
```
Fonte: `Nidus.pas:66-96`. `Start` é chamado por você indiretamente via
`Nidus_Horse(TAppModule.Create)` (que chama `GetNidus.Start` —
`Nidus.Driver.Horse.pas:44-48`). Ver [bootstrap.md](bootstrap.md).

### Load de rota por request (interno)

```pascal
function LoadRouteModule(const APath: string; const AReq: IRouteRequest = nil): TReturnPair;
procedure DisposeRouteModule(const APath: string);
```
Fonte: `Nidus.pas:87-88,298-364`. Chamados pelo middleware `Nidus_Horse` a cada
request (`Nidus.Driver.Horse.pas:71,118`). `LoadRouteModule` roda, nesta ordem: o
guard global (se `UseGuard`), o pipe de validação (se `UsePipes`) e o
`SelectRoute` (`Nidus.pas:298-327`).

## `TBind<T>` — declaração de binds

Classe genérica com métodos de classe que fabricam o bind já no escopo
(`Binds/Nidus.Bind.pas:27-45`):

```pascal
TBind<T: class, constructor> = class(TBindAbstract<T>)
public
  class function Singleton(...): TBind<TObject>;
  class function SingletonLazy(...): TBind<TObject>;
  class function Factory(...): TBind<TObject>;
  class function SingletonInterface<I: IInterface>(...): TBind<TObject>;
  class function AddInstance(const AInstance: TObject): TBind<TObject>;
end;
```

Cada método aceita callbacks opcionais `AOnCreate`/`AOnDestroy`/
`AOnConstructorParams` (hooks de ciclo de vida e de resolução manual de params)
(`Nidus.Bind.pas:32-44`). Detalhe de cada escopo em [modules.md](modules.md).

## `TModule` — as sobrescritas

```pascal
TModule = class(TModuleAbstract)
public
  function Routes: TRoutes; override;
  function Binds: TBinds; override;
  function Imports: TImports; override;
  function ExportedBinds: TExportedBinds; override;
  function RouteHandlers: TRouteHandlers; override;
end;
```
Fonte: `Modules/Nidus.Module.pas:51-73`. Semântica de cada uma em
[modules.md](modules.md). O `TModule.Create` carrega binds + rotas + handlers na
construção (`Nidus.Module.pas:122-147`); o `Destroy` remove rotas + injector
(`Nidus.Module.pas:149-167`) — exceto na instância "harvest-only" de `Imports`
(DEC-050, ver [rules.md](rules.md), Regra 6).

### Funções de montagem de rota

```pascal
function RouteModule(const APath: string; const AModule: TModuleClass): TRouteModule; overload;
function RouteModule(const APath: string; const AModule: TModuleClass;
  const AMiddlewares: TMiddlewares): TRouteModule; overload;   // com guards
function RouteChild(const APath: string; const AModule: TModuleClass;
  const AMiddlewares: TMiddlewares = []): TRouteChild;
```
Fonte: `Modules/Nidus.Module.pas:80-118`. Detalhes em [routing.md](routing.md).

## `TRouteHandlerHorse` — o controller

```pascal
TRouteHandlerHorse = class(TRouteHandler)
public
  function RouteGet   (const ARoute: string; const ACallback: THorseCallbackRequestResponse): TRouteHandlerHorse;
  function RoutePost  (const ARoute: string; const ACallback: THorseCallbackRequestResponse): TRouteHandlerHorse;
  function RoutePut   (const ARoute: string; const ACallback: THorseCallbackRequestResponse): TRouteHandlerHorse;
  function RoutePatch (const ARoute: string; const ACallback: THorseCallbackRequestResponse): TRouteHandlerHorse;
  function RouteDelete(const ARoute: string; const ACallback: THorseCallbackRequestResponse): TRouteHandlerHorse;
end;
```
Fonte: `Horse/Nidus.Route.Handler.Horse.pas:27-34`. Cada `RouteXxx` encadeia
(retorna `Self`) e registra no roteador global do Horse (`THorse.Get/Post/...`),
de forma **idempotente** (primeira registração vence — dedup contra "Duplicate
route detected") (`Nidus.Route.Handler.Horse.pas:40-100`). O callback é
`procedure(Req: THorseRequest; Res: THorseResponse)`. Detalhes e exemplo completo
em [routing.md](routing.md).

O `TRouteHandler` base sobrescreve `RegisterRoutes` (chamado no `Create`) para
declarar as rotas (`Routes/Nidus.Route.Handler.pas:29-54`).

## Leitura da request / escrita da response (Horse)

Dentro de um handler `procedure(Req: THorseRequest; Res: THorseResponse)`:

- `Req.Body` — corpo cru (string). `Req.Params['chave']` — param de path da
  cauda. `Req.Query['x']` — query string. `Req.RawWebRequest.Authorization` — o
  header Authorization (`Nidus.Driver.Horse.pas:125-134`).
- `Res.Send(text).ContentType(...).Status(code)` — resposta encadeada
  (`modulos/nfe/nfe.route.handler.pas:65`).

## Citations

- `Nidus.pas:44-96,106-109,141-156,217-232,298-364` — `TNidus`/`GetNidus` e a API pública.
- `Binds/Nidus.Bind.pas:27-45` — `TBind<T>` e os escopos.
- `Modules/Nidus.Module.pas:51-118` — `TModule` e `RouteModule`/`RouteChild`.
- `Horse/Nidus.Route.Handler.Horse.pas:27-100` — `TRouteHandlerHorse`.
- `Routes/Nidus.Route.Handler.pas:29-54` — `RegisterRoutes`.
- `modulos/nfe/nfe.route.handler.pas:46-75` — uso real de handler + `GetNidus.Get`.
</content>
