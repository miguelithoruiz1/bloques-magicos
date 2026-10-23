extends Node3D
## Bloques Mágicos — Fase 1.
## Constructor de bloques 3D tipo Minecraft, simplificado y seguro para un
## niño de 5 años: cuadrícula 16×16, cursor con bloque fantasma, cubos de
## colores y de números, voz en español (TTS del sistema), sonidos generados
## en código y guardado automático. Sin red, sin anuncios, sin cuentas.
##
## La escena main.tscn es mínima: casi todo se construye aquí por código
## para mantener el proyecto robusto como archivos de texto.
## Decisiones técnicas (detalle en el README):
## - Una sola BoxMesh compartida y un material por color (rendimiento).
## - La selección táctil NO usa física: intersección rayo–caja calculada
##   a mano contra el diccionario de bloques (rápido y sin colisiones).
## - Los números de los cubos se dibujan con Label3D en las 5 caras visibles.

const PaletteUI := preload("res://scripts/palette_ui.gd")
const WorldSave := preload("res://scripts/world_save.gd")

const GRID_SIZE := 16
const MAX_HEIGHT := 8
const MAX_BLOCKS := 600
const SAVE_DELAY := 0.6

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

var blocks: Dictionary = {} ## Vector3i -> {"tipo": String, "dato": int}
var block_nodes: Dictionary = {} ## Vector3i -> Node3D
var cursor := Vector3i(8, 0, 8)
var selection: Dictionary = {"modo": "color", "dato": 0}

var _blocks_root: Node3D
var _box_mesh: BoxMesh
var _materials: Dictionary = {}
var _number_material: StandardMaterial3D

var _pivot: Node3D
var _camera: Camera3D
var _yaw_target := 0.0

var _ghost_root: Node3D
var _ghost_material: StandardMaterial3D
var _ghost_label: Label3D
var _ghost_state := ""

var _palette = null
var _move_timer := 0.0
var _dirty := false
var _save_delay := 0.0

var _audio_players: Array[AudioStreamPlayer] = []
var _audio_next := 0
var _pop_stream: AudioStream
var _toc_stream: AudioStream

var _tts_voice := ""

var _touching := false
var _touch_start := Vector2.ZERO
var _touch_dragged := false
var _mouse_down := false
var _mouse_start := Vector2.ZERO
var _mouse_dragged := false


func _ready() -> void:
	_build_shared()
	_build_environment()
	_build_ground()
	_build_trees()
	_build_camera()
	_build_ghost()
	_build_audio()
	_init_tts()
	_palette = PaletteUI.new()
	add_child(_palette)
	_palette.selection_changed.connect(_on_selection_changed)
	_palette.place_requested.connect(place_at_cursor)
	_palette.remove_requested.connect(remove_at_cursor)
	_palette.up_requested.connect(func() -> void: set_cursor_height(1))
	_palette.down_requested.connect(func() -> void: set_cursor_height(-1))
	_palette.world_reset.connect(_on_world_reset)
	_load_world()
	_update_info()
	_update_ghost(true)


