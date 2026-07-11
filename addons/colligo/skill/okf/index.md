---
okf_version: "0.1"
---

# Knowledge Bundle Index — Colligo Specialist

Base de conhecimento do especialista no **Colligo** (Delphi/Lazarus, por Isaque
Pinheiro) — coleções fluentes estilo **LINQ-to-Objects** com **lazy evaluation**.
Fundamentada no `README.md` (exemplos canônicos), `.modules\Colligo\Source`
(implementação) e `.modules\Colligo\Test Delphi` (comportamento verificado); todo
fato é rastreável por `arquivo:linha`.

## Conceitos

- [Visão Geral](overview.md) — o que é o Colligo, arquitetura (record + adapters
  + lazy), fontes da verdade, quando usar e a relação com o FluentQuery/Axial.
- [Referência Técnica](api.md) — entradas (`TColligoArray.From<T>`,
  `TColligoList<T>.From`, `TColligo.Range/&Repeat/Empty`), o record
  `IColligoEnumerable<T>` e os materializadores (`ToArray`/`ToList` + agregações).
- [Catálogo de Operadores](operators.md) — o mapa "um operador por unit":
  filtragem, projeção, particionamento, ordenação, conjunto, junção, agrupamento,
  geração e conversão.
- [Lazy Evaluation](lazy-evaluation.md) — deferred execution, o que é terminal vs
  deferido, re-enumeração da fonte e as armadilhas de efeito colateral.
- [Provider SQL `IColligoQueryable<T>`](queryable-sql.md) — o lado banco de dados
  sobre FluentSQL + DataEngine (atrás de `{$IFDEF QUERYABLE}`); e por que os
  providers JSON/XML ainda são stubs.
- [`TColligoString`](colligostring.md) — o `record helper for string` e o gotcha
  Linux de `ToLower`/`ToUpper`.
- [Regras & Erratas](rules.md) — antipadrões e lições aprendidas na marra
  (LER — nunca repita os bugs).

## Playbooks

- [Playbooks](playbooks/index.md) — guias práticos passo a passo:
  - [Quickstart](playbooks/quickstart.md) — do array cru a um pipeline
    filtrar → mapear → ordenar → materializar.
  - [Troubleshooting](playbooks/troubleshooting.md) — nada executa, overflow em
    `Sum`, sequência vazia, `Chunk` que não encadeia, gotcha Linux do
    `TColligoString`.

## Meta

- [Histórico](log.md) — log de criação/atualização desta base.
