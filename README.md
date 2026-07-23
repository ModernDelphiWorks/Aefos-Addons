# Aefos Addons

The community catalogue of **addons for [Aefos](https://github.com/ModernDelphiWorks)** —
the AI plugin suite for RAD Studio / Delphi. An addon teaches Aefos a new
skill, wires an MCP server, or ships a tool, and anyone can install it with one
command:

```
aefos install <slug>
```

This repository is the **source of truth**: each addon lives as a folder under
`addons/<type>/` — the catalogue is organized by type so the tree is legible at a
glance:

```
addons/
├── command/   — command/skill specialists (janus-orm, nidus, colligo, …)
├── mcp/        — MCP servers (desktop, …)
└── tool/       — runnable tools
```

`registry.json` indexes every published version (its `type` field matches the
folder). **Other developers are welcome to publish their own addons here via
Pull Request** — this README is the contract.

---

## What an addon is

An addon is a small bundle whose entry point is usually a global **slash
command** (`/janus`, `/mvc`, …). When you type it in Aefos chat, the command's
prompt tells the model to read the bundled **skill** and its **OKF** knowledge,
turning the assistant into a specialist. Addons can also ship an **MCP server**
or a **tool**.

There are **three types**:

| Type | Needs OKF? | Ships | What it does |
|------|-----------|-------|--------------|
| `command` | **yes** | `command/` + `skill/okf/` | a domain specialist (e.g. an ORM, a framework, a workflow) |
| `mcp` | no | an `mcpServers` fragment | a Model Context Protocol server (its tools self-describe) |
| `tool` | no | a runnable tool (e.g. Python) | a callable capability |

> **Templates are NOT a type.** A `command`/`skill` addon may carry an optional
> **`templates/`** folder — project/code scaffolds it generates (e.g. an MVC
> layout). It is content the command owns, never installed on its own: there is
> **no `aefos install <template>`**. The command's `COMMAND.md` (or the OKF)
> says where each template is and when to use it. See the anatomy below.

> **Why the OKF rule?** OKF ([Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md))
> is knowledge *for the model to read*. A `command`/`skill` is knowledge, so it
> uses OKF. An `mcp`/`tool` is *code the model calls* — it self-describes, so it
> doesn't need OKF (a one-line "when to use me" in the description is enough).

---

## Anatomy of a bundle (`addons/<type>/<slug>/`)

Each addon folder sits under its **type** directory — `addons/command/<slug>/`,
`addons/mcp/<slug>/`, or `addons/tool/<slug>/`.

This is the single source of truth. Every entry is tagged **(required)** or
**(optional)**. `addon.json` is the ONLY file required in every addon; beyond it,
include just the block for your addon **type** (`command`/`skill`, `mcp`, or
`tool`) — and within that block honor the tags. The install lays down **whatever
folders are present**, so an optional block (like `templates/`) is truly
independent: include it or not, the rest installs the same.

```
addons/<type>/<slug>/
├── addon.json                     (required)  — the manifest (see below); the ONLY always-required file
│
│   ▼ include the block(s) for your addon TYPE — command/skill · mcp · tool
│
├── command/                                   — command/skill addons
│   └── COMMAND.md                 (required)  — the /<cmd> trigger (frontmatter name == <cmd>)
├── skill/                                     — command/skill addons
│   ├── SKILL.md                   (required)  — activation; points at okf/ (and any templates/)
│   └── okf/                       (required)  — OKF knowledge; installs to ~/.aefos/skills/<slug>/
│       ├── index.md               (required)  — main navigation index (carries okf_version: "0.1")
│       ├── log.md                 (required)  — chronological update history (no frontmatter)
│       ├── overview.md            (optional)  — introduction / high-level overview   (has `type:`)
│       ├── api.md                 (optional)  — technical specs: APIs, MCPs, commands (has `type:`)
│       ├── rules.md               (optional)  — rules, conventions, constraints       (has `type:`)
│       └── playbooks/             (optional)  — step-by-step practical guides
│           ├── index.md           (optional)  — subfolder index (no frontmatter)
│           ├── troubleshooting.md (optional)  — how to resolve common errors
│           └── quickstart.md      (optional)  — quick-start guide
├── templates/                     (optional)  — scaffolds a command/skill GENERATES (NOT a type);
│   └── <name>/                                  installs to ~/.aefos/templates/<slug>/. Present or not,
│       ├── template.json                        the addon is valid either way. The COMMAND.md/OKF
│       └── {{Name}}*.*                          references it (where + when/how to use); {{...}} rendered on use.
├── mcp/                                        — mcp addons only
│   └── server.json                (required)  — one `mcpServers` entry, keyed by slug
└── tools/                         (required)  — tool addons only — the tool artifacts
```

The `skill/okf/` subtree is exactly what installs to `~/.aefos/skills/<slug>/` for
`command`/`skill` addons, following the OKF
([Open Knowledge Format](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)).
**(optional)** entries are recommended for quality but an addon is valid without
them.

### `addon.json`

```json
{
  "slug": "janus-orm",
  "version": "1.0.0",
  "name": "Janus ORM Specialist",
  "description": "One-line summary shown on the site and in `aefos list`.",
  "type": "command",
  "trust": "official",
  "author": "Your Name",
  "requirements": { "aefos_version": ">=0.30.0" },
  "command": "/janus",
  "install": {
    "commands": [
      { "name": "janus", "source": "addons/command/janus-orm/command/", "target_path": "commands/janus/" }
    ],
    "skills": [
      { "name": "delphi-janus-specialist", "source": "addons/command/janus-orm/skill/", "target_path": "skills/delphi-janus-specialist/" }
    ]
  }
}
```

- **`install`** maps each bundle folder (`source`, repo-relative) to where it
  lands under the user's `~/.aefos/` (`target_path`). Keys are by kind:
  `commands` / `skills` / `tools` / `mcp` / `templates`. A `command` that carries
  scaffolds maps its `addons/command/<slug>/templates/` → `templates/<slug>/` (the
  `templates` key is optional — omit it when the addon has no `templates/`).
- **`command`** is the chat trigger. The `COMMAND.md` frontmatter `name` **must
  equal** the command folder name (so `commands/janus/COMMAND.md` → `name: janus`
  → `/janus`).
- **`requirements.aefos_version`** gates install against the user's Aefos version.

---

## Publishing your addon (Pull Request)

1. **Fork** this repo.
2. Add your bundle under **`addons/<type>/<your-slug>/`** (`command/`, `mcp/`, or `tool/`) following the layout above.
3. For a `command`/`skill` addon, ground the OKF in real sources — **cite
   `file:line`**; don't invent APIs. The `rules.md` errata (real gotchas + the
   case that caused them) is the most valuable part.
