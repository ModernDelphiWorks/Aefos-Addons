---
type: Reference
title: InjectContainer — Escopos de Bind & Hierarquia de Injectors
description: Singleton vs SingletonLazy vs Factory vs SingletonInterface; os dois repositórios (por nome vs por GUID); e a hierarquia root -> filho via AddInject com scan de 1 nível — a base de root/filho/irmão.
tags: [injectcontainer, di, delphi, scopes, singleton, factory, injector-hierarchy]
timestamp: 2026-07-11T00:00:00Z
---

# Escopos de Bind & Hierarquia de Injectors

Duas coisas independentes se chamam "escopo" no InjectContainer: (1) o **modo de
vida** de um serviço (singleton/factory) e (2) a **hierarquia de injectors**
(root/filho) que decide **quem alcança quem**. Documentamos as duas.

## 1. Modo de vida (o "escopo" de cada bind)

| Registro | Vida da instância | Quando nasce | Fonte |
|---|---|---|---|
| `Singleton<T>` | **uma** por injector | 1º `Get<T>` (receita criada já no registro) | `Inject.pas:160-177` |
| `SingletonLazy<T>` | **uma** por injector | 1º `Get<T>` (só a referência é registrada) | `Inject.pas:198-207` |
| `Factory<T>` | **nova a cada** `Get<T>` | todo `Get<T>` | `Inject.pas:235-250` |
| `SingletonInterface<I,T>` | **uma** por GUID (refcontada) | 1º `GetInterface<I>` | `Inject.pas:179-196` |
| `AddInstance<T>` | a instância que você passou | já existe | `Inject.pas:223-233` |
| `AddInject(tag, inj)` | o injector-filho que você passou | já existe | `Inject.pas:209-221` |

- **Singleton vs SingletonLazy** são quase equivalentes na prática (ambos só
  materializam o objeto no primeiro `Get`); a diferença é que `Singleton` já cria
  o `TServiceData` no registro e `SingletonLazy` adia isso ao primeiro `Get`
  (`GetTry` `:345-349`). Comprovação: `TestInjectorSington` e
  `TestInjectorLazyLoad` fazem a MESMA asserção `obj1 = obj2`
  (`UTesteInject.pas:210-227,253-270`).
- **Factory** é o único que devolve instância diferente por resolução
  (`AreNotEqual`, `UTesteInject.pas:114`; `imFactory` em
  `Inject.Service.pas:198`).
- **Não há `FactoryInterface`.** Interface só existe como singleton
  (`SingletonInterface<I>`). Para comportamento por-resolve, dependa da **classe
  concreta** com `Factory` (`delphi-nidus-specialist.md:33`;
  `Inject.Factory.pas` só tem `Factory`, `FactorySingleton`, `FactoryInterface`
  singleton, `:28-31`).

## 2. Dois repositórios: por nome vs por GUID

O container guarda serviços em **dois** dicionários separados
(`Inject.Container.pas:34-35`; a `:36` é `FInstances`, o 3º dicionário):

- `FRepositoryReference: TDictionary<string, TClass>` — chave = **`T.ClassName`**.
  Resolvido por `Get<T>` (`Inject.pas:337`).
- `FRepositoryInterface: TDictionary<string, TPair<TClass,TGUID>>` — chave =
  **`GUIDToString(GUID de I)`**. Resolvido por `GetInterface<I>`
  (`Inject.pas:372`).

Consequência: registrar `SingletonInterface<I,T>` **NÃO** deixa `T` resolvível por
`Get<T>` (a classe não vai para o repo por-nome); e registrar `Singleton<T>` não
deixa `I` resolvível por `GetInterface<I>`. Se um serviço precisa das duas portas,
registre nas duas (é o que o teste de auto-inject faz:
`Singleton<TParamClass>` **e** `SingletonInterface<IParamClass, TParamClass>`,
`UTesteInject.pas:239-240`).

## 3. Hierarquia de injectors — a base de "root/filho/irmão"

O container **não tem** um campo "pai". A hierarquia **emerge** de `AddInject`: um
`TInject` pode guardar **outros `TInject`** como se fossem serviços singleton
(`Inject.pas:209-221`). Assim:

```
GNidusInject (RAIZ)                <- injector global do Nidus
├── 'Nidus'   -> TCoreInject        (AddInject, Nidus.Inject.pas:177)
├── 'R01Module' -> TNidusInject     (1 por módulo, Nidus.Tracker.pas:260)
├── 'B01Module' -> TNidusInject
└── ...
```

**Como a resolução caminha** (`Get<T>`, `Inject.pas:257-289`):

1. Tenta o **próprio** injector (`GetTry`, `:267`).
2. Se `nil`, itera `GetInstances.Values` e, para cada serviço que **é um
   `TInject`**, chama o `GetTry` **dele** — um **scan de 1 nível, não-recursivo**
   (`:274-285`). Ou seja: alcança os **filhos diretos**, mas **não os netos**.

Disso saem as três palavras:

- **Root → filho: alcança.** Chamando `Get<T>` na raiz, você vê os binds da raiz +
  os de qualquer injector-filho direto. É por isso que um handler Nidus, que
  resolve via `FNidusInject^.Get<T>` (`Nidus.Tracker.pas:291-294`), enxerga tanto
  o núcleo (`'Nidus'`) quanto os módulos.
- **Filho → root: NÃO alcança.** Um injector-filho só vê a si mesmo + os seus
  próprios filhos (que ele normalmente não tem). Ele **não sobe** para a raiz.
- **Irmão → irmão: NÃO alcança.** Dois módulos pendurados na mesma raiz não se
  enxergam; a busca começa em quem você chamou e só desce.

> ⚠️ **Nuance vs o especialista.** O especialista descreve a busca em filhos
> "via recursão" (`delphi-injectcontainer-specialist.md:17`); o **código** faz um
> scan de **1 nível** (chama `GetTry` do filho, que não re-varre) —
> `Inject.pas:274-285`, confirmado pela errata #6 do Nidus
> (`delphi-nidus-specialist.md:56`: "scan de 1 nível, não-recursivo"). Trate como
> **1 nível** ao raciocinar sobre alcance.

## 4. Por que isso importa para o Nidus

Cada módulo Nidus resolve os params do seu construtor **contra o injector do
próprio módulo** (ver [constructor-injection.md](constructor-injection.md)). Um
injector-filho **não vê os irmãos**. Logo, se o serviço A (do módulo X) depende de
B (provido por outro módulo Y), **B precisa estar dentro do injector de X** — no
Nidus isso é feito **exportando** B (`ExportedBinds`) e importando Y, o que mescla
B no injector de X (`Nidus.Tracker.pas:146-172`). Esta é a raiz mecânica das
erratas 1 e 2 do Nidus (`delphi-nidus-specialist.md:51-52`) — ver
[rules.md](rules.md).

## Citations

- `Source/Inject.pas:160-250` — os seis registros e seus modos.
- `Source/Inject.pas:257-289` — scan de 1 nível dos filhos (root→filho).
- `Source/Inject.pas:209-221` — `AddInject` cria a hierarquia.
- `Source/Inject.Container.pas:34-35` — os dois repositórios (nome vs GUID); `:36` = `FInstances`.
- `Source/Inject.Service.pas:191-200` — imSingleton cacheia, imFactory recria.
- `Nidus.Inject.pas:177` — núcleo pendurado como filho `'Nidus'`.
- `Nidus.Tracker.pas:236-261,291-294` — 1 injector por módulo + resolução via raiz.
- `delphi-nidus-specialist.md:56` — confirmação "1 nível, não-recursivo".
</content>
