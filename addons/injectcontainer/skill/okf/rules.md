---
type: Rules
title: InjectContainer — Regras & Erratas
description: Antipadrões e lições aprendidas na marra do InjectContainer (e do Nidus por cima dele); cada uma vira uma regra NUNCA/SEMPRE com o caso real citado. LER antes de registrar um bind ou depurar uma resolução.
tags: [injectcontainer, di, delphi, rules, errata, antipatterns]
timestamp: 2026-07-11T00:00:00Z
---

# Regras & Erratas

Regras destiladas do especialista curado (`delphi-injectcontainer-specialist.md`),
do Source e das erratas de campo do Nidus (o consumidor real). **LER antes de
registrar um bind ou depurar uma resolução.** Cada regra carrega o caso REAL que a
originou — não a resuma a ponto de perder o caso.

## SEMPRE — fundamentar em código

- **SEMPRE cite `arquivo:linha`** (Source e/ou Test). Sem fonte, leia — não chute
  (`delphi-injectcontainer-specialist.md:13`).
- **SEMPRE separe o mecanismo (container) da política (Nidus).** Binds/
  ExportedBinds/Imports/Routes são regras do **Nidus**; aqui está só o container.
  Ao explicar um bug de módulo, aponte para o addon `delphi-nidus`.

## Regra 1 — Dep de construtor resolve no injector CORRENTE, nunca no irmão

**`_ResolverParams` resolve cada parâmetro do `Create` NO injector que está
construindo o serviço (e num filho direto via scan de 1 nível), mas NUNCA num
injector IRMÃO** (`delphi-injectcontainer-specialist.md:17`; `Inject.pas:483,511`
resolvem sobre `Self`; scan de filhos `:274-285`).

Consequência: se o serviço A depende de B, **B precisa estar no mesmo injector que
constrói A**. No Nidus, o injector que constrói é o **do módulo consumidor**; por
isso **exportar só a interface do serviço NÃO basta — exporte TAMBÉM as deps do
construtor** (`delphi-injectcontainer-specialist.md:22`).

Caso real (errata 2 do Nidus, DFeFw 2026-06-21): `TEMP_FON_Service.Create(ARepository)`
foi exportado como `IEmpresaTenantValidator`, mas `TEMP_FON_Repository`/`TEMP_FON_DAO`
**não** foram exportados → o injector do consumidor não conseguia montar o `Create`
→ guard não construía o validator → **401**. Fix: exportar Repository+DAO junto
(`delphi-nidus-specialist.md:52`). Ver [constructor-injection.md](constructor-injection.md)
e [binds-scopes.md](binds-scopes.md).

## Regra 2 — `EServiceNotFound: Interface {GUID} not found` = bind fora de alcance

**Ao ver `EServiceNotFound`/`EBindException: Interface {GUID} not found!`, o bind
está num injector que o consumidor NÃO alcança** — não é "não registrei". Lembre a
mecânica: `GetInterface<I>` só vê o injector corrente + filhos diretos
(`Inject.pas:291-325`), e no Nidus só `ExportedBinds` cruzam `Imports`
(`delphi-injectcontainer-specialist.md:22`).

- **Interface estoura; classe some em silêncio.** `GetInterface<I>` **lança**
  `EServiceNotFound` (`Inject.pas:324`); `Get<T>` **retorna `nil`** (raise
  comentado, `:287-288`). Um `Get<T>` que "volta nil" é o MESMO sintoma de "não
  achou" — não confunda com "achou e veio vazio". **SEMPRE cheque nil após `Get<T>`.**

Caso real (errata 1 do Nidus): `TAuthService` dependia de `IUserCredentialReader`
que estava nos `Binds` privados do módulo provedor; mover o `SingletonInterface<I>`
para `ExportedBinds` do provedor (e o consumidor `Imports` o provedor) resolveu o
login (`delphi-nidus-specialist.md:51`).

## Regra 3 — DI dentro de GUARD resolve contra a RAIZ, não contra o módulo

**Tudo que um guard (ou algo que ele chame transitivamente) resolve em runtime
PRECISA estar no injector ROOT** — i.e. exportado por um módulo que o `TAppModule`
importa DIRETAMENTE. Um guard roda em `TTracker.FindRoute`→`_GuardianRoute` e
**não tem injector de módulo próprio**; ele resolve via `GNidusInject^` (raiz) com
o scan de 1 nível dos filhos (`Nidus.Tracker.pas`; `Inject.pas:257-289`).

Sintoma: `EBindNotFoundException ... "Class not found"` lançado de dentro de um
guard, enquanto o **mesmo** `Get<T>` funciona num handler/login. Fix:
`TAppModule.Imports` deve incluir o módulo que exporta a dependência do guard.
Caso real: `TAuthGuard.CompanyExists`→DAO→`GetNidus.Get<TJanusSession>` dava
`EBindNotFoundException` porque `TAppModule` não importava `TCoreModule`; adicionar
Core ao Imports resolveu (`delphi-nidus-specialist.md:56`).

