extends Node3D
## Bloques Mágicos — Fase 4 (1.10.0).
## Constructor de bloques 3D tipo Minecraft, simplificado y seguro para un
## niño de 5 años: mundo INFINITO por chunks, cursor con bloque fantasma,
## cubos de colores y de números, voz en español (TTS del sistema),
## sonidos generados en código y guardado automático. Sin red, sin
## anuncios, sin cuentas.
##
## 1.10.0: (A) menú radial en el paseo que recoge los botones;
## (B) los 5 mundos (libre + 4 de niveles) tienen identidad visual
## propia y el terreno se genera por chunks al caminar más allá del
## borde, sin muro; (C) colocar (y quitar) bloques desde 1ª/2ª persona
## apuntando con la cámara. La mascota no se toca.
##
## La escena main.tscn es mínima: casi todo se construye aquí por código
## para mantener el proyecto robusto como archivos de texto.
## Decisiones técnicas (detalle en el README):
## - Una sola BoxMesh compartida y un material por color (rendimiento).
## - La selección táctil NO usa física: intersección rayo–caja calculada
##   a mano contra el diccionario de bloques (rápido y sin colisiones).
## - Los números de los cubos se dibujan con Label3D en las 5 caras visibles.

const PaletteUI := preload("res://scripts/palette_ui.gd")
const AudioBank := preload("res://scripts/audio_bank.gd")
const WorldSave := preload("res://scripts/world_save.gd")
const LevelsData := preload("res://scripts/levels_data.gd")
const LevelLogic := preload("res://scripts/level_logic.gd")
const LevelHints := preload("res://scripts/level_hints.gd")
const ProgressSave := preload("res://scripts/progress_save.gd")

## 1.10.0: el mundo ya no tiene borde fijo. El terreno se genera por
## chunks de 16×16 alrededor del cursor y del avatar (radio 2 chunks =
## 80×80 a la vista, como el antiguo delantal). Los bloques colocados
## siguen con tope MAX_BLOCKS (protege la memoria del stick).
const CHUNK := 16
const CHUNK_RADIUS := 2
const MAX_CHUNKS := 256
const MAX_HEIGHT := 8
const MAX_BLOCKS := 800
const SAVE_DELAY := 0.6
const OK_HOLD_SECONDS := 0.35

const BLOCK_COLORS: Array = [
	{"nombre": "Rojo", "color": Color(0.90, 0.25, 0.22)},
	{"nombre": "Azul", "color": Color(0.20, 0.45, 0.95)},
	{"nombre": "Amarillo", "color": Color(0.98, 0.80, 0.15)},
	{"nombre": "Verde", "color": Color(0.30, 0.75, 0.35)},
	{"nombre": "Naranja", "color": Color(0.98, 0.55, 0.15)},
	{"nombre": "Morado", "color": Color(0.60, 0.35, 0.90)},
]
const NUMBER_NAMES: Array = ["Uno", "Dos", "Tres", "Cuatro", "Cinco"]
const NUMBER_CUBE_COLOR := Color(1.0, 0.95, 0.78)
const NUMBER_TEXT_COLOR := Color(0.10, 0.16, 0.45)
## Cubos con letras (Fase 2, Mundo Letras). Los textos vienen de
## LevelsData.LETRAS para no duplicar la lista.
const LETTER_CUBE_COLOR := Color(0.62, 0.85, 1.0)
## Contenido nuevo 1.3, solo mundo libre (lo pide el niño): agua, árbol,
## flor y piezas de casa (pared, techo, puerta). El agua es un cubo
## translúcido SÓLIDO como los demás (ocupa su celda, cuenta y se
## guarda): una capa de agua no sólida habría complicado guardado,
## borrado y fantasma sin beneficio para un niño de 5 años.
const WATER_COLOR := Color(0.25, 0.62, 1.00)
const WALL_COLOR := Color(0.95, 0.92, 0.82)
const ROOF_COLOR := Color(0.85, 0.25, 0.22)
const DOOR_COLOR := Color(0.55, 0.38, 0.22)
const TRUNK_COLOR := Color(0.45, 0.32, 0.20)
const LEAF_COLOR := Color(0.25, 0.60, 0.30)
const FLOWER_HEAD_COLOR := Color(1.00, 0.55, 0.75)
const LIBRE_NAMES := {"agua": "Agua", "arbol": "Árbol", "flor": "Flor", "pared": "Pared", "techo": "Techo", "puerta": "Puerta"}
## 1.10.0: identidad visual por mundo. Cada mundo tiene su suelo
## (damero claro/oscuro/línea), su cielo y su decoración (flores o
## piedras deterministas por chunk). "libre" es la pradera de siempre.
const WORLD_THEMES := {
	"libre": {"suelo_claro": Color(0.56, 0.80, 0.47), "suelo_oscuro": Color(0.49, 0.74, 0.42), "suelo_linea": Color(0.40, 0.64, 0.36), "cielo_arriba": Color(0.30, 0.58, 0.95), "cielo_horizonte": Color(0.72, 0.87, 1.00), "decor": [Color(1.00, 0.55, 0.75), Color(1.00, 0.85, 0.30), Color(1.00, 1.00, 1.00)]},
	"colores": {"suelo_claro": Color(0.62, 0.85, 0.55), "suelo_oscuro": Color(0.55, 0.78, 0.48), "suelo_linea": Color(0.45, 0.68, 0.40), "cielo_arriba": Color(0.35, 0.55, 0.95), "cielo_horizonte": Color(0.95, 0.80, 0.95), "decor": [Color(1.00, 0.25, 0.22), Color(0.98, 0.55, 0.15), Color(0.98, 0.80, 0.15), Color(0.30, 0.75, 0.35), Color(0.20, 0.45, 0.95), Color(0.60, 0.35, 0.90)]},
	"numeros": {"suelo_claro": Color(0.93, 0.85, 0.62), "suelo_oscuro": Color(0.87, 0.78, 0.52), "suelo_linea": Color(0.78, 0.68, 0.42), "cielo_arriba": Color(0.30, 0.58, 0.95), "cielo_horizonte": Color(0.85, 0.90, 1.00), "decor": [Color(0.65, 0.65, 0.65), Color(0.55, 0.55, 0.55), Color(0.75, 0.72, 0.60)]},
	"letras": {"suelo_claro": Color(0.75, 0.87, 0.98), "suelo_oscuro": Color(0.68, 0.80, 0.95), "suelo_linea": Color(0.58, 0.70, 0.88), "cielo_arriba": Color(0.45, 0.70, 1.00), "cielo_horizonte": Color(0.90, 0.95, 1.00), "decor": [Color(1.00, 1.00, 1.00), Color(0.95, 0.97, 1.00), Color(0.85, 0.92, 1.00)]},
	"sumas": {"suelo_claro": Color(0.35, 0.60, 0.35), "suelo_oscuro": Color(0.30, 0.54, 0.30), "suelo_linea": Color(0.24, 0.46, 0.24), "cielo_arriba": Color(0.30, 0.55, 0.85), "cielo_horizonte": Color(0.80, 0.88, 0.75), "decor": [Color(1.00, 0.85, 0.30), Color(1.00, 0.95, 0.60), Color(1.00, 0.55, 0.75)]},
}

var blocks: Dictionary = {} ## Vector3i -> {"tipo": String, "dato": int}
var block_nodes: Dictionary = {} ## Vector3i -> Node3D
var cursor := Vector3i(10, 0, 10)
var selection: Dictionary = {"modo": "color", "dato": 0}

var _blocks_root: Node3D
var _box_mesh: BoxMesh
var _materials: Dictionary = {}
var _number_material: StandardMaterial3D
var _letter_material: StandardMaterial3D
var _water_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _roof_material: StandardMaterial3D
var _door_material: StandardMaterial3D
var _trunk_material: StandardMaterial3D
var _leaf_material: StandardMaterial3D
var _flower_material: StandardMaterial3D

## Estado de la Fase 2 (modo nivel). En juego libre no se usa.
var _level_mode := false
var _level_def: Dictionary = {}
var _level_target := -1
var _level_placed: Array = []
var _level_completed := false
var _level_progress: Dictionary = {}
## 1.6: pistas visuales del nivel (solo muestran, nunca cuentan).
## Viven en _hint_root, fuera de blocks/block_nodes: no se guardan,
## no cuentan para la meta y no bloquean el paseo.
var _hint_root = null
var _hint_timer := 0.0
## 1.10.0: chunks del mundo infinito + tema activo + menú radial.
var _chunks: Dictionary = {} ## Vector2i(chunk) -> Node3D
var _theme: Dictionary = {}
var _sky_mat = null
var _chunk_material: StandardMaterial3D
var _chunk_mesh: PlaneMesh
var _decor_mesh: SphereMesh
var _decor_materials: Dictionary = {}
var _radial_open := false

var _pivot: Node3D
var _camera: Camera3D
var _yaw_target := 0.0

## 1.5 (F3): presets de cámara para la VISTA DE CONSTRUCCIÓN (distintos
## del modo caminar 1ª/2ª persona, que queda intacto). 0 = Arriba (la de
## siempre, por defecto). Se ciclan con el extra «Cámara» de la paleta
## TV; el giro yaw y el seguimiento del cursor no cambian.
var _cam_preset := 0
var _cam_presets: Array = [
	{"nombre": "Arriba", "offset": Vector3(0.0, 10.5, 10.5), "rot_x": -45.0, "voz": "Cámara arriba"},
	{"nombre": "Cerca", "offset": Vector3(0.0, 6.0, 6.0), "rot_x": -45.0, "voz": "Cámara cerca"},
	{"nombre": "Lado", "offset": Vector3(0.0, 3.5, 13.0), "rot_x": -14.0, "voz": "Cámara de lado"},
	{"nombre": "Lejos", "offset": Vector3(0.0, 16.0, 16.0), "rot_x": -45.0, "voz": "Cámara lejos"},
]

## 1.4: modo caminar (avatar). Primera persona obligatoria; segunda
## persona (Blocky detrás) se cambia con OK largo dentro del modo.
var _walk_mode := false
var _walk_cell := Vector2i(10, 10)
var _walk_yaw := 0.0
var _walk_view := 0 # 0 = primera persona, 1 = segunda (Blocky)
var _walk_move_timer := 0.0
var _walk_avatar = null
var _pet_node = null
var _pet_body = null
var _pet_tail = null
var _pet_cell := Vector2i(10, 10)
var _pet_timer := 0.0

var _ghost_root: Node3D
var _ghost_material: StandardMaterial3D
var _ghost_eye_material: StandardMaterial3D
var _ghost_label: Label3D
var _ghost_state := ""

