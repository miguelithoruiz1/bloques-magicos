# Bloques Mágicos 3.0.0 — cómo se construyó (primera entrega)

Base: copia de 2.0.2 en `~/workspace/bloques-3.0/` (1.15 y
`bloques-refactor/` intactos). Build limpio en
`~/workspace/bloques-30-export/` y trabajo de apktool en
`~/workspace/bloques-30-work/` (fuera del proyecto).

## Qué trae esta 3.0.0 (parcial, verificada)
- 20 misiones «Aventuras para empezar» (quest_system.gd),
  niveles con EXP y estaciones (level_system.gd), taller con
  5 recetas (workshop.gd).
- 16 animales amigos en anillo, pájaros ambientales,
  clima por estación (weather_system.gd), minimapa
  (minimap.gd) y línea de estado (nivel/EXP/día/estación/
  zona/clima/fps).
- 7 biomas base nuevos (océano, río, pantano, tundra
  nevada, sabana, desierto, jungla) + 26 especiales por
  anillo (biomes_special.gd) en generador y Ajustes
  (41 biomas elegibles).
- Catálogo de criaturas 246 (data/creatures.json +
  creature_catalog.gd): 22 pacíficas + 20 depredadores +
  40 fantásticas/jefes + 50 de facciones (10×5 roles) +
  106 variantes por bioma + 8 únicos.
- Multiedad: bandas 5-7 / 8-12 / 13+ (palabras y
  operaciones; división solo exacta y solo en 13+).
- Sol con energía de día 1.15 y de noche 0.4.
- project.godot: 3.0.0 / versionCode 12.

## Qué NO trae todavía (sigue en construcción, orden
## del usuario: todo el documento, sin recortes)
Catálogo de bloques 160+, IA completa de criaturas
(manadas, persecución, hordas), domesticación con
comida y monturas, combate y vitales, 6 razas, forja de
escultura, 8 estaciones, cuevas/estratos/estructuras,
música procedural por bioma y multijugador LAN.

## Pruebas headless (Godot 4.3, VM)
- `tests/refactor/test_3_0.gd`: TODO OK (misiones,
  niveles, taller, bloques nuevos, criaturas 246,
  biomas, especiales, bandas, división, animales 16,
  clima).
- `tests/refactor/test_3_0_scene.gd`: TODO OK (HUD con
  hijos, minimapa, nodos Quest/Level/Birds/Weather).
- `tests/refactor/test_2_0.gd`: 54/54.
- `tests/refactor/test_refactor.gd`: 27/27, SOLO tras
  borrar `spaced_repetition.json` y corriéndolo SOLO
  (test_2_0 escribe ese archivo y contamina la corrida:
  así se explicó el único FAIL visto al correrlos juntos).
- Lección nueva del test de escena: los _ready de la
  escena solo se disparan cuando el bucle principal
  itera; comprobar en el primer _process, no en _init
  (un quit() en _init mata los _ready y el HUD sale
  vacío aunque el código esté bien).

## Build y verificación
Misma receta que la 2.0.2, versionCode 12: export sin
Gradle (0 errores de script en ambos logs) → apktool
(TV: touchscreen no requerido, banner, LEANBACK_LAUNCHER;
celular: sin leanback ni banner) → zipalign → firma
con el keystore debug de siempre.
- apktool.yml trae versionCode 1 del export: se corrige
  a 12 a mano antes de reconstruir (como en la 2.0).
- apksigner es un script que exige `java` en el PATH:
  anteponer `~/workspace/godot-repro/jdk17/bin`.
- La contraseña del preset (export_presets.cfg) NO es
  la del keystore: el keystore debug estándar se abre
  con la contraseña por defecto de Android y su
  certificado es el de siempre; no extraer contraseñas
  del preset para firmar.
Verificado: paquete `com.miguelitho.bloquesmagicos`,
versionCode 12 / versionName 3.0.0 en ambos; TV con
leanback + banner; firmante SHA-256
47dfe528dd465b55f58cd07a89ea612294ea5d77b3198b71a8d8cf6c47d22e54
(idéntico a 1.12–2.0.2 → instala encima, conserva
progreso); `classes.dex`, `assets/data/blocks.json` y
`assets/data/creatures.json` dentro; 0 archivos de
apktool dentro del APK limpio.

## APK finales (Drive, carpeta «Bloques magicos»,
## tamaño/MD5 verificados contra Drive)
- TV: BloquesMagicos-TV-3.0.0.apk, 50.584.595 bytes,
  MD5 e19fb456c9575050b653d4c9a8994673, id
  1P_TSbqZl6UR0lFxmRDg-b_GZc6PE0fbk.
- Celular: BloquesMagicos-Celular-3.0.0.apk,
  50.572.235 bytes, MD5 e7b8245d2c55c333c3d63776ad59c223,
  id 12bqiFtKzUo1aWZcwnMOqD_G4FJ_ms2YB.

## GitHub
Pendiente: el push a main espera a que la 3.0 tenga
todo el documento (esta 3.0.0 es parcial). Al pushear:
solo texto, sin APKs, sin `export_presets.cfg`, sin
los 105 `.ogg` (el audio va completo en el APK de
Drive) y sin tocar `.github/workflows`.

## Huecos honestos (siguen vigentes)
- No jugado en celular ni stick por mí: la confirmación
  visual final es del usuario (joystick, botones,
  hotbar, mira, minimapa arriba-derecha, botones 🔨 y
  🎯 en la barra superior).
- Decoración visual sin colisión; torres colocadas sin
  colisión (heredado del refactor).
