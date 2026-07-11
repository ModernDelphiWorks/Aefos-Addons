---
type: Framework Overview
title: MetaDbDiff — Visão Geral
description: O que é o MetaDbDiff, sua arquitetura (atributos → RTTI → catálogo → diff → DDL), a relação com o Janus e o DataEngine, fontes da verdade e quando usar.
tags: [metadbdiff, delphi, orm, mapping, rtti, schema-diff, ddl, overview]
timestamp: 2026-07-11T00:00:00Z
---

# MetaDbDiff — Visão Geral

O **MetaDbDiff** é um motor Delphi/Lazarus de **comparação de metadados de banco
e geração de scripts de migração DDL**, autor **Isaque Pinheiro**
(ModernDelphiWorks), licença MIT (`Source/Core/MetaDbDiff.Mapping.Attributes.pas:1-11`).
Ele carrega três responsabilidades que se encadeiam:

1. **Atributos de mapeamento ORM** — decorators Delphi que descrevem tabela,
   colunas, chaves, índices, associações, etc. sobre classes comuns
   (`Source/Core/MetaDbDiff.Mapping.Attributes.pas`).
2. **RTTI que lê esse mapeamento** — helpers de `TRttiProperty`/`TRttiType` que
   extraem os atributos em tempo de execução
   (`Source/Core/MetaDbDiff.RTTI.Helper.pas`).
3. **Diff + geração de DDL** — compara um **modelo Pascal** contra um **banco
   vivo** (ou dois bancos entre si) e emite `CREATE/DROP/ALTER` cirúrgico por
   dialeto (`Source/Core/MetaDbDiff.Database.Compare.pas`,
   `Source/Core/MetaDbDiff.Database.Factory.pas`, `Source/Drivers/*`).

## Arquitetura em uma frase

Classe decorada → `TRegisterClass.RegisterEntity` → `TMappingExplorer` lê os
atributos via RTTI e monta um **catálogo** (`TCatalogMetadataMIK`) → o mesmo
catálogo é extraído do **banco vivo** via `IDBConnection` (DataEngine) → o
comparer confronta os dois catálogos e gera comandos DDL → o **gerador do
dialeto** serializa cada comando em SQL.

```
Classe decorada  ──▶  TRegisterClass  ──▶  TMappingExplorer (RTTI)  ──▶  Catálogo (modelo)
   [Table]/[Column]      registro           lê os atributos                     │
   [PrimaryKey]/…                                                               ▼
                                                                       TDatabaseCompare
Banco vivo  ──▶  IDBConnection (DataEngine)  ──▶  Metadata.<Dialeto>  ──▶  Catálogo (banco)
                                                                               │
                                                                               ▼
                                                            DDL cirúrgica por TSQLDriverRegister
                                                          (Firebird/PostgreSQL/MySQL/Oracle/…)
```

O motor **não** fala com o driver diretamente: ele fala com o **DataEngine**
(`IDBConnection`, `TDriverName`), que envolve FireDAC/etc. — a `TDatabaseCompare`
recebe as conexões já abstraídas
(`Source/Core/MetaDbDiff.Database.Compare.pas:53-68`).

## Relação com o Janus (fundação, não duplicação)

O MetaDbDiff é **standalone** — compila sem o Janus (é o Janus que depende dele,
`delphi-metadbdiff-specialist.md:19`). Os atributos que uma entidade Janus usa
(`[Entity]`, `[Table]`, `[Column]`, `[PrimaryKey]`, `[Association]`, `[JoinColumn]`,
`[CascadeActions]`…) são **declarados aqui**, na unit
`MetaDbDiff.Mapping.Attributes` — por isso as entidades do projeto colocam essa
unit no `uses` (`Source/Modules/A01/A01_Entity.pas:10`). O Janus **consome** esse
mapeamento (via os mesmos helpers RTTI) para gerar DML e materializar objetos.

- **Este addon** cobre: o significado e a assinatura de cada atributo, como ler o
  mapeamento por RTTI e como comparar/migrar schema (DDL).
- **O addon delphi-janus** cobre: CRUD genérico, associações em runtime, JSON e
  leitura viva. Não repita aqui o que é runtime do Janus.

## Camadas do Source (para investigar)

- **Mapping** (`Source/Core/MetaDbDiff.Mapping.*`): os atributos
  (`.Attributes.pas`), as exceções (`.Exceptions.pas`), as classes de mapeamento
  materializado (`.Classes.pas`), o **explorer** cacheado (`.Explorer.pas`), o
  **popular** que traduz RTTI→mapeamento (`.Popular.pas`), o registro global
  (`.Register.pas`) e o repositório (`.Repository.pas`).