func _process(delta: float) -> void:
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
	_pivot.rotation.y = lerp_angle(_pivot.rotation.y, _yaw_target, minf(1.0, delta * 10.0))

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
	if Input.is_action_just_pressed("place_block"):
		place_at_cursor()
	if Input.is_action_just_pressed("remove_block"):
		remove_at_cursor()
	if Input.is_action_just_pressed("cursor_up_level"):
		set_cursor_height(1)
	if Input.is_action_just_pressed("cursor_down_level"):
		set_cursor_height(-1)

	# La cámara sigue al cursor con suavidad.
	var target := Vector3(
		float(cursor.x) + 0.5,
		0.6 + float(cursor.y) * 0.35,
		float(cursor.z) + 0.5
	)
	_pivot.position = _pivot.position.lerp(target, minf(1.0, delta * 5.0))

	_update_ghost()

	# Autoguardado con pequeña espera para agrupar cambios seguidos.
	if _dirty:
		_save_delay -= delta
		if _save_delay <= 0.0:
			_save_now()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touching = true
			_touch_start = t.position
			_touch_dragged = false
		else:
			if _touching and not _touch_dragged:
				_handle_tap(t.position)
			_touching = false
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touching:
			if (d.position - _touch_start).length() > 26.0:
				_touch_dragged = true
			if _touch_dragged:
				_yaw_target -= d.relative.x * 0.01
	elif event is InputEventMouseButton:
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
			if (mm.position - _mouse_start).length() > 8.0:
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
	if String(selection.get("modo", "color")) == "borrador":
		remove_at_cursor()
		return
	if blocks.size() >= MAX_BLOCKS:
		_palette.show_message("¡Ya hay muchísimos bloques! Quita algunos para seguir construyendo.")
		return
	if blocks.has(cursor):
		_palette.show_message("Ahí ya hay un bloque.")
		return
	var data := {"tipo": "color", "dato": int(selection.get("dato", 0))}
	if String(selection.get("modo", "color")) == "numero":
		data = {"tipo": "numero", "dato": int(selection.get("dato", 1))}
	blocks[cursor] = data
	_spawn_block_node(cursor, data)
	_play_sound(_pop_stream)
	if String(data["tipo"]) == "numero":
		speak("¡" + NUMBER_NAMES[clampi(int(data["dato"]) - 1, 0, NUMBER_NAMES.size() - 1)] + "!")
	else:
		speak("¡" + String(BLOCK_COLORS[int(data["dato"])]["nombre"]) + "!")
	_mark_dirty()
	_update_info()
	_update_ghost(true)


func remove_at_cursor() -> void:
	var target := _remove_target()
	if target.x < 0:
		return
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
	cursor.x = clampi(cursor.x + step.x, 0, GRID_SIZE - 1)
	cursor.z = clampi(cursor.z + step.z, 0, GRID_SIZE - 1)
	_update_info()
	_update_ghost(true)


func _on_selection_changed(sel: Dictionary) -> void:
	selection = sel.duplicate()
	_update_ghost(true)


func _on_world_reset() -> void:
	for cell in block_nodes.keys():
		(block_nodes[cell] as Node).queue_free()
	block_nodes.clear()
	blocks.clear()
	cursor = Vector3i(8, 0, 8)
	_mark_dirty()
	_update_info()
	_update_ghost(true)
	_palette.show_message("¡Mundo nuevo! A construir.")
	speak("¡A construir!")


func _update_info() -> void:
	if _palette != null:
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
			if gc.x >= 0 and gc.x < GRID_SIZE and gc.z >= 0 and gc.z < GRID_SIZE:
				cursor = gc
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

