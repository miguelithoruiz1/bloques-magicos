extends Control
## Menú inicial de Bloques Mágicos (Fase 2): «Jugar libre», «Ciudad
## libre», «Espacio libre» (1.11.0) y «Mundos».
## Navegable con mando (cruceta + OK), táctil y teclado. La voz lee cada
## pantalla y cada botón al enfocarlo: el niño no necesita saber leer.
## Pantallas: principal → mundos → niveles. Atrás (ui_cancel) retrocede.
## El progreso (estrellas y desbloqueos) se lee de user://progreso.json.

const LevelsData := preload("res://scripts/levels_data.gd")
const ProgressSave := preload("res://scripts/progress_save.gd")
const AudioBank := preload("res://scripts/audio_bank.gd")

var _pantalla := "principal" # principal | mundos | niveles
var _mundo_sel := ""
var _progreso: Dictionary = {}
var _tts_voice := ""
var _tts_lang := ""
var _tts_name := ""
var _audio_bank = null

var _title_label: Label
var _buttons_box: VBoxContainer
var _voice_label: Label
var _hint_label: Label


func _ready() -> void:
	_audio_bank = AudioBank.new()
	add_child(_audio_bank)
	_init_tts()
	_progreso = ProgressSave.load_progress()
	_build_ui()
	_show_principal()


func _unhandled_input(_event: InputEvent) -> void:
	# Atrás retrocede una pantalla (en la principal no hace nada).
	if Input.is_action_just_pressed("ui_cancel"):
		match _pantalla:
			"niveles":
				_show_mundos()
			"mundos":
				_show_principal()


# ---------------------------------------------------------------------------
# Construcción de la interfaz
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.30, 0.58, 0.95)
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
	vbox.add_child(_title_label)

	_buttons_box = VBoxContainer.new()
	_buttons_box.add_theme_constant_override("separation", 16)
	_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_buttons_box)

	# Diagnóstico de voz (F2.1): aquí se muestra qué voz eligió el sistema
	# al pulsar «Probar voz», o que el TV no tiene voces.
	_voice_label = Label.new()
	_voice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_voice_label.text = ""
	_style_label(_voice_label, 20)
	vbox.add_child(_voice_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.text = "Mando: cruceta + OK · Teclado: flechas + Enter · Táctil: toca el botón · Atrás para volver"
	_style_label(_hint_label, 20)
	vbox.add_child(_hint_label)


func _style_label(label: Label, font_size: int) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.45))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)


