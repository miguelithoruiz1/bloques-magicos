extends Node3D
## Plaza / Hub de Bloques Mágicos (1.14.0): entrada principal del
## juego. Controles duales unificados con el mundo (1.13.0):
## joystick virtual abajo a la izquierda + arrastre en la mitad
## derecha para girar la vista (TouchControls reutilizable, misma
## lógica pura en InputController, sin duplicar joystick/cámara).
## Teclado: flechas + Enter. Mando: cruceta/joystick izquierdo +
## OK, igual que en la 1.13.0; con mando activo los controles
## táctiles se ocultan solos (TouchControls). Táctil: botones
## «Entrar» y «Ajustes» en pantalla, sin tapar por el joystick ni
## por el área de cámara (ver TouchControls, variante Plaza).
##
## La Plaza se mueve por pasos en rejilla (0,2 s / velocidad de
## caminar por paso) y el joystick ALIMENTA esa lógica, no la
## reemplaza por movimiento continuo: joystick mantenido hacia
## adelante = pasos repetidos hacia adelante; hacia atrás = pasos
## atrás; hacia los lados = giro continuo de la vista; al soltarlo,
## se detiene. El sprint del joystick (100% sostenido) acorta el
## tiempo entre pasos a 0.65×, como el paseo de main.gd.
##
## Yaw continuo (decisión 1.14.0, documentada): el yaw ya no es
## solo pasos de 45°. El arrastre derecho y el joystick lateral
## lo giran de forma continua y suave; la dirección de avance se
## cuantiza a los 4 rumbos de la rejilla a partir de ese yaw
## (InputController.hub_forward_step), así que pasos y vista
## siempre son coherentes. La cámara sigue al avatar y mira al
## avatar (look_at a su cabeza); su dirección es horizontal, con
## altura 1.5 (1ª persona) o 3.2 (2ª persona) sobre el suelo, así
## que nunca mira al vacío ni atraviesa el suelo. Los giros de
## 45° del mando/teclado (move_left/move_right) se conservan
## encima de este yaw continuo.
## OK corto entra al portal que está delante, OK largo abre
## Ajustes. No se toca ningún mundo, nivel ni guardado libre:
## solo se lee progreso.json para las estrellas y los candados, y
## se pasa a main.tscn con GameState como siempre.
##
## Portales (8): Jugar libre, Ciudad libre, Espacio libre,
## Colores, Números, Letras, Sumas y Ajustes (la casa).
## Un portal de mundo de enseñanza entra a su siguiente nivel
## pendiente (el primero sin estrella; si están todos, el último
## para rejugar). Un portal bloqueado se ve gris, con candado,
## y OK no lo abre: la regla es ProgressSave.is_unlocked sobre
## ese siguiente nivel (ver settings_save.gd).

const LevelsData := preload("res://scripts/levels_data.gd")
const ProgressSave := preload("res://scripts/progress_save.gd")
const SettingsSave := preload("res://scripts/settings_save.gd")
const AudioBank := preload("res://scripts/audio_bank.gd")
const InputController := preload("res://scripts/input_controller.gd")
const TouchControlsScene := preload("res://touch_controls.tscn")

const OK_HOLD_SECONDS := 0.35

var _progreso: Dictionary = {}
var _ajustes: Dictionary = {}
var _portales: Array = []
var _celda := Vector2i(0, 0)
var _yaw := 0.0
var _move_timer := 0.0
var _pet_celda := Vector2i(2, 2)
var _pet_timer := 0.0
var _ok_prev_down := false
var _ok_hold_time := 0.0
var _ok_long_fired := false

var _camera: Camera3D
var _avatar: Node3D
var _pet: Node3D
var _titulo_label: Label
var _info_label: Label
var _mensaje_label: Label
var _audio_bank = null
var _tts_voice := ""
## 1.14.0: controles duales reutilizados del mundo.
var _touch_controls = null
var _input_ctrl = null


func _ready() -> void:
	_ajustes = SettingsSave.load_settings()
	_progreso = ProgressSave.load_progress()
	_build_environment()
	_build_portales()
	_build_avatar()
	_build_pet()
	_build_hud()
	_build_touch_controls()
	_audio_bank = AudioBank.new()
	add_child(_audio_bank)
	_init_tts()
	_update_hud()


