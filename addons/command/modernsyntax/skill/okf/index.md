---
okf_version: "0.1"
---

# Knowledge Bundle Index — ModernSyntax Specialist

Base de conhecimento do especialista no **ModernSyntax** (Delphi, por Isaque
Pinheiro) — toolkit de programação funcional e sintaxe moderna. Fundamentada em
`.modules\ModernSyntax\Source` (implementação) e `.modules\ModernSyntax\Test Delphi`
(uso correto, testes DUnitX); todo fato é rastreável por `arquivo:linha`.

## Conceitos

- [Visão Geral](overview.md) — o que é o ModernSyntax, as unidades do toolkit,
  fontes da verdade e quando usar cada recurso.
- [Referência Técnica](api.md) — mapa das units, os pontos de entrada de cada
  tipo (`TOption`, `TResultPair`, `TMatch`, `TDotEnv`) e o que consultar em cada
  documento.
- [Null-safety — `TOption<T>`](nullable.md) — Some/None, IsSome/IsNone,
  Unwrap/UnwrapOr/Expect, Map/Filter/AndThen, Match e ponte para `TResultPair`.
- [Railway — `TResultPair<S,F>`](railway-result.md) — `New.Success`/`New.Failure`,
  `When`, `Map`/`FlatMap`, `Reduce`, `isSuccess`/`ValueSuccess` e o encadeamento
  Ok/Fail/ThenOf/ExceptOf.
- [Pattern matching — `TMatch<T>`](pattern-matching.md) — `Value` → `CaseEq`/
  `CaseIf`/`CaseGt`/`CaseLt`/`CaseIn`/`CaseRange`/`CaseIs`/`CaseRegex` → `Default`
  → `Execute`, devolvendo um `TResultPair`.
- [Configuração `.env` — `TDotEnv`](dotenv.md) — parsing do `.env`
  (comentários `#`, interpolação `${VAR}`), `Get<T>`/`GetOr<T>`/`TryGet<T>`,
  `UseSystemFallback` e as operações de variável de ambiente do SO.
- [Regras & Erratas](rules.md) — antipadrões e armadilhas (LER — o README está
  parcialmente desatualizado; o Source manda).

## Playbooks

- [Playbooks](playbooks/index.md) — guias práticos passo a passo:
  - [Quickstart](playbooks/quickstart.md) — cada recurso com o idioma real em
    poucas linhas.
  - [Troubleshooting](playbooks/troubleshooting.md) — "não compila", AV,
    conversão de tipo no `.env`, `${VAR}` que não expande.

## Meta

- [Histórico](log.md) — log de criação/atualização desta base.
