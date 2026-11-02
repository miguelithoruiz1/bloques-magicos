# Auditoría de 1.15.0 — lo que se verificó ANTES de refactorizar

Base auditada: `miguelithoruiz1/bloques-magicos`, main, commit `12f92dae`
(«Bloques Mágicos 1.15.0», versionCode 7), clonado el 2026-11-02.
Ningún archivo de esa base se modificó: esta variante es una copia
aparte en `bloques-refactor/` y la base sigue intacta en su repo.

## 1. No existe `PlayerBlocky.gd` en 1.15.0

- No hay ningún `PlayerBlocky.gd`, ni `CharacterBody3D`, ni `SpringArm3D`
  en `scripts/` ni en las escenas. El «jugador» de 1.15.0 es:
  - En mundos (`scripts/main.gd`, 2818 líneas): una `Camera3D` movida a
    mano junto a un `_pivot` (`Node3D`), con el avatar como malla
    suelta. El movimiento es por celdas/rejilla, no por física.
  - En la Plaza (`scripts/hub.gd`, 522 líneas): otra `Camera3D` creada
    en código (`hub.gd:112-116`) que cada frame hace `look_at()` al
    avatar (`hub.gd:344`). Un `look_at()` impone su propio pitch:
    cualquier pitch que se le sume se pierde.
- Consecuencia: la refactorización NO «corrige» un PlayerBlocky: lo
  CREA (`scripts/refactor/player_blocky.gd`, `CharacterBody3D` con
  `HeadAnchor` y `ThirdPersonPivot` (`SpringArm3D`)).

## 2. Botón Atrás: nadie desactiva el cierre automático

- Búsqueda en toda la base: 0 ocurrencias de `set_auto_accept_quit`
  y 0 de `NOTIFICATION_WM_GO_BACK_REQUEST`.
- `scripts/settings.gd:25`: `ui_cancel` → `_volver_plaza()`.
- `scripts/menu.gd:41`: `ui_cancel` retrocede en el menú.
- `scripts/main.gd`: NO gestiona `ui_cancel` en absoluto.
- Conclusión: en un mundo, pulsar Atrás en Android/Google TV puede
  cerrar la app por el comportamiento por defecto de Godot. La
  variante lo corrige en `scripts/refactor/refactor_controller.gd`
  (pila: cerrar panel → Plaza → diálogo modal de salida; `quit()`
  solo desde ese diálogo).

## 3. Ejes adelante/atrás: NO se reprodujo una inversión global

Se rastreó la cadena completa de signos en 1.15.0 y es coherente
consigo misma (convención interna: `y > 0 = adelante`):

- `scripts/touch_controls.gd` (`_update_joy`): el joystick virtual
  hace `move_vector = (offset.x, -offset.y) / radio`. Arriba en
  pantalla (`offset.y` negativo) da `y` positivo = adelante.
- `scripts/input_controller.gd` (`pad_vector`): `Input.get_vector`
  devuelve `y = atrás - adelante`; la función devuelve
  `(raw.x, -raw.y)`, así que `y > 0` = adelante también.
- `scripts/main.gd` (paseo): joystick táctil con `y > 0` → `a_fb = 1`
  (adelante); stick izquierdo del mando con `ay > 0` (hacia abajo)
  → `a_fb = -1` (atrás). Correcto en ambos.
- `scripts/main.gd:356` (construcción): el cursor usa
  `step_direction(Vector2(iv.x, -iv.y))` y luego `_step_cursor`
  multiplica por `-input_vec.y`: dos inversiones que se cancelan.
  El resultado final también es adelante = adelante.

Honestidad: el encargo afirmaba «la inversión actual», pero en el
código 1.15.0 no hay UNA inversión global demostrable en paseo ni
en construcción. Lo que sí puede sentirse invertido o roto es:

- El pitch de la Plaza (punto 4) y el área de cámara diminuta
  (punto 5), que hacen que girar/mirar se sienta mal.
- Cualquier inversión percibida en un dispositivo concreto (mando
  con ejes distintos) no se puede reproducir sin ese mando.

