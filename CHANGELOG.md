# Changelog — SABLE MERIDIAN

Histórico de novidades do protótipo. A página principal ([README](README.md), seção
“Novidades”) mostra os últimos commits; este arquivo guarda o detalhe.

> **Como manter atualizado:** após cada commit, rode
> `python3 tools/update_changelog.py` — o bloco automático no final deste arquivo
> é regenerado a partir do `git log`. Entradas manuais (destaques por versão)
> ficam acima dos marcadores e nunca são sobrescritas.

## Destaques

### Protótipo atual (outubro/2026)

- Tela **press-start cinematográfica** (“PRESS START TO PLAY”) como cena inicial,
  com voo de câmera e transição com fade para o título.
- Pátio de treino → hub vertical → **8 mundos** com portas, chaves persistentes e
  portais de retorno; mundo 01 com ciclo completo (boss → chave + Lâmina do Eco).
- Combate teatral: combos de 4 golpes com launcher, ataques aéreos, esquiva com
  i-frames, **esquiva perfeita em câmera lenta** e ranking de estilo **D–S**.
- **6 armas jogáveis** com skills **Q/E/R**, Máscara do Riso (`Tab`), Bilhete do Bis,
  magias de cartas com mana/cooldown, lock-on e saltos em parede com orbes.
- Kit de construção **GridMap graybox** (32 peças estáveis), céu contemplativo,
  água estilizada, HUD de vela com HP/MP, pausa e opções persistentes
  (presets LOW–ULTRA, modo sem bordas).

<!-- AUTO-START -->

## Novidades (gerado do git log)

_Atualizado via `python3 tools/update_changelog.py`. Não edite este bloco manualmente._

- `2026-10-08` `2709af3` — docs: pagina completa com novidades e CHANGELOG auto; inclui worlds GridMap e AI_CONTEXT
- `2026-10-08` `7e6bd0a` — feat: worlds 01-08, hub flow, gridmap graybox, water/sky shaders, audio, combat/player/ui updates
- `2026-10-07` `3b2a2cc` — docs: nova pagina com banner press-start, sinopse, mundos e galeria
- `2026-10-06` `97bd87d` — update: combat, style meter, ui, weapons, spells, levels e testes
- `2026-10-05` `1abd315` — docs: banner do README com a tela press start
- `2026-10-05` `0efdfad` — fix: transicao press-start com fade de 1s sobre o voo da camera
- `2026-10-05` `9e994d5` — feat: tela press start CRT antes do titulo, main scene para press_start
- `2026-10-05` `791ba49` — visual: pipeline grafico A-I, camera proxima e Veyl
- `2026-10-04` `44d6343` — build: presets de exportacao Linux + Windows
- `2026-10-04` `d6bb7f6` — Revert "docs: README direto, sem enfeite"
- `2026-10-04` `8c5e7c2` — docs: README direto, sem enfeite
- `2026-10-04` `ee5fc76` — docs: hero do README com cara de pagina lancada
- `2026-10-04` `a8c67e6` — docs: troca capa do README pela nova tela de inicio
- `2026-10-04` `32153ba` — docs: README com galeria, video e novidades do prototipo
- `2026-10-04` `e24e520` — docs: prints e video do jogo com mecanicas
- `2026-10-04` `67417e8` — feat: grimorio 3D, settings comerciais, mouse capture e HUD
- `2026-10-04` `1b2da75` — fix: prevent hud scaling above editor size
- `2026-10-04` `62c91f0` — feat: adiciona moldura HP/MP na HUD e adapta barras ao novo design
- `2026-10-03` `3f3b3ff` — fix: auditoria ampla de seguranca - null guards, lifecycle e cleanup
- `2026-10-02` `05b9d50` — feat: add graphics quality settings

<!-- AUTO-END -->
