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

REPOS=$(yq -r '.repos[].name' "$CONFIG")

for REPO in $REPOS; do
  FAILED_REPO="$REPO"
  git -C "$REPOS_DIR/$REPO" pull
  LAST_CHANGE=$(git -C "$REPOS_DIR/$REPO" log -1 --format=%ct 2>/dev/null)
  [ -z "$LAST_CHANGE" ] && LAST_CHANGE=1
  LAST_BUILD=$(stat -c %Y "$CONTEXT_DIR/$REPO/context.md" 2>/dev/null || echo 0)
  if [ "$LAST_CHANGE" -gt "$LAST_BUILD" ] || [ "$1" = "--force" ]; then
    mkdir -p "$CONTEXT_DIR/$REPO"
    repomix \
      --include "$INCLUDE_GLOBS" \
      --style markdown --compress \
      --output "$CONTEXT_DIR/$REPO/context.md" \
      "$REPOS_DIR/$REPO"
    echo "[$(date)] Rebuilt context for $REPO" | tee -a "$LOG"
  else
    echo "[$(date)] No changes for $REPO, skipping" | tee -a "$LOG"
  fi
  FAILED_REPO=""
done