# Fase 1: cuerpos del cielo (sol/luna por palabra). Se crean en
# _build_environment y empiezan ocultos.
var _sun_body = null
var _moon_body = null

var _palette = null
var _move_timer := 0.0
var _palette_mode := false
var _pal_move_timer := 0.0
var _ok_prev_down := false
var _ok_hold_time := 0.0
var _ok_long_fired := false
var _dirty := false
var _save_delay := 0.0

var _audio_players: Array[AudioStreamPlayer] = []
var _audio_next := 0
var _pop_stream: AudioStream
var _toc_stream: AudioStream
var _win_stream: AudioStream

var _tts_voice := ""
var _audio_bank = null

var _mouse_down := false
var _mouse_start := Vector2.ZERO
var _mouse_dragged := false


func _ready() -> void:
	_build_shared()
	_build_environment()
	_apply_theme("libre" if GameState.modo != "nivel" else GameState.mundo)
	_build_ground()
	_build_trees()
	_build_camera()
	_build_ghost()
	_build_audio()
	_audio_bank = AudioBank.new()
	add_child(_audio_bank)
	_init_tts()
	_palette = PaletteUI.new()
	add_child(_palette)
	_palette.selection_changed.connect(_on_selection_changed)
	_palette.place_requested.connect(place_at_cursor)
	_palette.remove_requested.connect(remove_at_cursor)
	_palette.up_requested.connect(func() -> void: set_cursor_height(1))
	_palette.down_requested.connect(func() -> void: set_cursor_height(-1))
	_palette.world_reset.connect(_on_world_reset)
	_palette.menu_requested.connect(_go_to_menu)
	# 1.3: giro de cámara por pasos con el mando (desde la paleta TV).
	_palette.rotate_step_requested.connect(_on_rotate_step)
	# 1.4: entrar al modo caminar (desde la paleta TV).
	_palette.walk_requested.connect(_enter_walk_mode)
	# 1.10.0: el menú radial del paseo (Poner / Quitar / Vista / Salir).
	# Las antiguas señales walk_exit/walk_view de 1.8.0 ya no existen:
	# Vista y Salir viven dentro del radial.
	_palette.radial_open_requested.connect(_open_radial)
	_palette.radial_place_requested.connect(_walk_place)
	_palette.radial_remove_requested.connect(_walk_remove)
	_palette.radial_view_requested.connect(_on_radial_view)
	_palette.radial_exit_requested.connect(_exit_walk_mode)
	# 1.5 (F3): ciclar la cámara de construcción (desde la paleta TV).
	_palette.camera_cycle_requested.connect(_on_camera_cycle)
	# Fase 2: en modo nivel se empieza con un tablero vacío (la meta se
	# mide solo con lo colocado en el nivel) y el mundo libre NO se toca:
	# ni se carga ni se guarda. En juego libre todo sigue igual que F1.
	_level_mode = GameState.modo == "nivel"
	if _level_mode:
		_start_level()
	else:
		_load_world()
	# 1.4: avatar Blocky y mascota (después de cargar el mundo, para
	# que la mascota nazca en una celda libre).
	_build_walk_actors()
	_update_info()
	_update_ghost(true)


func _process(delta: float) -> void:
	# Pulsación OK con duración: corta = colocar (o confirmar dentro de
	# la paleta TV); larga (OK_HOLD_SECONDS) = abrir la paleta en el TV.
	var ok_event := _poll_ok(delta)

	if _level_completed:
		# Nivel superado: el mundo queda en pausa y OK vuelve al menú.
		if ok_event == "short":
			_go_to_menu()
	elif _walk_mode:
		# 1.4: en modo caminar el mando mueve al avatar (ver
		# _handle_walk_mode); el mundo de construcción queda en pausa.
		_handle_walk_mode(delta, ok_event)
	elif _palette_mode:
		# Con la paleta TV abierta, el input del mundo queda en pausa.
		_handle_palette_mode(delta, ok_event)
	else:
		# Rotación de la cámara (mando y botones táctiles).
		var rot := 0.0
		if Input.is_action_pressed("camera_left"):
			rot += 1.0
		if Input.is_action_pressed("camera_right"):
			rot -= 1.0
		if _palette != null:
			rot += float(_palette.get("touch_rotate"))
		if rot != 0.0:
			_yaw_target += rot * deg_to_rad(100.0) * delta

		# Movimiento del cursor por la cuadrícula (con repetición al mantener).
		var iv := Vector2i.ZERO
		if Input.is_action_pressed("move_right"):
			iv.x += 1
		if Input.is_action_pressed("move_left"):
			iv.x -= 1
		if Input.is_action_pressed("move_back"):
			iv.y += 1
		if Input.is_action_pressed("move_forward"):
			iv.y -= 1
		if iv != Vector2i.ZERO:
			_move_timer -= delta
			if _move_timer <= 0.0:
				_step_cursor(iv)
				_move_timer = 0.16
		else:
			_move_timer = 0.0

		# Acciones puntuales.
		if ok_event == "long":
			_open_palette_mode()
		elif ok_event == "short":
			place_at_cursor()
		if Input.is_action_just_pressed("remove_block"):
			remove_at_cursor()
		if Input.is_action_just_pressed("cursor_up_level"):
			set_cursor_height(1)
		if Input.is_action_just_pressed("cursor_down_level"):
			set_cursor_height(-1)

	if _walk_mode:
		# 1.4: la cámara va con el avatar. Primera persona: a la altura
		# de los ojos (1.5 bloques) en la celda del avatar. Segunda:
		# detrás y arriba de Blocky. El pivot sigue al avatar y la
		# mascota lo sigue a él (ver _update_pet).
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, _walk_yaw, minf(1.0, delta * 10.0))
		var wtarget := Vector3(float(_walk_cell.x) + 0.5, 0.0, float(_walk_cell.y) + 0.5)
		_pivot.position = _pivot.position.lerp(wtarget, minf(1.0, delta * 8.0))
		var cam_pos := Vector3(0.0, 1.5, 0.0)
		var cam_rot_x := 0.0
		if _walk_view == 1:
			cam_pos = Vector3(0.0, 2.1, 3.4)
			cam_rot_x = deg_to_rad(-14.0)
		_camera.position = _camera.position.lerp(cam_pos, minf(1.0, delta * 8.0))
		_camera.rotation.x = lerpf(_camera.rotation.x, cam_rot_x, minf(1.0, delta * 8.0))
		_camera.rotation.y = lerpf(_camera.rotation.y, 0.0, minf(1.0, delta * 8.0))
		_camera.rotation.z = lerpf(_camera.rotation.z, 0.0, minf(1.0, delta * 8.0))
		_update_walk_avatar()
		_update_pet(delta)
	else:
		# 1.3: el suavizado de rotación corre SIEMPRE (antes solo con el
		# mundo activo), para que el giro por pasos con el mando se vea
		# también con la paleta TV abierta (si no, el niño gira a ciegas
		# hasta cerrarla).
		_pivot.rotation.y = lerp_angle(_pivot.rotation.y, _yaw_target, minf(1.0, delta * 10.0))

		# 1.5 (F3): la cámara de construcción sigue el preset activo
		# (Arriba = la de siempre; el resto se elige con «Cámara»).
		# Corre también con la paleta abierta, para que el niño vea
		# cada vista mientras cicla. El modo caminar tiene su propia
		# rama arriba y no se ve afectado.
		var cp: Dictionary = _cam_presets[_cam_preset]
		_camera.position = _camera.position.lerp(Vector3(cp["offset"]), minf(1.0, delta * 8.0))
		_camera.rotation.x = lerpf(_camera.rotation.x, deg_to_rad(float(cp["rot_x"])), minf(1.0, delta * 8.0))
		_camera.rotation.y = lerpf(_camera.rotation.y, 0.0, minf(1.0, delta * 8.0))
		_camera.rotation.z = lerpf(_camera.rotation.z, 0.0, minf(1.0, delta * 8.0))

		# La cámara sigue al cursor con suavidad.
		var target := Vector3(
			float(cursor.x) + 0.5,
			0.6 + float(cursor.y) * 0.35,
			float(cursor.z) + 0.5
		)
		_pivot.position = _pivot.position.lerp(target, minf(1.0, delta * 5.0))

	if _walk_mode:
		_update_walk_ghost()
	else:
		_update_ghost()

	# 1.6: las pistas parpadean juntas (0.6 s) para llamar la vista
	# sin tapar el tablero; al completar el nivel ya se limpiaron.
	if _level_mode and not _level_completed and _hint_root != null and _hint_root.get_child_count() > 0:
		_hint_timer += delta
		if _hint_timer >= 0.6:
			_hint_timer = 0.0
			_hint_root.visible = not _hint_root.visible

	# Autoguardado con pequeña espera para agrupar cambios seguidos.
	if _dirty:
		_save_delay -= delta
		if _save_delay <= 0.0:
			_save_now()


## Sigue la pulsación de «place_block» (OK del control de TV, botón A del
## mando, Espacio/Enter en teclado) distinguiendo corta de larga.
## Devuelve "long" una sola vez al cumplir OK_HOLD_SECONDS con el botón
## aún presionado, "short" al soltar una pulsación corta, y "" si nada.
## Así, mantener OK para abrir la paleta NUNCA coloca un bloque al soltar.
func _poll_ok(delta: float) -> String:
	var ev := ""
	var down := Input.is_action_pressed("place_block")
	if down and not _ok_prev_down:
		_ok_hold_time = 0.0
		_ok_long_fired = false
	elif down:
		_ok_hold_time += delta
		if _ok_hold_time >= OK_HOLD_SECONDS and not _ok_long_fired:
			_ok_long_fired = true
			ev = "long"
	if not down and _ok_prev_down and not _ok_long_fired:
		ev = "short"
	_ok_prev_down = down
	return ev


func _open_palette_mode() -> void:
	_palette_mode = true
	_pal_move_timer = 0.0
	_move_timer = 0.0
	_palette.open_tv_palette()


