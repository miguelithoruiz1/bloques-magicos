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
## Giro de cámara por pasos con el mando (1.3): grados por cada OK
## sobre «Girar ←»/«Girar →» en la paleta del TV (la paleta queda abierta).
signal rotate_step_requested(degrees: float)
signal walk_requested
## Fase 2 (1.8.0): paseo táctil. El overlay de paseo pide salir del
## modo caminar (equivale al OK corto del mando) y cambiar de vista
## (equivale al OK largo del mando). La mascota no se toca: solo se
## le da acceso táctil a un paseo que ya existe.
signal walk_exit_requested
signal walk_view_requested
## Cámara de construcción por presets (1.5/F3): cada OK sobre «Cámara»
## cicla Arriba → Cerca → Lado → Lejos (la paleta queda abierta).
signal camera_cycle_requested

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
## Entradas nuevas 1.3, solo mundo libre: agua, árbol, flor y piezas de
## casa (pared, techo, puerta) para construir estilo Minecraft. Los
## emojis ya se ven en este TV (el menú los usa); el nombre en texto y
## la voz al colocar desambiguan si un glifo fallara.
const LIBRE_DATA: Array = [
	{"modo": "agua", "nombre": "Agua", "emoji": "💧", "bg": Color(0.25, 0.62, 1.00)},
	{"modo": "arbol", "nombre": "Árbol", "emoji": "🌳", "bg": Color(0.25, 0.60, 0.30)},
	{"modo": "flor", "nombre": "Flor", "emoji": "🌸", "bg": Color(1.00, 0.55, 0.75)},
	{"modo": "pared", "nombre": "Pared", "emoji": "🧱", "bg": Color(0.95, 0.92, 0.82)},
	{"modo": "techo", "nombre": "Techo", "emoji": "🔺", "bg": Color(0.85, 0.25, 0.22)},
	{"modo": "puerta", "nombre": "Puerta", "emoji": "🚪", "bg": Color(0.55, 0.38, 0.22)},
]

## Rotación de cámara pedida desde los botones táctiles: -1.0, 0.0 o 1.0.
## main.gd la lee en cada frame y la suma a la rotación del mando.
var touch_rotate := 0.0

## Modo paleta para control de TV (sin puntero): la franja de botones se
## recorre con la cruceta y una opción queda resaltada (borde dorado).
## F2.2: al final de la lista hay 2 opciones extra solo para mando:
## «Empezar de nuevo» (con doble confirmación) e «Ir al menú». Así los
## botones superiores también se alcanzan sin tocar la pantalla.
## 1.3: se añaden «Girar ←» y «Girar →» (cada OK gira 45° y la paleta
## QUEDA ABIERTA para repetir y dar la vuelta completa de 360°).
## 1.5 (F3): se añade «Cámara» al final (cicla los presets de la vista
## de construcción; la paleta también QUEDA ABIERTA para repetir OK).
var tv_palette_open := false
var _tv_highlight := 0
var _tv_extras: Array[String] = ["reset", "menu", "rotl", "rotr", "walk", "cam"]
var _tv_reset_confirm := false
var _tv_hint_label: Label
var _help_label: Label

var _selection: Dictionary = {"modo": "color", "dato": 0}
var _palette_buttons: Array = []
var _base_buttons: Array = []
var _letter_buttons: Array = []
var _letters_row: HBoxContainer
var _libre_row: HBoxContainer
var _selection_label: Label
var _info_label: Label
var _message_label: Label
var _message_tween: Tween
var _announce_label: Label
var _announce_tween: Tween
var _goal_label: Label
var _celebration_label: Label
var _reset_button: Button
var _reset_bar: ProgressBar
var _reset_hold := 0.0
var _reset_fired := false
## Fase 2 (1.8.0): columna de acciones y overlay de paseo. La columna
## se oculta durante el paseo (el cluster del paseo ocupa su zona
## abajo-derecha) y vuelve al salir; la paleta y los botones de giro
## quedan visibles pero inertes en paseo (colocar/borrar ya se
## bloquean en main.gd).
var _actions_box: VBoxContainer
var _walk_box: Control


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


