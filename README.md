# neon-agents

Platform hosting AI agents orchestrated by [Multica](https://multica.ai).

📖 **Full documentation:** [docs/](docs/)

---

## Tech stack

- **[Multica](https://multica.ai)** — agent orchestration + Kanban (cloud UI at multica.ai, daemon on homelab)
- **[Claude Code](https://claude.ai/code)** — AI runtime (CLI, spawned per task by the Multica daemon)
- **Proxmox** — homelab hypervisor (node `gallium`, LXC `neon`)
- **[repomix](https://github.com/yamadashy/repomix)** — nightly context extraction for each repo

---

## Architecture

See [docs/architecture.md](docs/architecture.md) for diagrams and a full component breakdown.

---

## Agents

| Name | Nickname | Role | Trigger |
|---|---|---|---|
| JeanMichelPO | JeanMiPO | Product Owner — refines tickets | `@JeanMiPO` in a Multica comment |

---

## Main commands

```bash
# Create a ticket
multica issue create --project bismuth-blog --title "My feature"
# Then trigger the agent by adding a comment with @JeanMiPO in the Multica UI

# Re-trigger an agent (reliable alternative to @mention from CLI)
multica issue rerun <issue-id>

# View execution history for a ticket
multica issue runs <issue-id>

# Daemon status / logs
multica daemon status
multica daemon logs

# Force rebuild all context files
sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force

# Update a skill after pushing SKILL.md changes
git -C /opt/neon-agents pull && multica skill update <skill-id>

# Check auth
multica auth status

# Multica UI
# → https://multica.ai
```

---

## Adding an agent

See [docs/agents/skill-authoring.md](docs/agents/skill-authoring.md) for the complete guide.

Quick steps:
1. Copy `agents/.template/SKILL.md` → `agents/<name>/SKILL.md`
2. Customize identity, process, and rules sections
3. Commit and push to this repo
4. In Multica: Agents → Skills → Import from GitHub
5. Create the agent, attach the skill

## Adding a project (repo)

See [docs/agents/skill-authoring.md#adding-a-new-repository](docs/agents/skill-authoring.md#adding-a-new-repository).

---

## License

[CC BY-NC 4.0](LICENSE)
