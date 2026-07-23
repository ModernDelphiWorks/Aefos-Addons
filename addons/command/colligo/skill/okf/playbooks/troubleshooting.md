---
type: Playbook
title: Colligo — Troubleshooting
description: Sintoma → causa-raiz → fix dos erros mais caros do Colligo — nada executa (lazy), overflow em Sum, sequência vazia, Chunk que não encadeia, providers JSON/XML inexistentes e o gotcha Linux do TColligoString.
tags: [colligo, linq, delphi, troubleshooting, debug]
timestamp: 2026-07-11T00:00:00Z
---

# Troubleshooting

Sintoma → causa-raiz → fix, com a fonte. Regras completas em [../rules.md](../rules.md).

## "Montei o pipeline mas nada acontece" / o lambda não roda

- **Causa-raiz:** execução **deferida**. `Where`/`Select`/`OrderBy`/`GroupBy` só
  encadeiam; nada roda até um operador **terminal**.
- **Fix:** termine com `ToArray`/`ToList` (ou uma agregação `Count`/`Sum`/`First`…).
  O selector/predicado dispara aí (`Test Delphi/UTestColligo.ArrayStatic.pas:706-723`).
- **Corolário:** efeitos colaterais rodam no consumo, uma vez por item; cada
  terminal re-executa a cadeia (sem cache) — materialize uma vez se for reusar.
- Fonte: `delphi-colligo-specialist.md:33`. Ver [../lazy-evaluation.md](../lazy-evaluation.md).

## `EIntOverflow` num `Sum`

- **Causa-raiz:** `Sum` sobre `Integer`/`Int32`/`Int64` detecta overflow (acumula
  em Int64 e valida a cada passo, como o `checked int` do C#) e **lança**
  `EIntOverflow` (`Source/Colligo.pas:778-797`, `:813-851`).
- **Fix:** some com o seletor de maior faixa (`Sum(TFunc<T,Int64>)` /
  `Sum(TFunc<T,Double>)` / `SumCurrency`) quando o total puder estourar 32 bits.

## `EInvalidOperation: Sequence contains no elements`

- **Causa-raiz:** `Aggregate`/`Min`/`Max`/`Average` (não-nullable) numa sequência
  **vazia** lançam (`Source/Colligo.pas:667-668`, `:990-991`, `:1238-1239`,
  `:1262-1263`).
- **Fix:** cheque `Any`/`Count > 0` antes, ou use `FirstOrDefault`/`LastOrDefault`
  (devolvem `Default(T)`), ou as sobrecargas **nullable** de `Sum`/`Average`
  (`Sum` nullable de vazio = 0; `Average` nullable de vazio = null —
  `Source/Colligo.pas:888`, `:1080-1083`).

## "Não consigo encadear depois do `Chunk`"

- **Causa-raiz:** `Chunk` devolve `IColligoEnumerableBase<TArray<T>>`, **não** o
  record `IColligoEnumerable<TArray<T>>` (para evitar o E2604 do compilador —
  `Source/Colligo.pas:224-230`).
- **Fix:** itere pelo `GetEnumerator`, ou reembrulhe:
  `IColligoEnumerable<TArray<T>>.Create(minhaCadeia.Chunk(N))` para continuar o
  pipeline.

## `E2604 recursive use of generic type` ao compilar um operador sobre `TArray<T>`

- **Causa-raiz:** um record genérico não pode devolver uma instanciação de si
  mesmo sobre um tipo derivado do próprio `T` — foi exatamente por isso que
  `Chunk` devolve a interface base (`Source/Colligo.pas:224-230`).
- **Fix:** siga o padrão do `Chunk` — devolva `IColligoEnumerableBase<...>` e
  reembrulhe no ponto de uso.

## `ThenBy`/`ThenByDescending` sem efeito

- **Causa-raiz:** `ThenBy` lê o critério primário do campo `FOrdered`, preenchido
  só pelos operadores de ordenação (`Source/Colligo.pas:73-77`, `:558-560`).
- **Fix:** chame `OrderBy`/`Order`/`OrderByDesc`/`OrderDescending` **antes** do
  `ThenBy`.

## "Quero consultar um JSON/XML com Colligo"

- **Causa-raiz:** os providers JSON/XML são **stubs vazios** — anunciados no
  README (`README.md:38`, `:150`) mas não implementados no Source
  (`Source/Colligo.Json.pas:20-31`, `Colligo.Xml.pas:20-31`).
- **Fix:** para JSON avulso use **JsonFlow**. O único provider real do Colligo é o
  **SQL** `IColligoQueryable<T>` — ver [../queryable-sql.md](../queryable-sql.md).

## `IColligoQueryable<T>` não compila / "unknown identifier"

- **Causa-raiz:** o provider SQL está atrás de `{$IFDEF QUERYABLE}` (`:353`) e
  depende de `FluentSQL.*`/`DataEngine.*` (uses da interface,
  `Source/Colligo.Queryable.pas:29-33`) e `ModernSyntax.Tuple` (uses da
  implementation, `:340`).
- **Fix:** defina `QUERYABLE` e ponha as libs no search path; senão fique só no
  lado in-memory (`IColligoEnumerable<T>`).

## Linux64: erro de compilação em `UCS4LowerCase`/`UCS4UpperCase`

- **Causa-raiz:** fallback Linux antigo do `TColligoString` chamava símbolos
  inexistentes no RTL Linux.
- **Fix (já no Source):** locale usa o caminho `USE_LIBICU`; o fallback usa
  `System.SysUtils.LowerCase`/`UpperCase` (`Source/Colligo.Helpers.pas:1509-1514`).
  Garanta o Source atualizado. Windows inalterado.
- Fonte: `delphi-colligo-specialist.md:32`. Ver [../colligostring.md](../colligostring.md).

## Citations

- `delphi-colligo-specialist.md:32,33` — erratas de campo (lazy, Linux).
- `Source/Colligo.pas:73-77,224-230,558-560,667-668,778-797,888,990-991,1080-1083,1238-1263`.
- `Source/Colligo.Queryable.pas:29-33,340,353` — deps (interface + implementation)/define do provider SQL.
- `Source/Colligo.Json.pas:20-31`; `Colligo.Xml.pas:20-31` — providers stub.
- `Source/Colligo.Helpers.pas:1509-1514` — fix Linux do casing.
- `Test Delphi/UTestColligo.ArrayStatic.pas:706-723` — prova do lazy.