func _build_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.53, 0.78, 0.95)
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.position = Vector3(5.0, 10.0, 5.0)
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sun)
	var suelo := MeshInstance3D.new()
	var suelo_mesh := BoxMesh.new()
	suelo_mesh.size = Vector3(24.0, 0.2, 18.0)
	suelo.mesh = suelo_mesh
	suelo.material_override = _make_material(Color(0.35, 0.75, 0.40))
	suelo.position = Vector3(0.0, -0.1, 0.0)
	add_child(suelo)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.far = 150.0
	_camera.current = true
	add_child(_camera)


func _make_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _make_box(size: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = _make_material(color)
	return n


func _build_portales() -> void:
	var defs: Array = [
		{"id": "libre", "nombre": "Jugar libre", "color": Color(0.30, 0.75, 0.35), "tipo": "libre"},
		{"id": "ciudad", "nombre": "Ciudad libre", "color": Color(0.45, 0.60, 0.85), "tipo": "libre"},
		{"id": "espacio", "nombre": "Espacio libre", "color": Color(0.25, 0.25, 0.60), "tipo": "libre"},
		{"id": "colores", "nombre": "Colores", "color": Color(0.90, 0.25, 0.22), "tipo": "mundo"},
		{"id": "numeros", "nombre": "Números", "color": Color(0.98, 0.80, 0.15), "tipo": "mundo"},
		{"id": "letras", "nombre": "Letras", "color": Color(0.60, 0.35, 0.90), "tipo": "mundo"},
		{"id": "sumas", "nombre": "Sumas", "color": Color(0.98, 0.55, 0.15), "tipo": "mundo"},
		{"id": "ajustes", "nombre": "Ajustes", "color": Color(0.55, 0.38, 0.22), "tipo": "ajustes"},
	]
	var posiciones: Array = [
		Vector2i(-6, -4), Vector2i(-2, -4), Vector2i(2, -4), Vector2i(6, -4),
		Vector2i(-6, 4), Vector2i(-2, 4), Vector2i(2, 4), Vector2i(6, 4),
	]
	for i in range(defs.size()):
		var d: Dictionary = defs[i]
		var pos: Vector2i = posiciones[i]
		var bloqueado := false
		var texto := String(d["nombre"])
		if String(d["tipo"]) == "mundo":
			var mundo := String(d["id"])
			var estrellas := ProgressSave.stars_for(_progreso, mundo)
			var total := LevelsData.get_niveles(mundo).size()
			var siguiente := SettingsSave.next_pending_level(_progreso, mundo) + 1
			texto += "\n⭐ %d/%d · Nivel %d" % [estrellas, total, siguiente]
			bloqueado = SettingsSave.portal_locked(_progreso, mundo)
			if bloqueado:
				texto += "\n🔒 Cerrado"
		elif String(d["tipo"]) == "libre":
			texto += "\nLibre"
		else:
			texto += "\n🏠"
		var color: Color = d["color"] if not bloqueado else Color(0.55, 0.55, 0.58)
		var portal := Node3D.new()
		portal.position = Vector3(float(pos.x) + 0.5, 0.0, float(pos.y) + 0.5)
		for sx in [-0.9, 0.9]:
			var pilar := _make_box(Vector3(0.35, 2.4, 0.35), color)
			pilar.position = Vector3(sx, 1.2, 0.0)
			portal.add_child(pilar)
		var dintel := _make_box(Vector3(2.2, 0.4, 0.4), color)
		dintel.position = Vector3(0.0, 2.5, 0.0)
		portal.add_child(dintel)
		var etiqueta := Label3D.new()
		etiqueta.text = texto
		etiqueta.font_size = 64
		etiqueta.pixel_size = 0.02
		etiqueta.position = Vector3(0.0, 3.4, 0.0)
		portal.add_child(etiqueta)
		add_child(portal)
		_portales.append({"def": d, "celda": pos, "bloqueado": bloqueado, "texto": texto})


func _build_avatar() -> void:
	_avatar = Node3D.new()
	var cuerpo := _make_box(Vector3(0.55, 0.7, 0.35), Color(0.20, 0.55, 0.95))
	cuerpo.position = Vector3(0.0, 0.55, 0.0)
	_avatar.add_child(cuerpo)
	var cabeza := _make_box(Vector3(0.45, 0.45, 0.45), Color(1.0, 0.85, 0.65))
	cabeza.position = Vector3(0.0, 1.12, 0.0)
	_avatar.add_child(cabeza)
	for sx in [-0.11, 0.11]:
		var ojo := _make_box(Vector3(0.07, 0.09, 0.02), Color(0.05, 0.05, 0.10))
		ojo.position = Vector3(sx, 1.15, -0.24)
		_avatar.add_child(ojo)
	add_child(_avatar)


func _build_pet() -> void:
	_pet = Node3D.new()
	var cuerpo := _make_box(Vector3(0.5, 0.3, 0.35), Color(0.65, 0.45, 0.25))
	cuerpo.position = Vector3(0.0, 0.25, 0.0)
	_pet.add_child(cuerpo)
	var cabeza := _make_box(Vector3(0.3, 0.3, 0.3), Color(0.65, 0.45, 0.25))
	cabeza.position = Vector3(0.0, 0.45, -0.25)
	_pet.add_child(cabeza)
	add_child(_pet)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 96)
	margen.add_theme_constant_override("margin_right", 96)
	margen.add_theme_constant_override("margin_top", 96)
	margen.add_theme_constant_override("margin_bottom", 96)
	root.add_child(margen)
	var vbox := VBoxContainer.new()
	margen.add_child(vbox)
	_titulo_label = Label.new()
	_titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo_label.add_theme_font_size_override("font_size", int(44 * float(_ajustes.get("texto", 1.0))))
	_titulo_label.add_theme_color_override("font_color", Color.WHITE)
	_titulo_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	_titulo_label.add_theme_constant_override("shadow_offset_x", 2)
	_titulo_label.add_theme_constant_override("shadow_offset_y", 2)
	_titulo_label.text = "Plaza · Bloques Mágicos"
	vbox.add_child(_titulo_label)
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.add_theme_font_size_override("font_size", int(26 * float(_ajustes.get("texto", 1.0))))
	_info_label.add_theme_color_override("font_color", Color.WHITE)
	_info_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	_info_label.add_theme_constant_override("shadow_offset_x", 2)
	_info_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_info_label)
	_mensaje_label = Label.new()
	_mensaje_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje_label.add_theme_font_size_override("font_size", int(24 * float(_ajustes.get("texto", 1.0))))
	_mensaje_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.60))
	_mensaje_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	_mensaje_label.add_theme_constant_override("shadow_offset_x", 2)
	_mensaje_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_mensaje_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 24)
	vbox.add_child(botones)
	for par in [["Entrar", _entrar_cercano], ["Ajustes", _ir_ajustes]]:
		var b := Button.new()
		b.text = String(par[0])
		b.custom_minimum_size = Vector2(240, 84)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", int(28 * float(_ajustes.get("texto", 1.0))))
		b.pressed.connect(par[1])
		botones.add_child(b)


