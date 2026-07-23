---
type: API Reference
title: JsonFlow — Serialização objeto⇄JSON (RTTI + atributos)
description: TJSONSerializer (FromObject/ToObject/SerializeToString), os atributos de serialização ([JSONName]/[JSONIgnore]/[JSONInclude]/[JSONConverter]…), coleções, opções (pool/circular-ref) e a factory, transcrito do Source.
tags: [jsonflow, json, delphi, serialization, rtti, attributes, api]
timestamp: 2026-07-11T00:00:00Z
---

# Serialização objeto⇄JSON (RTTI + atributos)

Como converter objetos Delphi ⇄ JSON. Fonte: `.modules\JsonFlow\Source`.

## Duas vias — escolha por caso

1. **Fachada (string, sem gerenciar serializador)** — `TJsonFlow.ObjectToJsonString`
   / `JsonToObject<T>` / `…List` (métodos de classe, `Source/JsonFlow.pas:73-86`).
   É a via canônica para objeto⇄**string** no ecossistema. Ver [api.md](api.md).
2. **`TJSONSerializer` (instância, controle fino)** — quando você precisa de
   opções (pool, referência circular, atributos), `IJSONElement` intermediário, ou
   registrar middlewares por instância.

```pascal
uses JsonFlow.Serializer, JsonFlow.Interfaces;
var LSer: TJSONSerializer; LElem: IJSONElement; LUser: TUser;
begin
  LSer := TJSONSerializer.Create;
  try
    LElem := LSer.FromObject(LUser);              // objeto -> árvore
    // ... ou string direta:
    // LJson := LSer.SerializeToString(LUser);
    LSer.ToObject(LElem, LUser);                  // árvore -> objeto (overlay)
  finally
    LSer.Free;
  end;
end;
```

> **ATENÇÃO (Regra 1):** o `TJSONSerializer` **NÃO** tem `ObjectToJSON` nem
> `JSONToObject<T>` — esses nomes do Quick Start #1 do README pertencem à API
> legada removida. Os métodos reais são `FromObject`/`ToObject`/`SerializeToString`
> (`Source/JSON/IO/JsonFlow.Serializer.pas:119-124`). Para string direta objeto⇄
> string, prefira a fachada `TJsonFlow`.

## Schema — `TJSONSerializer`

`Source/JSON/IO/JsonFlow.Serializer.pas:78`.

```pascal
constructor Create; overload;                                                   // :115
constructor Create(const AFormatSettings: TFormatSettings;
                   const AUseISO8601DateFormat: Boolean = True); overload;      // :116
constructor Create(const AOptions: TJSONSerializerOptions); overload;           // :117

function FromObject(AObject: TObject; AStoreClassName: Boolean = False): IJSONElement;  // :119
function ToObject(const AElement: IJSONElement; AObject: TObject): Boolean;             // :120
function SerializeToString(AObject: TObject; AStoreClassName: Boolean = False): string; // :123
procedure SerializeToStream(AObject: TObject; AStream: TStream; AStoreClassName: Boolean = False);  // :124

procedure OnLog(const ALogProc: TProc<String>);                                 // :126
procedure AddMiddleware(const AMiddleware: IEventMiddleware);                    // :132  (validado)
property Middlewares: TList<IEventMiddleware> read FMiddlewares;                 // :135
property Options: TJSONSerializerOptions read FOptions write FOptions;           // :136
```

- `AStoreClassName = True` grava o nome da classe no JSON (para polimorfismo).
- `AddMiddleware` **valida o contrato na entrada** — rejeita middleware que só
  implemente o marcador `IEventMiddleware` (`:127-132`). Ver [middlewares.md](middlewares.md).

### Opções — `TJSONSerializerOptions` (`:62-73`)

```pascal
UsePool: Boolean;
DetectCircularReferences: Boolean;
CircularReferenceStrategy: TCircularReferenceStrategy;
ProcessAttributes: Boolean;          // liga/desliga os atributos de serialização
IgnoreNullValues: Boolean;
DateTimeFormat: string;
FloatFormat: string;
MaxDepth: Integer;
class function Default: TJSONSerializerOptions; static;   // :72
```

### Factory — `TJSONSerializerFactory` (`:142-149`)

