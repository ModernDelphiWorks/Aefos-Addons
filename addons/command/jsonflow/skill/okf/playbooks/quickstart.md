---
type: Playbook
title: JsonFlow — Quickstart
description: Os quatro fluxos essenciais do JsonFlow em minutos — parse/emit, compor/editar por path, serializar objeto⇄JSON e validar contra JSON Schema Draft 7 — cada passo citando o Source.
tags: [jsonflow, json, delphi, quickstart, parse, serialize, schema]
timestamp: 2026-07-11T00:00:00Z
---

# Quickstart — os quatro fluxos essenciais

Baseado em `.modules\JsonFlow\Source` e `.modules\JsonFlow\Examples`. Cada passo
cita a fonte. **Lembre da Regra 1:** confirme nomes no Source — o README mostra
API já removida.

## 1. Parse & Emit (texto ⇄ árvore)

```pascal
uses JsonFlow, JsonFlow.Interfaces;
var LFlow: TJsonFlow; LRoot: IJSONElement;
begin
  LFlow := TJsonFlow.Create;
  try
    LRoot := LFlow.Parse('{"user":{"name":"John"},"tags":["dev"]}');  // texto -> árvore
    Writeln(LFlow.ToJson(LRoot, True));                               // árvore -> texto (identado)
  finally
    LFlow.Free;   // LRoot é interface (ARC) — não dê Free nele (Regra 6)
  end;
end;
```
Fonte: `Source/JsonFlow.pas:57-58,130-139`. Entrada externa? Envolva em
`try/except EJsonFlowParseError` (Regra 7). Detalhes em [../parse-build.md](../parse-build.md).

## 2. Compor / editar por path (`TJSONComposer`)

```pascal
uses JsonFlow.Composer, JsonFlow.Interfaces;
var LComposer: IJSONComposer; LJson: string;
begin
  LComposer := TJSONComposer.Create;
  LComposer.LoadJSON('{"user":{"name":"John","age":30},"tags":["dev"]}');
  LComposer.SetValue('user.age', 31);        // edita in-place por path
  LComposer.AddToArray('tags', 'lead');
  LJson := LComposer.ToJSON(False);
end;
```
Fonte: `README.md:118-123`; contrato em
`Source/JSON/Core/JsonFlow.Interfaces.pas:333,336,338`. Construir do zero:
`BeginObject`/`Add`/`EndObject` ou `CreateForObject`/`CreateForArray`/
`CreateFromJSON` (`Composer.pas:156-158`). Detalhes em [../parse-build.md](../parse-build.md).

## 3. Serializar objeto ⇄ JSON

Via curta (fachada, string direta):

```pascal
uses JsonFlow;
LJson := TJsonFlow.ObjectToJsonString(LUser);          // objeto  -> string     JsonFlow.pas:73
LUser := TJsonFlow.JsonToObject<TUser>(LJson);         // string  -> objeto novo JsonFlow.pas:81
TJsonFlow.JsonToObject(LJson, LExisting);              // string  -> overlay     JsonFlow.pas:84
LJson := TJsonFlow.ObjectListToJsonString<TUser>(LList);   // lista -> string    JsonFlow.pas:77
```

Via com controle (instância `TJSONSerializer`, quando precisar de opções/árvore):

```pascal
uses JsonFlow.Serializer, JsonFlow.Interfaces;
LSer := TJSONSerializer.Create;
try
  LElem := LSer.FromObject(LUser);        // objeto -> IJSONElement   Serializer.pas:119
  LSer.ToObject(LElem, LUser);            // IJSONElement -> objeto    Serializer.pas:120
finally
  LSer.Free;
end;
```

Controle fino por atributo na entidade:
```pascal
[JSONName('base_item')] property Name: string ...;   // Serializer.Attributes.pas:43
[JSONIgnore]            property Secret: string ...;  // :37
[JSONConverter(TGUIDConverter)] property Id: TGUID ...;  // :103
```
Detalhes e opções (pool/circular-ref/coleções) em [../object-mapping.md](../object-mapping.md).

## 4. Validar contra JSON Schema Draft 7

```pascal
uses JsonFlow.SchemaReader, JsonFlow.Interfaces;
var LReader: TJSONSchemaReader;
begin
  LReader := TJSONSchemaReader.Create;
  try
    if not LReader.LoadFromString(
         '{"type":"object","properties":{"name":{"type":"string","minLength":2}},"required":["name"]}') then
      // erro no PRÓPRIO schema
      Writeln(LReader.GetErrors[0].Message)
    else if not LReader.Validate('{"name":"A"}') then
      // erro no DADO: Path + SchemaPath apontam onde/qual regra
      Writeln(LReader.GetErrors[0].Path, ' / ', LReader.GetErrors[0].SchemaPath);
  finally
    LReader.Free;
  end;
end;
```
Fonte: `Examples/SchemaValidation/SchemaRefAndSchemaPathDemo.dpr:47-61`;
`Source/Schema/IO/JsonFlow.SchemaReader.pas:46-53`. Formatos brasileiros:
`RegisterAllBrazilianFormatValidators;` e use `"format":"cpf"` no schema
(`Source/.../Format/Brazil/JsonFlow.FormatValidators.Brazil.pas:44,80`). Detalhes
em [../schema-ref.md](../schema-ref.md).

## 5. Integração REST (Horse) — opcional

```pascal
App.Use(HorseJsonFlow);                 // serializa Res.Content p/ JSON automaticamente
var LUser := Req.Body<TUser>;           // parse tipado do body
```
Fonte: `Source/Middleware-Horse/Horse.JsonFlow.pas:32-33,72,81-95`. É dependência
externa (fora do SDK mínimo; `README.md:60`).

## Checklist final

- [ ] Objeto⇄string ⇒ fachada `TJsonFlow`; objeto⇄árvore/opções ⇒ `TJSONSerializer`
      (NÃO existe `TJSONSerializer.ObjectToJSON` — Regra 1).
- [ ] Nunca `Free` em `IJSONElement` (ARC); `Free` só no `TJsonFlow`/serializer/
      reader que você criou (Regra 6).
- [ ] Parse de entrada externa protegido por `try/except EJsonFlowParseError` (Regra 7).
- [ ] Middleware com `IGetValueMiddleware`/`ISetValueMiddleware` (Regra 5).
- [ ] `$ref` HTTP só com define + lib; senão, `$ref` local (Regra 3).
- [ ] `TJsonFlow.FormatSettings` só na inicialização (Regra 4).

## Citations

- `Source/JsonFlow.pas:57-58,73,77,81,84` — parse/emit + objeto⇄string.
- `Source/JSON/Composition/JsonFlow.Composer.pas:156-158`;
  `Source/JSON/Core/JsonFlow.Interfaces.pas:333,336,338` — composer.
- `Source/JSON/IO/JsonFlow.Serializer.pas:119-120`;
  `JsonFlow.Serializer.Attributes.pas:37,43,103` — serializador + atributos.
- `Source/Schema/IO/JsonFlow.SchemaReader.pas:46-53` — validação.
- `Examples/SchemaValidation/SchemaRefAndSchemaPathDemo.dpr:47-61` — demo real.
- `Source/Middleware-Horse/Horse.JsonFlow.pas:32-95` — Horse.
