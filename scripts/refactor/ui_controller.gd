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
signal attack_pressed
signal dodge_pressed
signal mount_pressed
signal forge_pressed
signal stations_pressed
signal character_pressed
signal potion_pressed
signal food_pressed
signal forge_craft_requested(recipe_id: String)
signal station_craft_requested(station_id: String, recipe_id: String)
signal race_selected(race_id: String)
signal lan_pressed
signal lan_host_pressed
signal lan_search_pressed
signal lan_join_pressed(ip: String)
signal lan_leave_pressed
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
signal workshop_pressed
signal quests_pressed
signal craft_requested(recipe_id: String)

const HOTBAR_SLOTS := 9
const JOY_RADIUS := 110.0
const SPRINT_MAGNITUDE := 0.98
const SPRINT_HOLD_SECONDS := 0.30

# Bloques del inventario por pestaña. id: ver VoxelWorldGenerator
# (10..21 colores, 30..38 números, 40..43 operadores, 50..76 letras,
# 4 madera, 5 hojas, 7 arena, 8/9 flores, 80 antorcha).
const TABS := [
	{"name": "Colores", "blocks": [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]},
	{"name": "Números y Operadores", "blocks": [31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44]},
	{"name": "Letras y Fonética", "blocks": [50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76]},
	{"name": "Naturaleza y Decoración", "blocks": [4, 5, 7, 8, 9, 80]},
	{"name": "Construcción", "blocks": [84, 85, 86, 87, 88]},
	{"name": "Lógica Viva", "blocks": [31, 32, 33, 40, 41, 42, 43, 44]},
	# 3.0: catálogo 160+ por categoría (data/blocks.json v2).
	{"name": "Suelos", "blocks": [100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117]},
	{"name": "Rocas y Minerales", "blocks": [118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153]},
	{"name": "Madera", "blocks": [154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186]},
	{"name": "Construir", "blocks": [187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 247, 248, 249, 250, 251, 252, 253, 254]},
	{"name": "Fluidos y Flora", "blocks": [203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238]},
	{"name": "Trampas", "blocks": [239, 240, 241, 242, 243, 244, 245, 246]},
]
const BLOCK_NAMES := {
	10: "Rojo", 11: "Azul", 12: "Amarillo", 13: "Verde", 14: "Naranja",
	15: "Morado", 16: "Rosado", 17: "Café", 18: "Negro", 19: "Blanco",
	20: "Gris", 21: "Celeste", 40: "+", 41: "-", 42: "×", 43: "=", 44: "÷",
	4: "Madera", 5: "Hojas", 7: "Arena", 8: "Flor roja", 9: "Flor amarilla",
	80: "Antorcha", 84: "Tablones", 85: "Ladrillo", 86: "Vidrio",
	87: "Nieve", 88: "Cristal brillo",
	90: "Estrella", 91: "Corazón", 92: "Farol", 93: "Sílaba MA",
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
var _stats_label: Label = null
var _vitals_label: Label = null
var _minimap: Minimap = null
var _quest_panel: Control = null
var _quest_list: VBoxContainer = null
var _workshop_panel: Control = null
var _workshop_list: VBoxContainer = null
var _forge_panel: Control = null
var _forge_list: VBoxContainer = null
var _station_panel: Control = null
var _station_list: VBoxContainer = null
var _character_panel: Control = null
var _character_list: VBoxContainer = null
var _lan_panel: Control = null
var _lan_list: VBoxContainer = null


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

	# 3. Barra superior: pausa, cámara, taller, misiones, progreso.
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
	var workshop_btn := _make_button("🔨", func(): workshop_pressed.emit())
	workshop_btn.custom_minimum_size = Vector2(64, 64)
	top.add_child(workshop_btn)
	var quests_btn := _make_button("🎯", func(): quests_pressed.emit())
	quests_btn.custom_minimum_size = Vector2(64, 64)
	top.add_child(quests_btn)
	_top_progress = Label.new()
	_top_progress.text = "⭐ 0"
	top.add_child(_top_progress)
	# 3b. Línea de estado 3.0: nivel, EXP, día, estación, zona,
	# clima y fps. La actualiza RefactorMain con set_stats().
	_stats_label = Label.new()
	_stats_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stats_label.offset_top = 72.0
	_stats_label.offset_bottom = 108.0
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_stats_label)
	# 3.0 vitales: salud, maná, estamina, oxígeno, temperatura.
	_vitals_label = Label.new()
	_vitals_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_vitals_label.offset_top = 108.0
	_vitals_label.offset_bottom = 140.0
	_vitals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vitals_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vitals_label)

	# 4. Controles táctiles (se ocultan en TV).
	_touch_ui = Control.new()
	_touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_touch_ui)
	_build_joystick()
	_build_action_buttons()
	_build_action_buttons2()
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
	_hints.text = "Cruceta mover · OK poner · Atrás pausa · [A] saltar · [Y] inventario"
	_hints.visible = false
	_hints.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hints.offset_top = -36.0
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hints)

	# 7. Inventario modal (oculto hasta pulsar [...] o Y).
	_build_inventory(root)

	# 8. Minimapa 3.0 (arriba-derecha, sin bloquear toques).
	_minimap = Minimap.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -230.0
	_minimap.offset_top = 10.0
	_minimap.offset_right = -10.0
	_minimap.offset_bottom = 215.0
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_minimap)

	# 9. Paneles modales 3.0: misiones y taller.
	_build_quest_panel(root)
	_build_workshop_panel(root)
	_build_forge_panel(root)
	_build_station_panel(root)
	_build_character_panel(root)
	_build_lan_panel(root)


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