func _build_touch_controls() -> void:
	# 1.14.0: adiós a la cruceta ▲▼◀▶. La Plaza usa la misma
	# escena TouchControls del mundo (joystick abajo a la
	# izquierda + arrastre en la mitad derecha), con la variante
	# Plaza: sin tap/hold (aquí no se coloca nada) y con el área
	# de cámara terminando 200 px antes del borde inferior, por
	# encima de los botones «Entrar» / «Ajustes» (180 px). El
	# joystick queda a 190 px del borde, también por encima de
	# esa fila, y no tapa los botones (están centrados, en otra
	# franja vertical). Con mando conectado, TouchControls se
	# oculta sola y el mando sigue mandando por las acciones
	# move_*/place_block, igual que en la 1.13.0.
	_input_ctrl = InputController.new()
	_touch_controls = TouchControlsScene.instantiate()
	_touch_controls.enable_interact = false
	_touch_controls.camera_bottom_offset = -200.0
	add_child(_touch_controls)


func _hint_texto() -> String:
	match String(_ajustes.get("control", "tv")):
		"tactil":
			return "Joystick: caminar y girar · Arrastra a la derecha: girar la vista · Entrar: portal cercano · Ajustes: ajustes"
		"teclado":
			return "Flechas: caminar y girar · Enter: entrar · Atrás: Ajustes"
		_:
			return "Cruceta: ▲ avanza · ▼ retrocede · ◀ ▶ gira · OK: entrar · Mantén OK: Ajustes"


