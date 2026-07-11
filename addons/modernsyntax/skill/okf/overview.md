---
type: Framework Overview
title: ModernSyntax — Visão Geral
description: O que é o ModernSyntax, as unidades do toolkit, fontes da verdade e quando usar null-safety, railway, pattern matching e .env.
tags: [modernsyntax, delphi, functional, null-safety, railway, pattern-matching, dotenv, overview]
timestamp: 2026-07-11T00:00:00Z
---

# ModernSyntax — Visão Geral

O **ModernSyntax** é um toolkit de **programação funcional e extensão de sintaxe
moderna** para Delphi, autor **Isaque Pinheiro** (ModernDelphiWorks), licença MIT
(`Source/ModernSyntax.Option.pas:2-11`). Ele traz ao Pascal recursos de linguagens
como Rust, Kotlin, C# e Haskell: tipos opcionais seguros, fluxo de erro funcional
(railway), pattern matching, assíncrono, currying, tuplas e leitura de `.env`
(`README.md:18-27`).

## Os quatro recursos deste addon

O especialista foca em quatro pilares (`delphi-modernsyntax-specialist.md:3,7`):

| Recurso | Tipo real (Source) | Unidade | Para quê |
|---|---|---|---|
| **Null-safety** | `TOption<T>` | `ModernSyntax.Option` | Evitar Access Violation por valor ausente (estilo `Some`/`None`) |
| **Railway (erro funcional)** | `TResultPair<S, F>` | `ModernSyntax.ResultPair` | Retornar sucesso/falha sem lançar exceção pela camada |
| **Pattern matching** | `TMatch<T>` | `ModernSyntax.Match` | Substituir `if/case` aninhado por casamento tipado |
| **Configuração `.env`** | `TDotEnv` | `ModernSyntax.DotEnv` | Ler config de `.env` com fallback para env var do SO |

> ⚠️ **Nomenclatura:** o especialista-semente fala em `Nullable<T>`, `TResult`/
> `TResponse` e `.When` (`delphi-modernsyntax-specialist.md:11,16-17`). Os tipos
> reais do ModernSyntax são **`TOption<T>`**, **`TResultPair<S,F>`** e
> **`TMatch<T>`** — não há `Nullable<T>`/`TResult`/`TResponse` no Source. O método
> `When` existe, mas pertence a `TResultPair` (`Source/ModernSyntax.ResultPair.pas:227`).
> `Nullable<T>` neste ecossistema é um tipo do **Janus** (`Janus.Types.Nullable`),
> não do ModernSyntax. Ver [rules.md](rules.md).

## As unidades do Source (mapa)

Todas em `.modules\ModernSyntax\Source` (o barrel é `ModernSyntax.pas`):

- **Null-safety** — `ModernSyntax.Option.pas` (`TOption<T>`, `TSome`, `TNone`).
- **Railway** — `ModernSyntax.ResultPair.pas` (`TResultPair<S,F>`, `TResultValue`,
  exceções `EFailureException<F>`/`ESuccessException<S>`).
- **Pattern matching** — `ModernSyntax.Match.pas` (`TMatch<T>`).
- **`.env`** — `ModernSyntax.DotEnv.pas` (`TDotEnv`).
- **Auxiliares que aparecem nos idiomas** — `ModernSyntax.ArrowFun.pas`
  (`TArrow.Fn`), `ModernSyntax.RegExpression.pas` (usado por `CaseRegex`),
  `ModernSyntax.Std.pas`, `ModernSyntax.Tuple.pas`.
- **Outros recursos do toolkit (fora do escopo deste addon)** — `Async`,
  `Coroutine`, `Currying`, `Crypt`, `Objects`, `Safetry`, `Stream`.

## Fontes da verdade (estude ANTES de afirmar)

1. **Test Delphi (uso correto)** — `.modules\ModernSyntax\Test Delphi`, projetos
   DUnitX que exercitam cada tipo: `EclbrSystem\UTestMS.Option.pas`,
   `EclbrResultPair\UTestMS.ResultPair.pas`, `EclbrSystem\UTestMS.Match.pas`,
   `EclbrSystem\UTestMS.DotEnv.pas`. São a referência de idioma real.
2. **Source (implementação)** — `.modules\ModernSyntax\Source` (units acima).
3. **README** — útil para a intenção/marketing, mas com **snippets
   desatualizados** (ver aviso acima e [rules.md](rules.md)); nunca copie o
   README verbatim sem checar o Source.

> A pasta `Examples\` do repositório só traz demos de Currying e Corrotina — NÃO
> há Example de Option/ResultPair/Match/DotEnv. Para esses, a fonte de uso é o
> `Test Delphi`.

## Quando usar cada um

- **`TOption<T>`** — sempre que um valor pode legitimamente não existir (lookup
  que pode falhar, campo opcional, parse) e você quer o compilador/o fluxo te
  forçando a tratar o "None" (`Source/ModernSyntax.Option.pas:48-239`). Ver
  [nullable.md](nullable.md).
- **`TResultPair<S,F>`** — quando um método pode falhar e você NÃO quer propagar
  exceção pela camada; devolva `Success`/`Failure` e consuma com `When`
  (`Source/ModernSyntax.ResultPair.pas:57-547`). Ver [railway-result.md](railway-result.md).
- **`TMatch<T>`** — quando um `if/case` aninhado ficaria ilegível; encadeie
  `CaseEq`/`CaseIn`/`CaseRange`/`CaseRegex` e finalize com `Execute`
  (`Source/ModernSyntax.Match.pas:156-208`). Ver [pattern-matching.md](pattern-matching.md).
- **`TDotEnv`** — para carregar configuração de um `.env` com fallback para as
  variáveis de ambiente do SO (`Source/ModernSyntax.DotEnv.pas:44,321-370`). Ver
  [dotenv.md](dotenv.md).

## Multiplataforma

Verificado em produção compilando em **Win32, Win64 e Linux64** (`dcclinux64`);
macOS/iOS/Android seguem da RTL mas não são build-verificados aqui
(`README.md:35-41,144-150`). APIs Windows-only ficam guardadas: o `TDotEnv` usa um
shim POSIX `setenv`/`unsetenv` (`Posix.Stdlib`) no lugar de
`SetEnvironmentVariable` fora do Windows (`Source/ModernSyntax.DotEnv.pas:22-27`).

## Citations

- `Source/ModernSyntax.Option.pas:2-11,48-239` — cabeçalho MIT e `TOption<T>`.
- `Source/ModernSyntax.ResultPair.pas:57,227,547` — `TResultPair<S,F>` e `When`.
- `Source/ModernSyntax.Match.pas:156-208` — `TMatch<T>` (entrada e cases).
- `Source/ModernSyntax.DotEnv.pas:22-27,44,321-370` — shim POSIX, `Create`, `Get<T>`.
- `README.md:18-27,35-41,144-150` — visão dos recursos e build multiplataforma.
- `delphi-modernsyntax-specialist.md:3,7,11,16-17` — foco do especialista e a
  nomenclatura-semente a corrigir.
