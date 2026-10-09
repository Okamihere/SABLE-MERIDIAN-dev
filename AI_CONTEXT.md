# SABLE MERIDIAN — contexto rápido para IA

Leia `AGENTS.md` antes de editar. Este arquivo é um mapa do projeto, não substitui a leitura da cena, script e recurso reais da tarefa. Use `rg` para localizar dependências e `git status --short` antes de qualquer alteração. Preserve mudanças existentes; edite somente o necessário.

## Projeto e fluxo atual

- Godot 4.7.2, GDScript, renderizador GL Compatibility. Jogo de ação 3D estilizado, gótico e teatral, com visual low-poly PS1/PS2.
- Cena inicial: `scenes/ui/press_start.tscn` → `scenes/ui/title_screen.tscn` → `scenes/levels/start_room.tscn` (primeira área/tutorial).
- O `FogGate` instanciado em `start_room.tscn` define `destination_scene = res://scenes/levels/vertical_pilot.tscn`. O valor padrão em `scripts/levels/fog_gate.gd` ainda aponta para `main.tscn`; a instância da primeira área sobrescreve esse valor. `scenes/levels/main.tscn` foi preservada, mas está fora desse fluxo.
- `vertical_pilot.tscn` agora é o hub: passarela central com oito portas laterais (`HubDoors/world_01..08`), quatro por lado, contador de chaves e indicação visual de conclusão. `scripts/levels/hub_door.gd` controla entrada por `F`; `scripts/levels/vertical_hub.gd` restaura o spawn junto à última porta. O bloco antigo de arenas, subidas, segredo e atalho permanece na cena como arquitetura e percurso secundário; os antigos inimigos do piloto estão desativados. Distinga geometria visual de blocos com `use_collision = true`.
- Todas as entradas do hub têm retorno pelo mesmo acesso: `scenes/levels/room_return_portal.tscn` liga hub→primeira área e mundo 01→hub; os mundos 02–08 usam portal de entrada em `hub_world_draft.gd`. `AreaTransition.travel_to(path, arrival)` aceita spawn opcional para voltar junto ao FogGate sem ricochete. O atalho antigo recebeu degraus de volta e agora pode ser subido.
- `scenes/levels/world_01.tscn` é o modelo completo: exploração → combate → plataformas/wall jump → arena final → boss → chave, `echo_blade` e retorno ao hub. `world_02..08.tscn` são sete grayboxes espaciais diferentes, ligados às portas, com combate/travessia e marcação de arena final; seus bosses e recompensas ainda são protótipos pendentes. `scripts/levels/hub_world_draft.gd` gera esses percursos. **Essas cenas jogáveis são distintas de `scenes/levels/worlds/world_01..08.tscn`**, que são cenários independentes para construção manual; editar estes últimos não altera automaticamente a entrada pelas portas do hub.
- `Progression` salva chaves/conclusões em `user://hub_worlds.cfg`, separado das orbes em `user://wall_orbs.cfg`; `complete_world`, `is_world_complete`, `key_count` e `hub_return_world` são a interface do hub. A arma `echo_blade` usa a tecla `3` e persiste por esse progresso.
- A transição usa `scripts/levels/fog_gate.gd` e o autoload `scenes/ui/area_transition.tscn`. Preserve spawn, câmera e HUD ao trocar destinos.
- A primeira área tem **um** boneco passivo, `Dummy0` (`scenes/enemies/training_dummy.tscn`), atualmente perto de `X=8,4; Y=0; Z=7,3`. Ele entra nos grupos `training_dummies` e `enemies`; `scripts/levels/start_room.gd` registra lock-on e acertos nele. Testes devem buscar o alvo da cena e posicionar o Player em relação à posição atual, sem exigir `Dummy1`.

## Construção modular GridMap

