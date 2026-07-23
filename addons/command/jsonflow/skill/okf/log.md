# Log — JsonFlow Specialist

2026-07-11 — **Creation** — Bundle do addon `delphi-jsonflow` criado a partir do
especialista curado `delphi-jsonflow-specialist.md` e transcrito do código real
do framework (`.modules\JsonFlow\Source` + `.modules\JsonFlow\Examples`). Concept
docs: overview, api, parse-build, object-mapping, schema-ref, middlewares, rules;
playbooks: quickstart, troubleshooting. Todo fato citado por `arquivo:linha`.
Segue o padrão OKF travado pelo addon-piloto `delphi-janus`. Destaque de errata:
o Source é a lei — o README e alguns Examples ainda mostram API já removida no
refactor (`TSchemaValidator`, `TJSONElement.ParseFromString`,
`TJSONSerializer.ObjectToJSON`); a fachada correta é `TJsonFlow` e o validador é
`TJSONSchemaValidator`/`TJSONSchemaReader`.