## Input mientras la paleta TV está abierta: ◀ ▶ mueven el resaltado
## entre las opciones, ▲ ▼ suben/bajan la altura del cursor,
## OK corto confirma y cierra, Atrás cierra sin cambiar nada.
func _handle_palette_mode(delta: float, ok_event: String) -> void:
	if ok_event == "short":
		# confirm_tv_palette() devuelve false solo cuando armó la doble
		# confirmación de «Empezar de nuevo»: la paleta sigue abierta.
		if _palette.confirm_tv_palette():
			_palette_mode = false
		return
	if Input.is_action_just_pressed("remove_block"):
		_palette.cancel_tv_palette()
		_palette_mode = false
		return
	var iv := Vector2i.ZERO
	if Input.is_action_pressed("move_right"):
		iv.x += 1
	if Input.is_action_pressed("move_left"):
		iv.x -= 1
	if Input.is_action_pressed("move_back"):
		iv.y += 1
	if Input.is_action_pressed("move_forward"):
		iv.y -= 1
	if iv != Vector2i.ZERO:
		_pal_move_timer -= delta
		if _pal_move_timer <= 0.0:
			if iv.x != 0:
				_palette.move_tv_highlight(iv.x)
			elif iv.y != 0:
				set_cursor_height(-iv.y)
			_pal_move_timer = 0.16
	else:
		_pal_move_timer = 0.0


func _unhandled_input(event: InputEvent) -> void:
	# Nivel superado: el mundo no recibe más input, solo OK → menú.
	if _level_completed:
		return
	# 1.4: en modo caminar, Atrás sale del modo (no va al menú) y el
	# resto del input del mundo queda en pausa.
	if _walk_mode:
		if event is InputEventKey:
			var kw := event as InputEventKey
			if kw.keycode == KEY_ESCAPE and kw.pressed and not kw.echo:
				if _radial_open:
					_close_radial()
				else:
					_exit_walk_mode()
		return
	# Botón Atrás del control de TV (tecla Escape en Android): vuelve al
	# menú. Se distingue a propósito del botón B del mando (que borra),
	# que llega como evento de mando y no como tecla.
	if event is InputEventKey:
		var k0 := event as InputEventKey
		if k0.keycode == KEY_ESCAPE and k0.pressed and not k0.echo:
			_go_to_menu()
			return
	# Con la paleta TV abierta, el mundo no recibe clics/toques ni teclas.
	if _palette_mode:
		return
	# El tacto llega como ratón emulado (emulate_mouse_from_touch=true en
	# project.godot): UN solo camino de entrada para ratón real (PC) y
	# dedo (Android), sin procesar ningún toque dos veces.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_mouse_down = true
				_mouse_start = mb.position
				_mouse_dragged = false
			else:
				if _mouse_down and not _mouse_dragged:
					_handle_tap(mb.position)
				_mouse_down = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _mouse_down:
			if (mm.position - _mouse_start).length() > 24.0:
				_mouse_dragged = true
			if _mouse_dragged:
				_yaw_target -= mm.relative.x * 0.01
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode >= KEY_1 and k.keycode <= KEY_6:
			if _palette != null:
				_palette.select_color(int(k.keycode - KEY_1))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _dirty:
			_save_now()


# ---------------------------------------------------------------------------
# Construcción (acciones principales)
# ---------------------------------------------------------------------------

func place_at_cursor() -> void:
	# 1.4: en modo caminar no se coloca con el cursor (OK sale del
	# modo); colocar en paseo va por _walk_place, con punto de mira.
	if _walk_mode:
		return
	_place_at(cursor)


## Coloca el bloque elegido en `cell`. Lo usan el cursor de
## construcción y el punto de mira del paseo (1.10.0): mismas reglas
## (tope, ocupado, meta del nivel) en ambos modos.
func _place_at(cell: Vector3i) -> void:
	if String(selection.get("modo", "color")) == "borrador":
		_remove_at(cell)
		return
	if blocks.size() >= MAX_BLOCKS:
		_palette.show_message("¡Ya hay muchísimos bloques! Quita algunos para seguir construyendo.")
		return
	if blocks.has(cell):
		_palette.show_message("Ahí ya hay un bloque.")
		return
	var data := {"tipo": "color", "dato": int(selection.get("dato", 0))}
	if String(selection.get("modo", "color")) == "numero":
		data = {"tipo": "numero", "dato": int(selection.get("dato", 1))}
	elif String(selection.get("modo", "color")) == "letra":
		data = {"tipo": "letra", "dato": int(selection.get("dato", 0))}
	elif LIBRE_NAMES.has(String(selection.get("modo", "color"))):
		# 1.3: agua, árbol, flor y piezas de casa (solo mundo libre:
		# la paleta los oculta en los mundos de niveles).
		data = {"tipo": String(selection.get("modo", "color")), "dato": 0}
	blocks[cell] = data
	_spawn_block_node(cell, data)
	_play_sound(_pop_stream)
	# F2.1: el nombre se dice Y se muestra en grande. El anuncio visual es
	# la garantía si el TTS del TV no tiene voz en español (o ninguna voz).
	# F2.2: si existe el clip de voz familiar, suena él en vez del TTS.
	# Este código corre igual en modo libre y en modo nivel.
	var nombre := ""
	var clip := ""
	if String(data["tipo"]) == "numero":
		nombre = NUMBER_NAMES[clampi(int(data["dato"]) - 1, 0, NUMBER_NAMES.size() - 1)]
		clip = "numero_%d" % int(data["dato"])
	elif String(data["tipo"]) == "letra":
		var letras: Array = LevelsData.LETRAS
		nombre = String(letras[clampi(int(data["dato"]), 0, letras.size() - 1)])
		clip = "letra_" + nombre.to_lower()
	elif LIBRE_NAMES.has(String(data["tipo"])):
		# 1.3: sin clip familiar (el banco solo tiene colores, números
		# y letras): suena el TTS con el nombre.
		nombre = String(LIBRE_NAMES[String(data["tipo"])])
		clip = ""
	else:
		nombre = String(BLOCK_COLORS[int(data["dato"])]["nombre"])
		clip = "color_" + nombre.to_lower()
	speak("¡" + nombre + "!", clip)
	_palette.show_announcement("¡" + nombre.to_upper() + "!")
	# Fase 2: registrar lo colocado en el nivel y comprobar la meta.
	if _level_mode and not _level_completed:
		var placed := {"tipo": String(data["tipo"]), "dato": int(data["dato"]), "celda": cell}
		_level_placed.append(placed)
		var tipo_meta := String(_level_def.get("tipo", ""))
		var params: Dictionary = _level_def.get("params", {})
		if LevelLogic.check_goal(tipo_meta, params, _level_target, _level_placed):
			_complete_level()
	_mark_dirty()
	_update_info()
	_update_ghost(true)


func remove_at_cursor() -> void:
	# 1.4: en modo caminar no se borra con el cursor; quitar en paseo
	# va por _walk_remove, con punto de mira.
	if _walk_mode:
		return
	var target := _remove_target()
	_remove_at(target)


## Quita el bloque de `cell` (o nada si no hay). Lo usan el cursor y
## el paseo (1.10.0). `target.x < 0` es el "no hay nada" del cursor.
func _remove_at(target: Vector3i) -> void:
	if target.x < 0:
		return
	# Fase 2: quitar el bloque también de la lista del nivel, para que
	# borrar corrija (p. ej. si se pasó de la cantidad o puso uno mal).
	if _level_mode:
		for i in range(_level_placed.size() - 1, -1, -1):
			if Vector3i(_level_placed[i].get("celda", Vector3i(-1, -1, -1))) == target:
				_level_placed.remove_at(i)
				break
	blocks.erase(target)
	if block_nodes.has(target):
		(block_nodes[target] as Node).queue_free()
		block_nodes.erase(target)
	_play_sound(_toc_stream)
	_mark_dirty()
	_update_info()
	_update_ghost(true)


## Celda que se borraría: la del cursor si tiene bloque; si no, el bloque
## más alto de la misma columna (así borrar en el TV es fácil y amable).
func _remove_target() -> Vector3i:
	if blocks.has(cursor):
		return cursor
	for y in range(cursor.y - 1, -1, -1):
		var c := Vector3i(cursor.x, y, cursor.z)
		if blocks.has(c):
			return c
	return Vector3i(-1, -1, -1)


func set_cursor_height(delta_y: int) -> void:
	# 1.4: en modo caminar el avatar va a ras de suelo.
	if _walk_mode:
		return
	var ny := clampi(cursor.y + delta_y, 0, MAX_HEIGHT - 1)
	if ny == cursor.y:
		if delta_y > 0:
			_palette.show_message("¡Ya estás en lo más alto!")
		return
	cursor.y = ny
	_update_info()
	_update_ghost(true)


func _step_cursor(input_vec: Vector2i) -> void:
	# El movimiento sigue la orientación de la cámara, redondeada a 90°.
	var f := Vector3(-sin(_yaw_target), 0.0, -cos(_yaw_target))
	var f_step := Vector3i.ZERO
	if absf(f.x) > absf(f.z):
		f_step = Vector3i(1 if f.x > 0.0 else -1, 0, 0)
	else:
		f_step = Vector3i(0, 0, 1 if f.z > 0.0 else -1)
	var r_step := Vector3i(-f_step.z, 0, f_step.x)
	var step := r_step * input_vec.x + f_step * (-input_vec.y)
	cursor.x += step.x
	cursor.z += step.z
	_ensure_chunks_around(Vector2i(cursor.x, cursor.z))
	_update_info()
	_update_ghost(true)


func _on_selection_changed(sel: Dictionary) -> void:
	selection = sel.duplicate()
	_update_ghost(true)


## 1.3: giro de cámara por pasos con el mando (paleta TV). Cada OK
## sobre «Girar ←»/«Girar →» suma ±45°; 8 pasos = vuelta completa.
func _on_rotate_step(degrees: float) -> void:
	_yaw_target += deg_to_rad(degrees)


## 1.5 (F3): el extra «Cámara» de la paleta TV cicla los presets de la
## vista de construcción (Arriba → Cerca → Lado → Lejos). La paleta
## QUEDA ABIERTA (como el giro 1.3) para repetir OK y ver cada vista.
## La cámara por defecto sigue siendo Arriba; el modo caminar no se toca.
func _on_camera_cycle() -> void:
	_cam_preset = (_cam_preset + 1) % _cam_presets.size()
	var p: Dictionary = _cam_presets[_cam_preset]
	_palette.show_message("Cámara: " + String(p["nombre"]))
	speak(String(p["voz"]))


# ---------------------------------------------------------------------------
# 1.4: modo caminar (avatar) y mascota
# ---------------------------------------------------------------------------