## Atajo de teclado 1–6 (PC). F2.2: si el color está filtrado fuera en
## el mundo actual, el atajo no hace nada (coherente con la paleta).
func select_color(index: int) -> void:
	if index < 0 or index >= COLOR_DATA.size():
		return
	for entry in _base_buttons:
		if String(entry["modo"]) == "color" and int(entry["dato"]) == index:
			if (entry["button"] as Button).visible:
				_select("color", index)
			return


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


## Anuncio grande al colocar un bloque (F2.1): se ve aunque el TTS del
## TV falle. Dura ~2 segundos y luego se desvanece.
func show_announcement(text: String) -> void:
	if _announce_label == null:
		return
	_announce_label.text = text
	_announce_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if _announce_tween != null and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_interval(2.0)
	_announce_tween.tween_property(_announce_label, "modulate:a", 0.0, 0.5)


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
	_build_announce_label(root)
	_build_help_label(root)
	_build_goal_label(root)
	_build_celebration_label(root)
	_build_palette(root)
	_build_action_buttons(root)
	_build_rotate_buttons(root)
	_build_walk_controls(root)


func _build_top_bar(root: Control) -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 1.2.2: margen seguro anti-overscan subido de 64 a 96 px: el TV
	# Challenger del hijo recorta más que 64 px (en 1.2.1 «Menú» y
	# «Empezar de nuevo» quedaban cortados al borde derecho).
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_right", 96)
	margin.add_theme_constant_override("margin_top", 96)
	root.add_child(margin)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 12)
	margin.add_child(top)

	var title := Label.new()
	title.text = "Bloques Mágicos"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(title, 26)
	top.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	_info_label = Label.new()
	_info_label.text = "Altura: 1 · Bloques: 0/600"
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(_info_label, 18)
	top.add_child(_info_label)

	var reset_box := VBoxContainer.new()
	reset_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_box.add_theme_constant_override("separation", 4)
	top.add_child(reset_box)

	_reset_button = _make_button("Empezar de nuevo", Vector2(160, 44), 16)
	_apply_button_colors(_reset_button, Color(0.85, 0.45, 0.40))
	reset_box.add_child(_reset_button)

	_reset_bar = ProgressBar.new()
	_reset_bar.min_value = 0.0
	_reset_bar.max_value = HOLD_SECONDS
	_reset_bar.value = 0.0
	_reset_bar.show_percentage = false
	_reset_bar.custom_minimum_size = Vector2(160, 10)
	_reset_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reset_box.add_child(_reset_bar)

	var hint := Label.new()
	hint.text = "Mantén presionado para borrar todo"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(hint, 12)
	reset_box.add_child(hint)

	var menu_button := _make_button("Menú", Vector2(104, 44), 16)
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


func _build_announce_label(root: Control) -> void:
	_announce_label = Label.new()
	# Banda ancha centrada verticalmente: el texto queda centrado sea cual
	# sea su largo (con PRESET_CENTER puro quedaría desplazado a la derecha).
	_announce_label.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	_announce_label.offset_top = -60.0
	_announce_label.offset_bottom = 60.0
	_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_announce_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_style_label(_announce_label, 72)
	_announce_label.add_theme_constant_override("shadow_offset_x", 4)
	_announce_label.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(_announce_label)


## Ayuda breve y permanente, pensada para el TV: sin ella no se descubre
## que manteniendo OK se abre la paleta de colores y números.
func _build_help_label(root: Control) -> void:
	_help_label = Label.new()
	_help_label.text = "Mando: cruceta mueve · OK pone · mantén OK para elegir · Atrás = menú"
	_help_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_help_label.offset_left = 96.0
	_help_label.offset_top = 160.0
	_help_label.offset_right = 896.0
	_help_label.offset_bottom = 190.0
	_help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(_help_label, 16)
	root.add_child(_help_label)


