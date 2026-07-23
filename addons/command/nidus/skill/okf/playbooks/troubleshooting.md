---
type: Playbook
title: Nidus — Troubleshooting
description: Diagnóstico e correção dos erros mais caros do Nidus — 404 por param no meio, 401 por bind não exportado / deps de construtor / refcount / guard-DI no root, 400 permanente por Imports com rotas e header case-sensitive.
tags: [nidus, delphi, troubleshooting, debug, 404, 401, di]
timestamp: 2026-07-11T00:00:00Z
---

# Troubleshooting

Sintoma → causa-raiz → fix, com a fonte. Regras completas em
[../rules.md](../rules.md).

## 404 — a rota nunca casa

- **Causa nº 1: parâmetro no MEIO do path** (`/api/:version/x`). O resolver do
  Nidus só remove segmentos de param do FIM e casa o resto por igualdade exata
  (`Routes/Nidus.Route.Manager.pas:61-72`) — param no meio nunca reduz e nunca
  casa.
- **Fix:** versão/segmento variável tem que ser literal concreto (`/api/v1/...`),
  param só na cauda (`/consulta/:chave`). O exemplo usa `Root='/nfe/v1'`
  (`app.route.pas:40-42,82`).
- **Por que o Horse não salva:** o resolver do Nidus falhando responde e
  curto-circuita com `raise EHorseCallbackInterrupted`
  (`Nidus.Driver.Horse.pas:78-93`) — o router param-aware do Horse nem roda.
- Caso real: 1152 rotas `/api/:version/...` inalcançáveis; `/api/v1/...`
  destravou. Fonte: `delphi-nidus-specialist.md:53,55`. Ver Regra 3.

## `EBindException: Interface {GUID} not found!` ao resolver um serviço

- **Causa-raiz:** a interface está nos `Binds` (privados) do módulo provedor em
  vez de `ExportedBinds` — só `ExportedBinds` cruzam a fronteira
  (`Nidus.Tracker.pas:162-172`).
- **Fix:** mover o `SingletonInterface<I>` para `ExportedBinds` do provedor; o
  consumidor `Imports` o provedor. Caso real: `IUserCredentialReader` estava em
  `Usuario_Module.Binds` → login 401 até mover para `ExportedBinds`.
- Fonte: `delphi-nidus-specialist.md:51`. Ver Regra 1.

## 401 — o guard não constrói o validator (deps de construtor faltando)

- **Causa-raiz:** você exportou a interface, mas a implementação tem deps de
  construtor que NÃO foram exportadas; o Nidus resolve os params do construtor no
  injector do consumidor e não alcança injectors irmãos.
- **Fix:** exporte também o `Repository`/`DAO`/... do construtor. Caso real:
  `TEMP_FON_Service.Create(ARepository)` exportado como
  `IEmpresaTenantValidator`, mas `TEMP_FON_Repository`/`TEMP_FON_DAO` não → o
  guard não montava o validator → 401.
- Fonte: `delphi-nidus-specialist.md:52`. Ver Regra 2.

## 401/`EBindNotFoundException` DE DENTRO de um guard (mas o mesmo Get funciona no handler)

- **Causa-raiz:** DI em guard resolve no injector ROOT, não no do módulo. Um
  `TRouteMiddleware` roda em `_GuardianRoute` sem injector próprio
  (`Nidus.Tracker.pas:207-224`), e `Get`/`GetInterface` batem no injector global
  + scan de 1 nível não-recursivo. Se a dep está só no `ExportedBinds` de outro
  módulo (não importado pelo App), o guard não a alcança.
- **Fix:** inclua o módulo que exporta a dep no `TAppModule.Imports`. Caso real:
  `TAuthGuard`→DAO→`GetNidus.Get<TJanusSession>` dava `EBindNotFoundException`
  porque o App não importava `TCoreModule`; `Imports=[TCoreModule, TEMPModule]`
  resolveu (`Source\App.Module.pas:709-720`).
