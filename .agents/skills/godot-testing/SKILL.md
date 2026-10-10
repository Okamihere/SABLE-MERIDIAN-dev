---
name: godot-testing
description: >
  Run and validate tests for SABLE MERIDIAN. Use when the user asks to test, validate, check for
  regressions, or verify gameplay. Covers headless test execution, project validation, and
  identifying test coverage gaps.
---

# Godot Testing — SABLE MERIDIAN

## Quick Validation

```sh
# Static checks (references, structure, main scene)
python3 tools/validate_project.py

# Headless import check
godot --headless --path . --editor --quit

# Specific test suites
godot --headless --path . --script tools/test_gameplay.gd
godot --headless --path . --script tools/test_wall_movement.gd
godot --headless --path . --script tools/test_hud.gd
godot --headless --path . --script tools/test_combat_timing.gd
godot --headless --path . --script tools/test_equipment.gd
```

## Test Files

| Test | Covers |
|------|--------|
| `test_gameplay.gd` | Ground, camera, animation, self-hit, dummies, combat tips, city transition, lock-on, death, restart |
| `test_wall_movement.gd` | Surface detection, grip, sliding, wall jumps, limits, ground refill, persistence |
| `test_hud.gd` | Health, mana, regeneration, limits, bindings after scene change/death |
| `test_combat_timing.gd` | Attack timing, combos, cancel windows |
| `test_equipment.gd` | Weapon equip, skills, cooldowns |
| `test_grimoire_*.gd` | Grimoire puppet, air combat, skills, bite, light combo |
| `test_weapon_skills.gd` | Weapon-specific skills and upgrades |

## Running Tests

### Headless (CI-friendly)
```sh
godot --headless --path . --script tools/test_<name>.gd
```

### With output
```sh
godot --headless --path . --script tools/test_<name>.gd 2>&1 | tee /tmp/test_output.txt
```

### Check for errors
```sh
godot --headless --path . --script tools/test_<name>.gd 2>&1 | grep -i "error\|fail\|warning"
```

## Interpreting Results

- **PASS** — all assertions met
- **FAIL** — check which assertion failed, trace to source
- **Parse errors** — GDScript syntax issues, check Godot 4.7 API
- **Missing references** — broken `res://` paths or NodePaths

## Coverage Gaps

Tests do NOT cover:
- All map routes or combos
- Performance or frame timing
- Visual appearance or animation feel
- Wall jump feel (requires manual evaluation)
- Camera behavior (requires manual evaluation)

## After Changes

1. Run `python3 tools/validate_project.py` first
2. Run relevant test suites for changed systems
3. Report PASS/FAIL with specific test names
4. Note any pre-existing failures separately from new regressions