4. Open a **Pull Request**. On review + merge, the maintainer tags a release and
   the CI packs your `<slug>-<version>.zip`, computes its `sha256`, and updates
   `registry.json` — no manual edits to `registry.json` needed.

**Checklist before you open the PR**
- [ ] `addon.json` present, `slug` unique, `version` set.
- [ ] `install` targets stay under `~/.aefos/` (no `..`).
- [ ] `command` addons: `COMMAND.md` `name` == command folder name.
- [ ] OKF (command/skill): every concept file has `type:`; only `okf/index.md`
      has `okf_version`; `log.md` and `playbooks/index.md` have no frontmatter.
- [ ] No broken relative links.
- [ ] `mcp`/`tool` that runs third-party code: say so plainly in the description.

---

## How install & update work

`registry.json` is the index — it holds the **current** entry for each slug. The
CLI always brings that current build; you never pick a version.

```
aefos install <slug>     # download the current build, verify sha256, lay it under ~/.aefos/
aefos update <slug>      # refresh to the current build; a no-op ("already current") if unchanged
aefos update             # update ALL installed addons
aefos update --check     # dry-run: report what would update, install nothing
aefos list               # list what's installed
aefos uninstall <slug>   # remove it
```

`aefos install` reads `registry.json`, downloads the `<slug>` zip from its
Release, **verifies its `sha256`**, and extracts **whatever folders it carries**
under `~/.aefos/` per the `install` mappings — an optional block that isn't there
is simply skipped. `update` compares the installed `sha256` with the registry's:
same ⇒ nothing to do; different ⇒ clean-replace with the current build.

## Trust & security

- Every zip is **checksummed** (`sha256` in `registry.json`); a mismatch aborts
  the install. The `sha256` is also the update identity — how the CLI knows your
  copy differs from the current build.
- `requirements.aefos_version` gates install/update against the user's Aefos
  version — an addon that needs a newer Aefos is held back, never forced.
- `official` addons are maintained here; `community` addons that ship runnable
  code (`mcp`/`tool`) require the user's explicit consent (`--yes`) to install.

## License

Each addon is licensed by its author (see the addon's own files). Framework
specialist addons document open-source frameworks and cite their sources.
