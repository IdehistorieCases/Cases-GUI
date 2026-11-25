# Godot client ↔ CASES backend integration

## Run

The default Godot project now opens the network client in `godot/scenes/game_client.tscn`. The previous seated character preview remains available as `res://scenes/seated_suit_demo.tscn`.

Start the CASES backend deployment separately before opening Godot. The default API URL is `http://127.0.0.1:18081`, matching the API port currently published on Marcus_Computer. Use the URL field and **Connect** in the client if the backend runs elsewhere. For a remote server, use HTTPS. You can also set `CASES_API_BASE_URL` before launching Godot.

From the repository root in PowerShell:

```powershell
& 'D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64.exe' --path godot
```

The client checks `/healthz`, `/readyz`, `/api/v1/scenarios/versailles-1919`, and `/api/v1/narrators` when it connects. Session creation requires API and database readiness. Narrator readiness is displayed separately: if inference is unavailable, the client does not fabricate an opening and offers a retry for the failed initialization.

## Connected gameplay path

The first network flow targets the active Versailles release, the `british_adviser` role, and `gpt6_luna_high` (`gpt-6-luna`). New sessions use ChatGPT 6 Luna by default and stay pinned to that narrator; the backend does not silently switch to Qwen if Luna is unavailable. It creates a schema-v2 session with an idempotency key and a random capability, then loads the server-authored opening and history. Danish text entries go to the session turns endpoint. The client polls the durable turn request and refreshes the authoritative session state before rendering the saved reply.

The client can resume a saved session, continue an interrupted session creation, retry an opening or retryable turn, and preserve a submitted draft while a different turn already in progress completes. Existing saved sessions keep the narrator recorded when they were created; start a new session to use Luna if an older session is pinned to Qwen. The client never invents a fallback reply when the backend fails.

## Local data and security

Godot saves session IDs, capability tokens, pending requests, and the selected API URL in its per-user `user://cases_sessions.json` file. This file is outside the repository and must not be committed or shared. A session capability grants access to that session and expires after 24 hours under the current backend policy. Tokens are sent in authorization headers and are not written to logs or URLs. Remote HTTP is blocked by the client; only localhost may use plain HTTP.

GPT-6 Luna sends prompts and supplied conversation context to OpenAI through the signed-in Codex CLI. Enable it in Cases-AI Dashboard → Providers only after reviewing and accepting the cloud-data disclosure. Cases-Startup leaves the provider off until that dashboard consent is completed; it never falls back to local Qwen.

## Current limits

This connects the existing character presentation to the real session API; it does not yet implement the full final game interface. The current scope is one Versailles scenario and one fixed British role. The composer is free text; structured proposals, negotiation tools, a session end screen, and post-game reflection remain future work. The current scenario release reports no approved source passages, and its counterfactual-status notice is shown in the transcript. Use [Cases-Startup](https://github.com/IdehistorieCases/Cases-Startup) to clone the pinned project revisions, prepare local configuration, and start the bridge, gateway, backend, and GUI in order.

## Verification performed

- Godot 4.7.2 editor import and headless project startup completed successfully.
- An end-to-end smoke run used a fresh, isolated database and a deterministic fake inference service. It created the opening, committed three distinct turns, rendered actor-attributed dialogue with speaker names, then closed and reopened the client with identical persisted history (`STAGE1_SMOKE_OK opening=true turns=3 speaker_dialogue=true reopen_history_identical=true`).
- In the historical fake-Qwen smoke run, stopping the fake inference container left the API ready, reported `local_qwen_ready=false`, produced no fabricated opening, and displayed a retry action (`STAGE1_RETRYABLE_FAILURE_OK retry_button=true fabricated_opening=false`). This verifies fail-closed behavior, not a live ChatGPT 6 Luna connection.
- These session and turn writes were confined to the isolated smoke database; the live `ddu_game` database was not written.
- The repository formal test suite and Blender asset pipeline were not run for this integration change.
