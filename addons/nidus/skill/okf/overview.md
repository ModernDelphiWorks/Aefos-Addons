---
type: Framework Overview
title: Nidus — Visão Geral
description: O que é o Nidus, sua arquitetura modular sobre o Horse, o ciclo de vida de uma request, fontes da verdade e quando usar.
tags: [nidus, delphi, di, nestjs, horse, modules, overview]
timestamp: 2026-07-11T00:00:00Z
---

# Nidus — Visão Geral

O **Nidus** é um framework de aplicação **modular e escalável** para Delphi,
inspirado nos padrões arquiteturais do **NestJS**, autor **Isaque Pinheiro**
(ModernDelphiWorks), licença MIT (`Nidus.pas:2-11`). Ele fornece **injeção de
dependência** (por módulo, com escopos) e **roteamento** organizados em módulos,
e roda **sobre o Horse** (o servidor HTTP), do qual é um middleware
(`delphi-nidus-specialist.md:7`).

## Arquitetura em uma frase

Você declara **módulos** (`TModule`); cada módulo tem um **injector próprio** com
seus binds; os módulos montam **rotas** (`RouteModule`) e registram
**controllers** (`TRouteHandlerHorse`); um middleware `Nidus_Horse` intercepta
cada request, resolve a rota pelo path e deixa o módulo/controller responder.

```
.dpr  ─▶  THorse.Use(Nidus_Horse(TAppModule.Create))  ─▶  TAppModule
                                   │                          │
                             (middleware)          Routes / RouteHandlers / Binds
                                   │                          │
   request ──▶ Nidus_Horse.Middleware ──▶ GetNidus.LoadRouteModule(path)
                                   │
                    guard(TRouteMiddleware) ──▶ pipe de validação ──▶ SelectRoute
                                   │
                       controller (GetNidus.Get<T>) responde via Horse
```

O Nidus NÃO substitui o Horse: ele registra os handlers no roteador global do
Horse (`THorse.Get/Post/...` — `Horse/Nidus.Route.Handler.Horse.pas:66-100`) e
adiciona por cima um **resolver dinâmico próprio** que casa o path, roda os guards
e o pipe de validação, e faz load/dispose do módulo de rota por request
(`Horse/Nidus.Driver.Horse.pas:55-120`).

## Ciclo de vida de uma request (o que acontece por baixo)

1. `Nidus_Horse.Middleware` recebe a request; ignora rotas de swagger/favicon e
   só age em `GET/POST/PUT/PATCH/DELETE` (`Nidus.Driver.Horse.pas:62-69`).
2. Monta um `IRouteRequest` a partir do `THorseRequest` (headers, params, query,
   body, authorization) (`Nidus.Driver.Horse.pas:122-138`).
3. Chama `GetNidus.LoadRouteModule(path, req)` (`Nidus.Driver.Horse.pas:71`):
   - roda o **guard global** se houver (`UseGuard`) e os **guards de rota**;
   - roda o **pipe de validação** se `UsePipes` foi chamado, aplicando os
     decorators `[Body]`/`[Param]`/`[Query]` do método
     (`Nidus.pas:298-327`);
   - resolve a rota via `FRouteParse.SelectRoute` (`Nidus.pas:326`).
4. Se o resolver dinâmico **falha**, o middleware responde com o status da
   `ENidusException` (ex.: 401/400) e **curto-circuita** com
   `raise EHorseCallbackInterrupted` — o roteador nativo do Horse **não** chega a
   rodar (`Nidus.Driver.Horse.pas:78-93`; ver [rules.md](rules.md), errata do
   404).
5. No `finally`, `GetNidus.DisposeRouteModule(path)` descarrega o módulo de rota
   (`Nidus.Driver.Horse.pas:118`) — cada request faz load+dispose do seu módulo.

## Camadas do Source (para investigar)

- **Fachada** (`Source/Nidus.pas`): a classe `TNidus` e `GetNidus` — a API pública
  (`Start`, `Get<T>`, `GetInterface<I>`, `UseGuard`, `UsePipes`, `UseCache`,
  `LoadRouteModule`, `RegisterRouteHandler`) (`Nidus.pas:44-96`).
