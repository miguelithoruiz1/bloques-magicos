extends Control
## SettingsScene — Ajustes estilo Minecraft de la variante.
##
## Navegación lateral izquierda (5 secciones) + panel derecho con
## ScrollContainer. Cada cambio se guarda al instante en
## user://settings_refactor.cfg (propio de la variante).
## Secciones: Teclado y ratón, Mando, Táctil, Audio y Voces,
## Mundo y Semilla. La tabla de reasignación de mando edita los
## botones Joypad por acción y «Restablecer» devuelve los defaults
## de SettingsRefactor (sin tocar ningún otro archivo).

signal closed

const SECTIONS := ["Teclado y ratón", "Mando", "Táctil", "Audio y Voces", "Mundo y Semilla"]
const CONTROL_MODES := ["Joystick y pulsar para interactuar", "Cruceta y pulsar para interactuar", "Joystick y apuntar con el retículo"]
const CONTROL_MODE_KEYS := ["joystick_tap", "dpad_tap", "joystick_crosshair"]
const JOY_VIS := ["Siempre visible", "Siempre oculto", "Oculto cuando no se usa"]
const JOY_VIS_KEYS := ["always", "hidden", "when_used"]
const BIOMES := ["Croma-Isla", "Forja de los Números", "Valle del Eco", "Ciber-Núcleo", "Pradera Verde", "Playa y Mar", "Bosque Mágico", "Montaña Nevada", "Océano", "Río", "Pantano", "Tundra Nevada", "Sabana", "Desierto", "Jungla", "Valle Tranquilo (Zona 1)", "Bosque de Luciérnagas (Zona 1)", "Colinas de Cristal (Zona 2)", "Pantano Luminoso (Zona 2)", "Desierto de Sal (Zona 2)", "Bosque Otoñal (Zona 2)", "Montañas de Cobre (Zona 3)", "Selva de Bambú (Zona 3)", "Tundra Azul (Zona 3)", "Meseta Roja (Zona 3)", "Llanura de Girasoles (Zona 3)", "Tierras de Cristal (Zona 4)", "Bosque de Setas Gigantes (Zona 4)", "Glaciar Eterno (Zona 4)", "Volcán Dormido (Zona 4)", "Altiplano de Nubes (Zona 4)", "Bosque Petrificado (Zona 5)", "Desierto de Obsidiana (Zona 5)", "Pantano de Niebla (Zona 5)", "Montañas del Eco (Zona 5)", "Suelo Corrupto (Zona 5)", "Tierras Celestiales (Zona 6)", "Abismo de Cristal (Zona 6)", "Hielo Eterno (Zona 6)", "Tierras de Magma (Zona 6)", "Jardín del Vacío (Zona 6)"]
const BIOME_KEYS := ["croma_isla", "forja_numeros", "valle_eco", "ciber_nucleo", "pradera_verde", "playa_mar", "bosque_magico", "montana_nevada", "oceano", "rio", "pantano", "tundra_nevada", "sabana", "desierto", "jungla", "valle_tranquilo", "bosque_luciernagas", "colinas_cristal", "pantano_luminoso", "desierto_sal", "bosque_otonal", "montanas_cobre", "selva_bambu", "tundra_azul", "meseta_roja", "llanura_girasoles", "tierras_cristal", "bosque_setas", "glaciar_eterno", "volcan_dormido", "altiplano_nubes", "bosque_petrificado", "desierto_obsidiana", "pantano_niebla", "montanas_eco", "suelo_corrupto", "tierras_celestiales", "abismo_cristal", "hielo_eterno", "tierras_magma", "jardin_vacio"]
const REMAP_ACTIONS := ["jump", "crouch", "inventory", "place", "remove", "perspective"]
const REMAP_LABELS := {"jump": "Saltar", "crouch": "Agacharse", "inventory": "Inventario", "place": "Poner", "remove": "Quitar", "perspective": "Cámara"}

var settings: Dictionary = {}
var _right: VBoxContainer = null
var _seed_field: LineEdit = null


func _ready() -> void:
	settings = SettingsRefactor.load_settings()
	_build_ui()
	_show_section(2) # Táctil por defecto: es la sección más usada.


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.10, 0.12, 0.16)
	add_child(bg)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(320, 0)
	hbox.add_child(nav)
	for i in range(SECTIONS.size()):
		var b := Button.new()
		b.text = SECTIONS[i]
		b.custom_minimum_size = Vector2(300, 72)
		b.pressed.connect(_show_section.bind(i))
		nav.add_child(b)
	var back := Button.new()
	back.text = "← Volver"
	back.custom_minimum_size = Vector2(300, 72)
	back.pressed.connect(func(): closed.emit())
	nav.add_child(back)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(scroll)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 14)
	scroll.add_child(_right)


func _clear_right() -> void:
	for child in _right.get_children():
		child.queue_free()


func _title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 36)
	_right.add_child(label)


func _check(text: String, key: String) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(settings.get(key, false))
	c.toggled.connect(func(v: bool): _set_setting(key, v))
	_right.add_child(c)
	return c


func _slider(text: String, key: String, min_v: float, max_v: float, step_v: float = 1.0) -> HSlider:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "%s: %s" % [text, str(settings.get(key, 0))]
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = float(settings.get(key, 0))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v: float):
		_set_setting(key, v)
		label.text = "%s: %s" % [text, str(v)])
	row.add_child(slider)
	_right.add_child(row)
	return slider