## Input dentro del modo caminar. ▲ avanza, ▼ retrocede (con
## repetición al mantener), ◀ ▶ giran por pasos de 45° (como el giro
## 1.3), OK corto sale al modo construir. 1.10.0: OK largo y el botón
## B abren el menú radial (Poner / Quitar / Vista / Salir); con el
## radial abierto, ◀ ▶ cambian el resaltado y OK confirma, y el
## movimiento queda en pausa. Atrás cierra el radial o sale del paseo
## (ver _unhandled_input).
func _handle_walk_mode(delta: float, ok_event: String) -> void:
	if _radial_open:
		if ok_event == "short":
			_palette.radial_confirm()
		elif Input.is_action_just_pressed("move_left"):
			_palette.radial_move(-1)
		elif Input.is_action_just_pressed("move_right"):
			_palette.radial_move(1)
		return
	if ok_event == "short":
		_exit_walk_mode()
		return
	if ok_event == "long":
		_open_radial()
		return
	if Input.is_action_just_pressed("remove_block"):
		_open_radial()
		return
	if Input.is_action_just_pressed("move_left"):
		_walk_yaw += deg_to_rad(45.0)
	if Input.is_action_just_pressed("move_right"):
		_walk_yaw -= deg_to_rad(45.0)
	var fb := 0
	if Input.is_action_pressed("move_forward"):
		fb += 1
	if Input.is_action_pressed("move_back"):
		fb -= 1
	if fb != 0:
		_walk_move_timer -= delta
		if _walk_move_timer <= 0.0:
			_step_walk(fb)
			_walk_move_timer = 0.2
	else:
		_walk_move_timer = 0.0


## Cambiar la vista del paseo (1ª/2ª persona). Antes vivía dentro de
## _handle_walk_mode (OK largo del mando); en Fase 2 se extrae para
## que el botón táctil «Vista» use exactamente la misma función.
func _toggle_walk_view() -> void:
	_walk_view = 1 - _walk_view
	if _walk_avatar != null:
		_walk_avatar.visible = (_walk_view == 1)
	_palette.show_message("Vista: " + ("segunda persona (Blocky)" if _walk_view == 1 else "primera persona"))


## 1.10.0: menú radial del paseo. Abrir/cerrar actualiza el estado
## local; la vista del radial vive en palette_ui.gd (mismo patrón de
## resaltado manual que la paleta TV, sin foco que perder).
func _open_radial() -> void:
	if not _walk_mode or _radial_open:
		return
	_radial_open = true
	_palette.open_radial()


func _close_radial() -> void:
	if not _radial_open:
		return
	_radial_open = false
	_palette.close_radial()


## «Vista» desde el radial: cambia la vista y cierra el menú, para
## volver al paseo con un solo toque/OK.
func _on_radial_view() -> void:
	_close_radial()
	_toggle_walk_view()


## Paso del avatar en la dirección de la cámara (redondeada a 90°,
## igual que el cursor en construcción). Respeta la colisión simple
## (ver _walk_blocked): no entra a celdas con bloque sólido.
func _step_walk(dir: int) -> void:
	var f := Vector3(-sin(_walk_yaw), 0.0, -cos(_walk_yaw))
	var f_step := Vector2i.ZERO
	if absf(f.x) > absf(f.z):
		f_step = Vector2i(1 if f.x > 0.0 else -1, 0)
	else:
		f_step = Vector2i(0, 1 if f.z > 0.0 else -1)
	var next := _walk_cell + f_step * dir
	if _walk_blocked(next.x, next.y):
		return
	_walk_cell = next
	_ensure_chunks_around(_walk_cell)


## Colisión simple a nivel del suelo: fuera de la rejilla bloquea;
## una celda con bloque sólido a y=0 bloquea; puerta, agua y celdas
## vacías son transitables (la puerta es la entrada a la casa). Los
## bloques apilados por encima no bloquean el paso a ras de suelo.
func _walk_blocked(cx: int, cz: int) -> bool:
	# 1.10.0: sin muro en el borde (el mundo es infinito): solo
	# bloquea un bloque sólido a ras de suelo. La mascota usa esta
	# misma función, así que también puede seguir más allá del borde.
	var cell := Vector3i(cx, 0, cz)
	if blocks.has(cell):
		var tipo := String(blocks[cell].get("tipo", "color"))
		return tipo != "puerta" and tipo != "agua"
	return false


## Celda libre más cercana a `from` (búsqueda en anchura). Si no hay
## ninguna (prácticamente imposible), devuelve `from`.
func _nearest_free_cell(from: Vector2i) -> Vector2i:
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	seen[from] = true
	var head := 0
	while head < queue.size() and head < 4096:
		var c := queue[head]
		head += 1
		if not _walk_blocked(c.x, c.y):
			return c
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return from


## Entrar al modo caminar (desde la paleta TV). La cámara pasa a
## primera persona en la posición del cursor; si esa celda está
## ocupada por un bloque sólido, se empieza en la celda libre más
## cercana. El yaw de construcción se conserva para volver igual.
func _enter_walk_mode() -> void:
	if _level_completed or _walk_mode:
		return
	_walk_mode = true
	_walk_cell = Vector2i(cursor.x, cursor.z)
	if _walk_blocked(_walk_cell.x, _walk_cell.y):
		_walk_cell = _nearest_free_cell(_walk_cell)
	_walk_yaw = _yaw_target
	_walk_move_timer = 0.0
	if _walk_avatar != null:
		_walk_avatar.visible = (_walk_view == 1)
	_palette.set_walk_controls_visible(true)
	_update_walk_ghost()
	_palette.show_message("Caminando: ▲ avanza · ▼ retrocede · ◀ ▶ gira · OK sale · mantén OK cambia la vista")
	speak("¡A caminar!", "")


## Salir al modo construir: la cámara vuelve a la vista desde
## arriba y el fantasma del cursor reaparece. El yaw de construcción
## no se tocó durante el paseo, así que la vista vuelve igual.
func _exit_walk_mode() -> void:
	if not _walk_mode:
		return
	_walk_mode = false
	_close_radial()
	_palette.set_walk_controls_visible(false)
	# 1.5 (F3): al salir del paseo vuelve el preset de construcción
	# activo (antes forzaba Arriba aunque se hubiera elegido otro).
	var cp: Dictionary = _cam_presets[_cam_preset]
	_camera.position = Vector3(cp["offset"])
	_camera.rotation_degrees = Vector3(float(cp["rot_x"]), 0.0, 0.0)
	_ghost_root.visible = true
	if _walk_avatar != null:
		_walk_avatar.visible = false
	_update_ghost(true)
	_update_info()


## Blocky en segunda persona: cubo azul con cabeza y ojos, en la
## celda del avatar y mirando hacia donde mira la cámara. Solo se ve
## en segunda persona dentro del modo caminar.
func _update_walk_avatar() -> void:
	if _walk_avatar == null:
		return
	_walk_avatar.visible = (_walk_view == 1)
	_walk_avatar.position = Vector3(float(_walk_cell.x) + 0.5, 0.0, float(_walk_cell.y) + 0.5)
	_walk_avatar.rotation.y = _walk_yaw


## La mascota sigue al avatar en modo caminar. Si está lejos
## (distancia Manhattan > 1), avanza una celda cada 0.4 s hacia el
## avatar con la misma colisión (no atraviesa paredes; si el paso
## directo está bloqueado, intenta el otro eje); si está cerca,
## queda quieta con un balanceo idle y mueve la cola. En modo
## construcción no se mueve (se queda donde quedó).
func _update_pet(delta: float) -> void:
	if _pet_node == null:
		return
	var dx := _walk_cell.x - _pet_cell.x
	var dz := _walk_cell.y - _pet_cell.y
	var dist := absi(dx) + absi(dz)
	if dist > 1:
		_pet_timer -= delta
		if _pet_timer <= 0.0:
			_pet_timer = 0.4
			var step := Vector2i.ZERO
			if absi(dx) >= absi(dz):
				step = Vector2i(1 if dx > 0 else -1, 0)
			else:
				step = Vector2i(0, 1 if dz > 0 else -1)
			var nx := _pet_cell.x + step.x
			var nz := _pet_cell.y + step.y
			if _walk_blocked(nx, nz):
				var alt := Vector2i.ZERO
				if step.x != 0 and dz != 0:
					alt = Vector2i(0, 1 if dz > 0 else -1)
				elif step.y != 0 and dx != 0:
					alt = Vector2i(1 if dx > 0 else -1, 0)
				if alt != Vector2i.ZERO and not _walk_blocked(_pet_cell.x + alt.x, _pet_cell.y + alt.y):
					step = alt
					nx = _pet_cell.x + step.x
					nz = _pet_cell.y + step.y
				else:
					step = Vector2i.ZERO
			if step != Vector2i.ZERO:
				_pet_cell = Vector2i(nx, nz)
				_pet_node.rotation.y = atan2(-float(step.x), -float(step.y))
	var target := Vector3(float(_pet_cell.x) + 0.5, 0.0, float(_pet_cell.y) + 0.5)
	_pet_node.position = _pet_node.position.lerp(target, minf(1.0, delta * 8.0))
	var bob := 0.0
	if dist <= 1:
		bob = 0.04 * sin(float(Time.get_ticks_msec()) / 150.0)
	_pet_body.position.y = bob
	if _pet_tail != null:
		_pet_tail.rotation.z = 0.35 * sin(float(Time.get_ticks_msec()) / 120.0)


