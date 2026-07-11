---
okf_version: "0.1"
---

# Knowledge Bundle Index — DataEngine Specialist

Base de conhecimento do especialista no **DataEngine** (Delphi, por Isaque
Pinheiro) — a abstração de acesso a dados **desacoplada** (`IDBConnection` /
`IDBDataSet`) sobre FireDAC e outros drivers. Fundamentada em
`.modules\DataEngine\Source` (implementação) e no consumo real do ORM **Janus** +
do ERP (backend); todo fato é rastreável por `arquivo:linha`.

## Conceitos

- [Visão Geral](overview.md) — o que é o DataEngine, arquitetura (fábrica →
  driver → conexão), fontes da verdade e quando usar.
- [Referência Técnica](api.md) — as fábricas (`TFactoryFireDAC`), a base
  `TFactoryConnection`, e a execução de SQL (`CreateDataSet` / `CreateQuery` /
  `ExecuteDirect`).
- [`IDBConnection` & Transações](idbconnection.md) — a superfície da conexão e o
  contrato `IDBTransaction` (`StartTransaction`/`Commit`/`Rollback`, a transação
  `'DEFAULT'` compartilhada).
- [`IDBDataSet` / `IDBResultSet`](idbdataset.md) — o dataset/resultset abstrato,
  o **gotcha** do `NotEof` que auto-avança o cursor, e o acesso a campos.
- [Drivers & `TDriverName`](drivers.md) — o enum canônico de driver, a matriz
  driver↔fábrica e o cabeamento FireDAC.
- [Regras & Erratas](rules.md) — antipadrões e lições aprendidas na marra
  (LER — nunca repita os bugs).

## Playbooks

- [Playbooks](playbooks/index.md) — guias práticos passo a passo:
  - [Quickstart](playbooks/quickstart.md) — de uma `TFDConnection` a leituras e
    escritas via `IDBConnection`.
  - [Troubleshooting](playbooks/troubleshooting.md) — AV no `.Open` ad-hoc, loop
    infinito por `NotEof`, transação compartilhada envenenada, charset/leitura viva.

## Meta

- [Histórico](log.md) — log de criação/atualização desta base.
