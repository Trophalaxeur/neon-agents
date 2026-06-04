# Troubleshooting

> *Reference — known failure modes and how to resolve them.*

---

## Agent ran but produced no output

**Symptom:** task shows as `Completed` in Multica but the ticket description and comments are unchanged.

**Cause:** the agent exited without error but didn't reach its output step — usually a guard condition stopped it silently early (e.g., "already refined" check with no instruction found).

**Check:**
1. Look for a comment from the agent on the ticket — it should have posted one explaining why it stopped.
2. If no comment: check task logs → `multica issue runs <issue-id>` and inspect the last run.
3. If the agent detected an out-of-scope instruction, it posts a comment and stops. Verify the triggering @mention didn't contain an ambiguous instruction.

---

## Deploy key is read-only — push fails

**Symptom:** JeanMichelDev posts a `Blocked` comment saying `git push` failed with *"The key you are authenticating with has been marked as read only."*

**Cause:** the deploy key configured for the repo on GitHub is read-only (fetch only). JeanMichelDev needs write access to push branches.

**Resolution:**
1. Go to `https://github.com/Trophalaxeur/<repo>/settings/keys`
2. Find the deploy key used by neon (usually named `neon_deploy_<repo>`)
3. Check **"Allow write access"** and save
4. Re-trigger JeanMichelDev on the ticket: `multica issue rerun <issue-id>`

When JeanMichelDev is re-triggered, it checks for uncommitted changes first — if the previous run left a dirty working tree, Dev will stop and ask you to resolve it. Clean up by manually pushing or discarding the changes, then re-trigger. Dev will then detect the prior branch in comments with no associated PR (Priority 3 in branch detection) and **start a new branch** rather than resuming the old one.

---

## Rate limit hit mid-task

**Symptom:** agent comment says *"You've hit your limit · resets HH:MMpm (UTC)"* — task ends without completing its work.

**Cause:** the AI session hit the Claude API rate limit before finishing. All work done up to that point is lost unless it was already committed.

**What to check:**
- If the agent was in Proposer mode (JeanMichelArch): the ARCH section may be partially written or absent. Re-trigger after the rate limit resets.
- If the agent was in JeanMichelDev mode and had created a branch + committed locally but not pushed: the commit is in the local clone. A re-trigger will detect the uncommitted state and stop — you may need to manually push the branch or clean up first.

**Resolution:** wait for the rate limit to reset, then re-trigger: `multica issue rerun <issue-id>`.

---

## MULTICA_TASK_ID mistaken for issue ID

**Symptom:** agent calls `multica issue get $MULTICA_TASK_ID` and gets a 404 or wrong ticket.

**Cause:** `MULTICA_TASK_ID` is the execution task record ID, not the Multica issue ID. Every SKILL.md reads the issue ID from the injected `CLAUDE.md` in the workdir.

**Resolution:** this is a skill authoring bug. Check that the skill reads the issue ID from `CLAUDE.md` and not from the env var. See [index.md](index.md#what-happens-at-execution-time) for the distinction.

---

## Context cache is stale or absent

**Symptom:** agent cites facts that are outdated (references a file or function that no longer exists) — or posts an `[UNVERIFIED]` note on every AC item.

**Cause:** `context.md` wasn't rebuilt after the last push to the repo (build skipped because no change was detected, or the scheduler failed).

**Resolution:**
```bash
# Force rebuild for all repos
sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force

# Check last build timestamp (bottom of the file)
tail -3 /home/neonuser/.neon/context/<repo>/context.md
```

If the scheduler itself is failing, check the cron log:
```bash
ls -lt /home/neonuser/.neon/logs/
cat /home/neonuser/.neon/logs/context-nightly-<YYYYMMDD>.log
```

---

## context-dev.md missing for a repo

**Symptom:** JeanMichelArch falls back to `context.md` for a repo that should have targeted dev context, and notes it in a comment.

**Cause:** `dev_include` is not set for that repo in `agents/context-builder/config.yml`, or the context has never been built.

**Resolution:**
1. Add `dev_include` to the repo entry in `config.yml` (see [context-cache.md](../architecture/context-cache.md))
2. Force rebuild: `sudo -u neonuser bash /opt/neon-agents/scheduler/context-nightly.sh --force`

---

## Agent triggered but task never starts

**Symptom:** you posted the @mention, no task appears in `multica issue runs <id>`, and the ticket is unchanged.

**Possible causes:**
- The @mention handle is wrong (e.g., `@JeanMiPO` instead of `@JeanMichelPO` — check the agent's configured handle in Multica)
- The multica-daemon is stopped on neon: `multica daemon status`
- The task was created but is stuck in `Queued` state — check the Multica UI task queue

**Resolution:**
```bash
# Check daemon
multica daemon status
multica daemon logs

# Restart daemon if needed (on neon)
sudo systemctl restart multica-daemon

# Re-trigger explicitly (bypasses the @mention detection)
multica issue rerun <issue-id>
```

---

## Skill changes not taking effect

**Symptom:** you pushed a change to `SKILL.md` but the agent still behaves as before.

**Cause:** two things need to happen after a SKILL.md push, and both are often missed:

1. The LXC hasn't pulled the latest commit
2. Multica hasn't been told to reload the skill

**Resolution:**
```bash
# On neon
git -C /opt/neon-agents pull

# Then update each affected skill in Multica
multica skill update <skill-id>
```

Changes take effect on the **next** task. Any session currently running continues with the
version it started with.

Also verify the version bump: after any skill change, the `<!-- version: vX.Y.Z -->` header
and the version string in `## Version identification` must be incremented. See
[skill-authoring.md](skill-authoring.md#versioning) for the full procedure.

---

## Identifying which skill version an agent ran

Every agent comment and description section now starts with its version tag:
- Comments: `[JeanMichelPO v1.2.0] ...`
- Description sections: `_JeanMichelPO v1.2.0_` at the top of the PO block

If the version shown in a comment differs from the `<!-- version: -->` header in the current
`SKILL.md`, the deployed skill is stale → run `multica skill update <skill-id>`.
