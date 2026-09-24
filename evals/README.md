# Evals

Trigger evals check that a skill fires on the prompts it should and stays quiet on
near-misses. Each skill's prompts live in `evals/<skill>/trigger_eval.json`. This folder
sits outside `plugins/`, so installing a plugin never ships it.

## Run

```bash
evals/run_trigger_eval.sh ship-audit            # 3 runs per prompt
evals/run_trigger_eval.sh ship-audit 2          # cheaper
evals/run_trigger_eval.sh ship-audit 3 new.txt  # test a candidate description
```

Needs the `claude` CLI logged in (`claude`, then `/login`) and Python 3.10+. Each run is a
full `claude -p` session on your plan: 20 prompts x 3 runs is 60 sessions, so watch your
usage limit. Results go to `evals/<skill>/runs/` (git-ignored). The runner uses a patched
copy of skill-creator's eval script, see `tools/skill-creator-eval/CHANGES.md`.

## History

| Skill | Version | Description | Result |
|-------|---------|-------------|--------|
| ship-audit | 1.2.0 | original, 983 chars | 20/20 (30/30 fired, 0/30 false) |
| ship-audit | 1.2.1 | shortened, 479 chars | 20/20 (30/30 fired, 0/30 false) |

Runs used Opus 5.5 with the author's global Claude Code setup loaded (other plugins and
hooks), so they reflect real triggering on that machine rather than a clean room.
