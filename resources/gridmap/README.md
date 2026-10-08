# Graybox GridMap

Biblioteca: `sable_graybox_mesh_library.tres`. Demonstração: `../../scenes/levels/gridmap_graybox_demo.tscn`.

| ID fixo | Módulo | Encaixe e superfície |
| --- | --- | --- |
| 0 | Piso | 2 × 2 m; topo em Y=0 |
| 1 | Parede | borda norte (-Z); Y=-0,2 a 0,8 |
| 2 | Canto | bordas norte e oeste; Y=-0,2 a 0,8 |
| 3 | Plataforma | 2 × 2 m; topo em Y=1 |
| 4 | Rampa | sobe de +Z, Y=0, para -Z, Y=1 |
| 5 | Parede Wall Jump | mesma colisão e altura da parede; cor de identificação |
| 6 | Arco gótico | borda norte; 2 m de largura, Y=-0,2 a 2,8; vão livre de 1,4 × 2,15 m |
| 7 | Abertura para porta | mesmo envelope do arco; vão retangular de 1,4 × 2,15 m |
| 8 | Coluna | seção central de 0,5 × 0,5 m; Y=-0,2 a 0,8; empilhável |
| 9 | Parapeito | borda norte; Y=-0,2 a 0,7 |
| 10 | Sacada | laje 2 × 2 m com topo em Y=0; suportes visuais até Y=-0,6 |
| 11 | Escadaria | cinco degraus visuais; sobe de +Z, Y=0, para -Z, Y=1 |
| 12 | Arco gótico largo | borda norte; vão de 1,7 m; Y=-0,2 a 2,8 |
| 13 | Arco alto estreito | borda norte; vão de 1 m; Y=-0,2 a 3,8 |
| 14 | Janela gótica | borda norte; peitoril em Y=0,85; Y=-0,2 a 2,8 |
| 15 | Parede com abertura alta | borda norte; vão de 1,35 m; Y=-0,2 a 3,8 |
| 16 | Coluna alta | seção central de 0,6 × 0,6 m; Y=-0,2 a 2,8 |
| 17 | Coluna quebrada | seção central de 0,6 × 0,6 m; topo inclinado em Y=1,2–1,5 |
| 18 | Passarela estreita | piso de 1 × 2 m; topo em Y=0 |
| 19 | Ponte curta | piso de 2 × 2 m; topo em Y=0; vigas inferiores visuais |
| 20 | Sacada/camarote | laje 2 × 2 m; topo em Y=0; parapeito norte até Y=0,8 |
| 21 | Palco pequeno | bloco 2 × 2 m; topo em Y=0,8 |
| 22 | Palco largo | bloco 4 × 2 m; topo em Y=0,8; ocupa a célula atual e +X |
| 23 | Moldura cênica | abertura 3,2 m; Y=-0,2 a 3,8; ocupa a célula atual e +X |
| 24 | Escadaria monumental | largura 4 m, percurso 4 m; sobe de +Z, Y=0, para -Z, Y=2; ocupa +X e -Z |
| 25 | Plataforma elevada | bloco 2 × 2 m; topo em Y=2 |
| 26 | Corrimão teatral | borda norte; Y=-0,2 a 0,8; balaústres visuais |
| 27 | Moldura de cortina | borda norte; abertura 1,5 m; Y=-0,2 a 2,8 |
| 28 | Parede de fundo cênica | borda norte; Y=-0,2 a 2,8; nervuras visuais |
| 29 | Nicho/alcova | parede norte, laterais e teto; Y=-0,2 a 2,8; abertura sul |
| 30 | Canto interno | bordas norte e oeste; Y=-0,2 a 0,8 |
| 31 | Canto externo | bordas norte e leste; Y=-0,2 a 0,8 |

Os dois GridMaps da demonstração compartilham esta MeshLibrary: `FloorsAndRamps` e `Walls`. Ambos usam célula `(2, 1, 2)`, X/Z centralizados, Y não centralizado, escala 1 e camada de colisão 1 (`World`). Pinte pisos, rampas, plataformas, sacadas e escadarias no primeiro; paredes, cantos, arcos, vãos, colunas e parapeitos no segundo. Use a rotação de 90° da ferramenta GridMap para virar as peças direcionais. Empilhe paredes e colunas em células Y consecutivas. Parede e coluna terminam em Y=0,8 para encaixar na face inferior de um piso na célula Y=1; a face inferior aberta deve ficar coberta pelo piso de apoio.

Arco e vão de porta ocupam visualmente três alturas: deixe livres as células Y+1 e Y+2 no mesmo X/Z. Um piso na célula Y+3 encaixa na face superior em Y=2,8. A porta interativa deve ser uma cena independente. O parapeito pode ser pintado sobre uma sacada no outro GridMap. A escadaria reutiliza uma única colisão convexa em rampa; os degraus são apenas visuais. Os suportes sob a sacada também são apenas visuais.

Na demonstração, a galeria das peças novas fica a leste da arena inicial; contorne a parede de wall jump pelo lado sul para alcançá-la.

Os IDs 12–31 ampliam a galeria a leste com aberturas altas e colunas, um palco ao norte e uma ponte que leva a nichos e cantos. Use peças 18–25 no `FloorsAndRamps` e as demais no `Walls`. A moldura de cortina contém só estrutura: cortina animada e portas interativas são cenas independentes. O corrimão usa uma barreira simples; os balaústres, a escada e as vigas da ponte são visuais. Os módulos 13, 15 e 23 ocupam quatro alturas; reserve as células Y+1 a Y+3. Os módulos 12, 14, 16, 27, 28 e 29 ocupam três alturas; reserve Y+1 e Y+2. Os módulos 22–24 estendem-se para células vizinhas indicadas na tabela; deixe essas células livres no mesmo GridMap. Ao rotacionar, gire também a direção da extensão. A plataforma elevada ocupa Y+1; o topo em Y=2 se alinha a um piso nessa altura. Para unir a escadaria monumental a um palco de Y=0,8, use a plataforma de Y=2 ou outra transição de altura apropriada; os palcos têm altura cênica menor.

Para criar peças finais no Blender, modele em metros, aplique escala e rotação, mantenha a origem em `(0, 0, 0)` e respeite os envelopes e vãos da tabela. Exporte como `.glb` e importe no Godot. Na MeshLibrary existente, substitua apenas o recurso `Mesh` do mesmo `item/<ID>/mesh` pela malha importada; preserve `item/<ID>/shapes`, nomes e IDs. Os materiais devem estar nas superfícies da malha. Não exporte uma biblioteca nova sobre esta sem conferir os IDs: as células pintadas guardam esses números. A posição de uma célula `(0, 0, 0)` na cena é `(1, 0, 1)` por causa da centralização X/Z do GridMap.