- Fonte: `delphi-nidus-specialist.md:56`. Ver Regra 4.

## "Só a 1ª request funciona, 2ª+ dá 401/NIL"

- **Causa-raiz:** `SingletonInterface<I>` é refcontado. O consumidor (ex.: um
  guard) resolveu num LOCAL e largou o ref no fim do método → refcount zerou → o
  objeto foi destruído → a próxima resolução volta NIL.
- **Fix:** cacheie o ref num `class var`/campo de vida longa, resolvendo 1×. Caso
  real: `TAuthGuard._ResolveValidator` cacheia em `class var FValidator`
  (`Source\Shared\Guards\Shared.Auth.Guard.pas:74-83`).
- Fonte: `delphi-nidus-specialist.md:57`. Ver Regra 5. **Instrumente ONDE a 2ª
  request morre** antes de culpar a conexão de banco (pode ser isto, não a conexão).

## 400 PERMANENTE numa rota depois de outra rota rodar (Imports com rotas)

- **Causa-raiz (histórica, PRÉ-DEC-050):** importar um módulo COM ROTAS fazia a
  instância throwaway do harvest de `Imports` rodar `_DestroyRoutes`/
  `_DestroyInjector` no dispose, destruindo as rotas/injector REAIS do importado.
  Sintoma: rota B funciona até uma request da rota A (que `Imports` B) rodar; daí
  B dá `EBindNotFoundException` 400 para sempre.
- **CORRIGIDO (DEC-050):** a flag `GNidusHarvesting` faz a instância de harvest
  pular registro/destruição (`Nidus.Module.pas:56-167`,
  `Nidus.Module.Abstract.pas:44-52`, `Nidus.Tracker.pas:189-205`). Confirme que o
  Nidus do projeto tem o fix (no DFeFw tem).
- **Design (vale sempre):** `Imports` é para colher binds; para compor ROTAS de
  outro módulo use submódulo (`RouteModule`/`RouteChild`), e para compartilhar
  serviço use `ExportedBinds` de provider puro (sem rotas).
- Fonte: `delphi-nidus-specialist.md:58`. Ver Regra 6.

## 401 em TODA rota autenticada (nunca passa do JWT)

- **Causa-raiz:** header case-sensitive. O horse-jwt tem default `'authorization'`
  (minúsculo); o cliente manda `Authorization` → header não encontrado → token
  vazio → 401. É Horse/horse-jwt, não Nidus, mas aparece no fluxo de auth.
- **Fix:** `THorseJWTConfig.New.Header('Authorization')` no `.dpr`.
- Fonte: `delphi-nidus-specialist.md:59`. Ver Regra 7.

## "Preciso de uma interface com instância nova por resolve"

- Impossível: não há `FactoryInterface`. A API `TBind` só tem
  `Singleton/SingletonLazy/Factory/SingletonInterface/AddInstance`
  (`Binds/Nidus.Bind.pas:32-44`). Dependa da CLASSE concreta com `Factory` se
  precisa de instância fresca. Fonte: `delphi-nidus-specialist.md:54`. Ver Regra 8.

## Citations

- `delphi-nidus-specialist.md:51-59` — erratas de campo.
- `Routes/Nidus.Route.Manager.pas:61-72`; `Nidus.Driver.Horse.pas:78-93` — 404 / curto-circuito.
- `Core/Nidus.Tracker.pas:162-172,189-205,207-224` — visibilidade, harvest, guard-DI.
- `Nidus.Module.pas:56-167`, `Nidus.Module.Abstract.pas:44-52` — DEC-050.
- `Source\App.Module.pas:709-720`, `Source\Shared\Guards\Shared.Auth.Guard.pas:74-83` — casos vivos.
- `Binds/Nidus.Bind.pas:32-44` — escopos (sem FactoryInterface).
</content>
