---
description: Push a swarm task's branch to origin and open a GitHub pull request via gh CLI, straight from the task's worktree. Use as an alternative to /swarm-plugin:merge when you want the change reviewed as a PR instead of merged locally.
allowed-tools: Bash
---

## Open PR for swarm task

!`ruby ${CLAUDE_PLUGIN_ROOT}/bin/swarm pr $ARGUMENTS`

---

Usage: `/swarm-plugin:pr <task-id>` — commits any uncommitted changes in the worktree, pushes the `swarm/<task-id>` branch to `origin`, then opens a PR via `gh pr create` targeting the parent branch that was current when the task was spawned.

- Requires the [`gh`](https://cli.github.com/) CLI to be installed and authenticated.
- PR title defaults to the first line of the original prompt; body includes the full prompt for context.
- The worktree is kept after opening the PR so you can push follow-up commits — use `/swarm-plugin:discard` when the PR is merged/closed.
