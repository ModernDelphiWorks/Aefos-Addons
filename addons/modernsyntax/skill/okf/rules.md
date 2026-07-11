---
type: Rules
title: ModernSyntax — Regras & Erratas
description: Antipadrões e armadilhas do ModernSyntax; cada um vira uma regra NUNCA/SEMPRE com o caso real citado. LER antes de recomendar uma API — o README está parcialmente desatualizado; o Source manda.
tags: [modernsyntax, delphi, rules, errata, antipatterns]
timestamp: 2026-07-11T00:00:00Z
---

# Regras & Erratas

Regras destiladas do especialista curado (`delphi-modernsyntax-specialist.md:9-25`)
e do Source/Test. **LER antes de recomendar qualquer API.** Cada regra carrega o
caso REAL que a originou — não a resuma a ponto de perder o caso.

## SEMPRE — fundamentar em código

- **SEMPRE cite `arquivo:linha`** (Source e/ou Test Delphi). Sem fonte, leia — não
  chute (`delphi-modernsyntax-specialist.md:13`).
- **SEMPRE confirme o idioma no `Test Delphi`** antes de recomendar. Os testes
  DUnitX (`EclbrSystem\UTestMS.*.pas`, `EclbrResultPair\UTestMS.ResultPair.pas`)
  são o uso correto ponta a ponta; a pasta `Examples\` só tem Currying/Corrotina.

## Regra 1 — O `README.md` está DESATUALIZADO; o Source é a verdade

**NUNCA copie um snippet do `README.md` sem checar o Source.** Vários exemplos do
README usam nomes que **não existem** no código:

| README diz | NÃO existe / errado | Use (Source) | Fonte |
|---|---|---|---|
| `LOpt.HasValue` | não há | `LOpt.IsSome` | `Option.pas:89` |
| `LOpt.ValueOrElse('x')` | não há | `LOpt.UnwrapOr('x')` | `Option.pas:123` |
| `TMatch<T>.Create(x)` | não é a entrada | `TMatch<T>.Value(x)` | `Match.pas:156` |
| `.CaseOf(1, 'a')` | não há | `.CaseEq(1, proc/func)` | `Match.pas:162` |
| `.ElseOf('x').MatchValue` | não há | `.Default(...).Execute` | `Match.pas:200,207` |
| `TResultPair<..>.Success(x)` (classe) | `Success` é de instância | `TResultPair<..>.New.Success(x)` | `ResultPair.pas:143,164` |

Casos: `README.md:65-83` (Option), `README.md:87-105` (Match), `README.md:110-121`
(ResultPair). A `property Value` de `TOption` existe (`Option.pas:238`), mas
lança em None — então mesmo o `.Value` do README é arriscado; prefira `UnwrapOr`.

## Regra 2 — `TOption<T>` ≠ `Nullable<T>`

**NUNCA troque `TOption<T>` por `Nullable<T>` achando que é o mesmo tipo.** O
tipo null-safety do **ModernSyntax** é `TOption<T>` (`Option.pas:48`). O
`Nullable<T>` do ecossistema é do **Janus** (`Janus.Types.Nullable`), usado para
colunas anuláveis do ORM — outro contexto. O especialista-semente citou
`Nullable<T>` (`delphi-modernsyntax-specialist.md:11,17`) por aproximação; ao
falar de ModernSyntax, o certo é `TOption<T>`.

## Regra 3 — `Value`/`Unwrap` de `TOption` LANÇAM em None

**NUNCA acesse `LOpt.Value` ou `LOpt.Unwrap` sem antes garantir `IsSome`.** Ambos
chamam `GetValue`, que faz `raise Exception.Create('Attempted to access a value
from TOption.None')` quando vazio (`Option.pas:286-291`). Isso reintroduz
exatamente o crash que o `TOption` deveria evitar. **Prefira** `UnwrapOr(default)`,
`UnwrapOrElse(func)` ou `Expect('msg')` (`Option.pas:298,306,342`), ou consuma via
`Match(someProc, noneProc)` (`Option.pas:397`).

## Regra 4 — Railway: `New.Success` / `New.Failure`, não `Success`/`Failure` sozinhos

**SEMPRE inicie a cadeia com `New`.** `Success`/`Failure` são funções de
**instância** de `TResultPair<S,F>` (`ResultPair.pas:164,175`); só `New` é
`class function` estático (`:143`). O idioma consagrado nos testes é
`TResultPair<S,F>.New.Success(x)` / `.New.Failure(x)`
(`Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105,120`). Escrever
`TResultPair<...>.Success(...)` (como o README) não é a forma correta.

## Regra 5 — NÃO lance exceção pela camada; converta em `Failure`

**Serviços retornam `TResultPair`/`TResponse`; NUNCA propague exceção pela
fronteira do serviço — converta o erro em `Failure`** e deixe o chamador decidir
via `When` (`delphi-modernsyntax-specialist.md:16`). É o ponto inteiro do railway:
o erro vira dado, não fluxo de controle.

## Regra 6 — `TMatch.Execute` devolve um `TResultPair`, não o valor cru

**NUNCA trate o retorno de `Execute` como o valor casado.** `Execute` devolve
`TResultPair<Boolean, String>` e `Execute<R>` devolve `TResultPair<R, String>`
(`Match.pas:207-208`) — você ainda precisa consumir com `isSuccess`/`When`
([railway-result.md](railway-result.md)). O valor produzido por um `Case*` do tipo
`func` sai por `Execute<R>`; efeitos colaterais (proc) mutam suas próprias vars.
Idioma: `LMatchResult.isSuccess` (`UTestMS.Match.pas:255`).

## Regra 7 — `TDotEnv.Get<T>` só converte bem `Integer` e `String`

**NUNCA assuma que `Get<T>` converte qualquer tipo.** O corpo só trata
explicitamente `TypeInfo(Integer)` e `TypeInfo(String)`; outros tipos caem em
ramos frágeis (`raise` ou `AsType` que pode falhar) (`DotEnv.pas:334-346,354-359`).
Para `Boolean`/`Double`/data, **leia como `String` e converta você mesmo**, ou use
`GetOr<T>` (que devolve o default em vez de estourar, `:372-419`). `Value<T>` é só
um alias de `Get<T>` (`:305-308`) — mesma limitação.

## Regra 8 — `.env`: `${VAR}` só resolve o que já foi lido; `#` é comentário

- A interpolação `${NOME}` usa apenas variáveis **já carregadas** naquele ponto
  (`DotEnv.pas:229-248`) — **ordem no arquivo importa**; defina `HOST` antes de
  `URL=...${HOST}...`.
- `#` no início ignora a linha; `#` no meio corta o resto como comentário
  (`DotEnv.pas:207-211`) — logo um valor não pode conter `#` literal sem virar
  comentário.
- `LoadFiles` faz `Clear` e recarrega; **arquivos posteriores sobrescrevem**
  (`DotEnv.pas:255-263`).

## Regra 9 — `TDotEnv` é `class` (tem `Free`); os demais são `record`

**SEMPRE** envolva `TDotEnv` em `try..finally … Free` (`DotEnv.pas:30,182`).
`TOption`, `TResultPair` e `TMatch` são `record` por valor (`Option.pas:48`,
`ResultPair.pas:57`, `Match.pas` record) — vivem na pilha, sem `Free`. (Um
`TResultPair` cujo `S` é classe pode chamar `Dispose` para liberar o objeto,
`ResultPair.pas:153`.)

## Regra 10 — Multiplataforma: APIs Windows-only ficam guardadas

Ao usar `TDotEnv` fora do Windows, saiba que `EnvCreate`/`EnvDelete` usam o shim
POSIX `setenv`/`unsetenv` (`Posix.Stdlib`) no lugar de `SetEnvironmentVariable`
(`DotEnv.pas:22-27`; `README.md:39,148`). O comportamento no Windows não muda; o
toolkit foi build-verificado em Win32/Win64/Linux64 (`README.md:35-41`).

## Errata aberta (preencher com casos de campo)

O especialista-semente ainda tem a errata quase vazia
(`delphi-modernsyntax-specialist.md:20-22`). **TODO — equipe do framework:**
registrar aqui os bugs reais que aparecerem no uso do ModernSyntax no backend
(ex.: conversões de `Get<T>`, uso de `record` retornado por função e capturado em
closure, refcount de anonymous methods dentro de `Case*`).

## Citations

- `delphi-modernsyntax-specialist.md:9-25` — fontes, conhecimento essencial e errata-semente.
- `Source/ModernSyntax.Option.pas:48,89,123,238,286-291,298-342,397` — TOption (regras 2,3).
- `Source/ModernSyntax.ResultPair.pas:143,153,164,175,207,227` — TResultPair (regras 4,5,6,9).
- `Source/ModernSyntax.Match.pas:156,162,200,207-208` — TMatch (regras 1,6).
- `Source/ModernSyntax.DotEnv.pas:22-27,30,182,207-263,334-419` — TDotEnv (regras 7,8,9,10).
- `Test Delphi/EclbrResultPair/UTestMS.ResultPair.pas:105,120` — idioma New.Success/New.Failure.
- `README.md:65-83,87-105,110-121,35-41,148` — snippets desatualizados e nota multiplataforma.
