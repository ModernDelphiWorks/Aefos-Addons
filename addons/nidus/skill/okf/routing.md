---
type: API Reference
title: Nidus — Roteamento
description: Como montar rotas com RouteModule/RouteChild, a convenção de path por record, o gotcha crítico do parâmetro só na cauda (regex RemoveSuffix) e os controllers TRouteHandlerHorse.
tags: [nidus, delphi, routing, routemodule, controller, path, param]
timestamp: 2026-07-11T00:00:00Z
---

# Roteamento

O roteamento no Nidus tem dois lados: o **módulo** monta sub-rotas com
`RouteModule`/`RouteChild` (declara QUE módulo atende QUE path), e o
**controller** (`TRouteHandlerHorse`) registra os handlers HTTP por método.

## Convenção de path (record de rotas)

O exemplo centraliza os paths num record com um `Root` concreto e cada rota
derivada dele — nada de string mágica espalhada
(`modulos/app.route.pas:5-124`):

```pascal
function TRotas.Root: String;          begin Result := '/nfe/v1';                 end;
function TRotas.Configurar: String;    begin Result := Root + '/configuracao';    end;
function TRotas.NFeConsultar: String;  begin Result := Root + '/consulta/:chave'; end;  // param na CAUDA
function TRotas.NFeTransmitidaXML: String; begin Result := Root + '/xml/:chave';  end;
```

Note `Root = '/nfe/v1'` — **a versão é um literal concreto**, nunca um param.
Isso é deliberado (ver o gotcha abaixo).

## Montar rotas no módulo — `RouteModule` / `RouteChild`

```pascal
function TAppModule.Routes: TRoutes;
begin
  Result := [RouteModule(Rota.Configurar, TConfigModule),
             RouteModule(Rota.NFeConsultar, TNFeModule),
             RouteModule(Rota.NFeServicoStatus, TNFeModule, [TGardNFeMiddleware])]; // com guard
end;
```
Fonte: `modulos/app.module.pas:60-70`. Assinaturas em
`Modules/Nidus.Module.pas:80-118`:

- `RouteModule(path, TModulo)` — monta o módulo sob o path.
- `RouteModule(path, TModulo, [TGuard1, TGuard2])` — idem, com guards de rota
  (`TMiddlewares`).
- `RouteChild(path, TModulo [, middlewares])` — sub-rota aninhada.

Um mesmo módulo pode ser montado em vários paths (o exemplo monta `TNFeModule` em
sete rotas diferentes — `app.module.pas:63-69`; a linha 62 monta `TConfigModule`).
O Tracker cria **um único
injector por módulo**, reusado por todas as rotas dele
(`Nidus.Tracker.pas:236-246`).

Módulos também montam sub-módulos nas suas próprias `Routes` (composição de
rotas) — o `TNFeModule` monta `TPDFModule`/`TXMLModule` sob paths de PDF/XML
(`modulos/nfe/nfe.module.pas:53-63`). **Prefira isso a `Imports` para compor
rotas** (ver [rules.md](rules.md), Regra 6).

## ⚠️ Gotcha crítico — parâmetro SÓ na cauda

O resolver dinâmico do Nidus reduz o path removendo os segmentos de parâmetro do
**FIM** (via regex ancorado em `$`) e então casa o restante por igualdade exata
na lista de endpoints (`Routes/Nidus.Route.Manager.pas:49-72`):

```pascal
function TRouteManager.RemoveSuffix(const ARoute: String): String;
const
  // DEC-051 — tira TODOS os segmentos de param no fim (um ou mais), não só o último.
  LPattern = '(/:[^/]+|/\{[^/]*\})+$';
begin
  Result := TRegEx.Replace(ARoute, LPattern, '');
end;
```

Consequência:

- ✅ `/nfe/v1/consulta/:chave` → param é o último segmento → reduz a
  `/nfe/v1/consulta` → **casa**.
- ✅ `/x/:a/:b` (composite key, DEC-051) → reduz a `/x` → **casa**.
- ❌ `/api/:version/x` (param no MEIO) → o `$` não pega o param do meio → o path
  reduzido ainda tem `:version` embutido → **NUNCA casa → 404**.

