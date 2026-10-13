# Paleta visual

A fonte de cores do jogo é `resources/palettes/sable_default.tres`. As cores seguem o Jester: carvão, ameixa, vinho, violeta, marfim e ouro; o ciano fica como contraste de armas e água. Os PNGs originais não são alterados.

## Ajustar no editor

Selecione um GridMap `Walls` e use **Paleta** na barra do pincel de paredes. Edite o recurso no Inspector; **Aplicar cores** salva os materiais compartilhados e a MeshLibrary, preservando seus IDs, colisões e variações de luminosidade. O jogo também lê o recurso diretamente ao iniciar.

## Variar um mundo

Duplique `resources/palettes/world_02.tres`. No mundo, crie um filho direto chamado `PaletteRegion` com `scripts/levels/palette_region.gd` e atribua o perfil. Ajuste `ambient_tint`, `light_tint`, `fog_tint` e `accent_tint`. Para materiais importados que precisam de correção local, informe os caminhos em `tint_targets` e ajuste `terrain_tint`; o sistema duplica o material da instância, preservando texturas e o arquivo original.

Os materiais de GridMap usam a paleta base compartilhada. As regiões se diferenciam por atmosfera, luz e acentos, sem duplicar a biblioteca de peças.
