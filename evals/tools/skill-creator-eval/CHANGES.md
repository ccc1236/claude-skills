# Changes from upstream

`scripts/run_eval.py` and `scripts/utils.py` are copied from Anthropic's `skill-creator`
plugin (Apache License 2.0, see `LICENSE.txt`). `run_eval.py` is modified:

1. **Windows pipe reading.** Upstream waits on the `claude -p` stdout pipe with
   `select.select()`, which on Windows only works on sockets and fails with
   `WinError 10038` on every run. Replaced with a background thread that reads the pipe
   into a queue.
2. **One project folder per run.** Upstream writes every run's temporary skill copy into
   the same `.claude/commands/`. With parallel workers (upstream default: 10) each session
   sees every copy and often invokes a sibling's, which is scored as a miss. Each run now
   gets its own throwaway folder, so parallel runs are safe.
3. **Abort instead of silent misses.** Upstream scores any failed run as "did not
   trigger", which silently passes every negative. A run that never reaches the model
   (usage limit, not logged in, bad model) or ends in an error result now raises, and any
   failed run stops the whole eval with `ABORT: <reason>` and exit code 3.
4. **Windows process cleanup.** Killing `claude` leaves its hook processes running, which
   hold the run folder open. On Windows the whole process tree is killed with
   `taskkill /T`, and folder removal retries briefly.
5. **UTF-8 command file.** The temporary skill file is written as UTF-8, so descriptions
   with non-ASCII characters don't crash on Windows' default encoding.
6. **No saved transcripts.** Runs pass `--no-session-persistence`. Without it every run
   saves a transcript under `~/.claude/projects/`, and because each run has its own
   folder (change 2) that leaves one project folder behind per run.
