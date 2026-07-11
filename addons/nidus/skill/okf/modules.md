---
type: API Reference
title: Nidus — Módulos & Injeção de Dependência
description: A anatomia do TModule (Binds/ExportedBinds/Imports/Routes/RouteHandlers), a regra de visibilidade cross-module e os escopos de bind, transcritos do Source e do exemplo funcional.
tags: [nidus, delphi, di, module, binds, exportedbinds, imports, scopes]
timestamp: 2026-07-11T00:00:00Z
---

# Módulos & Injeção de Dependência

O `TModule` é a unidade de composição do Nidus. Ele descende de `TModuleAbstract`
e sobrescreve até cinco funções, cada uma retornando um array
(`Modules/Nidus.Module.Abstract.pas:28-42`, `Modules/Nidus.Module.pas:51-73`).

## Anatomia do módulo (as 5 sobrescritas)

| Override | Retorna | Papel |
|---|---|---|
| `Binds` | `TBinds` | DI **privado ao injector do próprio módulo**. Visível só aos serviços/handlers deste módulo. |
| `ExportedBinds` | `TExportedBinds` | DI **visível a qualquer módulo que faça `Imports` deste**. É o ÚNICO jeito de um bind cruzar a fronteira de módulo. |
| `Imports` | `TImports` | Classes de módulo cujos **ExportedBinds** são mesclados no injector DESTE módulo (os `Binds` privados deles NÃO vêm junto). |
| `Routes` | `TRoutes` | Sub-módulos montados sob um path via `RouteModule(path, TModulo [, [TGuard]])`. |
| `RouteHandlers` | `TRouteHandlers` | Controllers (classes descendentes de `TRouteHandlerHorse`). |

Tipos (`Modules/Nidus.Module.Abstract.pas:28-32`):

```pascal
TRoutes        = array of TRoute;
TBinds         = array of TBind<TObject>;
TImports       = array of TModuleClass;       // classes de módulo, não instâncias
TExportedBinds = array of TBind<TObject>;
TRouteHandlers = array of TRouteHandlerClass; // classes de controller
```

Todas as sobrescritas são `virtual`; o padrão de cada uma é `[]` (vazio), então
você só declara o que usar (`Nidus.Module.pas:169-192`).

### Exemplo de módulo completo (feature module) — ilustrativo

```pascal
type
  TNFeModule = class(TModule)
  public
    function Binds: TBinds; override;
    function Imports: TImports; override;
    function Routes: TRoutes; override;
  end;

function TNFeModule.Binds: TBinds;
begin
  Result := [Bind<TNFeInfra>.Factory,
             Bind<TNFeRepository>.Factory,
             Bind<TNFeService>.Factory,
             Bind<TNFeController>.Singleton];
end;

function TNFeModule.Imports: TImports;
begin
  Result := [TCoreModule];                     // recebe os ExportedBinds do Core
end;

function TNFeModule.Routes: TRoutes;
begin
  Result := [RouteModule(Rota.NFeTransmitidaXML, TXMLModule),
             RouteModule(Rota.NFeTransmitidaPDF, TPDFModule)];  // sub-módulos
end;
```
Fonte (ilustrativa — a ordem/roteiro real pode diferir): `modulos/nfe/nfe.module.pas:34-63`.
`Bind<T>` é um alias de `TBind<T>` só
para deixar a sintaxe curta dentro dos módulos (`Nidus.Module.pas:75-77`).

### Módulo provider puro (só exporta serviço)

O `TCoreModule` do exemplo não tem rotas nem binds privados — só `ExportedBinds`.
É o modelo do "módulo compartilhado":

```pascal
function TCoreModule.ExportedBinds: TExportedBinds;
begin
  Result := [Bind<TJsonLib>.Singleton,
             Bind<TNFeLibACBr>.SingletonInterface<INFeLib>];
end;
```
Fonte: `modulos/core/core.module.pas:24-28`. Todo feature module do exemplo
importa só `[TCoreModule]` (`nfe.module.pas:48-51`, `config.module.pas:43-46`).

## A regra de visibilidade cross-module (a coisa mais importante)

**Um módulo enxerga = seus próprios `Binds` + os `ExportedBinds` de cada módulo
em `Imports`. NÃO enxerga os `Binds` privados dos importados, nem os próprios
`ExportedBinds`.** Só `ExportedBinds` cruzam a fronteira.

Prova no Source — quando o Tracker constrói o injector de um módulo
(`Core/Nidus.Tracker.pas:236-261`):

```pascal
procedure TTracker.BindModule(const AModule: TModuleAbstract);
begin
  LInjector := FNidusInject^.Get<TNidusInject>(AModule.ClassName);
  if LInjector <> nil then Exit;              // 1 injector por módulo, reusado
  LInjector := _CreateInjector;
  LInjector.Name := AModule.ClassName;
  _AddModuleBinds(AModule, LInjector);         // <- os Binds PRÓPRIOS
  ...
  for LModule in AModule.Imports do
    _ResolverImports(LModule, LInjector);      // <- só ExportedBinds dos imports
  FNidusInject^.AddInject(AModule.ClassName, LInjector);
end;
```

