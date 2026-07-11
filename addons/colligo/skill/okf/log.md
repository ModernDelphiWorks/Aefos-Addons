# Log — Colligo Specialist

2026-07-11 — **Creation** — Bundle do addon `delphi-colligo` criado a partir do
especialista curado `delphi-colligo-specialist.md` e transcrito do código real do
framework (`.modules\Colligo\README.md` + `Source` + `Test Delphi`). Concept docs:
overview, api, operators, lazy-evaluation, queryable-sql, colligostring, rules;
playbooks: quickstart, troubleshooting. Todo fato citado por `arquivo:linha`.
Segue o padrão OKF travado pelo addon-piloto `delphi-janus`. Achados registrados:
(1) o filtro é `Where` (não `Filter`); (2) providers JSON/XML são stubs vazios
(`Source/Colligo.Json.pas`, `Colligo.Xml.pas`); (3) o provider SQL real é o
`IColligoQueryable<T>`, atrás de `{$IFDEF QUERYABLE}`, sobre FluentSQL/DataEngine;
(4) gotcha Linux do `TColligoString.ToLower/ToUpper` corrigido em
`Source/Colligo.Helpers.pas:1509-1514`.
