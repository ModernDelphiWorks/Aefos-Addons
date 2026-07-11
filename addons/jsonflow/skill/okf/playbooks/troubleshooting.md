---
type: Playbook
title: JsonFlow — Troubleshooting
description: Sintoma → causa-raiz → fix dos erros mais caros do JsonFlow — API do README que não existe, EJsonFlowParseError, middleware rejeitado, $ref HTTP ausente, FormatSettings global e coleção que vira saco de propriedades.
tags: [jsonflow, json, delphi, troubleshooting, debug, schema]
timestamp: 2026-07-11T00:00:00Z
---

# Troubleshooting

Sintoma → causa-raiz → fix, com a fonte. Regras completas em [../rules.md](../rules.md).

## "Método não existe" / não compila: `TJSONSerializer.ObjectToJSON`, `TSchemaValidator`, `TJSONElement.ParseFromString`

- **Causa-raiz:** você copiou do README/Example — **API legada removida no
  refactor** (Regra 1). O Source é a lei (`delphi-jsonflow-specialist.md:11,17`).
- **Fix — o que usar:**
  - objeto⇄string ⇒ fachada `TJsonFlow.ObjectToJsonString`/`JsonToObject<T>`
    (`Source/JsonFlow.pas:73,81`).
  - objeto⇄árvore ⇒ `TJSONSerializer.FromObject`/`ToObject`
    (`Source/JSON/IO/JsonFlow.Serializer.pas:119-120`).
  - validar schema ⇒ `TJSONSchemaReader` / `TJSONSchemaValidator`
    (`Source/Schema/IO/JsonFlow.SchemaReader.pas:30`;
    `Source/Schema/Validators/JsonFlow.SchemaValidator.pas:135`).
  - parsear ⇒ `TJsonFlow.Parse` / `TJSONReader.Read`
    (`Source/JsonFlow.pas:57`; `Source/JSON/IO/JsonFlow.Reader.pas:51`).
- **Example desatualizado:** `Validators/BrazilianValidatorsExample.dpr:22-26`
  usa units `JsonFlow4D.*` (namespace antigo); a lógica
  (`RegisterAllBrazilianFormatValidators`) é válida, só o `uses` mudou para
  `JsonFlow.*`.

## `EJsonFlowParseError` ao parsear

- **Causa:** JSON malformado. `Parse` **propaga a exceção sem shim**
  (`Source/JsonFlow.pas:130-134`; classe em
  `Source/JSON/IO/JsonFlow.Reader.pas:31`).
- **Fix:** para entrada externa, `try LRoot := LFlow.Parse(s) except on
  EJsonFlowParseError do … end;`. Ligue `OnLog`/`OnProgress` no reader para
  diagnosticar (`Source/JSON/IO/JsonFlow.Reader.pas:53-54`).

## Números/decimais saem errados; datas fora do formato

- **Números:** o reader usa `DecimalSeparator := '.'` interno
  (`Source/JSON/IO/JsonFlow.Reader.pas:62-67`) — JSON é sempre ponto. Se a SAÍDA
  de floats está com vírgula/locale errado, é `TJsonFlow.FormatSettings` global.
- **`FormatSettings` global (Regra 4):** é `class property` sem lock; **defina só
  na inicialização** (`Source/JsonFlow.pas:175-181`). Alterá-lo com serializações
  concorrentes é race condition. O Horse seta uma vez no setup
  (`Source/Middleware-Horse/Horse.JsonFlow.pas:45-49`).
- **Datas:** use `AUseISO8601DateFormat` no construtor do serializer
  (`Serializer.pas:116`) ou um middleware de data (padrão em
  `Source/JSON/Middleware/JsonFlow.MiddlewareDatatime.pas:50-70`).

## Meu middleware não roda / é rejeitado ao registrar

- **Causa-raiz:** implementou só `IEventMiddleware` (o marcador). O registro
  **valida e rejeita** — precisa de `IGetValueMiddleware` e/ou
  `ISetValueMiddleware` (`Source/JSON/IO/JsonFlow.Serializer.pas:127-132`;
  contrato em `Source/JSON/Core/JsonFlow.Interfaces.pas:171-204`).
- **Não dispara mesmo implementando get/set:** cheque o filtro por tipo/
  propriedade e o `ABreak` — só dê `ABreak := True` quando de fato assumir o
  valor (padrão em `MiddlewareDatatime.pas:54-58,65-69`).
- **NÃO use `OnSetValue`/`OnGetValue`** — deprecated (`Source/JsonFlow.pas:93-96`).
  Ver [../middlewares.md](../middlewares.md).

## `$ref` remoto (HTTP) não resolve / não compila o backend HTTP

- **Causa-raiz:** os backends HTTP de `$ref` são **opt-in por define** e a lib
  precisa estar presente: `JSONFLOW_HTTP_INDY`
  (`Source/Schema/IO/JsonFlow.SchemaRefIndy.pas:18-19`) ou `JSONFLOW_HTTP_SYNAPSE`
  (`JsonFlow.SchemaRefSynapse.pas:18-19`). Sem isso, só `$ref` **local/por
  arquivo** existe (`SchemaReader.LoadFromFile`).
- **No SDK mínimo/Linux:** não assuma `System.Net.*`/Indy/Synapse
  (`delphi-jsonflow-specialist.md:17,22`). É por isso que o framework compila
  standalone em Linux64 (`README.md:60`). Ver [../schema-ref.md](../schema-ref.md).

## Minha `TObjectList`/`TList<T>` virou `{"Capacity":…,"Count":…}`

- **Causa:** o tipo não foi classificado como coleção (versão antiga do bug). No
  Source atual, `TStrings`/`TCollection`/`TList<T>`/`TObjectList<T>` serializam
  como **array JSON** (`TSerializerCollectionKind`,
  `Source/JSON/IO/JsonFlow.Serializer.pas:36-41`).
- **Ao desserializar de volta:** o item precisa de construtor/tipo resolvível — o
  serializer resolve `ToArray`/`Add`/`Clear` e o metaclass do item uma vez por
  classe (`TSerializerTypeInfo`, `:47-57`). Item sem construtor público não
  materializa.

## Access violation ao liberar elementos

- **Causa:** você deu `Free` num `IJSONElement`/`IJSONObject`/`IJSONArray`. São
  interfaces ARC (`TInterfacedObject`) — **não libere** (Regra 6;
  `Source/JSON/Composition/JsonFlow.Objects.pas:29`).
- **Fix:** `Free` só nos objetos de API que você `Create` (`TJsonFlow`,
  `TJSONSerializer`, `TJSONSchemaReader`, `TJSONComposer`) em `try/finally`
  (`Examples/SchemaValidation/SchemaRefAndSchemaPathDemo.dpr:47-61`).

## Citations

- `delphi-jsonflow-specialist.md:11,17,22` — API removida, Source é a lei, HTTP opcional.
- `Source/JsonFlow.pas:57,73,81,93-96,130-134,175-181` — parse, fachada, deprecação, FormatSettings.
- `Source/JSON/IO/JsonFlow.Reader.pas:31,51-54,62-67` — parse error, log/progress, decimal.
- `Source/JSON/IO/JsonFlow.Serializer.pas:36-57,119-132` — coleções, métodos reais, middleware validado.
- `Source/JSON/Core/JsonFlow.Interfaces.pas:171-204` — contrato de middleware.
- `Source/Schema/IO/JsonFlow.SchemaRefIndy.pas:18-19`; `JsonFlow.SchemaRefSynapse.pas:18-19` — HTTP opt-in.
- `Source/JSON/Composition/JsonFlow.Objects.pas:29` — elementos são ARC.