func _portal_cercano() -> Dictionary:
	var mejor: Dictionary = {}
	var mejor_dist := 999.0
	for p in _portales:
		var celda: Vector2i = p["celda"]
		var dist := float(abs(celda.x - _celda.x) + abs(celda.y - _celda.y))
		if dist < mejor_dist:
			mejor_dist = dist
			mejor = p
	return mejor


func _update_hud() -> void:
	if _info_label == null:
		return
	_info_label.text = _hint_texto()
	var p := _portal_cercano()
	if p.is_empty():
		_mensaje_label.text = ""
		return
	var d: Dictionary = p["def"]
	var celda_p: Vector2i = p["celda"]
	var dist: int = absi(celda_p.x - _celda.x) + absi(celda_p.y - _celda.y)
	if bool(p["bloqueado"]):
		_mensaje_label.text = "%s · 🔒 Cerrado: termina el nivel anterior" % String(d["nombre"])
	else:
		_mensaje_label.text = "%s · a %d pasos · OK para entrar" % [String(p["texto"]).replace("\n", " · "), dist]


func _update_avatar_camera(delta: float) -> void:
	# 1.14.0: _yaw ya es continuo (arrastre/joystick lateral), y
	# esta cámara lo sigue tal cual: mira siempre a la cabeza del
	# avatar (look_at), con dirección horizontal y altura 1.5
	# (1ª persona) o 3.2 (2ª persona) sobre el suelo: nunca mira
	# al vacío ni atraviesa el suelo.
	var pos := Vector3(float(_celda.x) + 0.5, 0.0, float(_celda.y) + 0.5)
	_avatar.position = pos
	_avatar.rotation.y = _yaw
	_avatar.visible = (int(_ajustes.get("vista", 0)) == 1)
	var dir := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var cam_target := pos - dir * 4.5 + Vector3(0.0, 3.2, 0.0)
	if int(_ajustes.get("vista", 0)) == 0:
		cam_target = pos + Vector3(0.0, 1.5, 0.0) + dir * 0.5
	var factor := 1.0 if bool(_ajustes.get("menos_movimiento", false)) else minf(1.0, delta * 8.0)
	_camera.position = _camera.position.lerp(cam_target, factor)
	_camera.look_at(pos + Vector3(0.0, 1.2, 0.0), Vector3.UP)
	_pet.position = Vector3(float(_pet_celda.x) + 0.5, 0.0, float(_pet_celda.y) + 0.5)


