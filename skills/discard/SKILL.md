---
description: Discard a swarm task — remove its worktree and delete its branch without merging. Use for attempts that lost the comparison after /swarm-plugin:merge, or for failed runs.
allowed-tools: Bash
---

## Discard swarm task

!`ruby ${CLAUDE_PLUGIN_ROOT}/bin/swarm discard $ARGUMENTS`

---

Usage: `/swarm-plugin:discard <task-id>` — removes the worktree at `.swarm/worktrees/<task-id>/` and deletes the `swarm/<task-id>` branch.

- If the task is still `running`, the underlying `claude` process is terminated first.
- Uncommitted changes in the worktree are lost — there is no undo. Prefer `/swarm-plugin:diff` before discarding if you're not sure.
- The task's state file at `~/.swarm/tasks/<task-id>.json` is kept as an audit trail with `status: discarded`.
