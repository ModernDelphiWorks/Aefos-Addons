---
okf_version: "0.1"
---

# Knowledge Bundle Index — MetaDbDiff Specialist

Base de conhecimento do especialista no **MetaDbDiff** (Delphi, por Isaque
Pinheiro) — o motor de **atributos de mapeamento ORM + RTTI + diff/migração de
schema** que serve de fundação estrutural ao **Janus**. Fundamentada em
`.modules\MetaDbDiff\Source` (`Core\` + `Drivers\`), no `README.md` do framework
e no uso real das entidades do projeto; todo fato é rastreável por `arquivo:linha`.

## Conceitos

- [Visão Geral](overview.md) — o que é o MetaDbDiff, arquitetura (atributos →
  RTTI → catálogo → diff → DDL), relação com Janus e DataEngine, quando usar.
- [API do Motor](api.md) — as unidades públicas: `TRegisterClass` (registro de
  entidade), `TMappingExplorer` (leitura cacheada do mapeamento), `TDatabaseCompare`
  (comparação), `TSQLDriverRegister` (drivers de DDL) e a nota sobre o facade do
  `README`.
- [Atributos de Mapeamento](mapping-attributes.md) — catálogo completo de todos
  os decorators (`[Entity]`, `[Table]`, `[Column]`, `[PrimaryKey]`, `[ForeignKey]`,
  `[Association]`, `[JoinColumn]`, `[Dictionary]`, `[Restrictions]`, `[OrderBy]`,
  `[Sequence]`, `[Indexe]`, `[Check]`, `[Enumeration]`, `[CascadeActions]`,
  validações) com assinatura e caveats.
- [Helpers RTTI](rtti-helpers.md) — como LER o mapeamento em código:
  `TRttiProperty.GetColumn`, `TRttiType.GetPrimaryKey`, `IsNullable`,
  `IsAssociation`, `GetAssociation`, `GetCascadeActions`, `GetNullableValue`, etc.
- [Diff & Migração de Schema](schema-diff.md) — o motor de comparação
  (modelo↔banco e banco↔banco), as regras de igualdade (`DeepEqualsColumn`), a
  geração de DDL cirúrgica e os dialetos suportados.
- [Regras & Erratas](rules.md) — antipadrões e lições aprendidas na marra
  (LER — nunca repita os bugs).

## Playbooks

- [Playbooks](playbooks/index.md) — guias práticos passo a passo:
  - [Quickstart](playbooks/quickstart.md) — decorar uma entidade, registrá-la e
    rodar um diff modelo→banco que gera o DDL.
  - [Troubleshooting](playbooks/troubleshooting.md) — driver não registrado,
    facade inexistente, `size`/`scale` trocados, entidade não aparece no diff.

## Meta

- [Histórico](log.md) — log de criação/atualização desta base.
