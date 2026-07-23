---
type: API Reference
title: Colligo — Referência Técnica
description: Entradas (factories), o record IColligoEnumerable<T>, materializadores (ToArray/ToList) e agregações terminais, transcritos do Source com file:line.
tags: [colligo, linq, delphi, api, enumerable, materializers, aggregations]
timestamp: 2026-07-11T00:00:00Z
---

# Colligo — Referência Técnica

Tudo aqui é transcrito de `.modules\Colligo\Source`, do `README.md` e dos testes.
O catálogo completo de operadores intermediários está em [operators.md](operators.md);
esta página cobre **como entrar**, **o record central** e **como sair**
(materializar).

## Schema — Entradas (factories)

Toda cadeia começa transformando uma fonte concreta num `IColligoEnumerable<T>`:

```pascal
uses Colligo, Colligo.Collections;

// A partir de um TArray<T> (ou array aberto):
TColligoArray.From<Integer>([1,2,3,4,5])            // record TColligoArray
// A partir de um TList<T> ou TArray<T>:
TColligoList<TUser>.From(MyList)                     // classe TColligoList<T>
// Geradores sem fonte (Enumerable.Range/Repeat/Empty do LINQ):
TColligo.Range(1, 5)                                 // 1,2,3,4,5 (o 2º arg é COUNT)
TColligo.&Repeat<string>('x', 3)                     // 'x','x','x'
TColligo.Empty<Integer>                             // sequência vazia
```

- `TColligoArray.From<T>(array of T): IColligoEnumerable<T>` — record utilitário,
  `Source/Colligo.Collections.pas:56`, `:288-291`. Há também a versão de classe
  `TColligoArray<T>.From(TArray<T>)` / `From(TList<T>)`
  (`Source/Colligo.Collections.pas:41-42`, `:264-286`).
- `TColligoList<T>.From(TList<T>)` / `From(TArray<T>)`
  (`Source/Colligo.Collections.pas:96-97`, `:762-777`).
- `TColligo.Range(AStart, ACount)` / `TColligo.&Repeat<T>(AElement, ACount)` /
  `TColligo.Empty<T>` — geradores estáticos, todos deferidos
  (`Source/Colligo.pas:451-463`). **`Range(1,5)` = 1,2,3,4,5** — o 2º argumento é
  uma CONTAGEM, não um valor final (`Source/Colligo.pas:453-457`).

> As factories embrulham a fonte numa interface ARC para não vazar; o adapter
> guarda a própria cópia dos dados, então o enumerável continua válido depois que
> o wrapper é liberado (`Source/Colligo.Collections.pas:264-274`, `:762-772`).

## Schema — O record central `IColligoEnumerable<T>`

`Source/Colligo.pas:67-291`. É um **record** (valor), não uma classe — copia
barato e vive na pilha. Métodos-chave (assinaturas reais):

```pascal
// deferidos (devolvem outro IColligoEnumerable<T>):
function Where(const APredicate: TFunc<T, Boolean>): IColligoEnumerable<T>;         // :90
function Select<TResult>(const ASelector: TFunc<T, TResult>): IColligoEnumerable<TResult>; // :265
function Select<TResult>(const ASelector: TFunc<T, Integer, TResult>): ...;         // :266 (indexado)
function Take(const ACount: Integer): IColligoEnumerable<T>;                         // :91
function Skip(const ACount: Integer): IColligoEnumerable<T>;                         // :92
function Distinct: IColligoEnumerable<T>;                                            // :93
function OrderBy(const AComparer: TFunc<T, T, Integer>): IColligoEnumerable<T>;      // :161
function GroupBy<TKey>(const AKeySelector: TFunc<T, TKey>): IGroupByEnumerable<TKey, T>; // :165

// terminais (materializam / disparam a execução):
function ToArray: IColligoArray<T>;                                                  // :289
function ToList: IColligoList<T>;                                                    // :290
```

- **`Where`** é o filtro. **NÃO existe `Filter`** como método — o texto de
  features do README fala em "Filter", mas a API é `Where`
  (`Source/Colligo.pas:90`, `:527`; `delphi-colligo-specialist.md:15`).
- **`Select<TResult>`** é a projeção/map, com o **genérico explícito**
  obrigatório: `.Select<string>(func)` (`Source/Colligo.pas:265`, `:639`;
  `README.md:91-96`). Há a variante indexada `Select<TResult>(TFunc<T,Integer,TResult>)`.
- **`OrderBy`** recebe um **comparador** `TFunc<T,T,Integer>` (estilo
  `CompareText`), não um key-selector por padrão (`Source/Colligo.pas:161`,
  `:554`; `README.md:110-114`). Há a sobrecarga `OrderBy<TKey>(keySelector,
  IComparer<TKey>)` (`:162`). `ThenBy`/`ThenByDescending` só valem **depois** de um
  operador de ordenação (`:287-288`) — ver Regra 4 em [rules.md](rules.md).

