---
type: Playbook
title: InjectContainer — Troubleshooting
description: Sintoma -> causa-raiz -> fix para os erros mais caros do InjectContainer — EServiceNotFound, Get<T> nil silencioso, EServiceAlreadyRegistered, ECircularDependency, dep de construtor não injetada e SingletonInterface que morre na 2ª request.
tags: [injectcontainer, di, delphi, troubleshooting, debug, nidus]
timestamp: 2026-07-11T00:00:00Z
---

# Troubleshooting

Sintoma → causa-raiz → fix, com a fonte. Regras completas em [../rules.md](../rules.md).

## `EServiceNotFound: Interface {GUID} not found!`

- **Causa-raiz:** o bind está num injector que o consumidor **não alcança**, não
  que "não foi registrado". `GetInterface<I>` só vê o injector corrente + filhos
  diretos (scan de 1 nível, `Inject.pas:291-325`); um **irmão** é invisível.
- **No Nidus:** só `ExportedBinds` cruzam `Imports`; o bind provável está nos
  `Binds` privados do provedor. **Fix:** mover o `SingletonInterface<I>` para
  `ExportedBinds` e o consumidor `Imports` o provedor
  (`delphi-nidus-specialist.md:51`).
- **Se o serviço tem deps de construtor**, exporte-as TAMBÉM (Regra 1) — senão o
  injector do consumidor não monta o `Create` e você vê o mesmo not-found ou 401
  (`delphi-nidus-specialist.md:52`).
- Fonte: `delphi-injectcontainer-specialist.md:22`; `Inject.pas:324`.

## `Get<T>` retorna `nil` (e nada estoura)

- **Causa-raiz:** `Get<T>` **NÃO lança** quando não acha — o `raise EServiceNotFound`
  está comentado (`Inject.pas:287-288`); retorna `nil` em silêncio. Fácil de
  confundir com "achou e veio vazio".
- **Fix:** **sempre cheque `nil` após `Get<T>`.** Se veio nil, o serviço não está
  registrado NESTE injector (nem em filho direto). Diferente de `GetInterface<I>`,
  que **estoura** `EServiceNotFound` (`:324`).
- Fonte: `Inject.pas:257-289`.

## `EBindNotFoundException` dentro de um GUARD, mas o mesmo `Get<T>` funciona no handler

- **Causa-raiz:** um guard resolve contra a **raiz** (`GNidusInject^`), que só vê
  seus filhos diretos; um bind que está só no `ExportedBinds` de outro módulo não
  é alcançável do guard. O guard não tem injector de módulo próprio.
- **Fix:** `TAppModule.Imports` deve incluir o módulo que exporta a dependência do
  guard (ex.: `[TCoreModule, TEMPModule]`). Caso real: `TAuthGuard`→DAO→
  `GetNidus.Get<TJanusSession>` só passou depois de `TAppModule` importar
  `TCoreModule` (`delphi-nidus-specialist.md:56`). Ver Regra 3 em [../rules.md](../rules.md).

## Funciona na 1ª request, `nil`/401 nas seguintes (interface)

- **Causa-raiz:** `SingletonInterface` é `TInterfacedObject` **refcontado**; o
  container não segura um ref contado independente (RefCount = 1 com um único
  holder, `UTesteInject.pas:194-208`). Resolver numa **variável local** e soltá-la
  destrói o objeto; a próxima `GetInterface<I>` volta `nil`/reconstrói.
- **Fix:** cachear o ref num **campo/`class var` de vida longa**, resolvendo 1× e
  reusando. Caso real: `TAuthGuard._ResolveValidator` num local → 2ª+ request
  `validator NIL` → 401; `class var FValidator` resolveu
  (`delphi-nidus-specialist.md:57`). **Não confunda com o item do guard acima**
  (lá é visibilidade root; aqui é tempo de vida). Ver
  [../resolve-by-interface.md](../resolve-by-interface.md).

## Dependência de construtor chega `nil` (mesmo estando registrada)

- **Causa A — porta errada:** o construtor pede a **interface** mas você só
  registrou a **classe** (`Singleton<T>`), ou vice-versa. `_ResolverParams`
  resolve `tkClass` por nome e `tkInterface` por GUID — em repositórios separados
  (`Inject.pas:480-491`). **Fix:** registre na porta que o `Create` pede (se pede
  as duas, registre nas duas — `UTesteInject.pas:239-240`).
- **Causa B — injector irmão:** a dep existe, mas num injector que **não** é o que
  constrói o serviço (irmão não alcança). **Fix:** ponha a dep no mesmo injector
  (no Nidus: exporte-a). Regra 1.
- **Causa C — primitivo:** o parâmetro é `string`/`Integer`/record → o container
  injeta `nil` de propósito (`:492-493`). **Fix:** use `OnParams` para fornecê-lo
  (`Nidus.Inject.pas:92-97`). Ver [../constructor-injection.md](../constructor-injection.md).

## `EServiceAlreadyRegistered` / `Class %s registered!` no registro

- **Causa-raiz:** o mesmo serviço foi registrado duas vezes no mesmo injector.
  `Singleton`/`Factory` lançam `Exception` genérica (`Inject.pas:170,243`); os
  demais lançam `EServiceAlreadyRegistered` (`:192,203,215,228`).
- **Fix:** registre uma vez só; para trocar, `Remove<T>` antes (`:395-418`;
  Nidus: `ExtractInject<T>`).

## `ECircularDependency: Circular dependency detected: A -> B -> A`

- **Causa-raiz:** o construtor de A depende de B e o de B depende de A; o container
  detecta o ciclo na pilha de resolução (`_CheckCircularDependency`
  `Inject.pas:519-549`).
- **Fix:** quebre o ciclo — injete um dos lados por **setter** (`OnCreate`) ou
  introduza uma interface mediadora; não patcheie o container.

## Citations

- `Source/Inject.pas:257-289` — `Get<T>` retorna nil (raise comentado).
- `Source/Inject.pas:291-325` — `GetInterface<I>` lança `EServiceNotFound`.
- `Source/Inject.pas:480-494` — tipos injetáveis (primitivo → nil).
- `Source/Inject.pas:170,192,203,215,228,243` — duplicado lança.
- `Source/Inject.pas:519-549` — ciclo.
- `Test Delphi/UTesteInject.pas:194-208,239-240` — refcount + duas portas.
- `delphi-nidus-specialist.md:51-52,56-57` — erratas de campo (Nidus).
</content>
