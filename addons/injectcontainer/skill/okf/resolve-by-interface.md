---
type: Reference
title: InjectContainer — Resolução por Interface (GUID)
description: Como SingletonInterface<I,T> registra T sob o GUID de I, como GetInterface<I> resolve, o refcount de TInterfacedObject (o singleton que morre) e a assimetria por classe vs por interface.
tags: [injectcontainer, di, delphi, interface, guid, refcount, singletoninterface]
timestamp: 2026-07-11T00:00:00Z
---

# Resolução por Interface (GUID)

Além de resolver por **nome de classe** (`Get<T>`), o container resolve por
**interface**, usando o **GUID** da interface como chave. É a porta para programar
contra abstrações.

## Registro: `SingletonInterface<I, T>`

```pascal
LInjector.SingletonInterface<IMyClass, TMyClass>;          // sob o GUID de IMyClass
LMyClass1 := LInjector.GetInterface<IMyClass>;             // resolve
Assert.AreEqual(LMyClass1.GetMessage, 'TMyClass Message!');
```
Fonte: `Test Delphi/UTesteInject.pas:120-154`. Requisitos:

- **`I` precisa ter GUID** (`['{...}']`) — o container faz
  `GetTypeData(TypeInfo(I)).Guid` e usa `GUIDToString` como chave
  (`Inject.pas:186-188`). Sem GUID, não há chave.
- **`T` deve implementar `I`** e, para o refcount funcionar, herdar de
  `TInterfacedObject` (o modelo dos testes: `TMyClass = class(TInterfacedObject,
  IMyClass)`, `UTesteInject.pas:32`).
- O par vai para `FRepositoryInterface` como `TPair<TClass, TGUID>`
  (`Inject.pas:193`) — repositório **separado** do de classes.

### Tag: registrar/resolver por rótulo

Passe `ATag` para usar um rótulo no lugar do GUID (útil para múltiplas
implementações da mesma interface):

```pascal
LInjector.SingletonInterface<IMyClass, TMyClass>('TMyClass');
LMyClass1 := LInjector.GetInterface<IMyClass>('TMyClass');
```
Fonte: `UTesteInject.pas:156-173`; a tag sobrescreve o GUID em
`Inject.pas:189-190` (registro) e `:299-300` (resolução).

## Resolução: `GetInterface<I>`

`Inject.pas:291-325`. Calcula o GUID (ou usa a tag), tenta o próprio injector
(`GetInterfaceTry`, `:303`), depois faz o **scan de 1 nível dos filhos**
(`:310-321`). Diferença crucial vs `Get<T>`:

> **`GetInterface<I>` LANÇA `EServiceNotFound` se não achar** (`:322-324`),
> enquanto `Get<T>` **retorna `nil` em silêncio** (`:287-288`, raise comentado).

O `TServiceData` cacheia a interface como um `TValue`
(`GetInterface<I>` `Inject.Service.pas:202-216`): a primeira resolução constrói via
`_FactoryInterface` e as seguintes reusam o `TValue` guardado.

## Refcount — o "singleton" de interface pode MORRER

O objeto por trás de um `SingletonInterface` é um `TInterfacedObject`
**refcontado**. Os testes de refcount provam o comportamento:

- Um único holder externo ⇒ **RefCount = 1** (`TestInjectorInterfaceRefCountEqualOne`,
  `UTesteInject.pas:194-208`).
- Dois holders externos ⇒ **RefCount = 2** (`TestInjectorInterfaceRefCountEqualTo`,
  `:175-192`).

RefCount = 1 com um único holder externo revela que **o container NÃO segura um ref
contado independente que mantenha o objeto vivo por conta própria**. Consequência
de campo (errata #7 do Nidus): se um consumidor resolve `GetInterface<I>` numa
variável **local** e a solta ao fim do método, o refcount zera, o objeto é
**destruído**, e a próxima `GetInterface<I>` volta `nil`/reconstrói — o clássico
"funciona na 1ª request, quebra na 2ª". **Fix: cachear o ref num campo/`class var`
de vida longa** (`delphi-nidus-specialist.md:57`). Ver [rules.md](rules.md).

## Assimetria por classe vs por interface (resumo)

| Aspecto | `Get<T>` (classe) | `GetInterface<I>` (interface) |
|---|---|---|
| Chave | `T.ClassName` | GUID de `I` (ou tag) |
| Repositório | `FRepositoryReference` | `FRepositoryInterface` |
| Registro | `Singleton`/`SingletonLazy`/`Factory`/`AddInstance` | `SingletonInterface` (não há Factory) |
| Não encontrado | retorna `nil` | **lança `EServiceNotFound`** |
| Vida | objeto comum (dono = container) | `TInterfacedObject` **refcontado** |

## Citations

- `Source/Inject.pas:179-196` — `SingletonInterface` (GUID/tag → `FRepositoryInterface`).
- `Source/Inject.pas:291-325` — `GetInterface<I>` (scan + raise `EServiceNotFound`).
- `Source/Inject.pas:287-288` — `Get<T>` retorna nil (raise comentado) — a assimetria.
- `Source/Inject.Service.pas:202-216` — cache do `TValue` da interface.
- `Test Delphi/UTesteInject.pas:120-208` — interface, tag e refcount (1 e 2).
- `delphi-nidus-specialist.md:57` — errata do ref que morre.
</content>
