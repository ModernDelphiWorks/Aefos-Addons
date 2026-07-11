---
type: Rules
title: MetaDbDiff — Regras & Erratas
description: Antipadrões e lições aprendidas na marra do MetaDbDiff; cada uma vira uma regra NUNCA/SEMPRE com o caso real citado. LER antes de decorar entidade, ler mapeamento ou rodar um diff.
tags: [metadbdiff, delphi, rules, errata, antipatterns]
timestamp: 2026-07-11T00:00:00Z
---

# Regras & Erratas

Regras destiladas do especialista curado (`delphi-metadbdiff-specialist.md:21-27`)
e do Source. **LER antes de decorar uma entidade, ler o mapeamento por RTTI ou
rodar um diff.** Cada regra carrega o caso REAL que a originou — não a resuma a
ponto de perder o caso.

## SEMPRE — fundamentar em código

- **SEMPRE cite `arquivo:linha`** (Source e/ou uso real). Sem fonte, leia — não
  chute (`delphi-metadbdiff-specialist.md:13`).
- **SEMPRE estude o Source antes de afirmar** — chave em
  `Source\Core\MetaDbDiff.Mapping.Attributes.pas` (atributos),
  `Source\Core\MetaDbDiff.RTTI.Helper.pas` (leitura) e o par
  `Database.Factory`/`Database.Compare` (diff)
  (`delphi-metadbdiff-specialist.md:9-11`).

## Regra 1 — Mapeie ao DDL VIVO, não ao modelo legado assumido (DEC-046)

**Nome, tipo, tamanho e escala de coluna vêm do BANCO REAL, não do modelo legado
assumido.** Colunas inventadas só falham ao ler/comparar ao vivo. Ao decorar uma
entidade de migração, reconcilie cada `[Column]` contra o DDL do banco antes de
confiar (`delphi-metadbdiff-specialist.md:22`). Uso correto: a entidade real
`TA01_FON` documenta no comentário que foi portada verbatim do DDL vivo
(`Source/Modules/A01/A01_Entity.pas:16-23,37`).

## Regra 2 — Método de tipo parametrizado NÃO referencia `const` da implementation (E2506)

**Num método de um tipo genérico (ex.: `TEntityDao<T>`), a seção `interface` não
pode referenciar uma `const` declarada na seção `implementation` — inline o
literal.** Caso real: `TEntityDao<T>` não conseguia usar um `const CTenantColumn`;
a correção foi inlinar `'EMP_FILIAL'` diretamente
(`delphi-metadbdiff-specialist.md:23`). Vale para qualquer código genérico que
consome os helpers RTTI do MetaDbDiff.

## Regra 3 — `[Column]` de precisão/escala seta `Size := Scale`

**No overload `[Column('c', ftFloat, APrecision, AScale)]`, o construtor faz
`FSize := AScale`** (`Source/Core/MetaDbDiff.Mapping.Attributes.pas:642-651`) — ou
seja, `Column.Size` fica igual à **escala**, não à precisão nem ao total. Para
numéricos, use `Precision` e `Scale`; **NUNCA** derive o tamanho total de `Size`
nesse overload. `DeepEqualsColumn` compara `Size` **e** `Precision`
separadamente (`.Database.Factory.pas:114-117`), então isso importa no diff.

## Regra 4 — `[Association]` na prop-objeto; `[ForeignKey]` na coluna FK escalar

**O `[Association]` vai na propriedade-OBJETO (nav: `Tclient`/`TObjectList<>`); o
`[ForeignKey]` vai na coluna FK ESCALAR (`Integer`/`Nullable<>`).** Trocar isso é
o bug clássico que estoura em runtime quando o engine (Janus) instancia a
associação via `AsInstance` num tipo não-classe. O MetaDbDiff só **descreve** os
atributos; quem os exercita é o Janus — o detalhe do `EInvalidCast` e o caso real
(`TB01_F01.B01_BANCO` sistêmico, ~127 ocorrências na migração) estão no addon
**delphi-janus** (rules.md daquele addon). Aqui: derive a multiplicidade da
**cardinalidade da FK** (FK escalar única ⇒ `OneToOne`), não copie o `[Association]`
legado cegamente.

## Regra 5 — Registre TODAS as entidades antes do primeiro diff (registro é consumido 1×)

**`TRegisterClass.GetAllEntityClass` ESVAZIA a lista após devolvê-la**
(`finally FEntitys.Clear;`, `Source/Core/MetaDbDiff.Mapping.Register.pas:71-82`), e
`TMappingExplorer.GetRepositoryMapping` constrói o repositório **uma vez** e o
cacheia (`Source/Core/MetaDbDiff.Mapping.Explorer.pas:433-439`). Consequência:
todas as `RegisterEntity` (nos `initialization` das units) precisam ter rodado
**antes** do primeiro acesso ao repositório/diff; registrar depois não entra.
Garanta que as units das entidades estão no `uses` do projeto.

