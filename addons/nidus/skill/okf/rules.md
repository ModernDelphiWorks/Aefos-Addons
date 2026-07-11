---
type: Rules
title: Nidus — Regras & Erratas
description: Antipadrões e lições aprendidas na marra do Nidus; cada uma vira uma regra NUNCA/SEMPRE com o caso real citado. LER antes de desenhar um módulo ou depurar 401/404/400.
tags: [nidus, delphi, rules, errata, antipatterns, di, routing]
timestamp: 2026-07-11T00:00:00Z
---

# Regras & Erratas

Regras destiladas do especialista curado (`delphi-nidus-specialist.md:50-59`), do
Source e do uso vivo no DFeFw. **LER antes de desenhar um módulo ou depurar um
401/404/400.** Cada regra carrega o caso REAL que a originou — não a resuma a
ponto de perder o caso.

## SEMPRE — fundamentar em código

- **SEMPRE cite `arquivo:linha`** (exemplo funcional e/ou Source). Sem fonte,
  leia — não chute (`delphi-nidus-specialist.md:14`).
- **SEMPRE estude `D:\PROJETOS-Brasil\e-docs-api-horse` ANTES de desenhar** um
  módulo — é o uso correto ponta a ponta (`delphi-nidus-specialist.md:9-10`).

## Regra 1 — Só `ExportedBinds` cruzam a fronteira de módulo

**NUNCA ponha em `Binds` (privado) uma dependência que outro módulo precisa
consumir.** Um módulo só enxerga seus próprios `Binds` + os `ExportedBinds` dos
módulos que ele `Imports` (`Nidus.Tracker.pas:162-172,236-261`). Interface num
`Binds` privado do provedor ⇒ `EBindException: Interface {GUID} not found!` no
consumidor.

**Fix:** mover o `SingletonInterface<I>` para `ExportedBinds` do provedor e o
consumidor `Imports` o provedor. *(Caso real DFeFw 2026-06-21: `TAuthService`
dependia de `IUserCredentialReader`; estava em `Usuario_Module.Binds`; mover para
`ExportedBinds` resolveu o login.)* (`delphi-nidus-specialist.md:51`.)

## Regra 2 — Exporte TAMBÉM as deps de construtor da implementação

**Exportar a interface NÃO basta se a implementação tem deps de construtor.** O
Nidus resolve os params do construtor no injector do módulo **consumidor**;
injectors de módulos irmãos não são alcançáveis. Logo, se você exporta
`TRepo.SingletonInterface<IRepo>` e `TRepo.Create(ADao: TDao)`, **exporte `TDao`
também** (`delphi-nidus-specialist.md:52`).

*(Caso real: `TEMP_FON_Service.Create(ARepository)` exportado como
`IEmpresaTenantValidator`, mas `TEMP_FON_Repository`/`TEMP_FON_DAO` não exportados
→ o guard não construía o validator → 401. Fix: exportar Repository+DAO junto.)*

## Regra 3 — Parâmetro de rota SÓ na cauda (param no meio = 404)

**NUNCA ponha um param no MEIO do path** (`/api/:version/x`). O resolver do Nidus
só remove segmentos de param do FIM (regex ancorado em `$`) e casa o restante por
igualdade exata (`Routes/Nidus.Route.Manager.pas:61-72`). Param no meio nunca
casa → **404**.

**Fix:** versão/segmento variável tem que ser literal concreto (`/api/v1/...`).
Confirmado contra o exemplo, que usa `Root='/nfe/v1'` (`app.route.pas:40-42`) e
param só na cauda (`app.route.pas:82`). O Horse por baixo (que É param-aware) não
salva: quando o resolver do Nidus falha, o middleware curto-circuita com
`raise EHorseCallbackInterrupted` e o router do Horse nem roda
(`Nidus.Driver.Horse.pas:78-93`).

*(Caso real DFeFw 2026-06-21: 1152 rotas `/api/:version/...` inalcançáveis; trocar
para `/api/v1/...` destravou.)* (`delphi-nidus-specialist.md:53,55`.)

## Regra 4 — DI em guard resolve no injector ROOT

**Tudo que um guard (ou algo que ele chame transitivamente) resolve em runtime
PRECISA estar no injector ROOT** — i.e. exportado por um módulo que o `TAppModule`
importa DIRETAMENTE. Um `TRouteMiddleware`/guard roda dentro de
`TTracker.FindRoute`→`_GuardianRoute` e **não tem injector de módulo próprio**;
`GetNidus.Get`/`GetInterface` resolvem contra o injector global + um scan de 1
nível não-recursivo dos filhos (`Nidus.Tracker.pas:207-224,291-299`;
`delphi-nidus-specialist.md:56`).

Sintoma: `EBindNotFoundException ... "Class not found"` lançado de dentro de um
guard, enquanto o MESMO `Get<T>` funciona num handler/login.

