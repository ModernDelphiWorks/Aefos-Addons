---
type: Framework Overview
title: JsonFlow — Visão Geral
description: O que é o JsonFlow, seus quatro pilares (parse, compose, serialize, schema), o mapa do Source, fontes da verdade e quando usar.
tags: [jsonflow, json, delphi, serialization, schema, overview]
timestamp: 2026-07-11T00:00:00Z
---

# JsonFlow — Visão Geral

O **JsonFlow** é um framework Delphi de alto desempenho para JSON, autor **Isaque
Pinheiro** (ModernDelphiWorks), licença MIT
(`Source/JsonFlow.pas:2-11`). Ele unifica quatro capacidades sob uma API única:
serialização objeto⇄JSON via RTTI, composição/edição dinâmica in-place, parse/emit
e validação de **JSON Schema Draft 7** (`README.md:5,23`). É o **JSON padrão de
todo o ecossistema** do dono — Nidus/Janus e demais frameworks usam JsonFlow para
JSON avulso (`delphi-jsonflow-specialist.md:7`).

## Os quatro pilares

1. **Parse / Emit** — texto JSON ⇄ árvore de elementos (`IJSONElement`), via a
   fachada `TJsonFlow.Parse`/`ToJson` (`Source/JsonFlow.pas:57-58`). Ver
   [parse-build.md](parse-build.md).
2. **Compose (in-place)** — construir e editar JSON navegando por strings de path
   (`user.address[0].zip`), via `TJSONComposer` (`README.md:28,107-124`;
   `Source/JSON/Composition/JsonFlow.Composer.pas:35`). Ver
   [parse-build.md](parse-build.md).
3. **Serialize (RTTI)** — objetos Delphi ⇄ JSON com atributos e conversores, via
   `TJSONSerializer` (`Source/JSON/IO/JsonFlow.Serializer.pas:78`) ou a fachada
   `TJsonFlow.ObjectToJsonString`/`JsonToObject<T>` (`Source/JsonFlow.pas:73,81`).
   Ver [object-mapping.md](object-mapping.md).
4. **Schema (Draft 7)** — validar JSON contra schema, com `$ref` e formatos
   plugáveis, via `TJSONSchemaValidator`/`TJSONSchemaReader`
   (`Source/Schema/Validators/JsonFlow.SchemaValidator.pas:135`;
   `Source/Schema/IO/JsonFlow.SchemaReader.pas:30`). Ver [schema-ref.md](schema-ref.md).

Transversal aos pilares: **middlewares de evento** interceptam campos na
(de)serialização (`Source/JSON/Core/JsonFlow.Interfaces.pas:180-204`). Ver
[middlewares.md](middlewares.md).

## Arquitetura em uma frase

`TJsonFlow` é uma **fachada fina** sobre um core evoluído: instancia delega a
`TJSONReader`/`TJSONWriter`/`TJSONSerializer`; os métodos de classe
objeto⇄string delegam a um `TJsonBuilder` estático
(`Source/JsonFlow.pas:37-100,104-281`). O modelo de dados é 100% baseado em
interfaces (`IJSONElement` e derivadas), então tudo é ARC/refcount — sem `Free`
manual dos elementos.

```
Texto JSON ──Parse──▶ IJSONElement (IJSONObject / IJSONArray / IJSONValue)
   ▲                          │
   └────────ToJson────────────┘
Objeto TObject ──FromObject/ObjectToJsonString──▶ IJSONElement / string
   ▲                          │
   └──ToObject/JsonToObject<T>┘
IJSONElement ──TJSONSchemaValidator.Validate──▶ Boolean + TValidationError[]
```

## Mapa do Source (para investigar)

Raiz: `.modules\JsonFlow\Source`. A unit `JsonFlow.pas` (a fachada) puxa os
apelidos `JsonFlow.Reader`/`.Writer`/`.Serializer`/`.Builders`/`.Interfaces`
(`Source/JsonFlow.pas:28-34`), cujos arquivos físicos estão nas subpastas abaixo:

- **`JSON/Core`** — o modelo e o contrato:
  - `JsonFlow.Interfaces.pas` — TODAS as interfaces (`IJSONElement:75`,
    `IJSONValue:83`, `IJSONObject:116`, `IJSONArray:131`, `IJSONComposer:305`,
    middlewares `:180-204`, schema `:206-234`) e os records de validação
    (`TValidationError:50`, `TValidationResult:64`).
  - `JsonFlow.Value.pas` — `TJSONValue` e subtipos escalares (string/int/float/
    boolean/null) (`:30-58`).