- **Módulos** (`Source/Modules`): `TModule` (as 5 sobrescritas) e as funções
  `RouteModule`/`RouteChild` (`Nidus.Module.pas:51-118`).
- **Binds** (`Source/Binds`): `TBind<T>` com os escopos
  (Singleton/SingletonLazy/Factory/SingletonInterface/AddInstance)
  (`Nidus.Bind.pas:27-45`).
- **Core/Tracker** (`Source/Core/Nidus.Tracker.pas`): o coração da resolução —
  `BindModule` (um injector por módulo), `_AddModuleImportsBind` (só
  `ExportedBinds` cruzam), `FindRoute`/`_GuardianRoute` (guards)
  (`Nidus.Tracker.pas:134-289`).
- **Rotas** (`Source/Routes`): `TRouteManager.RemoveSuffix` (o regex do param na
  cauda), `TRouteMiddleware`/`IRouteMiddleware` (guards)
  (`Nidus.Route.Manager.pas:61-72`, `Nidus.Route.Abstract.pas:26-42`).
- **Horse** (`Source/Horse`): `Nidus_Horse` (o middleware) e `TRouteHandlerHorse`
  (`RouteGet`/`RoutePost`/... → `THorse.Get`/`Post`/...)
  (`Nidus.Driver.Horse.pas`, `Nidus.Route.Handler.Horse.pas`).
- **Pipes** (`Source/Pipes`): o `TValidationPipe`, os decorators de payload
  (`[Body]`/`[Param]`/`[Query]`) e a família de validadores estilo
  class-validator (`Nidus.Decorator.Body.pas`, `Nidus.Validation.Include.pas`).
- **Addons** (`Source/Addons`): cache de módulo, message bus e object pooling
  (`UseCache`, `UsePools` — `Nidus.pas:74-83`).

## Fontes da verdade (estude ANTES de afirmar)

1. **Exemplo funcional** — `D:\PROJETOS-Brasil\e-docs-api-horse`: uma API e-docs
   (NF-e) em Horse + Nidus do próprio autor. Referência de uso correto ponta a
   ponta: `modulos\app.module.pas` (AppModule), `modulos\app.route.pas` (nomes de
   rota), `modulos\core\core.module.pas` (módulo provider puro),
   `modulos\nfe\nfe.module.pas` + `nfe.route.handler.pas` (feature module +
   controller), `e_docs_api.dpr` (bootstrap). Ignore `modules\ACBr2` (lib fiscal
   vendorizada) e os `.dcu` (`delphi-nidus-specialist.md:10`).
2. **Source do framework** — `.modules\Nidus\Source` (unidades-chave acima)
   (`delphi-nidus-specialist.md:11`).
3. **Uso vivo** — no backend DFeFw: `Source\App.Module.pas` (`Imports` do root e
   `Routes` com guard) e `Source\Shared\Guards\Shared.Auth.Guard.pas` (guard de
   tenant) confirmam as erratas de guard-DI e refcount.

## Quando usar

- App Delphi/Horse que precisa de **organização modular** (features isoladas com
  seus próprios serviços) e **injeção de dependência por construtor**.
- Quer o estilo NestJS: módulos que declaram providers, exportam o que é público,
  importam o que consomem, e montam rotas + controllers
  (`delphi-nidus-specialist.md:7`).

## Quando NÃO usar / limites

- Não é um ORM nem um cliente de dados: acesso a dados é do Janus/DataEngine; o
  Nidus só orquestra DI + rotas.
- Não há `FactoryInterface`: dependência consumida como **interface** só existe em
  escopo `SingletonInterface` (`delphi-nidus-specialist.md:33`, ver
  [rules.md](rules.md)).

## Citations

- `Nidus.pas:2-11,44-96` — licença/autoria e a API pública `TNidus`.
- `Nidus.Driver.Horse.pas:55-138` — o middleware `Nidus_Horse` e o ciclo da request.
- `Nidus.Tracker.pas:134-289` — resolução de binds, imports e guards.
- `modulos\app.module.pas`, `modulos\core\core.module.pas`, `e_docs_api.dpr` —
  uso correto ponta a ponta.
- `delphi-nidus-specialist.md:7-16` — fontes da verdade e a natureza do framework.
</content>
