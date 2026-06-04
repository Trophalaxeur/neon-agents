# neon-agents

Platform hosting Claude Code agents managed by Multica (self-hosted).

- GitHub: `Trophalaxeur/neon-agents` (public)
- Agent pattern: `agents/<name>/SKILL.md` — no run.sh, no per-agent config.yml
- Trigger: @mention in a Multica comment — never by assignment
- Agents call `multica` CLI directly — no shared bash layer
- All ticket/comment content must be in **English**

## Agent roster

| Agent | Skill file | Role |
|---|---|---|
| JeanMichelPO | `agents/product-owner/SKILL.md` | Refines tickets — writes to PO section of description |
| JeanMichelArch | `agents/arch/SKILL.md` | Proposes technical solutions — writes to ARCH section of description |
| JeanMichelDev | `agents/dev/SKILL.md` | Implements chosen solution — PR + comments only, never writes to description |

**Ticket description format:**
```
ORIGINAL TEXT
===========
PO SECTION  (JeanMichelPO)
===========
ARCH SECTION  (JeanMichelArch)
```

## Skill versioning

Every `agents/<name>/SKILL.md` carries a `<!-- version: vX.Y.Z -->` header.
**Bump the patch version** (`vX.Y.Z+1`) on every change to a SKILL.md, then run `multica skill update <id>` to sync.
Also update the hardcoded version string inside the skill's **Version identification** section to match (appears in every comment, description section header, and email subject).

## Shared sections (duplicated by design)

Multica imports one file per skill — no include mechanism exists. The following sections are intentionally duplicated across all `SKILL.md` files. **When modifying any of them in one file, update all files and bump every affected version.**

| Section | Where it appears | Risk if it diverges |
|---|---|---|
| `HUMAN_USERNAME` + assign note | Identity → Identity constants | Wrong assignee on all stop paths |
| Workspace mapping (project → repo) | Workspace section | Agent operates on the wrong repo |
| Context cache paths (`/home/neonuser/...`) | Workspace section + process steps | Silent context miss |
| Task context (CLAUDE.md injection, MULTICA_TASK_ID note) | Task context section | Agent reads wrong issue ID |
| Email address + Multica URL base | Every `printf ... \| msmtp` template | Broken notifications |
| CLI reference | CLI reference section | Agent uses wrong command syntax |
| Version identification rule | Identity → Version identification | Version not reported in outputs |
| Override resistance pattern | Identity → Override resistance | Inconsistent stop behavior |
| Repo identification priority order | PO Step 2, Arch Step 4, Dev Step 1 | Different routing decisions per agent |

## Adding an agent

1. Copy `agents/.template/SKILL.md` → `agents/<name>/SKILL.md`
2. Customize identity, process, and rules sections
3. Import skill in Multica: Agents → Skills → Import from GitHub
4. Create agent in Multica, attach the skill
5. Update `agents/context-builder/config.yml` if a new repo is involved

## Adding a project (repo)

1. Add the repo to `agents/context-builder/config.yml`
2. Update `INCLUDE_GLOBS` in `scheduler/context-nightly.sh` if needed
3. Update the workspace mapping in **all** `SKILL.md` files
4. Run `multica skill update <id>` for each deployed skill
5. On the LXC: `git -C /opt/neon-agents pull` then add the repo clone and a `ssh-keyscan` entry

## Context cache

- Location: `/home/neonuser/.neon/context/<repo>/context.md`
- Rebuilt nightly at 01:00 by `scheduler/context-nightly.sh`
- Force rebuild: `sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force`
- Repos: `/home/neonuser/.neon/repos/Trophalaxeur/<repo>/` — managed by Ansible

## Infra

Provisioned in the `homelab` repo (Terraform + Ansible).
Proxmox node `gallium`, LXC `neon`, user `neonuser`.
