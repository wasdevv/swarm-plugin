---
description: Merge a finished swarm task's branch into the parent branch with a --no-ff merge commit, then remove the worktree. Use after reviewing with /swarm-plugin:diff.
allowed-tools: Bash
---

## Merge swarm task

!`ruby ${CLAUDE_PLUGIN_ROOT}/bin/swarm merge $ARGUMENTS`

---

Usage: `/swarm-plugin:merge <task-id>` — merges the task's `swarm/<task-id>` branch into the branch that was current when it was spawned, then deletes the worktree and prunes the branch.

- Commits any uncommitted changes in the worktree first (auto-message: `swarm: <task-id> — <first line of prompt>`).
- Uses `git merge --no-ff` so the merge always creates a commit — the history keeps the swarm attempt visible.
- If the merge hits conflicts, it is aborted cleanly (`git merge --abort`) and the worktree is left in place so you can inspect and merge manually.
- After a successful merge, the other swarm tasks (siblings from the same spawn) remain untouched — clean them up with `/swarm-plugin:discard` if you're done exploring.
