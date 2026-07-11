---
type: Rules
title: Janus ORM — Regras & Erratas
description: Antipadrões e lições aprendidas na marra do Janus; cada uma vira uma regra NUNCA/SEMPRE com o caso real citado. LER antes de decorar ou depurar.
tags: [janus, orm, delphi, rules, errata, antipatterns]
timestamp: 2026-07-11T00:00:00Z
---

# Regras & Erratas

Regras destiladas do especialista curado (`delphi-janus-specialist.md:29-36`) e do
Source. **LER antes de decorar um modelo ou depurar uma leitura.** Cada regra
carrega o caso REAL que a originou — não a resuma a ponto de perder o caso.

## SEMPRE — fundamentar em código

- **SEMPRE cite `arquivo:linha`** (Examples e/ou Source). Sem fonte, leia — não
  chute (`delphi-janus-specialist.md:14`).
- **SEMPRE estude `.modules\Janus\Examples` ANTES de decorar** um modelo.
  Transcreva `[Association]`/`[ForeignKey]`/`[CascadeActions]`/`[JoinColumn]` do
  legado **verbatim**; não invente multiplicidade
  (`delphi-janus-specialist.md:32`).
- **SEMPRE reconcilie as colunas ao DDL VIVO** (DEC-046). O modelo legado (ORMBr)
  costuma divergir do banco real (`delphi-janus-specialist.md:27`).

## Regra 1 — HANG/AV em leitura ⇒ suspeite de cursor sem `.Next`

**Ao investigar HANG/AV/"Out of memory" não-determinístico ao popular objetos,
suspeite SEMPRE de cursor não avançado ANTES de qualquer outra coisa.** O padrão
é `while not ResultSet.Eof do … ` sem `ResultSet.Next` no fim → loop infinito
que repopula a mesma linha até esgotar a heap.