- **RTTI** (`Source/Core/MetaDbDiff.RTTI.Helper.pas`): os class helpers que leem
  os atributos. Ver [rtti-helpers.md](rtti-helpers.md).
- **Types** (`Source/Core/MetaDbDiff.Types.Mapping.pas`): os enums de domínio
  (`TMultiplicity`, `TRuleAction`, `TRestriction`, `TCascadeAction`,
  `TGeneratorType`, `TJoin`, `TSortingOrder`, `TEnumType`) — linhas 28-59.
- **Database** (`Source/Core/MetaDbDiff.Database.*`): `TDatabaseAbstract` (base +
  propriedades), `TDatabaseFactory` (algoritmo de comparação), `TDatabaseCompare`
  (comparação banco↔banco), `.Mapping.pas` (as classes `*MIK` do catálogo).
- **DDL** (`Source/Core/MetaDbDiff.DDL.*`): `.Commands.pas` (comandos DDL),
  `.Generator.pas` (gerador abstrato), `.Register.pas` (singleton de drivers),
  `.Interfaces.pas`.
- **Metadata** (`Source/Core/MetaDbDiff.Metadata.*`): extração do catálogo
  (`.Extract.pas`, `.DB.Factory.pas`, `.Register.pas`).
- **Drivers** (`Source/Drivers/*`): um par **gerador de DDL** + **extrator de
  metadata** por dialeto — Firebird, Firebird3, Interbase, MSSQL, MySQL, Oracle,
  PostgreSQL, SQLite, AbsoluteDB — mais `MetaDbDiff.Metadata.Model.pas` (extrai o
  catálogo do lado do **modelo**). Ver [schema-diff.md](schema-diff.md).

## Fontes da verdade (estude ANTES de afirmar)

1. **Source do framework** — `.modules\MetaDbDiff\Source` (`Core\` + `Drivers\`).
   As units-chave estão acima.
2. **Uso real** — as entidades do projeto que decoram com estes atributos, ex.
   `Source\Modules\A01\A01_Entity.pas` (mapeamento verbatim ao DDL vivo,
   registro no `initialization`).
3. **README do framework** — `.modules\MetaDbDiff\README.md` (visão, matriz de
   compatibilidade, quick-start). ⚠️ o quick-start do README usa um **facade**
   (`TMetaDbComparer`) que **não existe** nesta cópia do Source — ver
   [api.md](api.md) e [rules.md](rules.md).

## Quando usar

- Precisa **descrever** uma entidade Delphi para um ORM/engine relacional →
  decore com os atributos daqui (`delphi-metadbdiff-specialist.md:16`).
- Precisa **ler** o mapeamento em código (metaprogramação, geradores, DAOs
  genéricos) → use os helpers RTTI (`GetColumn`, `GetPrimaryKey`, `IsNullable`…)
  (`delphi-metadbdiff-specialist.md:17`).
- Precisa **sincronizar** um schema: aplicar mudanças de modelo ao banco, ou
  comparar dois bancos e gerar o script de migração → use o comparer
  (`README.md:19-31`).

## Quando NÃO usar / limites

- CRUD, associações em runtime, JSON e leitura viva **não** são deste framework —
  são do **Janus** (addon delphi-janus).
- O MetaDbDiff não executa SQL por conta própria fora do fluxo do comparer; ele
  gera o texto do DDL e (opcionalmente) o aplica pela `IDBConnection` do
  DataEngine (`Source/Core/MetaDbDiff.Database.Compare.pas:78-113`).

## Citations

- `Source/Core/MetaDbDiff.Mapping.Attributes.pas:1-11,49-487` — atributos e licença.
- `Source/Core/MetaDbDiff.RTTI.Helper.pas:55-118` — helpers RTTI.
- `Source/Core/MetaDbDiff.Types.Mapping.pas:28-59` — enums de domínio.
- `Source/Core/MetaDbDiff.Database.Compare.pas:53-122` — comparação banco↔banco.
- `Source/Drivers/MetaDbDiff.Metadata.Model.pas:20-115` — extração do catálogo do modelo.
- `Source/Modules/A01/A01_Entity.pas:10,24-58` — uso real dos atributos.
- `README.md:19-31,120-132` — visão e recursos.
- `delphi-metadbdiff-specialist.md:7-19` — fontes da verdade e conhecimento essencial.
