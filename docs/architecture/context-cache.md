---
title: "Context Cache"
description: "What the context cache contains, how it is built, and how to maintain it."
---

# Context cache

> *Reference — what the context cache contains, how it is built, and how to maintain it.*

---

## Purpose

Agents cannot clone repos at runtime — it would be too slow and would expose write credentials
unnecessarily. Instead, a nightly job pre-processes each repo into compact Markdown files that
agents can `cat` in seconds.

There are two cache levels per repo:

| File | Purpose | Who uses it |
|---|---|---|
| `context.md` | Light orientation: conventions, config, file tree | All agents |
| `context-dev.md` | Targeted source files for implementation analysis | JeanMichelArch (targeted mode), JeanMichelDev |

---

## Locations

```
/home/neonuser/.neon/context/
├── bismuth-blog/
│   ├── context.md
│   └── context-dev.md
├── homelab-gallium/
│   ├── context.md
│   └── context-dev.md
└── neon-agents/
    └── context.md        ← no context-dev.md (no dev_include configured)
```

Repo clones live at:
```
/home/neonuser/.neon/repos/Trophalaxeur/<repo>/
```

---

## What `context.md` contains

Built from a fixed set of files present in every repo:

```
CLAUDE.md · README.md · package.json · pyproject.toml · Makefile
.eslintrc* · .stylelintrc* · .prettierrc*
.github/workflows/*.yml
```

Plus a complete git file tree appended at the bottom, and a build timestamp.

**Purpose:** gives an agent a fast, accurate picture of the stack, conventions, project purpose,
and available scripts — without loading source files. Sufficient for PO refinement and for
JeanMichelArch's light context mode.

---

## What `context-dev.md` contains

Built from repo-specific source file globs defined in `agents/context-builder/config.yml`:

| Repo | Included paths |
|---|---|
| `bismuth-blog` | `src/pages/**`, `src/components/**`, `src/utils/**`, `src/content.config.ts`, `src/site.config.ts` |
| `homelab-gallium` | `ansible/roles/**`, `ansible/group_vars/**`, `terraform/**` |
| `neon-agents` | *(not built — no `dev_include` configured)* |

**Purpose:** gives JeanMichelArch targeted knowledge of the existing implementation so it can
propose solutions that fit the current patterns, types, and component structure.

To add `context-dev.md` for a new or existing repo, add `dev_include` to the repo entry in
`agents/context-builder/config.yml` (see [Adding a repo to the context builder](#adding-a-repo-to-the-context-builder)).

---

## Build schedule

The nightly job runs at **01:00** on neon, managed by the system crontab for `neonuser`.

It skips a repo if:
- The last git commit is older than the last `context.md` build time
- AND `--force` was not passed

It always rebuilds if:
- There is a new commit since the last build
- `--force` is passed
- `context-dev.md` is expected (has `dev_include`) but missing

---

## Force rebuild

```bash
# All repos
sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force

# Verify result (check timestamp at the bottom of the file)
tail -3 /home/neonuser/.neon/context/<repo>/context.md
```

---

## Check the build log

```bash
ls -lt /home/neonuser/.neon/logs/
cat /home/neonuser/.neon/logs/context-nightly-<YYYYMMDD>.log
```

---

## Adding a repo to the context builder

1. Add the entry to `agents/context-builder/config.yml`:

```yaml
repos:
  - owner: Trophalaxeur
    name: <new-repo>
    dev_include: "src/**,..."   # omit this line if context-dev.md is not needed
```

2. Update `INCLUDE_GLOBS` in `scheduler/context-nightly.sh` if you need new file types in
   `context.md` (rare — the default set covers most projects).

3. Clone the repo on neon:
```bash
git clone git@github.com:Trophalaxeur/<new-repo>.git \
  /home/neonuser/.neon/repos/Trophalaxeur/<new-repo>
```

4. Register a deploy key on GitHub for read access.

5. Force rebuild:
```bash
sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force
```

6. Update the workspace mapping in **all deployed `SKILL.md` files** and run
   `multica skill update <id>` for each. See [CLAUDE.md](../../CLAUDE.md#adding-a-project-repo).

---

## Tools

The context builder uses **[repomix](https://github.com/yamadashy/repomix)** with `--compress`
and `--style markdown`. The compressed output strips whitespace-only lines and collapses
consecutive blank lines, keeping the token count low while preserving all content.