## 3.0 editor TouchHud (§7.3): las columnas de acciones
## se pueden arrastrar con el asa ⠿ (visible con
## hud_edit_mode) y su posición persiste en ajustes.
const COL1_LEFT := -220.0
const COL1_TOP := -340.0
const COL2_LEFT := -310.0
const COL2_TOP := -340.0
var _action_col: Container = null
var _action_col2: Container = null


## Desplazamiento guardado (Array [x, y] o Vector2).
static func offset_from_settings(st: Dictionary, key: String) -> Vector2:
	var v: Variant = st.get(key, [0.0, 0.0])
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	return Vector2.ZERO


## El desplazamiento se mantiene en pantalla.
static func clamp_hud_offset(off: Vector2) -> Vector2:
	return Vector2(clampf(off.x, -400.0, 150.0), clampf(off.y, -500.0, 150.0))


func _apply_settings() -> void:
	settings = SettingsRefactor.load_settings()
	_build_action_buttons()
	_build_action_buttons2()
	_apply_settings_to_ui()


## 3.0.2: en pantallas cortas (celular apaisado) las
## columnas de 8-9 botones de 72 px desbordaban por
## abajo y tapaban la hotbar; ahora se anclan por
## ABAJO (offset_bottom -90, encima de la hotbar) y
## en alto < 1080 usan rejilla de 2 columnas con
## botón máximo de 64 px. La posición natural es
## -90 - altura_contenido; el desplazamiento del
## editor se guarda relativo a esa posición.
static func action_columns(viewport_h: float) -> int:
	return 1 if viewport_h >= 1080.0 else 2


static func action_button_size(viewport_h: float, setting_size: float) -> float:
	var s := 72.0 * setting_size
	if viewport_h >= 1080.0:
		return s
	return minf(s, 64.0)


func _natural_col_top(col: Container) -> float:
	return -90.0 - col.get_combined_minimum_size().y


func _make_drag_handle(col: Container, size: float) -> Button:
	var handle := Button.new()
	handle.text = "⠿"
	handle.custom_minimum_size = Vector2(size, 36.0)
	handle.visible = bool(settings.get("hud_edit_mode", false))
	handle.gui_input.connect(_on_handle_drag.bind(col))
	return handle


func _on_handle_drag(event: InputEvent, col: Container) -> void:
	var rel := Vector2.ZERO
	if event is InputEventScreenDrag:
		rel = event.relative
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		rel = event.relative
	elif (event is InputEventScreenTouch and not event.pressed) or (event is InputEventMouseButton and not event.pressed):
		_save_col_offsets()
		return
	else:
		return
	var base_left := COL1_LEFT if col == _action_col else COL2_LEFT
	var base_top := _natural_col_top(col)
	var off := clamp_hud_offset(Vector2(col.offset_left - base_left + rel.x, col.offset_top - base_top + rel.y))
	col.offset_left = base_left + off.x
	col.offset_top = base_top + off.y


