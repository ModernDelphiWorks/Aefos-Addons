---
type: Rules
title: JsonFlow — Regras & Erratas
description: Antipadrões e lições aprendidas do JsonFlow; cada uma vira uma regra NUNCA/SEMPRE com o caso real citado. LER antes de usar ou depurar.
tags: [jsonflow, json, delphi, rules, errata, antipatterns]
timestamp: 2026-07-11T00:00:00Z
---

# Regras & Erratas

Regras destiladas do especialista curado (`delphi-jsonflow-specialist.md`) e do
Source. **LER antes de escrever contra o JsonFlow ou depurar.** Cada regra carrega
o caso REAL que a originou — não a resuma a ponto de perder o caso.

## SEMPRE — fundamentar em código, e o Source é a lei

- **SEMPRE cite `arquivo:linha`** (Source e/ou Examples). Sem fonte, leia — não
  chute (`delphi-jsonflow-specialist.md:14`).
- **SEMPRE o Source vence README/Examples.** A API legada foi removida num
  refactor (`delphi-jsonflow-specialist.md:17`) — ver Regra 1.

## Regra 1 — NUNCA cite API pelo README/Examples sem confirmar no Source

**A API legada foi removida; o README e vários Examples ainda mostram nomes que
NÃO existem no Source atual.** Confirme sempre em `.modules\JsonFlow\Source` antes
de citar. Casos reais observados:

- README Quick Start #1 usa `TJSONSerializer.ObjectToJSON` e `.JSONToObject<T>`
  — o `TJSONSerializer` real tem **`FromObject`/`ToObject`/`SerializeToString`**
  (`Source/JSON/IO/JsonFlow.Serializer.pas:119-124`). Para objeto⇄string use a
  fachada `TJsonFlow.ObjectToJsonString`/`JsonToObject<T>`
  (`Source/JsonFlow.pas:73,81`).
- README #3 usa `TSchemaValidator` e `TJSONElement.ParseFromString` — **não
  existem.** As classes reais são `TJSONSchemaValidator`
  (`Source/Schema/Validators/JsonFlow.SchemaValidator.pas:135`) e
  `TJSONSchemaReader` (`Source/Schema/IO/JsonFlow.SchemaReader.pas:30`); parse é
  via `TJSONReader.Read`/`TJsonFlow.Parse`.
- `Examples/Validators/BrazilianValidatorsExample.dpr:22-26` referencia units
  `JsonFlow4D.Schema`/`JsonFlow4D.SchemaValidator`/… — nome **antigo** do
  namespace (`JsonFlow4D.*`), já renomeado para `JsonFlow.*`. A função
  `RegisterAllBrazilianFormatValidators` em si é real
  (`Source/Schema/Validators/Format/Brazil/JsonFlow.FormatValidators.Brazil.pas:44,80`).

Fonte: `delphi-jsonflow-specialist.md:11,17`.

## Regra 2 — JSON avulso ⇒ JsonFlow; JSON no ORM ⇒ TJanusJson

**NUNCA use `TJanusJson` para JSON fora do ORM, nem JsonFlow para (de)serializar
entidades Janus.** JsonFlow é o JSON padrão do ecossistema para request/response,
config, schema e manipulação avulsa; o JSON acoplado ao mapeamento de entidade é
do Janus via `TJanusJson` (`delphi-jsonflow-specialist.md:7,19`).

## Regra 3 — `$ref` por HTTP é OPT-IN; não assuma rede/lib presentes

**NUNCA assuma que `$ref` remoto (HTTP) funciona por padrão, nem que
`System.Net.*`/Indy/Synapse estão disponíveis** — especialmente em Linux/SDK
mínimo. Os backends HTTP de `$ref` são compilados só com defines de feature:
`JSONFLOW_HTTP_INDY` (`Source/Schema/IO/JsonFlow.SchemaRefIndy.pas:18-19`) e
`JSONFLOW_HTTP_SYNAPSE` (`JsonFlow.SchemaRefSynapse.pas:18-19`). Sem o define +
a lib, só `$ref` **local/por arquivo** existe. O framework compila 100% em Linux64
justamente porque os backends HTTP ficam guardados
(`delphi-jsonflow-specialist.md:17,18,22`; `README.md:60`). Ver [schema-ref.md](schema-ref.md).

## Regra 4 — `TJsonFlow.FormatSettings` é GLOBAL e sem sincronização