## Botón grande de menú. Si "habilitado" es false, queda visible con un
## candado pero fuera de la navegación con mando.
func _add_button(texto: String, habilitado: bool, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(640, 96)
	b.add_theme_font_size_override("font_size", 34)
	if habilitado:
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(accion)
		b.focus_entered.connect(_on_button_focused.bind(texto))
	else:
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = true
		b.add_theme_color_override("font_disabled_color", Color(0.85, 0.85, 0.85))
	_buttons_box.add_child(b)
	return b


## Conecta la navegación con cruceta entre los botones habilitados y
## deja el foco en el primero (la voz lo lee al enfocarse).
func _finish_buttons() -> void:
	var nav: Array = []
	for child in _buttons_box.get_children():
		# 1.2.2: al cambiar de pantalla, _clear_buttons() marca los botones
		# viejos con queue_free pero siguen siendo hijos hasta el final del
		# cuadro. Sin este filtro, nav[0] era un botón viejo, grab_focus()
		# caía en él, se borraba y el foco se perdía: la cruceta no
		# respondía en «Mundos» ni en «Niveles». No se usa free() directo
		# porque el botón que emite pressed aún está en su señal.
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
		# F2.2: la lista es vertical; ◀ ▶ no deben saltar a otro botón
		# por la búsqueda espacial automática de Godot: se quedan quietos.
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
		b.focus_previous = b.get_path_to(prev)
		b.focus_next = b.get_path_to(nxt)
	if not nav.is_empty():
		(nav[0] as Button).grab_focus()


func _clear_buttons() -> void:
	for child in _buttons_box.get_children():
		(child as Node).queue_free()


# ---------------------------------------------------------------------------
# Pantallas
# ---------------------------------------------------------------------------

func _show_principal() -> void:
	_pantalla = "principal"
	_clear_buttons()
	_title_label.text = "Bloques Mágicos"
	_add_button("Jugar libre", true, _jugar_libre)
	_add_button("🏙️ Ciudad libre", true, _jugar_libre_mundo.bind("ciudad"))
	_add_button("🚀 Espacio libre", true, _jugar_libre_mundo.bind("espacio"))
	var total := ProgressSave.stars_total(_progreso)
	var total_max := 0
	for m in LevelsData.MUNDOS:
		total_max += LevelsData.get_niveles(String(m["id"])).size()
	_add_button("Mundos  ⭐ %d/%d" % [total, total_max], true, _show_mundos)
	_add_button("🔊 Probar voz", true, _probar_voz)
	_finish_buttons()
	speak("Bloques Mágicos. Elige: jugar libre o mundos.", "frase_elige_modo")


func _show_mundos() -> void:
	_pantalla = "mundos"
	_clear_buttons()
	_title_label.text = "Elige un mundo"
	for m in LevelsData.MUNDOS:
		var id := String(m["id"])
		var max_estrellas := LevelsData.get_niveles(id).size()
		var texto := "%s %s  ⭐ %d/%d" % [String(m["emoji"]), String(m["nombre"]), ProgressSave.stars_for(_progreso, id), max_estrellas]
		_add_button(texto, true, _show_niveles.bind(id))
	_add_button("Atrás", true, _show_principal)
	_finish_buttons()
	speak("Elige un mundo.", "frase_elige_mundo")


func _show_niveles(mundo_id: String) -> void:
	_pantalla = "niveles"
	_mundo_sel = mundo_id
	_clear_buttons()
	var mundo := LevelsData.get_mundo(mundo_id)
	_title_label.text = "%s %s" % [String(mundo.get("emoji", "")), String(mundo.get("nombre", ""))]
	for i in range(LevelsData.get_niveles(mundo_id).size()):
		var hecho := ProgressSave.is_completed(_progreso, mundo_id, i)
		var abierto := ProgressSave.is_unlocked(_progreso, mundo_id, i)
		var texto := "Nivel %d" % (i + 1)
		if hecho:
			texto += "  ⭐"
		elif not abierto:
			texto += "  🔒"
		_add_button(texto, abierto, _empezar_nivel.bind(mundo_id, i))
	_add_button("Atrás", true, _show_mundos)
	_finish_buttons()
	speak("Elige un nivel.", "frase_elige_nivel")


func _on_button_focused(texto: String) -> void:
	speak(texto)


func _jugar_libre() -> void:
	GameState.modo = "libre"
	GameState.mundo = ""
	GameState.nivel = 0
	get_tree().change_scene_to_file("res://main.tscn")


## 1.11.0: mundos libres nuevos (Ciudad y Espacio). Como la pradera,
## cada uno tiene su propio guardado (ver world_save.gd).
func _jugar_libre_mundo(mundo_id: String) -> void:
	GameState.modo = "libre"
	GameState.mundo = mundo_id
	GameState.nivel = 0
	get_tree().change_scene_to_file("res://main.tscn")


func _empezar_nivel(mundo_id: String, indice: int) -> void:
	GameState.modo = "nivel"
	GameState.mundo = mundo_id
	GameState.nivel = indice
	get_tree().change_scene_to_file("res://main.tscn")


# ---------------------------------------------------------------------------
# Voz (TTS del sistema), igual que en main.gd
# ---------------------------------------------------------------------------

func _init_tts() -> void:
	var voices := DisplayServer.tts_get_voices()
	var fallback_id := ""
	var fallback_lang := ""
	var fallback_name := ""
	for v in voices:
		var vid := String(v.get("id", ""))
		if vid == "":
			continue
		if fallback_id == "":
			fallback_id = vid
			fallback_lang = String(v.get("language", ""))
			fallback_name = String(v.get("name", ""))
		if String(v.get("language", "")).begins_with("es"):
			_tts_voice = vid
			_tts_lang = String(v.get("language", ""))
			_tts_name = String(v.get("name", ""))
			break
	if _tts_voice == "":
		_tts_voice = fallback_id
		_tts_lang = fallback_lang
		_tts_name = fallback_name


## F2.1: frase de prueba + diagnóstico visible de la voz elegida.
func _probar_voz() -> void:
	if _tts_voice == "":
		_voice_label.text = "Sin voces en este TV: el juego muestra las palabras pero no puede hablar."
		return
	var nombre := _tts_name if _tts_name != "" else _tts_voice
	_voice_label.text = "Voz: %s (%s)" % [nombre, _tts_lang]
	speak("¡Hola! Soy Bloques Mágicos. ¿Me escuchas?", "frase_hola")


## F2.2: igual que en main.gd — clip familiar primero, TTS si no hay
## clip, silencio si no hay voces. Los textos de los botones al enfocar
## siguen por TTS porque son dinámicos (nombres de mundos, niveles).
func speak(text: String, clip := "") -> void:
	if clip != "" and _audio_bank != null and _audio_bank.play_clip(clip):
		return
	if _tts_voice == "":
		return
	DisplayServer.tts_speak(text, _tts_voice, 50, 1.0, 1.0, 0, true)
