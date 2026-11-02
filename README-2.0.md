# Bloques Mágicos 2.0 — a partir del informe de Cube Unbound

**Base:** variante refactorizada 1.16 (sin validar aún por el usuario),
copiada aparte en `bloques-2.0/`. La 1.15.0 y el refactor quedan
intactos. Versión: **2.0.0 / versionCode 9** (en `project.godot`).

**Regla de inspiración:** solo arquitectura e ideas, nunca assets
ajenos. No se copian modelos `.vox`, JSON ni shaders de Cube
Unbound. Todo el arte es procedural propio (BoxMesh) y las voces
son las de la familia.

## Lo que ya existía en la variante (no se rehizo)

- Terreno por semilla con FastNoiseLite, guardado diferencial
  (`modified_blocks`), biomas de aprendizaje, hotbar 9 + inventario
  por pestañas, Creativo/Supervivencia, palabras y matemáticas,
  auto-paso por altura de columna (subir 1 bloque al caminar).
- Por eso la 2.0 no reescribe el mundo: añade lo que faltaba del
  plan de Cube y deja intacto lo de aprendizaje (letras, números,
  colores, palabras, voces 105 .ogg).

## Lo nuevo en 2.0

1. **Catálogo de bloques en datos** (`data/blocks.json` +
   `scripts/refactor/block_catalog.gd`): id, nombre, color, dureza,
   forma, luz y familia de sonido. Si el JSON falta en la
   exportación, el catálogo usa la misma tabla incrustada.
   Bloques nuevos, fuera de los rangos de aprendizaje:
   tablones 84, ladrillo 85, vidrio 86, nieve 87, cristal brillo 88.
   Pestaña nueva en el inventario: «Construcción».
2. **4 biomas del plan** (`scripts/refactor/biomes2.gd` + generador
   + Ajustes > Mundo y Semilla): Pradera Verde, Playa y Mar
   (palmeras), Bosque Mágico (árboles + setas de cristal brillo) y
   Montaña Nevada (pinos + superficie de nieve). Sin peligro ni
   enemigos: la diferencia es visual y de aprendizaje. Los 4 biomas
   viejos siguen en la lista. Default para instalaciones nuevas:
   Pradera Verde (quien ya tiene ajustes guardados conserva su
   bioma).
3. **Guardado diferencial v2** (`scripts/refactor/save_v2.gd`):
   nombre, semilla, jugador (posición + inventario) y ediciones
   agrupadas por región 16x16, como el ejemplo del plan. La v1
   sigue siendo el guardado principal; la v2 se escribe además
   al guardar, en `user://worlds_v2/`.
4. **Animales amigos** (`scripts/refactor/friendly_animal.gd`):
   oveja, perro, pollo y slime amistoso, en cubos propios, con
   patas procedurales (sin/cos) y 3 estados (IDLE, WANDER, FOLLOW).
   Acercarse y quedarse cerca 3.5 s = amigo (♥ encima) y te sigue.
   Sin combate, sin hambre, sin muerte, sin monstruos.
5. **Avatar** (`scripts/refactor/avatar_custom.gd` +
   `PlayerBlocky.apply_avatar`): sombreros Explorador, Caballero,
   Astronauta y Rana (procedurales) + camiseta azul/roja/verde/
   amarilla, elegidos en el título y guardados en
   `user://avatar.json`.
6. **Ala delta** (`PlayerBlocky`): al caer, la velocidad no pasa
   de -2.5 bloques/s y aparecen alas blancas (solo fuera de
   primera persona). No es vuelo libre: solo frena la caída.
   Auto-paso: ya existía por altura de columna; se documenta, no
   se duplicó.

## Lo del plan que NO se hizo (a propósito, para un niño de 5 años)

- 37 biomas con zonas de peligro nivel 1-999, 246 criaturas,
  combate, jefes, hordas, cuevas con trampas, supervivencia con
  vida/maná/temperatura y crafteo por estaciones: fuera de
  alcance y fuera de tono para Bloques Mágicos.
- Color por vértice con paleta 1D y shaders propios: el generador
  ya usa MultiMesh con color por instancia, que es la misma idea
  adaptada a Godot sin shaders a medida.
- Multijugador LAN, skins `.vox` importadas y mundo de 32x192:
  no se tocan; el juego sigue sin red, sin cuentas y sin
  importaciones de archivos del usuario.

## Probar

- Headless: `godot --headless --path . -s tests/refactor/test_2_0.gd`
  (y el viejo `test_refactor.gd` debe seguir en verde).
- En el juego: título 2.0 → elegir sombrero/camiseta → Jugar →
  Ajustes > Mundo y Semilla → elegir un bioma nuevo → volver a
  Jugar (el bioma se aplica al generar el mundo) → acercarse a
  un animal 3.5 s → ver ♥ → caer desde una montaña y ver las
  alas frenando la caída → pestaña Construcción → poner
  tablones/ladrillo/vidrio/nieve/cristal → Pausa → Guardar.

## 2.0.1 — corrección pantalla negra (2026-11-02)

Al probar la 2.0.0 en el celular, dar Jugar dejaba el juego con
cielo azul y terreno en silueta negra. Causa: la escena
`refactor_main.tscn` nunca creaba luz ni ambiente (la 1.15 sí
creaba su sol en `main.gd`/`hub.gd`). Corrección:
`VoxelWorldGenerator._ready()` ahora construye su propio cielo y
un sol direccional (energía 1.15, sin sombras para el stick).
Tests: 54/54 en 2.0 y 25/25 en el viejo. Detalle en
`COMO-SE-CONSTRUYO-2.0.1.md`. La 1.16-refactor tiene el mismo
bug sin corregir.

## Pendiente de validación (no afirmado)

- Ejecución real en celular y stick: la prueba headless no
  sustituye jugarlo. Lista de pruebas en la entrega del APK.
- La decoración (árboles, palmeras, pinos, setas) es visual:
  no entra en `get_block`, igual que los árboles viejos.
- El JSON `data/blocks.json` debe aparecer en el APK; si no,
  el catálogo usa el fallback y el juego sigue igual (verificado
  en el test por la tabla incrustada, no por el archivo dentro
  del APK: revisar con `unzip -l` tras construir).
