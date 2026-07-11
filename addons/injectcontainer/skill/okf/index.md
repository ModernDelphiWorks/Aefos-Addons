---
okf_version: "0.1"
---

# Knowledge Bundle Index — InjectContainer Specialist

Base de conhecimento do especialista no **InjectContainer** (Delphi, por Isaque
Pinheiro) — o container de **injeção de dependência (DI)** thread-safe que
sustenta o **Nidus**. Fundamentada em `.modules\InjectContainer\Source`
(implementação) e `.modules\InjectContainer\Test Delphi\UTesteInject.pas` (uso
correto), com o consumo real pelo Nidus em `.modules\Nidus\Source`. Todo fato é
rastreável por `arquivo:linha`.

## Conceitos

- [Visão Geral](overview.md) — o que é o container, arquitetura interna
  (`TInject`/`TInjectContainer`/`TServiceData`/`TInjectFactory`), o injector
  global, fontes da verdade e quando usar.
- [Referência Técnica](api.md) — a API pública de `TInject`: métodos de
  registro (`Singleton`/`SingletonLazy`/`Factory`/`SingletonInterface`/
  `AddInstance`/`AddInject`), de resolução (`Get<T>`/`GetInterface<I>`),
  `Remove<T>`, logging/cache e as exceções.
- [Escopos de Bind & Hierarquia de Injectors](binds-scopes.md) — Singleton vs
  SingletonLazy vs Factory vs SingletonInterface; o repositório-por-nome vs
  repositório-por-GUID; e a hierarquia root → filho (via `AddInject`) com scan
  de 1 nível — a base de "root/filho/irmão".
- [Injeção por Construtor](constructor-injection.md) — como `_ResolverParams`
  resolve cada parâmetro do `Create` por RTTI (classe por nome, interface por
  GUID), em qual injector resolve, e a detecção de dependência circular.
- [Resolução por Interface (GUID)](resolve-by-interface.md) — como
  `SingletonInterface<I,T>` registra `T` sob o GUID de `I`, o refcount de
  `TInterfacedObject` e a assimetria "por classe vs por interface".
- [Regras & Erratas](rules.md) — antipadrões e lições aprendidas na marra
  (LER — nunca repita os bugs).

## Playbooks

- [Playbooks](playbooks/index.md) — guias práticos passo a passo:
  - [Quickstart](playbooks/quickstart.md) — do primeiro bind à resolução com
    injeção automática de construtor.
  - [Troubleshooting](playbooks/troubleshooting.md) — `EServiceNotFound`,
    `EServiceAlreadyRegistered`, `ECircularDependency`, dep de construtor não
    injetada e `SingletonInterface` que "morre" na 2ª request.

## Meta

- [Histórico](log.md) — log de criação/atualização desta base.
</content>