## Construye el avatar Blocky (segunda persona) y la mascota
## (perrito de cubos procedural: cuerpo + cabeza + orejas + cola).
## La mascota nace en la celda libre más cercana al centro; el
## avatar nace oculto (solo se ve en segunda persona al caminar).
func _build_walk_actors() -> void:
	_walk_avatar = Node3D.new()
	var abody := MeshInstance3D.new()
	var abody_mesh := BoxMesh.new()
	abody_mesh.size = Vector3(0.55, 0.7, 0.35)
	abody.mesh = abody_mesh
	abody.material_override = _make_material(Color(0.20, 0.55, 0.95))
	abody.position = Vector3(0.0, 0.55, 0.0)
	_walk_avatar.add_child(abody)
	var ahead := MeshInstance3D.new()
	var ahead_mesh := BoxMesh.new()
	ahead_mesh.size = Vector3(0.45, 0.45, 0.45)
	ahead.mesh = ahead_mesh
	ahead.material_override = _make_material(Color(1.0, 0.85, 0.65))
	ahead.position = Vector3(0.0, 1.12, 0.0)
	_walk_avatar.add_child(ahead)
	for sx in [-0.11, 0.11]:
		var eye := MeshInstance3D.new()
		var eye_mesh := BoxMesh.new()
		eye_mesh.size = Vector3(0.07, 0.09, 0.02)
		eye.mesh = eye_mesh
		eye.material_override = _make_material(Color(0.05, 0.05, 0.10))
		eye.position = Vector3(sx, 1.15, -0.24)
		_walk_avatar.add_child(eye)
	_walk_avatar.visible = false
	add_child(_walk_avatar)

	_pet_node = Node3D.new()
	_pet_body = Node3D.new()
	_pet_node.add_child(_pet_body)
	var pbody := MeshInstance3D.new()
	var pbody_mesh := BoxMesh.new()
	pbody_mesh.size = Vector3(0.55, 0.32, 0.75)
	pbody.mesh = pbody_mesh
	pbody.material_override = _make_material(Color(0.85, 0.68, 0.45))
	pbody.position = Vector3(0.0, 0.32, 0.0)
	_pet_body.add_child(pbody)
	var phead := MeshInstance3D.new()
	var phead_mesh := BoxMesh.new()
	phead_mesh.size = Vector3(0.38, 0.35, 0.38)
	phead.mesh = phead_mesh
	phead.material_override = _make_material(Color(0.90, 0.75, 0.55))
	phead.position = Vector3(0.0, 0.42, -0.52)
	_pet_body.add_child(phead)
	for sx in [-0.13, 0.13]:
		var ear := MeshInstance3D.new()
		var ear_mesh := BoxMesh.new()
		ear_mesh.size = Vector3(0.12, 0.18, 0.08)
		ear.mesh = ear_mesh
		ear.material_override = _make_material(Color(0.55, 0.38, 0.22))
		ear.position = Vector3(sx, 0.66, -0.52)
		_pet_body.add_child(ear)
	_pet_tail = MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.10, 0.10, 0.30)
	_pet_tail.mesh = tail_mesh
	_pet_tail.material_override = _make_material(Color(0.85, 0.68, 0.45))
	_pet_tail.position = Vector3(0.0, 0.42, 0.48)
	_pet_tail.rotation.x = -0.5
	_pet_body.add_child(_pet_tail)
	_pet_cell = _nearest_free_cell(Vector2i(10, 10))
	_pet_node.position = Vector3(float(_pet_cell.x) + 0.5, 0.0, float(_pet_cell.y) + 0.5)
	add_child(_pet_node)


func _on_world_reset() -> void:
	for cell in block_nodes.keys():
		(block_nodes[cell] as Node).queue_free()
	block_nodes.clear()
	blocks.clear()
	cursor = Vector3i(10, 0, 10)
	_mark_dirty()
	_update_info()
	_update_ghost(true)
	if _level_mode:
		# En un nivel, «Empezar de nuevo» reinicia el nivel, no el mundo.
		_level_placed.clear()
		_level_completed = false
		_hide_sky_bodies()
		_palette.hide_celebration()
		_palette.set_goal(_level_instruction_text())
		speak(_level_instruction_voice())
		_show_level_hints()
	else:
		_palette.show_message("¡Mundo nuevo! A construir.")
		speak("¡A construir!", "frase_a_construir")


func _update_info() -> void:
	if _palette == null:
		return
	if _level_mode:
		_update_level_info()
		return
	_palette.set_info("Altura: %d · Bloques: %d/%d" % [cursor.y + 1, blocks.size(), MAX_BLOCKS])


# ---------------------------------------------------------------------------
# Toque en pantalla: mover el cursor con un rayo desde la cámara
# ---------------------------------------------------------------------------

func _handle_tap(screen_pos: Vector2) -> void:
	if _camera == null:
		return
	var origin := _camera.project_ray_origin(screen_pos)
	var dir := _camera.project_ray_normal(screen_pos)
	var best_t := 1.0e9
	var best_cell := Vector3i.ZERO
	var best_normal := Vector3.ZERO
	var found := false
	for cell in blocks.keys():
		var res := _ray_aabb(origin, dir, Vector3(cell))
		if bool(res.get("hit", false)) and float(res["t"]) < best_t:
			best_t = float(res["t"])
			best_cell = cell
			best_normal = res["normal"]
			found = true
	var ground_point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if ground_point != null:
		var gp: Vector3 = ground_point
		if origin.distance_to(gp) < best_t:
			var gc := Vector3i(floori(gp.x), 0, floori(gp.z))
			cursor = gc
			_ensure_chunks_around(Vector2i(cursor.x, cursor.z))
			_update_info()
			_update_ghost(true)
			return
	if found:
		if best_normal.y > 0.5:
			cursor = Vector3i(best_cell.x, mini(best_cell.y + 1, MAX_HEIGHT - 1), best_cell.z)
		else:
			cursor = best_cell
		_update_info()
		_update_ghost(true)


## Intersección rayo–caja (método de los planos) contra un cubo de 1×1×1
## cuya esquina mínima es box_min. Devuelve {"hit", "t", "normal"}.
func _ray_aabb(origin: Vector3, dir: Vector3, box_min: Vector3) -> Dictionary:
	var tmin := 0.0
	var tmax := 1000.0
	var normal := Vector3.ZERO
	for axis in range(3):
		var o := origin[axis]
		var d := dir[axis]
		var mn := box_min[axis]
		var mx := mn + 1.0
		if absf(d) < 0.00001:
			if o < mn or o > mx:
				return {"hit": false}
		else:
			var inv := 1.0 / d
			var t1 := (mn - o) * inv
			var t2 := (mx - o) * inv
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			if t1 > tmin:
				tmin = t1
				normal = Vector3.ZERO
				match axis:
					0:
						normal.x = -signf(d)
					1:
						normal.y = -signf(d)
					_:
						normal.z = -signf(d)
			tmax = minf(tmax, t2)
			if tmax < tmin:
				return {"hit": false}
	return {"hit": true, "t": tmin, "normal": normal}


# ---------------------------------------------------------------------------
# Bloques y fantasma
# ---------------------------------------------------------------------------

func _spawn_block_node(cell: Vector3i, data: Dictionary, pop := true) -> void:
	var root := Node3D.new()
	root.position = Vector3(cell) + Vector3(0.5, 0.5, 0.5)
	var tipo := String(data.get("tipo", "color"))
	if tipo == "arbol":
		# 1.3: arbolito procedural (tronco + copa) dentro de la celda.
		_spawn_tree(root)
	elif tipo == "flor":
		# 1.3: flor decorativa procedural (tallo + pétalos) en la celda.
		_spawn_flower(root)
	elif tipo == "puerta":
		# Fase 1: puerta real (marco + abertura), no un cubo café.
		_spawn_door(root)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh
		if tipo == "numero":
			mi.material_override = _number_material
		elif tipo == "letra":
			mi.material_override = _letter_material
		elif tipo == "agua":
			mi.material_override = _water_material
		elif tipo == "pared":
			mi.material_override = _wall_material
		elif tipo == "techo":
			mi.material_override = _roof_material
		elif tipo == "puerta":
			mi.material_override = _door_material
		else:
			mi.material_override = _materials[int(data.get("dato", 0))]
		root.add_child(mi)
		if tipo == "numero":
			_add_text_labels(root, str(int(data.get("dato", 1))))
		elif tipo == "letra":
			var letras: Array = LevelsData.LETRAS
			_add_text_labels(root, String(letras[clampi(int(data.get("dato", 0)), 0, letras.size() - 1)]))
	_blocks_root.add_child(root)
	block_nodes[cell] = root
	if pop:
		# 1.5 (F3): pop elástico al colocar (~0.25 s, sutil). Al cargar
		# el mundo guardado NO hay pop (pop=false) para no animar los
		# cientos de bloques de golpe al abrir el juego.
		root.scale = Vector3(0.25, 0.25, 0.25)
		var tw := root.create_tween()
		tw.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Arbolito 1.3: tronco cilíndrico + copa esférica, todo procedural
## (mismo patrón que los árboles decorativos del borde del mundo).
## Cabe en la celda (la copa asoma un poco por arriba, como un árbol).
func _spawn_tree(parent: Node3D) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.13
	trunk_mesh.bottom_radius = 0.18
	trunk_mesh.height = 0.6
	trunk.mesh = trunk_mesh
	trunk.material_override = _trunk_material
	trunk.position = Vector3(0.0, -0.2, 0.0)
	parent.add_child(trunk)
	var leaves := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.42
	sphere.height = 0.84
	leaves.mesh = sphere
	leaves.material_override = _leaf_material
	leaves.position = Vector3(0.0, 0.28, 0.0)
	parent.add_child(leaves)


## Flor 1.3: tallo fino + cabeza de pétalos (esfera rosa) en la celda.
func _spawn_flower(parent: Node3D) -> void:
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.05
	stem_mesh.bottom_radius = 0.05
	stem_mesh.height = 0.5
	stem.mesh = stem_mesh
	stem.material_override = _trunk_material
	stem.position = Vector3(0.0, -0.25, 0.0)
	parent.add_child(stem)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	head.mesh = sphere
	head.material_override = _flower_material
	head.position = Vector3(0.0, 0.22, 0.0)
	parent.add_child(head)


## Puerta real (Fase 1): marco de 4 postes en las esquinas + anillo
## superior, con el centro ABIERTO. Se lee como puerta desde los 4 lados
## (las casas se construyen en cualquier dirección) y es coherente con
## la colisión: la celda ya era transitable (ver _walk_blocked: la
## puerta es la entrada a la casa). No cambia el guardado: el tipo
## sigue siendo "puerta".
func _spawn_door(parent: Node3D) -> void:
	for sx in [-0.41, 0.41]:
		for sz in [-0.41, 0.41]:
			var post := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.18, 1.0, 0.18)
			post.mesh = pm
			post.material_override = _door_material
			post.position = Vector3(sx, 0.0, sz)
			parent.add_child(post)
	for sz in [-0.41, 0.41]:
		var beam_x := MeshInstance3D.new()
		var bm_x := BoxMesh.new()
		bm_x.size = Vector3(1.0, 0.18, 0.18)
		beam_x.mesh = bm_x
		beam_x.material_override = _door_material
		beam_x.position = Vector3(0.0, 0.41, sz)
		parent.add_child(beam_x)
	for sx in [-0.41, 0.41]:
		var beam_z := MeshInstance3D.new()
		var bm_z := BoxMesh.new()
		bm_z.size = Vector3(0.18, 0.18, 1.0)
		beam_z.mesh = bm_z
		beam_z.material_override = _door_material
		beam_z.position = Vector3(sx, 0.41, 0.0)
		parent.add_child(beam_z)


## El texto (número o letra) se dibuja con Label3D en la cara superior
## y las 4 laterales, para que se vea desde cualquier ángulo de cámara.
func _add_text_labels(parent: Node3D, texto: String) -> void:
	var faces: Array = [
		[Vector3(0.0, 0.51, 0.0), Vector3(-90.0, 0.0, 0.0)],
		[Vector3(0.0, 0.0, 0.51), Vector3(0.0, 0.0, 0.0)],
		[Vector3(0.0, 0.0, -0.51), Vector3(0.0, 180.0, 0.0)],
		[Vector3(0.51, 0.0, 0.0), Vector3(0.0, 90.0, 0.0)],
		[Vector3(-0.51, 0.0, 0.0), Vector3(0.0, -90.0, 0.0)],
	]
	for face in faces:
		var label := Label3D.new()
		label.text = texto
		label.font_size = 160
		label.pixel_size = 0.0035
		label.modulate = NUMBER_TEXT_COLOR
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = face[0]
		label.rotation_degrees = face[1]
		parent.add_child(label)


