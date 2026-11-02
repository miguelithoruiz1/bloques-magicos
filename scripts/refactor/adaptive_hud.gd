extends CanvasLayer
## 02 — AdaptiveHUD: HUD minimalista por perfil + limpieza de telemetría.
##
## Sustituye, en el mundo voxel principal, la barra superior y las
## columnas de acciones de UIController (3.0.2). NO es un HUD
## completo de juego: los paneles modales (taller, misiones,
## estaciones, personaje, LAN) siguen viviendo detrás del botón
## de pausa en la escena principal, hasta la fase 2 de migración.
## Lo que sí hace, completo, es lo que pide el encargo:
##  - Esquinas, no fila invasiva: arriba-izquierda pausa y cámara;
##    arriba-derecha solo telemetría si modo desarrollador.
##  - Explorador: joystick + 3 botones gigantes (poner, quitar,
##    saltar). Nada de stats, nada de "Primeros pasos".
##  - Constructor / Maestro: hotbar de 9 + acciones con iconos.
##  - Telemetría (FPS, zona, clima, vitales) OCULTA por defecto.
##    Solo se muestra si personaje.json tiene modo_desarrollador.
##  - Prompts contextuales por dispositivo. En táctil y en TV
##    NUNCA aparecen textos de PC ("clic izquierdo", "Mayús",
##    "ratón"). Esos textos solo existen en el caso "teclado".
##  - TV: todos los botones con foco (FOCUS_ALL) y el primero
##    con grab_focus(), para D-Pad + OK. Táctil: botones grandes
##    con mouse_filter STOP, sin depender del foco.
##
## Señales (mismo nombre que UIController para reconectar
## RefactorMain sin renombrar lógica de juego):
##   place_pressed, remove_pressed, jump_pressed,
##   pause_pressed, perspective_pressed, block_selected.

class_name AdaptiveHUD

signal place_pressed
signal remove_pressed
signal jump_pressed
signal pause_pressed
signal perspective_pressed
signal block_selected(block_id: int)

enum Device { TOUCH, TV, KEYBOARD }

const HOTBAR_SLOTS := 9
const GIANT_SIZE := Vector2(96, 96)
const NORMAL_SIZE := Vector2(64, 64)

var profile: CognitiveProfile = null
var device: int = Device.TOUCH
var developer_mode := false

var _root: Control = null
var _telemetry: Label = null
var _vitals: Label = null
var _prompt: Label = null
var _first_steps: Control = null
var _hotbar_buttons: Array[Button] = []
var _giant_buttons: Array[Button] = []
var _action_buttons: Array[Button] = []
var _first_focus: Button = null
var _top_left: HBoxContainer = null

# Hotbar inicial: colores + números + letra, como la 3.0.2.
# IDs reales del generador: 10-21 colores, 31 = "1", 50 = "A".
var hotbar: Array[int] = [10, 11, 12, 13, 14, 15, 31, 32, 50]
var selected_slot := 0


func _ready() -> void:
	layer = 10
	if profile == null:
		profile = CognitiveProfile.load_or_create()
	developer_mode = profile.developer_mode
	_build_ui()
	apply_profile()
	_set_device_prompt()


