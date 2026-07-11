---
type: API Reference
title: Nidus — Bootstrap (.dpr) & Integração Horse
description: A ordem de montagem no .dpr — middlewares do Horse, Nidus_Horse(TAppModule), UsePipes/UseCache, e THorse.Listen — e os addons (cache/pools/RPC).
tags: [nidus, delphi, bootstrap, dpr, horse, listen, pipes, cache]
timestamp: 2026-07-11T00:00:00Z
---

# Bootstrap (.dpr) & Integração Horse

O `.dpr` monta a aplicação numa ordem que importa. Referência real
(`e_docs_api.dpr:238-262`):

```pascal
begin
  // 1) Middlewares do Horse (crus) primeiro
  THorse.Use(OctetStream)
        .Use(HorseBasicAuthentication(
             function (const AUserName, APassword: string): Boolean
             begin
               Result := True;
             end));

  // 2) Registra o AppModule (isto chama GetNidus.Start por baixo)
  THorse.Use(Nidus_Horse(TAppModule.Create));

  // 3) Middlewares que dependem do Nidus já montado (ex.: cache de response)
  THorse.Use(ResponseCache([Rota.Root + '/api/xml/',
                            Rota.Root + '/api/pdf/'], 30, 5000));

  // 4) Configura o Nidus (fluent) — pipes de validação e cache de módulo
  GetNidus.UsePipes(TValidationPipe.Create);
  GetNidus.UseCache(TModuleCacheManager.Create);

  // 5) Sobe o servidor por ÚLTIMO
  THorse.Listen(9000, '127.0.0.1',
    procedure begin WriteLn('Status: Online') end);
end.
```

## A ordem (não inverta)

1. **`THorse.Use(...)` dos middlewares crus do Horse** (octet-stream, auth
   básica, CORS, JWT, ...). Eles rodam na cadeia do Horse.
2. **`THorse.Use(Nidus_Horse(TAppModule.Create))`** — instancia o AppModule e o
   passa ao `Nidus_Horse`, que chama `GetNidus.Start(AAppModule)` e devolve o
   middleware do Nidus (`Horse/Nidus.Driver.Horse.pas:44-53`). A partir daqui o
   Nidus está montado e `GetNidus` funciona.
3. **Middlewares que dependem do Nidus** (ex.: `ResponseCache`) vêm DEPOIS do
   `Nidus_Horse`.
4. **`GetNidus.UsePipes(...)` / `UseCache(...)` / `UsePools(...)` / `UseRPC(...)`**
   — configuração fluent do Nidus (`Nidus.pas:73-84`).
5. **`THorse.Listen(porta, host, callback)`** por último — bloqueia servindo.

`Start` só pode rodar uma vez; chamá-lo com o app já iniciado levanta
`EModuleStartedException` (`Nidus.pas:249-269`).

## O que o `Nidus_Horse` faz

`Nidus_Horse(TAppModule.Create)` (`Nidus.Driver.Horse.pas:44-53`):

```pascal
function Nidus_Horse(const AAppModule: TModule): THorseCallback;
begin
  GetNidus.Start(AAppModule);       // monta o AppModule (binds/rotas/handlers)
  Result := Nidus_Horse('UTF-8');   // devolve o Middleware
end;
```

O `Middleware` resultante intercepta cada request, resolve a rota, roda
guards+pipe e faz load/dispose do módulo de rota (ver
[overview.md](overview.md), ciclo de vida).

## Registro dos controllers

Cada unit de handler faz `GetNidus.RegisterRouteHandler(TXxxRouteHandler)` no seu
`initialization` (`modulos/nfe/nfe.route.handler.pas:204-205`) E o handler é
listado no `RouteHandlers` do módulo dono (`app.module.pas:52-58`). Para isso
disparar, a unit do handler precisa estar no `uses` do `.dpr` (todas estão —
`e_docs_api.dpr:137-139`).

## Addons opcionais

- **Cache de módulo:** `GetNidus.UseCache(TModuleCacheManager.Create [, [TMod]])`
  — cacheia a resolução de módulos; a sobrecarga com policy limita a quais módulos
  (`Nidus.pas:158-175`).
- **Object/Component pools:** `GetNidus.UsePools<T>(maxSize)` /
  `UseComponentPool<T>` + `WithPool<T>(proc)` (`Nidus.pas:77-93,177-215`).
- **RPC (microservices):** `GetNidus.UseRPC(server).PublishRPC(nome, TRes)`
  (`Nidus.pas:84-86,291-342`).
- **Listener/log:** `TNidus.UseListener(TListener...)` imprime o boot
  (`[NidusStart]`, `[InstanceImported] X`) (`Nidus.pas:262-283`).

## Horse/auth que aparecem junto (não são Nidus, mas mordem)

- **Header case-sensitive** no horse-jwt: o default é `'authorization'`
  (minúsculo); o cliente manda `Authorization`. Configure
  `THorseJWTConfig.New.Header('Authorization')` no `.dpr` ou toda rota autenticada
  dá 401 (`delphi-nidus-specialist.md:59`). Ver [rules.md](rules.md), Regra 7.
- **`.dcu` cacheado:** para recompilar um `.pas` de `.modules` (horse-jwt etc.),
  delete o `.dcu` correspondente antes do build; e cuidado com o Horse puxado de
  um path global em vez do `.modules` vendorizado
  (`delphi-nidus-specialist.md:59`).

## Citations

- `e_docs_api.dpr:137-139,238-262` — a ordem de bootstrap real.
- `Horse/Nidus.Driver.Horse.pas:44-53` — `Nidus_Horse` chama `Start`.
- `Nidus.pas:73-93,158-215,249-342` — `UsePipes`/`UseCache`/`UsePools`/`UseRPC`/`Start`/`UseListener`.
- `modulos/nfe/nfe.route.handler.pas:204-205`, `app.module.pas:52-58` — registro de handlers.
- `delphi-nidus-specialist.md:45-48,59` — bootstrap e erratas de auth/build.
</content>
