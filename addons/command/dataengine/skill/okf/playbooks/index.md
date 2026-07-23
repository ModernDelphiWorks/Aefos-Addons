# Playbooks — DataEngine

Guias práticos passo a passo, todos fundamentados no Source do DataEngine
(`.modules\DataEngine\Source`) e no consumo real do ERP (backend:
`Source/Core/Core.Connection.pas`, `Source/Shared/...`).

- [Quickstart](quickstart.md) — de uma `TFDConnection` a leituras (`CreateDataSet`
  + `NotEof` + `GetFieldValue`) e comandos (`ExecuteDirect`) via `IDBConnection`,
  no padrão canônico da casa (singleton aberto).
- [Troubleshooting](troubleshooting.md) — os erros que mais custam: AV no `.Open`
  ad-hoc, loop que pula/repete linhas por causa do `NotEof`, transação `'DEFAULT'`
  compartilhada envenenada, conexão que trava na 2ª request e leitura viva Firebird
  (charset).
