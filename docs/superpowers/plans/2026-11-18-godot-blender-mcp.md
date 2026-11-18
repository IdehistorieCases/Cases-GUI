# Godot and Blender MCP Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect Codex globally to Godot Editor MCP and MCP for Blender, with Godot project skills and Blender safe mode enabled.

**Architecture:** Run pinned local stdio MCP servers through `uvx`. Install the Godot Editor MCP add-on and its companion skills in this repository; install the Blender add-on in the existing Blender user profile. Preserve all pre-existing Codex MCP entries.

**Tech Stack:** Godot 4.7.2, Blender 4.2.2 LTS, Godot Editor MCP 2026.11.4, MCP for Blender 2.3.1, Codex CLI, uvx.

**Spec:** `docs/superpowers/specs/2026-11-18-godot-blender-mcp-design.md`

## Global Constraints

- Use Godot Editor MCP 2026.11.4 with Godot 4.7.2.
- Use MCP for Blender 2.3.1 with `BLENDER_MCP_SAFE_MODE=1` and `DISABLE_TELEMETRY=true`.
- Register both MCP servers in the global Codex config and preserve existing server entries.
- Do not upgrade Blender or configure paid/cloud model services or API keys.
- Do not run the repository test suite.

## Review Focus

- Add-on/server version mismatch — install both components from matching pinned releases and compare their version metadata.
- Existing global MCP configuration — inspect server names before adding entries; verify previous entries remain.
- Missing or incorrect Godot editor plugin setting — verify `godot/project.godot` references the installed plugin path.
- Blender 4.2 add-on discovery — check the installed module path against Blender 4.2's configured add-ons directory.
- Blender safety flags — inspect only the Blender MCP server's environment values and verify safe mode and telemetry-off are set.

---

### Task 1: Install Godot Editor MCP and project skills

**Files:**
- Create: `godot/addons/godot_mcp/` from the pinned Godot Editor MCP release archive.
- Create: `.agents/skills/godot-getting-started/`.
- Create: `.agents/skills/godot-playtest-and-debug/`.
- Create: `.agents/skills/godot-expert/`, including `references/`.
- Modify: `godot/project.godot` to enable the editor plugin.

- [x] **Step 1: Fetch the 2026.11.4 add-on archive and matching skill sources.** Confirm the release version before copying files.
- [x] **Step 2: Install the add-on and three skills at the listed paths.** Do not copy the MCP repository's development project or test files into this project.
- [x] **Step 3: Enable the plugin in `godot/project.godot`.** Preserve existing project settings.
- [x] **Step 4: Check the installed plugin metadata and skill folder contents.** Confirm `godot-expert/references/` is present.

### Task 2: Install and enable MCP for Blender 2.3.1

**Files:**
- Create: Blender 4.2 user add-on module via the package's `install-addon` command.
- Modify: Blender 4.2 user preferences to enable the add-on.

- [x] **Step 1: Install the add-on using `uvx --from mcp-for-blender==2.3.1 mcp-for-blender install-addon`.**
- [x] **Step 2: Enable the installed Blender 4.2 add-on.**
- [x] **Step 3: Check the add-on module path and Blender preference state.** Confirm auto-start is enabled for a GUI Blender session.

### Task 3: Register both global Codex MCP servers

**Files:**
- Modify: `%USERPROFILE%\.codex\config.toml` by adding only the `godot` and `blender` server entries.

- [x] **Step 1: Record existing MCP server names and back up the Codex config before editing.** Do not print or copy unrelated environment values.
- [x] **Step 2: Add the Godot server pinned to 2026.11.4 and the Blender server pinned to 2.3.1 using the full `uvx` path.** Set `BLENDER_MCP_SAFE_MODE=1`, `DISABLE_TELEMETRY=true`, `BLENDER_MCP_APPS=1`, and `BLENDER_MCP_OPENAI_FORMS=1` for Blender.
- [x] **Step 3: Run `codex mcp list` and inspect the two resulting server entries.** Confirm old server entries remain and Blender has the required environment settings.

### Task 4: Confirm setup readiness

**Files:**
- No additional project files.

- [x] **Step 1: Confirm the Godot project plugin loads under Godot 4.7.2 and is enabled in the project settings.**
- [x] **Step 2: Confirm Blender reports MCP for Blender enabled and auto-start is on for a GUI session.**
- [x] **Step 3: Record that Codex must be fully restarted to load new global MCP settings.** No game or asset-generation tests were run.
