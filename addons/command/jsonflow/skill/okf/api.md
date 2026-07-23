---
type: API Reference
title: JsonFlow — Referência Técnica (Fachada + Modelo)
description: A fachada TJsonFlow (Parse/ToJson/FromObject/ToObject + métodos de classe objeto⇄string) e as interfaces do modelo (IJSONElement/Object/Array/Value), transcritas do Source com file:line.
tags: [jsonflow, json, delphi, facade, interfaces, api]
timestamp: 2026-07-11T00:00:00Z
---

# JsonFlow — Referência Técnica (Fachada + Modelo)

Tudo aqui é transcrito de `.modules\JsonFlow\Source`. A porta de entrada é a
fachada `TJsonFlow` (`Source/JsonFlow.pas:37`); o modelo de dados são interfaces
em `Source/JSON/Core/JsonFlow.Interfaces.pas`.

## Schema — A fachada `TJsonFlow`

`Source/JsonFlow.pas:37-100`. Tem uma face de **instância** (parse/emit/serialize
com estado próprio) e uma face de **classe** (conveniências objeto⇄string).

### Instância — parse, emit e serialização

```pascal
constructor Create; overload;                               // :52
constructor Create(const AFormatSettings: TFormatSettings); overload;  // :53

function Parse(const AJson: string): IJSONElement;          // :57  -> texto -> árvore
function ToJson(const AElement: IJSONElement;
                const AIdent: Boolean = False): string;     // :58  -> árvore -> texto

function FromObject(AObject: TObject;
                    const AStoreClass: Boolean = False): IJSONElement;  // :61
function ToObject(const AElement: IJSONElement;
                  AObject: TObject): Boolean;                // :62  overlay num objeto existente

procedure OnLog(const ALogProc: TProc<string>);            // :65  log unificado (reader+writer+serializer)
```

Implementação: `Parse` delega a `FReader.Read` e **propaga
`EJsonFlowParseError` sem shim** (`Source/JsonFlow.pas:130-134`); `ToJson` delega
a `FWriter.Write` (`:136-139`); `FromObject`/`ToObject` delegam a `FSerializer`
(`:141-149`). A instância possui `FReader`/`FWriter`/`FSerializer` e os libera no
destrutor (`:106-128`).

### Classe — objeto ⇄ string (conveniência; delega ao `TJsonBuilder`)

```pascal
class function ObjectToJsonString(AObject: TObject;
  AStoreClassName: Boolean = False): string;                             // :73
class function ObjectListToJsonString(AObjectList: TObjectList<TObject>;
  AStoreClassName: Boolean = False): string; overload;                   // :75
class function ObjectListToJsonString<T: class, constructor>(
  AObjectList: TObjectList<T>; AStoreClassName: Boolean = False): string; overload;  // :77

class function JsonToObject<T: class, constructor>(const AJson: string): T; overload;      // :81
class function JsonToObject<T: class>(const AObject: T; const AJson: string): Boolean; overload;  // :82
class procedure JsonToObject(const AJson: string; AObject: TObject); overload;             // :84  overlay
class function JsonToObjectList<T: class, constructor>(const AJson: string): TObjectList<T>; overload;  // :85
class function JsonToObjectList(const AJson: string; const AType: TClass): TObjectList<TObject>; overload;  // :86
```

> **É a via canônica para objeto⇄JSON-string** no ecossistema. O `TJSONSerializer`
> (instância) NÃO expõe `ObjectToJSON`/`JSONToObject<T>` (nomes do README que já
> não existem) — ele usa `FromObject`/`ToObject`/`SerializeToString`. Ver
> [object-mapping.md](object-mapping.md) e Regra 1 em [rules.md](rules.md).

### Middlewares e configuração global (classe)

```pascal
class procedure AddMiddleware(const AEventMiddleware: IEventMiddleware);  // :89
class procedure ClearMiddlewares;                                        // :90
class property  FormatSettings: TFormatSettings ...;                     // :99  GLOBAL, sem sync
```

- `AddMiddleware`/`ClearMiddlewares` delegam ao `TJsonBuilder` estático
  (`:273-281`). Ver [middlewares.md](middlewares.md).
- `FormatSettings` é **GLOBAL e sem sincronização** — o próprio código adverte:
  defina só na inicialização, antes de haver serializações concorrentes (o record
  guarda strings; escrita concorrente a leituras é race condition)
  (`Source/JsonFlow.pas:175-181`). Ver Regra 4 em [rules.md](rules.md).
- `OnSetValue`/`OnGetValue` são propriedades **DEPRECATED** (o compilador emite
  `$MESSAGE WARN`): use middlewares (`Source/JsonFlow.pas:93-96`).

## Schema — O modelo de elementos (`IJSONElement`)