**NUNCA altere `TJsonFlow.FormatSettings` em runtime com serializações
concorrentes.** É uma configuração **global** (`class property`) sem lock; o
próprio Source adverte: defina **apenas na inicialização da aplicação**, antes de
haver serializações concorrentes — o record contém strings e escrita concorrente
a leituras é race condition (`Source/JsonFlow.pas:175-181`). Ex.: o middleware
Horse seta `TJsonFlow.FormatSettings` uma vez, no setup do callback
(`Source/Middleware-Horse/Horse.JsonFlow.pas:45-49`).

> Contraste: o `TFormatRegistry` (validadores de formato) É thread-safe por lock
> (`Source/Schema/Validators/JsonFlow.FormatRegistry.pas:68-70`) — mas isso não se
> estende ao `FormatSettings` global.

## Regra 5 — Middleware sem get/set é rejeitado no registro

**NUNCA registre um middleware que implemente só `IEventMiddleware`** — ele seria
silenciosamente inútil, então `AddMiddleware` **falha no registro**. Todo
middleware precisa de `IGetValueMiddleware` e/ou `ISetValueMiddleware`
(`Source/JSON/IO/JsonFlow.Serializer.pas:127-132`;
`Source/JSON/Core/JsonFlow.Interfaces.pas:171-182`). E `OnSetValue`/`OnGetValue`
estão **deprecated** — use middlewares (`Source/JsonFlow.pas:93-96`). Ver
[middlewares.md](middlewares.md).

## Regra 6 — Elementos são interfaces (ARC); libere só os objetos que você `Create`

**NUNCA dê `Free` num `IJSONElement`/`IJSONObject`/`IJSONArray`** — são interfaces
refcontadas (`TInterfacedObject`), liberadas por ARC
(`Source/JSON/Composition/JsonFlow.Objects.pas:29`,
`JsonFlow.Arrays.pas:27`, `JsonFlow.Value.pas:30`). Libere sim os **objetos de
API** que você instanciou explicitamente: `TJsonFlow`, `TJSONReader`,
`TJSONSerializer`, `TJSONSchemaReader`, `TJSONComposer` (quando usado como classe
concreta) — os Examples fazem `try/finally … .Free`
(`Examples/SchemaValidation/SchemaRefAndSchemaPathDemo.dpr:47-61`).

## Regra 7 — Erro de parse ⇒ `EJsonFlowParseError` (propaga sem shim)

`TJsonFlow.Parse` **propaga `EJsonFlowParseError` sem modificar** — o comentário do
Source é explícito ("no shim") (`Source/JsonFlow.pas:130-134`;
`Source/JSON/IO/JsonFlow.Reader.pas:31`). Ao consumir entrada externa, envolva o
parse em `try/except EJsonFlowParseError`. Ver [troubleshooting](playbooks/troubleshooting.md).

## Regra 8 — Coleções serializam como array; itens precisam de tipo resolvível

O serializador reconhece `TStrings`/`TCollection`/`TList<T>`/`TObjectList<T>` e
emite **array JSON** (`TSerializerCollectionKind`,
`Source/JSON/IO/JsonFlow.Serializer.pas:36-41`). O bug histórico que isso evita:
sem a classificação, uma `TObjectList` virava um "saco de propriedades"
(`{"Capacity":…,"Count":…}`) (`:36-41`). Ao desserializar, o item da lista precisa
de construtor/tipo resolvível (cache `TSerializerTypeInfo`, `:47-57`).

## Regra 9 — Patches no `.modules\JsonFlow`

Ao corrigir o próprio framework: **branch dedicada no repo do frw + backup
pristino + PR no final** (várias equipes editam em paralelo). O projeto consumidor
**NUNCA** commita `.modules` (feedback do dono; mesmo protocolo do Janus).

## Citations

- `delphi-jsonflow-specialist.md:7,11,14,17,18,19,22` — errata destilada (fonte primária).
- `Source/JsonFlow.pas:73,81,93-96,130-134,175-181` — fachada, deprecação, parse, FormatSettings global.
- `Source/JSON/IO/JsonFlow.Serializer.pas:36-57,119-132` — coleções, métodos reais, registro validado.
- `Source/JSON/Core/JsonFlow.Interfaces.pas:171-182` — contrato de middleware.
- `Source/Schema/IO/JsonFlow.SchemaRefIndy.pas:18-19`; `JsonFlow.SchemaRefSynapse.pas:18-19` — HTTP opt-in.
- `Source/Schema/Validators/JsonFlow.FormatRegistry.pas:68-70` — registry thread-safe.
- `Source/Middleware-Horse/Horse.JsonFlow.pas:45-49` — FormatSettings setado uma vez.