`CreateWithDefaults` / `CreateWithPool` / `CreateWithCircularRefDetection` /
`CreateWithAttributes` / `CreateFull` — atalhos para instâncias pré-configuradas.

### Coleções serializam como array JSON

O serializador reconhece nativamente `TStrings`, `TCollection`, `TList<T>`/
`TObjectList<T>` e listas clássicas (`TSerializerCollectionKind`:
`sckStrings`/`sckCollection`/`sckClassicList`/`sckGenericList`,
`Source/JSON/IO/JsonFlow.Serializer.pas:41`). Sem isso, uma `TObjectList` viraria
um "saco de propriedades" (`{"Capacity":…,"Count":…}`) — o comentário do Source
registra exatamente esse bug evitado (`:36-41`). Os métodos da coleção
(`ToArray`/`Add`/`Clear`) são resolvidos uma vez por classe e cacheados
(`TSerializerTypeInfo`, `:47-57`).

## Schema — Atributos de serialização

`Source/JSON/IO/JsonFlow.Serializer.Attributes.pas`. Decorem propriedades para
controlar o JSON (só têm efeito com `ProcessAttributes` ligado):

```pascal
[JSONName('base_item')]     // nome customizado da chave          // Attributes:43 ; uso :117
[JSONIgnore]                // não serializa a propriedade         // Attributes:37 ; uso :120
[JSONInclude(False, False)] // omite se null / vazio               // Attributes:54 ; uso :123
[JSONDateTimeFormat('yyyy-mm-dd')] // ou (True) p/ ISO8601        // Attributes:67
[JSONFloatFormat(2)]        // casas decimais                      // Attributes:81
[JSONOrder(1)]              // ordem de emissão                    // Attributes:115
[JSONConverter(TGUIDConverter)]  // conversor custom               // Attributes:103 ; uso :38
```

- Todos herdam de `JSONSerializationAttribute` (`:31`).
- **Conversor customizado:** implemente `IJSONPropertyConverter` (`ToJSON`/
  `FromJSON`, `:94-98`) e aponte com `[JSONConverter(TSuaClasse)]` (`:103-110`).
  Exemplos reais de conversores no VCL demo: GUID, set, Vector3, Point3D, Font,
  StringList, DataSet
  (`Examples/VCL/JsonFlowMainDemo/Demo.JsonFlow.Entities.pas:38-129`).

## Datas — o middleware de referência

Datas costumam ser o ponto de fricção. O `TMiddlewareDateTime` mostra o padrão:
na serialização formata `TDateTime` como `yyyy-mm-dd`; na desserialização usa
`Iso8601ToDateTime` (`Source/JSON/Middleware/JsonFlow.MiddlewareDatatime.pas:50-70`).
Ver [middlewares.md](middlewares.md). Para ISO8601 automático, o construtor do
serializer aceita `AUseISO8601DateFormat` (`Serializer.pas:116`).

## Examples

```pascal
// objeto -> elemento (VCL demo)
LJsonElement := LSerializer.FromObject(FComplexEntity);   // Demo.Forms.Main.pas:247
// elemento -> objeto existente
LSerializer.ToObject(LJsonElement, LTempEntity);          // Demo.Forms.Main.pas:330
// serializar cada item de uma lista para dentro de um IJSONArray
LArray.Add(LSerializer.FromObject(LItem));                // Demo.JsonFlow.Converters.pas:523
```

## Citations

- `Source/JSON/IO/JsonFlow.Serializer.pas:41,47-57,62-73,78,115-136,142-149` —
  `TJSONSerializer`, coleções, opções, factory, middleware validado.
- `Source/JSON/IO/JsonFlow.Serializer.Attributes.pas:31,37,43,54,67,81,94-110,115` —
  atributos e conversores.
- `Source/JsonFlow.pas:73-86` — fachada objeto⇄string (via canônica).
- `Source/JSON/Middleware/JsonFlow.MiddlewareDatatime.pas:50-70` — datas.
- `Examples/VCL/JsonFlowMainDemo/Demo.JsonFlow.Entities.pas:38-129`;
  `Demo.Forms.Main.pas:247,330`; `Demo.JsonFlow.Converters.pas:523` — uso real.
