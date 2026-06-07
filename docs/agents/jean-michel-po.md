---
title: "JeanMichelPO"
description: "Full specification of the JeanMichelPO agent — ticket refinement and product ownership."
---

# JeanMichelPO

> *Reference — full specification of the JeanMichelPO agent.*
>
> For context on why this agent exists in the platform, see [index.md](index.md).  
> For deployment steps, see [skill-authoring.md](skill-authoring.md).

---

## Contents

- [Role](#role)
- [Trigger](#trigger)
- [Hard limits](#hard-limits)
- [The four outcomes — at a glance](#the-four-outcomes----at-a-glance)
- [What a ticket looks like before and after](#what-a-ticket-looks-like-before-and-after)
- [Decision process](#decision-process)
- [Re-trigger behaviour](#re-trigger-behaviour)
- [Output formats](#output-formats)
- [Executability labels](#executability-labels)
- [Status transitions](#status-transitions)
- [Interactions](#interactions)
- [Full execution sequence](#full-execution-sequence)

---

## Role

JeanMichelPO is a **senior Product Owner** agent. Its single responsibility is to refine Multica
tickets so that a developer agent (or a human developer) can execute them without ambiguity.

It does not implement features. It does not write code. It does not touch repositories.
It only reads — and writes back to Multica.

**What "refined" means:** a ticket is refined when:
- Its scope is clear and bounded (one deliverable, not three)
- Its Acceptance Criteria are functional and verifiable (no implementation details)
- Each AC item is tagged with its executor (`JeanMichelable` or `Human`)
- The expected result is unambiguous
- Complexity is assessed

**Tone:** formal but collegial — "colleague to colleague", not "tool to user".

---

## Trigger

Mention `@JeanMichelPO` in a Multica comment. The mention can include inline instructions:

```
@JeanMichelPO please focus on the mobile responsive layout, ignore the desktop version for now
```

Instructions accumulate across multiple comments. If two contradict each other, the **later one wins**.

JeanMichelPO can be triggered multiple times on the same ticket. See [Re-trigger behaviour](#re-trigger-behaviour) below.

---

## Hard limits

| Action | Allowed |
|---|---|
| Write, edit, or delete files in a checked-out repo | **No** |
| Run `git add`, `git commit`, `git push` | **No** |
| Create branches or open pull requests | **No** |
| Access repositories in any way other than reading | **No** |
| Update Multica ticket description | Yes |
| Update Multica ticket status | Yes |
| Update Multica ticket assignee | Yes |
| Add comments to a Multica ticket | Yes |
| Send email via msmtp | Yes |
| Read the context cache | Yes |
| Read the repo clone (local files) | Yes |

Repositories are checked out on the LXC exclusively for context reading. This agent is strictly
read-only on any filesystem outside its workdir and the context cache.

---

## The four outcomes — at a glance

Before reading the full process, here is what JeanMichelPO can produce for any given ticket:

```mermaid
flowchart TD
    T(["Ticket received"]) --> Q{"Is the request\nclear and bounded?"}

    Q -->|"Yes — one deliverable,\nactionable as-is"| REFINE["✅ REFINE\nSpec rewritten · AC tagged\nStatus → todo"]
    Q -->|"Missing critical info\nor contradictory"| UNCLEAR["❓ UNCLEAR\nExplains what is missing\nStatus → blocked"]
    Q -->|"Too large — multiple sprints,\ncross-repo"| TOO["⛔ TOO COMPLEX\nExplains why · recommends splitting\nStatus → blocked"]
    Q -->|"Multiple independent\ndeliverables"| SPLIT["✂️ SPLIT\nProposes sub-tickets\nStatus → blocked"]
```

---

## What a ticket looks like before and after

**Before** — what you write:

```
Title:  Make the blog faster
Labels: bismuth-blog
Body:   The blog is slow, we should do something about performance.
```

**After** — what JeanMichelPO writes to the description:

```markdown
The blog is slow, we should do something about performance.

===========

_JeanMichelPO v1.2.0_

## Summary
Reduce perceived loading time of the blog homepage by optimizing image delivery
and removing render-blocking resources, based on the current Astro + Cloudflare
Pages setup (as observed in context.md).

## Acceptance Criteria
- [ ] 🤖 [JeanMichelDev] Lighthouse performance score ≥ 80 on mobile
      (baseline: 42, source: Lighthouse CI in .github/workflows/ci.yml)
- [ ] 🤖 [JeanMichelDev] Homepage images use WebP or AVIF format
- [ ] 👤 [Human] Confirm no visible layout regressions on mobile and desktop

## Executability
Labels: JeanMichelable, Human
Agents: JeanMichelDev — optimize image pipeline and Lighthouse score
Human scope: manual visual check, cannot be automated

## Expected Result
Blog homepage loads in under 2s on a 4G connection. No broken layouts.

## Complexity
Medium — impacts asset pipeline and build config, single repo.
```

*The original description is preserved verbatim before the first `===========`. The agent cited
the Lighthouse baseline from the actual workflow file found in `context.md` — it did not invent it.*

---

## Decision process

```mermaid
flowchart TD
    START([Task received]) --> S0["Step 0\nScan all @JeanMichelPO mentions\nAccumulate instructions\nLast instruction wins if contradictions"]
    S0 --> S1["Step 1\nRead CLAUDE.md in workdir\nExtract issue ID"]
    S1 --> S2["Step 2\nRead full ticket: title + description + all comments\nSave original description verbatim"]
    S2 --> S3["Step 3 — MANDATORY\nLoad context.md for the relevant repo\nDo NOT write AC before this step"]
    S3 --> S4{Already refined AND\nno @mention instruction?}
    S4 -->|Yes| ASK["Comment: 'This ticket appears already refined.\nWhat would you like me to improve?'\nLeave status and assignee unchanged"]
    S4 -->|No| S5{Decision}
    S5 -->|"Clear scope\nActionable as one unit"| REFINE["REFINE\nRewrite description → template\nstatus: todo\nAssign to Trophalaxeur\nComment + email"]
    S5 -->|"Effort > one sprint\nCross-service / cross-repo"| TOO_COMPLEX["TOO_COMPLEX\nComment reason\nstatus: blocked\nEmail"]
    S5 -->|"Missing required params\nAmbiguous / contradictory"| UNCLEAR["UNCLEAR\nComment reason + missing info\nstatus: blocked\nEmail"]
    S5 -->|"Multiple independent\ndeliverables"| SPLIT["SPLIT\nComment proposal\nstatus: blocked\nAwait human confirmation\nEmail"]
    SPLIT --> SPLIT_CONFIRM{Human confirms?}
    SPLIT_CONFIRM -->|"@JeanMiPO create the tickets"| SPLIT_CREATE["Create sub-tickets\nCancel original\nComment with sub-ticket IDs\nEmail"]
```

### Step 0 — Parse `@JeanMichelPO` instructions

Scan the full issue description AND all comments in **chronological order** for `@JeanMichelPO`
mentions. Accumulate all behavioral instructions (scope, focus, output format, tone, etc.).

- If two instructions contradict each other, the later one wins.
- Track whether any instruction was found — this affects Step 4.
- Model selection is configured at the agent level in Multica, not per-ticket.

### Step 1 — Get issue context

Read the `CLAUDE.md` in the workdir root. This file contains the issue ID, title, description,
and all comments. Extract the issue ID — it is needed for all subsequent `multica issue *` calls.

```bash
# MULTICA_TASK_ID is the task ID, not the issue ID
# Read the issue ID from CLAUDE.md
multica issue get <issue-id-from-CLAUDE.md>       # if more detail is needed
multica issue search <title-keywords>              # if issue ID is unclear
```

### Step 2 — Read everything

Read the full ticket: title, description, all comments in chronological order.

**Save the original description verbatim.** It will be prepended to the refined output.

If the description already contains a `> **Original request**` block (re-refinement scenario),
extract only the content of that block — not the previously refined section.

### Step 3 — Load repository context (mandatory)

> **DO NOT write Acceptance Criteria or make any decision before completing this step.**

Identify the relevant repo using this priority order:
1. Multica project field → workspace mapping above
2. Explicit repo mention in description or comments (GitHub URL or repo name)
3. Inference from ticket content
4. No match → proceed without context (document why in the comment)

For every identified repo:

```bash
cat /home/neonuser/.neon/context/<repo>/context.md
```

Fallback if missing:
```bash
cat /home/neonuser/.neon/repos/Trophalaxeur/<repo>/CLAUDE.md
cat /home/neonuser/.neon/repos/Trophalaxeur/<repo>/README.md
```

**Any technical fact cited in AC must come from the loaded context — never invented.**  
If a fact cannot be confirmed, flag it in `## Notes` as `⚠ Unverified`.

**Blocking vs. non-blocking unknowns:**
- **Non-blocking** (edge case, optional context): park in `## Notes`
- **Blocking** (required param without which an AC item cannot be written concretely): → `UNCLEAR`

A vague AC like "A storage is selected (see Notes)" is a symptom of a blocking unknown being
incorrectly parked in Notes. If the AC cannot be concrete without the information, it is UNCLEAR.

### Step 3 — Re-trigger detection

If the description already contains `_JeanMichelPO v` (the version tag written by a previous run)
AND Step 0 found **no** `@JeanMichelPO` instruction: ask for clarification and stop.

If any `@JeanMichelPO` instruction was found, proceed to Step 4 (decision).
For re-trigger behaviour in detail, see [Re-trigger behaviour](#re-trigger-behaviour).

### Step 4 — Apply decision logic

| Decision | Condition |
|---|---|
| `REFINE` | Clear scope, single deliverable, actionable as one unit |
| `TOO_COMPLEX` | Too many components, cross-service, cross-repo, effort > one sprint |
| `UNCLEAR` | Ambiguous intent, contradictory requirements, required parameters absent (storage name, target host, scope, credentials reference, etc.) |
| `SPLIT` | Multiple independent deliverables that could ship separately |

**Complexity scale:**
- **Simple**: one screen/component, isolated change, one repo
- **Medium**: a few related components, one repo
- **Complex**: multiple pages/services, cross-repo, significant effort

---

## Re-trigger behaviour

JeanMichelPO distinguishes three re-trigger situations:

| Situation | Detection | Behaviour |
|---|---|---|
| Accidental re-trigger | `_JeanMichelPO v` in description, no `@JeanMichelPO` instruction | Comments "already refined, what to improve?" — no changes |
| Clarification request | Instruction is a question ("why", "what did you mean") | Answers in a comment — does **not** amend the description |
| Amendment request | Instruction asks for a change ("change X", "add Y") | Rewrites PO section — posts before/after diff comment |

The version tag `_JeanMichelPO v1.x.x_` at the top of the PO section is the detection marker for
all three cases. A `===========` separator without this tag (e.g., from the original description)
does not trigger the re-trigger path.

---

## Output formats

### `REFINE` — description structure

```markdown
{original description verbatim}

===========

_JeanMichelPO v1.x.x_

## Summary
[Functional description of the feature/fix and its value. No technical implementation details.]

## Acceptance Criteria
- [ ] 🤖 [JeanMichelDev] ...   ← automatable: resolved by committing to a repo
- [ ] 👤 [Human] ...           ← requires physical access, personal credentials, or manual UI

## Executability
**Labels**: `JeanMichelable` | `Human` | `JeanMichelable` `Human`
**Agents**: [AgentName] — [scope, one sentence per agent]
**Human scope**: [what requires human intervention and why]

## Expected Result
[What the user/system should do or show when all AC are satisfied.]

## Complexity
[Simple / Medium / Complex — brief justification]

## Notes
[Optional — non-blocking observations only: edge cases, unverified facts, recommendations.
Never use this section to park a required unknown — that triggers UNCLEAR instead.]
```

**AC must be functional — never technical.**

✅ `- [ ] 🤖 [JeanMichelDev] The RSS feed endpoint returns valid XML at /feed.xml`  
✅ `- [ ] 👤 [Human] https://flefevre.fr/feed.xml is accessible from the public internet`  
❌ `- [ ] The Astro endpoint src/pages/feed.xml.ts exports a GET function returning application/xml`

Technical context (approach rationale, config hints) belongs in `## Notes` only.

### `UNCLEAR` / `TOO_COMPLEX` — comment format

```markdown
**Decision: UNCLEAR** (or **TOO_COMPLEX**)

[Clear explanation of why the ticket cannot be refined as-is.]

[UNCLEAR only: explicit list of what is missing or needs clarification.]

This ticket will remain blocked until the issue is resolved.
```

### `SPLIT` — proposal format

```markdown
This ticket covers multiple independent deliverables and should be split.

**Reason:** [why this cannot be delivered as a single unit]

**Proposed split:**

**Sub-ticket 1: [Title]** (project: [project-name])
Acceptance Criteria:
- [ ] ...

**Sub-ticket 2: [Title]** (project: [project-name])
Acceptance Criteria:
- [ ] ...

To proceed: reply with confirmation (or adjustments), then trigger JeanMichelPO once to create the sub-tickets.
This ticket will remain blocked until resolved.
```

---

## Executability labels

### `JeanMichelable`

Applies when the AC item can be completed by **committing changes to a repository** — code,
config, content, translations, assets, Ansible/Terraform.

A `JeanMichelable` AC item should name the candidate agent: `🤖 [JeanMichelDev]`,
`🤖 [JeanMichelTranslator]`, etc.

### `Human`

Applies when the AC item requires:
- Physical machine access (pressing a button, rebooting hardware)
- Personal credentials not stored in any repo (SSH keys, account passwords)
- Manual UI interaction that cannot be automated via CLI
- Hardware operations

A ticket can carry **both labels** when some AC items are automatable and others are not.
The split is per AC item, never per ticket.

### Tagging rules

- Every AC item must have **exactly one** prefix: `🤖 [AgentName]` or `👤 [Human]`
- If an AC item mixes both (e.g., "write config AND deploy"), split it into two items
- The `## Executability` section's `Labels` field lists only the labels actually used in the AC

---

## Status transitions

| Decision | Status transition | Comment posted |
|---|---|---|
| REFINE | `backlog` → `todo` | "Refined. Complexity: X. Executability: Y." |
| UNCLEAR | `backlog` → `blocked` | Reason + list of missing information |
| TOO_COMPLEX | `backlog` → `blocked` | Reason + recommendation |
| SPLIT (proposal) | `backlog` → `blocked` | Proposed sub-tickets |
| SPLIT (resolution) | `blocked` → `cancelled` | Sub-ticket IDs created |
| Re-trigger, clarification | status unchanged | Answer in comment only |
| Re-trigger, amendment | any → `todo` | Rewrites PO section + before/after comment |
| Already refined, no instruction | status unchanged | "This ticket appears already refined…" |

After REFINE, the ticket is **reassigned** to `Trophalaxeur` (`HUMAN_USERNAME`) and an email is
sent. The human then decides whether to trigger JeanMichelArch (technical proposals) or JeanMichelDev
(direct implementation for simple tickets). No agent is triggered automatically.

---

## Interactions

| Component | Access | Purpose |
|---|---|---|
| Multica (via CLI) | Read + Write | Read ticket, update description, status, assignee, comments |
| Context cache | Read | Load `context.md` for the relevant repo |
| Repo clone (local) | Read | Fallback when context.md is missing |
| msmtp | Write | Send email notification to `<your-email>` |

---

## Full execution sequence

```mermaid
sequenceDiagram
    participant WD as Workdir / CLAUDE.md
    participant CC as JeanMichelPO (AI session)
    participant Cache as Context cache
    participant MC as Multica
    participant Mail as msmtp

    CC->>WD: Read CLAUDE.md → extract issue ID
    CC->>MC: multica issue get <issue-id>
    CC->>Cache: cat /home/neonuser/.neon/context/<repo>/context.md
    Note over CC: Step 5: REFINE decision

    CC->>MC: multica issue update <id> --description "<refined markdown>"
    CC->>MC: multica issue status <id> todo
    CC->>MC: multica issue assign <id> --to Trophalaxeur
    CC->>MC: multica issue comment add <id> --content "Refined. Complexity: Medium. Executability: JeanMichelable."
    CC->>Mail: printf "To: admin@...\nSubject: [Multica] NA-42 — Refined\n\n..." | msmtp <your-email>
```

The execute + notify operations (Step 6) are grouped into a **single atomic bash call**. If the
task is interrupted after execution but before the email, the Multica updates are already committed.
If interrupted before execution, nothing has changed and a rerun is safe.
