# SABLE MERIDIAN — contexto rápido para IA

Leia `AGENTS.md` antes de editar. Este arquivo é um mapa do projeto, não substitui a leitura da cena, script e recurso reais da tarefa. Use `rg` para localizar dependências e `git status --short` antes de qualquer alteração. Preserve mudanças existentes; edite somente o necessário.

## Projeto e fluxo atual

- Godot 4.7.2, GDScript, renderizador GL Compatibility. Jogo de ação 3D estilizado, gótico e teatral, com visual low-poly PS1/PS2.
- Cena inicial: `scenes/ui/press_start.tscn` → `scenes/ui/title_screen.tscn` → `scenes/levels/start_room.tscn` (primeira área/tutorial).
- O `FogGate` instanciado em `start_room.tscn` define `destination_scene = res://scenes/levels/vertical_pilot.tscn`. O valor padrão em `scripts/levels/fog_gate.gd` ainda aponta para `main.tscn`; a instância da primeira área sobrescreve esse valor. `scenes/levels/main.tscn` foi preservada, mas está fora desse fluxo.
- `vertical_pilot.tscn`: entrada → Arena 1 → subidas laterais/plataformas e wall jump → Arena 2 → galeria superior → Arena 3/palco → ascensão → boss. Há segredo lateral e atalho de queda que reconecta áreas anteriores. Em `Blockout`, as superfícies jogáveis ficam em grupos como `WestAscent`, `EastWallJumpRoute`, `UpperGallery`, `BossAscent` e `OneWayShortcut`; a massa arquitetônica modular fica em `Blockout/Architecture`. Distinga geometria visual de blocos com `use_collision = true` ao alterar o percurso.
- A transição usa `scripts/levels/fog_gate.gd` e o autoload `scenes/ui/area_transition.tscn`. Preserve spawn, câmera e HUD ao trocar destinos.

## Player e sistemas

- Os níveis usam `scenes/player/player_rig.tscn`, `scenes/player/camera_rig.tscn` e `scenes/ui/hud.tscn`. `scenes/player/player.tscn` é uma representação separada; confirme a instância real antes de editar.
- `player_rig.tscn`: `Player` (`CharacterBody3D`), `DirectionalSprite` (`AnimatedSprite3D` de 8 direções), `ModelRoot` 3D oculto, `CombatController`, `LockOnController`, `StateMachine`, hitboxes e componentes. A orientação do sprite depende da câmera e do lock-on.
- Movimento, esquiva, pulo e parede: `scripts/player/player.gd` e `scripts/player/wall_movement.gd`. Câmera: `scripts/camera/camera_controller.gd`. Sprite: `scripts/player/directional_sprite.gd`. Combate: `scripts/combat/combat_controller.gd`, `resources/attacks/`, `resources/weapons/` e `resources/spells/`.
- Autoloads em `project.godot`: `GameManager`, `CelShading`, `Progression`, `GraphicsSettings`, `UiSfx`, `PauseMenu`, `NpcInteraction`, `AreaTransition`, `MusicManager`, `PhantomCameraManager`. Consulte o arquivo para caminhos exatos e lista atual.
- Interface em `scenes/ui/` e `scripts/ui/`; áudio em `assets/audio/` e `scripts/systems/music_manager.gd`/`ui_sfx.gd`; efeitos em `scenes/effects/`, `scripts/effects/` e `shaders/`.

## Navegação por tarefa

| Tema | Comece por |
| --- | --- |
| Fluxo e níveis | `scenes/levels/`, `scripts/levels/`, `scenes/ui/area_transition.tscn` |
| Player, sprite, parede | `scenes/player/player_rig.tscn`, `scripts/player/` |
| Câmera e lock-on | `scenes/player/camera_rig.tscn`, `scripts/camera/`, `scripts/player/lock_on_controller.gd` |
| Combate e equipamentos | `scripts/combat/`, `scripts/components/`, `scripts/resources/`, `resources/` |
| HUD e menus | `scenes/ui/`, `scripts/ui/` |
| VFX e áudio | `scenes/effects/`, `scripts/effects/`, `shaders/`, `assets/audio/` |

## Validação

- Após editar, execute `python3 tools/validate_project.py` e o teste pertinente em `tools/test_*.gd` com `godot --headless --path . --script res://tools/test_NOME.gd`. Para cenas, confirme também que carregam no Godot e teste o percurso ou interação real afetado.
- Para `vertical_pilot`, confira entrada → boss, rota alternativa, wall jump, segredo, atalho e transição desde a primeira área. Testes de navegação temporários podem existir em `/tmp`, mas não são parte do repositório.
- **Teste desatualizado conhecido:** `tools/test_gameplay.gd:111` ainda exige `main.tscn` após o FogGate. O destino atual da primeira área é `vertical_pilot.tscn`; uma falha isolada nessa asserção não indica regressão da transição. Verifique o restante do teste e não mude o jogo para satisfazer essa expectativa antiga.
- Regras e restrições: `AGENTS.md`. Detalhes adicionais de testes: `docs/validation.md`, se presente. Valores finos de gameplay e recursos devem ser lidos nos arquivos atuais; não os copie deste resumo.