- A MeshLibrary graybox é `resources/gridmap/sable_graybox_mesh_library.tres`; o catálogo, envelopes, encaixes e instruções de substituição por GLB estão em `resources/gridmap/README.md`. Existem **33 IDs estáveis (0–32)**: 32 módulos arquitetônicos (0–31) e a água estilizada (32). Nunca renumere IDs ou substitua a MeshLibrary por outra ao trocar malhas: as células pintadas dependem desses números.
- A cena isolada `scenes/levels/gridmap_graybox_demo.tscn` usa `FloorsAndRamps` e `Walls`, ambos GridMaps nativos com célula `(2, 1, 2)` m, X/Z centralizados, Y não centralizado e colisão `World` (camada/máscara 1). A biblioteca usa colisões simples; degraus e detalhes são visuais, e escadarias usam uma colisão convexa contínua. Peças largas ou altas ocupam células vizinhas: confira a tabela antes de pintar ou rotacionar.
- `scenes/levels/worlds/world_01.tscn` até `world_08.tscn` são cenas editáveis e salvas separadamente, com Player, CameraRig, ambiente, luz, spawn seguro e GridMaps `FloorsAndRamps`, `Walls` e `Water` compartilhando a MeshLibrary. Os nomes atuais são: Coro Afundado, Galeria dos Espelhos, Poço das Cordas, Nave Partida, Arquivo Suspenso, Ponte dos Ecos, Camarotes Vazios e Torre do Silêncio. `world_02` já contém células pintadas; não suponha que os oito estejam vazios. Os mapas jogáveis ligados ao hub não foram migrados para esses templates.
- O módulo `00_Piso` tem superfície plana e colisão de laje com topo em Y=0. Para colocar água sobre chão, pinte primeiro o piso em `FloorsAndRamps` e depois o item 32 em `Water`, **na mesma célula e no mesmo nível Y**. A lâmina fica 0,04 m acima, é transparente, não tem colisão e usa coordenadas contínuas para evitar cortes entre quadrados. Pintar água em `FloorsAndRamps` substitui o piso; a água não sustenta o jogador. O material é `materials/stylized_water_gridmap.tres`, com `shaders/stylized_water.gdshader`.
- Portas, cortinas animadas e demais interativos devem ser cenas independentes. Para modelos finais do Blender, mantenha origem, escala e vão da peça e substitua o `Mesh` do mesmo ID, preservando colisões e células pintadas.

## Céu e renderização

- O renderizador do projeto é `gl_compatibility` (`project.godot`). `materials/contemplative_sky.tres` usa `shaders/contemplative_sky.gdshader` para o céu roxo com nuvens lentas e lua; as cenas jogáveis têm um `WorldEnvironment` com `Sky` próprio. As cenas de abertura usam o céu noturno existente. `tools/test_level_skyboxes.gd` verifica as 11 cenas de nível e as duas de abertura.
- `scenes/effects/stylized_water.tscn` e `materials/stylized_water.tres` compõem a água estilizada usada em `main.tscn`. Preserve o renderizador e os materiais ao editar a atmosfera.

## Câmera livre, lock-on e zonas fixas

- A câmera livre continua padrão em `scripts/camera/camera_controller.gd`/`scenes/player/camera_rig.tscn`. O lock-on seleciona alvos em `scripts/player/lock_on_controller.gd`; a câmera enquadra jogador e tamanho do alvo, considera combate aéreo, suaviza movimento e respeita colisões. A aquisição exige alvo visível e permite troca de alvo. Preserve a relação entre orientação da câmera, movimento e sprite de oito direções.
- `scenes/player/fixed_camera_zone.tscn` é uma `Area3D` reutilizável com `CollisionShape3D` e `ViewAnchor` (`Marker3D`). Instancie a zona na cena, ajuste o volume e a pose do marcador no editor; use `priority` da `Area3D` e `transition_duration` do script no Inspector. O CameraRig continua com uma única Camera3D, escolhe a zona sobreposta de maior prioridade, faz transições suaves e volta temporariamente à câmera livre quando jogador/alvo saem do enquadramento ou ficam obstruídos. `scenes/levels/fixed_camera_demo.tscn` é a demonstração isolada; os oito templates e o hub não receberam zonas automaticamente.

## Grimório vivo

