---
type: Reference
title: Colligo — Provider SQL (IColligoQueryable<T>)
description: O lado banco de dados do Colligo — IColligoQueryable<T> sobre FluentSQL + DataEngine, atrás de {$IFDEF QUERYABLE}, e por que os providers JSON/XML ainda são stubs.
tags: [colligo, delphi, queryable, sql, fluentsql, dataengine, provider]
timestamp: 2026-07-11T00:00:00Z
---

# Provider SQL — `IColligoQueryable<T>`

Além do LINQ-to-Objects em memória, o Colligo tem um **provider SQL** que traduz
uma cadeia fluente em SQL e materializa contra um banco: o record
`IColligoQueryable<T>`, em `Source/Colligo.Queryable.pas`. É análogo ao
`IQueryable<T>` do C# (query builder + execução), **distinto** do
`IColligoEnumerable<T>` (memória).

> **Confirme o suporte antes de afirmar.** Não emita SQL pelo Colligo a menos que
> use explicitamente este provider — o data-access da casa é Janus → DataEngine
> (`delphi-colligo-specialist.md:21`, `:28`).

## Dependências e feature-define

`IColligoQueryable<T>` está **atrás de `{$IFDEF QUERYABLE}`**
(`Source/Colligo.Queryable.pas:353`) e depende de:

- **FluentSQL** — `FluentSQL.Interfaces/Expression/Utils/Name`
  (`Source/Colligo.Queryable.pas:29-32`); é o AST de SQL por dialeto.
- **DataEngine** — `DataEngine.FactoryInterfaces` (`IDBConnection`,
  `IDBDataSet`, `TDriverName`) (`:33`, `:56-61`).
- **ModernSyntax** — `ModernSyntax.Tuple` na implementação (`:340`).

Ou seja: sem o define e sem essas libs no path, só o lado in-memory compila. Isso
casa com a "regra da casa" — Colligo cobre coleções; o provider SQL é opcional.

## Entrada (factory) e materialização

Você cria a partir de um inicializador de conexão (dialeto + `IDBConnection`):

```pascal
uses Colligo, Colligo.Queryable, DataEngine.FactoryFireDac;

FQueryable := IColligoQueryable<String>.CreateForDatabase(
  procedure(var ADatabase: TDriverName; var AConnection: IDBConnection)
  begin
    ADatabase   := TDriverName.dnFirebird;
    AConnection := TFactoryFireDAC.Create(FFDConnection, TDriverName.dnFirebird);
  end);
```
Fonte: `Test Delphi/UTestColligo.FluentSQL.pas:172-178`;
construtores em `Source/Colligo.Queryable.pas:363-376`.

Depois encadeia o builder e materializa/inspeciona:

```pascal
FQueryable.Select('*').From('CLIENTES');
S := FQueryable.AsString;   // 'SELECT * FROM CLIENTES'
```
Fonte: `Test Delphi/UTestColligo.FluentSQL.pas:190-191`.

## Métodos do builder (`IColligoQueryable<T>`)

`Source/Colligo.Queryable.pas:212-309`. Principais:

- **Fonte/projeção:** `From(tabela [,alias])`, `Select(colunas)` /
  `Select(TArray<IColligoQueryExpression>)`, `Distinct`, `Alias`.
- **Filtro:** `Where(string)` / `Where(array of const)` /
  `Where(IColligoQueryExpression)`, `AndOpe`, `OrOpe`.
- **Junção:** `InnerJoin(tabela [,alias])`, `OnCond(expr)`.
- **Agrupamento/ordenação:** `GroupBy(coluna)` / `GroupBy<TKey>(expr)`,
  `OrderBy(coluna)` / `OrderByDesc`, `ThenBy` / `ThenByDescending`.
- **Paginação:** `Take(n)`, `Skip(n)`.
- **Conjunto:** `Union`, `Intersect`, `Exclude`, `Join<TInner,TResult>`.
- **Terminais:** `ToArray`, `ToList`, `AsString` (o SQL gerado), agregações
  `Count`/`Min`/`Max`/`Sum<TResult>`/`Average<TResult>`, `First`/`FirstOrDefault`,
  `Last`, `Single`, `ElementAt`, `Any`/`All`.

Exemplos verificados (SQL exato gerado):

```pascal
From('CLIENTES').Where('NOME > ''Ana''').Select('*')
  => 'SELECT * FROM CLIENTES WHERE NOME > ''Ana'''        // :209-210
Select('*').From('CLIENTES').InnerJoin('PEDIDOS','P').OnCond('CLIENTES.ID = P.ID_CLIENTE')
  => 'SELECT * FROM CLIENTES INNER JOIN PEDIDOS AS P ON CLIENTES.ID = P.ID_CLIENTE' // :307-309
Select('COUNT(*)').From('PEDIDOS').GroupBy('CLIENTE_ID')
  => 'SELECT COUNT(*) FROM PEDIDOS GROUP BY CLIENTE_ID'   // :314-316
From('CLIENTES').Select('*').OrderBy('NOME')
  => 'SELECT * FROM CLIENTES ORDER BY NOME ASC'           // :321-323
```
Fonte: `Test Delphi/UTestColligo.FluentSQL.pas:190-323`.

> **A ordem de chamada não fixa a ordem do SQL:** `From` antes de `Select` ou
> `Select` antes de `Where` geram o mesmo SQL canônico (o AST reordena) —
> `Test Delphi/UTestColligo.FluentSQL.pas:293-302`.

## Materialização em objetos

Ao consumir, `TDataSetEnumerator<T>` lê cada linha do `IDBDataSet` e a projeta em
`T` (`Source/Colligo.Queryable.pas:318-330`). Dialetos suportados são os
`dbn*` reexportados do FluentSQL (`:39-53`).

## Providers JSON/XML — NÃO existem ainda (stubs)

`Source/Colligo.Json.pas` e `Colligo.Json.Provider.pas` são **stubs vazios** —
o skeleton `IColligoJsonProvider<T>` / `IColligoJsonEnumerable<T>` (sem
implementação) fica só em `Source/Colligo.Json.pas:20-31`; a unit
`Colligo.Json.Provider.pas` está **totalmente vazia** (só `interface`/`implementation`,
sem tipos — `:16-22`).
O mesmo para XML (`Colligo.Xml.pas:20-31`, `Colligo.Xml.Provider.pas`). Apesar de
o README anunciar "JSON datasets and XML documents" nos format providers
(`README.md:38`, `:150`), **isso ainda não está implementado no Source**. Para
JSON avulso o ecossistema usa **JsonFlow**. Ver Regra 6 em [rules.md](rules.md).

## Citations

- `Source/Colligo.Queryable.pas:29-61` — deps FluentSQL/DataEngine + tipos reexportados.
- `Source/Colligo.Queryable.pas:69-188` — `IColligoQueryProvider<T>` (SQL builder).
- `Source/Colligo.Queryable.pas:212-309` — `IColligoQueryable<T>` (record + métodos).
- `Source/Colligo.Queryable.pas:318-330` — `TDataSetEnumerator<T>` (linha→objeto).
- `Source/Colligo.Queryable.pas:353,363-376` — `{$IFDEF QUERYABLE}` + `CreateForDatabase`.
- `Test Delphi/UTestColligo.FluentSQL.pas:172-323` — uso e SQL gerado verificado.
- `Source/Colligo.Json.pas:20-31`, `Colligo.Xml.pas:20-31` — providers stub.
- `README.md:38,150` — anúncio de format providers (ainda não implementado).
- `delphi-colligo-specialist.md:21,28` — confirmar suporte; regra da casa.
