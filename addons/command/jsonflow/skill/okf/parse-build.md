---
type: API Reference
title: JsonFlow — Parse, Emit & Composição in-place
description: Ler e escrever JSON (TJSONReader/TJsonFlow.Parse-ToJson) e construir/editar JSON dinamicamente por path com TJSONComposer (fluente + SetValue/AddToArray/LoadJSON), transcrito do Source.
tags: [jsonflow, json, delphi, parse, composer, path, api]
timestamp: 2026-07-11T00:00:00Z
---

# Parse, Emit & Composição in-place

Como transformar texto ⇄ árvore e como **construir/editar** JSON sem montar
strings à mão. Fonte: `.modules\JsonFlow\Source`.

## Parse & Emit (texto ⇄ `IJSONElement`)

A via curta é a fachada:

```pascal
uses JsonFlow, JsonFlow.Interfaces;
var LFlow: TJsonFlow; LRoot: IJSONElement;
begin
  LFlow := TJsonFlow.Create;
  try
    LRoot := LFlow.Parse('{"user":{"name":"John","age":30},"tags":["dev"]}');  // texto -> árvore
    // ... navegue via IJSONObject/IJSONArray (ver api.md) ...
    Writeln(LFlow.ToJson(LRoot, True));  // árvore -> texto (True = identado)
  finally
    LFlow.Free;   // libera reader/writer/serializer; LRoot é interface (ARC)
  end;
end;
```

Fonte: `Source/JsonFlow.pas:57-58,130-139`.

### O leitor por baixo: `TJSONReader`

`Source/JSON/IO/JsonFlow.Reader.pas:33`. Implementa `IJSONReader`:

```pascal
function Read(const AJson: String): IJSONElement;          // :51
function ReadFromStream(AStream: TStream): IJSONElement;   // :52
procedure OnLog(const ALogProc: TProc<String>);            // :53
procedure OnProgress(const AProgress: TProc<TObject, Single>);  // :54  progresso de parse
```

- Erro de parse ⇒ **`EJsonFlowParseError`** (`Source/JSON/IO/JsonFlow.Reader.pas:31`),
  que a fachada propaga sem modificar (`Source/JsonFlow.pas:132`). Trate com
  `try/except EJsonFlowParseError`.
- `BufferSize` default 65536, piso 4096 (`Source/JSON/IO/JsonFlow.Reader.pas:66-77`).
- O reader usa `FormatSettings` `en_US` com `DecimalSeparator := '.'` internamente
  (`:62-67`) — números JSON são sempre ponto decimal.

## Composição in-place: `TJSONComposer`

`Source/JSON/Composition/JsonFlow.Composer.pas:35`, implementa `IJSONComposer`
(`Source/JSON/Core/JsonFlow.Interfaces.pas:305`). Constrói e **edita** JSON
navegando por strings de path (`user.address[0].zip`).

### Construir do zero (fluente)

```pascal
uses JsonFlow.Composer, JsonFlow.Interfaces;
var LComposer: IJSONComposer; LJson: string;
begin
  LComposer := TJSONComposer.Create;
  LComposer
    .BeginObject
      .Add('name', 'John')          // string
      .Add('age', 31)               // integer
      .BeginArray('tags')
        // itens de array via AddToArray no path, ou callbacks ArrayValue
      .EndArray
    .EndObject;
  LJson := LComposer.ToJSON(False);
end;
```

Métodos de construção (todos retornam `IJSONComposer` — encadeáveis):
`BeginObject`/`BeginArray`/`EndObject`/`EndArray`
(`Interfaces.pas:308-311`); sobrecargas de `Add` para String/Integer/Double/
Boolean/TDateTime/Char/Variant/`IJSONElement` e para `TArray<…>`
(`:314-331`); `AddNull`/`AddArray`/`AddJSON` (`:322-324`); `Merge`/`LoadJSON`
(`:332-333`); callbacks `ObjectValue`/`ArrayValue` (`:368-369`); conveniências
`StringValue`/`IntegerValue`/`NumberValue`/`BooleanValue`/`DateTimeValue`
(`:360-365`).

