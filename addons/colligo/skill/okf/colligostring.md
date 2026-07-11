---
type: Reference
title: Colligo — TColligoString (record helper for string)
description: O record helper de string do Colligo (compatível com TStringHelper) e o gotcha Linux de ToLower/ToUpper corrigido no Source.
tags: [colligo, delphi, tcolligostring, string-helper, linux, libicu]
timestamp: 2026-07-11T00:00:00Z
---

# `TColligoString` — record helper para `string`

`TColligoString` é um **`record helper for string`** (`Source/Colligo.Helpers.pas:45`)
que reimplementa/espelha o `TStringHelper` da RTL: comparação, conversão, busca,
split/join, padding, trim e operações de caixa. Você o usa transparentemente sobre
qualquer `string` quando a unit `Colligo.Helpers` está no `uses`.

## API (grupos principais)

`Source/Colligo.Helpers.pas:63-260`:

- **Comparação:** `Compare` (várias sobrecargas com `TCompareOptions`/`LocaleID`),
  `CompareOrdinal`, `CompareText`, `CompareTo`, `Equals` (`:69-79`, `:94`, `:104-105`).
- **Conversão de/para:** `ToBoolean/ToInteger/ToInt64/ToSingle/ToDouble/ToExtended`
  e `Parse(Integer|Int64|Boolean|Extended)` (`:80-89`).
- **Caixa:** `LowerCase`/`UpperCase` (class, delegam ao RTL, `:90-93`, `:405-413`),
  e os métodos de instância `ToLower`/`ToUpper` (+ `LocaleID`) e
  `ToLowerInvariant`/`ToUpperInvariant` (`:184-189`).
- **Busca/estrutura:** `Contains`, `IndexOf*`, `LastIndexOf*`, `StartsWith`/
  `EndsWith`, `Split` (muitas sobrecargas, com quoting), `Join`, `PadLeft`/
  `PadRight`, `Trim*`, `Replace`, `Remove`, `Insert`, `QuotedString`/`DeQuotedString`.
- **Enumerável de chars:** `AsEnumerable(string): IColligoEnumerable<Char>`
  (`:62`) — integra a string ao pipeline Colligo.

## Gotcha Linux — `ToLower`/`ToUpper` (ERRATA)

**Contexto:** ao portar o backend para **Linux64** (`dcclinux64`), `TColligoString`
tinha um fallback Linux **quebrado**: chamava `UCS4LowerCase`/`UCS4UpperCase`, que
**não são declarados** no RTL Linux → não compilava (`README.md:51`, `:163`;
`delphi-colligo-specialist.md:32`).

**Correção (já no Source):** o caminho com locale usa `USE_LIBICU` (ICU); o
fallback Linux passou a usar o RTL `System.SysUtils.LowerCase`/`UpperCase`. O
comportamento no Windows não mudou. Confirma-se na ramificação de plataforma de
`ToLower` (`Source/Colligo.Helpers.pas:1509-1514`):

```pascal
{$ELSEIF defined(LINUX)}
begin
  // Epic 25: UCS4LowerCase is undeclared on Linux; locale-aware lowering uses the
  // USE_LIBICU path above. Fall back to the RTL invariant lowercase otherwise.
  Result := System.SysUtils.LowerCase(Self);
end;
```

- No Windows, `ToLower`/`ToUpper` usam `LCMapString` com casing linguístico
  (`Source/Colligo.Helpers.pas:1422-1432`, `:1593-1603`).
- Com `USE_LIBICU` definido, o lowering com locale usa `u_strToLower`/`u_strToUpper`
  do ICU, com fallback para `System.SysUtils.LowerCase` quando o ICU não está
  disponível (`Source/Colligo.Helpers.pas:1433-1481`).

**Relevância no Axial:** só importa se o backend rodar/compilar em **Linux64**
(verificado como suportado — `README.md:47-53`). Em Windows, inalterado.

## Como aplicar

```pascal
uses Colligo.Helpers;
...
if MinhaString.ToLower.Contains('ana') then ...
LParts := 'a;b;c'.Split([';']);
```

## Citations

- `Source/Colligo.Helpers.pas:45` — `TColligoString = record helper for string`.
- `Source/Colligo.Helpers.pas:63-260` — superfície da API.
- `Source/Colligo.Helpers.pas:184-189` — `ToLower/ToUpper/Invariant`.
- `Source/Colligo.Helpers.pas:1416-1481,1509-1514,1587-1603` — casing por
  plataforma + fallback Linux corrigido.
- `README.md:47-53,159-165` — build Linux64 verificado + descrição do fix.
- `delphi-colligo-specialist.md:32` — errata do gotcha Linux.
