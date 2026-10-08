# SABLE MERIDIAN — contexto rápido para IA

Leia `AGENTS.md` antes de editar. Este arquivo é um mapa do projeto, não substitui a leitura da cena, script e recurso reais da tarefa. Use `rg` para localizar dependências e `git status --short` antes de qualquer alteração. Preserve mudanças existentes; edite somente o necessário.

## Projeto e fluxo atual

- Godot 4.7.2, GDScript, renderizador GL Compatibility. Jogo de ação 3D estilizado, gótico e teatral, com visual low-poly PS1/PS2.
- Cena inicial: `scenes/ui/press_start.tscn` → `scenes/ui/title_screen.tscn` → `scenes/levels/start_room.tscn` (primeira área/tutorial).
- O `FogGate` instanciado em `start_room.tscn` define `destination_scene = res://scenes/levels/vertical_pilot.tscn`. O valor padrão em `scripts/levels/fog_gate.gd` ainda aponta para `main.tscn`; a instância da primeira área sobrescreve esse valor. `scenes/levels/main.tscn` foi preservada, mas está fora desse fluxo.
- `vertical_pilot.tscn` agora é o hub: passarela central com oito portas laterais (`HubDoors/world_01..08`), quatro por lado, contador de chaves e indicação visual de conclusão. `scripts/levels/hub_door.gd` controla entrada por `F`; `scripts/levels/vertical_hub.gd` restaura o spawn junto à última porta. O bloco antigo de arenas, subidas, segredo e atalho permanece na cena como arquitetura e percurso secundário; os antigos inimigos do piloto estão desativados. Distinga geometria visual de blocos com `use_collision = true`.
- Todas as entradas do hub têm retorno pelo mesmo acesso: `scenes/levels/room_return_portal.tscn` liga hub→primeira área e mundo 01→hub; os mundos 02–08 usam portal de entrada em `hub_world_draft.gd`. `AreaTransition.travel_to(path, arrival)` aceita spawn opcional para voltar junto ao FogGate sem ricochete. O atalho antigo recebeu degraus de volta e agora pode ser subido.
- `scenes/levels/world_01.tscn` é o modelo completo: exploração → combate → plataformas/wall jump → arena final → boss → chave, `echo_blade` e retorno ao hub. `world_02..08.tscn` são sete grayboxes espaciais diferentes, ligados às portas, com combate/travessia e marcação de arena final; seus bosses e recompensas ainda são protótipos pendentes. `scripts/levels/hub_world_draft.gd` gera esses percursos.
- `Progression` salva chaves/conclusões em `user://hub_worlds.cfg`, separado das orbes em `user://wall_orbs.cfg`; `complete_world`, `is_world_complete`, `key_count` e `hub_return_world` são a interface do hub. A arma `echo_blade` usa a tecla `3` e persiste por esse progresso.
- A transição usa `scripts/levels/fog_gate.gd` e o autoload `scenes/ui/area_transition.tscn`. Preserve spawn, câmera e HUD ao trocar destinos.
- A primeira área tem **um** boneco passivo, `Dummy0` (`scenes/enemies/training_dummy.tscn`), atualmente perto de `X=8,4; Y=0; Z=7,3`. Ele entra nos grupos `training_dummies` e `enemies`; `scripts/levels/start_room.gd` registra lock-on e acertos nele. Testes devem buscar o alvo da cena e posicionar o Player em relação à posição atual, sem exigir `Dummy1`.

## Construção modular GridMap

- A MeshLibrary graybox é `resources/gridmap/sable_graybox_mesh_library.tres`; o catálogo, envelopes, encaixes e instruções de substituição por GLB estão em `resources/gridmap/README.md`. Existem **32 IDs estáveis (0–31)**: base arquitetônica 0–11 e expansão gótico-teatral 12–31 (arcos altos, janela, colunas, ponte, passarela, palcos, camarote, molduras, escadaria monumental, nicho e cantos). Nunca renumere IDs ou substitua a MeshLibrary por outra ao trocar malhas: as células pintadas dependem desses números.
- A cena isolada `scenes/levels/gridmap_graybox_demo.tscn` usa `FloorsAndRamps` e `Walls`, ambos GridMaps nativos com célula `(2, 1, 2)` m, X/Z centralizados, Y não centralizado e colisão `World` (camada/máscara 1). A biblioteca usa colisões simples; degraus e detalhes são visuais, e escadarias usam uma colisão convexa contínua. Peças largas ou altas ocupam células vizinhas: confira a tabela antes de pintar ou rotacionar.
- O kit é editável pelo GridMap nativo e está **apenas na demonstração**; os mapas jogáveis existentes não foram migrados. Portas, cortinas animadas e demais interativos devem ser cenas independentes. Para modelos finais do Blender, mantenha origem, escala e vão da peça e substitua o `Mesh` do mesmo ID, preservando colisões e células pintadas.

