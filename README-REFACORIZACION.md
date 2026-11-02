# Bloques Mágicos — Variante refactorizada (NO es la 1.16)

**Base:** `miguelithoruiz1/bloques-magicos`, main 1.15.0, commit
`12f92dae`. **Esta carpeta NO se pusheó a GitHub y NO es main:**
es una variante de trabajo en `bloques-refactor/`. El juego actual
(1.15.0), sus mundos, su progreso y sus APKs de Drive están
intactos. La versión en `project.godot` se deja en 1.15.0 a
propósito: esta variante no es un lanzamiento.

## Integración completa 2026-11-02 — todas las fases juntas

**Qué cambió en esta integración (solo dentro de esta carpeta):**
- `project.godot`: `run/main_scene` pasó de `res://hub.tscn` a
  `res://scenes/refactor_main.tscn`. Ahora la variante arranca
  directamente en el mundo refactorizado (Fases 1–5 juntas) con
  F5, sin tener que abrir la escena a mano. `hub.tscn` (Plaza
  1.15.0) sigue intacto y accesible desde «Volver a la Plaza».
  No se tocó `version_code` (sigue en 7) ni la etiqueta de
  versión (sigue diciendo 1.15.0): la etiqueta es cosmética y
  esta variante no es un lanzamiento.
- `audio/`: copiados los 105 `.ogg` del banco completo de
  `bloques-f22/audio/` (sin borrar ni sobrescribir los 6 que ya
  estaban; comprobado: eran byte a byte iguales). Total en
  `audio/`: 105 archivos, 2.4 MB.
- Verificación estática hecha en esta integración (sin Godot en
  la VM, ver «Qué falta por validar»): balance de llaves /
  paréntesis / corchetes en todos los `scripts/**/*.gd` sin
  errores; todas las rutas `res://` reales existen (el único
  «fallo» del escaneo era un comentario con comodín,
  `res://audio/color_*.ogg`, y los nombres `color_voz` /
  `letra_voz` / `numero_pedido`, que son tipos de nivel, no
  archivos); los 5 nodos que espera `refactor_main.gd`
  (`VoxelWorld`, `PlayerBlocky`, `TouchAndTVControls`,
  `GameModeManager`, `RefactorController`) existen con esos
  nombres exactos en `scenes/refactor_main.tscn`; todas las
  señales y métodos que `refactor_main.gd` usa de UI, jugador,
  controlador, modos, ajustes, semillas y terreno existen en sus
  scripts; las 27 letras de `GameModeManager.LETTER_CLIP`
  resuelven a archivo real; los clips literales del código 1.15
  copiado (frases, palabras, 12 colores, números) resuelven
  todos. No se encontró ningún enlace roto que corregir: no se
  reescribió lógica que funciona.
- `scripts/refactor/game_mode_manager.gd`: solo se actualizó su
  comentario de cabecera, que decía que solo existían 6 clips;
  la lógica no cambió.

**Cómo entrar a la variante ahora:** abrir el proyecto en el
editor de Godot 4.3 y pulsar F5 (Play): arranca en
`scenes/refactor_main.tscn`. También se puede seguir abriendo
esa escena a mano con F6 («Play Scene»).

## Árbol de nodos (variante)

```
RefactorMain (Node3D, scripts/refactor/refactor_main.gd)
├── VoxelWorld (Node3D, scripts/refactor/voxel_world_generator.gd)
│   ├── MultiMeshInstance3D sólido (BoxMesh, color por instancia)
│   └── MultiMeshInstance3D agua (BoxMesh, transparente)
├── PlayerBlocky (CharacterBody3D, scripts/refactor/player_blocky.gd)
│   ├── CollisionShape3D (caja 0.8 × 1.8 × 0.8, origen en los pies)
│   ├── Visual (MeshInstance3D, cubo azul; oculto en 1ª persona)
│   ├── HeadAnchor (Node3D, altura 1.5)
│   │   └── CameraFP (Camera3D, 1ª persona)
│   └── ThirdPersonPivot (SpringArm3D, largo 3.4 / 2.6 / 9.0)
│       └── CameraTP (Camera3D, 3ª / 2ª / cenital, con look_at)
├── TouchAndTVControls (CanvasLayer 10, scripts/refactor/ui_controller.gd)
│   ├── Área de arrastre de cámara (pantalla completa, primera hija)
│   ├── Crosshair central, barra superior (pausa, cámara, ⭐)
│   ├── Joystick / DPad, botones de acción, Hotbar 9 slots + [...]
│   ├── Sugerencias de mando (solo TV) e Inventario modal (5 pestañas)
├── GameModeManager (Node, scripts/refactor/game_mode_manager.gd)
└── RefactorController (Node, scripts/refactor/refactor_controller.gd)
```

