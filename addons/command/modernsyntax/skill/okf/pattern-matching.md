---
type: API Reference
title: ModernSyntax — Pattern matching com TMatch<T>
description: O casamento tipado TMatch<T> — Value → CaseEq/CaseIf/CaseGt/CaseLt/CaseIn/CaseRange/CaseIs/CaseRegex → Default → Execute, devolvendo um TResultPair, transcrito do Source com file:line.
tags: [modernsyntax, delphi, match, pattern-matching, case, execute, api]
timestamp: 2026-07-11T00:00:00Z
---

# Pattern matching — `TMatch<T>`

`TMatch<T>` é um **record** que substitui `if/case` aninhado por um casamento
fluente e tipado. Você parte de um valor (`Value`), encadeia cláusulas `Case*`,
opcionalmente um `Default`, e finaliza em `Execute`, que devolve um
**`TResultPair<Boolean, String>`** (ou `TResultPair<R, String>` na forma
genérica). Unidade: `ModernSyntax.Match` (`Source/ModernSyntax.Match.pas`;
entrada `Value` em `:156`).

> ⚠️ **A API real NÃO é `Create/CaseOf/ElseOf/MatchValue`** (como no
> `README.md:87-105`). É `Value` → `CaseEq`/`Default` → `Execute`. Ver
> [rules.md](rules.md).

## Schema — a forma canônica

```pascal
uses ModernSyntax.Match;

var
  LResult: TResultPair<Boolean, String>;
  LMsg: string;
begin
  LResult := TMatch<Integer>.Value(LInput)                 // ponto de partida  :156
    .CaseEq(1, procedure begin LMsg := 'Primeiro' end)     // igual a 1         :162
    .CaseEq(2, procedure begin LMsg := 'Segundo'  end)
    .CaseEq(3, procedure begin LMsg := 'Terceiro' end)
    .Default(procedure begin LMsg := 'Outro' end)          // fallback          :200
    .Execute;                                              // roda o match      :207

  if LResult.isSuccess then ... ;   // Execute devolve TResultPair
end;
```
Idioma real: `Test Delphi/EclbrSystem/UTestMS.Match.pas:194-200,245-253`.

## Schema — cláusulas de caso (todas devolvem `TMatch<T>`)

| Cláusula | Casa quando | Linhas |
|---|---|---|
| `CaseEq(v, proc/func)` | valor **igual** a `v` (aceita `TArray<T>`, `Tuple`) | `:162-167` |
| `CaseIf(cond [, proc/func])` | a **guarda** `cond: Boolean` é verdadeira | `:157-161` |
| `CaseGt(v, …)` / `CaseLt(v, …)` | valor **maior** / **menor** que `v` | `:168-175` |
| `CaseIn(range, …)` | valor **pertence** a `TArray<T>` / `TSysCharSet` / `TIntegerSet` | `:176-190` |
| `CaseRange(a, b, …)` | valor no **intervalo** `[a, b]` | `:195-198` |
| `CaseIs<Typ>(…)` | valor **é do tipo** `Typ` | `:191-194` |
| `CaseRegex(input, pattern)` | `input` **casa** a regex `pattern` | `:199` |
| `Default(…)` | nenhum caso anterior casou | `:200-204` |
| `Combine(outroMatch)` | mescla outro `TMatch` | `:205` |
| `TryExcept(proc)` | trata exceção dentro do match | `:206` |

Cada `Case*` tem sobrecargas com `TProc`, `TProc<T>`, `TProc<TValue>`,
`TFunc<TValue>` e `TFunc<T, TValue>` — use `proc` para efeito colateral e `func`
para produzir um valor a ser lido via `Execute<R>` (`:157-204`).

## Schema — Execute e o resultado

```pascal
function Execute: TResultPair<Boolean, String>;   // sucesso/falha do casamento  :207
function Execute<R>: TResultPair<R, String>;       // com valor de retorno R       :208
```
`Execute` valida a cadeia e devolve um `TResultPair` — consuma-o com
`isSuccess`/`When` ([railway-result.md](railway-result.md)). Idioma:
`LMatchResult.isSuccess` em `UTestMS.Match.pas:255`.

## Examples — casamento por array e por regex

```pascal
// casa um TArray<Integer> e valida um e-mail por regex, com Default:
LMatchResult := TMatch<TArray<Integer>>.Value(LValue)
  .CaseEq([1, 2, 3], procedure begin LIsMatch := False end)
  .CaseEq([1, 4, 8], procedure begin LIsMatch := True  end)
  .CaseRegex('email@gmail.com', '^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$')
  .Default(procedure begin LIsMatch := False end)
  .Execute;
```
Fonte: `Test Delphi/EclbrSystem/UTestMS.Match.pas:245-253`.

```pascal
// CaseIn com a arrow-function TArrow.Fn (atribui um valor a uma var):
uses ModernSyntax.ArrowFun;   // TArrow.Fn<T>(var AVar, AValue): TProc<TValue>

LMatchResult := TMatch<Integer>.Value(2)
  .CaseIn([1, 2, 3], TArrow.Fn<Boolean>(LIsMatch, True))
  .CaseIn([1, 4, 8], TArrow.Fn<Boolean>(LIsMatch, False))
  .Execute;
```
Fonte: `Test Delphi/EclbrSystem/UTestMS.Match.pas:210-214`; `TArrow.Fn<T>` em
`Source/ModernSyntax.ArrowFun.pas:58`.

## Guardas com `CaseIf`

`CaseIf` recebe uma condição `Boolean` já avaliada e serve de **guarda** antes de
um `CaseEq` (encadeados, viram um AND lógico):
```pascal
TMatch<Integer>.Value(LValue)
  .CaseIf((LValue > 0) and (0 < LValue))     // guarda
  .CaseEq(1, procedure begin LMsg := 'Matched 1 with AndGuard' end)
  .Execute;
```
Fonte: `Test Delphi/EclbrSystem/UTestMS.Match.pas:194-200`.

## Citations

- `Source/ModernSyntax.Match.pas:32-60` — `TCaseType`, `TMatchSession`, tipos internos.
- `Source/ModernSyntax.Match.pas:156-208` — `Value` e todas as cláusulas `Case*`/`Default`/`Execute`.
- `Source/ModernSyntax.ArrowFun.pas:52-58` — `TArrow.Fn`.
- `Test Delphi/EclbrSystem/UTestMS.Match.pas:194-269` — idiomas reais (CaseEq/CaseIn/CaseRegex/Default/Execute/isSuccess).
- `README.md:87-105` — snippet DESATUALIZADO (Create/CaseOf/ElseOf/MatchValue).
