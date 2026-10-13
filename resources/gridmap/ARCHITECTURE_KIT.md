# Kit modular de arquitetura

Abra um mundo e selecione o GridMap `Walls` graybox. Na barra superior, use **Kit 3D → Editar seed** e depois **Gerar peças e prévia**. A geração grava `sable_architecture_kit.tres` e abre `gridmap_architecture_kit_preview.tscn`. A mesma seed produz as mesmas formas. **Abrir prévia** não regenera nada.

A biblioteca tem dez peças: duas paredes, dois arcos, duas colunas, duas escadas e duas ruínas. Todas usam os materiais compartilhados `stone.tres` e `stone_light.tres`, ajustados pela paleta global. As peças seguem o GridMap de célula `(2, 1, 2)`, com X/Z centralizados e Y não centralizado. Paredes e arcos ficam na borda local −Z; escadas sobem de +Z para −Z. Gire as peças com a ferramenta GridMap nativa.

Para usá-las num mundo, crie **um GridMap adicional** com esta MeshLibrary, célula `(2, 1, 2)`, `cell_center_y = false` e colisão na camada `World` (1). Mantenha `FloorsAndRamps` e `Walls` atuais. Não pinte uma peça nova sobre uma passagem já ocupada; arcos e colunas altas precisam das duas células Y acima livres. O pincel de autoalinhamento continua dedicado às paredes graybox.
