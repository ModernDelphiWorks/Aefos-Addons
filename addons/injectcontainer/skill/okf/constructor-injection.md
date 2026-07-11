---
type: Reference
title: InjectContainer — Injeção por Construtor
description: Como _ResolverParams resolve cada parâmetro do Create por RTTI (classe por nome, interface por GUID), em qual injector resolve, o override por OnParams e a detecção de dependência circular.
tags: [injectcontainer, di, delphi, constructor-injection, rtti, resolverparams]
timestamp: 2026-07-11T00:00:00Z
---

# Injeção por Construtor

A auto-injeção é o coração do container: ao resolver um serviço, ele **descobre o
`Create` por RTTI, lê cada parâmetro e resolve cada um** no injector corrente. Não
há atributos a decorar — basta declarar um `constructor Create(...)` com as
dependências como parâmetros.

## Exemplo de uso correto (do Test)

```pascal
TMyClassParam = class
  constructor Create(const AClass: TParamClass;      // dep por CLASSE
                     const AInterface: IParamClass);  // dep por INTERFACE
end;
...
LInjector.Singleton<TParamClass>;                       // porta por nome
LInjector.SingletonInterface<IParamClass, TParamClass>; // porta por GUID
LInjector.Singleton<TMyClassParam>;
LMyClassParam := LInjector.Get<TMyClassParam>;          // params injetados sozinhos
Assert.IsNotNull(LMyClassParam.ParamClass);
Assert.IsNotNull(LMyClassParam.ParamInterface);
```
Fonte: `Test Delphi/UTesteInject.pas:48-57,229-251`. Note que a MESMA classe foi
registrada nas **duas** portas (nome e GUID) porque o construtor pede as duas
formas.

## Como funciona: `_ResolverParams`

`Source/Inject.pas:440-501`. Quando um `Get`/`GetInterface` precisa criar a
instância e **não há `OnParams`** registrado (`FInjectorEvents.Count = 0`,
`:350,387`), ele chama `_ResolverParams(ServiceClass)`:

1. Pega o `TRttiType` da classe (do **cache RTTI**, `_GetCachedType` `:566`) e o
   método `Create` (`_GetCachedMethod` `:470,590`).
2. Para cada parâmetro, decide pelo `TypeKind` (`:480-494`):
   - **`tkClass` / `tkClassRef`** → `Get<TObject>(nomeDoTipo).Cast(handle)`
     (`:481-485`) — resolve **por NOME de classe** no injector corrente.
   - **`tkInterface`** → `_ResolverInterfaceType(handle, GUID)` (`:486-491`), que
     faz `GetInterface<IInterface>(GUIDToString(GUID))` e dá `Supports` para o
     tipo certo (`:503-517`) — resolve **por GUID** no injector corrente.
   - **qualquer outro tipo** (string/Integer/record/…) → `TValue.From(nil)`
     (`:492-493`): o container **não injeta primitivos**; eles chegam vazios.
3. Invoca o `Create` com o array de `TValue` montado
   (`TServiceData._Factory` → `LConstructorMethod.Invoke`,
   `Inject.Service.pas:92-111`).

Se algo falhar no meio, a exceção é re-lançada com o dump dos params já resolvidos
(`Format(E.Message + ' => ' + TostringParams(...))`, `:496-499`).

## Em QUAL injector os params são resolvidos

Os `Get<TObject>` / `GetInterface` de dentro de `_ResolverParams` rodam sobre
**`Self` — o injector que está criando o serviço** (`:483,511`). Combinado com o
scan de 1 nível (ver [binds-scopes.md](binds-scopes.md)), isso significa:

> Cada dependência de construtor precisa estar **no mesmo injector** que constrói o
> serviço (ou num filho direto dele). Um injector **irmão** não é alcançado.

No Nidus, o injector que constrói é **o do módulo consumidor**; por isso as deps de
um serviço exportado **também** têm de estar no injector do consumidor (exporte-as)
— errata 2 do Nidus (`delphi-nidus-specialist.md:52`). Ver [rules.md](rules.md).

## Override manual: `OnParams`

Se você **não** quer a auto-injeção (ou precisa passar algo que o RTTI não resolve,
como um primitivo ou uma instância específica), registre um
`AOnConstructorParams: TFunc<TConstructorParams>`. Quando presente, o container usa
o array que ele devolve e **pula** `_ResolverParams` (`Inject.pas:350,387`;
`Inject.Service.pas:123-133`).

```pascal
// Nidus passando TTracker explicitamente ao construtor de TBindProvider:
Self.Factory<TBindProvider>(nil, nil,
  function: TConstructorParams
  begin
    Result := [TValue.From<TTracker>(Self.Get<TTracker>)];
  end);
```
Fonte: `Nidus.Inject.pas:90-97`.

## Dependência circular

Antes de resolver, o container empilha o nome do serviço
(`_PushDependency` `:551-558`) e checa se ele **já está na pilha**
(`_CheckCircularDependency` `:519-549`). Se estiver, lança
`ECircularDependency` com a cadeia legível (`A -> B -> A`). Ao terminar, desempilha
(`_PopDependency` `:560-564`). Isso protege contra `A(Create: B)` e `B(Create: A)`.

## Citations

- `Source/Inject.pas:440-501` — `_ResolverParams` (tkClass/tkClassRef/tkInterface/else).
- `Source/Inject.pas:503-517` — `_ResolverInterfaceType` (Supports por GUID).
- `Source/Inject.pas:350,387` — auto-injeção só quando não há `OnParams`.
- `Source/Inject.pas:519-564` — detecção de ciclo (push/check/pop).
- `Source/Inject.Service.pas:92-133` — `_Factory` (Invoke) + prioridade do `OnParams`.
- `Test Delphi/UTesteInject.pas:48-57,229-251` — auto-inject de classe + interface.
- `Nidus.Inject.pas:90-97` — override por `OnParams` no consumo real.
- `delphi-injectcontainer-specialist.md:17` — resolve no injector corrente, não em irmãos.
</content>