## Regra 6 — Inclua a unit do dialeto no `uses` (driver não registrado)

**Cada gerador de DDL só existe no `TSQLDriverRegister` se a unit
`MetaDbDiff.DDL.Generator.<Dialeto>` estiver no `uses`.** Sem ela, `GetDriver`
levanta exceção explícita mandando adicionar a unit
(`Source/Core/MetaDbDiff.DDL.Register.pas:69-72`). Adicione o gerador do seu banco
(ex.: `MetaDbDiff.DDL.Generator.Firebird`) — e, se for extrair metadata daquele
banco, também o extrator `MetaDbDiff.Metadata.<Dialeto>`.

## Regra 7 — O facade do README (`TMetaDbComparer`) ainda não existe nesta cópia

**Não code contra `TMetaDbComparer`/`IMetaDbComparer`/`IMetaDbDelta`/
`CompareModelToDatabase`/`GenerateDDLScript` sem confirmar** — essas units
(`MetaDbDiff.Comparer`, `MetaDbDiff.Interfaces`) **não estão** no `Source` desta
cópia (`README.md:66-114` documenta a API pretendida). O caminho real e presente é
`TDatabaseCompare` + `BuildDatabase` + `GetCommandList` + `CommandsAutoExecute`
(ver [api.md](api.md)). É um TODO para a equipe do framework (ver abaixo).

## Regra 8 — `CommandsAutoExecute` default TRUE aplica no banco

**`TDatabaseCompare` nasce com `CommandsAutoExecute=True`**
(`Source/Core/MetaDbDiff.Database.Abstract.pas:77`), então `BuildDatabase`
**aplica** o DDL no Target dentro de uma transação
(`Source/Core/MetaDbDiff.Database.Compare.pas:84-99`). Se você só quer **inspecionar
o script**, ponha `CommandsAutoExecute := False` antes de `BuildDatabase` e leia
`GetCommandList` — senão você migra o banco sem querer.

## Regra 9 — SQLite não cria FK ao criar tabela nova

**Ao gerar uma tabela nova, as FKs não são emitidas separadamente para SQLite**
(`if FDriverName <> dnSQLite`, `Source/Core/MetaDbDiff.Database.Factory.pas:418-420`),
porque o SQLite declara FK inline no `CREATE TABLE`. Não espere um
`ALTER TABLE … ADD FOREIGN KEY` avulso nesse dialeto.

## Regra 10 — `Description` de coluna/FK/índice NÃO entra no diff

**Diferenças só de `Description` não geram DDL** — as comparações de description
estão comentadas em `DeepEqualsColumn` (`:130-131`), `DeepEqualsForeignKey`
(`:150-151`) e `DeepEqualsIndexe` (`:159-160`). Se você mudou só o comentário/
descrição no modelo, o comparer não vai emitir `ALTER` — é esperado.

## TODOs / lacunas para a equipe do framework

- **Facade do README ausente:** confirmar se `MetaDbDiff.Comparer`
  (`TMetaDbComparer`/`IMetaDbComparer`/`IMetaDbDelta`) é roadmap, foi removido, ou
  vive noutra branch. Enquanto isso, a doc aponta para `TDatabaseCompare`.
- **Triggers/views parciais:** vários ramos de `CompareTriggers`/`ActionCreateTrigger`
  estão comentados (`.Database.Factory.pas:256-278`); pedir à equipe o estado
  suportado de triggers por dialeto + um Example de migração ponta a ponta
  (o `Test Delphi/Test.MetaDbDiff.pas` é um stub vazio, `:37-43`).
- **Errata viva:** a seção 3 da errata do especialista está aberta para novos
  casos (`delphi-metadbdiff-specialist.md:24`) — realimente ao aprender na marra.

## Citations

- `delphi-metadbdiff-specialist.md:21-27` — errata destilada (fonte primária).
- `Source/Core/MetaDbDiff.Mapping.Attributes.pas:642-651` — `Size := Scale`.
- `Source/Core/MetaDbDiff.Mapping.Register.pas:71-82` — registro consumido 1×.
- `Source/Core/MetaDbDiff.Mapping.Explorer.pas:433-439` — repositório cacheado.
- `Source/Core/MetaDbDiff.DDL.Register.pas:69-72` — driver não registrado.
- `Source/Core/MetaDbDiff.Database.Abstract.pas:77` · `Database.Compare.pas:84-99` — auto-execute.
- `Source/Core/MetaDbDiff.Database.Factory.pas:114-117,130-131,150-151,159-160,418-420` — regras de igualdade e SQLite.
- `README.md:66-114` — facade documentado (ausente no Source atual).
