---
type: Playbook
title: Janus ORM — Troubleshooting
description: Diagnóstico e correção dos erros mais caros do Janus — HANG/AV por cursor, EInvalidCast por associação mal-posta, live-read Firebird e conexão que trava na 2ª request.
tags: [janus, orm, delphi, troubleshooting, debug, firebird]
timestamp: 2026-07-11T00:00:00Z
---

# Troubleshooting

Sintoma → causa-raiz → fix, com a fonte. Regras completas em [../rules.md](../rules.md).

## HANG / AV / "Out of memory" não-determinístico ao ler ou popular objetos

- **Causa provável nº 1:** cursor não avançado (`while not ResultSet.Eof` sem
  `ResultSet.Next`) → repopula a mesma linha até estourar a heap. **Suspeite disso
  ANTES de tudo.**
- **Onde:** já corrigido no Janus em `PopularObjectSet`
  (`Source/Core/Janus.Session.Abstract.pas:381`), `ExecuteOneToOne`
  (`Source/Core/Janus.Command.Executor.pas:347`) e `ExecuteOneToMany`
  (`…Executor.pas:385`). Se você patchou o Janus ou tem um laço próprio, confirme
  o `.Next` no fim.
- **Pista:** só entidades com `[Association]` exercitam `ExecuteOneToOne/Many`;
  lookups simples não. Se o hang só ocorre em entidade associada, é aqui.
- Fonte: `delphi-janus-specialist.md:30`.

## `EInvalidCast: Invalid class typecast` dentro do `FindWhere`

- **Causa-raiz:** `[Association]`/`[ForeignKey]` posto na propriedade da **coluna
  FK escalar** (`string`/`Integer`/`Nullable<>`) em vez da propriedade **objeto**
  (nav). `ExecuteOneToOne/Many` chamam `PropertyType.AsInstance.MetaclassType`
  (`…Executor.pas:328`, `:373`), que estoura num tipo não-classe.
- **NÃO é a PK composta** — red herring; a correlação é só que a entidade que
  falha tem associação viva.
- **Fix (na entidade, não no Janus):** mover `[Association]`+`[ForeignKey]` para a
  prop-objeto; deixar a FK escalar só com `[Column]`. Padrão correto em
  `Examples/.../models/Janus.Model.Master.pas:91-111`.
- **Caso real:** `TB01_F01.B01_BANCO:string` tinha o `[Association]` → mover para
  `B01_FON:TB01_FON` resolveu. Sistêmico: ~127 ocorrências na migração legada.
- Fonte: `delphi-janus-specialist.md:36`. Ver Regra 6 em [../rules.md](../rules.md).

## Leitura viva Firebird falha (AV logo no SELECT, ou "Out of memory" com acento)

- **AV no primeiro SELECT:** falta registrar o gerador **SQLite**. O SELECT do
  Firebird remapeia para o gerador SQLite — inclua `Janus.DML.Generator.SQLite`
  no `uses` da conexão, além do Firebird.
- **"Out of memory" em string acentuada:** a conexão precisa de
  `CharacterSet=WIN1252` (charset legado do DB BR).
- **Colunas inexistentes / read vazio inesperado:** a entidade (vinda do modelo
  legado ORMBr) diverge do DDL vivo — reconcilie ao banco real.
- Fonte: `delphi-janus-specialist.md:24-27`. Detalhes em [../dialects.md](../dialects.md).

## "Só a 1ª request funciona" / servidor trava após poucas requests

- **Causa A (vazamento):** usar `Bind<TConn>.Factory` por-request — cria conexão
  nova por resolve e não libera → cada read vaza uma `TFDConnection` → trava.
- **Causa B (churn):** singleton com conexão que chega FECHADA — o adapter
  `Connect`/`Disconnect`a e o `Disconnect` FECHA a `TFDConnection`; reads
  repetidos falham (vazio/400).
- **Causa C (nem era conexão):** refcount de `SingletonInterface` no guard (Nidus
  errata #8). **Instrumente ONDE a 2ª request morre antes de culpar a conexão.**
- **Fix single-process:** Singleton + abrir 1× e MANTER aberta
  (`FConnection.Connected := True`). Ref: `DM.Connection.pas:54`.
- Fonte: `delphi-janus-specialist.md:34`. Ver Regra 5 em [../rules.md](../rules.md).

## `NextPacket` retorna vazio / falha

- `NextPacket` **NÃO** auto-conecta (ao contrário de `Find`/`FindWhere`). A
  conexão precisa já estar aberta. Fonte: `delphi-janus-specialist.md:19`;
  contrato em `Source/Objectset/Janus.Container.ObjectSet.Interfaces.pas:42-45`.

## "O Janus não suporta PK composta"

- Falso. É nativo (`Janus.Model.Detail.pas:41`). O limite está no genérico acima
  que assume UMA coluna — componha o WHERE por todas as `[PrimaryKey]`. Fonte:
  `delphi-janus-specialist.md:31`.

## Citations

- `delphi-janus-specialist.md:19,24-27,30,31,34,36` — erratas de campo.
- `Source/Core/Janus.Session.Abstract.pas:381`; `Source/Core/Janus.Command.Executor.pas:328,347,373,385`.
- `Examples/.../models/Janus.Model.Master.pas:91-111`; `Janus.Model.Detail.pas:41`.
- `Source/Objectset/Janus.Container.ObjectSet.Interfaces.pas:42-45`.
