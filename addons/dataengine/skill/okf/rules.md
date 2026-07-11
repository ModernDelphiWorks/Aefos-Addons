---
type: Rules
title: DataEngine — Regras & Erratas
description: Antipadrões e lições aprendidas na marra do DataEngine; cada uma vira uma regra NUNCA/SEMPRE com o caso REAL citado. LER antes de escrever qualquer read/write avulso ou depurar um AV.
tags: [dataengine, delphi, rules, errata, antipatterns, firedac, transaction]
timestamp: 2026-07-11T00:00:00Z
---

# Regras & Erratas

Regras destiladas do especialista curado (`delphi-dataengine-specialist.md:21-26`) e
do Source verificado. **LER antes de escrever um read/write avulso ou depurar um
AV.** Cada regra carrega o caso REAL que a originou — não a resuma a ponto de perder
o caso; são anos de bug-hunt condensados.

## SEMPRE — fundamentar em código

- **SEMPRE cite `arquivo:linha`** (Source e/ou consumidor). Sem fonte, leia — não
  chute (`delphi-dataengine-specialist.md:13`).
- **SEMPRE lembre que o DataEngine NÃO tem `Examples` hoje** — o uso correto vem do
  Source + dos consumidores reais (ERP/Janus). Se precisar de um exemplo canônico do
  autor, é um TODO, não invente (`delphi-dataengine-specialist.md:10`).
- **SEMPRE distinga a fábrica (biblioteca de acesso) do `TDriverName` (dialeto).**
  Ver [drivers.md](drivers.md).

## Regra 1 — `NotEof` AUTO-AVANÇA o cursor: `while NotEof do` SEM `Next`

**NUNCA ponha `Next` dentro de um laço `while ADataSet.NotEof do`.** `NotEof` não é
`not Eof`: da 2ª chamada em diante ele chama `Next` internamente
(`Source/Core/DataEngine.DriverConnection.pas:672-679`,
`FNotEofStarted → Next`). Misturar os dois **pula uma linha por iteração**.

- **Certo:** `while ADataSet.NotEof do begin … end;` (sem `Next`).
- **Também certo:** `while not ADataSet.Eof do begin … ADataSet.Next; end;` (`Eof`
  NÃO anda; aí o `Next` é seu).
- **Errado:** `NotEof` **e** `Next` juntos.

Caso real / documentação da casa: o comentário do consumidor grava o gotcha verbatim
— *"NAO chamar Next: IDBDataSet.NotEof AVANCA o cursor (gotcha da casa) — o laco
`while NotEof do` ja anda sozinho"*
(`Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas:11-12,64`). Ver
[idbdataset.md](idbdataset.md).

## Regra 2 — AV no `.Open` ad-hoc: era o monitor-log dereferenciando `Transaction` NIL

**Se um `IDBDataSet` de `CreateDataSet(SQL)` dava Access Violation ao chamar `.Open`
explicitamente, o culpado NÃO era o `CreateDataSet` — era o `.Open` logando a
transação NIL.** Numa leitura autônoma (sem transação compartilhada *Active*),
`_InternalExecuteQuery` **não** atribui `LDataSet.Transaction` (só quando `.Active`,
`Source/Drivers/DataEngine.DriverFireDac.pas:392-395`) → `Transaction=nil` e o
FireDAC auto-gerencia por statement. O monitor-log no `finally` do `.Open`
dereferenciava `FDataSet.Transaction.Name` → *"Read of address 00000008"* (offset 8
= `TComponent.FName`).

