# Log — ModernSyntax Specialist

2026-07-11 — **Creation** — Bundle do addon `delphi-modernsyntax` criado a partir
do especialista curado `delphi-modernsyntax-specialist.md` e transcrito do código
real do framework (`.modules\ModernSyntax\Source` + `.modules\ModernSyntax\Test Delphi`).
Concept docs: overview, api, nullable (`TOption<T>`), railway-result
(`TResultPair<S,F>`), pattern-matching (`TMatch<T>`), dotenv (`TDotEnv`), rules;
playbooks: quickstart, troubleshooting. Todo fato citado por `arquivo:linha`.
Registrada a divergência entre o `README.md` (snippets desatualizados:
`HasValue`/`ValueOrElse`/`CaseOf`/`ElseOf`/`MatchValue`/`TResultPair.Success`
classe) e a API real do Source (`IsSome`/`UnwrapOr`/`Value`, `CaseEq`/`Default`/
`Execute`, `New.Success`/`New.Failure`) — o Source é a fonte da verdade. Segue o
padrão OKF travado pelo addon-piloto `delphi-janus`.