## Céu e renderização

- O renderizador do projeto é `gl_compatibility` (`project.godot`). `materials/contemplative_sky.tres` usa `shaders/contemplative_sky.gdshader` para o céu roxo com nuvens lentas e lua; as cenas jogáveis têm um `WorldEnvironment` com `Sky` próprio. As cenas de abertura usam o céu noturno existente. `tools/test_level_skyboxes.gd` verifica as 11 cenas de nível e as duas de abertura.
- `scenes/effects/stylized_water.tscn` e `materials/stylized_water.tres` compõem a água estilizada usada em `main.tscn`. Preserve o renderizador e os materiais ao editar a atmosfera.

## Player e sistemas

- Os níveis usam `scenes/player/player_rig.tscn`, `scenes/player/camera_rig.tscn` e `scenes/ui/hud.tscn`. `scenes/player/player.tscn` é uma representação separada; confirme a instância real antes de editar.
- `player_rig.tscn`: `Player` (`CharacterBody3D`), `DirectionalSprite` (`AnimatedSprite3D` de 8 direções), `ModelRoot` 3D oculto, `CombatController`, `LockOnController`, `StateMachine`, hitboxes e componentes. A orientação do sprite depende da câmera e do lock-on.
- Movimento, esquiva, pulo e parede: `scripts/player/player.gd` e `scripts/player/wall_movement.gd`. Câmera: `scripts/camera/camera_controller.gd`. Sprite: `scripts/player/directional_sprite.gd`. Combate: `scripts/combat/combat_controller.gd`, `resources/attacks/`, `resources/weapons/` e `resources/spells/`.
- O cajado usa projéteis nos ataques básicos (`resources/weapons/staff.tres`); ao testar dano por sobreposição de hitboxes corpo a corpo, equipe uma arma apropriada, como `cane_blade`. Os inimigos antigos do hub têm `process_mode = DISABLED` e não servem como alvos de testes de física; `main.tscn` ainda pode ser carregada isoladamente como cena de combate.
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
| GridMap e construção | `resources/gridmap/README.md`, `resources/gridmap/sable_graybox_mesh_library.tres`, `scenes/levels/gridmap_graybox_demo.tscn` |
| Céu e renderização | `materials/contemplative_sky.tres`, `shaders/contemplative_sky.gdshader`, `project.godot` |

## Validação

- Após editar, execute `python3 tools/validate_project.py` e o teste pertinente em `tools/test_*.gd` com `godot --headless --path . --rendering-method gl_compatibility --script res://tools/test_NOME.gd`. Para cenas, confirme também que carregam no Godot e teste o percurso ou interação real afetado.
- Para o hub, rode `tools/test_hub_flow.gd`, `tools/test_room_backtracking.gd` e `tools/test_hub_progress.gd`; valide primeira área ↔ hub ↔ cada mundo e o percurso do mundo 01. Testes de navegação temporários podem existir em `/tmp`, mas não são parte do repositório.
- GridMap: `tools/test_gridmap_library.gd` verifica os 32 IDs, quatro rotações, colisões, Player, câmera e wall jump na cena de demonstração. `tools/test_gameplay.gd` verifica o treino com o alvo atual, a travessia ao hub e depois abre `main.tscn` diretamente para testar combate e respawn. `tools/test_weapon_skills.gd` e `tools/test_cursed_deck_zoom.gd` também usam `Dummy0`.
- Alguns testes headless exibem avisos de `ObjectDB`/recursos ainda em uso ao encerrar mesmo após `PASS` e código de saída 0; diferencie esses avisos de falhas de asserção ou saída não zero.
- Regras e restrições: `AGENTS.md`. Detalhes adicionais de testes: `docs/validation.md`. Valores finos de gameplay e recursos devem ser lidos nos arquivos atuais; não os copie deste resumo.
