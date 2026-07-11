---
type: API Reference
title: JsonFlow — JSON Schema Draft 7, $ref & Validadores de Formato
description: Validar JSON contra JSON Schema Draft 7 com TJSONSchemaValidator/TJSONSchemaReader, erros com Path/SchemaPath, $ref local e HTTP (opt-in por define) e validadores de formato plugáveis (inclusive brasileiros cpf/cnpj/cep), transcrito do Source.
tags: [jsonflow, json, delphi, schema, draft7, ref, validation, brazil, api]
timestamp: 2026-07-11T00:00:00Z
---

# JSON Schema Draft 7, `$ref` & Validadores de Formato

Validação de payload contra JSON Schema **Draft 7**, com caminhos de erro
detalhados, `$ref` e formatos plugáveis. Fonte: `.modules\JsonFlow\Source\Schema`.

## Duas portas de entrada

- **`TJSONSchemaReader`** (`Source/Schema/IO/JsonFlow.SchemaReader.pas:30`) — a
  via de alto nível: carrega o schema de arquivo/string e valida. **É a usada nos
  Examples.**
- **`TJSONSchemaValidator`** (`Source/Schema/Validators/JsonFlow.SchemaValidator.pas:135`)
  — o motor: recebe schema + dado como `IJSONElement`, dá `Boolean` + erros e
  métricas.

> **ATENÇÃO (Regra 1):** o README mostra `TSchemaValidator` e
> `TJSONElement.ParseFromString` — **nenhum dos dois existe** no Source atual. As
> classes reais são `TJSONSchemaValidator`/`TJSONSchemaReader` e o parse é via
> `TJSONReader.Read`/`TjsonFlow.Parse`. O Example
> `Validators/BrazilianValidatorsExample.dpr` referencia units `JsonFlow4D.*` já
> renomeadas — está **desatualizado**. Confirme no Source. Ver [rules.md](rules.md).

## Schema — `TJSONSchemaReader` (`IJSONSchemaReader`)

`Source/Schema/IO/JsonFlow.SchemaReader.pas:30-54`.

```pascal
function LoadFromFile(const AFileName: string): Boolean;   // :46 — resolve $ref por arquivo relativo
function LoadFromString(const AJsonString: string): Boolean; // :47
function Validate(const AJson: string): Boolean; overload;   // :48
function Validate(const AElement: IJSONElement): Boolean; overload;  // :49
function Validate(const AJson, AJsonSchema: String): Boolean; overload;  // :50
function GetErrors: TArray<TValidationError>;                // :51
function GetVersion: TJsonSchemaVersion;                     // :52
function GetSchema: IJSONElement;                            // :53
```

Por default o reader cria um validador **`jsvDraft7`**
(`Source/Schema/IO/JsonFlow.SchemaReader.pas:64`).

### Example completo (do próprio framework)

```pascal
uses JsonFlow.SchemaReader, JsonFlow.Interfaces;
var LReader: TJSONSchemaReader;
begin
  LReader := TJSONSchemaReader.Create;
  try
    if not LReader.LoadFromString(LSchema) then
      PrintErrors(LReader.GetErrors)          // erro no PRÓPRIO schema
    else if not LReader.Validate('{"a":{"b":"hi"}}') then
      PrintErrors(LReader.GetErrors)          // erro no DADO
    else
      Writeln('OK');
  finally
    LReader.Free;
  end;
end;
```

Fonte: `Examples/SchemaValidation/SchemaRefAndSchemaPathDemo.dpr:47-61`. `$ref` por
arquivo: `LoadFromFile(...root-file-ref.json)` (`:66-92`).

## Schema — `TJSONSchemaValidator` (o motor)

`Source/Schema/Validators/JsonFlow.SchemaValidator.pas:135-174`.

```pascal
constructor Create(const AVersion: TJsonSchemaVersion = jsvDraft7); overload;  // :152
function Validate(const AJson: string; const AJsonSchema: string = ''): Boolean; overload;  // :158
function Validate(const AElement: IJSONElement; const APath: string = ''): Boolean; overload;  // :159
function GetErrors: TArray<TValidationError>;                    // :162
procedure ParseSchema(const ASchema: IJSONElement);             // :167 — pré-compila o schema
function ValidateWithMetrics(const AElement: IJSONElement;
                             const APath: string = ''): TValidationResult;  // :166
procedure OnLog(const ALogProc: TProc<String>);                 // :168
```

Otimizações (auditadas jul/2026, `README.md:32`): cache de compilação por
identidade, regex de regra pré-compilada e caminhos de erro incrementais O(1) →
~3.4× mais rápido.

### Versões de schema — `TJsonSchemaVersion`

