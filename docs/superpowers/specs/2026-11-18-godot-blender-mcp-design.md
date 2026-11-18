# Godot and Blender MCP Setup

## Intent

Connect Codex to the live Godot project and the installed Blender application so it can inspect, edit, and validate scenes through MCP tools.

## Current state and constraints

- The project uses Godot 4.7.2; Blender 4.2.2 LTS is installed.
- Codex already has unrelated MCP servers configured. Add entries without replacing existing configuration.
- Blender's official MCP requires Blender 5.1 or newer, so it does not fit this installation.

## Approaches

- **Recommended: live-editor bridges.** Use Godot Editor MCP 2026.11.4, which supports Godot 4.4–4.7 and was validated on 4.7, plus MCP for Blender 2.3.1, which supports Blender 4.2. This gives Codex editor-aware scene tools in both applications. Godot toolsets remain gated by default; Blender runs with safe mode enabled and telemetry disabled.
- **Godot CLI bridge.** The established Coding-Solo server can launch Godot, inspect output, and make some scene edits, but it does not provide the same live-editor workflow.
- **Blender Lab MCP.** It is Blender's official bridge, but it requires Blender 5.1+, which would require changing the installed Blender version.

## Chosen scope

Add both MCP servers to the global Codex config so they are available across projects. Install the Godot editor add-on and the three companion Godot skills into this repository. Install the Blender add-on in the Blender 4.2 user profile.

## Implementation details

- Pin Godot Editor MCP to `2026.11.4` and MCP for Blender to `2.3.1`, launched through the installed `uvx` executable.
- Enable Godot Editor MCP in `godot/project.godot` and copy its `godot-getting-started`, `godot-playtest-and-debug`, and `godot-expert` skills (including references) into `.agents/skills/`.
- Configure Blender MCP with `BLENDER_MCP_SAFE_MODE=1` and `DISABLE_TELEMETRY=true`. Enable its Codex viewport and asset picker surfaces, and keep the Blender connection on localhost.
- Preserve all existing Codex server entries and existing project files outside the required add-on, skill, and configuration changes.
- Do not configure paid or cloud model-generation services or API credentials.

## Verification

Confirm both pinned servers are registered and startable, confirm each add-on is present and enabled, and confirm the Godot MCP reports the expected project connection. Do not run the repository's test suite as part of installation.