func _save_col_offsets() -> void:
	if _action_col != null:
		settings["action_offset"] = [_action_col.offset_left - COL1_LEFT, _action_col.offset_top - _natural_col_top(_action_col)]
	if _action_col2 != null:
		settings["action2_offset"] = [_action_col2.offset_left - COL2_LEFT, _action_col2.offset_top - _natural_col_top(_action_col2)]
	SettingsRefactor.save_settings(settings)


## 3.0.2 TV: foco inicial para navegar con cruceta.
## Devuelve true si enfocó algo.
func _focus_first(node: Node) -> bool:
	if node is Button or node is OptionButton:
		var c := node as Control
		if c.visible:
			c.grab_focus()
			return true
	for child in node.get_children():
		if _focus_first(child):
			return true
	return false


func has_open_modal() -> bool:
	for panel in [_inventory, _quest_panel, _workshop_panel, _forge_panel, _station_panel, _character_panel, _lan_panel]:
		if panel != null and panel.visible:
			return true
	return false


## Cierra el primer modal visible (para Atrás en TV).
func close_open_modal() -> bool:
	for panel in [_inventory, _quest_panel, _workshop_panel, _forge_panel, _station_panel, _character_panel, _lan_panel]:
		if panel != null and panel.visible:
			panel.visible = false
			return true
	return false


func _new_action_col(base_left: float) -> Container:
	var vh := get_viewport().get_visible_rect().size.y if get_viewport() != null else 1080.0
	var col: Container
	if action_columns(vh) == 2:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		col = grid
	else:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		col = vbox
	col.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	col.offset_left = base_left
	col.offset_bottom = -90.0
	col.modulate.a = float(settings.get("button_opacity", 1.0))
	_touch_ui.add_child(col)
	return col


func _build_action_buttons() -> void:
	if _action_col != null:
		_touch_ui.remove_child(_action_col)
		_action_col.free()
		_action_col = null
	var vh := get_viewport().get_visible_rect().size.y if get_viewport() != null else 1080.0
	var size := action_button_size(vh, float(settings.get("button_size", 1.0)))
	var col := _new_action_col(COL1_LEFT)
	var off := offset_from_settings(settings, "action_offset")
	col.offset_left = COL1_LEFT + off.x
	_action_col = col
	col.add_child(_make_drag_handle(col, size))
	for data in [["↑", func(): jump_pressed.emit()], ["👁", func(): perspective_pressed.emit()], ["+", func(): _on_place()], ["−", func(): _on_remove()], ["🐴", func(): mount_pressed.emit()], ["⚔", func(): attack_pressed.emit()], ["💨", func(): dodge_pressed.emit()]]:
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
	col.offset_top = _natural_col_top(col) + off.y


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
	# 3.0: bloques del catálogo con su nombre.
	if block_id >= 100:
		return VoxelWorldGenerator.block_label(block_id)
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
	_focus_first(_inventory)
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


## --- 3.0: stats, minimapa, misiones, taller ---

func set_stats(text: String) -> void:
	if _stats_label != null:
		_stats_label.text = text


func _bar(value: float) -> String:
	var filled := int(round(value / 10.0))
	filled = clampi(filled, 0, 10)
	return "█".repeat(filled) + "░".repeat(10 - filled)


func set_vitals(health: float, mana: float, stamina: float, oxygen: float, temperature: float) -> void:
	if _vitals_label != null:
		_vitals_label.text = "❤ %s %d  ✨ %s %d  ⚡ %s %d  🫧 %s %d  🌡 %d" % [
			_bar(health), int(health), _bar(mana), int(mana),
			_bar(stamina), int(stamina), _bar(oxygen), int(oxygen),
			int(temperature)]


func setup_minimap(world: VoxelWorldGenerator) -> void:
	if _minimap != null:
		_minimap.setup(world)


func update_minimap(player_pos: Vector3) -> void:
	if _minimap != null:
		_minimap.update_view(player_pos, Time.get_ticks_msec() / 1000.0)


func set_hotbar_slot(block_id: int) -> void:
	hotbar[selected_slot] = block_id
	_refresh_hotbar_labels()
	block_selected.emit(block_id)


func _modal_panel(root: Control) -> Control:
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(bg)
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(900, 500)
	box.offset_left = -450.0
	box.offset_top = -250.0
	box.offset_right = 450.0
	box.offset_bottom = 250.0
	panel.add_child(box)
	return panel


