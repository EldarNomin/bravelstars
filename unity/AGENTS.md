# Unity migration

This directory is the Unity implementation requested by the owner. The Godot source
outside this directory remains the migration reference. Do not edit `project.godot`,
`docs/PLAN.md` or `docs/TASKS.md` as part of Unity work.

- Unity 6000.3.25f1; Android first. Built-in pipeline, small palette shader, uGUI,
  legacy input. No networking, monetization or service SDKs until the offline gate.
- `Assets/Scripts/Sim` is plain C#: no UnityEngine, Input, wall clock, scene objects
  or unseeded randomness. Gameplay numbers come from `Assets/Resources/Data`.
- Regenerate data using `python tools/unity/export_data.py` from the repo root;
  source balance lives in the Godot data during the migration. Never silently tune it.
- Keep `.meta` files. Ignore Library, Temp, UserSettings, builds and local logs.
- Validate pure simulation, Unity imports, player runtime and Android APK separately.
  PC pointer tests do not establish physical multitouch or Android performance.
- Work on one migration branch/PR to `dev`. Do not merge it yourself.
