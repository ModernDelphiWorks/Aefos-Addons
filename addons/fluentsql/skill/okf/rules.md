---
type: Rules
title: FluentSQL — Regras & Erratas
description: Antipadrões e lições aprendidas na marra do FluentSQL; cada uma vira uma regra NUNCA/SEMPRE com o caso real citado. LER antes de montar WHERE executado via IDBConnection.CreateDataSet.
tags: [fluentsql, sql, delphi, rules, errata, antipatterns, parametrization]
timestamp: 2026-07-11T00:00:00Z
---

# Regras & Erratas

Regras destiladas do especialista curado (`delphi-fluentsql-specialist.md:20-24`) e
do Source/Testes. **LER antes de montar um WHERE que será executado via
`IDBConnection.CreateDataSet`.** Cada regra carrega o caso REAL que a originou —
não a resuma a ponto de perder o caso.

## SEMPRE — fundamentar em código

- **SEMPRE cite `arquivo:linha`** (Source e/ou `Test Delphi`). Sem fonte, leia —
  não chute (`delphi-fluentsql-specialist.md:13`).
- **SEMPRE use `FluentSQL.Query(dbn...)`** como entrada; `TCQ`/`CreateFluentSQL`
  são `deprecated` (`Source/Core/FluentSQL.pas:238,240`).
- **SEMPRE escolha o dialeto do banco alvo.** Para Firebird vivo, `dbnFirebird`;
  não assuma sintaxe MSSQL (`delphi-fluentsql-specialist.md:21`).

## Regra 1 — Operadores tipados PARAMETRIZAM; SQL cru via CreateDataSet quebra

**NUNCA use os operadores tipados de valor (`.Equal('x')`, `.InValues([...])`,
etc.) num SELECT que será executado por `IDBConnection.CreateDataSet` — esse
caminho roda SQL cru SEM bind de parâmetro, então o `:p1` gerado fica
não-vinculado e o filtro quebra.**

- Os operadores de string parametrizam: `.Where('col').Equal('x')` → `col = :p1`;
  e listas `.InValues([1,2,3])` → `IN (:p1, :p2, :p3)`
  (`Test Delphi/Firebird_tests/test.operators.isin.firebird.pas:64-75`;
  `Test Delphi/Common_tests/test.core.params.pas:361-362`).
- **Solução:** condições de valor como **fragmento raw**: `.Where('col = ' +
  QuotedStr(v))` / `.AndOpe('col = ' + QuotedStr(v))`. `.Where(rawPredicate)`
  **NÃO** parametriza (`test.select.firebird.pas:119-130`). Overloads de
  Integer/Float/Date **formatam/quotam sozinhos** e podem sair inline
  (`test.operators.equal.firebird.pas:100-124`).

**Caso real (ABC_DAO, DFeFw 2026-06-21):** um SELECT com `.Equal('x')` gerou
`:p1`; ao rodar via `CreateDataSet` o parâmetro não foi vinculado → filtro vazio.
Corrigido passando a condição como fragmento raw
(`delphi-fluentsql-specialist.md:24`).

> ⚠️ Nuance a confirmar por versão: em `test.operators.equal.firebird.pas:104` o
> Integer sai **inline** (`= 10`), mas em `test.core.params.pas:362` `Equal(1)`
> sai **`:p1`** (contexto de parâmetros, ESP-010/011 — `CHANGELOG.md:141,149`).
> **Não presuma inline nem `:pN` de cabeça — verifique o `.AsString` gerado** e,
> em execução sem bind, use fragmento raw.

## Regra 2 — `Sum`/`Average` NÃO estão no builder `IFluentSQL`

**NUNCA chame `.Sum`/`.Average` diretamente na cadeia do builder — não existem
lá.** O builder tem `Count/Min/Max/Lower/Upper/SubString/Date/Day/Month/Year/
Concat` (`Source/Core/FluentSQL.Interfaces.pas:293-303`). `Sum`/`Average` vivem em
`IFluentSQLFunctions` (`:786-787`).

**Para `SUM(col)`:** `LQuery.AsFun.Sum('col')` (ou `Func(dbn...).Sum('col')`)
retorna a string raw `'SUM(col)'`; combine com `.Column(<raw>).Alias('x')` para
`SUM(col) AS x`. Provado em
`Test Delphi/MongoDB_tests/test.dml.mongodb.pas:92-101`
(`delphi-fluentsql-specialist.md:22`).

## Regra 3 — NÃO existe operador `Between`

**NUNCA procure `.Between` — não existe em `IFluentSQL` nem em
`IFluentSQLOperators`.** `fcBetween`/`fcNotBetween` existem no enum
`TFluentSQLOperatorCompare` (`Source/Core/FluentSQL.Interfaces.pas:604`) e
serializam para `'between'`/`'not between'` (`Source/Core/FluentSQL.Operators.pas:239-240`),
mas **nenhum método público em `IFluentSQL`/`IFluentSQLOperators` os expõe**. Para
`col BETWEEN a AND b`, passe um **fragmento raw** a `.Where(...)`/`.AndOpe(...)`
(`delphi-fluentsql-specialist.md:23`).

## Regra 4 — FluentSQL gera; DataEngine executa

**NUNCA espere que o FluentSQL execute a SQL.** Ele só produz a string via
`.AsString`. Para rodar, passe ao DataEngine (`IDBConnection`)
(`delphi-fluentsql-specialist.md:18`). Lembre da errata do DataEngine sobre
`CreateDataSet` — prefira o container do Janus quando possível
(`delphi-fluentsql-specialist.md:18`).

## Regra 5 — LIKE por afixo tem semântica fixa

`.LikeFull('V')` → `'%V%'`; `.LikeLeft('V')` → `'%V'`; `.LikeRight('V')` → `'V%'`
(`Test Delphi/Firebird_tests/test.operators.like.firebird.pas:49-86`). **NÃO
inverta** `LikeLeft`/`LikeRight`: "Left" = curinga à esquerda (termina com), "Right"
= curinga à direita (começa com).

## Regra 6 — Patches no `.modules\FluentSQL`

Ao corrigir o próprio framework: **branch dedicada no repo do frw + backup
pristino + PR no final** (várias equipes editam em paralelo). O projeto consumidor
**NUNCA** commita `.modules` (política do ecossistema do dono).

## Citations

- `delphi-fluentsql-specialist.md:13,18,20-24` — errata destilada (fonte primária destas regras).
- `Source/Core/FluentSQL.Interfaces.pas:293-303,604,786-787` — builder sem Sum/Average/Between; funções.
- `Test Delphi/Firebird_tests/test.operators.isin.firebird.pas:64-75` — `IN (:p1, :p2, :p3)`.
- `Test Delphi/Firebird_tests/test.operators.equal.firebird.pas:100-124` — inline por tipo.
- `Test Delphi/Common_tests/test.core.params.pas:361-362`; `CHANGELOG.md:141,149` — `:pN` (ESP-010/011).
- `Test Delphi/MongoDB_tests/test.dml.mongodb.pas:92-101` — `AsFun.Sum/Average`.
- `Test Delphi/Firebird_tests/test.operators.like.firebird.pas:49-86` — afixos LIKE.
