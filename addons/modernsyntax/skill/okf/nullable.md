---
type: API Reference
title: ModernSyntax — Null-safety com TOption<T>
description: O tipo opcional TOption<T> — Some/None, IsSome/IsNone, Unwrap/UnwrapOr/Expect, Map/Filter/AndThen, Match e a ponte OkOr para TResultPair, transcrito do Source com file:line.
tags: [modernsyntax, delphi, option, null-safety, some, none, api]
timestamp: 2026-07-11T00:00:00Z
---

# Null-safety — `TOption<T>`

`TOption<T>` é um **record** que representa "um valor de `T`" (**Some**) ou "nenhum
valor" (**None**), no estilo `Option` de Rust / `Maybe` de Haskell. Serve para
evitar Access Violation por valor ausente, forçando o fluxo a tratar o caso vazio.
Unidade: `ModernSyntax.Option` (`Source/ModernSyntax.Option.pas:48`).

> ⚠️ **Não é `Nullable<T>`.** O tipo null-safety do ModernSyntax é `TOption<T>`. O
> `Nullable<T>` do ecossistema é do **Janus** (`Janus.Types.Nullable`), outra
> coisa. Ver [rules.md](rules.md).

## Schema — criação e consulta

```pascal
uses ModernSyntax.Option;

var LOpt: TOption<Integer>;

LOpt := TOption<Integer>.Some(42);   // com valor
LOpt := TOption<Integer>.None;       // vazio

if LOpt.IsSome then ... ;            // True se tem valor
if LOpt.IsNone then ... ;            // True se vazio
```
Fonte: `Some` (`:69/:245`), `None` (`:75/:251`), `IsSome` (`:89/:256`), `IsNone`
(`:95/:261`). Idioma confirmado em
`Test Delphi/EclbrSystem/UTestMS.Option.pas:142-143,163-164`.

## Schema — extrair o valor com segurança

```pascal
LOpt.Value;                     // property; RAISE se None (GetValue)          :238/:286
LOpt.Unwrap;                    // = Value; RAISE se None                       :116/:293
LOpt.UnwrapOr(0);               // valor, ou 0 se None                          :123/:298
LOpt.UnwrapOrElse(function: Integer begin Result := 1 end);  // default computado :130/:306
LOpt.UnwrapOrDefault;           // valor, ou Default(T) (0/'' /nil) se None      :136/:329
LOpt.Expect('faltou o id');     // valor, ou RAISE com sua mensagem             :143/:342
```
`GetValue`/`Unwrap` lançam `Exception.Create('Attempted to access a value from
TOption.None')` em None (`:288-289`). **Prefira `UnwrapOr`/`UnwrapOrElse`/`Expect`
a `Value`/`Unwrap`** quando o None é possível. Idioma:
`UnwrapOr(0)` (`UTestMS.Option.pas:206,210`), `UnwrapOrElse`
(`UTestMS.Option.pas:220,225`).

## Schema — transformar sem sair do Option

```pascal
LStr := LOpt.Map<string>(function(V: Integer): string begin Result := V.ToString end); // :151/:349
LOpt2 := LOpt.Filter(function(V: Integer): Boolean begin Result := V > 0 end);          // :158/:357
LOpt3 := LOpt.AndThen<string>(function(const V: Integer): TOption<string> begin ... end);// :166/:365
LOpt4 := LOpt.Otherwise(TOption<Integer>.Some(7));   // alternativa se None            :173/:373
LOpt5 := LOpt.OrElse(function: TOption<Integer> begin Result := ... end);               // :180/:381
```
- `Map<U>`: se Some, aplica e devolve `TOption<U>.Some`; se None, `TOption<U>.None`
  (`:349-355`). Idioma: `UTestMS.Option.pas:234`.
- `Filter`: mantém o Some só se o predicado passar, senão vira None (`:357-363`).
- `AndThen<U>`: encadeia uma função que já devolve `TOption<U>` (flat-map)
  (`:365-371`).

## Schema — consumir com Match / IfSome

```pascal
LOpt.Match(
  procedure(const V: Integer) begin Writeln('tem ', V) end,   // Some
  procedure begin Writeln('vazio') end);                       // None       :195/:397

LOpt.IfSome(procedure(const V: Integer) begin ... end);        // só no Some  :209/:413
```
Há também uma sobrecarga `Match<R>(ASome: TSome; ANone: TNone): R` que devolve um
valor a partir dos records `TSome`/`TNone` (`:203/:405`; `TSome`/`TNone` em
`:28-46`).

## Schema — ponte para o railway

```pascal
LRes := LOpt.OkOr<string>('não encontrado');   // TResultPair<Integer, string>   :188/:389
```
Se Some → `TResultPair<T,F>.New.Success(valor)`; se None →
`New.Failure(AFailure)` (`:389-395`). É o elo entre [nullable.md](nullable.md) e
[railway-result.md](railway-result.md).

## Outros utilitários (Source)

- `Contains(v [, comparer])` — `:110/:276`; `IsSomeAnd(pred)` — `:102/:266`.
- `Take(var self)` — extrai e zera a origem — `:216/:419`.
- `Replace(var self, novo)` — troca e devolve o antigo — `:231/:446`.
- `Flatten<U>` — achata `TOption<TOption<U>>` — `:223/:430`.
- `Zip(a, b): TOption<Variant>` — par se ambos Some — `:83/:314`.
- `AsString` — `:233/:271`.

## Examples

```pascal
// lookup seguro que pode não achar
function BuscarNome(const AId: Integer): TOption<string>;
begin
  if AId = 1 then
    Result := TOption<string>.Some('Isaque')
  else
    Result := TOption<string>.None;
end;

// consumo sem risco de AV:
Writeln(BuscarNome(1).UnwrapOr('desconhecido'));   // 'Isaque'
Writeln(BuscarNome(9).UnwrapOr('desconhecido'));   // 'desconhecido'
```
Padrão de idioma alinhado a `Test Delphi/EclbrSystem/UTestMS.Option.pas:142-243`.

> ⚠️ O `README.md:65-83` usa `HasValue`, `Value` e `ValueOrElse('...')` — **esses
> nomes não existem** no Source. Use `IsSome`/`Value`/`UnwrapOr`. Ver
> [rules.md](rules.md).

## Citations

- `Source/ModernSyntax.Option.pas:48-239` — declaração completa de `TOption<T>`.
- `Source/ModernSyntax.Option.pas:245-451` — implementações (Some/None/Unwrap*/Map/Filter/AndThen/Match/OkOr).
- `Source/ModernSyntax.Option.pas:286-291` — `GetValue` lança em None.
- `Test Delphi/EclbrSystem/UTestMS.Option.pas:142-243` — idiomas reais (Some/IsSome/UnwrapOr/UnwrapOrElse/Map).
- `README.md:65-83` — snippet DESATUALIZADO (HasValue/ValueOrElse).