Escenas: `scenes/player_blocky.tscn`, `scenes/voxel_world.tscn`,
`scenes/touch_and_tv_controls.tscn`, `scenes/settings_refactor.tscn`
(`scripts/refactor/settings_scene.gd`), `scenes/refactor_main.tscn`.

## Qué cambió, por fase

### Fase 1 — Input / cámara / Atrás
- `RefactorController`: `set_auto_accept_quit(false)`,
  `NOTIFICATION_WM_GO_BACK_REQUEST` y `ui_cancel` con pila de
  menús (cerrar panel → Plaza → diálogo modal de salida; `quit()`
  solo desde ese diálogo). En 1.15.0 nadie desactivaba el cierre
  automático (ver `AUDITORIA-1.15.0.md`).
- `PlayerBlocky`: convención única — `y > 0 = adelante`,
  adelante = `-basis.z` aplanado; yaw en el cuerpo, pitch en
  `HeadAnchor` y `ThirdPersonPivot`, clamp ±85°, por arrastre
  (mitad derecha o toda la pantalla, el área ya no se encoge) y
  por stick derecho (`JOY_AXIS_RIGHT_X/Y`), en Plaza Y en mundos.
  Corrección honesta: en 1.15.0 no se encontró UNA inversión
  global (la cadena de signos era coherente); lo roto de verdad
  era el pitch descartado en la Plaza, el stick derecho sin
  conectar en la Plaza y el clamp de ±28.6° en mundos. Todo eso
  queda documentado y probado en la auditoría y los tests.
- Suelo por altura de columna: el terreno MultiMesh no tiene
  cuerpos de colisión, así que el jugador se apoya en la altura
  superior de la columna (`ground_top_func`). Subir un escalón de
  1 bloque funciona por ese ajuste. Limitación: atravesar torres
  colocadas por encima del suelo no colisiona (la mira por
  ray-marching sí usa los bloques reales).

### Fase 2 — HUD Minecraft
- `UIController` (`TouchAndTVControls`, CanvasLayer 10):
  auto-switch por evento real (mando → oculta joystick/botones,
  deja hotbar + crosshair + `[A] Saltar · [RT] Poner ·
  [Y] Inventario`; toque → HUD táctil). Joystick semitransparente
  con visibilidad configurable (siempre / oculto / cuando se usa)
  y sprint al 100% sostenido 0.3 s. Derecha: Saltar, Agacharse
  (mantener), perspectiva (1ª/2ª/3ª/cenital), Poner, Quitar.
  Hotbar de 9 slots + `[...]` (a la izquierda si «zurdo») que
  abre el inventario modal por pestañas (Colores, Números y
  Operadores, Letras y Fonética, Naturaleza y Decoración, Lógica
  Viva); al elegir, equipa en la hotbar y cierra el modal. Barra
  superior minimalista (pausa, cámara, ⭐). Desaparecen del HUD
  nuevo el cuadro amarillo gigante, la cruceta azul flotante y el
  teclado gigante permanente — el HUD viejo sigue intacto en
  `main.tscn` / `touch_controls.tscn`.

### Fase 3 — Ajustes estilo Minecraft
- `SettingsScene`: navegación lateral (Teclado y ratón, Mando,
  Táctil, Audio y Voces, Mundo y Semilla) + panel derecho con
  `ScrollContainer`. Incluye todo lo pedido: 3 modos de control,
  visibilidad del joystick, invertir Y, salto automático, correr
  sencillo, inventario zurdo, botón de perspectiva, retraso de
  ruptura, sliders de sensibilidad de cámara 0–100 (default 50,
  factor interno = sensibilidad / 50) y tamaño de botón; mando con
  sensibilidad de cámara/cursor, invertir Y, ocultar sugerencias y
  cursor, intercambiar A/B y X/Y, tabla de reasignación y
  restablecer. Se guarda en `user://settings_refactor.cfg`
  (NO toca `ajustes.json` de 1.15.0).

### Fase 4 — Mundo con relieve y semillas
- `VoxelWorldGenerator` + `WorldSeedManager`: `FastNoiseLite`
  (Simplex + Perlin de detalle) con colinas, valles, montañas
  (Ciber-Núcleo), árboles voxel, flores y agua; biomas Croma-Isla,
  Forja de los Números, Valle del Eco y Ciber-Núcleo. Render con
  2 MultiMesh (sólido + agua) y bloques de aprendizaje como
  mallas individuales con `Label3D`. Semilla: texto o número
  (`.hash()` para `noise.seed`; vacío = 0; «aleatoria» genera un
  número). Guardado en `user://worlds/{nombre}_{semilla}.json`
  con semilla + `modified_blocks` (`{"x,y,z": id}`; quitar = 0).
  Export/import Base64 (semilla + bloques) al portapapeles, con
  respaldo en `user://worlds/export.txt` (en TV el portapapeles
  puede no existir). IDs: 0 aire, 1 hierba, 2 tierra, 3 piedra,
  4 madera, 5 hojas, 6 agua, 7 arena, 8/9 flores, 10–21 colores,
  30–39 números (30 + dígito), 40–43 operadores (+ − × =),
  50–76 letras (mismo orden que 1.15.0: Ñ = 13), 80 antorcha,
  81 cofre, 82 portal. Radio de terreno configurable (default 24).

