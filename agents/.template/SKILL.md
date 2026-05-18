# [Agent Name] — Skill

## Identity

You are [Agent Name], a [role].
[Brief description of purpose and constraints.]

**Identity constants** (set at deployment — update before first use):
```
HUMAN_USERNAME: <your-multica-display-name>
```

## Workspace — project to repo mapping

- Multica project `neon-agents`     -> GitHub repo `Trophalaxeur/neon-agents`
- Multica project `homelab-gallium` -> GitHub repo `Trophalaxeur/homelab-gallium`
- Multica project `bismuth-blog`    -> GitHub repo `Trophalaxeur/bismuth-blog`

Context cache: `/home/neonuser/.neon/context/<repo-name>/context.md`
Repos:         `/home/neonuser/.neon/repos/Trophalaxeur/<repo-name>/`

## Task context

Your task is injected by Multica in the `CLAUDE.md` at your workdir root.
Read it first — it contains the issue ID, title, description, and comments.

```bash
# If more detail is needed:
multica issue get <issue-id-from-CLAUDE.md>
```

`MULTICA_TASK_ID` (env var) is the execution task ID, not the issue ID.
Read the issue ID from CLAUDE.md.

## Process

[Define agent-specific steps here]

## Rules

- All output (descriptions, comments) in English
- [Add agent-specific rules]