## Schema — Materializadores e agregações (terminais)

`ToArray`/`ToList` e **toda agregação** consomem o enumerador e disparam a
execução (`Source/Colligo.pas`):

```pascal
function ToArray: IColligoArray<T>;   // :289
function ToList:  IColligoList<T>;    // :290

// agregações (executam imediatamente):
function Count: Integer;                                   // :137
function Any:   Boolean;  // e Any(predicate)              // :124-125
function All(const APredicate: TFunc<T, Boolean>): Boolean;// :126
function First / FirstOrDefault / Last / LastOrDefault;    // :129-136
function Single / SingleOrDefault;                         // :155-158
function Aggregate(const AReducer: TFunc<T, T, T>): T;     // :98 (+ overloads com seed)
function Sum(const ASelector: TFunc<T, Double>): Double;   // :109 (+ Integer/Int64/Currency/Nullable…)
function Average(...): Double / Nullable…;                 // :214-223
function Min / Max;  // + MinBy<TKey> / MaxBy<TKey>        // :120-123, :233-260
function Contains(const AValue: T): Boolean;               // :127
```

### Pegando o `TArray<T>` cru

`IColligoArray<T>` expõe `ArrayData: TArray<T>` (read-only), `Items[]` e
`Length` (`Source/Colligo.pas:330-341`). O idioma canônico do README é
`…ToArray.ArrayData`:

```pascal
LResult := TColligoArray.From<Integer>(LNumbers)
  .Where(function(const X: Integer): Boolean begin Result := X mod 2 = 0; end)
  .Take(3)
  .Select<string>(function(const X: Integer): string begin Result := 'Number ' + IntToStr(X); end)
  .ToArray
  .ArrayData;                                    // TArray<string>
// LResult = ['Number 2', 'Number 4', 'Number 6']
```
Fonte: `README.md:84-100` / `:196-212`.

### Semântica confirmada (código/testes/errata)

- **Nada executa até um terminal.** O map (`Select`) só roda no `ToArray` — o
  `Writeln` de dentro do selector só imprime na materialização
  (`Test Delphi/UTestColligo.ArrayStatic.pas:706-723`). Detalhe em
  [lazy-evaluation.md](lazy-evaluation.md).
- **`ToArray`/`ToList` são não-destrutivos** (copiam; a fonte permanece
  consultável) — `Source/Colligo.Collections.pas:733-741`.
- **`Sum` sobre `Integer` detecta overflow** e lança `EIntOverflow` (acumula em
  Int64 e valida a cada passo, espelhando o `checked int` do C#) —
  `Source/Colligo.pas:778-797`. O mesmo para `Int64`/`Int32`.
- **`Aggregate`/`Min`/`Max` numa sequência vazia lançam** `EInvalidOperation`
  ("Sequence contains no elements") — `Source/Colligo.pas:667-668`, `:1238-1239`,
  `:1262-1263`. Já `FirstOrDefault`/`LastOrDefault` devolvem `Default(T)`.
- **Agregações nullable de sequência vazia:** `Sum` nullable = 0 (nunca null,
  nunca lança) — `Source/Colligo.pas:888`; `Average` nullable = null
  (`NullableDouble.CreateEmpty`) — `Source/Colligo.pas:1080-1083`. `Average`
  não-nullable de vazio lança `EInvalidOperation` (`:990-991`).

## Coleções auxiliares

Além das factories, `Source/Colligo.Collections.pas` traz coleções concretas
usáveis diretamente: `TColligoList<T>` (`:75-150`, wrapper sobre `TList<T>` com
`AsEnumerable`) e `TColligoDictionary<K,V>` (`:152-202`). O record utilitário
`TColligoArray` também expõe `Sort`/`BinarySearch`/`IndexOf`/`Concat`/`ToString`
estáticos sobre arrays (`:49-73`).

## Citations

- `Source/Colligo.pas:67-291` — record `IColligoEnumerable<T>` (todas as assinaturas).
- `Source/Colligo.pas:330-341` — `IColligoArray<T>` (`ArrayData`, `Items`, `Length`).
- `Source/Colligo.pas:451-463` — geradores `TColligo.Range/&Repeat/Empty`.
- `Source/Colligo.pas:778-797` — `Sum` com detecção de overflow.
- `Source/Colligo.pas:667-668,888,990-991,1080-1083` — sequência vazia / nullable.
- `Source/Colligo.Collections.pas:41-42,56,96-97,264-291,733-741,762-777` —
  factories e `ToArray` não-destrutivo.
- `README.md:84-100,196-212` — pipeline canônico + `.ToArray.ArrayData`.
- `Test Delphi/UTestColligo.ArrayStatic.pas:706-723` — prova da execução deferida.
- `delphi-colligo-specialist.md:15` — `Where` (não `Filter`), `Select<T>` explícito.