- **Fix (framework, DataEngine PR #56, merged):** nil-guard de `.Transaction` no
  `Open`, emitindo `'(no transaction)'` — hoje presente em
  `Source/Drivers/DataEngine.DriverFireDac.pas:585-589` (comentário explicando em
  `:581-584`), espelhando o guard que já existia em `_InternalExecuteQuery`
  (`:460-463`).
- **Detalhe crucial:** o dataset de `CreateDataSet` **já vem ABERTO** (o
  `_InternalExecuteQuery` faz `LDataSet.Open` em `:434`). O container Janus itera
  direto e **nunca** chama `IDBDataSet.Open` — por isso só o caller que dava `.Open`
  explícito (ex.: o scalar-read do ABC/curva-abc) batia no AV.
- **Supersede:** uma leitura antiga da errata culpava o `CreateDataSet(SQL)` em si;
  está **corrigida** — o gatilho é o `.Open` ad-hoc, não o `CreateDataSet`
  (`delphi-dataengine-specialist.md:22,24`).

Caso real: ABC / curva-abc (DFeFw 2026-06-21).

## Regra 3 — Singleton `IDBConnection` + `'DEFAULT'` compartilhada: reads interleaved podem se envenenar

**NUNCA deixe um read autônomo "pegar carona" numa transação compartilhada que ficou
`Active` por acidente.** Uma `IDBConnection` sobre uma `TFDConnection` tem **UMA**
`TFDTransaction` `'DEFAULT'` compartilhada
(`Source/Drivers/DataEngine.DriverFireDacTransaction.pas:62-75`). Por read,
`CreateDataSet → _InternalExecuteQuery` cria um `TFDQuery` **fresco** (logo o
`FFDQuery` não é o culpado), mas o liga à `'DEFAULT'` **só se ela já estiver Active**
(`Source/Drivers/DataEngine.DriverFireDac.pas:392-395`).

- Os read paths do Janus (`ObjectSet.Adapter Find/FindWhere`) **nunca** dão
  Commit/Rollback; só os write paths. Um read que DEIXA a `'DEFAULT'` Active (ex.:
  associações eager abrindo datasets aninhados na mesma conexão) faz o **próximo**
  read se ligar a essa transação suja → AV/erro no `Open` → **400 persistente** até
  alguém commitar.
- Sintoma característico: rota X (com eager assoc) → rota Y dá 400, mas Z segue 200;
  Y sozinha 5× = 200.
- ⚠️ `InTransaction`/`_InTransaction` só retornam `.Active`
  (`Source/Core/DataEngine.FactoryConnection.pas:280-286` →
  `DriverFireDacTransaction.pas:108-111`) — **não distinguem** "transação explícita
  do dev" de "incidentalmente Active"; por isso o fix real precisaria de um contador
  de `StartTransaction` explícito.
- **Fix (framework, pendente/de-risco):** não deixar reads autônomos herdarem a
  `'DEFAULT'` (guardar o bind de `DriverFireDac.pas:394` por "transação explícita"),
  ou envolver os read paths do Janus em StartTransaction/Commit. **NÃO** "consertar"
  com `IDBConnection` fresco por-resolve via Factory (vaza/trava — ver Regra 4).

Caso real: rota `bancos` após `clientes` (DFeFw 2026-06-21)
(`delphi-dataengine-specialist.md:23`).

## Regra 4 — Conexão compartilhada: mantenha ABERTA; NUNCA Factory por-request

**NUNCA troque uma `IDBConnection` singleton compartilhada por uma Factory que
resolve conexão nova por request.** A Factory por-resolve cria instância nova e
**não a libera** → cada read **vaza** uma `TFDConnection` → o servidor **trava** em
poucas requests. E o adapter do objectset só `Connect`/`Disconnect`a uma conexão que
chegou **desconectada**, e o `Disconnect` **fecha fisicamente** a `TFDConnection`.

- **Fix p/ servidor single-process:** singleton + abrir 1× e MANTER aberta
  (`FConnection.Connected := True`) — DEC-047,
  `Source/Core/Core.Connection.pas:130-136,194-196` (consumidor).
- Antes de culpar a conexão, **instrumente ONDE a 2ª request morre** — grande parte
  do "só a 1ª request funciona" nem era conexão (era refcount de singleton no guard
  do DI). Herdada da errata do Janus (Regra 5 da skill `delphi-janus`).

## Regra 5 — AV cumulativo por Nº de ENTIDADES DISTINTAS lidas (leak por-entidade)

**Existe um AV DISTINTO das Regras 2 e 3: `Read of address 00000004` (offset 4) no
read-path do container, CUMULATIVO pelo número de entidades DISTINTAS lidas na
conexão singleton.** Caracterizado (terminais-caixa, 2026-06-22):

- NÃO é poisoner único (`ncms→terminais` sozinho = 200);
- NÃO é contagem bruta (160× a MESMA rota = ok — metadata reusada);
- NÃO é o txn-binding da Regra 3;
- ~150 entidades DISTINTAS esgotam alguma alocação por-entidade
  (RTTI/metadata/cursor/handle de statement) não liberada → nil → offset-4 AV, e
  **persiste na sessão**.

⚠️ O fix da Regra 3 (contador `FExplicitDepth` em `TDriverFireDACTransaction` +
guardar o bind em `DriverFireDac.pas:394` por `InExplicitTransaction`) foi
**desenhado, aplicado e REVERTIDO** — não corrigiu este AV e não era validável
contra o caso da Regra 3 (que não reproduz hoje). **Lição: não shipar mudança de
framework sem um bug vivo que ela comprovadamente conserta.** Em uso real uma request
toca poucas entidades, então raramente manifesta; o smoke de 176 rotas é stress
artificial. **Fix real (pendente):** caçar o leak por-entidade-distinta no read-path
DataEngine/Janus. Classe diferente do PR #56
(`delphi-dataengine-specialist.md:25`).

## Regra 6 — Patches no `.modules\DataEngine`

Ao corrigir o próprio framework: **branch dedicada no repo do DataEngine + backup
pristino + PR no final** (várias equipes editam em paralelo). O projeto consumidor
**NUNCA** commita `.modules`. O PR #56 (nil-guard do `.Open`) é o exemplo do fluxo
certo (`delphi-dataengine-specialist.md:24`).

## Citations

- `delphi-dataengine-specialist.md:10,13,19,21-26` — errata destilada (fonte primária).
- `Source/Core/DataEngine.DriverConnection.pas:672-679` — `NotEof` auto-avança.
- `Source/Drivers/DataEngine.DriverFireDac.pas:392-395,434,460-463,585-589` — bind de txn + `Open` já-aberto + nil-guard (PR #56).
- `Source/Drivers/DataEngine.DriverFireDacTransaction.pas:62-75,108-111` — `'DEFAULT'` compartilhada + `_InTransaction` só `.Active`.
- `Source/Core/DataEngine.FactoryConnection.pas:280-286` — `InTransaction`.
- `Source/Core/Core.Connection.pas:130-136,194-196` — abrir-e-manter (consumidor).
- `Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas:11-12,64` — o gotcha do `NotEof` documentado.
