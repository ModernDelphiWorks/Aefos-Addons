---
type: Playbook
title: ModernSyntax — Troubleshooting
description: Sintoma → causa-raiz → fix dos erros mais caros do ModernSyntax — nomes do README que não compilam, AV por acessar None, Get<T> que não converte, ${VAR} que não expande e Execute mal interpretado.
tags: [modernsyntax, delphi, troubleshooting, debug, option, resultpair, match, dotenv]
timestamp: 2026-07-11T00:00:00Z
---

# Troubleshooting

Sintoma → causa-raiz → fix, com a fonte. Regras completas em [../rules.md](../rules.md).

## "Undeclared identifier" em `HasValue` / `ValueOrElse` / `CaseOf` / `ElseOf` / `MatchValue`

- **Causa-raiz:** você copiou um snippet do `README.md` — esses nomes **não
  existem** no Source. O README está desatualizado.
- **Fix:** use os nomes reais — `IsSome` no lugar de `HasValue`
  (`Option.pas:89`), `UnwrapOr` no lugar de `ValueOrElse` (`Option.pas:123`),
  `CaseEq` no lugar de `CaseOf` (`Match.pas:162`), `Default` no lugar de `ElseOf`
  (`Match.pas:200`), `Execute` no lugar de `MatchValue` (`Match.pas:207`).
- Fonte: `README.md:65-83,87-105`. Ver Regra 1.

## "não compila": `TResultPair<...>.Success(...)` ou `.Failure(...)`

- **Causa-raiz:** `Success`/`Failure` são funções de **instância**
  (`ResultPair.pas:164,175`); não dá para chamá-las como `class function`.
- **Fix:** inicie com `New`: `TResultPair<S,F>.New.Success(x)` /
  `.New.Failure(x)` (`ResultPair.pas:143`; idioma em
  `Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105,120`).
- Ver Regra 4.

## Access Violation / Exception ao ler um `TOption`

- **Sintoma:** `Exception: 'Attempted to access a value from TOption.None'` (ou AV
  logo depois de um lookup).
- **Causa-raiz:** acessou `LOpt.Value` ou `LOpt.Unwrap` num `TOption` que estava
  `None` — ambos chamam `GetValue`, que lança (`Option.pas:286-291`).
- **Fix:** cheque `IsSome` antes, ou use `UnwrapOr(default)` /
  `UnwrapOrElse(func)` / `Expect('msg')` (`Option.pas:298,306,342`), ou consuma via
  `Match(someProc, noneProc)` (`Option.pas:397`).
- Ver Regra 3.

## `TDotEnv.Get<T>` estoura ou devolve lixo para `Boolean`/`Double`/data

- **Causa-raiz:** `Get<T>` só converte explicitamente `Integer` e `String`; outros
  tipos caem em ramos frágeis (`DotEnv.pas:334-359`).
- **Fix:** leia como `String` e converta você mesmo
  (`StrToBool`/`StrToFloat`/`ISO8601ToDate`), ou use `GetOr<T>` para não estourar
  (`DotEnv.pas:372-419`). `Value<T>` tem a mesma limitação (é alias de `Get<T>`).
- Ver Regra 7.

## `${VAR}` aparece literal no valor (não interpolou)

- **Causa-raiz:** a variável referenciada ainda **não tinha sido lida** quando a
  linha foi processada — `_ReplaceVars` só resolve o que já está no dicionário
  (`DotEnv.pas:229-248`).
- **Fix:** declare a variável-base ANTES da que a referencia no `.env` (ex.:
  `HOST=` e `PORT=` antes de `URL=...${HOST}:${PORT}...`).
- **Cuidado extra:** um `#` no meio do valor vira comentário
  (`DotEnv.pas:207-211`) — o valor é truncado ali.
- Ver Regra 8.

## `TMatch.Execute` "não devolve o valor que casei"

- **Causa-raiz:** `Execute` devolve `TResultPair<Boolean, String>` (e `Execute<R>`,
  `TResultPair<R, String>`), não o valor cru (`Match.pas:207-208`).
- **Fix:** para efeito colateral, use `Case*` com `TProc` e mute sua própria var;
  para produzir valor, use `Case*` com `TFunc` e leia via `Execute<R>` + `When`.
  Cheque `isSuccess` antes de usar (`UTestMS.Match.pas:255`).
- Ver Regra 6.

## Vazamento / "não liberei" com os tipos do ModernSyntax

- **Causa-raiz:** confundir record com class. `TOption`/`TResultPair`/`TMatch` são
  `record` (pilha, sem `Free`); `TDotEnv` é `class`.
- **Fix:** só `TDotEnv` precisa de `try..finally … Free` (`DotEnv.pas:30,182`). Um
  `TResultPair` cujo `S` é objeto pode chamar `Dispose` para liberá-lo
  (`ResultPair.pas:153`).
- Ver Regra 9.

## Citations

- `Source/ModernSyntax.Option.pas:89,123,286-291,298-342,397` — nomes reais e raise em None.
- `Source/ModernSyntax.ResultPair.pas:143,153,164,175,207-208` — New/Success/Failure/Dispose/Execute.
- `Source/ModernSyntax.Match.pas:162,200,207-208` — CaseEq/Default/Execute.
- `Source/ModernSyntax.DotEnv.pas:30,182,207-263,334-419` — parsing e conversão.
- `Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105,120`; `Test Delphi/EclbrSystem/UTestMS.Match.pas:255`.
- `README.md:65-83,87-105,110-121` — origem dos nomes que não compilam.
