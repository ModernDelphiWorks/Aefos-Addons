---
type: API Reference
title: Nidus — Guards & Pipes de Validação
description: Guards de rota (TRouteMiddleware, Call/Before/After) e o pipe de validação com os decorators de payload [Body]/[Param]/[Query], com o lifecycle real e as armadilhas de DI em guard.
tags: [nidus, delphi, guard, middleware, pipe, validation, body, param]
timestamp: 2026-07-11T00:00:00Z
---

# Guards & Pipes de Validação

Duas camadas rodam **antes** do controller: os **guards** (autorização por rota)
e o **pipe de validação** (validação de payload por decorators).

## Guards — `TRouteMiddleware`

Um guard é uma classe descendente de `TRouteMiddleware`, que implementa
`IRouteMiddleware` (`Routes/Nidus.Route.Abstract.pas:26-42`):

```pascal
IRouteMiddleware = interface
  ['{0962F508-FEA3-4109-9775-220C9F8B257E}']
  function Before(ARoute: TRouteAbstract): TRouteAbstract;
  function Call(const AReq: IRouteRequest): Boolean;   // False ⇒ 401
  procedure After(ARoute: TRouteAbstract);
end;

TMiddlewares = array of TRouteMiddlewareClass;
```

- **`Call` é o gate**: retornar `False` rejeita a request. O Tracker roda cada
  guard da rota em `_GuardianRoute` e levanta `EUnauthorizedException` (⇒ HTTP
  401) se algum `Call` volta `False` (`Core/Nidus.Tracker.pas:207-224`):

  ```pascal
  if not LMiddleware.Call(LParamRequest.AsType<IRouteRequest>) then
    raise EUnauthorizedException.Create('');
  ```

- Anexe guards a uma rota no `RouteModule`:
  `RouteModule(path, TModulo, [TAuthGuard])`
  (`modulos/app.module.pas:68`, `Source\App.Module.pas:719-741`).

- Guard mínimo do exemplo (`modulos/app.module.pas:16-19,74-77`):
  ```pascal
  TGardNFeMiddleware = class(TRouteMiddleware)
  public
    function Call(const AReq: IRouteRequest): boolean; override;
  end;

  function TGardNFeMiddleware.Call(const AReq: IRouteRequest): boolean;
  begin
    Result := True;
  end;
  ```

### ⚠️ Lifecycle do guard (duas armadilhas reais)

O guard é criado por um `Create` **sem parâmetros** (`Nidus.Tracker.pas:217`
`ARoute.Middlewares[LFor].Create`), então **não há injeção por construtor num
guard** — a resolução de dependências é por container (`GetNidus.Get`/
`GetInterface`) em tempo de `Call`
(`Source\Shared\Guards\Shared.Auth.Guard.pas:26-32`).

1. **DI em guard resolve no injector ROOT, não no do módulo.** Tudo que um guard
   (ou algo que ele chame transitivamente) resolve em runtime precisa estar
   exportado por um módulo que o `TAppModule` **importa diretamente**. Caso real:
   o `TAppModule.Imports = [TCoreModule, TEMPModule]` existe justamente para o
   guard achar seu validator e o `TJanusSession`
   (`Source\App.Module.pas:709-720`). Ver [rules.md](rules.md), Regra 4.

2. **`SingletonInterface` resolvido num local morre no fim do `Call`.** Cacheie o
   ref num `class var`. O `TAuthGuard` faz exatamente isso
   (`Shared.Auth.Guard.pas:74-83`):
   ```pascal
   // DEC-047 — CACHE o validator no class var; SingletonInterface é refcontado.
   FValidator := GetNidus.GetInterface<IEmpresaTenantValidator>;
   ```
   Ver [rules.md](rules.md), Regra 5.

3. **`After` roda ANTES do handler nesse lifecycle** — não use `After` para limpar
   estado que o controller precisa; o `TAuthGuard` reseta o escopo de tenant no
   **início do `Call`**, não no `After` (`Shared.Auth.Guard.pas:94-100,133-139`).

### Guard global (opcional)

