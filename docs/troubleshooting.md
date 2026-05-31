# Troubleshooting

> *How-to — diagnosing and fixing common problems.*
>
> Format: symptom → probable cause → diagnostic → fix.

---

## `@mention` in a CLI comment does not trigger the agent

**Symptom:** You ran `multica issue comment add <id> --content "@JeanMichelPO ..."`, but no
task appears in `multica issue runs <id>`. The ticket status is unchanged.

**Probable cause:** Mentions injected via the CLI do not always enqueue a new task. This is a
known limitation of Multica's @mention resolution when comments are created programmatically.

**Fix:**

```bash
multica issue rerun <issue-id>
```

This creates a new task directly, bypassing the mention mechanism. Use `rerun` whenever you want
to reliably re-dispatch an agent, whether from the CLI or after a failed session.

---

## Task stuck in `Dispatched` state

**Symptom:** `multica issue runs <id>` shows a task with status `Dispatched` that has not
moved to `Running` for more than a minute.

**Probable cause:** The daemon on neon is not responding to the dispatch.

**Diagnostic:**

```bash
# On neon or via CLI
multica daemon status
systemctl status multica-daemon   # on neon
```

**Fix:**

```bash
# Restart the daemon on neon
sudo systemctl restart multica-daemon
sudo systemctl status multica-daemon

# Then rerun the stuck task
multica issue rerun <issue-id>
```

---

## Daemon not responding / `multica daemon status` fails

**Symptom:** `multica daemon status` returns an error or shows `inactive`.

**Probable cause 1:** The daemon process crashed (bad task, OOM, etc.).

**Diagnostic:**

```bash
# On neon
journalctl -u multica-daemon -n 50 --no-pager
```

Look for error messages around the crash time.

**Fix:**

```bash
sudo systemctl restart multica-daemon
journalctl -u multica-daemon -f   # watch for restart errors
```

**Probable cause 2:** The daemon port `127.0.0.1:19514` is occupied by a leftover process.

**Diagnostic:**

```bash
# On neon
ss -tlnp | grep 19514
```

**Fix:** Kill the orphaned process, then restart the service.

---

## Context not rebuilt after a push

**Symptom:** An agent produces AC items that reference outdated or missing information from a
repo. The `context.md` for that repo has a stale modification time.

**Probable cause 1:** The nightly cron has not run yet (if the push was recent).

**Diagnostic:**

```bash
# On neon — check last build time
stat /home/neonuser/.neon/context/<repo>/context.md

# Check if there is a cron entry
crontab -l -u neonuser
```

**Fix:** Wait until 01:00, or force a rebuild immediately:

```bash
sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force
```

**Probable cause 2:** The nightly script failed. Check the log:

```bash
cat /home/neonuser/.neon/logs/context-nightly-$(date +%Y%m%d).log
```

Also check whether an email alert was sent to `<your-email>`.

---

## Authentication expired (CLI)

**Symptom:** Any `multica` CLI command returns `401 Unauthorized` or `authentication required`.

**Probable cause:** The OAuth token on Thallium has expired.

**Fix:**

```bash
# On Thallium
multica auth login   # opens OAuth flow in browser
multica auth status  # verify
```

If the daemon on neon also fails (unlikely — it uses `MULTICA_TOKEN` injected per task), check
the agent configuration in the Multica UI.

---

## Task timeout with no explicit error

**Symptom:** A task moves from `Running` to `Completed` but the ticket has not been updated.
Or the task stays in `Running` indefinitely.

**Probable cause:** The AI session ran for too long, encountered an infinite loop, or
exited without making any Multica API calls.

**Diagnostic:**

```bash
multica issue runs <issue-id>
# Check duration — unusually long or short suggests an anomaly

# On neon — check workdir for any output left behind
ls ~/multica_workspaces/<workspace-id>/<task-id>/workdir/
```

**Fix:**

1. Check the task stdout in the Multica UI (Agents → Tasks → `<task-id>`)
2. If the Skill has a logic bug, fix `SKILL.md`, push, and run:
   ```bash
   git -C /opt/neon-agents pull
   multica skill update <skill-id>
   multica issue rerun <issue-id>
   ```

---

## Context cache is missing for a repo

**Symptom:** Agent logs show `cat: /home/neonuser/.neon/context/<repo>/context.md: No such file`.

**Probable cause:** The repo was added to `config.yml` but the nightly script has not run since,
or the first run failed.

**Fix:**

```bash
# Force rebuild
sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force

# Verify
ls /home/neonuser/.neon/context/
```

Also verify the repo is cloned on neon:

```bash
ls /home/neonuser/.neon/repos/Trophalaxeur/
```

If the repo clone is missing, clone it manually and register the deploy key on GitHub.

---

## Agent produces incorrect or invented technical facts in AC

**Symptom:** The refined ticket references routes, components, field names, or configuration
values that don't exist in the codebase. The agent appears to have invented technical details
rather than reading them from the actual project.

**Probable cause:** The context cache for the relevant repository is stale or missing. The agent
fell back to guessing rather than reading verified facts from `context.md`.

**Diagnostic:**

```bash
# Check when the context was last built
stat /home/neonuser/.neon/context/<repo>/context.md

# Compare with the last commit in the repo
git -C /home/neonuser/.neon/repos/Trophalaxeur/<repo> log -1 --format="%ci %s"
```

If the context.md modification time predates recent commits, the cache is stale.

**Fix:**

```bash
# Force a full rebuild
sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force
```

Wait for the script to finish — the cache must be current before re-triggering. Then:

```bash
multica issue rerun <issue-id>
```

---

## Agent made the wrong decision (REFINE when it should have been UNCLEAR, etc.)

**Symptom:** The agent ran and completed, but its decision was wrong — it refined a ticket that
was missing critical information, or marked something UNCLEAR that was actually actionable.

**Probable cause 1:** The triggering instruction was ambiguous or missing. The agent applied its
default decision logic without specific guidance.

**Fix:** Re-trigger with an explicit instruction inline:

```bash
# Re-trigger with a corrective instruction
multica issue rerun <issue-id>
# OR add a new comment in Multica UI:
# "@JeanMiPO the previous refinement is incorrect — the target host is missing, mark UNCLEAR"
```

The agent accumulates all `@JeanMichelPO` instructions in chronological order. The latest
instruction wins on any conflict.

**Probable cause 2:** The Skill's decision conditions are ambiguous or not mutually exclusive,
causing the agent to pick the wrong branch.

**Fix:** Review the `## Process` section of the Skill, tighten the decision table conditions,
push the fix, and re-trigger:

```bash
git -C /opt/neon-agents pull
multica skill update <skill-id>
multica issue rerun <issue-id>
```

---

## Skill changes not taking effect

**Symptom:** You pushed a SKILL.md change and reran a task, but the agent still behaves as before.

**Probable cause:** `multica skill update` was not run after the push, so Multica is still using
the previous version.

**Fix:**

```bash
git -C /opt/neon-agents pull           # on neon
multica skill update <skill-id>         # from anywhere with CLI access
multica issue rerun <issue-id>          # re-dispatch
```

Confirm the skill version in the Multica UI under Agents → Skills → `<skill-name>`.