func setup(p: CognitiveProfile, dev: int) -> void:
	profile = p
	device = dev
	developer_mode = p.developer_mode
	if _root != null:
		apply_profile()
		_set_device_prompt()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Esquina superior izquierda: pausa + cámara. Solo 2 iconos.
	var top_left := HBoxContainer.new()
	top_left.name = "TopLeft"
	_top_left = top_left
	top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_left.position = Vector2(12, 12)
	top_left.add_theme_constant_override("separation", 10)
	_root.add_child(top_left)
	var pause_btn := _make_button("⏸", func(): pause_pressed.emit())
	_action_buttons.append(pause_btn)
	top_left.add_child(pause_btn)
	var cam_btn := _make_button("📷", func(): perspective_pressed.emit())
	_action_buttons.append(cam_btn)
	top_left.add_child(cam_btn)
	_first_focus = pause_btn

	# Esquina superior derecha: telemetría. Existe, pero oculta
	# por defecto. Solo el interruptor de OPCIONES la enciende.
	_telemetry = Label.new()
	_telemetry.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_telemetry.position = Vector2(-420, 12)
	_telemetry.size = Vector2(400, 30)
	_telemetry.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_telemetry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_telemetry.visible = false
	_root.add_child(_telemetry)

	# Vitales: segunda línea, misma regla que telemetría.
	_vitals = Label.new()
	_vitals.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vitals.position = Vector2(-420, 44)
	_vitals.size = Vector2(400, 30)
	_vitals.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals.visible = false
	_root.add_child(_vitals)

	# Panel "Primeros pasos": existe para perfiles grandes,
	# pero en Explorador se oculta entero (ver apply_profile).
	_first_steps = _build_first_steps_panel()
	_root.add_child(_first_steps)

	# Prompt contextual inferior (encima de la hotbar).
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_prompt.offset_top = -118.0
	_prompt.offset_bottom = -88.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt)

	# Hotbar inferior centrada (Constructor / Maestro).
	var hotbar_row := HBoxContainer.new()
	hotbar_row.name = "HotbarRow"
	hotbar_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hotbar_row.offset_top = -80.0
	hotbar_row.offset_bottom = -8.0
	hotbar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_row.add_theme_constant_override("separation", 6)
	_root.add_child(hotbar_row)
	for i in range(HOTBAR_SLOTS):
		var slot := Button.new()
		slot.custom_minimum_size = NORMAL_SIZE
		slot.text = _slot_label(i)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slot.focus_mode = Control.FOCUS_ALL
		_hotbar_buttons.append(slot)
		hotbar_row.add_child(slot)

	# 3 botones gigantes (Explorador): poner, quitar, saltar.
	var giant_row := HBoxContainer.new()
	giant_row.name = "GiantRow"
	giant_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	giant_row.position = Vector2(-320, -116)
	giant_row.size = Vector2(308, 96)
	giant_row.add_theme_constant_override("separation", 10)
	_root.add_child(giant_row)
	var place_btn := _make_button("＋", func(): place_pressed.emit(), GIANT_SIZE)
	var remove_btn := _make_button("－", func(): remove_pressed.emit(), GIANT_SIZE)
	var jump_btn := _make_button("⬆", func(): jump_pressed.emit(), GIANT_SIZE)
	_giant_buttons = [place_btn, remove_btn, jump_btn]
	for b in _giant_buttons:
		giant_row.add_child(b)


func _make_button(text: String, callback: Callable, size: Vector2 = NORMAL_SIZE) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(callback)
	return b


func _build_first_steps_panel() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(12, 84)
	panel.size = Vector2(280, 44)
	var label := Label.new()
	label.text = "Primeros pasos"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return panel


func _slot_label(i: int) -> String:
	# Etiquetas cortas, sin depender de UIController.
	# 10-21 colores, 31-39 números, 50-76 letras.
	var block_id: int = hotbar[i]
	if block_id >= 10 and block_id <= 21:
		var names := ["Rojo", "Azul", "Amarillo", "Verde", "Naranja",
			"Morado", "Rosado", "Café", "Negro", "Blanco", "Gris", "Celeste"]
		return names[block_id - 10]
	if block_id >= 30 and block_id <= 39:
		return str(block_id - 30)
	if block_id >= 50 and block_id <= 76:
		var letters := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
			"K", "L", "M", "N", "Ñ", "O", "P", "Q", "R", "S", "T", "U",
			"V", "W", "X", "Y", "Z"]
		return letters[block_id - 50]
	return "■"


func set_hud_rows_visible(show: bool) -> void:
	# 4.0: UIController keeps the joystick, hotbar and action
	# columns, so these AdaptiveHUD rows stay hidden to avoid
	# two hotbars / two pause buttons on top of each other.
	# Telemetry, vitals, prompt and first-steps gating below
	# stay active. Full visual replacement is a later step
	# once AdaptiveHUD gains a joystick and the modal panels.
	if _top_left != null:
		_top_left.visible = show
	if _root != null:
		var hotbar_row := _root.get_node_or_null("HotbarRow")
		if hotbar_row != null:
			hotbar_row.visible = show
		var giant_row := _root.get_node_or_null("GiantRow")
		if giant_row != null:
			giant_row.visible = show