`GetNidus.UseGuard(callback)` registra um guard global rodado em todo
`LoadRouteModule` antes da resolução da rota (`Nidus.pas:271-275,305-310`). É um
`TGuardCallback` (função boolean), separado dos guards de rota.

## Pipe de validação — decorators de payload

Habilite o pipe no bootstrap com `GetNidus.UsePipes(TValidationPipe.Create)`
(`e_docs_api.dpr:252`, `Nidus.pas:285-289`). Com o pipe ativo, o
`LoadRouteModule` valida o método-alvo pelos seus decorators ANTES de resolver a
rota; se houver mensagens, responde `EBadRequestException` (HTTP 400)
(`Nidus.pas:311-324`).

Decore o método do handler com os atributos de payload
(`modulos/nfe/nfe.route.handler.pas:36-39`):

```pascal
[Body(TPerson, TParseJsonPipe)]
// [Param('id', TIsNotEmpty), Param('id', TParseIntegerPipe)]
// [Query('name', TIsString), Query('name', TIsNotEmpty)]
procedure NFeServicoStatus(Req: THorseRequest; Res: THorseResponse);
```

Os três decorators de payload (`Source/Pipes/Decorators/PayLoads/`):

- **`[Body(TDto, TTransformPipe [, TValidacao] [, msg])]`** — valida/transforma o
  corpo. `Body(TPerson, TParseJsonPipe)` faz o parse do JSON para `TPerson`
  (`Nidus.Decorator.Body.pas:26-59`; tag `'body'`).
- **`[Param('nome', TTransform [, TValidacao] [, msg])]`** — valida/transforma um
  param de path pelo nome (`Nidus.Decorator.Param.pas:25-77`; tag `'param'`).
- **`[Query('nome', ...)]`** — idem para query string
  (`Nidus.Decorator.Query.pas`).

Validadores e pipes disponíveis (via `Nidus.Validation.Include` e
`Nidus.Decorator.Include`): pipes de transformação `TParseJsonPipe`,
`TParseIntegerPipe`; validadores `TIsNotEmpty`, `TIsString`, `TIsInteger`,
`TIsNumber`, `TIsBoolean`, `TIsDate`, `TIsEnum`, `TIsArray`, `TIsObject`,
`TIsEmpty`, `TIsMin`/`TIsMax`, `TIsMinLength`/`TIsMaxLength`, `TIsAlpha`,
`TIsAlphaNumeric`, `TContains`, `TIsLength`
(`Pipes/Core/Nidus.Validation.Include.pas`, `Pipes/Decorators/Nidus.Decorator.Include.pas`).
Há ainda uma família ampla estilo class-validator (IsEmail, IsUUID, IsCreditCard,
IsIban, IsJWT, ...) em `Pipes/Validators/` e `Pipes/Decorators/`.

O `uses` do handler que usa pipes traz `Nidus.Decorator.Include`,
`Nidus.Validation.Include` e o pipe de parse concreto (ex.:
`Nidus.parse.Jsonbr.Pipe`) (`modulos/nfe/nfe.route.handler.pas:17-19`).

## Citations

- `Routes/Nidus.Route.Abstract.pas:26-42` — `IRouteMiddleware`/`TRouteMiddleware`/`TMiddlewares`.
- `Core/Nidus.Tracker.pas:207-224` — `_GuardianRoute` (Call False ⇒ 401).
- `modulos/app.module.pas:16-19,68,74-77` — guard de rota no exemplo.
- `Source\App.Module.pas:709-741`, `Source\Shared\Guards\Shared.Auth.Guard.pas:26-139` — guard vivo (root import, refcount, After lifecycle).
- `Nidus.pas:271-289,305-324` — `UseGuard`/`UsePipes` e a validação no `LoadRouteModule`.
- `Pipes/Decorators/PayLoads/Nidus.Decorator.Body.pas:26-59`, `Nidus.Decorator.Param.pas:25-77` — `[Body]`/`[Param]`.
- `modulos/nfe/nfe.route.handler.pas:17-19,36-39` — decorators no handler.
- `delphi-nidus-specialist.md:43,45-48,56-57` — controllers, guards e erratas 4-5.
</content>
