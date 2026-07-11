# Playbooks — FluentSQL

Guias práticos passo a passo, todos fundamentados nos testes DUnitX
(`.modules\FluentSQL\Test Delphi`) e no Source.

- [Quickstart](quickstart.md) — do `FluentSQL.Query(dbn...)` a um SELECT paginado
  por dialeto, WHERE seguro, e INSERT/UPDATE/DELETE; como executar via DataEngine.
- [Troubleshooting](troubleshooting.md) — os erros que mais custam: `:pN`
  não-vinculado ao rodar via `CreateDataSet`, `Between`/`Sum` que "não existem",
  dialeto errado na paginação, e LIKE invertido.
