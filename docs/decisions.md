# Design decisions

> *Explanation — why the platform works the way it does.*
>
> This page indexes the key architectural decisions made while building neon-agents. Each entry
> states the decision, the alternatives that were evaluated, and links to the file where the
> full rationale is documented.

---

## Why Multica instead of GitHub Projects

**Decision:** Use Multica as the Kanban board and agent orchestration layer.

**Context:** The original design used GitHub Projects v2 as the Kanban. It worked as a board
but had no concept of an agent runtime — spawning AI sessions, injecting context, and managing
task lifecycle all had to be built from scratch. Multica provides this natively.

**Alternatives evaluated:**
- GitHub Projects v2 + custom Bash/Python scripts + systemd timer *(original design, dropped)*
- Multica self-hosted via Docker Compose *(attempted, abandoned — SMTP dependency, SSH tunnel required for UI)*
- GitHub Actions *(functional but not homelab-hosted)*
- Custom agent service *(too heavy for a first version)*

**Full rationale:** [multica.md — Why Multica](multica.md#why-multica)

---

## Why Multica cloud instead of self-hosted

**Decision:** Use multica.ai (cloud) for the Kanban and orchestration, keep the daemon local.

**Context:** Multica offers both a cloud version and a self-hosted Docker Compose option. The
self-hosted path was attempted first to keep everything on the homelab. It failed before
reaching the first login: mandatory SMTP server dependency, UI inaccessible without SSH tunnel.

**Trade-off accepted:** The Kanban state lives on an external service. Acceptable because
`neon-agents` is a public repository — no secrets, no private code, no personal data flow
through Multica.

**Full rationale:** [multica.md — Stage 3 & Stage 4](multica.md#stage-3--self-hosted-attempt)

---

## Why the workspace mapping lives in each Skill

**Decision:** Embed the Multica project → GitHub repo mapping inside every `SKILL.md` rather
than in a shared config file or environment variables.

**Alternatives evaluated:**
- Central config file read at runtime *(shared mutable dependency — single point of failure)*
- Environment variables set per-project in Multica *(duplicated across agents, hard to audit)*
- Hard-coded in Skill logic *(less explicit)*

**Trade-off accepted:** When a new repository is added, all deployed Skills must be updated.
This is an infrequent operation with a documented procedure.

**Full rationale:** [agents/skill-authoring.md — Why the mapping lives in each Skill](agents/skill-authoring.md#why-the-mapping-lives-in-each-skill)

---

## Why Claude Code CLI instead of the Anthropic API

**Decision:** Run AI sessions via the Claude Code CLI (flat subscription billing) rather than
direct Anthropic API calls (per-token billing).

**Context:** At current session volume, all agent executions fit within the Claude subscription
plan at zero marginal cost. The Anthropic API would bill per token, adding up quickly with
frequent agent runs.

**Migration path:** If session volume grows significantly, switching to API tokens is a Multica
agent configuration change — the Skill files and platform architecture are runtime-agnostic.

**Full rationale:** [architecture.md — AI runtime](architecture.md#ai-runtime)

---

## Why a nightly context cache instead of live repo access

**Decision:** Build a compressed Markdown snapshot of each repository once per night and serve
it as a static read-only file to agents at execution time.

**Alternatives evaluated:**
- Live GitHub API access per session *(token management, rate limits, latency, scope creep)*
- No repo access — agent works from ticket alone *(agent invents technical facts)*

**Core insight:** Repository structure does not change hourly. Building the context once and
reusing it across all sessions that day eliminates per-execution token cost for repo parsing.

**Full rationale:** [context-system.md — The problem](context-system.md#the-problem)

---

## Why agents communicate via ticket comments, not direct calls

**Decision:** Agents hand off work by mentioning the next agent in a closing Multica comment.
No agent has a direct connection to any other agent.

**Alternatives evaluated:**
- Direct API calls between agents *(hard coupling — changing one agent breaks others)*
- A shared message queue *(additional infrastructure, overkill for current scale)*

**Benefits:** The pipeline is fully auditable (every handoff is a visible comment), resilient
(agents are independent — one failing does not crash others), and extensible (adding an agent
requires no changes to existing agents).

**Full rationale:** [vision.md — Multica as the message bus](vision.md#multica-as-the-message-bus)

---

## Why @mention triggers instead of assignment

**Decision:** Agents are triggered exclusively by `@mention` in a Multica comment, not by
assigning the ticket to the agent.

**Rationale:** Assignment is a human workflow signal ("this is now your responsibility"). It is
not repeatable (assigning the same agent twice does nothing) and cannot carry inline instructions.
`@mention` is explicit, repeatable, and supports inline context: `@JeanMiPO focus on mobile only`.

**Full rationale:** [concepts.md — Trigger mechanism](concepts.md#trigger-mechanism)