## Cartel grande con la meta del nivel (Fase 2). Vacío en juego libre.
func _build_goal_label(root: Control) -> void:
	_goal_label = Label.new()
	_goal_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_goal_label.offset_top = 200.0
	_goal_label.offset_bottom = 252.0
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
	# Fase 1: paleta anclada abajo a la IZQUIERDA (antes centrada a lo
	# ancho): el centro de la vista de construcción queda libre. El
	# margen anti-overscan de 96 px se conserva.
	var dock := Control.new()
	dock.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	dock.offset_left = 96.0
	dock.offset_top = -286.0
	dock.offset_right = 916.0
	dock.offset_bottom = -96.0
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dock)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.10, 0.14, 0.72)
	panel_style.set_corner_radius_all(20)
	panel_style.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	dock.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	_selection_label = Label.new()
	_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(_selection_label, 18)
	vbox.add_child(_selection_label)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	for i in range(COLOR_DATA.size()):
		var b := _make_button("", Vector2(56, 56), 30)
		row.add_child(b)
		var entry_c := {
			"button": b, "modo": "color", "dato": i,
			"bg": COLOR_DATA[i]["color"],
			"mundos": ["colores", "libre"],
		}
		_palette_buttons.append(entry_c)
		_base_buttons.append(entry_c)
		b.pressed.connect(_on_palette_pressed.bind("color", i))

	for n in range(1, 6):
		var b := _make_button(str(n), Vector2(56, 56), 28)
		b.add_theme_color_override("font_color", NUMBER_FG)
		b.add_theme_color_override("font_hover_color", NUMBER_FG)
		b.add_theme_color_override("font_pressed_color", NUMBER_FG)
		row.add_child(b)
		var entry_n := {
			"button": b, "modo": "numero", "dato": n, "bg": NUMBER_BG,
			"mundos": ["numeros", "sumas", "libre"],
		}
		_palette_buttons.append(entry_n)
		_base_buttons.append(entry_n)
		b.pressed.connect(_on_palette_pressed.bind("numero", n))

	var eraser := _make_button("Borrar", Vector2(84, 56), 18)
	eraser.add_theme_color_override("font_color", ERASER_FG)
	eraser.add_theme_color_override("font_hover_color", ERASER_FG)
	eraser.add_theme_color_override("font_pressed_color", ERASER_FG)
	row.add_child(eraser)
	var entry_e := {
		"button": eraser, "modo": "borrador", "dato": 0, "bg": ERASER_BG,
		"mundos": ["colores", "numeros", "letras", "sumas", "libre"],
	}
	_palette_buttons.append(entry_e)
	_base_buttons.append(entry_e)
	eraser.pressed.connect(_on_palette_pressed.bind("borrador", 0))

	# Segunda fila (Fase 2): cubos con letras. Oculta salvo en el Mundo
	# Letras; al mostrarse entra también en la navegación con mando.
	_letters_row = HBoxContainer.new()
	_letters_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letters_row.add_theme_constant_override("separation", 8)
	_letters_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_letters_row.visible = false
	vbox.add_child(_letters_row)
	for li in range(LETTER_DATA.size()):
		var lb := _make_button(String(LETTER_DATA[li]), Vector2(56, 56), 28)
		lb.add_theme_color_override("font_color", LETTER_FG)
		lb.add_theme_color_override("font_hover_color", LETTER_FG)
		lb.add_theme_color_override("font_pressed_color", LETTER_FG)
		_letters_row.add_child(lb)
		_letter_buttons.append({
			"button": lb, "modo": "letra", "dato": li, "bg": LETTER_BG,
			"mundos": ["letras"],
		})
		lb.pressed.connect(_on_palette_pressed.bind("letra", li))

	# Segunda fila 1.3: contenido nuevo solo para mundo libre (agua,
	# árbol, flor y piezas de casa). Visible por defecto (en libre nunca
	# se llama a set_level_world); set_level_world la oculta en los
	# mundos de niveles. Al mostrarse entra en la navegación con mando
	# porque sus entradas van en _base_buttons (filtro "libre").
	_libre_row = HBoxContainer.new()
	_libre_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_libre_row.add_theme_constant_override("separation", 8)
	_libre_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_libre_row)
	for entry_def in LIBRE_DATA:
		var modo_l := String(entry_def["modo"])
		var nb := _make_button(String(entry_def["emoji"]), Vector2(56, 56), 28)
		_libre_row.add_child(nb)
		var entry_l := {
			"button": nb, "modo": modo_l, "dato": 0,
			"bg": entry_def["bg"], "mundos": ["libre"],
		}
		_palette_buttons.append(entry_l)
		_base_buttons.append(entry_l)
		nb.pressed.connect(_on_palette_pressed.bind(modo_l, 0))

	_tv_hint_label = Label.new()
	_tv_hint_label.text = "Elige con ◀ ▶ · al final: Nuevo, Menú, Girar, Caminar y Cámara · Altura con ▲ ▼ · OK confirma · Atrás cancela"
	_tv_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tv_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tv_hint_label.visible = false
	_style_label(_tv_hint_label, 16)
	vbox.add_child(_tv_hint_label)


