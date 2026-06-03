#!/usr/bin/env bash
set -e  # exit on first error — triggers trap ERR and sends failure email

CONFIG=/opt/neon-agents/agents/context-builder/config.yml
REPOS_DIR=/home/neonuser/.neon/repos/Trophalaxeur
CONTEXT_DIR=/home/neonuser/.neon/context
LOG=/home/neonuser/.neon/logs/context-nightly-$(date +%Y%m%d).log
ADMIN_EMAIL="${NEON_ADMIN_EMAIL:-admin@flefevre.fr}"
INCLUDE_GLOBS="CLAUDE.md,README.md,package.json,pyproject.toml,Makefile,.eslintrc*,.stylelintrc*,.prettierrc*,.github/workflows/*.yml"
FAILED_REPO=""

trap 'echo "context-nightly.sh failed at $(date)${FAILED_REPO:+ for repo: $FAILED_REPO}" | \
  mail -s "[neon] context build FAILED" "$ADMIN_EMAIL"' ERR

# Step 0: self-update the platform
git -C /opt/neon-agents pull

while IFS='|' read -r REPO DEV_INCLUDE; do
  FAILED_REPO="$REPO"
  git -C "$REPOS_DIR/$REPO" fetch origin
  DEFAULT_BRANCH=$(git -C "$REPOS_DIR/$REPO" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' \
    || git -C "$REPOS_DIR/$REPO" remote show origin | grep 'HEAD branch' | awk '{print $NF}')
  git -C "$REPOS_DIR/$REPO" checkout "$DEFAULT_BRANCH"
  git -C "$REPOS_DIR/$REPO" reset --hard "origin/$DEFAULT_BRANCH"
  LAST_CHANGE=$(git -C "$REPOS_DIR/$REPO" log -1 --format=%ct 2>/dev/null)
  [ -z "$LAST_CHANGE" ] && LAST_CHANGE=1
  LAST_BUILD=$(stat -c %Y "$CONTEXT_DIR/$REPO/context.md" 2>/dev/null || echo 0)
  # Also rebuild if context-dev.md is expected but missing
  DEV_MISSING=0
  [ -n "$DEV_INCLUDE" ] && [ ! -f "$CONTEXT_DIR/$REPO/context-dev.md" ] && DEV_MISSING=1
  if [ "$LAST_CHANGE" -gt "$LAST_BUILD" ] || [ "$1" = "--force" ] || [ "$DEV_MISSING" -eq 1 ]; then
    mkdir -p "$CONTEXT_DIR/$REPO"

    # Light context (orientation: CLAUDE.md, README, configs)
    repomix \
      --include "$INCLUDE_GLOBS" \
      --style markdown --compress \
      --output "$CONTEXT_DIR/$REPO/context.md" \
      "$REPOS_DIR/$REPO"
    {
      printf "\n## File tree\n\`\`\`\n"
      git -C "$REPOS_DIR/$REPO" ls-files
      printf "\`\`\`\n"
      printf "\n_Context built: $(date -u +%Y-%m-%dT%H:%M:%SZ)_\n"
    } >> "$CONTEXT_DIR/$REPO/context.md"

    # Dev context (targeted: source files for JeanMichelDev proposer mode)
    if [ -n "$DEV_INCLUDE" ]; then
      repomix \
        --include "$DEV_INCLUDE" \
        --style markdown --compress \
        --output "$CONTEXT_DIR/$REPO/context-dev.md" \
        "$REPOS_DIR/$REPO"
      printf "\n_Context built: $(date -u +%Y-%m-%dT%H:%M:%SZ)_\n" \
        >> "$CONTEXT_DIR/$REPO/context-dev.md"
      echo "[$(date)] Rebuilt context-dev for $REPO" | tee -a "$LOG"
    fi

    echo "[$(date)] Rebuilt context for $REPO" | tee -a "$LOG"
  else
    echo "[$(date)] No changes for $REPO, skipping" | tee -a "$LOG"
  fi
  FAILED_REPO=""
done < <(yq -r '.repos[] | [.name, (.dev_include // "")] | join("|")' "$CONFIG")
