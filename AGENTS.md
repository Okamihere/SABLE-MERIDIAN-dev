# SABLE MERIDIAN

## PROJECT / ENGINE

Action game 3D estilizado de dark fantasy com protagonista jester. Godot 4.7 (instalado: 4.7.2), GDScript, Linux/CachyOS, renderizador GL Compatibility. Direção visual: low-poly PS1/PS2, gótico e surreal, roxo/vinho/dourado discretos; evitar fantasy genérico.

## ARCHITECTURE / IMPORTANT SCENES

- Entrada: `scenes/ui/press_start.tscn` → `scenes/ui/title_screen.tscn` → `scenes/levels/start_room.tscn` ou `scenes/levels/main.tscn`.
- Ambos os níveis usam `scenes/player/player_rig.tscn`, `scenes/player/camera_rig.tscn` e `scenes/ui/hud.tscn`. `scenes/player/player.tscn` é uma representação simples separada: confirme qual cena está em uso antes de editar.
- `player_rig.tscn` tem `Player` (CharacterBody3D), `DirectionalSprite` (AnimatedSprite3D billboard), `ModelRoot` 3D atualmente oculto, `CombatController`, `LockOnController`, `StateMachine`, hitboxes e componentes. As oito direções visuais estão em `scripts/player/directional_sprite.gd`; poses do esqueleto são procedurais em `scripts/player/player_animation_controller.gd`.

## IMPORTANT SYSTEMS

- `scripts/player/player.gd` coordena locomoção, estados, esquiva, parede e equipamento. `scripts/combat/combat_controller.gd` usa `resources/attacks/*.tres`, hitboxes e input buffer; armas e magias ficam em `resources/weapons/`, `resources/spells/` e `scripts/resources/`.
- `scripts/player/lock_on_controller.gd` seleciona alvos; `scripts/camera/camera_controller.gd` controla a câmera; o sprite consulta câmera e alvo. Mudanças cruzadas exigem verificar direções do sprite, movimento e combate.
- `scripts/systems/game_manager.gd` cria ações no InputMap; `scripts/ui/pause_menu.gd` oferece opções e controles. UI em `scenes/ui/` e `scripts/ui/`.
- Shaders em `shaders/`; VFX em `scenes/effects/`, `scripts/effects/` e `scripts/levels/visual_atmosphere.gd` (GPUParticles3D). Áudio em `assets/audio/`, `MusicManager` e efeitos locais; buses Music/SFX são preparados pela UI. Autoloads: GameManager, CelShading, Progression, GraphicsSettings, PauseMenu, NpcInteraction, AreaTransition, MusicManager, PhantomCameraManager.

## CONVENTIONS / EDITING RULES

- Leia cena e script reais antes de editar; verifique NodePaths, sinais, recursos e fluxo. Preserve sistemas existentes e mudanças do usuário. Altere apenas arquivos necessários, sem refatoração ou renomeação gratuita; prefira componentes simples e sinais quando úteis.
- Não altere gameplay, assets, plugins, engine, renderizador ou sistema operacional fora do pedido. Não instale addons ou dependências sem autorização. Não mascare referências inválidas com null checks genéricos.
- Use o menor número de agentes necessário. Bug conhecido: especialista → revisão quando relevante. Causa desconhecida: explorer → especialista → revisão. Mudança cruzada: especialistas necessários → integration_tester → revisão. Arquitetura e performance só entram quando a tarefa exigir; paralelize apenas trabalhos independentes e nunca edição concorrente do mesmo arquivo.

## TESTING / SAFETY

- Antes de editar: `git status --short`; nunca reverta trabalho alheio. Após editar: teste o fluxo alterado, use testes pertinentes em `tools/test_*.gd` com Godot headless e `python3 tools/validate_project.py` quando apropriado; relate falhas preexistentes separadamente.
- Não execute limpeza ou reset destrutivo, remoção massiva, migração de versão nem commit automático. Não modifique arquivos do jogo para testar a infraestrutura de agentes.
