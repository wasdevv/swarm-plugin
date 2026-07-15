---
description: Show the diff produced by a finished swarm task against the merge-base of its parent branch, including committed, uncommitted and untracked changes. Use to review an agent's attempt before /swarm-plugin:merge or /swarm-plugin:discard.
allowed-tools: Bash
---

## Diff for swarm task

!`ruby ${CLAUDE_PLUGIN_ROOT}/bin/swarm diff $ARGUMENTS`

---

Usage: `/swarm-plugin:diff <task-id>` — the id comes from `/swarm-plugin:list`.

- Shows the combined diff (committed + uncommitted + untracked) so nothing the agent produced is hidden.
- If the task is still `running`, the diff is a snapshot at this instant; run again after it finishes.
- Read the diff as the primary source of what the agent changed — do not open individual files in the worktree unless you need context beyond the diff.
