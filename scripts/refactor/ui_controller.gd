extends CanvasLayer
## UIController — HUD estilo Minecraft Bedrock (TouchAndTVControls).
##
## Corrige el HUD de 1.15.0 sin tocarlo: 1.15.0 sigue intacto en
## main.tscn / touch_controls.tscn. Este HUD es la variante nueva
## y vive solo en scenes/refactor_main.tscn.
##
## Lo que desaparece en el HUD NUEVO (no se borra del juego viejo):
## - El cuadro amarillo gigante de la esquina superior izquierda
##   (era el dock de la paleta de 1.15.0, que tapaba la vista).
## - La cruceta azul flotante y el teclado gigante permanente de
##   letras/colores/números: ahora hay una Hotbar de 9 slots y un
##   inventario MODAL por pestañas, que se cierra al elegir.
## - Los textos largos de instrucciones: ahora una barra superior
##   minimalista (pausa, cámara, progreso/estrellas).
##
## Orden de entrada (la lección de 1.14.0/1.15.0): el área de
## arrastre de cámara ocupa TODA la pantalla y se añade PRIMERO;
## los botones se añaden DESPUÉS y con mouse_filter STOP, así que
## los botones ganan siempre al área. En 1.15.0 el área tuvo que
## encogerse a 120 px de alto (210..330 a 720p) para no tapar
## botones; aquí no hace falta encogerla.
##
## Auto-switch TV/móvil: cualquier InputEventJoypadButton o
## InputEventJoypadMotion pone tv_mode (oculta joystick y botones
## táctiles, deja hotbar + crosshair + sugerencias); cualquier
## InputEventScreenTouch vuelve a modo táctil. El cambio es por
## evento real, no por adivinar el dispositivo.
##
## Vector de entrada: x = derecha (+), y = adelante (+). El
## joystick convierte la Y de pantalla UNA sola vez aquí
## (offset.y negado): PlayerBlocky ya no invierte nada.

class_name UIController

signal camera_dragged(relative: Vector2)
signal move_input_changed(input: Vector2)
signal jump_pressed
signal crouch_pressed
signal crouch_released
signal place_pressed
signal remove_pressed
signal perspective_pressed
signal pause_pressed
signal camera_tapped
signal block_selected(block_id: int)
signal inventory_opened
signal inventory_closed

const HOTBAR_SLOTS := 9
const JOY_RADIUS := 110.0
const SPRINT_MAGNITUDE := 0.98
const SPRINT_HOLD_SECONDS := 0.30

# Bloques del inventario por pestaña. id: ver VoxelWorldGenerator
# (10..21 colores, 30..38 números, 40..43 operadores, 50..76 letras,
# 4 madera, 5 hojas, 7 arena, 8/9 flores, 80 antorcha).
const TABS := [
	{"name": "Colores", "blocks": [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]},
	{"name": "Números y Operadores", "blocks": [31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43]},
	{"name": "Letras y Fonética", "blocks": [50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76]},
	{"name": "Naturaleza y Decoración", "blocks": [4, 5, 7, 8, 9, 80]},
	{"name": "Construcción", "blocks": [84, 85, 86, 87, 88]},
	{"name": "Lógica Viva", "blocks": [31, 32, 33, 40, 41, 42, 43]},
]
const BLOCK_NAMES := {
	10: "Rojo", 11: "Azul", 12: "Amarillo", 13: "Verde", 14: "Naranja",
	15: "Morado", 16: "Rosado", 17: "Café", 18: "Negro", 19: "Blanco",
	20: "Gris", 21: "Celeste", 40: "+", 41: "-", 42: "×", 43: "=",
	4: "Madera", 5: "Hojas", 7: "Arena", 8: "Flor roja", 9: "Flor amarilla",
	80: "Antorcha", 84: "Tablones", 85: "Ladrillo", 86: "Vidrio",
	87: "Nieve", 88: "Cristal brillo",
}

var move_vector := Vector2.ZERO
var sprinting := false
var tv_mode := false
var selected_slot := 0
var hotbar: Array[int] = [10, 11, 12, 13, 14, 15, 31, 32, 50]
var settings: Dictionary = {}

var _joy_base: Control = null
var _joy_knob: Control = null
var _joy_center := Vector2.ZERO
var _joy_finger := -1
var _joy_touching := false
var _sprint_timer := 0.0
var _drag_area: Control = null
var _cam_finger := -1
var _cam_start := Vector2.ZERO
var _cam_last := Vector2.ZERO
var _cam_dragged := false
var _touch_ui: Control = null
var _crosshair: Control = null
var _hints: Label = null
var _top_progress: Label = null
var _hotbar_buttons: Array[Button] = []
var _inventory: Control = null
var _break_cooldown := 0.0
var _dpad: Control = null


