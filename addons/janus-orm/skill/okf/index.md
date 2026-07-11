---
okf_version: "0.1"
---

# Knowledge Bundle Index — Janus ORM Specialist

Base de conhecimento do especialista no **Janus ORM** (Delphi, por Isaque
Pinheiro) sobre o **DataEngine** (acesso a dados desacoplado via `IDBConnection`).
Fundamentada em `.modules\Janus\Examples` (uso correto) e `.modules\Janus\Source`
(implementação); todo fato é rastreável por `arquivo:linha`.

## Conceitos

- [Visão Geral](overview.md) — o que é o Janus, arquitetura sobre o DataEngine,
  fontes da verdade e quando usar.
- [Referência Técnica](api.md) — decorators de mapeamento, a interface
  `IContainerObjectSet<M>` (contrato de CRUD) e a API `TJanusJson`.
- [Associações, FK & Cascade](associations.md) — `[Association]`, `[ForeignKey]`,
  `[JoinColumn]`, `[CascadeActions]`, multiplicidade a partir da FK e como o Janus
  preenche as associações.
- [Padrão CRUD Canônico](crud-pattern.md) — o `DAOBase<T>` genérico sobre
  `TContainerObjectSet<T>` e os controllers Horse de referência.
- [Dialetos de DML & Leitura Viva](dialects.md) — geradores por banco e os
  requisitos para ler ao vivo contra Firebird.
- [Regras & Erratas](rules.md) — antipadrões e lições aprendidas na marra
  (LER — nunca repita os bugs).

## Playbooks

- [Playbooks](playbooks/index.md) — guias práticos passo a passo:
  - [Quickstart](playbooks/quickstart.md) — do zero a um CRUD REST funcional.
  - [Troubleshooting](playbooks/troubleshooting.md) — HANG/AV, `EInvalidCast`,
    live-read Firebird, conexão que trava na 2ª request.

## Meta

- [Histórico](log.md) — log de criação/atualização desta base.
