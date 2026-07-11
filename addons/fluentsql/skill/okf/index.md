---
okf_version: "0.1"
---

# Knowledge Bundle Index — FluentSQL Specialist

Base de conhecimento do especialista no **FluentSQL** (Delphi/Lazarus, por Isaque
Pinheiro) — DSL fluente para gerar **SQL/MQL avulso** com qualificadores por
dialeto. Fundamentada em `.modules\FluentSQL\Source` (implementação) e
`.modules\FluentSQL\Test Delphi` (uso correto, com a SQL esperada por dialeto);
todo fato é rastreável por `arquivo:linha`.

## Conceitos

- [Visão Geral](overview.md) — o que é o FluentSQL, arquitetura (só gera string;
  executa no DataEngine), a relação com o Janus, fontes da verdade e quando usar.
- [Referência Técnica](api.md) — ponto de entrada `FluentSQL.Query`, o contrato
  `IFluentSQL` (builder), funções (`IFluentSQLFunctions`), drivers/dialetos e os
  terminais `AsString`/`Params`.
- [SELECT](select.md) — colunas, `All`/`Distinct`, `From`, `WHERE`
  (operadores tipados vs. fragmento raw), `AndOpe`/`OrOpe`, `CASE WHEN`, funções,
  `GROUP BY`/`HAVING`/`ORDER BY`, `IN`/`EXISTS` com subquery.
- [Joins & Paginação](joins-paging.md) — `InnerJoin`/`LeftJoin`/`RightJoin`/
  `FullJoin` + `OnCond`; paginação `First`/`Skip` renderizada por dialeto
  (FIRST/SKIP · LIMIT/OFFSET · ROW_NUMBER · ROWNUM).
- [DML](dml.md) — `INSERT` (`Into`/`SetValue`/`AddRow`), `UPDATE` (`Update`/
  `SetValue`/`Where`) e `DELETE` (`Delete`/`From`/`Where`); sobrecargas de
  `SetValue` e formatação de datas.
- [Dialetos & Fragmentos Específicos](dialects.md) — a enum `TFluentSQLDriver`,
  `ForDialectOnly` (ESP-016) e o alvo MongoDB (MQL, não SQL).
- [Regras & Erratas](rules.md) — antipadrões e lições aprendidas na marra
  (LER — nunca repita os bugs).

## Playbooks

- [Playbooks](playbooks/index.md) — guias práticos passo a passo:
  - [Quickstart](playbooks/quickstart.md) — do `FluentSQL.Query` a um SELECT
    paginado + INSERT/UPDATE/DELETE, e como executar via DataEngine.
  - [Troubleshooting](playbooks/troubleshooting.md) — `:pN` não-vinculado,
    `Between`/`Sum` inexistentes no builder, dialeto errado na paginação.

## Meta

- [Histórico](log.md) — log de criação/atualização desta base.
