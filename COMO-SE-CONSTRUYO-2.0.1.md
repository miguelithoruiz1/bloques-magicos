# Bloques Mágicos 2.0.1 — cómo se construyó

Corrección sobre la 2.0.0 (misma base, sin tocar 1.15 ni refactor).
Fuente en `~/workspace/bloques-2.0/`; build limpio en
`~/workspace/bloques-201-export/` (copia fresca, sin carpetas de
apktool dentro, para que el APK no arrastre archivos extra) y
trabajo de apktool en `~/workspace/bloques-201-work/` (fuera del
proyecto, lección aprendida: el primer intento 2.0.1 metió 210
archivos de apktool dentro del APK y se descartó).

## El bug (reporte del usuario, 2026-11-02 10:15)
Al entrar y dar Jugar, el juego quedaba como en su captura: cielo
azul y terreno en silueta negra. Diagnóstico real, no adivinado:
la escena nueva `scenes/refactor_main.tscn` nunca creaba luz ni
ambiente, a diferencia de `main.gd`/`hub.gd` de la 1.15, que sí
añadían un sol direccional. Sin ninguna luz, los materiales
sombreados del MultiMesh salen negros puros. El terreno SÍ se
generaba bien (la silueta de la captura es el relieve), solo
faltaba iluminarlo. El mismo bug afecta a la 1.16-refactor, que
usa la misma escena; la 2.0.1 lo corrige solo en la línea 2.0.

## La corrección
- `scripts/refactor/voxel_world_generator.gd`: `_ready()` llama a
  `_build_environment()`. El mundo crea su propio `WorldEnvironment`
  (cielo procedural con los colores de la 1.15 y luz ambiental
  desde el cielo) y un `DirectionalLight3D` «Sol» (rotación
  -52°, -32°, energía 1.15). Sombras apagadas a propósito: el
  stick onn mueve miles de instancias MultiMesh y se prioriza que
  se vea y rinda.
- `tests/refactor/test_2_0.gd`: 4 comprobaciones nuevas de la luz
  y el ambiente. Ojo: liberar el mundo con `world.free()` en el
  test cuelga el proceso headless (signal 11) al salir; por eso el
  test ya no lo libera (el aviso ObjectDB es inofensivo).
- `project.godot`: 2.0.1 / versionCode 10.
- Hallazgo lateral (no es del bug, no se tocó el juego): el test
  viejo `test_refactor.gd` no es repetible tal cual, porque
  `SpacedRepetitionManager` carga y guarda en `user://` real: la
  segunda corrida ya no da 7 en `prioridad_fallo_pesa`. Borrando
  ese archivo vuelve a pasar. Queda anotado, no corregido aquí.

## Pruebas headless (Godot 4.3, VM)
- `tests/refactor/test_2_0.gd`: **54/54, salida 0** (50 viejos +
  4 nuevos de luz/ambiente).
- `tests/refactor/test_refactor.gd`: **25/25, salida 0**, tras
  borrar el `spaced_repetition.json` contaminado por la corrida
  anterior (ver hallazgo lateral arriba).

## Build y verificación
Misma receta que la 2.0.0, con versionCode 10 y trabajo de apktool
fuera del proyecto: export sin Gradle → apktool (TV: touchscreen
no requerido, banner, LEANBACK_LAUNCHER; celular: sin leanback ni
banner) → zipalign → firma con el keystore debug de siempre.
Verificado: paquete `com.miguelitho.bloquesmagicos`, versionCode
10 / versionName 2.0.1 en ambos; TV con leanback + banner;
firmante SHA-256 47dfe528dd465b55f58cd07a89ea612294ea5d77b3198b71a8d8cf6c47d22e54
(idéntico a 1.12–2.0 → instala encima, conserva progreso);
`classes.dex` y `assets/data/blocks.json` dentro; **0 archivos de
apktool** dentro del APK limpio.

## APK finales (Drive, carpeta «Bloques magicos», tamaños/MD5 verificados)
- TV: BloquesMagicos-TV-2.0.1.apk, 50.525.421 bytes,
  MD5 8a6afc3461249539c1e654a12ef56252.
- Celular: BloquesMagicos-Celular-2.0.1.apk, 50.517.157 bytes,
  MD5 80f5243efe95dc4f6c3227615d6a5b9b.

## GitHub
Push a main autorizado por el usuario el 2026-11-02 (tocó «Sí,
súbela a GitHub main»). Solo archivos de texto (código, escenas,
datos, docs, `.import`): los 105 `.ogg` son binarios y la
herramienta de push trabaja con texto, así que el audio queda
fuera del repo y dentro del APK de Drive, que es el entregable.
Sin APKs, sin `export_presets.cfg` y sin tocar `.github/workflows`.

## Huecos honestos (siguen vigentes)
- No jugado en celular ni stick por mí: la 2.0.1 corrige la causa
  raíz, pero la confirmación visual final es del usuario.
- Decoración visual sin colisión; torres colocadas sin colisión
  (heredado del refactor).
