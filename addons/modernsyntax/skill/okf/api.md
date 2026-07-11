---
type: API Reference
title: ModernSyntax — Referência Técnica
description: Mapa das units, os pontos de entrada de cada tipo (TOption, TResultPair, TMatch, TDotEnv) e o uses correto, transcritos do Source com file:line.
tags: [modernsyntax, delphi, api, option, resultpair, match, dotenv, reference]
timestamp: 2026-07-11T00:00:00Z
---

# ModernSyntax — Referência Técnica

Tudo aqui é transcrito de `.modules\ModernSyntax\Source` e confirmado nos testes
`.modules\ModernSyntax\Test Delphi`. Este documento é o **índice de assinaturas**;
o detalhe de cada tipo está no seu concept-doc dedicado.

## `uses` — que unidade importar

| Recurso | `uses` | Tipo principal |
|---|---|---|
| Null-safety | `ModernSyntax.Option` | `TOption<T>` |
| Railway | `ModernSyntax.ResultPair` | `TResultPair<S, F>` |
| Pattern matching | `ModernSyntax.Match` | `TMatch<T>` |
| `.env` | `ModernSyntax.DotEnv` | `TDotEnv` |
| Arrow helper (nos idiomas de Match) | `ModernSyntax.ArrowFun` | `TArrow.Fn` |

`ModernSyntax.Option` já usa `ModernSyntax.ResultPair` internamente (para `OkOr`)
(`Source/ModernSyntax.Option.pas:22`); `ModernSyntax.Match` usa
`ModernSyntax.ResultPair`, `ModernSyntax.RegExpression` e `ModernSyntax.Std`
(`Source/ModernSyntax.Match.pas:26-29`).

## Entrada de cada tipo (assinaturas-chave)

### `TOption<T>` — `Source/ModernSyntax.Option.pas`
```pascal
class function Some(const AValue: T): TOption<T>; static;   // :69
class function None: TOption<T>; static;                    // :75
function IsSome: Boolean;  function IsNone: Boolean;         // :89, :95
function Unwrap: T;        // raise se None                  // :116
function UnwrapOr(const ADefault: T): T;                     // :123
function Expect(const AMessage: string): T;                  // :143
function Map<U>(const AFunc: TFunc<T, U>): TOption<U>;        // :151
procedure Match(const ASomeProc: TSomeProc<T>;
                const ANoneProc: TNoneProc); overload;       // :195
function OkOr<F>(const AFailure: F): TResultPair<T, F>;      // :188
property Value: T read GetValue;                             // :238 (GetValue raise em None :286)
```
Detalhe e idiomas: **[nullable.md](nullable.md)**.

### `TResultPair<S, F>` — `Source/ModernSyntax.ResultPair.pas`
```pascal
class function New: TResultPair<S, F>; static;               // :143
function Success(const ASuccess: S): TResultPair<S, F>;      // :164  (instância; use New.Success)
function Failure(const AFailure: F): TResultPair<S, F>;      // :175  (instância; use New.Failure)
function When<R>(const ASuccessFunc: TFunc<S, R>;
                 const AFailureFunc: TFunc<F, R>): R; overload;   // :227
function When(const ASuccessProc: TProc<S>;
              const AFailureProc: TProc<F>): TResultPair<S,F>; overload; // :229
function Map<R>(const ASuccessFunc: TFunc<S, R>): TResultPair<S,F>; // :245
function Reduce<R>(const AFunc: TFunc<S, F, R>): R;          // :209
function isSuccess: Boolean;  function isFailure: Boolean;   // :447, :455
function ValueSuccess: S;     function ValueFailure: F;      // :466, :477
```
Detalhe e idiomas: **[railway-result.md](railway-result.md)**.

### `TMatch<T>` — `Source/ModernSyntax.Match.pas`
```pascal
class function Value(const AValue: T): TMatch<T>; static;    // :156  (ponto de partida)
function CaseEq(const AValue: T; ...): TMatch<T>;            // :162-167
function CaseIf(const ACondition: Boolean; ...): TMatch<T>;  // :157-161 (guarda)
function CaseIn(const ARange: TArray<T>; ...): TMatch<T>;    // :176-190
function CaseRange(const AStart, AEnd: T; ...): TMatch<T>;   // :195-198
function CaseRegex(const AInput, APattern: String): TMatch<T>; // :199
function Default(...): TMatch<T>;                            // :200-204
function Execute: TResultPair<Boolean, String>; overload;   // :207
function Execute<R>: TResultPair<R, String>; overload;       // :208
```
Detalhe e idiomas: **[pattern-matching.md](pattern-matching.md)**.

### `TDotEnv` — `Source/ModernSyntax.DotEnv.pas`
```pascal
constructor Create(const AFileName: String = '.env';
                   AUseSystemFallback: Boolean = True);      // :44
function Get<T>(const AName: String): T;                     // :104 (raise se ausente)
function GetOr<T>(const AName: String; const ADefault: T): T; // :98  (default se ausente/erro)
function TryGet<T>(const AName: String; out AValue: T): Boolean; // :91
function Value<T>(const AName: String): T;                   // :84  (alias de Get<T>)
procedure Add(const AName: String; const AValue: TValue);    // :66
function EnvLoad(const AName: String): String;               // :124 (env var do SO)
property UseSystemFallback: Boolean ...;                     // :148
```
Detalhe e idiomas: **[dotenv.md](dotenv.md)**.

## Convenções observadas no Source

- **Records por valor, sem `Free`:** `TOption`, `TResultPair` e `TMatch` são
  `record` (`Source/ModernSyntax.Option.pas:48`,
  `Source/ModernSyntax.ResultPair.pas:57`) — vivem na pilha; não há `Create`
  destrutível. `TDotEnv` é `class` e precisa de `Free`/`try..finally`
  (`Source/ModernSyntax.DotEnv.pas:30,182`).
- **`New.` inicia a cadeia railway:** o idioma consagrado nos testes é
  `TResultPair<S,F>.New.Success(x)` / `.New.Failure(x)`
  (`Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105,120`), NÃO
  `TResultPair<...>.Success(...)` como classe (o README erra nisso).
- **`Value` inicia o match:** `TMatch<T>.Value(x)`, não `Create`
  (`Test Delphi/EclbrSystem/UTestMS.Match.pas:194`).

## Citations

- `Source/ModernSyntax.Option.pas:22,48,69-238,286` — imports e assinaturas de `TOption<T>`.
- `Source/ModernSyntax.ResultPair.pas:57,143,164,175,209,227-229,245,447-477` — `TResultPair<S,F>`.
- `Source/ModernSyntax.Match.pas:26-29,156-208` — `uses` e cases de `TMatch<T>`.
- `Source/ModernSyntax.DotEnv.pas:30,44,66,84-124,148,182` — `TDotEnv`.
- `Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105,120` — idioma `New.Success`/`New.Failure`.
- `Test Delphi/EclbrSystem/UTestMS.Match.pas:194` — idioma `TMatch<T>.Value`.
