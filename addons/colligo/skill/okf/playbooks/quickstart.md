---
type: Playbook
title: Colligo — Quickstart
description: Do array cru a um pipeline filtrar → mapear → ordenar → paginar → materializar, seguindo os exemplos canônicos do README e dos testes.
tags: [colligo, linq, delphi, quickstart, pipeline]
timestamp: 2026-07-11T00:00:00Z
---

# Quickstart — do array a um pipeline materializado

Baseado no `README.md` (exemplos canônicos) e nos testes DUnitX. Cada passo cita
a fonte.

## 1. `uses` mínimos

```pascal
uses
  System.SysUtils,
  Colligo,               // o record IColligoEnumerable<T> e os operadores
  Colligo.Collections;   // as factories TColligoArray / TColligoList
```
Fonte: `README.md:72-75`.

## 2. Entre na cadeia por uma factory

```pascal
var LNumbers: TArray<Integer>;
LNumbers := [1,2,3,4,5,6,7,8,9,10];

// de um TArray<T>:
TColligoArray.From<Integer>(LNumbers)           // Source/Colligo.Collections.pas:288
// ou de um TList<T> / TArray<T>:
TColligoList<TUser>.From(MyList)                 // Source/Colligo.Collections.pas:762
// ou gere do zero:
TColligo.Range(1, 10)                            // 1..10  (Source/Colligo.pas:457)
```

## 3. Encadeie operadores (tudo deferido)

```pascal
LResult := TColligoArray.From<Integer>(LNumbers)
  .Where(
    function(const X: Integer): Boolean
    begin
      Result := (X mod 2 = 0);                   // pares
    end)
  .Take(3)                                        // os 3 primeiros que casam
  .Select<string>(                                // genérico explícito!
    function(const X: Integer): string
    begin
      Result := 'Number ' + IntToStr(X);
    end)
  .ToArray                                        // AQUI executa
  .ArrayData;                                     // TArray<string>
// LResult = ['Number 2', 'Number 4', 'Number 6']
```
Fonte: `README.md:84-100`. Note: `Where` (não `Filter`), `Select<string>` com o
tipo explícito, e a materialização só no `.ToArray`.

## 4. Ordenar + paginar (Skip/Take)

```pascal
LResult := TColligoList<TUser>.From(MyCollection)
  .OrderBy(
    function(const A, B: TUser): Integer
    begin
      Result := CompareText(A.Name, B.Name);      // comparador, não key-selector
    end)
  .Skip(10)                                        // paginação: pula 10
  .Take(5)                                         // pega os 5 seguintes
  .Select<string>(
    function(const U: TUser): string
    begin
      Result := U.Email;
    end)
  .ToArray
  .ArrayData;
```
Fonte: `README.md:105-124`.

## 5. Agregar, agrupar e materializar em coleção

```pascal
// soma (cuidado com overflow em Integer — ver troubleshooting)
LTotal := TColligoArray.From<TItem>(Itens).Sum(
  function(const I: TItem): Double begin Result := I.Valor; end);

// contar / existir
if TColligoArray.From<Integer>([1,2,3]).Any(...) then ...

// agrupar por chave
LGroups := TColligoArray.From<Integer>([1,2,3,4,5,6]).GroupBy<Integer>(
  function(Value: Integer): Integer begin Result := Value mod 2; end);
LEnum := LGroups.GetEnumerator;
while LEnum.MoveNext do
begin
  LGroup := LEnum.Current;                         // IGrouping<TKey,T>
  LArray := LGroup.Items.ToArray;                  // itens do grupo
end;

// materializar em lista Colligo
LList := TColligoArray.From<Integer>([1,2,3]).Where(...).ToList;
```
Fontes: `Test Delphi/UTestColligo.ArrayStatic.pas:541-567` (Where/Take/Skip),
`:609-623` (Select/map), `:625-...` (GroupBy), `:529-539` (Distinct).

## Checklist final

- [ ] Entrou por uma factory (`TColligoArray.From<T>` / `TColligoList<T>.From` /
      `TColligo.Range`).
- [ ] Usou os nomes reais: `Where` (não `Filter`), `Select<T>` com genérico
      explícito, `Exclude` (não `Except`).
- [ ] Terminou com um operador terminal (`ToArray`/`ToList`/agregação) — senão
      **nada executa** (Regra 2).
- [ ] `OrderBy` recebeu um **comparador** `TFunc<T,T,Integer>`; `ThenBy` só depois
      de ordenar (Regra 4).
- [ ] Para pegar o `TArray<T>` cru: `.ToArray.ArrayData`.

## Citations

- `README.md:72-124` — `uses` + os dois pipelines canônicos.
- `Source/Colligo.Collections.pas:288,762` — factories.
- `Source/Colligo.pas:457` — `TColligo.Range`.
- `Test Delphi/UTestColligo.ArrayStatic.pas:529-567,609-623,625-...` — usos verificados.