E `_AddModuleImportsBind` só adiciona os `ExportedBinds` do importado (nunca os
`Binds`) (`Nidus.Tracker.pas:162-172`):

```pascal
procedure TTracker._AddModuleImportsBind(const AModule; const AInject);
begin
  _AddExportedModuleBinds(AModule, AInject);   // só ExportedBinds
  for LModule in AModule.Imports do            // e recursivamente os imports dele
    _ResolverImports(LModule, AInject);
end;
```

**Corolário crítico (errata 1):** se um serviço de um módulo depende de uma
INTERFACE provida por outro módulo, essa interface tem que estar nos
`ExportedBinds` do provedor (não nos `Binds`), e o consumidor tem que `Imports` o
provedor. Interface em `Binds` privado ⇒ `EBindException: Interface {GUID} not
found!` no consumidor. Ver [rules.md](rules.md), Regra 1.

**Corolário 2 (errata 2):** exportar a interface **não basta** se a implementação
tem deps de construtor. O Nidus resolve os params do construtor no injector do
módulo **consumidor**; injectors de módulos irmãos não são alcançáveis. **Exporte
também as deps de construtor** (o `Repository`, o `DAO`, ...). Ver
[rules.md](rules.md), Regra 2.

## Escopos de bind (`Bind<TConcreto>.Escopo`)

Da API `TBind<T>` (`Binds/Nidus.Bind.pas:27-45`):

| Escopo | Efeito | Uso típico |
|---|---|---|
| `Singleton` | uma instância compartilhada, viva enquanto o injector existir | controllers, libs stateless |
| `SingletonLazy` | singleton criado só no 1º resolve (lazy) | singleton caro/opcional |
| `Factory` | instância nova a cada resolve | infra/repository/service por request |
| `SingletonInterface<I>` | registra `TConcreto` sob o GUID da interface `I` | quando a dep é consumida como interface |
| `AddInstance(obj)` | registra uma instância já criada | injetar um objeto pronto/externo |

Detalhes:

- **`SingletonInterface<I>`** liga a classe concreta ao GUID da interface `I`
  (`Nidus.Bind.pas:145-148` → `ANidusInject.SingletonInterface<I, T>`). Resolve-se
  via `GetNidus.GetInterface<I>` ou como param `I` no construtor. Ex.:
  `Bind<TNFeLibACBr>.SingletonInterface<INFeLib>`
  (`core/core.module.pas:27`).
- ⚠️ **NÃO existe `FactoryInterface`.** A API `TBind` só tem
  `Singleton/SingletonLazy/Factory/SingletonInterface/AddInstance`
  (`Nidus.Bind.pas:32-44`). Dependência consumida como interface só pode ser
  `SingletonInterface<I>`. Se precisa de instância fresca por resolve, dependa da
  **classe concreta** com `Factory` (`delphi-nidus-specialist.md:33`).
- ⚠️ **`SingletonInterface<I>` é REFCONTADO.** Se o consumidor resolve num local e
  larga o ref, o `TInterfacedObject` por trás pode ser destruído e a próxima
  resolução volta NIL. **Cacheie o ref** num campo/`class var` de vida longa. Ver
  [rules.md](rules.md), Regra 5, e o caso real em
  `Source\Shared\Guards\Shared.Auth.Guard.pas:74-83`.

### Injeção por construtor (automática por RTTI)

Declare um `Create` cujos params são as dependências; o Nidus resolve cada param
no injector — classe por nome para params `tkClass`, GUID para params
`tkInterface`. Não há atributo: é a assinatura do construtor que dirige a
resolução (`delphi-nidus-specialist.md:34`).

```pascal
TNFeService = class(TInterfacedObject, INFe)
private
  FRepository: TNFeRepository;
public
  constructor Create(const ARepository: TNFeRepository);  // dep injetada
end;
```
Fonte: `modulos/nfe/services/nfe.service.pas:13-35`. O `TNFeController` segue o
mesmo padrão dependendo de `TNFeService`
(`modulos/nfe/controlles/nfe.controller.pas:16-35`). Como cada camada depende da
concreta abaixo com `Factory`, uma cadeia
`Controller → Service → Repository → Infra` é montada por resolução.

## Citations

- `Modules/Nidus.Module.Abstract.pas:28-42` — os tipos das 5 sobrescritas.
- `Modules/Nidus.Module.pas:51-77,169-192` — `TModule`, o alias `Bind<T>`, defaults.
- `Binds/Nidus.Bind.pas:27-45,145-148` — a API `TBind` e os escopos.
- `Core/Nidus.Tracker.pas:162-172,236-261` — só `ExportedBinds` cruzam; 1 injector/módulo.
- `modulos/nfe/nfe.module.pas:34-63`, `modulos/core/core.module.pas:24-28`,
  `modulos/config/config.module.pas:29-46` — módulos reais.
- `modulos/nfe/services/nfe.service.pas:13-35` — injeção por construtor.
- `delphi-nidus-specialist.md:18-34,51-52` — anatomia, escopos e erratas 1-2.
</content>
