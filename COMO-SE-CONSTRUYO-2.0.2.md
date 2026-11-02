# Bloques Mágicos 2.0.2 — cómo se construyó

Corrección sobre la 2.0.1 (misma base, sin tocar 1.15 ni refactor).
Fuente en `~/workspace/bloques-2.0/`; build limpio en
`~/workspace/bloques-202-export/` y trabajo de apktool en
`~/workspace/bloques-202-work/` (fuera del proyecto).

## El bug (reporte del usuario, 2026-11-02 10:35)
En la 2.0.1 el mundo ya se veía iluminado, pero NO salían los
botones ni el joystick: en la captura no había HUD, ni hotbar,
ni mira. Diagnóstico probado en la VM, no adivinado: al instanciar
`scenes/refactor_main.tscn` en headless, `TouchAndTVControls`
quedaba como CanvasLayer vacío (0 hijos) porque su script no
cargaba. Causa en `scripts/refactor/ui_controller.gd`, líneas del
dpad: `var up := mk.call("▲", ...)` y sus tres hermanas. `call()`
devuelve Variant y `:=` con Variant no compila en este Godot (la
inferencia se trata como error). Al fallar ese script, el HUD
entero no se construía. Los logs de exportación de la 2.0.1 ya
traían esos 4 errores, tapados por el aviso del apksigner: lección,
revisar los logs de export completos, no solo la última línea.

## Las correcciones
- `ui_controller.gd`: las 4 variables del dpad pasan a tipo
  explícito (`var up: Button = mk.call(...)`, etc.). Tras el
  arreglo, la escena instanciada en headless muestra el HUD
  completo: 1 raíz Control con 7 hijos (arrastre, mira, barra
  superior, táctiles, hotbar, pistas, inventario).
- `voxel_world_generator.gd`: en LETRAS faltaba la «N» (26
  entradas en vez de 27): el bloque 76 rompía `_block_label` al
  abrir el inventario de Letras. Orden restaurado según
  `levels_data.gd` de la 1.15: N en el 13, Ñ en el 14, Z en el 26.
  El test viejo que pedía Ñ en el 63 quedó corregido (N=63,
  Ñ=64, Z=76).
- `settings_scene.gd`: su método se llamaba `_set`, pero Object
  ya tiene un `_set(StringName, Variant) -> bool` virtual y la
  firma distinta era error de compilación: la pantalla de Ajustes
  no cargaba. Renombrado a `_set_setting`, sin cambiar
  comportamiento.
- `project.godot`: 2.0.2 / versionCode 11.
- Tras estas tres correcciones, la importación y las dos
  exportaciones salen con **0 errores de script** (antes había
  errores en los logs que no se revisaron).

## Pruebas headless (Godot 4.3, VM)
- `tests/refactor/test_2_0.gd`: **54/54, salida 0**.
- `tests/refactor/test_refactor.gd`: **27/27, salida 0** (25 viejos
  + N y Z nuevos; se borró antes el `spaced_repetition.json` que
  contamina las recorridas, ver COMO 2.0.1).
- Instancia de `refactor_main.tscn`: HUD con 7 secciones y script
  principal cargado; sin errores de script ni fuera de rango.

## Build y verificación
Misma receta que la 2.0.1, versionCode 11: export sin Gradle →
apktool (TV: touchscreen no requerido, banner, LEANBACK_LAUNCHER;
celular: sin leanback ni banner) → zipalign → firma con el
keystore debug de siempre. Verificado: paquete
`com.miguelitho.bloquesmagicos`, versionCode 11 / versionName
2.0.2 en ambos; TV con leanback + banner; firmante SHA-256
47dfe528dd465b55f58cd07a89ea612294ea5d77b3198b71a8d8cf6c47d22e54
(idéntico a 1.12–2.0.1 → instala encima, conserva progreso);
`classes.dex` y `assets/data/blocks.json` dentro; 0 archivos de
apktool dentro del APK limpio.

## APK finales (Drive, carpeta «Bloques magicos», tamaños/MD5 verificados)
- TV: BloquesMagicos-TV-2.0.2.apk, 50.525.421 bytes,
  MD5 b4fa8f2f571d42c7f5d7569c102ea2fc.
- Celular: BloquesMagicos-Celular-2.0.2.apk, 50.517.157 bytes,
  MD5 6c4ca40dd448c24d44fb2a517e413a0b.

## GitHub
Push a main en la misma línea autorizada por el usuario para la
2.0 (tocó «Sí, súbela a GitHub main»): solo archivos de texto,
sin APKs, sin `export_presets.cfg`, sin los 105 `.ogg` binarios
(el audio va completo en el APK de Drive) y sin tocar
`.github/workflows`.

## Huecos honestos (siguen vigentes)
- No jugado en celular ni stick por mí: la 2.0.2 corrige la causa
  raíz del HUD y la escena construye el HUD en la prueba, pero la
  confirmación en tu teléfono es tuya: joystick abajo a la
  izquierda, botones a la derecha, hotbar abajo al centro y mira
  en el centro.
- Decoración visual sin colisión; torres colocadas sin colisión
  (heredado del refactor).
