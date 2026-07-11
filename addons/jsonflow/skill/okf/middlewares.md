---
type: API Reference
title: JsonFlow — Middlewares de evento (get/set)
description: O contrato IEventMiddleware + IGetValueMiddleware/ISetValueMiddleware, como interceptar campos na (de)serialização, a validação no registro e o TMiddlewareDateTime de referência, transcrito do Source.
tags: [jsonflow, json, delphi, middleware, serialization, api]
timestamp: 2026-07-11T00:00:00Z
---

# Middlewares de evento (get/set)

Middlewares interceptam **cada propriedade** durante a serialização (get) e a
desserialização (set) — para criptografar, formatar, converter tipos custom, etc.
(`README.md:34`). Fonte: `Source/JSON/Core/JsonFlow.Interfaces.pas` +
`Source/JSON/Middleware`.

## O contrato (3 interfaces)

`Source/JSON/Core/JsonFlow.Interfaces.pas:171-204`.

- **`IEventMiddleware` (`:180`)** — marcador base. **NÃO implemente só ele.** O
  próprio doc-comment do Source avisa: todo middleware DEVE implementar
  `IGetValueMiddleware` e/ou `ISetValueMiddleware`; o registro valida e rejeita
  quem tiver só o marcador (`:171-182`).
- **`IGetValueMiddleware` (`:189`)** — intercepta a LEITURA na **serialização**:

  ```pascal
  procedure GetValue(const AInstance: TObject; const AProperty: TRttiProperty;
    var AValue: Variant; var ABreak: Boolean);   // :191-192
  ```
  Defina `AValue` e `ABreak := True` para **substituir** o valor serializado; o
  pipeline para no primeiro middleware que der break (`:184-188`).
- **`ISetValueMiddleware` (`:200`)** — intercepta a ESCRITA na **desserialização**:

  ```pascal
  procedure SetValue(const AInstance: TObject; const AProperty: TRttiProperty;
    var AValue: Variant; var ABreak: Boolean);    // :202-203
  ```
  Escreva na instância (`AProperty.SetValue`) e `ABreak := True` para assumir a
  atribuição; o pipeline para no primeiro break (`:195-199`).

## Registro (validado no ponto de entrada)

- **Global (fachada):** `TJsonFlow.AddMiddleware(mw)` / `TJsonFlow.ClearMiddlewares`
  — delega ao `TJsonBuilder` estático usado pelos métodos de classe objeto⇄string
  (`Source/JsonFlow.pas:89-90,273-281`).
- **Por instância:** `TJSONSerializer.AddMiddleware(mw)`
  (`Source/JSON/IO/JsonFlow.Serializer.pas:132`).

Ambos **validam o contrato na entrada**: um middleware que implemente apenas
`IEventMiddleware` seria silenciosamente inútil, então **falha no registro** — o
comentário do Source é explícito (`Source/JSON/IO/JsonFlow.Serializer.pas:127-132`).
Prefira `AddMiddleware` à propriedade `Middlewares` (acesso direto mantido só por
compatibilidade — `:133-135`).

## Middleware de referência — `TMiddlewareDateTime`

`Source/JSON/Middleware/JsonFlow.MiddlewareDatatime.pas:28-70`. Implementa os três
contratos e trata `TDateTime`:

```pascal
TMiddlewareDateTime = class(TInterfacedObject, IEventMiddleware,
                                               IGetValueMiddleware,
                                               ISetValueMiddleware)   // :28-30
  constructor Create(const AFormatSettings: TFormatSettings);        // :34

  procedure GetValue(...);   // serializa TDateTime como 'yyyy-mm-dd'         :50-59
  procedure SetValue(...);   // desserializa via Iso8601ToDateTime            :61-70
```

Note o padrão: cada método checa
`AProperty.PropertyType.Handle = TypeInfo(TDateTime)` e só então age +
`ABreak := True` (`:54-58,65-69`) — middlewares devem ser seletivos por tipo/
propriedade e sair sem break quando não se aplicam.

## Como escrever o seu

1. Herde de `TInterfacedObject` e implemente `IEventMiddleware` +
   (`IGetValueMiddleware` e/ou `ISetValueMiddleware`).
2. Em `GetValue`/`SetValue`, filtre pela `AProperty` (tipo/nome/atributo); aja só
   no que lhe interessa; `ABreak := True` apenas quando assumir o valor.
3. Registre com `TJsonFlow.AddMiddleware(...)` (global) ou
   `serializer.AddMiddleware(...)` (instância) **antes** de serializar.

> As antigas `TJsonFlow.OnSetValue`/`OnGetValue` foram **DEPRECATED** justamente
> em favor deste sistema (`Source/JsonFlow.pas:93-96`). Não as use em código novo.

## Citations

- `Source/JSON/Core/JsonFlow.Interfaces.pas:171-204` — contrato dos 3 middlewares.
- `Source/JSON/IO/JsonFlow.Serializer.pas:127-135` — registro validado por instância.
- `Source/JsonFlow.pas:89-96,273-281` — registro global + deprecação de OnSet/OnGetValue.
- `Source/JSON/Middleware/JsonFlow.MiddlewareDatatime.pas:28-70` — implementação de referência.
- `README.md:34` — propósito (criptografar/formatar campos on-the-fly, contrato validado).
