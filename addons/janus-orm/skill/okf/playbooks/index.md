# Playbooks — Janus ORM

Guias práticos passo a passo, todos fundamentados no Example Horse
(`.modules\Janus\Examples\Delphi\RESTful\Horse`) e no Source.

- [Quickstart](quickstart.md) — do modelo decorado a um CRUD REST funcional, no
  padrão canônico (`DAOBase<T>` + controllers Horse).
- [Troubleshooting](troubleshooting.md) — os erros que mais custam: HANG/AV por
  cursor sem `.Next`, `EInvalidCast` por `[Association]` na propriedade errada,
  leitura viva Firebird (gerador SQLite + WIN1252) e conexão que trava na 2ª
  request.
