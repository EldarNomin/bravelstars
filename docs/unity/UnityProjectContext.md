# Unity project context

Updated 2026-11-08. Migration source: `origin/dev` at `dfd3bc9`.
Project root: `unity/` in the `codex/U-01-unity-mobile` worktree.

## Confirmed environment and ownership

Unity 6000.3.25f1 / e1dba0a9aba4. Built-in render pipeline; custom
`Bravel/Mobile Palette` shader. uGUI 2.0.0; legacy input with EventSystem.
Android first, IL2CPP ARM64, API 26–36, OpenGLES3; Windows Mono used for runtime QA.
No Unity MCP provider installed. Local Editor batch commands and logs are available.

## Code and startup

- `Assets/Scripts/Sim`: plain C# data, map collision, world, match modes and bots.
  No Unity dependency. Seeded xorshift RNG; fixed 30 Hz; input commands;
  bounded projectile pool and typed event queue. One world owns state.
- `BravelGame`: composition root, input/tick accumulator, pause/focus lifecycle,
  camera, quality. Starts after loading `Assets/Scenes/Bravel.unity` through
  `RuntimeInitializeOnLoadMethod`; the scene is intentionally empty.
- `ArenaView`: original imported models, legacy animation clips, interpolated
  transforms, static batched arena, visibility and projectile presentation.
- `GameUi`, `TouchStick`, `SafeArea`: runtime uGUI, per-pointer ownership,
  safe-area anchors, selection, HUD, result, settings.
- `Resources/Data`: generated JSON from the source Godot `.tres`/maps/role profiles.
  `tools/unity/export_data.py --check` rejects drift. `Resources/Models`: converted
  FBX plus conversion receipts; `.meta` files are tracked.
- `Assets/Editor`: platform setup/build commands, model importer, portable checks.
  No custom asmdefs; Unity's default runtime/editor assemblies separate tooling.

## Validation entry points

`dotnet run --project tools/unity/checks/Checks.csproj` compiles the same simulation
sources and behavioral checks without Unity. `Bravel.Editor.MobileBuild.Validate`
runs them in Unity and validates imported clips/materials/layout calculations.
`MobileBuild.Windows` / `.Android` configure, validate and build.
`RuntimeSmoke` is a development-player harness activated by `-bravelSmoke`.
`tools/unity/verify.ps1 -WithAndroid` is the complete local verification workflow.
Detailed executed results and hardware gaps belong in `docs/unity/VALIDATION.md`.

## Constraints and unknowns

Godot remains the reference outside `unity/`, excluded from Unity assets; `.gdignore`
keeps Unity's files out of Godot imports. Do not edit `docs/PLAN.md`, `docs/TASKS.md`
or `project.godot` for migration work. New Unity work is scoped by `unity/AGENTS.md`.
No networking or service backend has been added. Performance, GPU memory, thermal
behavior and real finger input need physical Android acceptance. A desktop frame
rate does not establish a mobile frame rate.
