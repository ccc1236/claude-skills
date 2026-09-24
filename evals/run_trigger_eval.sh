#!/usr/bin/env bash
# Trigger eval for one skill in this repo.
#   usage: evals/run_trigger_eval.sh <skill> [runs-per-query] [description-file]
# Runs every prompt in evals/<skill>/trigger_eval.json through `claude -p` and reports
# whether the skill fires. Uses your Claude plan quota: 20 prompts x 3 runs = 60 sessions.
set -euo pipefail
SKILL_NAME="${1:?usage: run_trigger_eval.sh <skill> [runs-per-query] [description-file]}"
RUNS="${2:-3}"
DESC_FILE="${3:-}"
MODEL="${EVAL_MODEL:-claude-opus-5-5}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_PATH="$REPO/plugins/$SKILL_NAME/skills/$SKILL_NAME"
EVAL_SET="$REPO/evals/$SKILL_NAME/trigger_eval.json"
OUT_DIR="$REPO/evals/$SKILL_NAME/runs"
TOOLS="$REPO/evals/tools/skill-creator-eval"
[ -f "$SKILL_PATH/SKILL.md" ] || { echo "no skill at $SKILL_PATH"; exit 1; }
[ -f "$EVAL_SET" ] || { echo "no eval set at $EVAL_SET"; exit 1; }
mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/$(date +%Y%m%d-%H%M%S).json"

# run_eval registers the test skill in the nearest .claude/ above the cwd, so work from
# a throwaway folder; from inside the repo it would land in ~/.claude.
WORK="$(mktemp -d)"; mkdir -p "$WORK/.claude"

# An installed copy of the same skill competes with the test copy; disable it for the run.
PLUGIN="$SKILL_NAME@claude-skills"; WAS_ENABLED=0
if claude plugin list 2>/dev/null | grep -A3 "$PLUGIN" | grep -q "enabled"; then
  WAS_ENABLED=1; claude plugin disable "$PLUGIN" >/dev/null
fi
cleanup() { [ "$WAS_ENABLED" = 1 ] && claude plugin enable "$PLUGIN" >/dev/null; rm -rf "$WORK"; }
trap cleanup EXIT

DESC_ARGS=()
[ -n "$DESC_FILE" ] && DESC_ARGS=(--description "$(tr -d '\r\n' < "$DESC_FILE")")

cd "$WORK"
PYTHONPATH="$TOOLS" python -m scripts.run_eval \
  --eval-set "$EVAL_SET" --skill-path "$SKILL_PATH" ${DESC_ARGS[@]+"${DESC_ARGS[@]}"} \
  --model "$MODEL" --runs-per-query "$RUNS" --num-workers 1 --timeout 120 --verbose \
  > "$OUT"
echo "results: $OUT"
