extends Control
## Pantalla de Ajustes (1.12.0): se abre desde la casa de la
## Plaza, desde la pausa de cualquier mundo (botón Ajustes de la
## paleta) o desde el menú clásico. Cada opción se cambia con OK
## y se guarda al instante en user://ajustes.json, separado de
## progreso.json y de mundo.json. «Volver a la Plaza» vuelve a la
## Plaza; «Menú clásico (lista)» abre la lista de siempre, por
## accesibilidad. Atrás también vuelve a la Plaza.

const SettingsSave := preload("res://scripts/settings_save.gd")

var _ajustes: Dictionary = {}
var _title_label: Label
var _buttons_box: VBoxContainer
var _filas: Dictionary = {}


func _ready() -> void:
	_ajustes = SettingsSave.load_settings()
	_build_ui()
	_mostrar()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_volver_plaza()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.20, 0.35, 0.60)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 26)
	center.add_child(vbox)
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_title_label, 58)
	_title_label.text = "Ajustes"
	vbox.add_child(_title_label)
	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 16)
	_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_buttons_box)
	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "Cruceta + OK para cambiar · Atrás para volver a la Plaza"
	_style_label(hint, 20)
	vbox.add_child(hint)


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", int(font_size * float(_ajustes.get("texto", 1.0))))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


func _add_button(texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(720, 88)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", int(32 * float(_ajustes.get("texto", 1.0))))
	b.pressed.connect(accion)
	_buttons_box.add_child(b)
	return b


func _finish_buttons() -> void:
	var nav: Array = []
	for child in _buttons_box.get_children():
		if (child as Node).is_queued_for_deletion():
			continue
		if child is Button and (child as Button).focus_mode == Control.FOCUS_ALL:
			nav.append(child)
	for i in range(nav.size()):
		var b: Button = nav[i]
		var prev: Button = nav[(i - 1 + nav.size()) % nav.size()]
		var nxt: Button = nav[(i + 1) % nav.size()]
		b.focus_neighbor_top = b.get_path_to(prev)
		b.focus_neighbor_bottom = b.get_path_to(nxt)
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.get_path_to(prev)
		b.focus_next = b.get_path_to(nxt)
	if not nav.is_empty():
		(nav[0] as Button).grab_focus()


func _clear_buttons() -> void:
	for child in _buttons_box.get_children():
		(child as Node).queue_free()
	_filas.clear()


func _ciclo(clave: String, valores: Array) -> void:
	var actual = _ajustes.get(clave)
	var idx := valores.find(actual)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + 1) % valores.size()
	_ajustes[clave] = valores[idx]
	SettingsSave.save_settings(_ajustes)
	_mostrar()


func _texto_opcion(clave: String, etiqueta: String, actual, pares: Array) -> String:
	for par in pares:
		if par[0] == actual:
			return "%s: %s" % [etiqueta, String(par[1])]
	return "%s: %s" % [etiqueta, str(actual)]


func _mostrar() -> void:
	_clear_buttons()
	_filas["control"] = _add_button(_texto_opcion("control", "Control", _ajustes.get("control"), [["tv", "Mando TV"], ["tactil", "Táctil"], ["teclado", "Teclado"]]), _ciclo.bind("control", ["tv", "tactil", "teclado"]))
	_filas["giro"] = _add_button(_texto_opcion("giro", "Velocidad de giro", _ajustes.get("giro"), [[0.5, "Lenta"], [1.0, "Normal"], [1.5, "Rápida"]]), _ciclo.bind("giro", [0.5, 1.0, 1.5]))
	_filas["caminar"] = _add_button(_texto_opcion("caminar", "Velocidad al caminar", _ajustes.get("caminar"), [[0.7, "Lenta"], [1.0, "Normal"], [1.4, "Rápida"]]), _ciclo.bind("caminar", [0.7, 1.0, 1.4]))
	_filas["volumen_voces"] = _add_button(_texto_opcion("volumen_voces", "Volumen de voces", _ajustes.get("volumen_voces"), [[0.0, "Silencio"], [0.5, "Medio"], [1.0, "Alto"]]), _ciclo.bind("volumen_voces", [0.0, 0.5, 1.0]))
	_filas["volumen_musica"] = _add_button(_texto_opcion("volumen_musica", "Volumen de música", _ajustes.get("volumen_musica"), [[0.0, "Silencio"], [0.5, "Medio"], [1.0, "Alto"]]), _ciclo.bind("volumen_musica", [0.0, 0.5, 1.0]))
	_filas["texto"] = _add_button(_texto_opcion("texto", "Tamaño de texto", _ajustes.get("texto"), [[0.85, "Pequeño"], [1.0, "Normal"], [1.25, "Grande"]]), _ciclo.bind("texto", [0.85, 1.0, 1.25]))
	_filas["vista"] = _add_button(_texto_opcion("vista", "Vista al caminar", _ajustes.get("vista"), [[0, "Primera persona"], [1, "Segunda persona (Blocky)"]]), _ciclo.bind("vista", [0, 1]))
	_filas["sensibilidad_camara"] = _add_button(_texto_opcion("sensibilidad_camara", "Sensibilidad de cámara", _ajustes.get("sensibilidad_camara"), [[0.5, "Baja"], [1.0, "Normal"], [1.5, "Alta"]]), _ciclo.bind("sensibilidad_camara", [0.5, 1.0, 1.5]))
	_filas["volar"] = _add_button(_texto_opcion("volar", "Volar en el paseo", _ajustes.get("volar"), [[false, "No"], [true, "Sí"]]), _ciclo.bind("volar", [false, true]))
	_filas["menos_movimiento"] = _add_button(_texto_opcion("menos_movimiento", "Menos movimiento de cámara", _ajustes.get("menos_movimiento"), [[false, "No"], [true, "Sí"]]), _ciclo.bind("menos_movimiento", [false, true]))
	_filas["mas_contraste"] = _add_button(_texto_opcion("mas_contraste", "Más contraste", _ajustes.get("mas_contraste"), [[false, "No"], [true, "Sí"]]), _ciclo.bind("mas_contraste", [false, true]))
	_add_button("Menú clásico (lista)", _menu_clasico)
	_add_button("Volver a la Plaza", _volver_plaza)
	_finish_buttons()


func _volver_plaza() -> void:
	get_tree().change_scene_to_file("res://hub.tscn")


func _menu_clasico() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