func _build_quest_panel(root: Control) -> void:
	_quest_panel = _modal_panel(root)
	var box := _quest_panel.get_child(1) as PanelContainer
	var vbox := VBoxContainer.new()
	box.add_child(vbox)
	var title := Label.new()
	title.text = "🎯 Aventuras para empezar"
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880, 400)
	_quest_list = VBoxContainer.new()
	scroll.add_child(_quest_list)
	vbox.add_child(scroll)
	var close := _make_button("Cerrar", func(): _quest_panel.visible = false)
	vbox.add_child(close)


func show_quests(data: Array[Dictionary]) -> void:
	if _quest_panel == null or _quest_list == null:
		return
	for child in _quest_list.get_children():
		child.queue_free()
	for q in data:
		var mark: String = "✓" if bool(q.get("done", false)) else "○"
		var label := Label.new()
		label.text = "%s %s — %s (%d/%d)" % [mark, str(q.get("title", "")),
			str(q.get("desc", "")), int(q.get("progress", 0)), int(q.get("target", 0))]
		_quest_list.add_child(label)
	_quest_panel.visible = true
	_focus_first(_quest_panel)


func _build_workshop_panel(root: Control) -> void:
	_workshop_panel = _modal_panel(root)
	var box := _workshop_panel.get_child(1) as PanelContainer
	var vbox := VBoxContainer.new()
	box.add_child(vbox)
	var title := Label.new()
	title.text = "🔨 Taller"
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880, 400)
	_workshop_list = VBoxContainer.new()
	scroll.add_child(_workshop_list)
	vbox.add_child(scroll)
	var close := _make_button("Cerrar", func(): _workshop_panel.visible = false)
	vbox.add_child(close)


func show_workshop(recipes: Array[Dictionary]) -> void:
	if _workshop_panel == null or _workshop_list == null:
		return
	for child in _workshop_list.get_children():
		child.queue_free()
	for r in recipes:
		var row := HBoxContainer.new()
		var needs := r["needs"] as Dictionary
		var parts: Array[String] = []
		for block_id in needs.keys():
			parts.append("%s ×%d" % [_block_label(int(block_id)), int(needs[block_id])])
		var label := Label.new()
		label.text = "%s: %s" % [str(r["name"]), ", ".join(parts)]
		row.add_child(label)
		var btn := _make_button("Fabricar", _on_craft_pick.bind(str(r["id"])))
		row.add_child(btn)
		_workshop_list.add_child(row)
	_workshop_panel.visible = true
	_focus_first(_workshop_panel)


func _on_craft_pick(recipe_id: String) -> void:
	if _workshop_panel != null:
		_workshop_panel.visible = false
	craft_requested.emit(recipe_id)


# 3.0: segunda columna de acciones (forja, estaciones,
# personaje, pociones, comida), a la izquierda de la
# primera para no alargarla hasta el título.
func _build_action_buttons2() -> void:
	if _action_col2 != null:
		_touch_ui.remove_child(_action_col2)
		_action_col2.free()
		_action_col2 = null
	var vh := get_viewport().get_visible_rect().size.y if get_viewport() != null else 1080.0
	var size := action_button_size(vh, float(settings.get("button_size", 1.0)))
	var col := _new_action_col(COL2_LEFT)
	var off := offset_from_settings(settings, "action2_offset")
	col.offset_left = COL2_LEFT + off.x
	_action_col2 = col
	col.add_child(_make_drag_handle(col, size))
	for data in [["⚒", func(): forge_pressed.emit()], ["🏭", func(): stations_pressed.emit()], ["👤", func(): character_pressed.emit()], ["🧪", func(): potion_pressed.emit()], ["🍎", func(): food_pressed.emit()], ["🌐", func(): lan_pressed.emit()]]:
		var b := _make_button(data[0], data[1])
		b.custom_minimum_size = Vector2(size, size)
		col.add_child(b)
	col.offset_top = _natural_col_top(col) + off.y


func _build_forge_panel(root: Control) -> void:
	_forge_panel = _modal_panel(root)
	var box := _forge_panel.get_child(1) as PanelContainer
	var vbox := VBoxContainer.new()
	box.add_child(vbox)
	var title := Label.new()
	title.text = "⚒ Forja de escultura"
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880, 400)
	_forge_list = VBoxContainer.new()
	scroll.add_child(_forge_list)
	vbox.add_child(scroll)
	var close := _make_button("Cerrar", func(): _forge_panel.visible = false)
	vbox.add_child(close)