func _spawn_block_node(cell: Vector3i, data: Dictionary) -> void:
	var root := Node3D.new()
	root.position = Vector3(cell) + Vector3(0.5, 0.5, 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh
	if String(data.get("tipo", "color")) == "numero":
		mi.material_override = _number_material
	else:
		mi.material_override = _materials[int(data.get("dato", 0))]
	root.add_child(mi)
	if String(data.get("tipo", "color")) == "numero":
		_add_number_labels(root, int(data.get("dato", 1)))
	_blocks_root.add_child(root)
	block_nodes[cell] = root


## El número se dibuja con Label3D en la cara superior y las 4 laterales,
## para que se vea desde cualquier ángulo de la cámara orbital.
func _add_number_labels(parent: Node3D, valor: int) -> void:
	var faces: Array = [
		[Vector3(0.0, 0.51, 0.0), Vector3(-90.0, 0.0, 0.0)],
		[Vector3(0.0, 0.0, 0.51), Vector3(0.0, 0.0, 0.0)],
		[Vector3(0.0, 0.0, -0.51), Vector3(0.0, 180.0, 0.0)],
		[Vector3(0.51, 0.0, 0.0), Vector3(0.0, 90.0, 0.0)],
		[Vector3(-0.51, 0.0, 0.0), Vector3(0.0, -90.0, 0.0)],
	]
	for face in faces:
		var label := Label3D.new()
		label.text = str(valor)
		label.font_size = 160
		label.pixel_size = 0.0035
		label.modulate = NUMBER_TEXT_COLOR
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = face[0]
		label.rotation_degrees = face[1]
		parent.add_child(label)


func _build_ghost() -> void:
	_ghost_root = Node3D.new()
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.albedo_color = Color(1.0, 1.0, 1.0, 0.45)
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh
	mi.material_override = _ghost_material
	_ghost_root.add_child(mi)
	_ghost_label = Label3D.new()
	_ghost_label.font_size = 160
	_ghost_label.pixel_size = 0.0035
	_ghost_label.modulate = NUMBER_TEXT_COLOR
	_ghost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ghost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ghost_label.position = Vector3(0.0, 0.56, 0.0)
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


func _build_ground() -> void:
	var apron := MeshInstance3D.new()
	var apron_mesh := PlaneMesh.new()
	apron_mesh.size = Vector2(80.0, 80.0)
	apron.mesh = apron_mesh
	apron.material_override = _make_material(Color(0.45, 0.68, 0.42))
	apron.position = Vector3(8.0, -0.05, 8.0)
	add_child(apron)

	var grid_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(float(GRID_SIZE), float(GRID_SIZE))
	grid_mi.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _make_ground_texture()
	mat.roughness = 1.0
	grid_mi.material_override = mat
	grid_mi.position = Vector3(GRID_SIZE * 0.5, 0.0, GRID_SIZE * 0.5)
	add_child(grid_mi)

	_blocks_root = Node3D.new()
	_blocks_root.name = "Blocks"
	add_child(_blocks_root)


## Textura de pradera a cuadros suaves, generada en código (sin archivos).
func _make_ground_texture() -> ImageTexture:
	var cell_px := 32
	var size := GRID_SIZE * cell_px
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var light := Color(0.56, 0.80, 0.47)
	var dark := Color(0.49, 0.74, 0.42)
	var line := Color(0.40, 0.64, 0.36)
	for cz in range(GRID_SIZE):
		for cx in range(GRID_SIZE):
			var base := light if (cx + cz) % 2 == 0 else dark
			img.fill_rect(Rect2i(cx * cell_px, cz * cell_px, cell_px, cell_px), base)
			img.fill_rect(Rect2i(cx * cell_px, cz * cell_px, cell_px, 2), line)
			img.fill_rect(Rect2i(cx * cell_px, cz * cell_px, 2, cell_px), line)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_trees() -> void:
	var trunk_mat := _make_material(Color(0.45, 0.32, 0.20))
	var leaf_mat := _make_material(Color(0.25, 0.60, 0.30))
	var spots: Array = [
		Vector2(-2.5, -2.0), Vector2(18.5, -1.5), Vector2(-2.0, 18.0),
		Vector2(18.0, 18.5), Vector2(4.0, -3.0), Vector2(12.0, 19.0),
		Vector2(-3.0, 7.0), Vector2(19.0, 10.0), Vector2(8.0, -3.5),
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


## Habla una frase corta. Si el dispositivo no tiene voces, no hace nada
## (el juego sigue funcionando sin error).
func speak(text: String) -> void:
	if _tts_voice == "":
		return
	DisplayServer.tts_speak(text, _tts_voice, 50, 1.0, 1.0, 0, true)


func _build_audio() -> void:
	_pop_stream = _make_tone(520.0, 160.0, 0.16, 0.5)
	_toc_stream = _make_tone(210.0, 140.0, 0.09, 0.45)
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
# Guardado
# ---------------------------------------------------------------------------

func _mark_dirty() -> void:
	_dirty = true
	_save_delay = SAVE_DELAY


func _save_now() -> void:
	WorldSave.save_world(blocks)
	_dirty = false


func _load_world() -> void:
	var loaded := WorldSave.load_world()
	for cell in loaded.keys():
		if blocks.size() >= MAX_BLOCKS:
			break
		if cell.x < 0 or cell.x >= GRID_SIZE or cell.z < 0 or cell.z >= GRID_SIZE:
			continue
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
		else:
			continue
		var clean := {"tipo": tipo, "dato": dato}
		blocks[cell] = clean
		_spawn_block_node(cell, clean)