**Versão/segmento variável tem que ser literal concreto.** Use `/api/v1/...`, não
`/api/:version/...`. Confirmado contra o exemplo, que usa `Root='/nfe/v1'`
(`app.route.pas:40-42`) e param só na cauda (`app.route.pas:80-83`).

Por que o Horse (que É param-aware) não salva: quando o resolver do Nidus falha,
o middleware `Nidus_Horse` responde e **curto-circuita com
`raise EHorseCallbackInterrupted`** (`Nidus.Driver.Horse.pas:78-93`), então o
roteador nativo do Horse nem chega a rodar. Não confie no router do Horse por
baixo do Nidus (`delphi-nidus-specialist.md:53,55`). Ver [rules.md](rules.md),
Regra 3. Caso real DFeFw: 1152 rotas `/api/:version/...` inalcançáveis; trocar
para `/api/v1/...` destravou.

## Controllers — `TRouteHandlerHorse`

Um controller descende de `TRouteHandlerHorse`, sobrescreve `RegisterRoutes`
encadeando `RouteGet/RoutePost/...(path, Metodo)`, e cada método é
`procedure(Req: THorseRequest; Res: THorseResponse)`
(`modulos/nfe/nfe.route.handler.pas:24-55`):

```pascal
type
  TNFeRouteHandler = class(TRouteHandlerHorse)
  protected
    procedure RegisterRoutes; override;
  public
    procedure NFeTransmitir(Req: THorseRequest; Res: THorseResponse);
    procedure NFeConsultar(Req: THorseRequest; Res: THorseResponse);
    // decorator opcional dirige o pipe de validação (ver guards-pipes.md):
    [Body(TPerson, TParseJsonPipe)]
    procedure NFeServicoStatus(Req: THorseRequest; Res: THorseResponse);
  end;

procedure TNFeRouteHandler.RegisterRoutes;
begin
  RouteGet(Rota.NFeTransmitir, NFeTransmitir)
    .RouteGet(Rota.NFeConsultar, NFeConsultar)
    .RouteGet(Rota.NFeServicoStatus, NFeServicoStatus);
end;

procedure TNFeRouteHandler.NFeTransmitir(Req: THorseRequest; Res: THorseResponse);
var LResult: TNFeResponse;
begin
  LResult := GetNidus.Get<TNFeController>.NFeTransmitir(Req.Body);  // resolve + delega
  LResult.When(
    procedure (Json: String) begin Res.Send(Json).ContentType(CONTENTTYPE_JSON).Status(200); end,
    procedure (Error: ERequestException)
    begin
      try Res.Send(Error.Message).ContentType(CONTENTTYPE_JSON).Status(Error.Status);
      finally Error.Free; end;
    end);
end;
```

### Dois passos obrigatórios de registro

1. No `initialization` da unit do handler:
   `GetNidus.RegisterRouteHandler(TNFeRouteHandler)`
   (`modulos/nfe/nfe.route.handler.pas:204-205`).
2. Liste o handler no `RouteHandlers` do módulo dono
   (`modulos/app.module.pas:52-58` lista `TNFeRouteHandler` etc.).

Sem os dois, o handler não é conhecido. O registro no roteador do Horse é
idempotente — o mesmo `[método] path` só entra uma vez, primeira registração vence
(`Nidus.Route.Handler.Horse.pas:40-100`), o que torna seguro reconstruir handlers
em testes/imports em diamante.

## Citations

- `modulos/app.route.pas:5-124` — record de rotas, `Root` concreto, param na cauda.
- `modulos/app.module.pas:60-70` — `RouteModule` com e sem guard.
- `Modules/Nidus.Module.pas:80-118` — assinaturas de `RouteModule`/`RouteChild`.
- `Routes/Nidus.Route.Manager.pas:49-72` — `RemoveSuffix`/`FindEndPoint` (o gotcha).
- `Nidus.Driver.Horse.pas:78-93` — curto-circuito com `EHorseCallbackInterrupted`.
- `modulos/nfe/nfe.route.handler.pas:24-55,204-205` — controller + registro.
- `Horse/Nidus.Route.Handler.Horse.pas:40-100` — registro idempotente no Horse.
- `delphi-nidus-specialist.md:36-43,53,55` — gotcha de roteamento e controllers.
</content>
