# Changes from upstream

`scripts/run_eval.py` and `scripts/utils.py` are copied from Anthropic's `skill-creator`
plugin (Apache License 2.0, see `LICENSE.txt`). `run_eval.py` is modified:

1. **Windows pipe reading.** Upstream waits on the `claude -p` stdout pipe with
   `select.select()`, which on Windows only works on sockets and fails with
   `WinError 10038` on every run. Replaced with a background thread that reads the pipe
   into a queue.
2. **Abort on unscoreable runs.** A run that never reaches the model (usage limit hit,
   not logged in) or ends in an error result used to be scored as "did not trigger",
   silently turning negatives into passes. It now prints `ABORT: <reason>` and exits
   with code 3.

Not changed in code but required when running: use `--num-workers 1`. With parallel
workers, every concurrent session sees every run's temporary skill copy and often invokes
a sibling's, which is scored as a miss and undercounts triggers.
