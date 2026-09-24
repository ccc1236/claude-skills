#!/usr/bin/env bash
# Trigger eval for one skill in this repo.
#   usage: evals/run_trigger_eval.sh <skill> [runs-per-query] [description-file]
#   env:   EVAL_MODEL (default claude-opus-5-5), EVAL_WORKERS (default 3)
# Runs every prompt in evals/<skill>/trigger_eval.json through `claude -p` and reports
# whether the skill fires. Uses your Claude plan quota: 20 prompts x 3 runs = 60 sessions.
set -euo pipefail
SKILL_NAME="${1:?usage: run_trigger_eval.sh <skill> [runs-per-query] [description-file]}"
RUNS="${2:-3}"
DESC_FILE="${3:-}"
MODEL="${EVAL_MODEL:-claude-opus-5-5}"
WORKERS="${EVAL_WORKERS:-3}"

# Python on Windows can't open Git Bash style /c/... paths; convert when cygpath exists.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_PATH="$REPO/plugins/$SKILL_NAME/skills/$SKILL_NAME"
EVAL_SET="$REPO/evals/$SKILL_NAME/trigger_eval.json"
TOOLS="$REPO/evals/tools/skill-creator-eval"
[ -f "$SKILL_PATH/SKILL.md" ] || { echo "no skill at $SKILL_PATH"; exit 1; }
[ -f "$EVAL_SET" ] || { echo "no eval set at $EVAL_SET"; exit 1; }
mkdir -p "$REPO/evals/$SKILL_NAME/runs"
OUT="$REPO/evals/$SKILL_NAME/runs/$(date +%Y%m%d-%H%M%S).json"

# An installed copy of the same skill competes with the test copy; disable it for the run.
PLUGIN="$SKILL_NAME@claude-skills"; WAS_ENABLED=0
if claude plugin list 2>/dev/null | grep -A3 "$PLUGIN" | grep -q "enabled"; then
  WAS_ENABLED=1; claude plugin disable "$PLUGIN" >/dev/null
fi
cleanup() { if [ "$WAS_ENABLED" = 1 ]; then claude plugin enable "$PLUGIN" >/dev/null; fi; }
trap cleanup EXIT

DESC_ARGS=()
[ -n "$DESC_FILE" ] && DESC_ARGS=(--description "$(tr -d '\r\n' < "$DESC_FILE")")

if ! PYTHONPATH="$(native "$TOOLS")" python -m scripts.run_eval \
    --eval-set "$(native "$EVAL_SET")" --skill-path "$(native "$SKILL_PATH")" \
    ${DESC_ARGS[@]+"${DESC_ARGS[@]}"} \
    --model "$MODEL" --runs-per-query "$RUNS" --num-workers "$WORKERS" --timeout 120 --verbose \
    > "$OUT"; then
  rm -f "$OUT"
  echo "eval aborted, no results written (reason printed above)" >&2
  exit 3
fi
echo "results: $OUT"
