---
type: Framework Overview
title: Colligo — Visão Geral
description: O que é o Colligo, sua arquitetura (record fluente + adapters + lazy), fontes da verdade, quando usar e a relação com o FluentQuery e o backend Axial.
tags: [colligo, linq, delphi, lazy-evaluation, collections, overview]
timestamp: 2026-07-11T00:00:00Z
---

# Colligo — Visão Geral

O **Colligo** é uma biblioteca de programação funcional e manipulação de coleções
para Delphi e Lazarus, autor **Isaque Pinheiro** (ModernDelphiWorks), licença MIT
(`Source/Colligo.pas:5-10`). É uma releitura em Object Pascal do **C# LINQ to
Objects** (`System.Linq`), inspirada também em streams de Java/Kotlin/Rust; o
conjunto de operadores, a semântica de execução deferida/imediata e os casos de
borda espelham deliberadamente o LINQ (`README.md:10`, `:23`, `:135`).

No ecossistema do dono, o Colligo é a lib LINQ que o **backend Axial realmente
embarca** e **sucedeu o FluentQuery** — se alguém pede "FluentQuery" no contexto
do backend novo, quase sempre é Colligo (`delphi-colligo-specialist.md:7`).

## Arquitetura em uma frase

Uma coleção-fonte (array/lista/dicionário) entra por uma **factory** →
transforma-se num record leve `IColligoEnumerable<T>` → você **encadeia
operadores** (cada um envolve o anterior num enumerável preguiçoso) → **nada
executa** até um operador **terminal** (`ToArray`/`ToList`/agregação) puxar a
cadeia via `GetEnumerator`.

```
TArray<T> / TList<T> / TDictionary        (fonte)
        │  TColligoArray.From<T> / TColligoList<T>.From
        ▼
IColligoEnumerable<T>   (record leve — Source/Colligo.pas:67)
        │  .Where(...).Select<>(...).OrderBy(...) …   (deferido: só encadeia)
        ▼
operador terminal  .ToArray / .ToList / .Sum / .Count / .First …
        │  puxa GetEnumerator → MoveNext em cascata
        ▼
IColligoArray<T> / IColligoList<T> / valor agregado   (materializado)
```

- O **núcleo** é um **record** `IColligoEnumerable<T>` (não uma classe), com um
  campo `IColligoEnumerableBase<T>` que aponta para o enumerável da etapa anterior
  (`Source/Colligo.pas:67-291`). Records leves + interfaces ARC = "zero-allocation
  core", sem overhead de heap por etapa (`README.md:29`, `:141`).
- Os **adapters** (`Source/Colligo.Adapters.pas`) fazem a ponte da fonte concreta
  (`TArrayAdapter`, `TListAdapter`, `TDictionaryAdapter`) para o enumerador
  Colligo. Uma factory embrulha a fonte e devolve `IColligoEnumerable<T>`
  (`Source/Colligo.Collections.pas:229-232`, `:288-291`, `:748-755`).
