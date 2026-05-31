# Operations

> *How-to — day-to-day commands for operating neon-agents.*
>
> Format: what you need → command → expected output.
>
> For diagnosing failures, see [troubleshooting.md](troubleshooting.md).

---

## Quick reference

| Task | Command |
|---|---|
| Check daemon health | `multica daemon status` |
| View daemon logs | `multica daemon logs` |
| Force rebuild all contexts | `sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force` |
| Rerun a stuck/failed ticket | `multica issue rerun <issue-id>` |
| View execution history | `multica issue runs <issue-id>` |
| Update a deployed skill | `git -C /opt/neon-agents pull && multica skill update <skill-id>` |
| Check CLI auth | `multica auth status` |

---

## Daemon

### Check daemon status

Run from Thallium (CLI) or on neon:

```bash
multica daemon status
```

From neon directly:

```bash
systemctl status multica-daemon
```

Expected: `active (running)`. If `inactive` or `failed`, see [troubleshooting.md](troubleshooting.md).

### View live logs

```bash
# Via Multica CLI (from Thallium or neon)
multica daemon logs

# Via journald (on neon)
journalctl -u multica-daemon -f
```

Logs show task dispatches, session starts/completions, and errors.

### Restart the daemon

```bash
# On neon
sudo systemctl restart multica-daemon
sudo systemctl status multica-daemon
```

After a restart, in-flight tasks are dropped. Any task stuck in `Running` or `Dispatched` will
need a manual rerun.

---

## Context cache

### Force rebuild all repos

Useful after changing include globs in `config.yml`, or after a repomix upgrade:

```bash
# Run as neonuser on neon
sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force
```

The script self-updates `/opt/neon-agents` first, then rebuilds each repo's `context.md`.
If the rebuild fails, see [troubleshooting.md](troubleshooting.md#context-not-rebuilt-after-a-push).

### Rebuild a single repo manually

```bash
# On neon, as neonuser
REPO=bismuth-blog
repomix \
  --include "CLAUDE.md,README.md,package.json,pyproject.toml,Makefile,.eslintrc*,.stylelintrc*,.prettierrc*,.github/workflows/*.yml" \
  --style markdown --compress \
  --output "/home/neonuser/.neon/context/${REPO}/context.md" \
  "/home/neonuser/.neon/repos/Trophalaxeur/${REPO}"
```

### Inspect a context file

```bash
# On neon
cat /home/neonuser/.neon/context/bismuth-blog/context.md | head -100

# Check last build time
stat /home/neonuser/.neon/context/bismuth-blog/context.md
```

### View nightly logs

```bash
# On neon — today's log
cat /home/neonuser/.neon/logs/context-nightly-$(date +%Y%m%d).log

# List available logs
ls /home/neonuser/.neon/logs/
```

---

## Tickets and agents

### Create a ticket

```bash
# From Thallium
multica issue create \
  --project bismuth-blog \
  --title "Add RSS feed to the blog"
```

Returns the issue ID (e.g., `BB-12`).

### Trigger an agent

The primary trigger is a `@mention` in a comment via the Multica UI.

To trigger programmatically (reliable — use this for scripting or re-triggers):

```bash
multica issue rerun <issue-id>
```

> **Note:** adding a `@mention` via `multica issue comment add` does **not** always enqueue a
> new task. Always use `multica issue rerun` to reliably re-dispatch.

### View execution history for a ticket

```bash
multica issue runs <issue-id>
```

Shows all task executions for that ticket: task ID, status, start time, duration.

### View detailed output of a specific run

```bash
multica issue runs <issue-id>
# Note the task ID from the output, then:
# (Use Multica UI → Agents → Tasks → <task-id> for full stdout)
```

### Check CLI authentication

```bash
multica auth status
```

If expired: `multica auth login` (OAuth flow in the browser on Thallium).

### Verify a successful agent run

After triggering an agent, confirm it completed as expected.

**1. Check task status:**

```bash
multica issue runs <issue-id>
```

Expected: most recent task shows `Completed`. `Failed` or a task stuck in `Running` for
more than a few minutes means something went wrong — see [troubleshooting.md](troubleshooting.md).

**2. View full task output:**

In the Multica UI: **Agents → Tasks → \<task-id\>**

The complete stdout of the AI session is available here. Useful for understanding what the
agent decided and why.

**3. Confirm the ticket was updated:**

```bash
multica issue get <issue-id>
```

For JeanMichelPO: the description should now contain the refined spec (`## Summary`,
`## Acceptance Criteria`, etc.) and the status should be `todo`.

**4. Check the email notification:**

An email with subject `[Multica] <KEY> — Refined [JeanMichelable]` (or similar) should have
arrived at `<your-email>`.

---

## Skills

### Update a deployed skill after pushing changes

When a `SKILL.md` is modified and pushed to GitHub:

```bash
# 1. Pull the latest platform on neon
git -C /opt/neon-agents pull

# 2. Update the skill in Multica (from Thallium or neon)
multica skill update <skill-id>
```

The skill ID is visible in the Multica UI under Agents → Skills.

New skill content takes effect on the **next** task. Running sessions are not affected.
If changes don't take effect, see [troubleshooting.md](troubleshooting.md#skill-changes-not-taking-effect).

### Find a skill ID

```bash
multica skill list
```

Returns a table of all imported skills with their name, ID, and last-updated timestamp:

```
NAME             ID                  UPDATED
JeanMichelPO     skill_abc123...     2026-05-24T10:30:00Z
```

The `ID` column is what to pass to `multica skill update <id>`.

---

## Access

| Resource | Value |
|---|---|
| Multica UI | [https://multica.ai](https://multica.ai) |
| Workspace | Mendeleiv Lab |
| LXC neon IP | `<neon-ip>` |
| SSH | `ssh neonuser@<neon-ip>` *(local network only)* |
| Platform path | `/opt/neon-agents/` |
| System user | `neonuser` |
