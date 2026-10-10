---
name: code-review
description: >
  Review code changes in SABLE MERIDIAN. Use when the user asks to review code, check for bugs,
  find regressions, verify NodePaths, check GDScript API compatibility, or validate that changes
  don't break existing systems. Focuses on concrete problems, not style preferences.
---

# Code Review — SABLE MERIDIAN

## Scope

Review only the diff and its integration points. Do not edit files during review.

## Checklist

### 1. NodePaths & References
- Verify all `get_node()` paths match the actual scene tree
- Check `res://` paths point to existing files (run `python3 tools/validate_project.py`)
- Confirm signal connections match emitted signal names

### 2. GDScript API Compatibility
- Godot 4.7 APIs only (no Godot 3 syntax)
- Autoloads: GameManager, CelShading, Progression, GraphicsSettings, PauseMenu, NpcInteraction, AreaTransition, MusicManager, PhantomCameraManager
- Check `class_name` conflicts with autoload names

### 3. System Integration
- **Player changes:** verify `player.gd` → `player_rig.tscn` node paths, state machine transitions
- **Combat changes:** check `combat_controller.gd` → `resources/attacks/*.tres` → hitbox/hurtbox pipeline
- **UI changes:** verify `hud.tscn` node paths, `pause_menu.gd` option handlers
- **Cross-system:** sprite directions, camera, lock-on — all read shared state

### 4. Common Regressions
- Null checks masking real bugs (don't hide broken references)
- Physics layers: 1=World, 2=Player, 3=Enemies, 4=Player hits, 5=Enemy hits, 6=Hurtboxes
- Characters face +Z; camera uses -Z
- Combat timers use physics delta; buffer/combo expiry use real time
- Death signal is synchronous — don't overwrite `DEAD` after fatal damage

### 5. Scope Creep
- Flag changes outside the task scope
- No refactoring, renaming, or "improvements" not requested

## Output Format

Classify findings by severity:
- **CRITICAL** — breaks gameplay, crashes, or corrupts saves
- **HIGH** — broken references, wrong API usage, system conflicts
- **MEDIUM** — edge cases, potential issues, missing validation
- **LOW** — style, minor improvements, documentation

If no relevant issues: respond `APPROVED`.

## Validation

After review, run:
```sh
python3 tools/validate_project.py
```
