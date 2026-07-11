# Log — MetaDbDiff Specialist

2026-07-11 — **Creation** — Addon `delphi-metadbdiff` criado a partir do
especialista curado `delphi-metadbdiff-specialist.md` e transcrito do código real
do framework (`.modules\MetaDbDiff\Source\Core` + `Source\Drivers`), do `README.md`
e do uso real das entidades do projeto (`Source\Modules\A01\A01_Entity.pas`).
Concept docs: overview, api, mapping-attributes, rtti-helpers, schema-diff, rules;
playbooks: quickstart, troubleshooting. Todo fato citado por `arquivo:linha`.
Segue o padrão OKF travado pelo addon-piloto `delphi-janus`. Relaciona-se ao
Janus (que consome estes atributos) sem duplicar o conteúdo de runtime.
Divergência registrada: o `README.md` documenta um facade (`TMetaDbComparer`/
`IMetaDbComparer`/`IMetaDbDelta`) ausente nesta cópia do Source, cujo caminho real
é `TDatabaseCompare` — marcado como TODO/incerteza para a equipe do framework.
