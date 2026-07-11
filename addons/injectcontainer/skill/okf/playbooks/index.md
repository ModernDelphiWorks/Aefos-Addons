# Playbooks — InjectContainer

Guias práticos passo a passo, todos fundamentados no
`.modules\InjectContainer\Test Delphi\UTesteInject.pas` (uso correto), no Source e
no consumo real pelo Nidus.

- [Quickstart](quickstart.md) — do primeiro bind à resolução com injeção
  automática de construtor, cobrindo os seis modos de registro e as duas portas
  (classe/interface).
- [Troubleshooting](troubleshooting.md) — os erros que mais custam:
  `EServiceNotFound`, `Get<T>` retornando `nil` em silêncio,
  `EServiceAlreadyRegistered`, `ECircularDependency`, dep de construtor não
  injetada e `SingletonInterface` que "morre" na 2ª request.
</content>