func _build_ghost() -> void:
	# 1.5 (F3): el cursor ya no es un cubo: es Blocky, el mismo
	# personajito de la 2ª persona del modo caminar (cuerpo + cabeza +
	# ojos, procedural, sin assets). SOLO cambia la apariencia: el
	# movimiento, la colocación y la vista desde arriba son los mismos.
	# Cuerpo y cabeza comparten _ghost_material (translúcido), así que
	# el tinte de _update_ghost (color elegido / rojo si ocupado o
	# borrador) sigue funcionando igual que con el cubo. Los ojos usan
	# un material oscuro propio para que siempre se distingan.
	_ghost_root = Node3D.new()
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.albedo_color = Color(1.0, 1.0, 1.0, 0.45)
	_ghost_eye_material = StandardMaterial3D.new()
	_ghost_eye_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_eye_material.albedo_color = Color(0.05, 0.05, 0.10, 0.85)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.55, 0.7, 0.35)
	body.mesh = body_mesh
	body.material_override = _ghost_material
	body.position = Vector3(0.0, -0.15, 0.0)
	_ghost_root.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.45, 0.45, 0.45)
	head.mesh = head_mesh
	head.material_override = _ghost_material
	head.position = Vector3(0.0, 0.425, 0.0)
	_ghost_root.add_child(head)
	for sx in [-0.11, 0.11]:
		var eye := MeshInstance3D.new()
		var eye_mesh := BoxMesh.new()
		eye_mesh.size = Vector3(0.07, 0.09, 0.02)
		eye.mesh = eye_mesh
		eye.material_override = _ghost_eye_material
		eye.position = Vector3(sx, 0.45, 0.24)
		_ghost_root.add_child(eye)
	_ghost_label = Label3D.new()
	_ghost_label.font_size = 160
	_ghost_label.pixel_size = 0.0035
	_ghost_label.modulate = NUMBER_TEXT_COLOR
	_ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ghost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ghost_label.position = Vector3(0.0, 0.72, 0.0)
	_ghost_label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_ghost_label.visible = false
	_ghost_root.add_child(_ghost_label)
	add_child(_ghost_root)


func _update_ghost(force := false) -> void:
	if _ghost_root == null:
		return
	var modo := String(selection.get("modo", "color"))
	var dato := int(selection.get("dato", 0))
	var target := cursor
	var base_color := Color.WHITE
	var number_text := ""
	if modo == "borrador":
		var rt := _remove_target()
		if rt.x >= 0:
			target = rt
		base_color = Color(0.95, 0.30, 0.30)
	elif modo == "numero":
		base_color = NUMBER_CUBE_COLOR
		number_text = str(dato)
	elif modo == "letra":
		base_color = LETTER_CUBE_COLOR
		var letras: Array = LevelsData.LETRAS
		number_text = String(letras[clampi(dato, 0, letras.size() - 1)])
	elif modo == "agua":
		base_color = WATER_COLOR
	elif modo == "arbol":
		base_color = LEAF_COLOR
	elif modo == "flor":
		base_color = FLOWER_HEAD_COLOR
	elif modo == "pared":
		base_color = WALL_COLOR
	elif modo == "techo":
		base_color = ROOF_COLOR
	elif modo == "puerta":
		base_color = DOOR_COLOR
	else:
		var c: Color = BLOCK_COLORS[dato]["color"]
		base_color = c
	var occupied := blocks.has(target) and modo != "borrador"
	var key := "%s|%d|%s|%s|%s" % [modo, dato, str(target), str(occupied), number_text]
	if force or key != _ghost_state:
		_ghost_state = key
		if occupied:
			_ghost_material.albedo_color = Color(1.0, 0.35, 0.35, 0.30)
		else:
			_ghost_material.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.45)
		_ghost_label.visible = number_text != ""
		if number_text != "":
			_ghost_label.text = number_text
	# 1.5 (F3): Blocky mira hacia la cámara: la cámara está del lado +z
	# del pivot antes del yaw, así que el fantasma gira con el pivot.
	if _pivot != null:
		_ghost_root.rotation.y = _pivot.rotation.y
	_ghost_root.position = Vector3(target) + Vector3(0.5, 0.5, 0.5)
	var pulse := 1.0 + 0.03 * sin(float(Time.get_ticks_msec()) / 200.0)
	_ghost_root.scale = Vector3.ONE * pulse


# ---------------------------------------------------------------------------
# Mundo: cielo, suelo, árboles y cámara
# ---------------------------------------------------------------------------

func _build_shared() -> void:
	_box_mesh = BoxMesh.new()
	_box_mesh.size = Vector3.ONE
	for i in range(BLOCK_COLORS.size()):
		var c: Color = BLOCK_COLORS[i]["color"]
		_materials[i] = _make_material(c)
	_number_material = _make_material(NUMBER_CUBE_COLOR)
	_letter_material = _make_material(LETTER_CUBE_COLOR)
	# 1.3: materiales de las entradas nuevas. El agua es translúcida
	# (se distingue a simple vista) pero sólida como los demás cubos.
	_water_material = _make_material(WATER_COLOR)
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.albedo_color = Color(WATER_COLOR.r, WATER_COLOR.g, WATER_COLOR.b, 0.55)
	_wall_material = _make_material(WALL_COLOR)
	_roof_material = _make_material(ROOF_COLOR)
	_door_material = _make_material(DOOR_COLOR)
	_trunk_material = _make_material(TRUNK_COLOR)
	_leaf_material = _make_material(LEAF_COLOR)
	_flower_material = _make_material(FLOWER_HEAD_COLOR)


func _make_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	_sky_mat = sky_mat
	sky_mat.sky_top_color = Color(0.30, 0.58, 0.95)
	sky_mat.sky_horizon_color = Color(0.72, 0.87, 1.00)
	sky_mat.ground_bottom_color = Color(0.42, 0.62, 0.38)
	sky_mat.ground_horizon_color = Color(0.72, 0.87, 1.00)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	# Fase 1: sol y luna visibles para las palabras SOL y LUNA. Empiezan
	# ocultos; solo se muestran al completar la palabra (ver
	# _complete_level). Son mallas simples con emisión, sin TTS ni
	# micrófono, y quedan en el mismo punto alto del cielo (solo uno
	# visible a la vez).
	var sky_bodies := Node3D.new()
	sky_bodies.name = "SkyBodies"
	add_child(sky_bodies)
	_sun_body = MeshInstance3D.new()
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 3.0
	sun_mesh.height = 6.0
	_sun_body.mesh = sun_mesh
	var sun_mat := StandardMaterial3D.new()
	sun_mat.albedo_color = Color(1.0, 0.85, 0.15)
	sun_mat.emission_enabled = true
	sun_mat.emission = Color(1.0, 0.8, 0.2)
	sun_mat.emission_energy_multiplier = 1.5
	_sun_body.material_override = sun_mat
	_sun_body.position = Vector3(8.0, 24.0, -26.0)
	_sun_body.visible = false
	sky_bodies.add_child(_sun_body)
	_moon_body = MeshInstance3D.new()
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 2.2
	moon_mesh.height = 4.4
	_moon_body.mesh = moon_mesh
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color(0.9, 0.93, 1.0)
	moon_mat.emission_enabled = true
	moon_mat.emission = Color(0.75, 0.8, 0.95)
	moon_mat.emission_energy_multiplier = 0.8
	_moon_body.material_override = moon_mat
	_moon_body.position = Vector3(8.0, 24.0, -26.0)
	_moon_body.visible = false
	sky_bodies.add_child(_moon_body)


func _apply_theme(mundo_id: String) -> void:
	## 1.10.0: el tema del mundo activo (suelo, cielo, decoración).
	## Un mundo desconocido cae a la pradera libre, nunca a un error.
	_theme = WORLD_THEMES.get(mundo_id, WORLD_THEMES["libre"])
	if _sky_mat != null:
		_sky_mat.sky_top_color = _theme["cielo_arriba"]
		_sky_mat.sky_horizon_color = _theme["cielo_horizonte"]
	_chunk_material = StandardMaterial3D.new()
	_chunk_material.roughness = 1.0
	_chunk_material.albedo_texture = _make_chunk_texture()
	_chunk_mesh = PlaneMesh.new()
	_chunk_mesh.size = Vector2(float(CHUNK), float(CHUNK))
	_decor_mesh = SphereMesh.new()
	_decor_mesh.radius = 0.18
	_decor_mesh.height = 0.36


## Textura de un chunk (16 celdas) con los colores del tema. Todos los
## chunks comparten ESTA textura: el damero encaja entre chunks porque
## 16 es par, así que el suelo infinito se ve continuo.
func _make_chunk_texture() -> ImageTexture:
	var cell_px := 32
	var size := CHUNK * cell_px
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var light: Color = _theme["suelo_claro"]
	var dark: Color = _theme["suelo_oscuro"]
	var line: Color = _theme["suelo_linea"]
	for cz in range(CHUNK):
		for cx in range(CHUNK):
			var base := light if (cx + cz) % 2 == 0 else dark
			img.fill_rect(Rect2i(cx * cell_px, cz * cell_px, cell_px, cell_px), base)
			img.fill_rect(Rect2i(cx * cell_px, cz * cell_px, cell_px, 2), line)
			img.fill_rect(Rect2i(cx * cell_px, cz * cell_px, 2, cell_px), line)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Hash determinista y barato para la decoración de un chunk: el mismo
## chunk siempre genera la misma decoración (el mundo "existe" aunque
## se cierre y se vuelva a abrir), sin guardar nada.
func _chunk_hash(cx: int, cz: int, salt: int) -> int:
	var h := (cx * 73856093) ^ (cz * 19349663) ^ (salt * 83492791)
	return absi(h)


func _build_ground() -> void:
	## 1.10.0: ya no hay plano fijo 20×20 ni delantal 80×80: el suelo
	## son chunks que se crean al acercarse (ver _ensure_chunks_around).
	_blocks_root = Node3D.new()
	_blocks_root.name = "Blocks"
	add_child(_blocks_root)
	_ensure_chunks_around(Vector2i(cursor.x, cursor.z))