func _ready() -> void:
	layer = 10
	settings = SettingsRefactor.load_settings()
	_build_ui()
	_apply_settings_to_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. Área de cámara: PRIMERO (toda la pantalla, por debajo).
	_drag_area = Control.new()
	_drag_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drag_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_drag_area.gui_input.connect(_on_drag_gui_input)
	root.add_child(_drag_area)

	# 2. Crosshair central (siempre visible, TV y móvil).
	_crosshair = Control.new()
	_crosshair.custom_minimum_size = Vector2(28, 28)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-14, -14)
	_crosshair.size = Vector2(28, 28)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch_h := ColorRect.new()
	ch_h.custom_minimum_size = Vector2(28, 4)
	ch_h.position = Vector2(0, 12)
	ch_h.color = Color.WHITE
	ch_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch_v := ColorRect.new()
	ch_v.custom_minimum_size = Vector2(4, 28)
	ch_v.position = Vector2(12, 0)
	ch_v.color = Color.WHITE
	ch_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.add_child(ch_h)
	_crosshair.add_child(ch_v)
	root.add_child(_crosshair)

	# 3. Barra superior minimalista: pausa, cámara, progreso.
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 72.0
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)
	var pause_btn := _make_button("||", func(): pause_pressed.emit())
	pause_btn.custom_minimum_size = Vector2(64, 64)
	top.add_child(pause_btn)
	var cam_btn := _make_button("📷", func(): perspective_pressed.emit())
	cam_btn.custom_minimum_size = Vector2(64, 64)
	top.add_child(cam_btn)
	_top_progress = Label.new()
	_top_progress.text = "⭐ 0"
	top.add_child(_top_progress)

	# 4. Controles táctiles (se ocultan en TV).
	_touch_ui = Control.new()
	_touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_touch_ui)
	_build_joystick()
	_build_action_buttons()
	_build_dpad()

	# 5. Hotbar inferior centrada + botón [...] (siempre visible).
	var hotbar_row := HBoxContainer.new()
	hotbar_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hotbar_row.offset_top = -80.0
	hotbar_row.offset_bottom = -8.0
	hotbar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_row.add_theme_constant_override("separation", 6)
	root.add_child(hotbar_row)
	var more_btn := _make_button("...", _on_more_pressed)
	more_btn.custom_minimum_size = Vector2(64, 64)
	if bool(settings.get("left_handed_inventory", false)):
		hotbar_row.add_child(more_btn)
	for i in range(HOTBAR_SLOTS):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(64, 64)
		slot.text = _slot_label(i)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		_hotbar_buttons.append(slot)
		hotbar_row.add_child(slot)
	if not bool(settings.get("left_handed_inventory", false)):
		hotbar_row.add_child(more_btn)

	# 6. Sugerencias de mando (solo TV).
	_hints = Label.new()
	_hints.text = "[A] Saltar  ·  [RT] Poner  ·  [Y] Inventario"
	_hints.visible = false
	_hints.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hints.offset_top = -36.0
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hints)

	# 7. Inventario modal (oculto hasta pulsar [...] o Y).
	_build_inventory(root)


func _make_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b


func _build_joystick() -> void:
	_joy_base = Control.new()
	_joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.offset_left = 36.0
	_joy_base.offset_top = -300.0
	_joy_base.offset_right = 36.0 + 240.0
	_joy_base.offset_bottom = -60.0
	_joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_joy_base.gui_input.connect(_on_joy_gui_input)
	_touch_ui.add_child(_joy_base)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.35)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.add_child(bg)
	_joy_knob = Control.new()
	_joy_knob.custom_minimum_size = Vector2(96, 96)
	_joy_knob.position = Vector2(72, 72)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_bg := ColorRect.new()
	knob_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	knob_bg.color = Color(0.95, 0.95, 0.95, 0.85)
	knob_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob.add_child(knob_bg)
	_joy_base.add_child(_joy_knob)


