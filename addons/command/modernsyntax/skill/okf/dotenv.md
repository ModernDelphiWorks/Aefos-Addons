---
type: API Reference
title: ModernSyntax — Configuração .env com TDotEnv
description: Leitura de arquivos .env — parsing (comentários #, interpolação ${VAR}), Get/GetOr/TryGet/Value, UseSystemFallback e as operações de env var do SO, transcrito do Source com file:line.
tags: [modernsyntax, delphi, dotenv, env, config, api]
timestamp: 2026-07-11T00:00:00Z
---

# Configuração `.env` — `TDotEnv`

`TDotEnv` é uma **classe** que carrega variáveis de um arquivo `.env` e as expõe
com conversão de tipo, com **fallback opcional para as variáveis de ambiente do
SO**. Unidade: `ModernSyntax.DotEnv` (`Source/ModernSyntax.DotEnv.pas:30`).

> É `class` (não record): crie com `try..finally … Free`
> (`Source/ModernSyntax.DotEnv.pas:30,182-186`).

## Schema — criar e carregar

```pascal
uses ModernSyntax.DotEnv;

var LEnv: TDotEnv;
begin
  LEnv := TDotEnv.Create;                 // arquivo '.env', fallback ao SO = True (defaults) :44
  // ou: TDotEnv.Create('config/.env', False);  // arquivo custom, sem fallback ao SO
  try
    ...
  finally
    LEnv.Free;
  end;
end;
```
O construtor já chama `_LoadFromFile` (`:179`). `Create(AFileName='.env',
AUseSystemFallback=True)` — ambos com default (`:44`). Idioma:
`Test Delphi/EclbrSystem/UTestMS.DotEnv.pas:59,91`.

## Schema — ler valores (com conversão de tipo)

```pascal
LEnv.Get<Integer>('PORT');            // RAISE se ausente                       :104/:321
LEnv.Get<String>('HOST');             // idem                                    :104
LEnv.Value<String>('DB');             // ALIAS de Get<T>                         :84/:305
LEnv.GetOr<Integer>('PORT', 8080);    // default 8080 se ausente/erro           :98/:372
if LEnv.TryGet<Integer>('PORT', LPort) then ... ;   // Boolean, sem raise       :91/:310
LEnv.Count;                           // nº de variáveis carregadas             :109/:188
```
- `Get<T>` **converte de forma robusta apenas `Integer` e `String`**; outros tipos
  caem em ramos de exceção/`AsType` frágil — para `Boolean`/`Double`/etc.
  leia como `String` e converta você mesmo (`:321-370`). Ver [rules.md](rules.md).
- `GetOr<T>` engole qualquer erro/ausência e devolve o default (`:372-419`).
- `TryGet<T>` = `Get<T>` num `try/except` que devolve `False` em falha
  (`:310-319`).

Idioma real: `Get<Integer>('PORT')=8080`, `Get<String>('HOST')='localhost'`
(`UTestMS.DotEnv.pas:94-97`); `GetOr<Integer>('PORT', 8080)`
(`UTestMS.DotEnv.pas:110-113`); `Value<String>('DB')`
(`UTestMS.DotEnv.pas:104`).

## Schema — o formato do arquivo `.env`

O parser (`_LoadFromFile`, `:193-227`):
- **Ignora** linhas vazias e linhas que começam com `#` (`:207`).
- **Comentário inline:** corta tudo a partir do primeiro `#` na linha (`:209-211`).
- **`CHAVE=VALOR`**, com `Trim` na chave e no valor (`:212-218`) — logo
  `  PORT = 8080  ` vira `PORT`→`8080` (idioma: `UTestMS.DotEnv.pas:81-83,94`).
- **Interpolação `${VAR}`:** o valor pode referenciar variáveis **já carregadas**;
  `_ReplaceVars` substitui `${NOME}` pelo valor de `NOME` no dicionário
  (`:216,229-248`). Só resolve o que já foi lido antes; ordem importa.

```dotenv
# comentário de linha inteira
HOST=localhost
PORT = 8080          # comentário inline é removido
URL=http://${HOST}:${PORT}/api   # interpola HOST e PORT já lidos acima
```

## Schema — escrever / manipular em memória

```pascal
LEnv.Add('DB', 'mysql');                    // adiciona/atualiza                 :66/:280
LEnv.Push('K', 'v').Push('K2', 'v2');       // fluente (retorna self)            :73/:294
LEnv.Delete('DB');                          //                                    :78/:300
LEnv.Save;                                  // grava tudo de volta no arquivo    :60/:265
LEnv.LoadFiles(['base.env', 'prod.env']);   // limpa e recarrega; últimos vencem :56/:255
LEnv.Open;                                  // recarrega o arquivo atual         :51/:250
LEnv['CHAVE'];                              // property default (lê/escreve)     :144
```
`Add` também aplica `${VAR}` a valores string (`:284-288`). `LoadFiles` faz
`FVariables.Clear` e recarrega cada arquivo, então **arquivos posteriores
sobrescrevem** os anteriores (`:255-263`).

## Schema — variáveis de ambiente do SO

```pascal
LEnv.EnvCreate('TEST_VAR', '123');   // cria env var do SO                        :118/:431
LEnv.EnvLoad('TEST_VAR');            // lê env var do SO                          :124/:440
LEnv.EnvUpdate('TEST_VAR', '456');   // atualiza                                   :131
LEnv.EnvDelete('TEST_VAR');          // remove                                     :137
LEnv.UseSystemFallback := True;      // Get/GetOr caem na env var se faltar no .env :148
```
Com `UseSystemFallback=True` (default), `Get<T>`/`GetOr<T>` que não acham a chave
no `.env` tentam `EnvLoad` (a env var do SO) antes de falhar/usar default
(`:348-350,398-401`). No Linux, `EnvCreate`/`EnvDelete` usam o shim POSIX
`setenv`/`unsetenv` em vez de `SetEnvironmentVariable` (`:22-27`). Idioma:
`EnvCreate`/`EnvLoad` em `UTestMS.DotEnv.pas:153-156`.

## Citations

- `Source/ModernSyntax.DotEnv.pas:30-149` — declaração de `TDotEnv`.
- `Source/ModernSyntax.DotEnv.pas:193-248` — `_LoadFromFile` (comentários) e `_ReplaceVars` (`${VAR}`).
- `Source/ModernSyntax.DotEnv.pas:305-419` — `Value`/`Get`/`GetOr`/`TryGet` e o fallback ao SO.
- `Source/ModernSyntax.DotEnv.pas:22-27,431-440` — shim POSIX e `EnvCreate`/`EnvLoad`.
- `Test Delphi/EclbrSystem/UTestMS.DotEnv.pas:59,81-97,104-113,153-156` — idiomas reais.
- `delphi-modernsyntax-specialist.md:18` — `TDotEnv.Create('.env')` + fallback ao SO.