func _chunk_of(cell: Vector2i) -> Vector2i:
	## División con suelo (floori), no truncada: los chunks negativos
	## también encajan (caminar hacia -x/-z genera terreno igual).
	return Vector2i(floori(float(cell.x) / float(CHUNK)), floori(float(cell.y) / float(CHUNK)))


func _ensure_chunks_around(cell: Vector2i) -> void:
	var center := _chunk_of(cell)
	for dz in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for dx in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			var key := center + Vector2i(dx, dz)
			if not _chunks.has(key):
				_create_chunk(key)


func _create_chunk(key: Vector2i) -> void:
	if _chunks.size() >= MAX_CHUNKS:
		## Tope de seguridad, no muro de juego: con 256 chunks el
		## mundo mide 4096 celdas de lado; un niño no lo alcanza en
		## una sesión, y al reabrir el juego el contador se reinicia.
		if _palette != null:
			_palette.show_message("¡El mundo es enorme! Vuelve un poco para seguir.")
		return
	var root := Node3D.new()
	var tile := MeshInstance3D.new()
	tile.mesh = _chunk_mesh
	tile.material_override = _chunk_material
	tile.position = Vector3(float(key.x * CHUNK + CHUNK / 2), 0.0, float(key.y * CHUNK + CHUNK / 2))
	root.add_child(tile)
	## Decoración determinista: 0–2 flores/piedras por chunk, siempre
	## en el mismo sitio para ese chunk. Son visuales y NO bloquean:
	## caminar sobre una flor es natural; por eso no hay árboles
	## dentro de los chunks (un tronco sí se notaría al atravesarlo).
	var count := _chunk_hash(key.x, key.y, 7) % 3
	var decor_colors: Array = _theme["decor"]
	for i in range(count):
		var lx := 1 + _chunk_hash(key.x, key.y, 11 + i * 2) % (CHUNK - 2)
		var lz := 1 + _chunk_hash(key.x, key.y, 13 + i * 2) % (CHUNK - 2)
		var item := MeshInstance3D.new()
		item.mesh = _decor_mesh
		var c: Color = decor_colors[_chunk_hash(key.x, key.y, 17 + i) % decor_colors.size()]
		if not _decor_materials.has(c):
			_decor_materials[c] = _make_material(c)
		item.material_override = _decor_materials[c]
		item.position = Vector3(float(key.x * CHUNK + lx) + 0.5, 0.12, float(key.y * CHUNK + lz) + 0.5)
		root.add_child(item)
	add_child(root)
	_chunks[key] = root


# ---------------------------------------------------------------------------
# 1.10.0: colocar y quitar desde el paseo (1ª/2ª persona)
# ---------------------------------------------------------------------------

## Celda a la que apunta la cámara del paseo. Rayo desde el centro de
## la vista contra los bloques (misma matemática que el toque); si no
## hay bloque cerca, el punto donde el rayo toca el suelo. Devuelve
## Vector3i(-1, -1, -1) cuando no hay objetivo válido a menos de 6
## celdas (el niño no coloca a lo lejos sin querer).
func _walk_aim_cell() -> Vector3i:
	if _camera == null:
		return Vector3i(-1, -1, -1)
	var origin: Vector3 = _camera.global_position
	var dir: Vector3 = -_camera.global_transform.basis.z
	var best_t := 6.0
	var best_cell := Vector3i(-1, -1, -1)
	var best_normal := Vector3.ZERO
	var found := false
	for cell in blocks.keys():
		var res := _ray_aabb(origin, dir, Vector3(cell))
		if bool(res.get("hit", false)) and float(res["t"]) < best_t:
			best_t = float(res["t"])
			best_cell = cell
			best_normal = res["normal"]
			found = true
	if found:
		if best_normal.y > 0.5:
			return Vector3i(best_cell.x, mini(best_cell.y + 1, MAX_HEIGHT - 1), best_cell.z)
		if best_normal.y < -0.5:
			return Vector3i(best_cell.x, maxi(best_cell.y - 1, 0), best_cell.z)
		return Vector3i(best_cell.x + int(best_normal.x), best_cell.y, best_cell.z + int(best_normal.z))
	var ground_point: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, dir)
	if ground_point != null:
		var gp: Vector3 = ground_point
		if origin.distance_to(gp) <= 6.0:
			return Vector3i(floori(gp.x), 0, floori(gp.z))
	## Sin impacto cerca: en 1ª persona el rayo sale horizontal a 1,5
	## de altura y pasa POR ENCIMA de los bloques sin tocar nunca el
	## suelo. En ese caso el objetivo es la celda 2 pasos al frente:
	## predecible, cerca y visible con el fantasma de mira.
	var f := Vector3(-sin(_walk_yaw), 0.0, -cos(_walk_yaw))
	var f_step := Vector2i.ZERO
	if absf(f.x) > absf(f.z):
		f_step = Vector2i(1 if f.x > 0.0 else -1, 0)
	else:
		f_step = Vector2i(0, 1 if f.z > 0.0 else -1)
	return Vector3i(_walk_cell.x + f_step.x * 2, 0, _walk_cell.y + f_step.y * 2)


## Celda del bloque al que apunta la cámara (para quitar): el bloque
## golpeado por el rayo, o nada si solo se apunta al suelo vacío.
func _walk_hit_cell() -> Vector3i:
	if _camera == null:
		return Vector3i(-1, -1, -1)
	var origin: Vector3 = _camera.global_position
	var dir: Vector3 = -_camera.global_transform.basis.z
	var best_t := 6.0
	var best_cell := Vector3i(-1, -1, -1)
	for cell in blocks.keys():
		var res := _ray_aabb(origin, dir, Vector3(cell))
		if bool(res.get("hit", false)) and float(res["t"]) < best_t:
			best_t = float(res["t"])
			best_cell = cell
	if best_cell.x >= 0:
		return best_cell
	## Sin impacto: el bloque de la celda 2 pasos al frente (el mismo
	## objetivo que _walk_aim_cell cuando no hay rayo), si lo hay.
	var aim := _walk_aim_cell()
	if aim.x >= 0 and blocks.has(aim):
		return aim
	return Vector3i(-1, -1, -1)


## Fantasma del paseo: Blocky translúcido en la celda de mira, con el
## color del bloque elegido (rojo si no se puede poner ahí). Es la
## única guía que necesita el niño para apuntar en 1ª/2ª persona.
func _update_walk_ghost() -> void:
	if _ghost_root == null:
		return
	var target := _walk_aim_cell()
	if target.x < 0:
		_ghost_root.visible = false
		return
	_ghost_root.visible = true
	var modo := String(selection.get("modo", "color"))
	var dato := int(selection.get("dato", 0))
	var base_color := _ghost_base_color(modo, dato)
	var occupied := blocks.has(target)
	var avatar_cell := Vector3i(_walk_cell.x, 0, _walk_cell.y)
	var pet_cell := Vector3i(_pet_cell.x, 0, _pet_cell.y)
	var blocked := occupied or target == avatar_cell or target == pet_cell
	if blocked:
		_ghost_material.albedo_color = Color(1.0, 0.35, 0.35, 0.30)
	else:
		_ghost_material.albedo_color = Color(base_color.r, base_color.g, base_color.b, 0.45)
	_ghost_label.visible = false
	_ghost_root.position = Vector3(target) + Vector3(0.5, 0.5, 0.5)
	_ghost_root.rotation.y = _walk_yaw


## Color base del fantasma según el bloque elegido (compartido por el
## fantasma del cursor y el del paseo).
func _ghost_base_color(modo: String, dato: int) -> Color:
	match modo:
		"numero":
			return NUMBER_CUBE_COLOR
		"letra":
			return LETTER_CUBE_COLOR
		"agua":
			return WATER_COLOR
		"arbol":
			return LEAF_COLOR
		"flor":
			return FLOWER_HEAD_COLOR
		"pared":
			return WALL_COLOR
		"techo":
			return ROOF_COLOR
		"puerta":
			return DOOR_COLOR
		"borrador":
			return Color(0.95, 0.30, 0.30)
		_:
			return BLOCK_COLORS[clampi(dato, 0, BLOCK_COLORS.size() - 1)]["color"]


## Poner desde el paseo: usa la selección actual (se elige en
## construcción antes de caminar) y las mismas reglas de _place_at.
## No se pone sobre el avatar ni sobre la mascota a ras de suelo.
func _walk_place() -> void:
	_close_radial()
	var target := _walk_aim_cell()
	if target.x < 0:
		_palette.show_message("Apunta a un sitio cerca para poner el bloque.")
		return
	var avatar_cell := Vector3i(_walk_cell.x, 0, _walk_cell.y)
	var pet_cell := Vector3i(_pet_cell.x, 0, _pet_cell.y)
	if target == avatar_cell or target == pet_cell:
		_palette.show_message("¡Ahí estás tú (o tu mascota)!")
		return
	_place_at(target)


## Quitar desde el paseo: el bloque al que apunta la cámara.
func _walk_remove() -> void:
	_close_radial()
	var target := _walk_hit_cell()
	if target.x < 0:
		_palette.show_message("Apunta a un bloque para quitarlo.")
		return
	_remove_at(target)


func _build_trees() -> void:
	var trunk_mat := _make_material(Color(0.45, 0.32, 0.20))
	var leaf_mat := _make_material(Color(0.25, 0.60, 0.30))
	var spots: Array = [
		Vector2(-2.5, -2.0), Vector2(22.5, -1.5), Vector2(-2.0, 22.0),
		Vector2(22.0, 22.5), Vector2(4.0, -3.0), Vector2(12.0, 23.0),
		Vector2(-3.0, 7.0), Vector2(23.0, 10.0), Vector2(8.0, -3.5),
		Vector2(-3.5, 13.0),
	]
	var idx := 0
	for s in spots:
		var tree := Node3D.new()
		var trunk := MeshInstance3D.new()
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.16
		trunk_mesh.bottom_radius = 0.24
		trunk_mesh.height = 1.2
		trunk.mesh = trunk_mesh
		trunk.material_override = trunk_mat
		trunk.position = Vector3(0.0, 0.6, 0.0)
		tree.add_child(trunk)
		var leaves := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.95
		sphere.height = 1.9
		leaves.mesh = sphere
		leaves.material_override = leaf_mat
		leaves.position = Vector3(0.0, 1.95, 0.0)
		tree.add_child(leaves)
		var sc := 0.9 + 0.15 * float(idx % 3)
		tree.scale = Vector3.ONE * sc
		tree.position = Vector3(s.x, 0.0, s.y)
		add_child(tree)
		idx += 1


