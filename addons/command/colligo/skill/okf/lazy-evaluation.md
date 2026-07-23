---
type: Reference
title: Colligo — Lazy Evaluation (Deferred Execution)
description: Como o Colligo posterga o processamento até um operador terminal, o que é deferido vs terminal, re-enumeração da fonte e as armadilhas de efeito colateral.
tags: [colligo, linq, delphi, lazy-evaluation, deferred-execution]
timestamp: 2026-07-11T00:00:00Z
---

# Lazy Evaluation (Deferred Execution)

O Colligo é **lazy por design**: montar um pipeline não processa dado nenhum. Os
operadores intermediários só **encadeiam** enumeráveis; o trabalho real só
acontece quando um operador **terminal** puxa a cadeia. É a mesma semântica do
LINQ to Objects, adotada de propósito (`README.md:28`, `:140`;
`delphi-colligo-specialist.md:33`).

## Como funciona (o mecanismo)

Cada operador deferido cria um `TColligo<Op>Enumerable<T>` que **guarda a fonte
anterior** e devolve um record novo. O `TColligo<Op>Enumerator<T>.MoveNext` só
pede o próximo item da fonte quando chamado. Ex.: o filtro puxa a fonte até o
predicado passar (`Source/Colligo.Where.pas:75-87`):

```pascal
function TColligoWhereEnumerator<T>.MoveNext: Boolean;
begin
  while FSource.MoveNext do          // puxa a fonte sob demanda
  begin
    FCurrent := FSource.Current;
    if FPredicate(FCurrent) then     // aplica o predicado item a item
      Exit(True);
  end;
  Result := False;
end;
```

Um terminal (`ToArray`, `Count`, `First`, `Sum`…) chama `GetEnumerator` e itera
com `MoveNext`, disparando a cascata inteira uma vez (`Source/Colligo.pas:522-525`
e cada agregação, ex.: `Count`/`Any` em `:1280-1298`).

## Deferido vs Terminal

- **Deferido** (só encadeia): `Where`, `Select<>`, `Take`, `Skip`, `TakeWhile`,
  `SkipWhile`, `Distinct`, `OrderBy`/`Order`/`Reverse`, `GroupBy`, `Join`,
  `SelectMany`, `Union`/`Intersect`/`Exclude`/`Concat`, `Append`/`Prepend`,
  `Cast`, `Chunk`, `DefaultIfEmpty`, `OfType`, `Zip`.
- **Terminal** (executa): `ToArray`, `ToList`, `ToHashSet`, `ToDictionary`,
  `ToLookup`, `First`/`Last`/`Single` (+`OrDefault`), `Count`/`LongCount`,
  `Any`/`All`, `Contains`, `Aggregate`, `Sum`, `Average`, `Min`/`Max`,
  `ElementAt`, `SequenceEqual`.

## Prova no teste

O selector de um `Select` com um `Writeln` dentro só imprime **na
materialização** — "Map chamado, mas ainda não iterado" aparece antes de qualquer
"Mapping: N" (`Test Delphi/UTestColligo.ArrayStatic.pas:706-723`):

```pascal
LMapped := TColligoArray.From<Integer>([1,2,3]).Select<string>(
  function(Value: Integer): string
  begin
    Writeln('Mapping: ' + IntToStr(Value));   // NÃO roda aqui
    Result := Value.ToString + 'x';
  end);
Writeln('Map chamado, mas ainda não iterado'); // roda primeiro
LArray := LMapped.ToArray;                      // AQUI o selector executa
```

## Armadilhas (LER)

1. **Efeitos colaterais no lambda rodam no consumo, não na montagem.** Se o
   `Select`/`Where` tem side-effect (log, mutação, I/O), ele dispara quando você
   materializa — e **uma vez por item consumido** (`delphi-colligo-specialist.md:33`).
2. **Não enumere a mesma cadeia duas vezes esperando cache.** Cada terminal
   re-executa o pipeline do zero; o resultado não é memoizado. Se precisa reusar,
   materialize uma vez (`ToArray`/`ToList`) e consulte o resultado.
3. **Cuidado com fontes que se esgotam.** A cadeia guarda a fonte por referência;
   uma fonte mutável/consumível entre dois terminais pode dar resultados
   diferentes. Materialize cedo quando a fonte for volátil.
4. **`ToArray`/`ToList` são não-destrutivos** — copiam e deixam a fonte intacta,
   então a lista original pode ser consultada de novo
   (`Source/Colligo.Collections.pas:733-741`).

## Citations

- `README.md:28,140` — lazy/deferred como recurso central.
- `Source/Colligo.Where.pas:75-87` — `MoveNext` que puxa a fonte sob demanda.
- `Source/Colligo.pas:522-525,1280-1298` — terminal consome via `GetEnumerator`.
- `Source/Colligo.Collections.pas:733-741` — `ToArray` não-destrutivo.
- `Test Delphi/UTestColligo.ArrayStatic.pas:706-723` — prova da execução deferida.
- `delphi-colligo-specialist.md:33` — errata lazy/deferred (efeitos colaterais).