func apply_profile() -> void:
	if profile == null or _root == null:
		return
	var explorer := profile.is_explorer()
	# Hotbar completa solo fuera de Explorador.
	var hotbar_row := _root.get_node_or_null("HotbarRow")
	if hotbar_row != null:
		hotbar_row.visible = not explorer
	var giant_row := _root.get_node_or_null("GiantRow")
	if giant_row != null:
		giant_row.visible = explorer
	# Stats complejas y panel de texto: ocultos en Explorador.
	if _first_steps != null:
		_first_steps.visible = profile.show_first_steps_panel()
	# Telemetría: manda el interruptor, no el perfil.
	_apply_telemetry_visibility()
	# En TV, el foco arranca en Pausa para D-Pad + OK.
	if device == Device.TV and _first_focus != null:
		_first_focus.grab_focus()


func _apply_telemetry_visibility() -> void:
	# Regla única y explícita: sin modo desarrollador,
	# telemetría y vitales NO se ven, aunque set_stats()
	# siga recibiendo texto. Así ningún cambio futuro
	# en RefactorMain vuelve a exponer FPS por accidente.
	var show := developer_mode
	if _telemetry != null:
		_telemetry.visible = show
	if _vitals != null:
		_vitals.visible = show


func set_developer_mode(enabled: bool) -> void:
	developer_mode = enabled
	if profile != null:
		profile.developer_mode = enabled
		profile.save()
	_apply_telemetry_visibility()


func set_stats(text: String) -> void:
	# Se guarda el texto aunque esté oculto: al activar
	# modo desarrollador aparece sin esperar al siguiente
	# tick de 0.5 s de RefactorMain.
	if _telemetry != null:
		_telemetry.text = text
	_apply_telemetry_visibility()


func set_vitals(health: float, mana: float, stamina: float, oxygen: float, temperature: float) -> void:
	if profile != null and not profile.show_complex_stats():
		# Explorador: no se muestra nada de esto. No se
		# "oculta con otro texto": simplemente no se dibuja.
		if _vitals != null:
			_vitals.text = ""
		return
	if _vitals != null:
		_vitals.text = "♥ %.0f · ✦ %.0f · ⚡ %.0f" % [health, mana, stamina]
	_apply_telemetry_visibility()


func set_device(new_device: int) -> void:
	device = new_device
	_set_device_prompt()
	apply_profile()


func _set_device_prompt() -> void:
	if _prompt == null:
		return
	match device:
		Device.TOUCH:
			_prompt.text = "Toca para poner un bloque · Mantén para quitarlo · Arrastra para girar"
		Device.TV:
			_prompt.text = "Cruceta: moverte · OK: poner · Atrás: pausa"
		_:
			# SOLO en teclado/PC aparecen textos de PC.
			_prompt.text = "Clic izquierdo: poner · Clic derecho: quitar · Mayús: correr"


func prompt_for_device(dev: int) -> String:
	match dev:
		Device.TOUCH:
			return "Toca para poner un bloque · Mantén para quitarlo · Arrastra para girar"
		Device.TV:
			return "Cruceta: moverte · OK: poner · Atrás: pausa"
		_:
			return "Clic izquierdo: poner · Clic derecho: quitar · Mayús: correr"


func _on_slot_pressed(i: int) -> void:
	selected_slot = i
	for j in range(_hotbar_buttons.size()):
		_hotbar_buttons[j].button_pressed = (j == i)
	block_selected.emit(hotbar[i])


func selected_block_id() -> int:
	if profile != null and profile.is_explorer():
		return hotbar[0]
	return hotbar[selected_slot]


func _input(event: InputEvent) -> void:
	# Auto-switch por evento real, como ya hace UIController
	# en 3.0.2: no se adivina el dispositivo, se detecta.
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if device != Device.TV:
			set_device(Device.TV)
	elif event is InputEventScreenTouch:
		if device != Device.TOUCH:
			set_device(Device.TOUCH)
