# Godot client ↔ CASES backend integration

## Run

The default Godot project now opens the network client in `godot/scenes/game_client.tscn`. The previous seated character preview remains available as `res://scenes/seated_suit_demo.tscn`.

Use [Cases-Startup](https://github.com/IdehistorieCases/Cases-Startup) as the demo launcher. After setup and one-time Luna consent in the dashboard, run `.\cases.ps1 start` from the Cases-Startup checkout. It starts the model services and backend, then launches Godot with the selected backend URL in `CASES_API_BASE_URL`. The default backend port is `18082`, matching the GUI default.

For manual GUI debugging, first start the backend and set the URL to its actual host port. Example for the default Cases-Startup stack:

```powershell
$env:CASES_API_BASE_URL = 'http://127.0.0.1:18082'
& 'D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path godot
```

`CASES_API_BASE_URL` overrides the URL saved by the GUI. You can also change the endpoint in the GUI and press **Connect**. Use HTTPS for remote servers.

The client checks `/healthz`, `/readyz`, `/api/v1/scenarios/versailles-1919`, and `/api/v1/narrators` when it connects. Session creation requires API and database readiness. Narrator readiness is displayed separately: if inference is unavailable, the client does not fabricate an opening and offers a retry for the failed initialization.

## Connected gameplay path

The first network flow targets the active Versailles release, the `british_adviser` role, and `gpt6_luna_high` (`gpt-6-luna`). New sessions use ChatGPT 6 Luna by default and stay pinned to that narrator; the backend does not silently switch to Qwen if Luna is unavailable. It creates a schema-v2 session with an idempotency key and a random capability, then loads the server-authored opening and history. Danish text entries go to the session turns endpoint. The client polls the durable turn request and refreshes the authoritative session state before rendering the saved reply.

The client can resume a saved session, continue an interrupted session creation, retry an opening or retryable turn, and preserve a submitted draft while a different turn already in progress completes. The player can end a ready negotiation with `POST /api/v1/sessions/{session_id}/completion`; the request and idempotency key are saved locally so the same completion can be retried or reconciled after resume. When the backend marks a session complete, the transcript shows an end state, disables further proposals, and offers an on-demand structured reflection. The client calls `POST /api/v1/sessions/{session_id}/reflection` with the session capability, saves a ready result locally, and restores it when the completed session is resumed. A temporary reflection failure leaves a retry action available; a non-retryable response is reported without presenting a fabricated reflection. Existing saved sessions keep the narrator recorded when they were created; start a new session to use Luna if an older session is pinned to Qwen. The client never invents a fallback reply when the backend fails.

## Local data and security

Godot saves session IDs, capability tokens, pending requests, ready reflection results, and the selected API URL in its per-user `user://cases_sessions.json` file. This file is outside the repository and must not be committed or shared. A session capability grants access to that session and expires after 24 hours under the current backend policy. Tokens are sent in authorization headers and are not written to logs or URLs. Remote HTTP is blocked by the client; only localhost may use plain HTTP.

GPT-6 Luna sends prompts and supplied conversation context to OpenAI through the signed-in Codex CLI. Enable it in Cases-AI Dashboard → Providers only after reviewing and accepting the cloud-data disclosure. Cases-Startup leaves the provider off until that dashboard consent is completed; it never falls back to local Qwen.

## Current limits

The current scope is one Versailles scenario and one fixed British role. The composer is free text; players do not edit structured proposal objects or use negotiation tools. The current scenario release reports no approved source passages, so postgame reflection must identify that evidence gap rather than cite unapproved passages. The transcript also labels the scenario as counterfactual. Use [Cases-Startup](https://github.com/IdehistorieCases/Cases-Startup) to clone the pinned project revisions, prepare local configuration, and start the bridge, gateway, backend, and GUI in order.

## Verification performed

### Live GUI pass — 25 November 2026

- Ran the current Godot 4.7.2 project against the local Cases backend and current Versailles schema-v2 scenario. Started a new session, waited for its generated opening, resumed it from the saved-session control, and confirmed the opening and player prompt remained available.
- Sent two Danish proposals in the visible game. The backend committed both and returned three dialogue actors per turn (`britain`, `france`, and `china`); the GUI rendered their simulated responses, narrator reply, outcome summary, and next prompt.
- Used **Afslut forløb**. The backend committed a `player_end` completion, and the GUI replaced the proposal composer with the completed state, final response, outcome, and structured reflection. The reflection correctly stated that no approved historical passages were available, showed objective feedback and uncertainty, and provided no score or mastery claim.
- Closed and relaunched the GUI, then resumed the saved completed session. The transcript, final state, and locally cached reflection were restored.
- Tested connection recovery in the GUI by pointing it at the unused local port `9`, confirming an explicit network error, restoring `http://127.0.0.1:18082`, and confirming the connected state returned while the completed result remained intact.
- Simulated HTTP 503 responses verified both retry paths in the GUI regression harness: completion retries reuse the saved idempotency key, and reflection keeps a retry action available. The live run’s reflection request succeeded, so the 503 path was not induced against the live provider.
- The live run used the local development database and created one completed test session, which remains in that development environment. It did not modify the other saved sessions.

### Version audit — 25 November 2026

- GitHub `Cases-GUI` `origin/main` is `9d78c32`, the tested base. The newer-looking GUI feature refs checked (`codex/cases-startup-luna-default` and `codex/fix-gui-launcher-port-20261125`) are ancestors of `main`; no remote GUI branch contains a later commit.
- `Cases-Backend` `origin/main` is merge `ef8f1d8`; its tree matches the Startup-pinned `2ff2c2f` checkout used for the local API and worker.
- `Cases-AI` `origin/main` is merge `d290b71`. Startup pins the later `codex/luna-primary-startup` commit `8121071`, which is the Codex bridge revision used by the running gateway during the live inference pass.
- `Cases-Startup` `origin/main` is `be2ab19` and its lock file pins those same backend, GUI, and AI revisions. The separate local `Cases-GUI-backend-integration` checkout is based on older commit `7110022`; its uncommitted result-view work was reviewed as a reference, not treated as a newer release.

### Automated checks — 25 November 2026

- `uv run --locked --project backend pytest backend/tests -q`: **310 passed, 108 skipped**.
- `uv run --locked --project backend ruff check backend/app/runtime/proposals.py backend/tests/test_turn_proposals.py`: passed.
- Godot 4.7.2 editor import completed; `validate_game_reflection.gd`, `validate_game_hud.gd`, and `validate_room_integration.gd` all passed.
- The new backend regression test accepts a complete `outcome_summary` longer than the old 240-character generic short-text limit; the dedicated outcome-summary limit is now 500 characters.

### Earlier isolated smoke checks

- An earlier end-to-end smoke run used a fresh, isolated database and deterministic fake inference service. It created the opening, committed three distinct turns, rendered actor-attributed dialogue, then closed and reopened the client with identical persisted history (`STAGE1_SMOKE_OK opening=true turns=3 speaker_dialogue=true reopen_history_identical=true`).
- In that fake-Qwen smoke run, stopping the fake inference container left the API ready, reported `local_qwen_ready=false`, produced no fabricated opening, and displayed a retry action (`STAGE1_RETRYABLE_FAILURE_OK retry_button=true fabricated_opening=false`). This checks fail-closed behavior, not live ChatGPT 6 Luna availability.