## Regra 4 — `SingletonInterface` é REFCONTADO: segure o ref ou ele morre

**NUNCA resolva um `SingletonInterface<I>` numa variável local e a solte** esperando
que o "singleton" sobreviva. O objeto é um `TInterfacedObject` refcontado; o
container **não segura um ref contado independente** (com um único holder externo o
RefCount é **1** — `UTesteInject.pas:194-208`). Ao largar o ref local, o objeto é
**destruído**; a próxima `GetInterface<I>` volta `nil`/reconstrói.

Sintoma clássico: funciona na 1ª request, `nil`/401 nas seguintes. **Fix:** cachear
o ref num campo/`class var` de vida longa, resolvendo 1× e reusando. Caso real:
`TAuthGuard._ResolveValidator` resolvia o `IEmpresaTenantValidator` num local → 2ª+
request `validator NIL` → 401; cachear em `class var FValidator` resolveu
(`delphi-nidus-specialist.md:57`). **NÃO confunda com a Regra 3** (lá é visibilidade
root; aqui é TEMPO DE VIDA do ref). Ver [resolve-by-interface.md](resolve-by-interface.md).

## Regra 5 — Não existe `FactoryInterface`

**NUNCA prometa "interface por-instância".** Dependência consumida como
**interface** só existe como `SingletonInterface<I>` — não há `FactoryInterface`
(`Inject.Factory.pas:28-31` só tem `Factory`/`FactorySingleton`/`FactoryInterface`
singleton; `delphi-nidus-specialist.md:33`). Se precisa de instância fresca por
resolução, **dependa da CLASSE concreta com `Factory`**.

## Regra 6 — O tipo do parâmetro decide a injeção; primitivo vem NIL

**`_ResolverParams` só injeta `tkClass`/`tkClassRef` (por nome) e `tkInterface`
(por GUID); qualquer outro tipo recebe `TValue.From(nil)`** (`Inject.pas:480-494`).
Não espere que o container preencha `string`/`Integer`/record num construtor —
para isso, use o hook `OnParams` (`AOnConstructorParams`), que **sobrescreve** a
auto-injeção (`Inject.pas:350,387`; `Inject.Service.pas:123-133`). Ex. no Nidus:
`Result := [TValue.From<TTracker>(Self.Get<TTracker>)]` (`Nidus.Inject.pas:92-97`).

## Regra 7 — Registro duplicado LANÇA (e a exceção varia)

**NUNCA registre o mesmo serviço duas vezes no mesmo injector.**
`Singleton`/`Factory` lançam `Exception` genérica (`'Class %s registered!'`,
`Inject.pas:170,243`); `SingletonInterface`/`SingletonLazy`/`AddInstance`/`AddInject`
lançam `EServiceAlreadyRegistered` (`:192,203,215,228`). Se precisa trocar, use
`Remove<T>` antes (dispara `OnDestroy`, `:395-418`; no Nidus: `ExtractInject<T>`,
`Nidus.Inject.pas:181-189`).

## Regra 8 — Dependência circular estoura na resolução

**Ciclos `A(Create:B)` / `B(Create:A)` lançam `ECircularDependency`** com a cadeia
(`A -> B -> A`) — o container empilha nomes e detecta a repetição
(`_CheckCircularDependency` `Inject.pas:519-549`). Quebre o ciclo (injeção por
setter/`OnCreate`, ou uma interface mediadora), não patcheie o container.

## Regra 9 — Patches no `.modules\InjectContainer`

Ao corrigir o próprio framework: **branch dedicada no repo do frw + backup
pristino + PR no final** (várias equipes editam em paralelo). O projeto consumidor
**NUNCA** commita `.modules` (padrão dos frameworks do dono;
`delphi-janus-specialist.md:33`, aplicável aqui). Registre o patch em
`MODULES_PATCHES/` para o dono espelhar.

## Citations

- `delphi-injectcontainer-specialist.md:13-22` — errata destilada (fonte primária).
- `Source/Inject.pas:257-325` — assimetria nil (classe) vs raise (interface) + scan de filhos.
- `Source/Inject.pas:440-501` — `_ResolverParams` (tipos injetáveis).
- `Source/Inject.pas:170,192,203,215,228,243` — exceções de registro duplicado.
- `Source/Inject.pas:519-549` — detecção de ciclo.
- `Source/Inject.Factory.pas:28-31` — não há `FactoryInterface` por-instância.
- `Test Delphi/UTesteInject.pas:175-208` — refcount 1/2 (base da Regra 4).
- `delphi-nidus-specialist.md:33,51-52,56-57` — erratas de campo (deps não exportadas, guard/root, ref que morre).
</content>