func _build_station_panel(root: Control) -> void:
	_station_panel = _modal_panel(root)
	var box := _station_panel.get_child(1) as PanelContainer
	var vbox := VBoxContainer.new()
	box.add_child(vbox)
	var title := Label.new()
	title.text = "🏭 Estaciones"
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880, 400)
	_station_list = VBoxContainer.new()
	scroll.add_child(_station_list)
	vbox.add_child(scroll)
	var close := _make_button("Cerrar", func(): _station_panel.visible = false)
	vbox.add_child(close)


func _build_character_panel(root: Control) -> void:
	_character_panel = _modal_panel(root)
	var box := _character_panel.get_child(1) as PanelContainer
	var vbox := VBoxContainer.new()
	box.add_child(vbox)
	var title := Label.new()
	title.text = "👤 Personaje"
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880, 400)
	_character_list = VBoxContainer.new()
	scroll.add_child(_character_list)
	vbox.add_child(scroll)
	var close := _make_button("Cerrar", func(): _character_panel.visible = false)
	vbox.add_child(close)


func _needs_text(recipe: Dictionary) -> String:
	var parts: Array[String] = []
	var needs_m: Dictionary = recipe.get("needs_materials", {})
	for kind in needs_m.keys():
		parts.append("%s ×%d" % [str(kind), int(needs_m[kind])])
	var needs_s: Dictionary = recipe.get("needs_spirits", {})
	for kind in needs_s.keys():
		parts.append("espíritu %s ×%d" % [str(kind), int(needs_s[kind])])
	var needs_b: Dictionary = recipe.get("needs_blocks", {})
	for block_id in needs_b.keys():
		parts.append("%s ×%d" % [_block_label(int(block_id)), int(needs_b[block_id])])
	return ", ".join(parts)


func _gives_text(recipe: Dictionary) -> String:
	var gives_block := int(recipe.get("gives_block", -1))
	if gives_block >= 0:
		return _block_label(gives_block)
	var item := str(recipe.get("gives_item", ""))
	if item != "":
		return item
	var material := str(recipe.get("gives_material", ""))
	if material != "":
		return "%s ×%d" % [material, int(recipe.get("gives_amount", 0))]
	var potion := str(recipe.get("gives_potion", ""))
	if potion != "":
		return "poción de %s" % potion
	var food := int(recipe.get("gives_food", 0))
	if food > 0:
		return "comida ×%d" % food
	return "?"


func show_forge(recipes: Array[Dictionary], materials: Dictionary, spirits: Dictionary) -> void:
	if _forge_panel == null or _forge_list == null:
		return
	for child in _forge_list.get_children():
		child.queue_free()
	var head := Label.new()
	var mat_parts: Array[String] = []
	for kind in materials.keys():
		mat_parts.append("%s: %d" % [str(kind), int(materials[kind])])
	for kind in spirits.keys():
		mat_parts.append("espíritu %s: %d" % [str(kind), int(spirits[kind])])
	head.text = "Tienes: " + ", ".join(mat_parts)
	_forge_list.add_child(head)
	for r in recipes:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s: %s → %s" % [str(r["name"]), _needs_text(r), _gives_text(r)]
		row.add_child(label)
		var btn := _make_button("Forjar", _on_forge_pick.bind(str(r["id"])))
		row.add_child(btn)
		_forge_list.add_child(row)
	_forge_panel.visible = true
	_focus_first(_forge_panel)


func _on_forge_pick(recipe_id: String) -> void:
	if _forge_panel != null:
		_forge_panel.visible = false
	forge_craft_requested.emit(recipe_id)


func show_stations(sections: Array[Dictionary]) -> void:
	if _station_panel == null or _station_list == null:
		return
	for child in _station_list.get_children():
		child.queue_free()
	for section in sections:
		var title := Label.new()
		title.text = "— " + str(section["station_name"])
		_station_list.add_child(title)
		var recipes: Array = section["recipes"]
		for r in recipes:
			var row := HBoxContainer.new()
			var label := Label.new()
			label.text = "%s: %s → %s" % [str(r["name"]), _needs_text(r), _gives_text(r)]
			row.add_child(label)
			var btn := _make_button("Fabricar", _on_station_pick.bind(str(section["station_id"]), str(r["id"])))
			row.add_child(btn)
			_station_list.add_child(row)
	_station_panel.visible = true
	_focus_first(_station_panel)