### Fase 5 — Modos Creativo y Supervivencia
- `GameModeManager` + `SpacedRepetitionManager`: Creativo con
  bloques infinitos, vuelo y sin daño ni energía; al formar
  SOL / CASA / ARBOL con letras suenan las letras (si su clip
  existe), suena un acorde mayor generado, salen partículas y
  aparece un modelo procedural (sol, casa, árbol). Con
  `[3] [+] [2] [=]` se genera una torre de 5 bloques brillantes
  con voz o texto. Supervivencia con gravedad, Energía Cognitiva,
  inventario limitado y recolección; retos en el entorno
  (fisura `4 + 3`, puente `P-U-E-N-T-E`); la repetición espaciada
  prioriza lo que falló (prioridad = fallos × 3 − aciertos +
  fallo reciente); ciclo día/noche con retos bioluminiscentes y
  Mascota Feynman en 2ª persona que pide ayuda para recargar
  antorchas y energía. **Sin pantallas de castigo**: un error da
  pista visual y auditiva y deja seguir jugando.

## Voces: lo que existe y lo que falta (sin inventar nada)

**Desde la integración 2026-11-02 el banco está completo.**
En `audio/` hay 105 `.ogg`:
- Los 69 de la lista original, completos: 12 colores en español
  (6 originales + rosado, café, negro, blanco, gris, celeste),
  10 frases (`frase_hola`, `frase_elige_modo`,
  `frase_elige_mundo`, `frase_elige_nivel`, `frase_muy_bien`,
  `frase_mundo_completo`, `frase_a_construir`,
  `frase_pon_bloque`, `frase_intentalo`,
  `frase_que_divertido`), 10 palabras mágicas (`palabra_mama`,
  `palabra_papa`, `palabra_gato`, `palabra_perro`, `palabra_sol`,
  `palabra_luna`, `palabra_casa`, `palabra_flor`, `palabra_pez`,
  `palabra_oso`), 27 letras (`letra_a`…`letra_z`, `letra_nn`
  para Ñ) y números del 1 al 10 (`numero_1`…`numero_10`).
- 36 extra: 10 colores en inglés (`color_black`,
  `color_blue`, `color_green`, `color_gray`, `color_pink`,
  `color_purple`, `color_white`, `color_yellow`,
  `color_orange`, `color_red`), 6 acciones como palabras
  habladas (`accion_bajar`, `accion_colocar`, `accion_derecha`,
  `accion_izquierda`, `accion_subir`, `accion_romper` — los
  efectos de sonido se añaden después, según el usuario) y
  números del 11 al 30 (`numero_11`…`numero_30`).

Cómo resuelven: `scripts/audio_bank.gd` reproduce cualquier
nombre como `res://audio/<nombre>.ogg` y devuelve `false` si
falta, así que nada falla por un clip ausente. En el mundo
refactorizado, `GameModeManager` habla las letras al invocar
palabras (SOL / CASA / ARBOL / PUENTE); el código 1.15 copiado
(Plaza y niveles, vía `hub.tscn`) ya pedía frases, palabras,
colores y números por esos nombres exactos, así que ahora
resuelven todos. **Hueco honesto:** los extra en inglés, las
acciones y los números 11–30 están en el banco pero ningún
script de la variante los llama todavía; sonarán solo cuando
un código los pida por `audio_bank.play_clip()`. No se inventó
ninguna voz ni efecto.

## Cómo probar

### En el editor (única vía probada en esta entrega: sin ejecución)
1. Abrir esta carpeta como proyecto en Godot 4.3.
2. Pulsar F5 (Play): arranca en `scenes/refactor_main.tscn`.
   También vale abrir esa escena y pulsar F6 (Play Scene).
3. En el título: elegir modo, nombre y semilla (p. ej.
   `MUNDO-PAPA-HIJO-777`), pulsar Jugar.