func _build_action_buttons() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	col.offset_left = -220.0
	col.offset_top = -340.0
	col.offset_bottom = -90.0
	col.add_theme_constant_override("separation", 10)
	_touch_ui.add_child(col)
	var size := 72.0 * float(settings.get("button_size", 1.0))
	for data in [["↑", func(): jump_pressed.emit()], ["👁", func(): perspective_pressed.emit()], ["+", func(): _on_place()], ["−", func(): _on_remove()]]:
		var b := _make_button(data[0], data[1])
		b.custom_minimum_size = Vector2(size, size)
		col.add_child(b)
	# Agacharse: mantener pulsado (button_down/up), no un toque.
	var crouch_btn := Button.new()
	crouch_btn.text = "↓"
	crouch_btn.custom_minimum_size = Vector2(size, size)
	crouch_btn.button_down.connect(func(): crouch_pressed.emit())
	crouch_btn.button_up.connect(func(): crouch_released.emit())
	col.add_child(crouch_btn)


func _build_dpad() -> void:
	_dpad = Control.new()
	_dpad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_dpad.offset_left = 36.0
	_dpad.offset_top = -300.0
	_dpad.offset_right = 36.0 + 240.0
	_dpad.offset_bottom = -60.0
	_dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dpad.visible = false
	_touch_ui.add_child(_dpad)
	var mk := func(text: String, vec: Vector2) -> Button:
		var b := Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(72, 72)
		b.button_down.connect(func(): _set_dpad(vec))
		b.button_up.connect(func(): _set_dpad(Vector2.ZERO))
		return b
	# 2.0.2 — CORRECCIÓN HUD AUSENTE: `mk.call()` devuelve Variant
	# y `var x :=` con Variant no compila en este Godot (la
	# inferencia se trata como error): el script entero no cargaba
	# y el HUD quedaba en 0 hijos, justo lo que se vio en el
	# celular. Con tipo explícito Button compila siempre.
	var up: Button = mk.call("▲", Vector2(0, 1))
	up.position = Vector2(84, 0)
	var down: Button = mk.call("▼", Vector2(0, -1))
	down.position = Vector2(84, 168)
	var left: Button = mk.call("◀", Vector2(-1, 0))
	left.position = Vector2(0, 84)
	var right: Button = mk.call("▶", Vector2(1, 0))
	right.position = Vector2(168, 84)
	_dpad.add_child(up)
	_dpad.add_child(down)
	_dpad.add_child(left)
	_dpad.add_child(right)


func _set_dpad(vec: Vector2) -> void:
	move_vector = vec
	move_input_changed.emit(move_vector)


func _build_inventory(root: Control) -> void:
	_inventory = Control.new()
	_inventory.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inventory.visible = false
	_inventory.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_inventory)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_inventory.add_child(bg)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(900, 500)
	panel.offset_left = -450.0
	panel.offset_top = -250.0
	panel.offset_right = 450.0
	panel.offset_bottom = 250.0
	_inventory.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var tabs := TabContainer.new()
	tabs.tab_alignment = TabBar.ALIGNMENT_CENTER
	vbox.add_child(tabs)
	for tab in TABS:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(880, 400)
		var grid := GridContainer.new()
		grid.columns = 6
		scroll.add_child(grid)
		for block_id in tab["blocks"]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(120, 64)
			b.text = _block_label(int(block_id))
			b.pressed.connect(_on_inventory_pick.bind(int(block_id)))
			grid.add_child(b)
		scroll.name = str(tab["name"])
		tabs.add_child(scroll)
	var close := _make_button("Cerrar", _close_inventory)
	vbox.add_child(close)


func _block_label(block_id: int) -> String:
	if BLOCK_NAMES.has(block_id):
		return str(BLOCK_NAMES[block_id])
	if block_id >= 30 and block_id <= 39:
		return str(block_id - 30)
	if block_id >= 50 and block_id <= 76:
		return VoxelWorldGenerator.LETRAS[block_id - 50]
	return str(block_id)


func _slot_label(slot: int) -> String:
	if slot < 0 or slot >= hotbar.size():
		return "·"
	return _block_label(hotbar[slot])


func _apply_settings_to_ui() -> void:
	var mode := str(settings.get("control_mode", "joystick_tap"))
	_dpad.visible = mode == "dpad_tap"
	_joy_base.visible = mode != "dpad_tap"
	_apply_joystick_visibility()
	_touch_ui.visible = not tv_mode


func _apply_joystick_visibility() -> void:
	if _joy_base == null:
		return
	match str(settings.get("joystick_visibility", "always")):
		"hidden":
			_joy_base.modulate.a = 0.0
		"when_used":
			_joy_base.modulate.a = 1.0 if _joy_touching else 0.35
		_:
			_joy_base.modulate.a = 1.0


