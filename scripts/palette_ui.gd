extends CanvasLayer
## Interfaz de Bloques Mágicos (Fase 1).
## La crea main.gd por código (no necesita .tscn). Contiene:
## - Barra superior: título, información (altura y conteo) y botón
##   «Empezar de nuevo» con pulsación larga anti-accidentes.
## - Paleta inferior con botones GRANDES: 6 colores, números 1-5 y borrador.
## - Botones táctiles en pantalla: Poner, Quitar, Subir, Bajar y Girar cámara.
## - Etiqueta de mensajes amables (avisos sin castigo, pensados para un niño).
## Todos los botones usan FOCUS_NONE para que el mando nunca pierda el control.

signal selection_changed(selection: Dictionary)
signal place_requested
signal remove_requested
signal up_requested
signal down_requested
signal world_reset
signal menu_requested

const HOLD_SECONDS := 1.5

const COLOR_DATA: Array = [
	{"nombre": "Rojo", "color": Color(0.90, 0.25, 0.22)},
	{"nombre": "Azul", "color": Color(0.20, 0.45, 0.95)},
	{"nombre": "Amarillo", "color": Color(0.98, 0.80, 0.15)},
	{"nombre": "Verde", "color": Color(0.30, 0.75, 0.35)},
	{"nombre": "Naranja", "color": Color(0.98, 0.55, 0.15)},
	{"nombre": "Morado", "color": Color(0.60, 0.35, 0.90)},
]
const NUMBER_BG := Color(1.0, 0.95, 0.78)
const NUMBER_FG := Color(0.10, 0.16, 0.45)
const ERASER_BG := Color(0.99, 0.87, 0.87)
const ERASER_FG := Color(0.55, 0.15, 0.15)
## Cubos con letras (Fase 2): vocales + M, P, S, T, L, N.
const LETTER_DATA: Array = ["A", "E", "I", "O", "U", "M", "P", "S", "T", "L", "N"]
const LETTER_BG := Color(0.62, 0.85, 1.0)
const LETTER_FG := Color(0.05, 0.15, 0.45)

## Rotación de cámara pedida desde los botones táctiles: -1.0, 0.0 o 1.0.
## main.gd la lee en cada frame y la suma a la rotación del mando.
var touch_rotate := 0.0

## Modo paleta para control de TV (sin puntero): la franja de botones se
## recorre con la cruceta y una opción queda resaltada (borde dorado).
var tv_palette_open := false
var _tv_highlight := 0
var _tv_hint_label: Label
var _help_label: Label

var _selection: Dictionary = {"modo": "color", "dato": 0}
var _palette_buttons: Array = []
var _base_buttons: Array = []
var _letter_buttons: Array = []
var _letters_row: HBoxContainer
var _selection_label: Label
var _info_label: Label
var _message_label: Label
var _message_tween: Tween
var _goal_label: Label
var _celebration_label: Label
var _reset_button: Button
var _reset_bar: ProgressBar
var _reset_hold := 0.0
var _reset_fired := false


func _ready() -> void:
	_build_ui()
	_select("color", 0)


func _process(delta: float) -> void:
	if _reset_button == null:
		return
	if _reset_button.is_pressed():
		if not _reset_fired:
			_reset_hold += delta
			_reset_bar.value = _reset_hold
			if _reset_hold >= HOLD_SECONDS:
				_reset_fired = true
				_reset_hold = 0.0
				_reset_bar.value = 0.0
				world_reset.emit()
	else:
		_reset_hold = 0.0
		_reset_bar.value = 0.0
		_reset_fired = false


func get_selection() -> Dictionary:
	return _selection.duplicate()


func select_color(index: int) -> void:
	if index >= 0 and index < COLOR_DATA.size():
		_select("color", index)


func set_info(text: String) -> void:
	if _info_label != null:
		_info_label.text = text


func show_message(text: String) -> void:
	if _message_label == null:
		return
	_message_label.text = text
	_message_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.8)
	_message_tween.tween_property(_message_label, "modulate:a", 0.0, 0.7)


# ---------------------------------------------------------------------------
# Construcción de la interfaz
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_bar(root)
	_build_message_label(root)
	_build_help_label(root)
	_build_goal_label(root)
	_build_celebration_label(root)
	_build_palette(root)
	_build_action_buttons(root)
	_build_rotate_buttons(root)


