---
okf_version: "0.1"
---

# Knowledge Bundle Index — Nidus Specialist

Base de conhecimento do especialista no **Nidus** — framework Delphi modular
(injeção de dependência + roteamento) inspirado no NestJS, autor Isaque Pinheiro,
rodando **sobre o Horse**. Fundamentada no exemplo funcional
`D:\PROJETOS-Brasil\e-docs-api-horse` (uso correto) e em `.modules\Nidus\Source`
(implementação); todo fato é rastreável por `arquivo:linha`.

## Conceitos

- [Visão Geral](overview.md) — o que é o Nidus, arquitetura sobre o Horse, o ciclo
  de vida de uma request, fontes da verdade e quando usar.
- [Módulos & Injeção de Dependência](modules.md) — a anatomia do `TModule`
  (`Binds`/`ExportedBinds`/`Imports`/`Routes`/`RouteHandlers`), a regra de
  visibilidade cross-module e os escopos de bind.
- [Referência da API](api.md) — `TBind` (Singleton/SingletonLazy/Factory/
  SingletonInterface/AddInstance), `TNidus`/`GetNidus`, as sobrescritas do
  `TModule` e o `TRouteHandlerHorse`.
- [Roteamento](routing.md) — `RouteModule`/`RouteChild`, a convenção de path, o
  gotcha do parâmetro só na cauda e os controllers.
- [Guards & Pipes de Validação](guards-pipes.md) — `TRouteMiddleware` (guards) e o
  pipe de validação com os decorators `[Body]`/`[Param]`/`[Query]`.
- [Bootstrap (.dpr)](bootstrap.md) — a ordem de montagem no `.dpr`, `Nidus_Horse`,
  `UsePipes`/`UseCache` e `THorse.Listen`.
- [Regras & Erratas](rules.md) — antipadrões e lições aprendidas na marra
  (LER — nunca repita os bugs).

## Playbooks

- [Playbooks](playbooks/index.md) — guias práticos passo a passo:
  - [Quickstart](playbooks/quickstart.md) — do zero a um módulo Nidus com rota,
    controller, service e DI por construtor.
  - [Troubleshooting](playbooks/troubleshooting.md) — 404 (param no meio), 401
    (interface não exportada / refcount do SingletonInterface / guard no root),
    400 permanente (Imports com rotas) e header case-sensitive.

## Meta

- [Histórico](log.md) — log de criação/atualização desta base.
</content>