func _build_action_buttons(root: Control) -> void:
	var actions := VBoxContainer.new()
	_actions_box = actions
	actions.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	actions.offset_left = -208.0
	actions.offset_right = -96.0
	actions.offset_top = -150.0
	actions.offset_bottom = 150.0
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)

	var place_b := _make_button("Poner", Vector2(112, 76), 22)
	_apply_button_colors(place_b, Color(0.25, 0.75, 0.35))
	place_b.pressed.connect(func() -> void: place_requested.emit())
	actions.add_child(place_b)

	var remove_b := _make_button("Quitar", Vector2(112, 60), 20)
	_apply_button_colors(remove_b, Color(0.90, 0.45, 0.40))
	remove_b.pressed.connect(func() -> void: remove_requested.emit())
	actions.add_child(remove_b)

	var up_b := _make_button("Subir", Vector2(112, 52), 18)
	_apply_button_colors(up_b, Color(0.35, 0.55, 0.95))
	up_b.pressed.connect(func() -> void: up_requested.emit())
	actions.add_child(up_b)

	var down_b := _make_button("Bajar", Vector2(112, 52), 18)
	_apply_button_colors(down_b, Color(0.35, 0.55, 0.95))
	down_b.pressed.connect(func() -> void: down_requested.emit())
	actions.add_child(down_b)

	# Fase 2 (1.8.0): entrada táctil al paseo, en la misma columna de
	# acciones. Emite la misma señal que la opción «Caminar» del mando
	# (paleta TV), así que main.gd no distingue el origen.
	var walk_b := _make_button("Caminar", Vector2(112, 52), 18)
	_apply_button_colors(walk_b, Color(0.20, 0.65, 0.55))
	walk_b.pressed.connect(func() -> void: walk_requested.emit())
	actions.add_child(walk_b)


func _build_rotate_buttons(root: Control) -> void:
	var rot_box := HBoxContainer.new()
	rot_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	rot_box.offset_left = 80.0
	rot_box.offset_top = -148.0
	rot_box.offset_right = 298.0
	rot_box.offset_bottom = -96.0
	rot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rot_box.add_theme_constant_override("separation", 10)
	root.add_child(rot_box)

	var rot_l := _make_button("Girar ←", Vector2(104, 56), 18)
	_apply_button_colors(rot_l, Color(0.45, 0.45, 0.55))
	rot_l.button_down.connect(_on_rotate_down.bind(1.0))
	rot_l.button_up.connect(_on_rotate_up)
	rot_box.add_child(rot_l)

	var rot_r := _make_button("Girar →", Vector2(104, 56), 18)
	_apply_button_colors(rot_r, Color(0.45, 0.45, 0.55))
	rot_r.button_down.connect(_on_rotate_down.bind(-1.0))
	rot_r.button_up.connect(_on_rotate_up)
	rot_box.add_child(rot_r)


