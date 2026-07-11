---
type: Playbook
title: InjectContainer — Quickstart
description: Do primeiro bind à resolução com injeção automática de construtor, cobrindo os seis modos de registro e as duas portas (classe/interface), seguindo o Test do framework.
tags: [injectcontainer, di, delphi, quickstart, registro, resolucao]
timestamp: 2026-07-11T00:00:00Z
---

# Quickstart — do primeiro bind à resolução

Baseado em `.modules\InjectContainer\Test Delphi\UTesteInject.pas` (cada `[Test]` é
um exemplo verificado) e no Source. Cada passo cita a fonte.

## 0. Obter um injector

```pascal
uses Inject;

var LInjector: TInject;
LInjector := TInject.Create;   // injector próprio (isolado)
try
  // ... registros e resoluções ...
finally
  LInjector.Free;
end;
```
Padrão dos testes: `UTesteInject.pas:105-117`. Para o **injector global** de
processo, use `GetInjector` (`Inject.pas:145-158`); no Nidus, o global é
`GNidusInject^` (`Nidus.Inject.pas:50,191-194`).

## 1. Registre por CLASSE (resolve com `Get<T>`)

```pascal
LInjector.Singleton<TMyClass>;       // 1 instância (eager na receita, lazy na criação)
// ou
LInjector.SingletonLazy<TMyClass>;   // idem, receita adiada ao 1º Get
// ou
LInjector.Factory<TMyClass>;         // instância NOVA a cada Get

LObj := LInjector.Get<TMyClass>;     // resolve por T.ClassName
```
Fontes: `UTesteInject.pas:253-270` (Singleton), `:210-227` (Lazy), `:101-118`
(Factory). Detalhe de cada modo em [../binds-scopes.md](../binds-scopes.md).

## 2. Registre por INTERFACE (resolve com `GetInterface<I>`)

```pascal
// I precisa ter GUID; T deve implementar I (via TInterfacedObject).
LInjector.SingletonInterface<IMyClass, TMyClass>;
LSvc := LInjector.GetInterface<IMyClass>;   // resolve pelo GUID de IMyClass
```
Fonte: `UTesteInject.pas:120-154`. Múltiplas implementações? Use **tag**:
`SingletonInterface<IMyClass, TMyClass>('nome')` +
`GetInterface<IMyClass>('nome')` (`:156-173`). Ver
[../resolve-by-interface.md](../resolve-by-interface.md).

> ⚠️ Se o consumidor guarda a interface num **local** e a solta, o objeto é
> destruído (refcount). Cacheie o ref (Regra 4 em [../rules.md](../rules.md)).

## 3. Deixe o container montar o construtor (injeção automática)

Declare o `Create` com as deps como parâmetros e registre **cada dep na porta
certa**:

```pascal
TMyClassParam = class
  constructor Create(const AClass: TParamClass; const AInterface: IParamClass);
end;

LInjector.Singleton<TParamClass>;                        // dep por classe
LInjector.SingletonInterface<IParamClass, TParamClass>;  // dep por interface
LInjector.Singleton<TMyClassParam>;

LObj := LInjector.Get<TMyClassParam>;   // AClass e AInterface vêm preenchidos
```
Fonte: `UTesteInject.pas:48-57,229-251`. O container lê o `Create` por RTTI e
resolve `tkClass` por nome e `tkInterface` por GUID; primitivos vêm `nil`. Ver
[../constructor-injection.md](../constructor-injection.md).

## 4. Quando precisar controlar os params: `OnParams`

```pascal
LInjector.Factory<TBindProvider>(nil, nil,
  function: TConstructorParams
  begin
    Result := [TValue.From<TTracker>(LInjector.Get<TTracker>)];
  end);
```
Fonte: `Nidus.Inject.pas:90-97`. `OnParams` **sobrescreve** a auto-injeção
(`Inject.pas:350,387`). Use também `OnCreate` para pós-configurar
(`Nidus.Inject.pas:128-135`) e `OnDestroy` (roda no `Remove<T>`).

## 5. Instância pronta ou injector-filho

```pascal
LInjector.AddInstance<TRegister>(TRegister.Create);   // registra objeto já criado
LInjector.AddInject('Nidus', TCoreInject.Create);     // pendura um injector-filho
```
Fonte: `Nidus.Inject.pas:177-178`. `AddInject` é o que forma a hierarquia
root→filho — ver [../binds-scopes.md](../binds-scopes.md).

## 6. Remover / trocar um bind

```pascal
LInjector.Remove<TMyClass>;   // dispara OnDestroy e limpa dos 4 repositórios
```
Fonte: `Inject.pas:395-418`. No Nidus: `ExtractInject<T>`
(`Nidus.Inject.pas:181-189`).

## Checklist final

- [ ] Registrou a dep **na mesma porta** que o construtor pede? (classe → `Get`,
      interface → `GetInterface`). Se o `Create` pede as duas, registre nas duas
      (Passo 3).
- [ ] As deps de construtor estão **no mesmo injector** que constrói o serviço?
      (irmão não alcança — Regra 1).
- [ ] Interface guardada num **campo de vida longa**, não num local? (Regra 4).
- [ ] Não há **registro duplicado** no mesmo injector? (lança — Regra 7).
- [ ] Sem **ciclo** de construtor? (`ECircularDependency` — Regra 8).

## Citations

- `Test Delphi/UTesteInject.pas:101-270` — todos os modos + auto-inject.
- `Source/Inject.pas:145-158,395-418` — global injector + `Remove`.
- `Nidus.Inject.pas:90-97,128-135,177-189` — `OnParams`/`OnCreate`/`AddInject`/`AddInstance`/`Extract`.
</content>