func _build_top_bar(root: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	root.add_child(margin)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	margin.add_child(top)

	var title := Label.new()
	title.text = "Bloques Mágicos"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(title, 30)
	top.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	_info_label = Label.new()
	_info_label.text = "Altura: 1 · Bloques: 0/600"
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(_info_label, 20)
	top.add_child(_info_label)

	var reset_box := VBoxContainer.new()
	reset_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_box.add_theme_constant_override("separation", 4)
	top.add_child(reset_box)

	_reset_button = _make_button("Empezar de nuevo", Vector2(196, 52), 18)
	_apply_button_colors(_reset_button, Color(0.85, 0.45, 0.40))
	reset_box.add_child(_reset_button)

	_reset_bar = ProgressBar.new()
	_reset_bar.min_value = 0.0
	_reset_bar.max_value = HOLD_SECONDS
	_reset_bar.value = 0.0
	_reset_bar.show_percentage = false
	_reset_bar.custom_minimum_size = Vector2(196, 10)
	_reset_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_box.add_child(_reset_bar)

	var hint := Label.new()
	hint.text = "Mantén presionado para borrar todo"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(hint, 12)
	reset_box.add_child(hint)

	var menu_button := _make_button("Menú", Vector2(130, 52), 18)
	_apply_button_colors(menu_button, Color(0.45, 0.45, 0.55))
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
	top.add_child(menu_button)


func _build_message_label(root: Control) -> void:
	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	_message_label.offset_top = -140.0
	_message_label.offset_bottom = -80.0
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_style_label(_message_label, 30)
	root.add_child(_message_label)


## Ayuda breve y permanente, pensada para el TV: sin ella no se descubre
## que manteniendo OK se abre la paleta de colores y números.
func _build_help_label(root: Control) -> void:
	_help_label = Label.new()
	_help_label.text = "Control TV: mantén OK para elegir color o número"
	_help_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_help_label.offset_left = 14.0
	_help_label.offset_top = 78.0
	_help_label.offset_right = 800.0
	_help_label.offset_bottom = 108.0
	_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(_help_label, 16)
	root.add_child(_help_label)


## Cartel grande con la meta del nivel (Fase 2). Vacío en juego libre.
func _build_goal_label(root: Control) -> void:
	_goal_label = Label.new()
	_goal_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_goal_label.offset_top = 112.0
	_goal_label.offset_bottom = 164.0
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(_goal_label, 34)
	root.add_child(_goal_label)


func set_goal(text: String) -> void:
	if _goal_label != null:
		_goal_label.text = text


## Cartel central de celebración (Fase 2): estrella al completar el nivel.
func _build_celebration_label(root: Control) -> void:
	_celebration_label = Label.new()
	_celebration_label.set_anchors_preset(Control.PRESET_CENTER)
	_celebration_label.offset_left = -460.0
	_celebration_label.offset_top = -80.0
	_celebration_label.offset_right = 460.0
	_celebration_label.offset_bottom = 80.0
	_celebration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_celebration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_celebration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_celebration_label.visible = false
	_style_label(_celebration_label, 56)
	_celebration_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
	root.add_child(_celebration_label)


func show_celebration(text: String) -> void:
	if _celebration_label != null:
		_celebration_label.text = text
		_celebration_label.visible = true


func hide_celebration() -> void:
	if _celebration_label != null:
		_celebration_label.visible = false


func _build_palette(root: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -160.0
	center.offset_bottom = -10.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.72)
	panel_style.set_corner_radius_all(20)
	panel_style.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_selection_label = Label.new()
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(_selection_label, 20)
	vbox.add_child(_selection_label)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	for i in range(COLOR_DATA.size()):
		var b := _make_button("", Vector2(74, 74), 30)
		row.add_child(b)
		var entry_c := {
			"button": b, "modo": "color", "dato": i,
			"bg": COLOR_DATA[i]["color"],
		}
		_palette_buttons.append(entry_c)
		_base_buttons.append(entry_c)
		b.pressed.connect(_on_palette_pressed.bind("color", i))

	for n in range(1, 6):
		var b := _make_button(str(n), Vector2(74, 74), 36)
		b.add_theme_color_override("font_color", NUMBER_FG)
		b.add_theme_color_override("font_hover_color", NUMBER_FG)
		b.add_theme_color_override("font_pressed_color", NUMBER_FG)
		row.add_child(b)
		var entry_n := {
			"button": b, "modo": "numero", "dato": n, "bg": NUMBER_BG,
		}
		_palette_buttons.append(entry_n)
		_base_buttons.append(entry_n)
		b.pressed.connect(_on_palette_pressed.bind("numero", n))

	var eraser := _make_button("Borrar", Vector2(100, 74), 20)
	eraser.add_theme_color_override("font_color", ERASER_FG)
	eraser.add_theme_color_override("font_hover_color", ERASER_FG)
	eraser.add_theme_color_override("font_pressed_color", ERASER_FG)
	row.add_child(eraser)
	var entry_e := {
		"button": eraser, "modo": "borrador", "dato": 0, "bg": ERASER_BG,
	}
	_palette_buttons.append(entry_e)
	_base_buttons.append(entry_e)
	eraser.pressed.connect(_on_palette_pressed.bind("borrador", 0))

	# Segunda fila (Fase 2): cubos con letras. Oculta salvo en el Mundo
	# Letras; al mostrarse entra también en la navegación con mando.
	_letters_row = HBoxContainer.new()
	_letters_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letters_row.add_theme_constant_override("separation", 10)
	_letters_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_letters_row.visible = false
	vbox.add_child(_letters_row)
	for li in range(LETTER_DATA.size()):
		var lb := _make_button(String(LETTER_DATA[li]), Vector2(74, 74), 36)
		lb.add_theme_color_override("font_color", LETTER_FG)
		lb.add_theme_color_override("font_hover_color", LETTER_FG)
		lb.add_theme_color_override("font_pressed_color", LETTER_FG)
		_letters_row.add_child(lb)
		_letter_buttons.append({
			"button": lb, "modo": "letra", "dato": li, "bg": LETTER_BG,
		})
		lb.pressed.connect(_on_palette_pressed.bind("letra", li))

	_tv_hint_label = Label.new()
	_tv_hint_label.text = "Elige con ◀ ▶ · Altura con ▲ ▼ · OK confirma · Atrás cancela"
	_tv_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tv_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tv_hint_label.visible = false
	_style_label(_tv_hint_label, 18)
	vbox.add_child(_tv_hint_label)


func _build_action_buttons(root: Control) -> void:
	var actions := VBoxContainer.new()
	actions.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	actions.offset_left = -160.0
	actions.offset_right = -14.0
	actions.offset_top = -200.0
	actions.offset_bottom = 200.0
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)

	var place_b := _make_button("Poner", Vector2(146, 104), 28)
	_apply_button_colors(place_b, Color(0.25, 0.75, 0.35))
	place_b.pressed.connect(func() -> void: place_requested.emit())
	actions.add_child(place_b)

	var remove_b := _make_button("Quitar", Vector2(146, 78), 24)
	_apply_button_colors(remove_b, Color(0.90, 0.45, 0.40))
	remove_b.pressed.connect(func() -> void: remove_requested.emit())
	actions.add_child(remove_b)

	var up_b := _make_button("Subir", Vector2(146, 64), 22)
	_apply_button_colors(up_b, Color(0.35, 0.55, 0.95))
	up_b.pressed.connect(func() -> void: up_requested.emit())
	actions.add_child(up_b)

	var down_b := _make_button("Bajar", Vector2(146, 64), 22)
	_apply_button_colors(down_b, Color(0.35, 0.55, 0.95))
	down_b.pressed.connect(func() -> void: down_requested.emit())
	actions.add_child(down_b)