## Fase 2 (1.8.0): controles del paseo para pantalla táctil. Solo
## visibles dentro del modo caminar. Cruceta abajo-derecha (margen
## anti-overscan 96 px, sin tocar la paleta abajo-izquierda): ▲
## avanza, ▼ retrocede (con repetición al mantener, igual que el
## mando), ◀ ▶ giran por pasos de 45° (un paso por toque, igual que
## el mando). «Vista» cambia 1ª/2ª persona y «Salir» sale del paseo.
## La cruceta NO inventa movimiento propio: marca las mismas acciones
## move_* que lee _handle_walk_mode en main.gd (action_press/release,
## la API para controles virtuales), así que el mando y el táctil
## comparten exactamente la misma lógica (y la mascota, que ya sigue
## con esa lógica, no se toca).
func _build_walk_controls(root: Control) -> void:
	_walk_box = Control.new()
	_walk_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_walk_box.offset_left = -328.0
	_walk_box.offset_right = -96.0
	_walk_box.offset_top = -384.0
	_walk_box.offset_bottom = -96.0
	_walk_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_walk_box.visible = false
	root.add_child(_walk_box)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 10)
	_walk_box.add_child(vbox)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var view_b := _make_button("Vista", Vector2(112, 56), 18)
	_apply_button_colors(view_b, Color(0.45, 0.45, 0.55))
	view_b.pressed.connect(func() -> void: walk_view_requested.emit())
	row.add_child(view_b)

	var exit_b := _make_button("Salir", Vector2(112, 56), 18)
	_apply_button_colors(exit_b, Color(0.90, 0.45, 0.40))
	exit_b.pressed.connect(func() -> void: walk_exit_requested.emit())
	row.add_child(exit_b)

	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dpad.add_theme_constant_override("h_separation", 8)
	dpad.add_theme_constant_override("v_separation", 8)
	vbox.add_child(dpad)

	var spacer := func() -> Control:
		var s := Control.new()
		s.custom_minimum_size = Vector2(72, 72)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return s
	dpad.add_child(spacer.call())
	dpad.add_child(_walk_dir_button("▲", "move_forward"))
	dpad.add_child(spacer.call())
	dpad.add_child(_walk_dir_button("◀", "move_left"))
	dpad.add_child(spacer.call())
	dpad.add_child(_walk_dir_button("▶", "move_right"))
	dpad.add_child(spacer.call())
	dpad.add_child(_walk_dir_button("▼", "move_back"))
	dpad.add_child(spacer.call())


func _walk_dir_button(text: String, action: String) -> Button:
	var b := _make_button(text, Vector2(72, 72), 30)
	_apply_button_colors(b, Color(0.30, 0.45, 0.75))
	b.button_down.connect(_send_walk_action.bind(action, true))
	b.button_up.connect(_send_walk_action.bind(action, false))
	return b


