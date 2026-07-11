---
okf_version: "0.1"
---

# Knowledge Bundle Index — JsonFlow Specialist

Base de conhecimento do especialista no **JsonFlow** (Delphi, por Isaque
Pinheiro) — manipulação, serialização e validação de JSON, o **JSON padrão de
todo o ecossistema** do dono (`delphi-jsonflow-specialist.md:7`). Fundamentada em
`.modules\JsonFlow\Source` (implementação) e `.modules\JsonFlow\Examples` (uso);
todo fato é rastreável por `arquivo:linha`. **O Source é a lei** — o README e
alguns Examples mostram API já removida (ver [Regras](rules.md), Regra 1).

## Conceitos

- [Visão Geral](overview.md) — o que é o JsonFlow, os quatro pilares (parse,
  compose, serialize, schema), o mapa do Source e quando usar.
- [Referência Técnica](api.md) — a fachada `TJsonFlow` (Parse/ToJson/FromObject/
  ToObject + métodos de classe) e as interfaces do modelo (`IJSONElement`,
  `IJSONObject`, `IJSONArray`, `IJSONValue`).
- [Parse, Emit & Composição](parse-build.md) — ler/escrever JSON, o modelo de
  elementos e o `TJSONComposer` (construção fluente + edição in-place por path).
- [Serialização objeto⇄JSON](object-mapping.md) — `TJSONSerializer` (RTTI),
  os atributos de serialização (`[JSONName]`/`[JSONIgnore]`/`[JSONConverter]`…)
  e as opções (pool, referência circular, coleções).
- [Schema, `$ref` & Formatos](schema-ref.md) — validação JSON Schema Draft 7
  (`TJSONSchemaValidator`/`TJSONSchemaReader`), `$ref` local/HTTP (opt-in) e os
  validadores de formato plugáveis (inclusive brasileiros: cpf/cnpj/cep).
- [Middlewares de evento](middlewares.md) — o contrato `IEventMiddleware` +
  `IGetValueMiddleware`/`ISetValueMiddleware` e a validação no registro.
- [Regras & Erratas](rules.md) — antipadrões e lições aprendidas (LER — nunca
  repita os bugs).

## Playbooks

- [Playbooks](playbooks/index.md) — guias práticos passo a passo:
  - [Quickstart](playbooks/quickstart.md) — os quatro fluxos essenciais em
    minutos (parse, compose, serialize, validate).
  - [Troubleshooting](playbooks/troubleshooting.md) — `EJsonFlowParseError`,
    middleware rejeitado, API do README que não existe, `$ref` HTTP ausente,
    `FormatSettings` global e race conditions.

## Meta

- [Histórico](log.md) — log de criação/atualização desta base.
