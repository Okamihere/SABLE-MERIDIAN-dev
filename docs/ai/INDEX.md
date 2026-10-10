# SABLE MERIDIAN — AI Documentation Index

Quick routing for AI agents. Load only what you need for the task.

## Start Here

| Task | Go to |
|------|-------|
| Understand project structure | [`docs/architecture.md`](../architecture.md) |
| Combat & abilities | [`docs/combat_abilities.md`](../combat_abilities.md) |
| Equipment & weapons | [`docs/equipment.md`](../equipment.md) |
| Contribute / conventions | [`docs/contributing.md`](../contributing.md) |
| Validation & testing | [`docs/validation.md`](../validation.md) |

## Agent Skills

Located in `.agents/skills/`. Load only the relevant skill.

| Skill | Use when |
|-------|----------|
| `scenario-godot-expert` | Godot 4.7 development, headless jobs, scene building, GDScript architecture |
| `scenario-godot-vfx` | Particle effects, GPUParticles, visual effects, juice |
| `game-feel` | Screen shake, hit-stop, game feel, feedback polish |
| `code-review` | Reviewing code changes, finding bugs, checking regressions |
| `godot-testing` | Running tests, validating gameplay, headless testing |
| `find-skills` | Discovering installable skills from the ecosystem |

## Project Overview

- **Engine:** Godot 4.7.2, GDScript, Linux/CachyOS, GL Compatibility
- **Genre:** 3D action, dark fantasy, jester protagonist
- **Style:** Low-poly PS1/PS2, gothic surreal, purple/wine/gold

## Key Paths

| What | Where |
|------|-------|
| Player | `scenes/player/player_rig.tscn`, `scripts/player/player.gd` |
| Combat | `scripts/combat/combat_controller.gd`, `resources/attacks/` |
| UI | `scenes/ui/`, `scripts/ui/` |
| Levels | `scenes/levels/`, `scripts/levels/` |
| VFX | `scenes/effects/`, `scripts/effects/` |
| Tests | `tools/test_*.gd`, `tools/validate_project.py` |
| Autoloads | GameManager, CelShading, Progression, GraphicsSettings, PauseMenu, NpcInteraction, AreaTransition, MusicManager, PhantomCameraManager |

## Conventions

- Read real scenes/scripts before editing; verify NodePaths, signals, resources
- Preserve existing systems; change only necessary files
- No refactoring or renaming without request
- Test after changes: `tools/test_*.gd` headless + `python3 tools/validate_project.py`
- Never auto-commit or run destructive git commands
