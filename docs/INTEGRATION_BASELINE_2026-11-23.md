# Repository baseline — 23 November 2026

## Scope

Read-only audit of the four CASES repositories before the Godot-to-backend integration. The inspected canonical checkouts are under `D:\projects`. No existing checkout or worktree was edited during this audit.

## Repository heads and working trees

| Repository | Local HEAD | Remote tracking | Working tree |
|---|---|---|---|
| `Cases-GUI` | `deec5ca49273f802dd737e7970d8616957c6245d` (`main`) | `origin/main` matched the same SHA | Clean |
| `Cases-Backend` | `7c61f24b7f1f74fa2865e6150ba33fe00e5ad9b2` (`main`) | `origin/main` matched the same SHA | Clean |
| `Cases-AI` | `3f954bffc1fad76240413272390b571ed910f363` (`main`) | `origin/main` matched the same SHA | Clean |
| `Cases-Server-Setup` | No commit; local `main` has no commit | No `origin/main` ref | Empty repository; no files to preserve |

The remote `main` refs were checked with `git ls-remote` and matched the three committed local `main` heads. No fetch, merge, migration, or push was performed.

### Existing GUI worktrees left intact

All inspected worktrees were clean when checked:

- `codex/versailles-seated-character` — `651461cb208f5f66fc528082a6570587cb6b2324`
- detached research checkout — `377bffd22cbc7bb30d0abe4b1e8d5401d5cc06bb`
- `codex/historical-delegate-archetypes` — `7397793fe351dbdad0003bba2fccde89eaf9fa8b`
- `codex/versailles-room` — `bb2901568dec728ad8e211233d8f0eecdbeadd3d`
- separate `Cases-GUI-archetypes` checkout, branch `codex/delegate-archetypes-v3` — `3a25268ed0e7115a7474cb33bc19c0a3c9ff6675`

The local branch `codex/suited-negotiator-v2` tracks a deleted remote branch and is not checked out. The active room and seated-character branches remain separate. To isolate integration work, this audit created a new worktree at `D:\projects\Cases-GUI-backend-integration`, branch `codex/godot-backend-integration`, starting from the clean `Cases-GUI/main` SHA above. The original main checkout and earlier worktrees remain untouched.

`Cases-Backend` and `Cases-AI` each had only their canonical local main worktree. `Cases-Server-Setup` had no files or commits.

## Current runtime baseline

Read-only checks on Marcus_Computer found the local stack already running:

- Backend API container is published on `127.0.0.1:18081`; liveness returned `alive`, readiness returned `ready` with database available.
- Active Versailles release is `versailles-1919 / 3.1-ai`, schema 2, role `british_adviser`.
- The `local_qwen` narrator reported configured and ready. `gpt6_luna_high` was configured but not ready.
- The main Godot scene in `main` is `res://scenes/seated_suit_demo.tscn`; it is a one-character animation preview and has no gameplay controls or backend calls.
- The backend already provides public scenario/narrator APIs, durable session initialization, capability-protected resume, idempotent turn submission, and turn-status polling. The client integration can use those existing contracts without a backend schema change.
- `Cases-Server-Setup` remains empty, so this work does not add or change a unified startup stack.

## Checks

| Check | Result |
|---|---|
| Git status of the four canonical checkouts | Clean / empty for Server-Setup |
| Git status of the listed GUI worktrees | Clean |
| Local `main` versus remote `origin/main` | Matched for GUI, Backend, and AI |
| Backend `/healthz` and `/readyz` | Passed (read-only requests) |
| Scenario and narrator availability | Read successfully |
| Godot test suite / Blender pipeline | Not run as part of this baseline |
| Database migrations or live session creation | Not performed |

This report records the baseline only. Integration changes belong to the isolated branch/worktree above; no existing worktree should be consolidated or cleaned up as part of this task.
