---
description: Aggregated metrics across every swarm task on this machine (all repos). Shows totals by status, keeper rate (merged vs discarded), agent success rate, elapsed time per outcome, activity over the last week, top repos and top prompts. Use to see which spawns are worth keeping and where you're spending your fanout budget.
allowed-tools: Bash
---

## Swarm metrics

!`ruby ${CLAUDE_PLUGIN_ROOT}/bin/swarm metrics`

---

Read the numbers above:

- **keeper rate** = merged / (merged + discarded). Low keeper rate means your fanout produces attempts you throw away — consider refining the prompt before the next `/swarm-plugin:spawn`.
- **agent ok rate** = (finished + merged) / (finished + failed + merged). Low means agents crash mid-run; check `.swarm/worktrees/<task-id>/.swarm/logs/stderr` on failed ones.
- **elapsed** = seconds between spawn and finish. If `merged` medians are much shorter than `discarded`, quick spawns tend to be the winners.
- **top prompts** = which prompts you fork the most — usually a sign that a spec or template would save time.

Data comes from `~/.swarm/tasks/*.json`. Delete a file to forget a task; the metric recomputes on the next run.
