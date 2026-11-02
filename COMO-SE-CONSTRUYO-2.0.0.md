# Bloques Mágicos 2.0.0 — cómo se construyó

Base: `~/workspace/bloques-refactor/` copiada a `~/workspace/bloques-2.0/`
(sin tocar 1.15 ni refactor). Trabajo en `~/workspace/bloques-2.0-apk/`
(staging, con export_presets.cfg local; nunca pushear ese archivo:
contiene datos del keystore).

## Cambios de juego (detalle en README-2.0.md)
- `data/blocks.json` + `scripts/refactor/block_catalog.gd` (catálogo en datos).
- `scripts/refactor/biomes2.gd` + generador: 4 biomas nuevos; Ajustes
  añade los 4 a la lista; default para instalaciones nuevas: Pradera Verde.
- `scripts/refactor/save_v2.gd`: guardado v2 por regiones 16x16, además del v1.
- `scripts/refactor/friendly_animal.gd` + spawn en `refactor_main.gd`.
- `scripts/refactor/avatar_custom.gd` + `PlayerBlocky.apply_avatar` + selectores en el título.
- `PlayerBlocky`: ala delta (caída frenada a -2.5, alas visibles fuera de 1ª persona).
- `ui_controller.gd`: pestaña «Construcción» [84, 85, 86, 87, 88] + nombres.
- `project.godot`: 2.0.0 / versionCode 9.

## Pruebas headless (Godot 4.3, VM)
- Import primero: `godot --headless --path . --import` (genera
  `.godot/global_script_class_cache.cfg`; sin él, los class_name
  globales no existen y el test se cuelga sin llegar a quit()).
- `tests/refactor/test_2_0.gd`: **50/50, salida 0**.
- `tests/refactor/test_refactor.gd` (viejo): **27/27, salida 0**
  (la línea ERROR de base64 es la prueba de basura rechazada, esperada).
- Aviso test-only: 1 recurso sin liberar al salir del test 2.0
  (instancia VoxelWorld.new() sin free); no afecta al juego.

## Build
1. Export sin Gradle en staging: `--export-debug "Android"` y
   `"Android Celular"` → raw (sin firmar, como siempre).
2. TV: apktool d raw, manifest (touchscreen required=false, banner
   @drawable/tv_banner copiado, LEANBACK_LAUNCHER), apktool.yml
   versionCode 9, apktool b. Celular: apktool d raw, apktool.yml
   versionCode 9, apktool b (sin leanback ni banner).
3. zipalign -f 4 + apksigner sign con el mismo keystore debug de siempre.
4. Verificación: aapt2 badging paquete com.miguelitho.bloquesmagicos,
   versionCode 9 / versionName 2.0.0 en ambos; TV leanback + banner,
   celular sin leanback; classes.dex en ambos; firmante SHA-256
   47dfe528dd465b55f58cd07a89ea612294ea5d77b3198b71a8d8cf6c47d22e54
   (idéntico a 1.12–1.16 → instala encima, conserva progreso);
   `assets/data/blocks.json` dentro de ambos APK finales.

## APK finales (Drive, carpeta «Bloques magicos», tamaños/MD5 verificados)
- TV: BloquesMagicos-TV-2.0.0.apk, 50.525.421 bytes,
  MD5 b475b6b743b0238ceadcfde6b9c5da17.
- Celular: BloquesMagicos-Celular-2.0.0.apk, 50.513.061 bytes,
  MD5 171801e92f7f920ace6607729fe2b479.

## Sin push a GitHub (decisión en la entrega)
La 2.0 se construye sobre el refactor 1.16, que aún no has validado
en celular/stick. No se pusheó a main: el push queda pendiente de
que la pruebes o de que me digas que la suba igual.

## Huecos honestos (no afirmados)
- No jugado en celular ni stick: la prueba headless no sustituye eso.
- Decoración (árboles, palmeras, pinos, setas) visual, no en get_block.
- Sin colisión en torres colocadas (limitación heredada del refactor).
- Sin multijugador, sin combate, sin 37 biomas ni 246 criaturas del
  informe: fuera de alcance y de tono para un niño de 5 años.
