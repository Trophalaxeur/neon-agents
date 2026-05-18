# neon-agents

Platform hosting Claude Code agents managed by Multica (self-hosted).

- GitHub: `Trophalaxeur/neon-agents` (public)
- Agent pattern: `agents/<name>/SKILL.md` — no run.sh, no per-agent config.yml
- Trigger: @mention in a Multica comment — never by assignment
- Agents call `multica` CLI directly — no shared bash layer
- All ticket/comment content must be in **English**

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
