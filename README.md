# swarm-plugin

**Claude Code plugin that runs Claude Code against N isolated Git worktrees in parallel** — spawn the fanout with `/swarm-plugin:spawn`, review each attempt's diff, then merge the best one (or open a PR) without leaving your current session.

Sibling of [rails-guard](https://github.com/wasdevv/rails-guard), [lean-output](https://github.com/wasdevv/lean-output) and [rails-context](https://github.com/wasdevv/rails-context).

## Why

Sometimes there's more than one way to make a change and you want to see them side by side before choosing. `swarm-plugin` does exactly that: spawns up to 4 Claude Code agents running the **same prompt** in **isolated Git worktrees**, keeps them running in the background, and gives you six slash commands to review, merge or discard each attempt.

```
/swarm-plugin:spawn 3 "Add cursor pagination to DealsController#index"
  ─▶ 20260715-1445-a3f2  pid=12345  .swarm/worktrees/20260715-1445-a3f2
  ─▶ 20260715-1445-b7c1  pid=12346  .swarm/worktrees/20260715-1445-b7c1
  ─▶ 20260715-1445-9d0e  pid=12347  .swarm/worktrees/20260715-1445-9d0e

/swarm-plugin:list
  TASK ID                  STATUS     ELAPSED  PROMPT
  20260715-1445-a3f2       finished   2m14s    Add cursor pagination to DealsController#index
  20260715-1445-b7c1       finished   1m58s    Add cursor pagination to DealsController#index
  20260715-1445-9d0e       running    ...      Add cursor pagination to DealsController#index

/swarm-plugin:diff 20260715-1445-a3f2      # review attempt A
/swarm-plugin:merge 20260715-1445-a3f2     # keep this one
/swarm-plugin:discard 20260715-1445-b7c1   # drop the loser
/swarm-plugin:pr 20260715-1445-9d0e        # or open a PR instead of a local merge
```

## Install

```
/plugin marketplace add wasdevv/swarm-plugin
/plugin install swarm-plugin@swarm-plugin
```

**Requirements:**

- Ruby ≥ 2.6 on your `PATH` (pure stdlib — no gems, no Bundler)
- Git ≥ 2.31 (for `git worktree`)
- The [`claude`](https://claude.com/claude-code) CLI on your `PATH` (the whole point is spawning it in each worktree)
- Optional: [`gh`](https://cli.github.com/) for `/swarm-plugin:pr`

## Commands

| Slash command                         | Verb         | Effect                                                                 |
| ------------------------------------- | ------------ | ---------------------------------------------------------------------- |
| `/swarm-plugin:spawn <n> "<prompt>"`  | `spawn`      | 1–4 isolated worktrees, each running `claude -p "<prompt>"` in background |
| `/swarm-plugin:list`                  | `list`       | Every task in the current repo, with status and elapsed time              |
| `/swarm-plugin:diff <task-id>`        | `diff`       | Combined diff (committed + uncommitted + untracked) vs merge-base         |
| `/swarm-plugin:merge <task-id>`       | `merge`      | Commits pending changes, `git merge --no-ff`, removes worktree             |
| `/swarm-plugin:discard <task-id>`     | `discard`    | Kills the agent (if running), removes worktree, deletes branch             |
| `/swarm-plugin:pr <task-id>`          | `pr`         | Pushes branch and opens a GitHub PR via `gh`                               |
| `/swarm-plugin:metrics`               | `metrics`    | Aggregated stats across all repos: keeper rate, agent success, elapsed medians, activity |

The same seven verbs also work directly from your shell as `swarm <verb> …` (add `swarm-plugin/bin` to your `PATH`).

## Where state lives

- **Task metadata** — `~/.swarm/tasks/<task-id>.json` (id, prompt, worktree path, parent branch, pid, status, elapsed). Override with `SWARM_HOME`.
- **Worktrees** — `.swarm/worktrees/<task-id>/` inside the repo. Add `.swarm/` to `.gitignore` if you want.
- **Agent logs** — `.swarm/worktrees/<task-id>/.swarm/logs/{stdout,stderr,exit_code}` (per worktree).

Everything is a plain file, no daemon, no database. Delete `~/.swarm/tasks/<task-id>.json` by hand to forget a task.

## Design principles

- **Ask, never mine** — the plugin only touches worktrees under `.swarm/worktrees/` and branches under `swarm/…`. It will never touch a branch you own.
- **Fail-safe** — any error inside the CLI exits 0 silently with a short message; your Claude Code session is never broken by the plugin.
- **Uses token cost transparently** — each spawned agent is a fresh `claude -p` process consuming its own tokens. 4 agents in parallel = ~4× tokens of a single run. Use it deliberately for high-value forks.
- **Nothing hidden** — every worktree, branch, log and state file is inspectable and deletable by hand.
- **Refuses on dirty tree** — `spawn` won't run if the current repo has uncommitted changes; commit or stash first so the fanout starts from a known state.

## What it deliberately does NOT do (yet)

- No `/compare` grid of live terminals — that's what the [Swarm ADE](https://github.com/wasdevv/swarm) desktop app is for; this plugin is the headless CLI slice.
- No per-line comments back to the agent's session — plugin runs agents in `-p` (headless), so once the agent finishes, the conversation is gone. Fork a new attempt with the refined prompt.
- No auto-selection — a human still picks which attempt wins.

## Environment variables

| Var             | Purpose                                                                    |
| --------------- | -------------------------------------------------------------------------- |
| `SWARM_HOME`    | Override the state directory (default: `~/.swarm`).                        |
| `SWARM_DEBUG`   | When set to a path, unexpected exceptions are appended to that file.       |

## License

MIT — see [LICENSE](LICENSE).