func _process(delta: float) -> void:
	var ok_event := _poll_ok(delta)
	if ok_event == "short":
		_entrar_delante()
	elif ok_event == "long":
		_ir_ajustes()
		return
	# 1.14.0: cámara por arrastre derecho (TouchControls). La
	# sensibilidad de Ajustes ya viene aplicada dentro de
	# TouchControls (su _sens_cache lee sensibilidad_camara);
	# aquí solo se aplica el factor 0.5 de menos_movimiento, como
	# hace main.gd, sin duplicar la sensibilidad. La Plaza no
	# tiene pitch: ese delta se descarta. Al consumir los deltas
	# se ponen a cero, igual que en main.gd.
	if _touch_controls != null and _touch_controls.visible:
		var move_factor := 0.5 if bool(_ajustes.get("menos_movimiento", false)) else 1.0
		_yaw += _touch_controls.camera_yaw_delta * move_factor
		_touch_controls.camera_yaw_delta = 0.0
		_touch_controls.camera_pitch_delta = 0.0
	# Giros de 45° del mando/teclado: se conservan encima del yaw
	# continuo, igual que en la 1.13.0.
	if Input.is_action_just_pressed("move_left"):
		_yaw += deg_to_rad(45.0)
	elif Input.is_action_just_pressed("move_right"):
		_yaw -= deg_to_rad(45.0)
	# 1.14.0: joystick táctil (mismo vector que el mundo). Eje
	# dominante manda: adelante/atrás = pasos repetidos, lados =
	# giro continuo. Al soltar, move_vector vuelve a cero y todo
	# se detiene (el temporizador se resetea abajo).
	var joy := Vector2.ZERO
	if _touch_controls != null and _touch_controls.visible:
		joy = _touch_controls.move_vector
	var sprinting := false
	if _input_ctrl != null:
		sprinting = _input_ctrl.update_sprint(joy.length(), delta)
	var joy_fb := 0
	if joy.length() >= InputController.DEADZONE and absf(joy.y) > absf(joy.x):
		joy_fb = 1 if joy.y > 0.0 else -1
	elif joy.length() >= InputController.DEADZONE:
		# Lateral dominante: giro continuo, a la derecha resta
		# yaw (igual que move_right), escalado por «giro».
		_yaw -= joy.x * InputController.hub_turn_rate(float(_ajustes.get("giro", 1.0))) * delta
	var fb := 0
	if Input.is_action_pressed("move_forward"):
		fb += 1
	if Input.is_action_pressed("move_back"):
		fb -= 1
	if fb == 0:
		fb = joy_fb
	if fb != 0:
		_move_timer -= delta
		if _move_timer <= 0.0:
			_paso(fb)
			# Sprint solo cuando el paso viene del joystick: el
			# camino de teclado/mando conserva su intervalo.
			_move_timer = InputController.hub_step_interval(float(_ajustes.get("caminar", 1.0)), sprinting and joy_fb != 0)
	else:
		_move_timer = 0.0
	_pet_timer -= delta
	if _pet_timer <= 0.0:
		_pet_timer = 0.4
		_paso_mascota()
	_update_avatar_camera(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE and k.pressed and not k.echo:
			_ir_ajustes()


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


func _paso(dir: int) -> void:
	# 1.14.0: la dirección de avance se cuantiza desde el yaw
	# continuo (InputController.hub_forward_step, única fuente);
	# con yaw en pasos de 45° da exactamente lo mismo que antes.
	var paso := InputController.hub_forward_step(_yaw)
	var siguiente := _celda + paso * dir
	siguiente.x = clampi(siguiente.x, -11, 11)
	siguiente.y = clampi(siguiente.y, -8, 8)
	_celda = siguiente


func _paso_mascota() -> void:
	var dx := _celda.x - _pet_celda.x
	var dy := _celda.y - _pet_celda.y
	if abs(dx) + abs(dy) <= 1:
		return
	if abs(dx) >= abs(dy):
		_pet_celda.x += 1 if dx > 0 else -1
	else:
		_pet_celda.y += 1 if dy > 0 else -1


func _entrar_delante() -> void:
	var p := _portal_cercano()
	if p.is_empty():
		return
	var celda_p: Vector2i = p["celda"]
	var dist: int = absi(celda_p.x - _celda.x) + absi(celda_p.y - _celda.y)
	if dist > 4:
		_mensaje_label.text = "Acércate más al portal para entrar"
		return
	_entrar_portal(p)


func _entrar_cercano() -> void:
	_entrar_delante()


func _entrar_portal(p: Dictionary) -> void:
	if bool(p["bloqueado"]):
		_mensaje_label.text = "Ese portal está cerrado: termina el nivel anterior"
		return
	var d: Dictionary = p["def"]
	var tipo := String(d["tipo"])
	if tipo == "ajustes":
		_ir_ajustes()
		return
	if tipo == "libre":
		GameState.modo = "libre"
		GameState.mundo = String(d["id"]) if String(d["id"]) != "libre" else ""
		GameState.nivel = 0
	else:
		GameState.modo = "nivel"
		GameState.mundo = String(d["id"])
		GameState.nivel = SettingsSave.next_pending_level(_progreso, String(d["id"]))
	get_tree().change_scene_to_file("res://main.tscn")


func _ir_ajustes() -> void:
	get_tree().change_scene_to_file("res://settings.tscn")


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


func speak(text: String, clip := "") -> void:
	if clip != "" and _audio_bank != null and _audio_bank.play_clip(clip):
		return
	if _tts_voice == "":
		return
	DisplayServer.tts_speak(text, _tts_voice, int(50 * float(_ajustes.get("volumen_voces", 1.0))), 1.0, 1.0, 0, true)
