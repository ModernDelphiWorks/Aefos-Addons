# Playbooks — JsonFlow

Guias práticos passo a passo, todos fundamentados no Source
(`.modules\JsonFlow\Source`) e nos Examples (`.modules\JsonFlow\Examples`).

- [Quickstart](quickstart.md) — os quatro fluxos essenciais em minutos: parse/
  emit, compor/editar por path, serializar objeto⇄JSON e validar contra JSON
  Schema Draft 7 (com formatos brasileiros).
- [Troubleshooting](troubleshooting.md) — os erros que mais custam: API do
  README que não existe (refactor), `EJsonFlowParseError`, middleware rejeitado
  no registro, `$ref` HTTP ausente por falta de define, `FormatSettings` global
  e race conditions, coleção que vira "saco de propriedades".
