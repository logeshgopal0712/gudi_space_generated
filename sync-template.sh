#!/usr/bin/env bash
# Pulls the latest template fixes from `main` into a live customer branch,
# WITHOUT touching that branch's own data/ folder (company info, uploaded
# images, etc). Safe to re-run any time there's a new template fix.
#
# Usage:
#   ./sync-template.sh <branch-name>
#   ./sync-template.sh awesomecompany

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: ./sync-template.sh <branch-name>"
  echo "Example: ./sync-template.sh awesomecompany"
  exit 1
fi

BRANCH="$1"
STARTING_BRANCH="$(git branch --show-current)"

echo "==> Fetching latest from GitHub..."
git fetch origin

echo "==> Stashing any local changes/untracked files so branch switch is clean..."
STASHED="no"
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git status --porcelain)" ]; then
  git stash -u -m "sync-template.sh auto-stash before syncing $BRANCH"
  STASHED="yes"
fi

echo "==> Switching to $BRANCH..."
git checkout "$BRANCH"
git pull origin "$BRANCH"

echo "==> Backing up $BRANCH's own data/ folder..."
BACKUP_DIR="$(mktemp -d)/data-backup"
cp -R data "$BACKUP_DIR"

echo "==> Pulling in everything from origin/main..."
git checkout origin/main -- .

echo "==> Restoring $BRANCH's own data/ folder..."
rm -rf data
cp -R "$BACKUP_DIR" data

echo "==> Checking what actually changed..."
if git diff --cached --quiet && git diff --quiet; then
  echo "Nothing changed — $BRANCH is already up to date with main. Nothing to commit."
else
  git add -A
  git commit -m "Sync template fixes from main (data/ preserved)"
  echo "==> Pushing to origin/$BRANCH..."
  git push origin "$BRANCH"
  echo "✅ Done — $BRANCH is updated on GitHub."
fi

echo "==> Switching back to $STARTING_BRANCH..."
git checkout "$STARTING_BRANCH"

if [ "$STASHED" = "yes" ]; then
  echo "==> Restoring your original local changes..."
  git stash pop
fi

echo "All done."