## Inyecta una acción de movimiento como si la hubiera producido el
## mando. Mantener ▲/▼ repite el paso cada 0.2 s (la lógica de
## _handle_walk_mode); ◀/▶ dan un paso de 45° por toque.
func _send_walk_action(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Muestra el overlay del paseo y oculta la columna de acciones (su
## zona se solapa con la cruceta). Al ocultar se sueltan las 4
## direcciones: si el niño salía con un dedo aún apoyado, el cursor
## no heredaría un movimiento fantasma al volver a construir.
func set_walk_controls_visible(visible: bool) -> void:
	if _walk_box != null:
		_walk_box.visible = visible
	if _actions_box != null:
		_actions_box.visible = not visible
	if not visible:
		_release_walk_actions()


func _release_walk_actions() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		_send_walk_action(action, false)


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
		"borrador":
			return "Borrar bloques"
		_:
			for entry_def in LIBRE_DATA:
				if String(entry_def["modo"]) == modo:
					return String(entry_def["nombre"])
			return "Borrar bloques"


## Filtro de paleta por mundo (F2.2): cada mundo muestra solo lo que
## necesita su meta (las metas de contar y sumar cuentan cualquier
## bloque, así que los números bastan en Números y Sumas). El borrador
## siempre está. En juego libre no cambia nada (colores + números).
func set_level_world(mundo: String) -> void:
	var filtro := mundo if mundo != "" else "libre"
	var show_letters := mundo == "letras"
	if _letters_row != null:
		_letters_row.visible = show_letters
	# 1.3: la fila libre (agua, árbol, flor, piezas de casa) solo se
	# muestra en mundo libre; en niveles el filtro ya excluye sus
	# entradas de _palette_buttons (mundos ["libre"]).
	if _libre_row != null:
		_libre_row.visible = (filtro == "libre")
	_palette_buttons = []
	for entry in _base_buttons:
		var b: Button = entry["button"]
		var mundos: Array = entry.get("mundos", [])
		var visible := mundos.has(filtro)
		b.visible = visible
		if visible:
			_palette_buttons.append(entry)
	if show_letters:
		_palette_buttons.append_array(_letter_buttons)
	_refresh_palette_styles()
	_refresh_selection_label()


func _refresh_selection_label() -> void:
	if _selection_label == null:
		return
	if tv_palette_open and not _palette_buttons.is_empty():
		if _tv_highlight < _palette_buttons.size():
			var entry: Dictionary = _palette_buttons[_tv_highlight]
			_selection_label.text = "Eligiendo: " + _option_name(String(entry["modo"]), int(entry["dato"]))
		else:
			# Opción extra del mando (sin botón en la paleta).
			var extra := _tv_extras[_tv_highlight - _palette_buttons.size()]
			if extra == "reset":
				if _tv_reset_confirm:
					_selection_label.text = "¿Seguro? OK = borrar todo · Atrás = no"
				else:
					_selection_label.text = "Eligiendo: Empezar de nuevo"
			elif extra == "menu":
				_selection_label.text = "Eligiendo: Ir al menú"
			elif extra == "rotl":
				_selection_label.text = "Eligiendo: Girar cámara ←"
			elif extra == "walk":
				_selection_label.text = "Eligiendo: Caminar (explora por dentro)"
			elif extra == "cam":
				_selection_label.text = "Eligiendo: Cámara"
			else:
				_selection_label.text = "Eligiendo: Girar cámara →"
		return
	var sm := String(_selection["modo"])
	if sm == "borrador":
		_selection_label.text = "Herramienta: Borrar bloques"
	else:
		_selection_label.text = "Bloque elegido: " + _option_name(sm, int(_selection["dato"]))


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
	# La lista incluye las opciones extra del mando al final.
	var total := _palette_buttons.size() + _tv_extras.size()
	if total <= 0:
		return
	_tv_highlight = (_tv_highlight + dir) % total
	if _tv_highlight < 0:
		_tv_highlight += total
	# 1.3: al salir de «Empezar de nuevo» se cancela su confirmación
	# armada (antes quedaba armada aunque el resaltado se hubiera ido).
	if _tv_highlight < _palette_buttons.size() \
			or _tv_extras[_tv_highlight - _palette_buttons.size()] != "reset":
		_tv_reset_confirm = false
	_refresh_selection_label()
	_refresh_palette_styles()


## Confirma la opción resaltada. Devuelve true si la paleta debe
## cerrarse, false solo cuando armó la doble confirmación de
## «Empezar de nuevo» (la paleta sigue abierta esperando el 2º OK).
func confirm_tv_palette() -> bool:
	if _palette_buttons.is_empty():
		close_tv_palette()
		return true
	if _tv_highlight >= _palette_buttons.size():
		var extra := _tv_extras[_tv_highlight - _palette_buttons.size()]
		if extra == "menu":
			close_tv_palette()
			menu_requested.emit()
			return true
		if extra == "rotl" or extra == "rotr":
			# 1.3: giro por pasos con el mando. La paleta QUEDA ABIERTA
			# (devuelve false) para repetir OK y dar la vuelta completa:
			# 8 pasos de 45° = 360°. Igual que los botones táctiles Girar
			# (Girar ← = +45°, Girar → = −45°).
			_tv_reset_confirm = false
			rotate_step_requested.emit(45.0 if extra == "rotl" else -45.0)
			_refresh_selection_label()
			return false
		if extra == "walk":
			# 1.4: entrar al modo caminar (primera persona). La paleta
			# se cierra y main.gd toma el control del mando.
			_tv_reset_confirm = false
			close_tv_palette()
			walk_requested.emit()
			return true
		if extra == "cam":
			# 1.5 (F3): ciclar la cámara de construcción. La paleta
			# QUEDA ABIERTA (devuelve false) para repetir OK y ver
			# cada vista, igual que el giro 1.3.
			_tv_reset_confirm = false
			camera_cycle_requested.emit()
			_refresh_selection_label()
			return false
		# «Empezar de nuevo» con mando: 1er OK arma la confirmación,
		# 2º OK borra. Equivale al toque sostenido 1.5 s anti-accidentes.
		if not _tv_reset_confirm:
			_tv_reset_confirm = true
			_refresh_selection_label()
			return false
		_tv_reset_confirm = false
		close_tv_palette()
		world_reset.emit()
		return true
	var entry: Dictionary = _palette_buttons[_tv_highlight]
	var modo := String(entry["modo"])
	var dato := int(entry["dato"])
	close_tv_palette()
	_select(modo, dato)
	return true


func cancel_tv_palette() -> void:
	_tv_reset_confirm = false
	close_tv_palette()
	_refresh_selection_label()


func close_tv_palette() -> void:
	tv_palette_open = false
	_tv_reset_confirm = false
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