`Source/JSON/Core/JsonFlow.Interfaces.pas`. Tudo é interface (ARC/refcount — **não
dê `Free` em elemento**).

### `IJSONElement` — base (`:75-81`)

```pascal
function AsJSON(const AIdent: Boolean = False): String;   // serializa este nó
procedure SaveToStream(AStream: TStream; const AIdent: Boolean = False);
function Clone: IJSONElement;
function TypeName: string;
```

### `IJSONValue` — escalares (`:83-103`)

Leitura/escrita tipada + checagens de tipo:
`AsBoolean`/`AsInteger`/`AsFloat`/`AsString` (properties) e
`IsString`/`IsInteger`/`IsFloat`/`IsBoolean`/`IsNull`/`IsDate`. Implementações
concretas por tipo em `Source/JSON/Core/JsonFlow.Value.pas:30-186` (`TJSONValue`
abstrato `:30` + escalares — `TJSONValueString` `:60`, `Boolean` `:81`, …).

### `IJSONObject` — objeto (`:116-129`)

```pascal
function Add(const AKey: String; const AValue: IJSONElement): IJSONPair;
function GetValue(const AKey: String): IJSONElement;
function TryGetValue(const AKey: String; out AValue: IJSONElement): Boolean;
function ContainsKey(const AKey: String): Boolean;
function Count: Integer;
procedure Remove(const AKey: String);
procedure Clear;
procedure ForEach(const ACallback: TProc<String, IJSONElement>);
function Filter(const APredicate: TFunc<String, IJSONElement, Boolean>): IJSONObject;
function Map(const ATransform: TFunc<String, IJSONElement, IJSONPair>): IJSONObject;
function Pairs: TArray<IJSONPair>;
```

Implementação `TJSONObject` (`Source/JSON/Composition/JsonFlow.Objects.pas:29`)
mantém um índice de chave só acima de 8 pares (`INDEX_THRESHOLD`, `:30-33`) — para
objetos pequenos a varredura linear é mais barata.

### `IJSONArray` — array (`:131-144`)

```pascal
procedure Add(const AValue: IJSONElement);
procedure Insert(const AIndex: Integer; const AValue: IJSONElement);   // :134
function GetItem(const AIndex: Integer): IJSONElement;
function Count: Integer;
procedure Remove(const AIndex: Integer);
procedure Clear;
procedure ForEach(const ACallback: TProc<IJSONElement>);
function Filter(const APredicate: TFunc<IJSONElement, Boolean>): IJSONArray;
function Map(const ATransform: TFunc<IJSONElement, IJSONElement>): IJSONArray;
function Items: TArray<IJSONElement>;
function Value(AIndex: Integer): IJSONElement;
```

`IJSONArray.Insert` é um dos hot-paths otimizados (`README.md:33`). Implementação
`TJSONArray` em `Source/JSON/Composition/JsonFlow.Arrays.pas:27`.

### `IJSONPair` — par chave/valor de objeto (`:105-114`)

`Key: String` + `Value: IJSONElement` (read/write) + `AsJSON`.

## Examples

Serializar/desserializar via a instância `TJSONSerializer` (o Quick Start #1 do
README usa nomes de método que já não existem — use estes):

```pascal
// árvore -> objeto existente (Benchmark real)
LJFSer.ToObject(LJFElem, AEnvelope);   // Examples/VCL/JsonFlowBenchmarkXSO/Benchmark.Forms.Main.pas:236
```

Objeto -> elemento (VCL demo real):

```pascal
LJsonElement := LSerializer.FromObject(FComplexEntity);  // Examples/VCL/JsonFlowMainDemo/Demo.Forms.Main.pas:247
LSerializer.ToObject(LJsonElement, LTempEntity);         // :330
```

## Citations

- `Source/JsonFlow.pas:37-100` — declaração da fachada `TJsonFlow`.
- `Source/JsonFlow.pas:106-149,175-281` — implementação (parse propaga erro,
  serialize delega, FormatSettings global, middlewares).
- `Source/JsonFlow.pas:93-96` — `OnSetValue`/`OnGetValue` deprecated.
- `Source/JSON/Core/JsonFlow.Interfaces.pas:75-144` — `IJSONElement`/`Value`/
  `Object`/`Array`/`Pair`.
- `Source/JSON/Composition/JsonFlow.Objects.pas:29-33`,
  `JsonFlow.Arrays.pas:27` — implementações concretas.
- `Source/JSON/Core/JsonFlow.Value.pas:30-186` — `TJSONValue` (`:30`) e escalares (`TJSONValueString` `:60`…).
- `Examples/VCL/JsonFlowMainDemo/Demo.Forms.Main.pas:247,330` — FromObject/ToObject reais.
