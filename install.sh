#!/usr/bin/env bash
#
# Installs the architecture-review skill into ~/.claude/skills so it is
# available in every project, in Claude Code and in the Claude desktop app.
#
#   ./install.sh          copy (default, safe everywhere)
#   ./install.sh --link   symlink - edits to this repo apply immediately
#   ./install.sh --force  overwrite without prompting
#
set -euo pipefail

LINK=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --link)  LINK=1 ;;
    --force) FORCE=1 ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="$REPO_ROOT/skill/architecture-review"
SKILLS_DIR="$HOME/.claude/skills"
TARGET="$SKILLS_DIR/architecture-review"

# Colors, only when attached to a terminal.
if [ -t 1 ]; then
  C='\033[0;36m'; G='\033[0;32m'; Y='\033[0;33m'; R='\033[0;31m'; D='\033[0;90m'; N='\033[0m'
else
  C=''; G=''; Y=''; R=''; D=''; N=''
fi

printf '\n%bArchitecture Review Skill - installer%b\n\n' "$C" "$N"

# --- Validate source -------------------------------------------------------
if [ ! -d "$SOURCE" ]; then
  printf '%bERROR: source not found at %s%b\n' "$R" "$SOURCE" "$N"
  echo 'Run this script from the repository root.'
  exit 1
fi
if [ ! -f "$SOURCE/SKILL.md" ]; then
  printf '%bERROR: SKILL.md missing from %s%b\n' "$R" "$SOURCE" "$N"
  exit 1
fi

# --- Handle existing install ----------------------------------------------
if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  if [ -L "$TARGET" ]; then kind='symlink'; else kind='directory'; fi

  if [ "$FORCE" -ne 1 ]; then
    printf '%bAn installation already exists (%s):%b\n' "$Y" "$kind" "$N"
    echo "  $TARGET"
    printf 'Replace it? [y/N] '
    read -r reply
    case "$reply" in
      [Yy]*) ;;
      *) echo 'Cancelled. Nothing changed.'; exit 0 ;;
    esac
  fi

  # Remove the link itself, never its contents.
  if [ -L "$TARGET" ]; then rm "$TARGET"; else rm -rf "$TARGET"; fi
  printf '%bRemoved previous installation.%b\n' "$D" "$N"
fi

mkdir -p "$SKILLS_DIR"

# --- Install ---------------------------------------------------------------
if [ "$LINK" -eq 1 ]; then
  ln -s "$SOURCE" "$TARGET"
  MODE='symlinked'
else
  cp -R "$SOURCE" "$TARGET"
  MODE='copied'
fi

# --- Verify ----------------------------------------------------------------
CHECKS="
SKILL.md
references/rules.md
references/differential-protocol.md
references/parallel-review.md
references/phases/phase-0-recon.md
references/phases/phase-7-report.md
references/domains/backend-service.md
references/domains/frontend-app.md
references/tooling/git-history.md
references/templates/findings-schema.json
"

MISSING=''
for c in $CHECKS; do
  [ -f "$TARGET/$c" ] || MISSING="$MISSING  $c\n"
done

if [ -n "$MISSING" ]; then
  printf '%bERROR: installation incomplete. Missing:%b\n' "$R" "$N"
  printf "%b" "$MISSING"
  exit 1
fi

FILE_COUNT=$(find "$TARGET/" -type f | wc -l | tr -d ' ')
PHASE_COUNT=$(find "$TARGET/references/phases"  -type f | wc -l | tr -d ' ')
DOMAIN_COUNT=$(find "$TARGET/references/domains" -type f | wc -l | tr -d ' ')

printf '\n%bInstalled (%s).%b\n' "$G" "$MODE" "$N"
echo   "  Location : $TARGET"
echo   "  Files    : $FILE_COUNT  ($PHASE_COUNT phases, $DOMAIN_COUNT domain guides)"
printf '\n%bUsage - from any project directory:%b\n' "$C" "$N"
echo '  /architecture-review           full design review (standard)'
echo '  /architecture-review quick     structural triage - graph, cycles, hotspots'
echo '  /architecture-review deep      wider evidence sweep, more change scenarios'
echo '  /architecture-review pr        review the design of a diff'
echo '  /architecture-review diff      re-review; did the debt move?'
echo ''
echo 'It also triggers on plain requests such as "is this overengineered"'
echo 'or "why is this so hard to change".'
echo ''
echo 'Output goes to .architecture-review/ in the reviewed project.'
printf '%bThe skill never modifies the project under review.%b\n' "$D" "$N"
printf '\n%bRestart Claude Code or the Claude desktop app to pick it up.%b\n\n' "$Y" "$N"