func _build_rotate_buttons(root: Control) -> void:
	var rot_box := HBoxContainer.new()
	rot_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	rot_box.offset_left = 14.0
	rot_box.offset_top = -84.0
	rot_box.offset_right = 300.0
	rot_box.offset_bottom = -14.0
	rot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rot_box.add_theme_constant_override("separation", 10)
	root.add_child(rot_box)

	var rot_l := _make_button("Girar ←", Vector2(132, 70), 20)
	_apply_button_colors(rot_l, Color(0.45, 0.45, 0.55))
	rot_l.button_down.connect(_on_rotate_down.bind(1.0))
	rot_l.button_up.connect(_on_rotate_up)
	rot_box.add_child(rot_l)

	var rot_r := _make_button("Girar →", Vector2(132, 70), 20)
	_apply_button_colors(rot_r, Color(0.45, 0.45, 0.55))
	rot_r.button_down.connect(_on_rotate_down.bind(-1.0))
	rot_r.button_up.connect(_on_rotate_up)
	rot_box.add_child(rot_r)


# ---------------------------------------------------------------------------
# Ayudantes
# ---------------------------------------------------------------------------

func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _make_button(text: String, min_size: Vector2, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", font_size)
	return b


func _style_box(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)
	if border_width > 0:
		s.set_border_width_all(border_width)
		s.border_color = border
	return s


func _apply_button_colors(b: Button, base: Color) -> void:
	b.add_theme_stylebox_override("normal", _style_box(base, Color(0, 0, 0, 0.25), 2))
	b.add_theme_stylebox_override("hover", _style_box(base.lightened(0.12), Color(0, 0, 0, 0.25), 2))
	b.add_theme_stylebox_override("pressed", _style_box(base.darkened(0.15), Color(1, 1, 1, 0.9), 3))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)


func _on_palette_pressed(modo: String, dato: int) -> void:
	_select(modo, dato)


func _select(modo: String, dato: int) -> void:
	_selection = {"modo": modo, "dato": dato}
	_refresh_palette_styles()
	_refresh_selection_label()
	selection_changed.emit(_selection.duplicate())


