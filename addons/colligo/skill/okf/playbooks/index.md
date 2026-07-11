# Playbooks — Colligo

Guias práticos passo a passo, todos fundamentados no `README.md`, no
`.modules\Colligo\Source` e nos testes DUnitX (`.modules\Colligo\Test Delphi`).

- [Quickstart](quickstart.md) — do array cru a um pipeline
  `Where → Select<> → OrderBy → Skip/Take → ToArray`, no idioma canônico do README.
- [Troubleshooting](troubleshooting.md) — os erros que mais custam: "nada
  executa" (lazy), `EIntOverflow` no `Sum`, `EInvalidOperation` em sequência
  vazia, `Chunk` que não encadeia, provider JSON/XML inexistente e o gotcha Linux
  do `TColligoString`.
