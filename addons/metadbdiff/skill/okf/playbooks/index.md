# Playbooks — MetaDbDiff

Guias práticos passo a passo, fundamentados no Source
(`.modules\MetaDbDiff\Source`), no `README.md` do framework e no uso real das
entidades do projeto.

- [Quickstart](quickstart.md) — decorar uma entidade com os atributos, registrá-la
  e rodar um diff modelo→banco que gera (e opcionalmente aplica) o DDL cirúrgico.
- [Troubleshooting](troubleshooting.md) — os erros que mais custam: driver de DDL
  não registrado, facade `TMetaDbComparer` inexistente, `size`/`scale` trocados no
  `[Column]` numérico, entidade que não aparece no diff (registro tardio) e diff
  que aplicou no banco sem querer.