func _build_camera() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_camera = Camera3D.new()
	_camera.position = Vector3(0.0, 10.5, 10.5)
	_camera.rotation_degrees = Vector3(-45.0, 0.0, 0.0)
	_camera.fov = 55.0
	_camera.far = 150.0
	_pivot.add_child(_camera)
	_camera.current = true
	_pivot.position = Vector3(float(cursor.x) + 0.5, 0.6, float(cursor.z) + 0.5)


# ---------------------------------------------------------------------------
# Voz (TTS del sistema) y sonidos generados
# ---------------------------------------------------------------------------

func _init_tts() -> void:
	var voices := DisplayServer.tts_get_voices()
	var fallback := ""
	for v in voices:
		var vid := String(v.get("id", ""))
		if vid == "":
			continue
		if fallback == "":
			fallback = vid
		if String(v.get("language", "")).begins_with("es"):
			_tts_voice = vid
			break
	if _tts_voice == "":
		_tts_voice = fallback


## Habla una frase corta. F2.2: si se pasa un clip y existe en el banco
## de audio interno, suena la voz familiar y NO se usa el TTS. Si no hay
## clip, se usa el TTS; si el dispositivo no tiene voces, no hace nada
## (el juego sigue funcionando sin error, con el anuncio visual).
func speak(text: String, clip := "") -> void:
	if clip != "" and _audio_bank != null and _audio_bank.play_clip(clip):
		return
	if _tts_voice == "":
		return
	DisplayServer.tts_speak(text, _tts_voice, 50, 1.0, 1.0, 0, true)


func _build_audio() -> void:
	_pop_stream = _make_tone(520.0, 160.0, 0.16, 0.5)
	_toc_stream = _make_tone(210.0, 140.0, 0.09, 0.45)
	_win_stream = _make_tone(600.0, 1400.0, 0.6, 0.5)
	for i in range(4):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_audio_players.append(p)


## Tono senoidal con caída de frecuencia y volumen, creado muestra a muestra.
func _make_tone(freq_start: float, freq_end: float, duration: float, volume: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(float(rate) * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / float(frames)
		var freq := lerpf(freq_start, freq_end, t)
		phase += TAU * freq / float(rate)
		var envelope := exp(-3.5 * t)
		var sample := sin(phase) * envelope * volume
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _play_sound(stream: AudioStream) -> void:
	if stream == null or _audio_players.is_empty():
		return
	var p := _audio_players[_audio_next]
	_audio_next = (_audio_next + 1) % _audio_players.size()
	p.stream = stream
	p.play()


# ---------------------------------------------------------------------------
# Fase 2: niveles de Mundos
# ---------------------------------------------------------------------------

## Prepara un nivel: tablero vacío, meta al azar si aplica, cartel con la
## instrucción y voz. El mundo libre no se carga ni se guarda aquí.
func _start_level() -> void:
	_level_def = LevelsData.get_nivel(GameState.mundo, GameState.nivel)
	_level_placed = []
	_level_completed = false
	_hide_sky_bodies()
	_level_progress = ProgressSave.load_progress()
	_level_target = -1
	var tipo := String(_level_def.get("tipo", ""))
	if tipo == "color_voz" or tipo == "letra_voz":
		var opciones: Array = _level_def.get("params", {}).get("opciones", [])
		if not opciones.is_empty():
			_level_target = int(opciones[randi() % opciones.size()])
	_palette.set_level_world(GameState.mundo)
	_palette.set_goal(_level_instruction_text())
	_palette.hide_celebration()
	_update_level_info()
	speak(_level_instruction_voice())
	_show_level_hints()


func _level_instruction_text() -> String:
	var tipo := String(_level_def.get("tipo", ""))
	if (tipo == "color_voz" or tipo == "letra_voz") and _level_target >= 0:
		return String(LevelsData.instruccion_aleatoria(tipo, _level_target).get("texto", ""))
	return String(_level_def.get("texto", ""))


func _level_instruction_voice() -> String:
	var tipo := String(_level_def.get("tipo", ""))
	if (tipo == "color_voz" or tipo == "letra_voz") and _level_target >= 0:
		return String(LevelsData.instruccion_aleatoria(tipo, _level_target).get("voz", ""))
	return String(_level_def.get("voz", ""))


## 1.6: pistas visuales del nivel. Una casilla plana translúcida por
## pista, con letra/número encima cuando la pista lo lleva. Las
## pistas NO entran en blocks/block_nodes, así que no cuentan, no se
## guardan y no bloquean al avatar: son solo una sugerencia visible
## (poner el bloque encima funciona, pero ponerlo en otra celda
## también, porque la meta la decide level_logic.gd).
func _show_level_hints() -> void:
	_clear_hints()
	if not _level_mode:
		return
	if _hint_root == null:
		_hint_root = Node3D.new()
		_hint_root.name = "Hints"
		add_child(_hint_root)
	var tipo := String(_level_def.get("tipo", ""))
	var params: Dictionary = _level_def.get("params", {})
	for item in LevelHints.items_for_level(tipo, params, _level_target):
		var cell := Vector3i(int(item["x"]), 0, int(item["z"]))
		var tile := Node3D.new()
		tile.position = Vector3(cell) + Vector3(0.5, 0.03, 0.5)
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.92, 0.04, 0.92)
		mi.mesh = box
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var c: Color = item["color"]
		mat.albedo_color = Color(c.r, c.g, c.b, 0.55)
		mi.material_override = mat
		tile.add_child(mi)
		var texto := String(item.get("texto", ""))
		if texto != "":
			var label := Label3D.new()
			label.text = texto
			label.font_size = 160
			label.pixel_size = 0.0035
			label.modulate = NUMBER_TEXT_COLOR
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.position = Vector3(0.0, 0.35, 0.0)
			label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
			tile.add_child(label)
		_hint_root.add_child(tile)
	_hint_root.visible = true
	_hint_timer = 0.0


func _clear_hints() -> void:
	_hint_timer = 0.0
	if _hint_root == null:
		return
	for child in _hint_root.get_children():
		(child as Node).queue_free()
	_hint_root.visible = true


func _update_level_info() -> void:
	if _palette == null:
		return
	var mundo := LevelsData.get_mundo(GameState.mundo)
	var nombre := String(mundo.get("nombre", ""))
	var estrellas := ProgressSave.stars_for(_level_progress, GameState.mundo)
	_palette.set_info("%s · Nivel %d · ⭐ %d/5" % [nombre, GameState.nivel + 1, estrellas])


## Nivel superado: estrella, desbloqueo del siguiente, celebración con
## voz y cartel. OK (o el botón Menú) vuelve al menú de niveles.
func _complete_level() -> void:
	_level_completed = true
	_clear_hints()
	var nuevo := ProgressSave.mark_completed(_level_progress, GameState.mundo, GameState.nivel)
	if nuevo:
		ProgressSave.save_progress(_level_progress)
	_palette.show_celebration("¡Lo lograste! ⭐")
	_play_sound(_win_stream)
	var mundo_nombre := String(LevelsData.get_mundo(GameState.mundo).get("nombre", ""))
	if ProgressSave.stars_for(_level_progress, GameState.mundo) >= 5:
		speak("¡Muy bien! ¡Ganaste una estrella! ¡Completaste el mundo " + mundo_nombre + "! ¡Eres increíble!", "frase_mundo_completo")
	else:
		speak("¡Muy bien! ¡Ganaste una estrella!", "frase_muy_bien")
	# Fase 1: si el nivel era una palabra, su astro sale en el cielo.
	# Solo visual: el anuncio grande ya es la garantía sin TTS. Si la
	# palabra no es SOL ni LUNA, ambos cuerpos quedan ocultos.
	if String(_level_def.get("tipo", "")) == "palabra":
		var letras_palabra: Array = _level_def.get("params", {}).get("letras", [])
		var palabra := ""
		for li in letras_palabra:
			var idx := clampi(int(li), 0, LevelsData.LETRAS.size() - 1)
			palabra += String(LevelsData.LETRAS[idx])
		_set_sky_word(palabra)
		if palabra == "SOL":
			_palette.show_announcement("¡Salió el SOL! ☀️")
		elif palabra == "LUNA":
			_palette.show_announcement("¡Salió la LUNA! 🌙")
	_update_level_info()


## Fase 1: muestra el astro de la palabra en el cielo. SOL = sol visible,
## LUNA = luna visible; cualquier otra palabra oculta ambos. Solo visual:
## no usa micrófono, ni TTS, ni clips de audio.
func _set_sky_word(palabra: String) -> void:
	if _sun_body != null:
		_sun_body.visible = (palabra == "SOL")
	if _moon_body != null:
		_moon_body.visible = (palabra == "LUNA")


func _hide_sky_bodies() -> void:
	if _sun_body != null:
		_sun_body.visible = false
	if _moon_body != null:
		_moon_body.visible = false


## Vuelve al menú inicial. En juego libre guarda antes si hay cambios;
## en un nivel no hay nada que guardar (mundo.json queda intacto).
func _go_to_menu() -> void:
	_clear_hints()
	if not _level_mode and _dirty:
		_save_now()
	get_tree().change_scene_to_file("res://menu.tscn")


# ---------------------------------------------------------------------------
# Guardado
# ---------------------------------------------------------------------------

func _mark_dirty() -> void:
	_dirty = true
	_save_delay = SAVE_DELAY


func _save_now() -> void:
	# En modo nivel el mundo libre NO se guarda: el tablero del nivel es
	# temporal y mundo.json queda intacto.
	if _level_mode:
		_dirty = false
		return
	WorldSave.save_world(blocks)
	_dirty = false


func _load_world() -> void:
	var loaded := WorldSave.load_world()
	for cell in loaded.keys():
		if blocks.size() >= MAX_BLOCKS:
			break
		# 1.10.0: sin filtro de borde (el mundo es infinito): las
		# partidas viejas 16×16 cargan igual y las celdas más allá del
		# antiguo borde también valen. Solo se filtra la altura.
		if cell.y < 0 or cell.y >= MAX_HEIGHT:
			continue
		var data: Dictionary = loaded[cell]
		var tipo := String(data.get("tipo", "color"))
		var dato := int(data.get("dato", 0))
		if tipo == "numero":
			if dato < 1 or dato > 5:
				continue
		elif tipo == "color":
			if dato < 0 or dato >= BLOCK_COLORS.size():
				continue
		elif LIBRE_NAMES.has(tipo):
			# 1.3: agua, árbol, flor y piezas de casa (dato siempre 0).
			if dato != 0:
				continue
		else:
			continue
		var clean := {"tipo": tipo, "dato": dato}
		blocks[cell] = clean
		_spawn_block_node(cell, clean, false)