### Editar JSON existente (por path)

```pascal
LComposer := TJSONComposer.Create;
LComposer.LoadJSON('{"user":{"name":"John","age":30},"tags":["dev"]}');  // README.md:118
LComposer.SetValue('user.age', 31);        // altera in-place
LComposer.AddToArray('tags', 'lead');      // README.md:121
LUpdatedJson := LComposer.ToJSON(False);    // README.md:123
```

Manipulação por path (`Interfaces.pas:336-344`): `SetValue` (`:336`),
`RemoveKey` (`:337`), `AddToArray` (Variant/`IJSONElement`/`TArray<Variant>`,
`:338-340`), `MergeArray` (`:341`), `RemoveFromArray` (`:342`), `ReplaceArray`
(`:343`), `AddObject` (`:344`). Saída: `AsJSON`/`ToJSON`/`ToElement`/`GetRoot`
(`:347-350`).

### Construtores de conveniência do Composer

```pascal
class function CreateForObject: TJSONComposer;                    // :156 — já em BeginObject
class function CreateForArray: TJSONComposer;                     // :157 — já em BeginArray
class function CreateFromJSON(const AJson: String): TJSONComposer; // :158 — já com LoadJSON
```

Fonte: `Source/JSON/Composition/JsonFlow.Composer.pas:156-158,1458-1470`. Uso real:
`Examples/Composer/TestComposerPhases1to4.dpr:241,257,277`.

> Performance: o Composer reusa um `TJSONNavigator` entre operações por path
> (invalidado quando o root muda) e cacheia o contexto corrente por identidade —
> antes cada `SetValue`/`AddToArray` alocava navegador novo e fazia
> `QueryInterface` a cada `Add`
> (`Source/JSON/Composition/JsonFlow.Composer.pas:68-77`). `IJSONArray.Insert` é
> hot-path otimizado (`README.md:33`).

### Recursos avançados do Composer (opt-in)

O `IJSONComposer` também expõe modo debug/trace (`EnableDebugMode`,
`GetCompositionTrace`), validação em tempo real (`EnableRealTimeValidation`,
`QuickValidate`, `IsValidJSON`), sugestões (`GetSuggestions`, `SuggestKeys`) e
métricas (`GetPerformanceMetrics`, `Benchmark`)
(`Source/JSON/Core/JsonFlow.Interfaces.pas:371-393`). São auxiliares de
DX/telemetria — o núcleo de uso é build + edição por path acima.

## `TDataSet` ⇄ JSON

Para converter datasets, há `TJSONDatasetConverter` (`Source/JSON/IO/JsonFlow.Converter.Dataset.pas:97`),
com opções ricas: tratamento de null (`TNullValueHandling`: incluir/excluir/vazio,
`:40-44`), caixa dos nomes de campo (`TFieldNameCase`: original/lower/upper/
camel/pascal, `:49-55`), `IncludeMetadata`/`IncludeFieldDefs`, `MaxRecords`,
`BufferSize` (`:60-70`).

## Citations

- `Source/JsonFlow.pas:57-58,130-139` — `Parse`/`ToJson` da fachada.
- `Source/JSON/IO/JsonFlow.Reader.pas:31,33,51-54,62-77` — `TJSONReader`,
  `EJsonFlowParseError`, BufferSize, FormatSettings interno.
- `Source/JSON/Core/JsonFlow.Interfaces.pas:305-393` — contrato `IJSONComposer`.
- `Source/JSON/Composition/JsonFlow.Composer.pas:35,68-77,156-158,1458-1470` —
  `TJSONComposer`, reuso de navegador, construtores de conveniência.
- `Source/JSON/IO/JsonFlow.Converter.Dataset.pas:97-185` — `TJSONDatasetConverter` (unit em `:16`).
- `Examples/Composer/TestComposerPhases1to4.dpr:241,257,277` — construtores reais.
- `README.md:28,33,118-123` — composição in-place por path e hot-paths.
