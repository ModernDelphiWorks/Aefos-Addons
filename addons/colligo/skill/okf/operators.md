---
type: Reference
title: Colligo — Catálogo de Operadores
description: Mapa "um operador por unit" — filtragem, projeção, particionamento, ordenação, conjunto, junção, agrupamento, geração e conversão, com o nome exato da API e a unit-fonte.
tags: [colligo, linq, delphi, operators, reference]
timestamp: 2026-07-11T00:00:00Z
---

# Catálogo de Operadores

O Colligo implementa **um operador por unit** em `Source\`, todas registradas no
`uses` da implementação de `Colligo.pas` (`Source/Colligo.pas:467-506`). Os nomes
abaixo são os **reais** (confirmados no record `IColligoEnumerable<T>`,
`Source/Colligo.pas:90-290`) — **não** os nomes de memória do LINQ C#
(`delphi-colligo-specialist.md:15`, `:31`).

> Convenção: **[deferido]** = devolve outro `IColligoEnumerable<T>` (só encadeia);
> **[terminal]** = executa e devolve valor/coleção materializada. Só os terminais
> disparam a cadeia — ver [lazy-evaluation.md](lazy-evaluation.md).

## Filtragem

| Operador | Assinatura (resumo) | Unit-fonte | Ref record |
|---|---|---|---|
| `Where` | `Where(TFunc<T,Boolean>)` **[deferido]** | `Colligo.Where.pas` | `Colligo.pas:90` |
| `OfType<TResult>` | filtra por tipo **[deferido]** | `Colligo.OfType.pas` | `Colligo.pas:143` |
| `DefaultIfEmpty` | vazio → 1 elemento default **[deferido]** | `Colligo.DefaultIfEmpty.pas` | `Colligo.pas:198-199` |
| `Distinct` / `DistinctBy<TKey>` | remove duplicatas **[deferido]** | `Colligo.Distinct.pas` / `Colligo.DistinctBy.pas` | `Colligo.pas:93-97` |

> O filtro é **`Where`**, não `Filter` — apesar de o README usar "Filter" na
> descrição de features, a API real é `Where` (`Source/Colligo.Where.pas:25`,
> `Colligo.pas:527`).

## Projeção

| Operador | Assinatura | Unit | Ref |
|---|---|---|---|
| `Select<TResult>` | `Select<TResult>(TFunc<T,TResult>)` **[deferido]** | `Colligo.Select.pas` | `Colligo.pas:265` |
| `Select<TResult>` (indexado) | `Select<TResult>(TFunc<T,Integer,TResult>)` | `Colligo.SelectIndexed.pas` | `Colligo.pas:266` |
| `SelectMany<TResult>` | achata `TArray<TResult>` **[deferido]** | `Colligo.SelectMany.pas` | `Colligo.pas:267` |
| `SelectMany` (indexado / collection) | variantes com índice e `resultSelector` | `Colligo.SelectManyIndexed.pas`, `Colligo.SelectManyCollection.pas`, `Colligo.SelectManyCollectionIndexed.pas` | `Colligo.pas:268-274` |

> `Select` exige o **genérico explícito**: `.Select<string>(func)`
> (`Source/Colligo.pas:639`; `README.md:91-96`).

## Particionamento

| Operador | Semântica | Unit | Ref |
|---|---|---|---|
| `Take` / `TakeLast` | primeiros/últimos N **[deferido]** | `Colligo.Take.pas` / `Colligo.TakeLast.pas` | `Colligo.pas:91,213` |
| `TakeWhile` (+ indexado) | enquanto o predicado for verdade | `Colligo.TakeWhile.pas` / `Colligo.TakeWhileIndexed.pas` | `Colligo.pas:277-278` |
| `Skip` / `SkipLast` | pula primeiros/últimos N **[deferido]** | `Colligo.Skip.pas` / `Colligo.SkipLast.pas` | `Colligo.pas:92,212` |
| `SkipWhile` (+ indexado) | pula enquanto o predicado for verdade | `Colligo.SkipWhile.pas` / `Colligo.SkipWhileIndexed.pas` | `Colligo.pas:275-276` |
| `Chunk` | fatia em arrays de até N (o último pode ser menor) | `Colligo.Chunk.pas` | `Colligo.pas:224-230` |

> **`Chunk` devolve `IColligoEnumerableBase<TArray<T>>`, não o record** — para
> evitar o E2604 (uso recursivo de tipo genérico). Itere pelo `GetEnumerator` ou
> reembrulhe em `IColligoEnumerable<TArray<T>>.Create(...)` para encadear
> (`Source/Colligo.pas:224-230`). Ver Regra 5 em [rules.md](rules.md).

## Ordenação

| Operador | Assinatura | Unit | Ref |
|---|---|---|---|
| `OrderBy` | `OrderBy(TFunc<T,T,Integer>)` (comparador) **[deferido]** | `Colligo.OrderBy.pas` | `Colligo.pas:161` |
| `OrderBy<TKey>` | `OrderBy<TKey>(keySelector, IComparer<TKey>)` | `Colligo.OrderBy.pas` | `Colligo.pas:162` |
| `OrderByDesc` | comparador invertido | `Colligo.OrderBy.pas` | `Colligo.pas:164` |
| `Order` / `OrderDescending` | ordenação natural (comparer default) | `Colligo.OrderBy.pas` | `Colligo.pas:261-264` |
| `ThenBy<TKey>` / `ThenByDescending<TKey>` | critério subordinado (só após ordenar) | `Colligo.OrderBy.pas` | `Colligo.pas:287-288` |
| `Reverse` | inverte a ordem **[deferido]** | `Colligo.Reverse.pas` | `Colligo.pas:211` |

> `OrderBy` padrão recebe um **comparador** (ex.: `CompareText(A.Name,B.Name)`),
> não um key-selector (`README.md:110-114`). `ThenBy*` exige um resultado já
> ordenado — ver Regra 4 em [rules.md](rules.md).

## Operações de conjunto

| Operador | Semântica | Unit | Ref |
|---|---|---|---|
| `Distinct` / `DistinctBy<TKey>` | únicos | `Colligo.Distinct(By).pas` | `Colligo.pas:93-97` |
| `Union` / `UnionBy<TKey>` | união sem duplicatas | `Colligo.Union.pas` / `Colligo.UnionBy.pas` | `Colligo.pas:150-152,191-195` |
| `Intersect` / `IntersectBy<TKey>` | interseção | `Colligo.Intersect.pas` / `Colligo.IntersectBy.pas` | `Colligo.pas:147-149,205-209` |
| `Exclude` / `ExcludeBy<TKey>` | diferença (o "Except" do LINQ) | `Colligo.Exclude.pas` / `Colligo.ExcludeBy.pas` | `Colligo.pas:144-146,200-204` |
| `Concat` | concatena duas sequências | `Colligo.Concat.pas` | `Colligo.pas:153` |
| `Append` / `Prepend` | adiciona 1 elemento no fim/início | `Colligo.Append.pas` / `Colligo.Prepend.pas` | `Colligo.pas:196,210` |

> A diferença de conjuntos é **`Exclude`**, não `Except` (`Source/Colligo.pas:144`).

## Junção, agrupamento e zipping

| Operador | Semântica | Unit | Ref |
|---|---|---|---|
| `Join<TInner,TKey,TResult>` | inner join por chave | `Colligo.Join.pas` | `Colligo.pas:178-184` |
| `GroupJoin<TInner,TKey,TResult>` | left join agrupado | `Colligo.GroupJoin.pas` | `Colligo.pas:185-187` |
| `GroupBy<TKey>` (+ variantes) | agrupa por chave → `IGroupByEnumerable<TKey,T>` | `Colligo.GroupBy.pas` | `Colligo.pas:165-177` |
| `Zip<TSecond,TResult>` | pareia elemento-a-elemento | `Colligo.Zip.pas` | `Colligo.pas:141-142` |

> `GroupBy` devolve `IGroupByEnumerable<TKey,T>`; itere e leia `Grouping.Key` +
> `Grouping.Items` (`Source/Colligo.pas:293-317`;
> `Test Delphi/UTestColligo.ArrayStatic.pas:625-...`).

## Geração e conversão

| Operador | Semântica | Unit | Ref |
|---|---|---|---|
| `TColligo.Range/&Repeat/Empty` | gera sequência do zero | `Colligo.Generators.pas` | `Colligo.pas:451-463` |
| `Cast<TResult>` | reinterpreta cada elemento como `TResult` | `Colligo.Cast.pas` | `Colligo.pas:197` |
| `Parse` | conversão (ver unit) | `Colligo.Parse.pas` | — |
| `ToArray` / `ToList` / `ToHashSet` / `ToDictionary` / `ToLookup` | **[terminais]** materializam | núcleo | `Colligo.pas:188-190,279-290` |

## Agregações (terminais)

`Aggregate` (+ seed/result), `Sum`, `Average`, `Min`/`MinBy`, `Max`/`MaxBy`,
`Count`/`LongCount`/`CountBy`, `Any`/`All`, `Contains`, `First(OrDefault)`,
`Last(OrDefault)`, `Single(OrDefault)`, `ElementAt(OrDefault)`, `SequenceEqual`
— todas em `Source/Colligo.pas:98-260`. Comportamento de borda (overflow, vazio,
nullable) em [api.md](api.md).

## Citations

- `Source/Colligo.pas:90-290` — assinaturas dos operadores no record.
- `Source/Colligo.pas:467-506` — `uses` que lista uma unit por operador.
- `Source/Colligo.pas:224-230` — nota do `Chunk` (retorno base, E2604).
- `Source/Colligo.pas:293-317` — `IGroupByEnumerable`/`IGrouping`.
- `Source/Colligo.Where.pas:25`, `Colligo.Select.pas` — implementações.
- `README.md:31-38,110-114,142-150` — agrupamento por categoria (features).
- `delphi-colligo-specialist.md:15,20,31` — nomes reais vs LINQ C#.