4. Probar, en orden (lo primero que debe probar el usuario):
   a) que el juego arranca en la variante y no en la Plaza;
   b) joystick arriba = adelante; arrastrar arriba = mirar
   arriba (pitch libre, no el clamp viejo de ±28.6°);
   c) `[...]` → inventario → elegir → equipa y cierra;
   d) formar `S-O-L` con letras: deben sonar las letras (ya
   no degradar a texto) y aparecer el sol procedural;
   e) `[3][+][2][=]` → torre de 5; f) pausa → Guardar →
   Exportar → Importar en otro arranque; g) Atrás con el
   inventario abierto (debe cerrarlo, no salir); Atrás en el
   título (debe pedir confirmación); h) Ajustes: cambiar
   sensibilidad y volver al mundo.
5. Tests de lógica (requieren Godot):
   `godot --headless --path . -s tests/refactor/test_refactor.gd`
   (sale 0 si todo pasa). Ojo: el test de repetición espaciada
   escribe en `user://spaced_repetition.json` del entorno de
   prueba, como haría el juego.

### En celular y en stick TV (PENDIENTE del usuario, no probado)
- Esta entrega NO incluye APK ni `export_presets.cfg` a propósito:
  el `export_presets.cfg` de 1.15.0 contiene datos del keystore y
  nunca se copia. Para probar en el teléfono o el stick, exportar
  desde el editor de Godot en el PC del usuario (Android) con sus
  propios presets y su keystore, e instalar encima solo si el
  certificado coincide con el de 1.15.0; si no, instalar como app
  aparte para no tocar el progreso actual.
- En TV: conectar el mando antes de entrar al mundo y comprobar
  que el HUD táctil se oculta, que aparecen las sugerencias y que
  el stick derecho gira y mira arriba/abajo. En la Plaza vieja el
  stick derecho seguirá sin hacer nada: eso es 1.15.0, no esta
  variante.

## Qué falta por validar (lista explícita, no se afirma nada)

- [ ] Ejecución real en Godot: **no hay Godot en esta VM** (se
  buscó en `/usr/local/bin` y `/opt`, sin resultado). La
  verificación hecha aquí es estática: balance de llaves,
  paréntesis y corchetes, rutas `preload`/`load`/`change_scene`
  y escenas `.tscn` existentes, sin errores; en la integración
  2026-11-02 se re-verificó todo eso más nodos, señales,
  métodos y los 105 clips del banco. Los tests headless NO se
  ejecutaron y no se promete ejecución ni 60 FPS.
- [ ] Rendimiento: no se promete 60 FPS. Bajar `render_radius`
  (Ajustes → Mundo y Semilla) si un móvil o el stick van lentos.
- [ ] Colisión con torres colocadas (ver Fase 1, limitación).
- [ ] Navegación por foco en TV en la escena de Ajustes: los
  botones son enfocables, pero no se definieron vecinos de foco
  explícitos como en los ajustes de 1.15.0; hay que probarlo con
  el mando en el stick.
- [ ] Partículas de invocación: son `one_shot` pero el nodo queda
  en el árbol tras dispararse (sin limpieza por temporizador).
- [ ] Modelos 3D invocados son procedurales, no el arte final.
- [ ] El `look_at()` de tercera persona usa la cabeza como punto
  de mira; en pendientes fuertes puede sentirse distinto a
  Minecraft: probar en el stick antes de darlo por bueno.
- [ ] La prueba de guardado/carga entre celular y TV con el código
  Base64 (export/import) está implementada pero no probada en
  dispositivos reales.

## Archivos nuevos de la variante

- `scripts/refactor/player_blocky.gd` — jugador (Fase 1).
- `scripts/refactor/refactor_controller.gd` — Atrás seguro (Fase 1).
- `scripts/refactor/ui_controller.gd` — HUD Minecraft (Fase 2).
- `scripts/refactor/settings_refactor.gd` — persistencia de ajustes (Fase 3).
- `scripts/refactor/settings_scene.gd` — escena de Ajustes (Fase 3).
- `scripts/refactor/voxel_world_generator.gd` — terreno (Fase 4).
- `scripts/refactor/world_seed_manager.gd` — semillas/guardado (Fase 4).
- `scripts/refactor/game_mode_manager.gd` — modos (Fase 5).
- `scripts/refactor/spaced_repetition_manager.gd` — repetición (Fase 5).
- `scripts/refactor/refactor_main.gd` — cableado de la escena (Fase 6).
- `scenes/*.tscn` — las 5 escenas de la variante (Fase 6).
- `tests/refactor/test_refactor.gd` — tests headless de lógica pura.
- `AUDITORIA-1.15.0.md` — auditoría previa con archivo:línea.
- Todo lo demás de la carpeta es la copia intacta de 1.15.0
  (sin `export_presets.cfg`, sin APKs), para que la variante
  arranque y la Plaza siga accesible.
