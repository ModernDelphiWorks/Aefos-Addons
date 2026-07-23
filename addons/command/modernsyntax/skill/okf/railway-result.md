---
type: API Reference
title: ModernSyntax — Railway com TResultPair<S,F>
description: O tipo de erro funcional TResultPair<S,F> — New.Success/New.Failure, When, Map/FlatMap, Reduce, isSuccess/ValueSuccess e o encadeamento Ok/Fail/ThenOf/ExceptOf, transcrito do Source com file:line.
tags: [modernsyntax, delphi, resultpair, railway, success, failure, when, api]
timestamp: 2026-07-11T00:00:00Z
---

# Railway-oriented — `TResultPair<S, F>`

`TResultPair<S, F>` é um **record** que carrega OU um valor de sucesso `S` OU um
valor de falha `F` — nunca os dois. É o "railway": em vez de lançar exceção pela
camada, um serviço devolve `Success(x)` ou `Failure(e)`, e o chamador consome com
`When`. Unidade: `ModernSyntax.ResultPair`
(`Source/ModernSyntax.ResultPair.pas:57`).

> Estado interno é um enum `TResultType = (rtNone, rtSuccess, rtFailure)`
> (`:25`). Exceções de apoio: `EFailureException<F>`, `ESuccessException<S>`,
> `ETypeIncompatibility` (`:27-38`).

## Schema — criar um resultado

```pascal
uses ModernSyntax.ResultPair;

function Dividir(const A, B: Double): TResultPair<Double, string>;
begin
  if B = 0 then
    Result := TResultPair<Double, string>.New.Failure('divisão por zero')  // :143 + :175
  else
    Result := TResultPair<Double, string>.New.Success(A / B);              // :143 + :164
end;
```
- `New` é o `class function` estático que inicia a cadeia (`:143`).
- `Success`/`Failure` são funções **de instância** (`:164`, `:175`) — por isso o
  idioma é `New.Success(...)` / `New.Failure(...)`, confirmado em
  `Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105,120`.

> ⚠️ O `README.md:110-121` chama `TResultPair<Double, string>.Failure('...')` como
> se `Failure` fosse `class function` — **não é**; precisa do `New.` antes. Ver
> [rules.md](rules.md).

## Schema — consumir com When (o "fold")

```pascal
// devolvendo um valor (fold):
LTexto := Dividir(10, 2).When<string>(
  function(V: Double): string begin Result := 'ok: ' + V.ToString end,   // sucesso
  function(E: string): string begin Result := 'erro: ' + E end);         // falha

// só efeitos colaterais (procedures):
Dividir(10, 0).When(
  procedure(V: Double) begin Writeln(V) end,
  procedure(E: string) begin Writeln('falhou: ', E) end);
```
Fonte: `When<R>` (`:227`) e `When(proc,proc)` (`:229`). Idioma real:
`When<Boolean>(succFunc, failFunc)` em
`Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:182-193`.

## Schema — consultar / extrair

```pascal
LR.isSuccess;      // Boolean                     :447
LR.isFailure;      // Boolean                     :455
LR.ValueSuccess;   // S — RAISE se for falha       :466
LR.ValueFailure;   // F — RAISE se for sucesso     :477
LR.SuccessOrDefault(0.0);            // S ou default        :394
LR.SuccessOrException;               // S ou re-raise falha :369
LR.FailureOrDefault('');             // F ou default        :439
```
Idioma: `ValueSuccess` em `UTestMS.ResultPair.pas:113,143,168`.

## Schema — transformar (mantendo o trilho)

```pascal
LR2 := LR.Map<Double>(function(V: Double): Double begin Result := V * 2 end);  // :245
LR3 := LR.Reduce<Integer>(
         function(V: Integer; E: string): Integer begin Result := V + 5 end);  // :209
LR4 := LR.FlatMap(function(V: S): TResultValue begin ... end);                  // :278
LR5 := LR.Recover<Double>(function(E: string): Double begin Result := 0 end);   // :343
LR6 := LR.Swap;                                                                 // :327
```
- `Map<R>` mapeia só o lado de sucesso (há sobrecarga para o lado de falha em
  `:261`) mantendo o outro intacto (`:245-261`). Idioma: `UTestMS.ResultPair.pas:137,152`.
- `Reduce<R>` recebe AMBOS (valor e erro) e produz um `R` (`:209`). Idioma:
  `UTestMS.ResultPair.pas:205-209`.
- `FlatMap` usa `TResultValue` (record com `Success`/`Failure: TValue`, `:40-44`)
  para poder virar sucesso→falha e vice-versa (`:278-295`). Idioma:
  `UTestMS.ResultPair.pas:106,121`.
- `Recover<R>` (sobre `TResultPair<S, F>`) devolve **`TResultPair<R, S>`** (`:343`)
  — ⚠️ note a **troca de posições dos tipos**: `R` vira o novo lado de sucesso e o
  `S` original desce para o slot de falha (não é `TResultPair<S, F>`).

## Schema — encadeamento fluente (workflow)

```pascal
TResultPair<S,F>.New
  .Ok(procedure(V: S) begin ... end)         // marca sucesso           :502
  .Fail(procedure(E: F) begin ... end)       // marca falha             :514
  .ThenOf(function(const V: S): TResultPair<S,F> begin ... end)  // passo no sucesso :526
  .ExceptOf(function(const E: F): TResultPair<S,F> begin ... end)// passo na falha   :538
  .Exec(function: TResultPair<S,F> begin ... end)               // passo custom     :490
  .Return;                                    // recupera o resultado final :547
```

## Regra de ouro

Serviços do ecossistema retornam `TResultPair`/`TResponse`; **NÃO lance exceção
pela camada — converta em `Failure`** e consuma com `When`
(`delphi-modernsyntax-specialist.md:16`). Como `TResultPair` é record, ele vive na
pilha — não há `Free` (mas `Dispose` (`:153`) libera um `S` do tipo classe, se
houver).

## Citations

- `Source/ModernSyntax.ResultPair.pas:25-44` — `TResultType`, `TResultValue`, exceções.
- `Source/ModernSyntax.ResultPair.pas:57-547` — `TResultPair<S,F>` completo.
- `Source/ModernSyntax.ResultPair.pas:143,164,175,209,227-229,245-295,343,447-477,490-547` — assinaturas citadas.
- `Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105,120,137,152,182-193,205-209` — idiomas reais.
- `README.md:110-121` — snippet DESATUALIZADO (Success/Failure sem `New`).
- `delphi-modernsyntax-specialist.md:16` — regra "converta exceção em Failure".
