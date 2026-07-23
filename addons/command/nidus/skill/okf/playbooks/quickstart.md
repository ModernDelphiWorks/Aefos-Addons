---
type: Playbook
title: Nidus — Quickstart
description: Do zero a um módulo Nidus com rota, controller, service e DI por construtor, seguindo o exemplo funcional passo a passo.
tags: [nidus, delphi, quickstart, module, controller, di, horse]
timestamp: 2026-07-11T00:00:00Z
---

# Quickstart — do zero a um feature module com rota + DI

Baseado em `D:\PROJETOS-Brasil\e-docs-api-horse` (referência ponta a ponta). Cada
passo cita a fonte. Conceitos completos em [../modules.md](../modules.md),
[../routing.md](../routing.md) e [../api.md](../api.md).

## 1. Defina os paths num record de rotas

```pascal
function TRotas.Root: String;         begin Result := '/nfe/v1';                 end;
function TRotas.NFeConsultar: String; begin Result := Root + '/consulta/:chave'; end; // param na CAUDA
```
`Root` é literal concreto (versão nunca é param — Regra 3). Fonte:
`modulos/app.route.pas:40-83`.

## 2. Camadas com DI por construtor (infra → repo → service → controller)

Cada camada depende da concreta abaixo; o Nidus injeta pelo construtor via RTTI:

```pascal
TNFeService = class(TInterfacedObject, INFe)
private
  FRepository: TNFeRepository;
public
  constructor Create(const ARepository: TNFeRepository);   // dep injetada
end;

TNFeController = class(TInterfacedObject, INFe)
private
  FService: TNFeService;
public
  constructor Create(const AService: TNFeService);          // dep injetada
end;
```
Fonte: `modulos/nfe/services/nfe.service.pas:13-35`,
`modulos/nfe/controlles/nfe.controller.pas:16-35`. As interfaces carregam GUID
(`modulos/nfe/interfaces/nfe.interfaces.pas:10-19`).

## 3. Um provider puro para o que é compartilhado (`TCoreModule`)

```pascal
function TCoreModule.ExportedBinds: TExportedBinds;
begin
  Result := [Bind<TJsonLib>.Singleton,
             Bind<TNFeLibACBr>.SingletonInterface<INFeLib>];
end;
```
Fonte: `modulos/core/core.module.pas:24-28`. Sem `Routes`/`Binds` privados — só
`ExportedBinds`. Só isto cruza a fronteira (Regra 1).

## 4. O feature module (Binds próprios + Imports + Routes)

```pascal
function TNFeModule.Binds: TBinds;
begin
  Result := [Bind<TNFeInfra>.Factory,
             Bind<TNFeRepository>.Factory,
             Bind<TNFeService>.Factory,
             Bind<TNFeController>.Singleton];
end;

function TNFeModule.Imports: TImports;
begin
  Result := [TCoreModule];                 // recebe os ExportedBinds do Core
end;
```
Fonte: `modulos/nfe/nfe.module.pas:34-51`. Escolha do escopo: infra/repo/service
por request → `Factory`; controller stateless → `Singleton` (ver
[../modules.md](../modules.md)).

## 5. O controller (`TRouteHandlerHorse`)

```pascal
type
  TNFeRouteHandler = class(TRouteHandlerHorse)
  protected
    procedure RegisterRoutes; override;
  public
    procedure NFeConsultar(Req: THorseRequest; Res: THorseResponse);
  end;

procedure TNFeRouteHandler.RegisterRoutes;
begin
  RouteGet(Rota.NFeConsultar, NFeConsultar);       // encadeie .RouteGet(...).RoutePost(...)
end;

procedure TNFeRouteHandler.NFeConsultar(Req: THorseRequest; Res: THorseResponse);
begin
  GetNidus.Get<TNFeController>.NFeConsultar(Req.Body).When(
    procedure (Json: String) begin Res.Send(Json).ContentType(CONTENTTYPE_JSON).Status(200); end,
    procedure (Error: ERequestException)
    begin
      try Res.Send(Error.Message).Status(Error.Status); finally Error.Free; end;
    end);
end;

initialization
  GetNidus.RegisterRouteHandler(TNFeRouteHandler);   // PASSO obrigatório (1 de 2)
```
Fonte: `modulos/nfe/nfe.route.handler.pas:24-75,204-205`. Leia o body com
`Req.Body`, param com `Req.Params['chave']`, query com `Req.Query['x']`.

## 6. Registre o handler no módulo raiz e monte a rota

```pascal
function TAppModule.RouteHandlers: TRouteHandlers;               // PASSO obrigatório (2 de 2)
begin
  Result := [TNFeRouteHandler];
end;

function TAppModule.Routes: TRoutes;
begin
  Result := [RouteModule(Rota.NFeConsultar, TNFeModule),
             RouteModule(Rota.NFeServicoStatus, TNFeModule, [TAuthGuard])];  // com guard
end;
```
Fonte: `modulos/app.module.pas:52-70`. Guard opcional em
[../guards-pipes.md](../guards-pipes.md).

## 7. Bootstrap no `.dpr` (ordem importa)

```pascal
THorse.Use(Nidus_Horse(TAppModule.Create));   // monta o Nidus (chama Start)
GetNidus.UsePipes(TValidationPipe.Create);     // valida payloads pelos decorators
GetNidus.UseCache(TModuleCacheManager.Create);
THorse.Listen(9000, '127.0.0.1', procedure begin WriteLn('Online') end);  // por ÚLTIMO
```
Fonte: `e_docs_api.dpr:247-262`. Detalhes em [../bootstrap.md](../bootstrap.md).

## Checklist final

- [ ] `Root` é literal concreto; param SÓ na cauda (Regra 3).
- [ ] Dep compartilhada está em `ExportedBinds` de um provider puro (Regra 1);
      exportou também as deps de construtor dela (Regra 2).
- [ ] Dep de interface é `SingletonInterface<I>` (não existe `FactoryInterface` —
      Regra 8); se cachear ref de interface, use `class var` (Regra 5).
- [ ] Handler: `GetNidus.RegisterRouteHandler` no `initialization` **E** listado
      no `RouteHandlers` do módulo.
- [ ] Se usa guard: o módulo que exporta a dep do guard está no
      `TAppModule.Imports` (Regra 4).
- [ ] `.dpr`: `Nidus_Horse` → `UsePipes/UseCache` → `THorse.Listen` por último.

## Citations

- `modulos/app.route.pas:40-83`, `modulos/app.module.pas:52-70`.
- `modulos/core/core.module.pas:24-28`, `modulos/nfe/nfe.module.pas:34-51`.
- `modulos/nfe/services/nfe.service.pas:13-35`, `modulos/nfe/controlles/nfe.controller.pas:16-35`.
- `modulos/nfe/nfe.route.handler.pas:24-75,204-205`, `e_docs_api.dpr:247-262`.
</content>
