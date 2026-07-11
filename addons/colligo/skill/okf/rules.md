---
type: Rules
title: Colligo — Regras & Erratas
description: Antipadrões e lições aprendidas na marra do Colligo; cada uma vira uma regra NUNCA/SEMPRE com o caso real citado. LER antes de escrever um pipeline ou depurar.
tags: [colligo, linq, delphi, rules, errata, antipatterns]
timestamp: 2026-07-11T00:00:00Z
---

# Regras & Erratas

Regras destiladas do especialista curado (`delphi-colligo-specialist.md:30-33`) e
do Source. **LER antes de escrever um pipeline ou depurar.** Cada regra carrega o
caso REAL que a originou — não a resuma a ponto de perder o caso.

## SEMPRE — fundamentar em código

- **SEMPRE cite `arquivo:linha`** (README/Source/Test). Sem fonte, leia — não
  chute (`delphi-colligo-specialist.md:15`, `:37`).
- **SEMPRE confirme o nome do operador no Source** antes de usar. O README fala em
  "Filter" nas features, mas a API é `Where`; a diferença de conjuntos é `Exclude`
  (não `Except`); `Select` exige o genérico explícito. Ver [operators.md](operators.md).
- **SEMPRE lembre que Colligo é a camada de COLEÇÕES em memória** — data-access é
  Janus → DataEngine; FluentSQL para SQL avulso (`delphi-colligo-specialist.md:26-28`).

## Regra 1 — NÃO decore nomes de operadores pela memória do LINQ C#

**NUNCA assuma um nome de método pela lembrança do `System.Linq`.** Confirme no
`Source`:

- filtro = **`Where`**, não `Filter` (`Source/Colligo.Where.pas:25`, `Colligo.pas:527`);
- projeção = **`Select<TResult>`** com genérico explícito, não `Map`
  (`Source/Colligo.pas:265`, `:639`);
- diferença de conjunto = **`Exclude`**, não `Except` (`Source/Colligo.pas:144`);
- não há `Cast`/`OfType` no provider SQL (comentados) — só no in-memory
  (`Source/Colligo.Queryable.pas:264-266`).

Caso/fonte: `delphi-colligo-specialist.md:15`, `:31`.

## Regra 2 — Lazy: nada executa até um terminal

**NUNCA espere que montar o pipeline processe dados.** `Where`/`Select`/`OrderBy`
etc. só encadeiam; o trabalho (e os efeitos colaterais dos lambdas) dispara no
operador **terminal** (`ToArray`/`ToList`/agregação). Prova: o `Writeln` dentro de
um `Select` só imprime no `ToArray` (`Test Delphi/UTestColligo.ArrayStatic.pas:706-723`).

Consequências:
- **Efeitos colaterais rodam no consumo, uma vez por item.**
- **Cada terminal re-executa a cadeia** — não há cache; materialize uma vez se for
  reusar.
- Fonte volátil pode dar resultados diferentes entre dois terminais.

Caso/fonte: `delphi-colligo-specialist.md:33`. Ver [lazy-evaluation.md](lazy-evaluation.md).

## Regra 3 — `Sum` inteiro pode lançar `EIntOverflow`; sequência vazia lança em `Aggregate/Min/Max/Average`

**NUNCA trate agregações como "sempre seguras".** O comportamento espelha o LINQ
com `checked`:

- `Sum` sobre `Integer`/`Int32`/`Int64` **detecta overflow e lança `EIntOverflow`**
  (acumula em Int64 e valida a cada passo — `Source/Colligo.pas:778-797`, `:813-851`).
- `Aggregate`/`Min`/`Max` numa **sequência vazia lançam `EInvalidOperation`**
  ("Sequence contains no elements") — `Source/Colligo.pas:667-668`, `:1238-1239`,
  `:1262-1263`.
- `Average` não-nullable de vazio **lança** (`Source/Colligo.pas:990-991`); a
  variante **nullable de vazio devolve null** (`:1080-1083`), e `Sum` nullable de
  vazio devolve **0** (`:888`).