func _process(delta: float) -> void:
	if _break_cooldown > 0.0:
		_break_cooldown -= delta
	# Sprint sencillo: joystick al 100% sostenido 0.3 s.
	if move_vector.length() >= SPRINT_MAGNITUDE and bool(settings.get("easy_sprint", true)):
		_sprint_timer += delta
		if _sprint_timer >= SPRINT_HOLD_SECONDS:
			sprinting = true
	elif move_vector.length() < 0.85:
		_sprint_timer = 0.0
		sprinting = false


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		set_tv_mode(true)
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) > 0.2:
			set_tv_mode(true)
	elif event is InputEventScreenTouch:
		set_tv_mode(false)
	if event.is_action_pressed("inventory"):
		if _inventory.visible:
			_close_inventory()
		else:
			_open_inventory()


func set_tv_mode(value: bool) -> void:
	if tv_mode == value:
		return
	tv_mode = value
	_touch_ui.visible = not tv_mode
	_hints.visible = tv_mode and not bool(settings.get("hide_gamepad_hints", false))
	if tv_mode:
		move_vector = Vector2.ZERO
		move_input_changed.emit(move_vector)


func set_progress(stars: int, total: int = 0) -> void:
	if _top_progress != null:
		_top_progress.text = "⭐ %d" % stars if total <= 0 else "⭐ %d/%d" % [stars, total]


func selected_block() -> int:
	if selected_slot < 0 or selected_slot >= hotbar.size():
		return 10
	return hotbar[selected_slot]


func _on_joy_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _joy_finger < 0:
			_joy_finger = t.index
			_joy_center = _joy_base.get_global_rect().get_center()
			_joy_touching = true
			_apply_joystick_visibility()
			_update_joy(t.position)
		elif not t.pressed and t.index == _joy_finger:
			_joy_finger = -1
			_joy_touching = false
			move_vector = Vector2.ZERO
			_joy_knob.position = Vector2(72, 72)
			_apply_joystick_visibility()
			move_input_changed.emit(move_vector)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_finger:
			_update_joy(d.position)


func _update_joy(pos: Vector2) -> void:
	var offset := pos - _joy_center
	if offset.length() > JOY_RADIUS:
		offset = offset.normalized() * JOY_RADIUS
	_joy_knob.position = Vector2(72, 72) + offset - Vector2(48, 48)
	# ÚNICA inversión de Y de pantalla en toda la variante:
	# arriba en pantalla (offset.y negativo) = adelante (+y).
	var raw := Vector2(offset.x, -offset.y) / JOY_RADIUS
	if raw.length() < 0.2:
		raw = Vector2.ZERO
	elif raw.length() > 1.0:
		raw = raw.normalized()
	move_vector = raw
	move_input_changed.emit(move_vector)


func _on_drag_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _cam_finger < 0:
			_cam_finger = t.index
			_cam_start = t.position
			_cam_last = t.position
			_cam_dragged = false
		elif not t.pressed and t.index == _cam_finger:
			if not _cam_dragged:
				camera_tapped.emit()
			_cam_finger = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _cam_finger:
			if (d.position - _cam_start).length() > 24.0:
				_cam_dragged = true
			if _cam_dragged:
				var rel := d.position - _cam_last
				_cam_last = d.position
				camera_dragged.emit(rel)


func _on_place() -> void:
	if _break_cooldown > 0.0:
		return
	_break_cooldown = float(settings.get("break_delay", 0.25))
	place_pressed.emit()


func _on_remove() -> void:
	if _break_cooldown > 0.0:
		return
	_break_cooldown = float(settings.get("break_delay", 0.25))
	remove_pressed.emit()


func _on_slot_pressed(slot: int) -> void:
	selected_slot = slot
	block_selected.emit(selected_block())
	_refresh_hotbar_labels()


func _refresh_hotbar_labels() -> void:
	for i in range(_hotbar_buttons.size()):
		_hotbar_buttons[i].text = _slot_label(i)


func _on_more_pressed() -> void:
	_open_inventory()


func _open_inventory() -> void:
	_inventory.visible = true
	inventory_opened.emit()


func _close_inventory() -> void:
	_inventory.visible = false
	inventory_closed.emit()


func _on_inventory_pick(block_id: int) -> void:
	hotbar[selected_slot] = block_id
	_refresh_hotbar_labels()
	block_selected.emit(block_id)
	# Al elegir, el inventario se minimiza (se cierra) para no
	# obstruir la visión, como pide la especificación.
	_close_inventory()
