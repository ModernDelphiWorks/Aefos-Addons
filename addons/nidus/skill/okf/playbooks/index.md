# Playbooks — Nidus

Guias práticos passo a passo, todos fundamentados no exemplo funcional
(`D:\PROJETOS-Brasil\e-docs-api-horse`) e no Source (`.modules\Nidus\Source`).

- [Quickstart](quickstart.md) — do zero a um módulo Nidus com rota, controller,
  service e DI por construtor, no padrão canônico (feature module + `TCoreModule`
  provider + `TRouteHandlerHorse`).
- [Troubleshooting](troubleshooting.md) — os erros que mais custam: 404 (param no
  meio), 401 (interface não exportada / deps de construtor não exportadas /
  refcount do `SingletonInterface` / guard resolvendo no injector root), 400
  permanente (`Imports` com rotas antes do DEC-050) e header case-sensitive.
</content>
