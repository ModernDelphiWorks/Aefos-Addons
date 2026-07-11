---
type: Playbook
title: DataEngine — Troubleshooting
description: Sintoma → causa-raiz → fix dos erros mais caros do DataEngine — AV no .Open ad-hoc, loop que pula/repete linhas por NotEof, transação 'DEFAULT' compartilhada envenenada, conexão que trava na 2ª request e leitura viva Firebird.
tags: [dataengine, delphi, troubleshooting, debug, firedac, av, transaction]
timestamp: 2026-07-11T00:00:00Z
---

# Troubleshooting

Sintoma → causa-raiz → fix, com a fonte. Regras completas em [../rules.md](../rules.md).

## Loop que PULA ou REPETE linhas ao ler

- **Pula linhas:** você tem `while ADataSet.NotEof do … ADataSet.Next;` — `NotEof`
  **já** chama `Next` internamente, então você anda duas vezes. **Remova o `Next`.**
- **Loop infinito / repete a mesma linha:** você tem `while not ADataSet.Eof do`
  **sem** `Next` — `Eof` NÃO anda. **Adicione o `Next`.**
- **Regra:** `NotEof` sem `Next`, **ou** `not Eof` com `Next` — nunca misture.
- **Onde:** `Source/Core/DataEngine.DriverConnection.pas:672-679` (`FNotEofStarted →
  Next`). Doc da casa: `Source/Shared/Estoque/Shared.Estoque.SnapshotRead.pas:11-12`.
- Ver Regra 1 em [../rules.md](../rules.md) e [../idbdataset.md](../idbdataset.md).

## Access Violation ao chamar `.Open` num dataset de `CreateDataSet`

- **Causa-raiz:** numa leitura autônoma (sem transação compartilhada Active), o
  dataset fica com `Transaction=nil` e o monitor-log do `.Open` dereferenciava
  `FDataSet.Transaction.Name` → *"Read of address 00000008"*.
- **Não é o `CreateDataSet`** — ele já devolve o dataset ABERTO
  (`DriverFireDac.pas:434`); o AV vinha do `.Open` explícito ad-hoc.
- **Fix:** já corrigido no framework (PR #56) — nil-guard emitindo
  `'(no transaction)'` em `Source/Drivers/DataEngine.DriverFireDac.pas:585-589`. Se
  você patchou o driver ou está numa cópia antiga, aplique o mesmo guard (espelha
  `_InternalExecuteQuery:460-463`).
- **Caso real:** ABC / curva-abc (2026-06-21). Ver Regra 2 em [../rules.md](../rules.md).

## Rota Y dá 400 logo depois da rota X (mas Z segue 200; Y sozinha funciona)

- **Causa-raiz:** a transação `'DEFAULT'` compartilhada da `IDBConnection` singleton
  ficou `Active` num read anterior (ex.: associações eager) e nunca foi commitada; o
  próximo read se ligou a ela (`DriverFireDac.pas:392-395`) e falhou no `Open` → 400
  persistente.
- **Confirmação:** `Y` isolada 5× = 200; só falha **depois** de uma rota com eager
  assoc.
- **Fix (framework, pendente):** não deixar reads autônomos herdarem a `'DEFAULT'`
  (guardar o bind por "transação explícita"), ou envolver os reads do Janus em
  StartTransaction/Commit. **NÃO** trocar por Factory por-request (Regra 4).
- **Fonte:** `delphi-dataengine-specialist.md:23`. Ver Regra 3 em
  [../rules.md](../rules.md) e [../idbconnection.md](../idbconnection.md).

## "Só a 1ª request funciona" / servidor trava após poucas requests

- **Causa A (vazamento):** Factory que resolve `IDBConnection` nova por request e não
  libera → cada read vaza uma `TFDConnection` → trava.
- **Causa B (churn):** singleton cuja conexão chega FECHADA — o adapter
  `Connect`/`Disconnect`a e o `Disconnect` FECHA a `TFDConnection`; reads repetidos
  falham (vazio/400).
- **Causa C (nem era conexão):** refcount de singleton no guard do DI.
  **Instrumente ONDE a 2ª request morre antes de culpar a conexão.**
- **Fix single-process:** singleton + abrir 1× e MANTER aberta
  (`FConnection.Connected := True`) — `Source/Core/Core.Connection.pas:130-136`.
- Ver Regra 4 em [../rules.md](../rules.md).

## AV que só aparece sob stress (muitas entidades DISTINTAS na mesma sessão)

- **Sintoma:** `Read of address 00000004` (offset 4) no read-path, CUMULATIVO pelo
  nº de entidades DISTINTAS lidas (~150) na conexão singleton; persiste na sessão.
- **NÃO é** poisoner único, NÃO é contagem bruta (mesma rota N× = ok), NÃO é o
  txn-binding da Regra 3. É um **leak por-entidade-distinta** (RTTI/metadata/cursor)
  ainda não caçado.
- **Estado:** o fix candidato (contador `FExplicitDepth`) foi aplicado e **revertido**
  — não corrigia este AV. Fix real **pendente**.
- **Na prática:** uma request toca poucas entidades → raramente manifesta; é stress
  artificial (smoke de 176 rotas). Ver Regra 5 em [../rules.md](../rules.md)
  (`delphi-dataengine-specialist.md:25`).

## "Out of memory" ao ler VARCHAR acentuado (Firebird)

- **Causa:** falta `CharacterSet=WIN1252` na `TFDConnection` (charset legado BR).
- **Fix:** `FConnection.Params.Add('CharacterSet=WIN1252')`
  (`Source/Core/Core.Connection.pas:118-120`).
- **Nota:** o requisito extra de registrar o gerador **SQLite** para o SELECT do
  Firebird é do **Janus** (camada de cima), não do DataEngine — ver a skill
  `delphi-janus`. Fonte: `delphi-dataengine-specialist.md:19`. Ver
  [../drivers.md](../drivers.md).

## Citations

- `delphi-dataengine-specialist.md:19,22-25` — erratas de campo.
- `Source/Core/DataEngine.DriverConnection.pas:672-679` — `NotEof` auto-avança.
- `Source/Drivers/DataEngine.DriverFireDac.pas:392-395,434,460-463,585-589` — bind de txn + `Open` já-aberto + nil-guard (PR #56).
- `Source/Drivers/DataEngine.DriverFireDacTransaction.pas:62-75,108-111` — `'DEFAULT'` compartilhada.
- `Source/Core/Core.Connection.pas:118-120,130-136` — WIN1252 + abrir-e-manter (consumidor).