Fix prático: para sequência possivelmente vazia use `FirstOrDefault`/`Count>0`
antes, ou as sobrecargas nullable.

## Regra 4 — `ThenBy`/`ThenByDescending` só valem DEPOIS de um operador de ordenação

**NUNCA chame `ThenBy` sem um `OrderBy`/`Order`/`OrderByDesc`/`OrderDescending`
antes.** O critério subordinado é lido do campo interno `FOrdered`, que só é
preenchido pelos operadores de ordenação (`Source/Colligo.pas:73-77`, `:558-560`).
Chamar `ThenBy` numa cadeia não-ordenada não tem critério primário para
subordinar.

## Regra 5 — `Chunk` NÃO devolve o record; encadeie com cuidado

**NUNCA espere continuar o pipeline direto de um `Chunk`.** Ele devolve
`IColligoEnumerableBase<TArray<T>>` (a interface base), **não** o record
`IColligoEnumerable<TArray<T>>` — para evitar o E2604 ("recursive use of generic
type") do compilador. Itere pelo `GetEnumerator` ou reembrulhe em
`IColligoEnumerable<TArray<T>>.Create(...)` para encadear
(`Source/Colligo.pas:224-230`).

## Regra 6 — Providers JSON/XML NÃO estão implementados (stubs)

**NUNCA afirme que o Colligo consulta JSON/XML.** As units `Colligo.Json.pas`,
`Colligo.Json.Provider.pas`, `Colligo.Xml.pas` e `Colligo.Xml.Provider.pas` são
**stubs vazios** — só skeleton de interface, sem implementação
(`Source/Colligo.Json.pas:20-31`, `Colligo.Xml.pas:20-31`). O README anuncia
"JSON datasets and XML documents" nos format providers (`README.md:38`, `:150`),
mas isso ainda não existe no Source. Para JSON avulso, o ecossistema usa
**JsonFlow**. O único provider real é o **SQL** `IColligoQueryable<T>` — ver
[queryable-sql.md](queryable-sql.md).

## Regra 7 — Gotcha Linux do `TColligoString.ToLower/ToUpper`

Ao compilar para **Linux64**, o fallback de caixa chamava
`UCS4LowerCase`/`UCS4UpperCase` (inexistentes no RTL Linux) → não compilava. Já
corrigido: locale usa o caminho `USE_LIBICU`; o fallback usa
`System.SysUtils.LowerCase`/`UpperCase` (`Source/Colligo.Helpers.pas:1509-1514`).
Windows inalterado. Relevante só se o backend rodar em Linux
(`delphi-colligo-specialist.md:32`). Ver [colligostring.md](colligostring.md).

## Regra 8 — Provider SQL depende de `{$IFDEF QUERYABLE}` + FluentSQL/DataEngine

**NUNCA assuma que `IColligoQueryable<T>` está disponível sem o define.** Ele está
atrás de `{$IFDEF QUERYABLE}` (`:353`) e importa `FluentSQL.*`/`DataEngine.*` (uses
da interface, `Source/Colligo.Queryable.pas:29-33`) e `ModernSyntax.Tuple` (uses da
implementation, `:340`). Sem o define e sem as libs no search path, só o lado
in-memory compila.

## Citations

- `delphi-colligo-specialist.md:15,26-28,30-33,37` — errata destilada (fonte primária).
- `Source/Colligo.pas:73-77,144,224-230,265,558-560,667-668,778-797,888,990-991,1080-1083` — comportamentos citados.
- `Source/Colligo.Where.pas:25`; `Colligo.Select.pas` — nomes reais.
- `Source/Colligo.Json.pas:20-31`; `Colligo.Xml.pas:20-31` — providers stub.
- `Source/Colligo.Helpers.pas:1509-1514` — fix Linux do casing.
- `Source/Colligo.Queryable.pas:29-33,340,353` — deps (interface + implementation) e define do provider SQL.
- `Test Delphi/UTestColligo.ArrayStatic.pas:706-723` — prova do lazy.