Caso real: o Janus teve 3 desses bugs, hoje corrigidos:
- `PopularObjectSet` (Janus #199) — hoje com `ADBResultSet.Next` no fim do laço
  (`Source/Core/Janus.Session.Abstract.pas:381`; comentário explicando em 379-380).
- `ExecuteOneToOne` (Janus #200) — `LResultSet.Next`
  (`Source/Core/Janus.Command.Executor.pas:347`).
- `ExecuteOneToMany` (Janus #200) — `LResultSet.Next`
  (`Source/Core/Janus.Command.Executor.pas:385`).

Lookups **sem** associação não exercitam `ExecuteOneToOne/Many` — só entidades
**com** `[Association]` disparam esse caminho
(`delphi-janus-specialist.md:30`).

## Regra 2 — PK composta É suportada (o limite está na camada de cima)

**NUNCA conclua "o Janus não suporta PK composta".** É nativo: declare múltiplas
`[PrimaryKey]` e componha o WHERE por todas as colunas. Ex.:
`[PrimaryKey('detail_id; master_id', 'Chave primária')]`
(`Examples/Delphi/RESTful/Horse/models/Janus.Model.Detail.pas:41`). O limite
costuma estar no genérico acima que assume UMA coluna — corrija lá, não no Janus
(`delphi-janus-specialist.md:31`).

## Regra 3 — Multiplicidade vem da FK, não do `[Association]` legado

FK escalar única ⇒ **`OneToOne` + objeto único** (`Tclient`), não `TObjectList<>`.
`OneToMany` só quando o lado remoto tem muitos por um. Derive a multiplicidade da
cardinalidade da FK; não copie o legado cegamente
(`delphi-janus-specialist.md:32`). Ver [associations.md](associations.md).

## Regra 4 — Patches no `.modules\Janus`

Ao corrigir o próprio framework: **branch dedicada no repo do frw + backup
pristino + PR no final** (várias equipes editam em paralelo). O projeto
consumidor **NUNCA** commita `.modules` (`delphi-janus-specialist.md:33`).

## Regra 5 — Conexão compartilhada: mantenha ABERTA (não use Factory por-request)

**NUNCA troque cegamente uma conexão compartilhada por `Bind<TConn>.Factory`.**

- O adapter do objectset (`Janus.ObjectSet.Adapter`) só `Connect`/`Disconnect`a
  uma conexão que chegou **DESCONECTADA**, e o `Disconnect` **FECHA** fisicamente
  a `TFDConnection`. Com singleton fechada, o churn connect/disconnect por-read
  intermitentemente falha um read repetido (vazio/400).
- `Bind<TConn>.Factory` **NÃO** resolve: cria instância nova por resolve mas NÃO
  a libera → cada read **VAZA** uma `TFDConnection` → o servidor TRAVA em poucas
  requests.

**Fix p/ servidor single-process:** Singleton + abrir 1× e MANTER aberta
(`FConnection.Connected := True` no `_Initialize`). No Example, o data module abre
no create (`Examples/.../providers/DM.Connection.pas:54`).

Caso real (DFeFw 2026-06-21): a 1ª recomendação foi Factory → vazou e travou; o
certo foi singleton-aberto. E grande parte do "só a 1ª request funciona" nem era
conexão — era refcount de `SingletonInterface` no guard (Nidus errata #8). **SEMPRE
instrumente ONDE a 2ª request morre antes de culpar a conexão**
(`delphi-janus-specialist.md:34`).

## Regra 6 — `EInvalidCast` no `FindWhere` ⇒ `[Association]` na propriedade errada

**`EInvalidCast: Invalid class typecast` dentro do `FindWhere` numa entidade com
`[Association]` = o `[Association]`/`[ForeignKey]` está MAL-POSTO na propriedade
da COLUNA FK ESCALAR em vez da propriedade NAV (objeto / `TObjectList<>`).**

Por quê: `ExecuteOneToOne`/`ExecuteOneToMany` chamam
`AProperty.PropertyType.AsInstance.MetaclassType`
(`Source/Core/Janus.Command.Executor.pas:328` e `:373`) — que lança `EInvalidCast`
num tipo não-classe (`string`/`Integer`/`Nullable<>`). Entidades SEM associação
não entram em `FillAssociation` (por isso single-PK sem assoc lê normal). **A PK
composta é red herring** — a correlação é só que a entidade que falha é a que tem
associação viva.

**Fix na ENTIDADE (não patch Janus):** mover `[Association]`+`[ForeignKey]` da
prop escalar para a prop-objeto. Todo Example põe na prop-objeto; a FK escalar é
só `[Column]` (ver `.../Janus.Model.Master.pas:91-111`: FK em `client_id`,
`[Association]` em `client: Tclient`).

Caso real (DFeFw 2026-06-21): `TB01_F01.B01_BANCO:string` tinha o `[Association]`
→ EInvalidCast; mover para `B01_FON:TB01_FON` resolveu, composite CRUD verde.
**É SISTÊMICO:** ~127 `[Association]` em escalares na migração legada
(A23/C01/C02/C03/CTB/E01×/E13/E17/E21…), todas com a nav-prop já existente → MOVER
para ela; atualizar os shape-tests que afirmam a posição antiga
(`delphi-janus-specialist.md:36`).

## Regra 7 — JSON avulso ⇒ JsonFlow, não TJanusJson

`TJanusJson` é para objeto ⇄ JSON dentro do ORM. Para JSON avulso (fora do ORM),
o ecossistema usa **JsonFlow** (`delphi-janus-specialist.md:20`).

## Citations

- `delphi-janus-specialist.md:29-36` — errata destilada (fonte primária destas regras).
- `Source/Core/Janus.Session.Abstract.pas:373-388` — .Next em PopularObjectSet.
- `Source/Core/Janus.Command.Executor.pas:319-352,354-387` — .Next + AsInstance em associações.
- `Examples/Delphi/RESTful/Horse/models/Janus.Model.Master.pas:91-118` — associação na prop-objeto.
- `Examples/Delphi/RESTful/Horse/models/Janus.Model.Detail.pas:41` — PK composta.