`Source/JSON/Core/JsonFlow.Interfaces.pas:34-42`: `jsvDraft3`/`4`/`6`/`7`/
`201909`/`202012` (+ `jsvUnknown`). **Draft 7 é o alvo suportado/testado**
(`README.md:5,29`); o reader detecta a versão do schema e cai para o validador
correspondente.

## Schema — Erros: `TValidationError`

`Source/JSON/Core/JsonFlow.Interfaces.pas:50-61`. Cada erro carrega:

- `Path` — o **dataPath** (JSON Pointer) onde o dado falhou.
- `SchemaPath` — a localização **no schema** que reprovou (permite apontar a regra
  exata, ex.: `minLength` aninhado).
- `Message`, `FoundValue`, `ExpectedValue`, `Keyword`, `LineNumber`,
  `ColumnNumber`, `Context`.
- `ToString` formata tudo (`:397-401`).

`TValidationResult` (`:64-73`) agrega `IsValid`, `Errors[]`, `ExecutionTime`,
`CacheHit` (usado por `ValidateWithMetrics`).

## Schema — `$ref`

- **Local / por arquivo** — funciona nativamente (`LoadFromFile` resolve `$ref`
  por caminho relativo; demo em `SchemaRefAndSchemaPathDemo.dpr:66-92`).
- **HTTP — OPT-IN por define.** Os backends que buscam `$ref` por rede são
  compilados só com defines de feature e a lib presente:
  - `JSONFLOW_HTTP_INDY` → `TJSONSchemaRefIndy` (usa Indy)
    (`Source/Schema/IO/JsonFlow.SchemaRefIndy.pas:18-19,31`).
  - `JSONFLOW_HTTP_SYNAPSE` → backend Synapse
    (`Source/Schema/IO/JsonFlow.SchemaRefSynapse.pas:18-19`).
  - Contrato: `IJSONSchemaRef.FetchReference(const ARef): IJSONElement`
    (`Source/JSON/Core/JsonFlow.Interfaces.pas:231-234`).
  - No **SDK mínimo/Linux não assuma `System.Net.*`/Indy/Synapse presentes**
    (`delphi-jsonflow-specialist.md:17,22`). Ver Regra 3 em [rules.md](rules.md).

## Schema — Validadores de formato (`format`)

`Source/Schema/Validators/JsonFlow.FormatRegistry.pas`. Registro **plugável** e
**thread-safe** (dicionário protegido por lock — `:68-70`) de validadores de
`format`.

```pascal
class procedure RegisterValidator(const AFormatName: string;
                                  const AValidator: IFormatValidator);  // :76
class function GetValidator(const AFormatName: string): IFormatValidator; // :78
class function IsFormatRegistered(const AFormatName: string): Boolean;    // :79
```

Um validador implementa `IFormatValidator` (`Validate`/`GetErrorMessage`/
`GetFormatName`, `:42-47`); há a base `TBaseFormatValidator` (`:50`).

### Formatos prontos

- **Genéricos** (unidades em `Source/Schema/Validators/Format/`): `email`,
  `date`, `date-time`, `time`, `ipv4`, `ipv6`, `uri`, `uuid`.
- **Brasileiros** (`Source/Schema/Validators/Format/Brazil/`): `cpf`, `cnpj`,
  `cep`, `brazilian-phone`, `brazilian-license-plate`. Registre todos de uma vez:

```pascal
RegisterAllBrazilianFormatValidators;   // Source/.../Format/Brazil/JsonFlow.FormatValidators.Brazil.pas:44,80
```

Depois basta usar `"format":"cpf"` no schema
(`Examples/Validators/BrazilianValidatorsExample.dpr:43-89`, ver ressalva de units
desatualizadas acima; a função `RegisterAllBrazilianFormatValidators` é real).

## Citations

- `Source/Schema/IO/JsonFlow.SchemaReader.pas:30-54,64` — `TJSONSchemaReader`, default Draft 7.
- `Source/Schema/Validators/JsonFlow.SchemaValidator.pas:135-174` — `TJSONSchemaValidator`.
- `Source/JSON/Core/JsonFlow.Interfaces.pas:34-73,206-234` — versões, erros, contratos de schema/ref.
- `Source/Schema/Validators/JsonFlow.FormatRegistry.pas:42-79` — registry de formato.
- `Source/Schema/Validators/Format/Brazil/JsonFlow.FormatValidators.Brazil.pas:44,80` — validadores BR.
- `Source/Schema/IO/JsonFlow.SchemaRefIndy.pas:18-19,31`;
  `JsonFlow.SchemaRefSynapse.pas:18-19` — `$ref` HTTP opt-in.
- `Examples/SchemaValidation/SchemaRefAndSchemaPathDemo.dpr:47-92` — uso real do reader.
- `delphi-jsonflow-specialist.md:17,22` — HTTP opcional; não assumir System.Net.*.
- `README.md:5,29,32` — Draft 7, SchemaPath, cache de compilação.
