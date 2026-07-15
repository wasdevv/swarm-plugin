---
description: Spawn N isolated Claude Code agents in parallel Git worktrees for the same prompt. Each attempt runs headless (claude -p) and can be reviewed with /swarm-plugin:diff before merging with /swarm-plugin:merge or dropping with /swarm-plugin:discard. Use before answering when the user asks to explore multiple approaches to the same change.
allowed-tools: Bash
---

## Spawn parallel swarm

!`ruby ${CLAUDE_PLUGIN_ROOT}/bin/swarm spawn $ARGUMENTS`

---

Usage: `/swarm-plugin:spawn <n> "<prompt>"` — creates `n` isolated Git worktrees (1 ≤ n ≤ 4) under `.swarm/worktrees/`, then runs `claude -p "<prompt>"` in each. Every worktree gets a `swarm/<task-id>` branch cut from the current `HEAD`.

- Each task's id, prompt, branch and status are persisted at `~/.swarm/tasks/<task-id>.json`.
- Tasks run in the background; the command returns as soon as spawning is done. Use `/swarm-plugin:list` to check progress.
- `claude -p` inherits the caller's `ANTHROPIC_API_KEY` and consumes tokens per agent — 4 parallel spawns use ~4× the tokens of a single run.
- If the working tree is dirty (uncommitted changes), spawn is refused; commit or stash first.