func _option(text: String, key: String, labels: Array, keys: Array) -> OptionButton:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	row.add_child(label)
	var opt := OptionButton.new()
	for item in labels:
		opt.add_item(str(item))
	var current := str(settings.get(key, ""))
	opt.selected = keys.find(current) if keys.has(current) else 0
	opt.item_selected.connect(func(idx: int): _set_setting(key, keys[idx]))
	row.add_child(opt)
	_right.add_child(row)
	return opt


## 2.0.2 — antes se llamaba `_set`, pero Object ya tiene un
## `_set(StringName, Variant) -> bool` virtual y la firma distinta
## era error de compilación: la pantalla de Ajustes no cargaba.
## Renombrado a `_set_setting`, sin cambiar comportamiento.
func _set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	SettingsRefactor.save_settings(settings)


func _show_section(index: int) -> void:
	_clear_right()
	match index:
		0:
			_show_keyboard()
		1:
			_show_gamepad()
		2:
			_show_touch()
		3:
			_show_audio()
		4:
			_show_world()


func _show_keyboard() -> void:
	_title("Teclado y ratón")
	_note("WASD o flechas: moverse · Espacio: saltar · Mayús: correr · C: agacharse · E: inventario · Clic: poner · Clic derecho: quitar.")
	_slider("Sensibilidad de la cámara", "camera_sensitivity", 0, 100)
	_check("Invertir eje Y de la cámara", "invert_y")
	_check("Saltar automáticamente", "auto_jump")


func _show_gamepad() -> void:
	_title("Mando (TV)")
	_slider("Sensibilidad de la cámara", "gamepad_camera_sensitivity", 0, 100)
	_slider("Sensibilidad del cursor", "gamepad_cursor_sensitivity", 0, 100)
	_check("Invertir eje Y", "gamepad_invert_y")
	_check("Saltar automáticamente", "gamepad_auto_jump")
	_check("Ocultar sugerencias del mando", "hide_gamepad_hints")
	_check("Ocultar cursor del mando", "hide_gamepad_cursor")
	_check("Intercambiar botones A/B", "swap_ab")
	_check("Intercambiar botones X/Y", "swap_xy")
	_title("Reasignación de botones")
	var remap: Dictionary = settings.get("remap", {})
	for action in REMAP_ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = str(REMAP_LABELS[action])
		row.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 20
		spin.value = int(remap.get(action, 0))
		spin.value_changed.connect(func(v: float):
			remap[action] = int(v)
			_set_setting("remap", remap))
		row.add_child(spin)
		_right.add_child(row)
	var reset := Button.new()
	reset.text = "Restablecer configuración predeterminada"
	reset.pressed.connect(func():
		settings = SettingsRefactor.reset_settings()
		_show_section(1))
	_right.add_child(reset)


func _show_touch() -> void:
	_title("Táctil")
	_option("Modo de control", "control_mode", CONTROL_MODES, CONTROL_MODE_KEYS)
	_option("Visibilidad del joystick", "joystick_visibility", JOY_VIS, JOY_VIS_KEYS)
	_check("Invertir la cámara del eje Y", "invert_y")
	_check("Saltar automáticamente", "auto_jump")
	_check("Correr de manera sencilla (joystick al 100%)", "easy_sprint")
	_check("Acceso al inventario para zurdos ([...] a la izquierda)", "left_handed_inventory")
	_check("Botón de perspectiva de cámara", "perspective_button")
	_slider("Sensibilidad de la cámara", "camera_sensitivity", 0, 100)
	_slider("Tamaño de botón", "button_size", 0.5, 1.5, 0.1)
	_slider("Opacidad de botones", "button_opacity", 0.3, 1.0, 0.05)
	_check("Mover botones (editor TouchHud)", "hud_edit_mode")
	_slider("Retraso en la ruptura de bloques (s)", "break_delay", 0.0, 1.0, 0.05)


func _show_audio() -> void:
	_title("Audio y Voces")
	_note("Las voces son clips .ogg grabados por la familia. Si un clip no existe, el juego muestra el texto y sigue en silencio: nunca inventa una voz.")
	_slider("Volumen de voces", "voice_volume", 0.0, 1.0, 0.05)
	_slider("Volumen de música", "music_volume", 0.0, 1.0, 0.05)


func _show_world() -> void:
	_title("Mundo y Semilla")
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "Semilla (texto o número):"
	row.add_child(label)
	_seed_field = LineEdit.new()
	_seed_field.text = str(settings.get("seed_text", ""))
	_seed_field.placeholder_text = "Ej. MUNDO-PAPA-HIJO-777 (vacío = aleatoria al crear)"
	_seed_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_field.text_changed.connect(func(t: String): _set_setting("seed_text", t))
	row.add_child(_seed_field)
	_right.add_child(row)
	var random_btn := Button.new()
	random_btn.text = "Generar semilla aleatoria"
	random_btn.pressed.connect(func():
		var s := WorldSeedManager.random_seed_text()
		_set_setting("seed_text", s)
		if _seed_field != null:
			_seed_field.text = s)
	_right.add_child(random_btn)
	_option("Bioma", "biome", BIOMES, BIOME_KEYS)
	_slider("Radio de terreno (bloques)", "render_radius", 12, 40)
	_note("La semilla alimenta el ruido del terreno: el mismo texto genera siempre el mismo mundo, en el celular y en el televisor.")


func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(700, 0)
	_right.add_child(label)