func _on_station_pick(station_id: String, recipe_id: String) -> void:
	if _station_panel != null:
		_station_panel.visible = false
	station_craft_requested.emit(station_id, recipe_id)


func show_character(data: Dictionary, races: Array[Dictionary]) -> void:
	if _character_panel == null or _character_list == null:
		return
	for child in _character_list.get_children():
		child.queue_free()
	var info := Label.new()
	var eq: Dictionary = data.get("equipment", {})
	var sk: Dictionary = data.get("skill_xp", {})
	var mat: Dictionary = data.get("materials", {})
	var spi: Dictionary = data.get("spirits", {})
	var pot: Dictionary = data.get("potions", {})
	var skill_parts: Array[String] = []
	for skill in sk.keys():
		skill_parts.append("%s Nv %d" % [str(skill), int(sk[skill]) / 10])
	var mat_parts: Array[String] = []
	for kind in mat.keys():
		mat_parts.append("%s: %d" % [str(kind), int(mat[kind])])
	for kind in spi.keys():
		mat_parts.append("espíritu %s: %d" % [str(kind), int(spi[kind])])
	info.text = "Raza: %s · Monedas: %d · Mascota: %s\nArma: %s · Armadura: %s · Capa: %s\nHabilidades: %s\nMateriales: %s\nPociones: salud %d, maná %d · Comida: %d" % [
		str(data.get("race_name", "")), int(data.get("coins", 0)), str(data.get("pet", "")),
		str(eq.get("arma", "")), str(eq.get("armadura", "")), str(eq.get("capa", "")),
		", ".join(skill_parts), ", ".join(mat_parts),
		int(pot.get("salud", 0)), int(pot.get("mana", 0)), int(data.get("food", 0))]
	_character_list.add_child(info)
	var row := HBoxContainer.new()
	for race in races:
		var btn := _make_button(str(race["name"]), _on_race_pick.bind(str(race["id"])))
		row.add_child(btn)
	_character_list.add_child(row)
	_character_panel.visible = true
	_focus_first(_character_panel)


func _on_race_pick(race_id: String) -> void:
	if _character_panel != null:
		_character_panel.visible = false
	race_selected.emit(race_id)


func _build_lan_panel(root: Control) -> void:
	_lan_panel = _modal_panel(root)
	var box := _lan_panel.get_child(1) as PanelContainer
	var vbox := VBoxContainer.new()
	box.add_child(vbox)
	var title := Label.new()
	title.text = "🌐 Multijugador LAN"
	vbox.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(880, 400)
	_lan_list = VBoxContainer.new()
	scroll.add_child(_lan_list)
	vbox.add_child(scroll)
	var close := _make_button("Cerrar", func(): _lan_panel.visible = false)
	vbox.add_child(close)


func show_lan(hosts: Dictionary, connected: bool, status: String) -> void:
	if _lan_panel == null or _lan_list == null:
		return
	for child in _lan_list.get_children():
		child.queue_free()
	var info := Label.new()
	info.text = status
	_lan_list.add_child(info)
	if connected:
		var leave := _make_button("Salir de la partida", func(): _lan_panel.visible = false; lan_leave_pressed.emit())
		_lan_list.add_child(leave)
	else:
		var row := HBoxContainer.new()
		row.add_child(_make_button("Crear partida", func(): _lan_panel.visible = false; lan_host_pressed.emit()))
		row.add_child(_make_button("Buscar partidas", func(): lan_search_pressed.emit()))
		_lan_list.add_child(row)
		if hosts.is_empty():
			var none := Label.new()
			none.text = "Sin partidas en tu Wi-Fi. Pulsa Buscar."
			_lan_list.add_child(none)
		for ip in hosts.keys():
			var hrow := HBoxContainer.new()
			var label := Label.new()
			label.text = "%s (%s)" % [str(hosts[ip]), str(ip)]
			hrow.add_child(label)
			hrow.add_child(_make_button("Unirse", _on_lan_join_pick.bind(str(ip))))
			_lan_list.add_child(hrow)
	_lan_panel.visible = true
	_focus_first(_lan_panel)


func _on_lan_join_pick(ip: String) -> void:
	if _lan_panel != null:
		_lan_panel.visible = false
	lan_join_pressed.emit(ip)