- **`JSON/Composition`** — `TJSONObject` (`JsonFlow.Objects.pas:29`), `TJSONArray`
  (`JsonFlow.Arrays.pas:27`), `TJSONPair`, e o `TJSONComposer`
  (`JsonFlow.Composer.pas:35`).
- **`JSON/IO`** — `TJSONReader` (`JsonFlow.Reader.pas:33`), `TJSONWriter`,
  `TJSONSerializer` (`JsonFlow.Serializer.pas:78`), os atributos de serialização
  (`JsonFlow.Serializer.Attributes.pas`), pool/circular-ref, `TJSONNavigator`
  (path) e o conversor de `TDataSet` (`JsonFlow.Converter.Dataset.pas`).
- **`JSON/Middleware`** — `TMiddlewareDateTime`, o middleware de referência
  (`JsonFlow.MiddlewareDatatime.pas:28`).
- **`Core`** — `TJsonBuilder`/`TJsonData` (`JsonFlow.Builders.pas`), o motor
  objeto⇄string dos métodos de classe da fachada; `JsonFlow.Types.pas`,
  `JsonFlow.Utils.pas`.
- **`Schema`** — o validador Draft 7: `Core` (engine/rules), `Validators`
  (`JsonFlow.SchemaValidator.pas`, cada regra `ValidationRules.*`, `FormatRegistry`
  e os validadores de formato, inclusive `Format/Brazil`), `IO`
  (`JsonFlow.SchemaReader.pas`, `$ref` HTTP opt-in Indy/Synapse) e `Composition`.
- **`Middleware-Horse`** — `Horse.JsonFlow.pas`, integração REST (fora do escopo
  do SDK mínimo; `README.md:60`).

## Fontes da verdade (estude ANTES de afirmar)

1. **Source** — `.modules\JsonFlow\Source`. É a **lei**
   (`delphi-jsonflow-specialist.md:11`).
2. **Examples** — `.modules\JsonFlow\Examples` (Composer, SchemaValidation,
   Converters, Validators, Performance, VCL/…). Uso real, mas **alguns Examples
   estão desatualizados** (referenciam units `JsonFlow4D.*` já renomeadas — ver
   Regra 1 em [rules.md](rules.md)).
3. **README** — visão e benchmarks; porém alguns trechos de código mostram API já
   removida (`delphi-jsonflow-specialist.md:17`). Confirme no Source.

## Quando usar

- Manipular/serializar/validar JSON **avulso** (request/response, config, schema)
  em Delphi (`delphi-jsonflow-specialist.md:19`).
- Objeto⇄JSON com controle fino via atributos e conversores customizados.
- Editar JSON existente in-place por path sem reserializar tudo à mão.
- Validar payloads contra JSON Schema Draft 7 (com formatos brasileiros prontos).

## Quando NÃO usar / limites

- JSON **dentro do ORM** (entidade Janus ⇄ JSON): use `TJanusJson` do Janus, não
  JsonFlow (`delphi-jsonflow-specialist.md:19`).
- `$ref` por **HTTP** só existe se compilado com os defines opt-in
  (`JSONFLOW_HTTP_INDY`/`JSONFLOW_HTTP_SYNAPSE`) e a lib presente — no SDK mínimo/
  Linux não assuma `System.Net.*`/Indy/Synapse
  (`delphi-jsonflow-specialist.md:17,22`;
  `Source/Schema/IO/JsonFlow.SchemaRefIndy.pas:18-19`). Ver [schema-ref.md](schema-ref.md).
- Integração Horse é dependência externa, fora do SDK mínimo (`README.md:60`).

## Citations

- `Source/JsonFlow.pas:2-11,37-100,104-281` — licença e a fachada `TJsonFlow`.
- `Source/JSON/Core/JsonFlow.Interfaces.pas:50,64,75,83,116,131,180-234,305` —
  modelo, middlewares e schema.
- `Source/JSON/IO/JsonFlow.Serializer.pas:78` — `TJSONSerializer`.
- `Source/JSON/Composition/JsonFlow.Composer.pas:35` — `TJSONComposer`.
- `Source/Schema/Validators/JsonFlow.SchemaValidator.pas:135` — `TJSONSchemaValidator`.
- `Source/Schema/IO/JsonFlow.SchemaReader.pas:30` — `TJSONSchemaReader`.
- `README.md:5,23,28,60,107-124` — visão, composer in-place, Linux64.
- `delphi-jsonflow-specialist.md:7,11,17,19,22` — papel no ecossistema, fachada,
  API legada removida, JSON avulso vs ORM, HTTP opt-in.
