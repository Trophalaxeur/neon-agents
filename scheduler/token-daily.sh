#!/usr/bin/env bash
# token-daily.sh — Daily token usage report for neon agents
# Cron (neonuser): 0 7 * * * /opt/neon-agents/scheduler/token-daily.sh

set -euo pipefail

ADMIN_EMAIL="${NEON_ADMIN_EMAIL:-admin@flefevre.fr}"
PROJECTS_DIR="/home/neonuser/.claude/projects"
REPORT_DATE=$(date -d "yesterday" +%Y-%m-%d)
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

AGENT_IDS=(
  "0785e567-9b4b-46c8-8816-81886aa672f4"
  "4fc1abc0-c326-4798-831c-59211296207b"
)

for ID in "${AGENT_IDS[@]}"; do
  multica agent tasks "$ID" --output json > "$WORK_DIR/${ID}.json" 2>/dev/null \
    || echo "[]" > "$WORK_DIR/${ID}.json"
done

python3 - "$REPORT_DATE" "$PROJECTS_DIR" "$WORK_DIR" "$ADMIN_EMAIL" <<'EOF'
import json, glob, sys, subprocess

report_date, projects_dir, work_dir, admin_email = sys.argv[1:]

# Pricing (USD/token) — Sonnet 4.6
P = {
    'input':       3e-6,
    'cache_write': 3.75e-6,
    'cache_read':  0.3e-6,
    'output':      15e-6,
}

AGENTS = [
    ("0785e567-9b4b-46c8-8816-81886aa672f4", "JeanMichelPO"),
    ("4fc1abc0-c326-4798-831c-59211296207b", "JeanMichelDev"),
]

def parse_session(session_id):
    matches = glob.glob(f"{projects_dir}/**/{session_id}.jsonl", recursive=True)
    if not matches:
        return None
    inp = cw = cr = out = 0
    with open(matches[0]) as f:
        for line in f:
            obj = json.loads(line)
            if obj.get('type') == 'assistant':
                u = obj.get('message', {}).get('usage', {})
                inp += u.get('input_tokens', 0)
                cw  += u.get('cache_creation_input_tokens', 0)
                cr  += u.get('cache_read_input_tokens', 0)
                out += u.get('output_tokens', 0)
    return inp, cw, cr, out

def compute_cost(inp, cw, cr, out):
    return inp*P['input'] + cw*P['cache_write'] + cr*P['cache_read'] + out*P['output']

lines = []
grand_total = 0.0
any_task = False

for agent_id, agent_name in AGENTS:
    with open(f"{work_dir}/{agent_id}.json") as f:
        tasks = json.load(f)

    day_tasks = [
        t for t in tasks
        if t.get('created_at', '').startswith(report_date)
        and (t.get('result') or {}).get('session_id')
    ]
    if not day_tasks:
        continue

    any_task = True
    lines.append(f"{agent_name}")
    lines.append("─" * 44)

    for t in day_tasks:
        sid    = t['result']['session_id']
        issue  = str(t.get('issue_id') or '?')[:8]
        status = t.get('status', '?')
        duration_s = None
        if t.get('started_at') and t.get('completed_at'):
            from datetime import datetime
            fmt = "%Y-%m-%dT%H:%M:%SZ"
            try:
                d = int((datetime.strptime(t['completed_at'], fmt) -
                         datetime.strptime(t['started_at'], fmt)).total_seconds())
                duration_s = f"{d}s"
            except ValueError:
                pass

        usage = parse_session(sid)
        if usage is None:
            lines.append(f"  issue={issue}  status={status}  ⚠ session JSONL not found on disk")
            lines.append("")
            continue

        inp, cw, cr, out = usage
        c = compute_cost(inp, cw, cr, out)
        grand_total += c

        total_in = inp + cw + cr
        cache_pct = int(cr / total_in * 100) if total_in else 0

        lines.append(f"  issue={issue}  status={status}" +
                      (f"  duration={duration_s}" if duration_s else ""))
        lines.append(f"    input={inp:>8,}  cache_write={cw:>8,}  "
                     f"cache_read={cr:>8,}  output={out:>6,}")
        lines.append(f"    cache_hit={cache_pct:>3}%  cost=${c:.4f}")
        lines.append("")

    lines.append("")

if not any_task:
    lines.append(f"No agent tasks recorded on {report_date}.")
    lines.append("")

lines.append("─" * 44)
lines.append(f"Total cost: ${grand_total:.4f}")
lines.append("")
lines.append("Pricing: Sonnet 4.6")
lines.append("  input $3/MTok  |  cache_write $3.75/MTok  |  "
             "cache_read $0.30/MTok  |  output $15/MTok")

body    = "\n".join(lines)
subject = f"[neon] Token usage — {report_date}  (${grand_total:.4f})"

subprocess.run(
    ["msmtp", admin_email],
    input=f"To: {admin_email}\nSubject: {subject}\n\n{body}".encode(),
    check=True,
)
print(f"Sent: {subject}")
EOF
