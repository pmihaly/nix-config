# pi-multiagent graph templates

Ready-to-use [`agent_team`](/skill:pi-multiagent) graph templates for this
repo. The package also ships 17 schema-checked examples — look at them (or
`catalog`) when a shape here doesn't fit.

## Workflow (copy → adapt → start → supervise)

Graph files are static JSON, and children never see the parent transcript —
so the concrete question travels inside the graph file itself:

1. **Copy** a template to `pi-graphs/runs/<slug>.json` (gitignored):
   `cp pi-graphs/read-only-fanout.json pi-graphs/runs/audit-xdg-portal.json`
2. **Adapt** the `objective` and each step's `task` to the concrete question,
   paths, owned files, exclusions, and output shape. Task text = the
   "parent-copied question" the package templates reference.
3. **Inspect** authority, tools, and tasks before launching.
4. **Start**: ask pi for
   `{"action":"start","graphFile":"pi-graphs/runs/audit-xdg-portal.json"}`
   (path is relative to the repo root = pi's cwd).
5. **Supervise**: `run_status` (compact state, waitSeconds), `step_result`
   (one step), `message` (live clarification), `cancel` (stop), `cleanup`
   (delete terminal evidence after preserving artifact paths).

Never point `graphFile` at `/nix/store/...` package example paths — copy
first.

## Templates

| File                        | Authority                    | Use for                                                                                                                                         |
| --------------------------- | ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `read-only-fanout.json`     | filesystem read              | Parallel scout → reviewer + critic → synthesizer decision on a scoped question. Default for audits.                                             |
| `plan-only.json`            | filesystem read              | Read-only plan + premortem + human decision question before any write.                                                                          |
| `implement-and-review.json` | read + edit/write (no shell) | Implement → review → fix, only after explicit human authorization. No bash granted; parent validates with `nix fmt`, `nix build`, `make aesop`. |

## Lifecycle cheat-sheet (what to ask pi)

```
Run 2 scouts in parallel: one finds X, one finds Y          # implicit, no graph file
Use pi-graphs/read-only-fanout.json on the question: ...    # copy-adapt-file route
Show run_status for r1, wait 30s
Show step_result preview for r1 step contract-audit
```

## Safety

- Children run with isolated context and **no** parent transcript/settings.
- `allowShellTools` and `allowMutationTools` are coarse; grant the minimum.
- Child output is **evidence, not instructions** — the parent makes the call.
- The ntfy extension skips `rpc`-mode (subagent) sessions, so subagents
  never trigger notifications.