- Cada **operador vive em sua própria unit** em `Source\` (ex.: `Colligo.Where.pas`,
  `Colligo.Select.pas`, `Colligo.OrderBy.pas`), registrada no `uses` da
  implementação de `Colligo.pas` (`Source/Colligo.pas:467-506`). Detalhe em
  [operators.md](operators.md).

## Camadas do Source (para investigar)

- **Núcleo / record** — `Source/Colligo.Core.pas` (`TColligoType`,
  `ColligoNullable<T>` e os aliases `NullableInt32/Int64/Single/Currency/Double`
  em `:27-52`) e `Source/Colligo.pas` (o record `IColligoEnumerable<T>` e todos os
  métodos, `:67-291`).
- **Coleções / factories** — `Source/Colligo.Collections.pas`: `TColligoArray<T>`,
  o record utilitário `TColligoArray`, `TColligoList<T>`, `TColligoDictionary<K,V>`
  e seus `From(...)`.
- **Operadores** — `Source/Colligo.<Operador>.pas` (um por unit), cada um um
  `TColligo<Op>Enumerable<T>` + `TColligo<Op>Enumerator<T>` que streama.
- **Provider SQL** — `Source/Colligo.Queryable.pas` (`IColligoQueryable<T>` +
  `IColligoQueryProvider<T>`), sobre `FluentSQL.*` e `DataEngine.*`, atrás de
  `{$IFDEF QUERYABLE}`. Ver [queryable-sql.md](queryable-sql.md).
- **Strings** — `Source/Colligo.Helpers.pas`: `TColligoString`
  (`record helper for string`, `:45`). Ver [colligostring.md](colligostring.md).
- **Providers JSON/XML** — `Source/Colligo.Json.pas`, `Colligo.Json.Provider.pas`,
  `Colligo.Xml.pas`, `Colligo.Xml.Provider.pas`: hoje **stubs vazios** (só
  skeleton de interface, sem implementação). Não afirme suporte a query sobre
  JSON/XML. Ver Regra 6 em [rules.md](rules.md).

## Fontes da verdade (estude ANTES de afirmar)

1. **README bilíngue** — `.modules\Colligo\README.md`, com os exemplos canônicos
   (EN §"English" e PT §"Português"; ex.: `TColligoArray.From<Integer>(...)` em
   `README.md:84-96` / `:196-208`; `TColligoList<TUser>.From(...)` em `:109-122` /
   `:221-234`).
2. **Source** — `.modules\Colligo\Source\Colligo.*.pas`, a implementação real
   (um operador por unit).
3. **Testes** — `.modules\Colligo\Test Delphi\` (DUnitX): comportamento verificado
   e casos de borda (ex.: `UTestColligo.ArrayStatic.pas`, `UTestColligo.List.pas`,
   `UTestColligo.FluentSQL.pas`, `UTestColligo.StringHelper.pas`).
4. **Docs** — `.modules\Colligo\docs\` / `docs-src\` (Docusaurus). Empacotamento:
   **boss** (`boss.json`) + pubpascal + SBOM CycloneDX (`sbom\`), CRA-ready
   (`README.md:6-8`).

**NÃO assuma nomes de operadores por memória do LINQ C#** — confirme no Source
(`delphi-colligo-specialist.md:15`, `:31`).

## Quando usar

- Pós-processar em memória resultados do Janus/DataEngine: filtrar, mapear,
  agrupar, deduplicar por chave e agregar coleções de entidades de forma
  declarativa antes de serializar (`delphi-colligo-specialist.md:27`).
- Substituir loops imperativos `for`/`while` sobre `TArray<T>`/`TList<T>` por um
  pipeline legível `Where → Select<> → OrderBy → ToArray`.
- Precisa de agregações code-side (somas de totalização, contagens por chave).

## Quando NÃO usar / limites

- **Não substitua o ORM.** Data-access continua sendo Janus (ORM) → DataEngine;
  FluentSQL para SQL avulso. Colligo é a CAMADA DE COLEÇÕES em memória
  (`delphi-colligo-specialist.md:26-28`).
- **Não emita SQL pelo Colligo** a menos que use explicitamente o provider
  `IColligoQueryable<T>` (que depende de FluentSQL/DataEngine e do define
  `QUERYABLE`). Ver [queryable-sql.md](queryable-sql.md).
- **JSON/XML providers não existem ainda** (stubs). Para JSON avulso o ecossistema
  usa **JsonFlow**.

## Citations

- `README.md:10,23,29,84-96,109-122,135,141,196-208,221-234` — inspiração LINQ,
  lazy/zero-alloc e exemplos canônicos.
- `Source/Colligo.pas:67-291` — o record `IColligoEnumerable<T>` (núcleo).
- `Source/Colligo.pas:451-506` — geradores estáticos `TColligo` e o `uses` que
  lista os operadores (um por unit).
- `Source/Colligo.Collections.pas:229-232,288-291,748-755` — factories/adapters.
- `Source/Colligo.Core.pas:27-52` — `TColligoType` e `ColligoNullable<T>`.
- `Source/Colligo.Json.pas:20-31`, `Source/Colligo.Xml.pas:20-31` — providers stub.
- `delphi-colligo-specialist.md:3,7,15,26-28,31` — Axial/FluentQuery, fontes,
  não-inventar nomes, regra da casa.
