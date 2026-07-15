---
description: List all swarm tasks in the current repository — id, status (running/finished/failed), prompt, worktree path, branch and elapsed time. Use to check which spawned agents are done before running /swarm-plugin:diff or /swarm-plugin:merge.
allowed-tools: Bash
---

## Swarm tasks

!`ruby ${CLAUDE_PLUGIN_ROOT}/bin/swarm list`

---

Read the table above:

- `status: running` — the agent is still working; wait before reviewing.
- `status: finished` — the agent exited 0; safe to `/swarm-plugin:diff <task-id>` and merge or discard.
- `status: failed` — the agent exited non-zero; inspect the worktree at the shown path and decide whether to discard.
- Tasks live at `.swarm/worktrees/<task-id>/` inside the repo and their state at `~/.swarm/tasks/<task-id>.json`.