func _option_name(modo: String, dato: int) -> String:
	match modo:
		"color":
			return String(COLOR_DATA[dato]["nombre"])
		"numero":
			return "Número " + str(dato)
		"letra":
			return "Letra " + String(LETTER_DATA[clampi(dato, 0, LETTER_DATA.size() - 1)])
		_:
			return "Borrar bloques"


## Muestra la fila de letras solo en el Mundo Letras (Fase 2) y ajusta
## la lista de navegación con mando. En juego libre no cambia nada.
func set_level_world(mundo: String) -> void:
	var show_letters := mundo == "letras"
	if _letters_row != null:
		_letters_row.visible = show_letters
	_palette_buttons = _base_buttons.duplicate()
	if show_letters:
		_palette_buttons.append_array(_letter_buttons)
	_refresh_palette_styles()
	_refresh_selection_label()


func _refresh_selection_label() -> void:
	if _selection_label == null:
		return
	if tv_palette_open and not _palette_buttons.is_empty():
		var entry: Dictionary = _palette_buttons[_tv_highlight]
		_selection_label.text = "Eligiendo: " + _option_name(String(entry["modo"]), int(entry["dato"]))
		return
	match String(_selection["modo"]):
		"color":
			_selection_label.text = "Bloque elegido: " + _option_name("color", int(_selection["dato"]))
		"numero":
			_selection_label.text = "Bloque elegido: " + _option_name("numero", int(_selection["dato"]))
		"letra":
			_selection_label.text = "Bloque elegido: " + _option_name("letra", int(_selection["dato"]))
		_:
			_selection_label.text = "Herramienta: Borrar bloques"


# ---------------------------------------------------------------------------
# Modo paleta con control de TV (sin puntero)
# ---------------------------------------------------------------------------

func _index_of_selection() -> int:
	for i in range(_palette_buttons.size()):
		var entry: Dictionary = _palette_buttons[i]
		if String(entry["modo"]) == String(_selection["modo"]) \
				and int(entry["dato"]) == int(_selection["dato"]):
			return i
	return 0


func open_tv_palette() -> void:
	tv_palette_open = true
	_tv_highlight = _index_of_selection()
	if _tv_hint_label != null:
		_tv_hint_label.visible = true
	_refresh_selection_label()
	_refresh_palette_styles()


func move_tv_highlight(dir: int) -> void:
	if _palette_buttons.is_empty():
		return
	_tv_highlight = (_tv_highlight + dir) % _palette_buttons.size()
	if _tv_highlight < 0:
		_tv_highlight += _palette_buttons.size()
	_refresh_selection_label()
	_refresh_palette_styles()


func confirm_tv_palette() -> void:
	if _palette_buttons.is_empty():
		close_tv_palette()
		return
	var entry: Dictionary = _palette_buttons[_tv_highlight]
	var modo := String(entry["modo"])
	var dato := int(entry["dato"])
	close_tv_palette()
	_select(modo, dato)


func cancel_tv_palette() -> void:
	close_tv_palette()
	_refresh_selection_label()


func close_tv_palette() -> void:
	tv_palette_open = false
	if _tv_hint_label != null:
		_tv_hint_label.visible = false
	_refresh_palette_styles()


func _refresh_palette_styles() -> void:
	for idx in range(_palette_buttons.size()):
		var entry: Dictionary = _palette_buttons[idx]
		var b: Button = entry["button"]
		var bg: Color = entry["bg"]
		var selected := String(entry["modo"]) == String(_selection["modo"]) \
			and int(entry["dato"]) == int(_selection["dato"])
		if tv_palette_open and idx == _tv_highlight:
			# Resaltado de navegación con el control de TV: borde dorado
			# grueso, distinto del borde blanco de la opción ya elegida.
			b.add_theme_stylebox_override("normal", _style_box(bg.lightened(0.10), Color(1.0, 0.85, 0.20), 6))
			b.add_theme_stylebox_override("pressed", _style_box(bg, Color(1.0, 0.85, 0.20), 6))
		elif selected:
			b.add_theme_stylebox_override("normal", _style_box(bg, Color.WHITE, 5))
			b.add_theme_stylebox_override("pressed", _style_box(bg, Color.WHITE, 5))
		else:
			b.add_theme_stylebox_override("normal", _style_box(bg, Color(0, 0, 0, 0.28), 2))
			b.add_theme_stylebox_override("pressed", _style_box(bg.darkened(0.1), Color(0, 0, 0, 0.28), 2))
		b.add_theme_stylebox_override("hover", _style_box(bg.lightened(0.08), Color(0, 0, 0, 0.28), 2))


func _on_rotate_down(direction: float) -> void:
	touch_rotate = direction


func _on_rotate_up() -> void:
	touch_rotate = 0.0