La variante fija UNA convención canónica por escrito
(`player_blocky.gd`, cabecera) y la deja probada en
`tests/refactor/test_refactor.gd`, para que no pueda derivar más:
`y > 0 = adelante`, adelante = `-basis.z` aplanado, y la inversión
de la Y de pantalla ocurre una sola vez, en `ui_controller.gd`.

## 4. Pitch: existe en mundos, NO existe en la Plaza

- Mundos (`scripts/main.gd:1014`): `_cam_pitch` se acumula con el
  arrastre táctil y con el stick derecho (`-rsy`), pero con clamp
  de **±0.5 rad (±28.6°)**, no ±85°.
- Mundos, construcción (`scripts/main.gd:417`): el pitch se suma al
  preset como offset, con clamp asimétrico **-80°..+20°**.
- Mundos, paseo (`scripts/main.gd:387-392`): vista 1ª usa el pitch
  directo; vista 2ª usa `-14° + pitch`.
- Plaza (`scripts/hub.gd:365-367`): el delta de pitch táctil **se
  descarta explícitamente** («La Plaza no tiene pitch») y la cámara
  usa `look_at()`. Además, `hub.gd` no lee `JOY_AXIS_RIGHT_X/Y` en
  ningún punto: **el stick derecho en la Plaza no hace nada**
  (coincide con el hueco reportado en 1.14.0).
- La variante da pitch ±85° en Plaza Y en mundos, por arrastre y
  por stick derecho, en `HeadAnchor` y en `ThirdPersonPivot`.

## 5. Área de cámara del mundo: estrecha por diseño (1.15.0)

`scripts/touch_controls.gd` (`cam_rect`, viewport 1280×720):

- Mundo: x 640..1050, y 210..330 → **410 × 120 px**.
- Plaza: y hasta `height - 200` (más alta, pero sin pitch).

Se encogió así para no tapar la barra superior, la columna de
acciones ni el dock de la paleta (el fallo de 1.14.0, cuando el
área cubría toda la mitad derecha en la capa 5 y tapaba todos los
botones). La variante vuelve al área de pantalla completa y hace
que los botones ganen por orden de hermanos (se añaden después,
con `mouse_filter = STOP`): no hace falta encoger nada.

## 6. HUD de 1.15.0 (lo que la variante sustituye, sin borrarlo)

- `scripts/palette_ui.gd` (1145 líneas): dock de paleta permanente
  con letras/colores/números, barra superior y columna de acciones.
- `scripts/touch_controls.gd`: joystick fijo abajo a la izquierda
  (base 240×240) y área de cámara (punto 5).
- La variante (`scripts/refactor/ui_controller.gd`) usa Hotbar de
  9 slots + inventario modal por pestañas + barra superior
  minimalista. El HUD viejo sigue existiendo en `main.tscn` y
  `touch_controls.tscn` de esta misma carpeta, sin tocar.

## 7. Voces: solo 6 clips reales

- `scripts/audio_bank.gd`: `play_clip()` devuelve `false` si el
  archivo no existe; quien llama usa respaldo. Nunca inventa voces.
- En `bloques-f22/audio/` solo existen 6 `.ogg`: los 6 colores
  originales (rojo, azul, amarillo, verde, naranja, morado).
- `scripts/levels_data.gd` referencia además clips de 27 letras,
  10 palabras mágicas y 6 colores nuevos: esos archivos NO existen.
- La variante copia los 6 reales a `audio/` y su
  `GameModeManager` degrada a texto visible cuando falta un clip.
  La lista completa de faltantes está en README-REFACORIZACION.md.

## 8. Guardados de 1.15.0 (la variante NO los toca)

- `scripts/world_save.gd`: `user://mundo.json`, `mundo_ciudad.json`,
  `mundo_espacio.json` (formato v2).
- `scripts/settings_save.gd`: `user://ajustes.json`.
- `scripts/progress_save.gd`: progreso y estrellas.
- La variante usa archivos PROPIOS: `user://settings_refactor.cfg`,
  `user://worlds/{nombre}_{semilla}.json` y
  `user://spaced_repetition.json`. Borrar la variante no afecta al
  juego actual, y viceversa.
