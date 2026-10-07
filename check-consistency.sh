#!/usr/bin/env bash
#
# Verifies the repo's invariants. Run after editing anything in skill/.
#
# Checks:
#   1. Domain router in SKILL.md matches references/domains/ on disk
#   2. Phase table in SKILL.md matches references/phases/ on disk
#   3. Every references/... path cited anywhere actually exists
#   4. Mirrors agree with SKILL.md on modes and phase count
#   5. Mirrors contain no rules content (pointers only)
#   6. rules.md still has exactly 9 stable section anchors
#   7. Ceiling range (C1..CN) agrees across rules.md, mirrors, phases and schema
#   8. Both JSON schemas parse
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL="$ROOT/skill/architecture-review"
FAIL=0

if [ -t 1 ]; then G='\033[0;32m'; R='\033[0;31m'; Y='\033[0;33m'; N='\033[0m'
else G=''; R=''; Y=''; N=''; fi

ok()   { printf '%b  ok  %b %s\n' "$G" "$N" "$1"; }
bad()  { printf '%b FAIL %b %s\n' "$R" "$N" "$1"; FAIL=1; }
warn() { printf '%b warn %b %s\n' "$Y" "$N" "$1"; }

cd "$SKILL" || { echo "skill tree not found at $SKILL"; exit 1; }

# --- 1. domain router ------------------------------------------------------
if diff -q <(grep -oE 'references/domains/[a-z-]+\.md' SKILL.md | sort -u) \
           <(ls references/domains | sed 's|^|references/domains/|' | sort) >/dev/null; then
  ok "domain router matches disk ($(ls references/domains | wc -l | tr -d ' ') guides)"
else
  bad "domain router and references/domains/ disagree:"
  diff <(grep -oE 'references/domains/[a-z-]+\.md' SKILL.md | sort -u) \
       <(ls references/domains | sed 's|^|references/domains/|' | sort) | sed 's/^/       /'
fi

# --- 2. phase table --------------------------------------------------------
if diff -q <(grep -oE 'references/phases/phase-[0-9]-[a-z-]+\.md' SKILL.md | sort -u) \
           <(ls references/phases | sed 's|^|references/phases/|' | sort) >/dev/null; then
  ok "phase table matches disk ($(ls references/phases | wc -l | tr -d ' ') phases)"
else
  bad "phase table and references/phases/ disagree:"
  diff <(grep -oE 'references/phases/phase-[0-9]-[a-z-]+\.md' SKILL.md | sort -u) \
       <(ls references/phases | sed 's|^|references/phases/|' | sort) | sed 's/^/       /'
fi

# --- 3. dangling references ------------------------------------------------
MISSING=0
while read -r p; do
  [ -f "$p" ] || { bad "dangling reference: $p"; MISSING=1; }
done < <(grep -rhoE '`?references/[a-zA-Z0-9/_.-]+\.(md|json)' SKILL.md references/ | tr -d '`' | sort -u)
[ "$MISSING" -eq 0 ] && ok "every references/... path resolves"

# --- 4. mirrors agree on modes and phase count -----------------------------
PHASE_N=$(ls references/phases | wc -l | tr -d ' ')
for m in AGENTS.md .cursorrules .windsurfrules; do
  f="$ROOT/$m"
  [ -f "$f" ] || { bad "$m missing"; continue; }
  miss=''
  for mode in quick standard deep pr diff refactor; do
    grep -q "\`$mode\`" "$f" || miss="$miss $mode"
  done
  # last phase index must appear (phases are 0-indexed)
  last=$((PHASE_N - 1))
  grep -qE "(0[–-]$last|$last report)" "$f" || miss="$miss phase-range"
  if [ -n "$miss" ]; then bad "$m out of sync:$miss"; else ok "$m in sync (modes + phase range)"; fi
done

# --- 5. mirrors carry no rules content -------------------------------------
LEAK='blast radius|change frequency|ceremony budget|chesterton|remediation cost|Wide.*Moderate.*Contained|Hot.*Warm.*Cold|C1.*C2.*C3'
for m in AGENTS.md .cursorrules .windsurfrules; do
  # grep -c prints 0 and exits 1 on no-match; the count is what we want either way
  n=$(grep -icE "$LEAK" "$ROOT/$m" 2>/dev/null); n=${n:-0}
  if [ "$n" -eq 0 ]; then ok "$m carries no rules content"
  else bad "$m restates rules content ($n hits) — mirrors must point, not copy"; fi
done

# --- 6. rules.md section anchors -------------------------------------------
SEC=$(grep -c '^## [0-9]\.' references/rules.md)
if [ "$SEC" -eq 9 ]; then ok "rules.md has 9 stable section anchors"
else bad "rules.md has $SEC top-level sections, expected 9 — section numbers are citation anchors, never renumber"; fi

# --- 7. ceiling range agrees everywhere ------------------------------------
# rules.md §3 defines the ceilings; the mirrors, CLAUDE.md, the phase files and
# the JSON schema all cite the RANGE. When a ceiling was added, every one of
# those said "C1-C4" for a while and nothing noticed - the exact drift the
# mirrors exist to prevent, in the mirrors themselves.
TOP=$(grep -oE '^- \*\*C[0-9]+\*\*' references/rules.md | grep -oE 'C[0-9]+' | sort -V | tail -1)
if [ -z "$TOP" ]; then
  bad "could not find any '- **CN**' ceiling definitions in rules.md §3"
else
  # rules.md is excluded: it DEFINES the ceilings, so it may legitimately discuss
  # a subrange ("C1-C4 check what kind of evidence you have; C5 checks whether it
  # supports the claim"). Everything else only ever CITES the full range.
  STALE=$(grep -rlE "C1[–-]C[0-9]+" \
            "$ROOT/AGENTS.md" "$ROOT/.cursorrules" "$ROOT/.windsurfrules" "$ROOT/CLAUDE.md" \
            SKILL.md references/ 2>/dev/null \
          | grep -v 'references/rules\.md$' \
          | while read -r f; do
              grep -oE "C1[–-]C[0-9]+" "$f" | grep -qv "C1[–-]$TOP" && echo "$f"
            done | sort -u)
  # the schema enumerates them individually rather than as a range
  SCHEMA_TOP=$(grep -oE '"C[0-9]+"' references/templates/findings-schema.json | tr -d '"' | sort -V | tail -1)
  if [ -n "$STALE" ]; then
    bad "ceiling range drift — rules.md defines up to $TOP but these cite a different top:"
    echo "$STALE" | sed 's/^/       /'
  elif [ "$SCHEMA_TOP" != "$TOP" ]; then
    bad "findings-schema.json enumerates up to $SCHEMA_TOP but rules.md defines up to $TOP"
  else
    ok "ceiling range consistent everywhere (C1-$TOP)"
  fi
fi

# --- 8. schemas parse ------------------------------------------------------
for f in references/templates/*.json; do
  if python -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null \
  || python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$f" 2>/dev/null; then
    ok "$(basename "$f") parses"
  else
    bad "$(basename "$f") is not valid JSON"
  fi
done

echo
if [ "$FAIL" -eq 0 ]; then printf '%bAll invariants hold.%b\n' "$G" "$N"
else printf '%bInvariants broken — see FAIL lines above.%b\n' "$R" "$N"; fi
exit "$FAIL"
