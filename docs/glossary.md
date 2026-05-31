# Glossary

> *Reference — alphabetical definitions of all technical terms.*

| Term | Definition |
|---|---|
| **Acceptance Criteria (AC)** | A list of conditions that must all be satisfied for a ticket to be considered complete. Written by a refinement agent during the refinement step. Each AC item is tagged with its executor: 🤖 for automatable items, 👤 for items requiring human action. |
| **Agent** | An entity configured in Multica that ties together a Skill, an AI runtime, and a model. When triggered, the Multica daemon spawns an AI session using the attached Skill as instructions. See [concepts.md](concepts.md). |
| **`backlog`** | Default issue status when a ticket is created. Work has not started. |
| **`blocked`** | Issue status set when an agent cannot proceed — missing information, scope too large, or awaiting human input. Requires action before work can continue. |
| **`CLAUDE.md`** | (1) Project-level instructions file for AI agents, checked into each repo. Specific to the Claude Code runtime — only Claude Code reads and interprets it automatically. (2) A file injected by the Multica daemon into each task's workdir, containing the issue ID, title, description, and comments. Agents read this first. |
| **Context cache** | A set of per-repo Markdown files generated nightly by repomix. Stored at `/home/neonuser/.neon/context/<repo>/context.md`. Read by agents at execution time to understand the codebase without live GitHub access. |
| **`context.md`** | The output file of a repomix run for a given repository. Contains extracted and compressed content of key files (CLAUDE.md, README, package.json, workflows, etc.). |
| **cron job** | A scheduled task configured to run automatically at a fixed time, without manual intervention. The context builder runs as a cron job at 01:00 every night on neon. See [context-system.md](context-system.md). |
| **Daemon** | The `multica-daemon.service` process running on neon. Bridges Multica cloud and the LXC: receives dispatched tasks, creates workdirs, spawns AI sessions, and reports completion. |
| **`done`** | Issue status indicating that all AC items have been validated and the work is complete. |
| **Executability label** | A tag applied to each AC item by a refinement agent: `JeanMichelable` (automatable by committing to a repo) or `Human` (requires physical access, personal credentials, or manual UI interaction). |
| **`in_progress`** | Issue status indicating that an agent or human is actively working on the ticket. |
| **`in_review`** | Issue status indicating that a deliverable (e.g. a PR) is open and awaiting review. Set by execution agents — never by refinement agents. |
| **Issue** | A ticket in the Multica Kanban board. Has a title, description, status, assignee, and comments. Identified by an issue ID (e.g., `NA-42`). |
| **Issue ID** | The short identifier of a Multica ticket (e.g., `NA-42`). Read from `CLAUDE.md` in the workdir. Different from the task ID. |
| **JeanMichel team** | The collection of autonomous AI agents in this platform, each named JeanMichel\<Role\>. The suffix indicates the agent's domain: PO (Product Owner), Dev (developer), Tester, etc. See [vision.md](vision.md). |
| **`JeanMichelable`** | Executability label meaning the AC item can be completed by committing changes to a repository. Candidate for automation by a JeanMichel team agent. |
| **Kanban** | A visual project management board where work items (tickets) progress through columns representing stages. In this platform, Multica provides the Kanban board. Each column maps to an issue status: `backlog`, `todo`, `in_progress`, etc. |
| **LXC** | Linux Container — a lightweight virtualisation technology that runs an isolated Linux system on the same host kernel. Less overhead than a full virtual machine. `neon` runs as an LXC container on the Proxmox hypervisor. |
| **`multica-daemon.service`** | The systemd unit running the Multica daemon on neon. Process: `/usr/local/bin/multica daemon start --foreground`. Listens on `127.0.0.1:19514`. |
| **`MULTICA_TASK_ID`** | Environment variable injected by the daemon. Contains the **task** ID of the current execution — **not** the issue ID. Do not confuse the two. |
| **msmtp** | A minimal SMTP client for sending email from the command line. Used by agents to send notification emails to `<your-email>` after completing a task. |
| **neon** | The LXC container (Debian 13) on Proxmox node `gallium` that runs the Multica daemon and all AI sessions. |
| **`neonuser`** | The dedicated Linux user on neon under which all agent processes and cron jobs run. Home: `/home/neonuser/`. Never root. |
| **Proxmox** | An open-source server virtualisation platform. The homelab hypervisor running on the `gallium` machine, which hosts the LXC container `neon`. |
| **Pull Request (PR)** | A request to merge code changes from one branch into another on GitHub. Created by an execution agent after implementing the automatable AC items. Reviewed and approved before merging. |
| **repomix** | A CLI tool that bundles a repository into a single Markdown file for AI consumption. Uses Tree-sitter for code compression. See [context-system.md](context-system.md). |
| **Skill** | A Markdown file (`SKILL.md`) containing the instructions given to the AI runtime for a given agent. Lives in `agents/<name>/SKILL.md`. Version-controlled and imported into Multica. See [concepts.md](concepts.md). |
| **`SKILL.md`** | The file that defines a Skill. Contains five sections: Identity, Workspace mapping, Task context, Process, Rules. |
| **Task** | A single execution of an agent. Created when a trigger fires. Has its own lifecycle (`Queued → Dispatched → Running → Completed`), separate from the issue status. |
| **Task ID** | The internal Multica ID of a task execution. Available as `$MULTICA_TASK_ID`. Different from the issue ID. |
| **Thallium** | The operator's development machine (Arch Linux). Runs the `multica` CLI for ticket management and git for pushing code. No daemon. |
| **`todo`** | Issue status meaning the ticket is refined and ready to be picked up. Set by a refinement agent after a successful refinement, or manually by a human. |
| **Trigger** | The mechanism that starts an agent session: a `@mention` in a Multica comment. Assignment does not trigger agents. |
| **Workdir** | The ephemeral directory created per task by the daemon: `~/multica_workspaces/{workspace_id}/{task_id}/workdir/`. Contains `CLAUDE.md` and any files the agent creates during the session. Discarded after completion. |
| **Workspace** | The top-level organisational unit in Multica. "Mendeleiv Lab" contains all projects for this platform. |