**Fix:** `TAppModule.Imports` deve incluir o módulo que exporta a dependência que
o guard precisa. *(Caso real DFeFw 2026-06-21: `TAuthGuard.CompanyExists`→DAO→
`GetNidus.Get<TJanusSession>` dava `EBindNotFoundException` porque `TAppModule`
não importava `TCoreModule`; `Imports = [TCoreModule, TEMPModule]` resolveu.)* Ver
`Source\App.Module.pas:709-720`.

## Regra 5 — `SingletonInterface<I>` é refcontado: cacheie o ref

**NUNCA resolva um `GetInterface<I>` num local e largue o ref se vai reusar em
requests futuras.** O `SingletonInterface<I>` registra um `TInterfacedObject`
refcontado; quando o único ref (um local) sai de escopo, o refcount zera e o
objeto é **DESTRUÍDO** — a próxima `GetInterface<I>` volta NIL. Sintoma clássico:
funciona na 1ª request, NIL/401 nas seguintes.

**Fix:** cacheie o ref num campo/`class var` de vida longa, resolvendo 1× e
reusando. *(Caso real DFeFw 2026-06-21: `TAuthGuard._ResolveValidator` resolvia o
`IEmpresaTenantValidator` num local → 1ª request OK, 2ª+ NIL → 401; cachear no
`class var FValidator` resolveu.)* Ver `Source\Shared\Guards\Shared.Auth.Guard.pas:74-83`
(`delphi-nidus-specialist.md:57`). **Não confunda com a Regra 4:** lá era
visibilidade root; aqui é TEMPO DE VIDA do ref.

## Regra 6 — `Imports` colhe binds; para compor ROTAS, use submódulo

`Imports` existe para **colher `ExportedBinds`** de um provider, não para compor
rotas. Como DESIGN, prefira **submódulo** (`RouteModule`/`RouteChild` nas
`Routes`) para montar rotas de outro módulo, e `ExportedBinds` de **provider puro**
(sem `Routes`/`RouteHandlers`, tipo `TCoreModule`) para compartilhar serviço. O
exemplo obedece: todo feature module importa só `[TCoreModule]`
(`nfe.module.pas:48-51`).

⚠️ **Histórico:** importar um módulo COM ROTAS chegou a destruir as rotas/injector
reais dele (a instância throwaway do harvest de `Imports` rodava
`_DestroyRoutes`/`_DestroyInjector` no dispose). **CORRIGIDO na raiz (DEC-050):**
a flag `GNidusHarvesting` faz a instância de harvest PULAR registro/destruição de
rotas e injector (`Nidus.Module.pas:56-167`, `Nidus.Module.Abstract.pas:44-52`,
`Nidus.Tracker.pas:189-205,337-353`). Confirme que o Nidus do projeto tem o fix
(no DFeFw tem). Depois do fix, `Imports` é não-destrutivo para qualquer módulo,
mas a regra de DESIGN acima continua valendo. *(Caso real 2026-06-21:
`R01_Module.Imports=[TCoreModule,TB01Module]` matava `/api/v1/bancos` até o fix;
remover o import (dead weight) também resolveu.)* (`delphi-nidus-specialist.md:58`.)

## Regra 7 — Header do request é case-sensitive (Horse/horse-jwt)

**SEMPRE configure `THorseJWTConfig.New.Header('Authorization')` no `.dpr`.** O
horse-jwt tem default `'authorization'` (minúsculo) e o cliente manda
`Authorization` → não acha o header → token vazio → 401 em toda rota autenticada.
É Horse/horse-jwt (não Nidus), mas aparece junto no fluxo de auth
(`delphi-nidus-specialist.md:59`). ⚠️ Build: para recompilar um `.pas` de
`.modules`, delete o `.dcu` correspondente; cuidado com Horse puxado de path
global em vez do `.modules` vendorizado.

## Regra 8 — Não há `FactoryInterface`

**NUNCA espere uma dependência de INTERFACE com instância fresca por resolve** —
não existe `FactoryInterface`; a API `TBind` só tem `Singleton`, `SingletonLazy`,
`Factory`, `SingletonInterface`, `AddInstance` (`Binds/Nidus.Bind.pas:32-44`). Se
precisa de instância nova por resolve, dependa da **classe concreta** com
`Factory` (`delphi-nidus-specialist.md:54`).

## Citations

- `delphi-nidus-specialist.md:50-59` — errata destilada (fonte primária destas regras).
- `Core/Nidus.Tracker.pas:162-172,207-224,236-261,291-299` — visibilidade, guard-DI, 1 injector/módulo.
- `Routes/Nidus.Route.Manager.pas:61-72` — regex do param na cauda.
- `Nidus.Module.pas:56-167`, `Nidus.Module.Abstract.pas:44-52` — DEC-050 harvest não-destrutivo.
- `Source\App.Module.pas:709-720`, `Source\Shared\Guards\Shared.Auth.Guard.pas:74-83` — casos vivos (root import, refcount).
- `Binds/Nidus.Bind.pas:32-44` — a API de escopos (sem FactoryInterface).
</content>