- Arma em `resources/weapons/living_grimoire.tres`; os recursos de ataque ficam em `resources/attacks/grimoire_*.tres`. Mouse esquerdo: quatro invocações visuais distintas (página cortante, tapa de tinta, enxame e guilhotina) via `scripts/effects/grimoire_combo_visual.gd`, sem mana. Mouse direito no chão: **Mordida do Manuscrito**, 15 de dano e launcher, visual em `scripts/effects/grimoire_bite_visual.gd`; o segundo golpe leve continua podendo transitar para o launcher. Ataques aéreos próprios usam `grimoire_air_light/heavy.tres` e `scripts/effects/grimoire_air_visual.gd`, com limite de cadeia aérea. Efeitos e poses do livro ficam em `scripts/player/weapon_display.gd` e `scripts/effects/weapon_basic_*.gd`. Não alterar a lógica compartilhada de combate para ajustes só visuais.
- Q **Página Errante** (`grimoire_q`): 14 mana, 0,9 s de cooldown, projétil de origami amaldiçoado com conjuração, voo, rastro curto e impacto. Implementação visual em `scripts/effects/grimoire_q_visual.gd` e `grimoire_q_trail.gd`; lógica do projétil em `scripts/effects/cursed_card.gd`. Preserva lock-on, uso sem alvo e combate aéreo.
- E **Aplausos Obrigatórios** (`grimoire_e`): 23 mana, 5 s de cooldown, área persistente por 3,4 s, 10 de dano e um acerto por alvo. `scripts/effects/grimoire_e_effect.gd` mantém hitbox e busca piso válido para conjuração aérea sem atravessar andares; `grimoire_e_visual.gd` apresenta selo, mãos, aplausos, tinta/papel e feedback discreto para entradas tardias. O GridMap da água não interfere nessa busca de piso, pois não tem colisão.
- R **O Último Ato** (`grimoire_r`): 34 mana, 18 s de cooldown, uma marionete ativa por jogador por 12 s (duração configurável). `scenes/effects/grimoire_puppet.tscn` e `scripts/effects/grimoire_puppet.gd` cuidam de invocação, seguimento, alvo de lock-on ou inimigo próximo visível, obstáculos, retorno, ataques, golpe final/reverência e despawn. O placeholder, VFX e SFX são provisórios; preserve `SpellManager`, IA, hitboxes, dano e limpeza quando integrar um GLB final. A marionete não pertence ao grupo `enemies`.
- Os visuais do Grimório reutilizam SFX existentes e placeholders geométricos leves para GL Compatibility. Não trate essas malhas, animações ou sons como assets finais.

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
| GridMap e construção | `resources/gridmap/README.md`, `resources/gridmap/sable_graybox_mesh_library.tres`, `scenes/levels/worlds/`, `scenes/levels/gridmap_graybox_demo.tscn` |
| Câmeras fixas | `scenes/player/fixed_camera_zone.tscn`, `scripts/camera/fixed_camera_zone.gd`, `scenes/levels/fixed_camera_demo.tscn` |
| Grimório | `resources/weapons/living_grimoire.tres`, `scripts/effects/grimoire_*.gd`, `tools/test_grimoire_*.gd` |
| Céu e renderização | `materials/contemplative_sky.tres`, `shaders/contemplative_sky.gdshader`, `project.godot` |

## Validação

- Após editar, execute `python3 tools/validate_project.py` e o teste pertinente em `tools/test_*.gd` com `godot --headless --path . --rendering-method gl_compatibility --script res://tools/test_NOME.gd`. Para cenas, confirme também que carregam no Godot e teste o percurso ou interação real afetado.
- Para o hub, rode `tools/test_hub_flow.gd`, `tools/test_room_backtracking.gd` e `tools/test_hub_progress.gd`; valide primeira área ↔ hub ↔ cada mundo e o percurso do mundo 01. Testes de navegação temporários podem existir em `/tmp`, mas não são parte do repositório.
- GridMap: `tools/test_gridmap_library.gd` verifica os 33 IDs, quatro rotações, colisões, Player, câmera e wall jump na cena de demonstração. Abra cada `scenes/levels/worlds/world_XX.tscn` diretamente no editor para construir e use **F6** para testar a cena atual; F5 inicia o fluxo principal e ainda carrega os mundos jogáveis antigos do hub. `tools/test_gameplay.gd` verifica o treino com o alvo atual, a travessia ao hub e depois abre `main.tscn` diretamente para testar combate e respawn. `tools/test_weapon_skills.gd` e `tools/test_cursed_deck_zoom.gd` também usam `Dummy0`.
- Câmera fixa: `tools/test_fixed_camera_zone.gd`. Grimório: `tools/test_grimoire_light_combo.gd`, `test_grimoire_bite.gd`, `test_grimoire_errant_page.gd`, `test_grimoire_applause.gd`, `test_grimoire_air_*.gd` e `test_grimoire_puppet_*.gd`, conforme o fluxo alterado. Para VFX, teste também visualmente em janela com GL Compatibility; headless não renderiza as capturas.
- Alguns testes headless exibem avisos de `ObjectDB`/recursos ainda em uso ao encerrar mesmo após `PASS` e código de saída 0; diferencie esses avisos de falhas de asserção ou saída não zero.
- `python3 tools/validate_project.py` atualmente também varre `.agents/skills/` e pode acusar referências `res://` de exemplos das skills instaladas. Esses caminhos não pertencem ao jogo; se o validador falhar, confira se todas as ocorrências são desses arquivos antes de atribuir a falha ao projeto. `scenario-godot-vfx` está disponível em `.agents/skills/`, mas os comandos específicos de macOS/AgentKit do pacote não se aplicam automaticamente ao Linux/CachyOS deste projeto. Não use agentes do OpenCode.
- Regras e restrições: `AGENTS.md`. Detalhes adicionais de testes: `docs/validation.md`. Valores finos de gameplay e recursos devem ser lidos nos arquivos atuais; não os copie deste resumo.
