---
type: Playbook
title: ModernSyntax — Quickstart
description: Cada recurso do ModernSyntax (TOption, TResultPair, TMatch, TDotEnv) com o idioma real em poucas linhas, do uses ao consumo, seguindo os testes DUnitX.
tags: [modernsyntax, delphi, quickstart, option, resultpair, match, dotenv]
timestamp: 2026-07-11T00:00:00Z
---

# Quickstart — os quatro recursos em minutos

Idiomas transcritos dos testes `.modules\ModernSyntax\Test Delphi`. Cada passo cita
a fonte. Detalhe completo nos concept-docs: [nullable](../nullable.md) ·
[railway-result](../railway-result.md) · [pattern-matching](../pattern-matching.md)
· [dotenv](../dotenv.md).

## 1. Null-safety — `TOption<T>`

```pascal
uses ModernSyntax.Option;

function BuscarNome(const AId: Integer): TOption<string>;
begin
  if AId = 1 then Result := TOption<string>.Some('Isaque')
  else             Result := TOption<string>.None;
end;

// consumo seguro (nunca AV):
Writeln(BuscarNome(1).UnwrapOr('desconhecido'));   // 'Isaque'
BuscarNome(9).Match(
  procedure(const V: string) begin Writeln('achei: ', V) end,
  procedure begin Writeln('nada') end);
```
Fonte: `Test Delphi/EclbrSystem/UTestMS.Option.pas:142-143,206,234`;
`Source/ModernSyntax.Option.pas:69,75,123,195`. **NÃO** use `HasValue`/`ValueOrElse`
(não existem — Regra 1).

## 2. Railway — `TResultPair<S, F>`

```pascal
uses ModernSyntax.ResultPair;

function Dividir(const A, B: Double): TResultPair<Double, string>;
begin
  if B = 0 then Result := TResultPair<Double, string>.New.Failure('div/0')
  else          Result := TResultPair<Double, string>.New.Success(A / B);
end;

// consumo (fold com When):
LTexto := Dividir(10, 2).When<string>(
  function(V: Double): string begin Result := 'ok: '  + V.ToString end,
  function(E: string): string begin Result := 'erro: ' + E end);
```
Fonte: `Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105,120,182-193`;
`Source/ModernSyntax.ResultPair.pas:143,164,175,227`. Sempre `New.` antes de
`Success`/`Failure` (Regra 4).

## 3. Pattern matching — `TMatch<T>`

```pascal
uses ModernSyntax.Match;

LResult := TMatch<Integer>.Value(LInput)
  .CaseEq(1, procedure begin LMsg := 'Primeiro' end)
  .CaseEq(2, procedure begin LMsg := 'Segundo'  end)
  .Default(procedure begin LMsg := 'Outro' end)
  .Execute;                       // TResultPair<Boolean, String>

if LResult.isSuccess then Writeln(LMsg);
```
Fonte: `Test Delphi/EclbrSystem/UTestMS.Match.pas:194-200,255`;
`Source/ModernSyntax.Match.pas:156,162,200,207`. A entrada é `Value` (não
`Create`); o fim é `Execute` (não `MatchValue`) — Regra 1.

## 4. Configuração — `TDotEnv`

Arquivo `.env`:
```dotenv
# app
HOST=localhost
PORT = 8080
URL=http://${HOST}:${PORT}/api
```
Código:
```pascal
uses ModernSyntax.DotEnv;

var LEnv: TDotEnv;
begin
  LEnv := TDotEnv.Create('.env');   // fallback ao SO = True por default
  try
    LPort := LEnv.GetOr<Integer>('PORT', 8080);   // 8080
    LHost := LEnv.Get<String>('HOST');            // 'localhost'
    LUrl  := LEnv.Get<String>('URL');             // 'http://localhost:8080/api'
  finally
    LEnv.Free;                                    // é CLASS: precisa Free
  end;
end;
```
Fonte: `Test Delphi/EclbrSystem/UTestMS.DotEnv.pas:59,81-97,110-113`;
`Source/ModernSyntax.DotEnv.pas:44,104,321,372`. Defina `HOST`/`PORT` **antes** de
`URL` (interpolação só vê o que já foi lido — Regra 8).

## Checklist final

- [ ] `TOption`: consumir com `UnwrapOr`/`Match`, nunca `.Value` num possível None (Regra 3).
- [ ] `TResultPair`: `New.Success`/`New.Failure` + consumir com `When`/`isSuccess` (Regras 4/5).
- [ ] `TMatch`: `Value → Case* → Default → Execute`; o retorno é um `TResultPair` (Regra 6).
- [ ] `TDotEnv`: `try..finally Free`; `Get<T>` bom só p/ `Integer`/`String` (Regras 7/9).
- [ ] Ignorar snippets do README com `HasValue`/`CaseOf`/`Success` de classe (Regra 1).

## Citations

- `Test Delphi/EclbrSystem/UTestMS.Option.pas:142-243` — TOption.
- `Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105-193` — TResultPair.
- `Test Delphi/EclbrSystem/UTestMS.Match.pas:194-269` — TMatch.
- `Test Delphi/EclbrSystem/UTestMS.DotEnv.pas:59-156` — TDotEnv.
- `Source/ModernSyntax.Option.pas:69,75,123,195` · `ModernSyntax.ResultPair.pas:143,164,175,227` · `ModernSyntax.Match.pas:156,207` · `ModernSyntax.DotEnv.pas:44,104,372`.
