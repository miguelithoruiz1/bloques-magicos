extends Node3D
## RefactorMain — escena principal de la variante refactorizada.
##
## Cableado 4.0 (hub.tscn ya no es el camino de la Plaza desde aqui):
##   VoxelWorldGenerator  → terreno por semilla + bloques
##   PlayerBlocky         → movimiento/cámara (ver su convención)
##   UIController         → HUD Minecraft (hotbar, inventario, TV)
##   GameModeManager      → Creativo / Supervivencia, voces, retos
##   RefactorController   → Atrás nunca cierra la app por accidente
##   SettingsScene        → Ajustes (se instancia al pulsar Ajustes)
##
## 4.0: la Plaza Central vive DENTRO del mundo voxel
## (CentralPlaza, en el punto de aparicion). «Volver a la Plaza»
## ya NO cambia a hub.tscn: teletransporta al spawn del mundo
## actual. hub.tscn / main.tscn de 1.15.0 siguen en el repo,
## pero ya no son el camino de la Plaza desde este mundo.
## AdaptiveHUD 4.0: se instancia y se conecta para telemetria
## (FPS/vitales solo con modo desarrollador), prompt por
## dispositivo y bloqueo de stats en Explorador. Sus filas de
## hotbar/botones gigantes quedan ocultas en 4.0 porque
## UIController 3.0.2 sigue llevando el joystick, la hotbar y
## las columnas de acciones (AdaptiveHUD aun no tiene joystick
## ni paneles de taller/misiones/LAN); ocultar UIController
## romperia el movimiento en movil. La sustitucion visual
## completa es el siguiente paso, no un cambio silencioso aqui.
##
## Mira: el terreno no tiene cuerpos de colisión, así que la mira
## usa ray-marching sobre los datos de bloques (no sobre física):
## se avanza en pasos de 0.25 desde la cámara hasta 6 bloques y
## el primer bloque sólido es el apuntado. Colocar pone el bloque
## en la celda anterior al impacto (la cara libre).

const VoxelWorldGeneratorScript := preload("res://scripts/refactor/voxel_world_generator.gd")
const GameModeManagerScript := preload("res://scripts/refactor/game_mode_manager.gd")

var _world: VoxelWorldGenerator = null
var _player: PlayerBlocky = null
var _ui: UIController = null
var _modes: GameModeManager = null
var _controller: Node = null
var _settings: Dictionary = {}
var _ui_layer: CanvasLayer = null
var _title_panel: Control = null
var _play_btn: Button = null
var _pause_first_btn: Button = null
var _pause_panel: Control = null
# 4.0.1: nodo de Ajustes abierto (si lo hay) y marca de tiempo del
# último Atrás, para que un mismo toque no se procese dos veces
# (evento ui_cancel + notificación GO_BACK del sistema).
var _settings_node: Control = null
var _last_back_ms := 0
var _message_label: Label = null
var _message_timer := 0.0
var _seed_field: LineEdit = null
var _name_field: LineEdit = null
var _mode_option: OptionButton = null
var _age_option: OptionButton = null
var _hat_option: OptionButton = null
var _shirt_option: OptionButton = null
var _animals: Array = []
var _started := false
# 3.0: misiones, niveles, mundo vivo y multiedad.
var _quests: QuestSystem = null
var _levels: LevelSystem = null
var _birds: AmbientBirds = null
var _weather: WeatherSystem = null
var _day := 1
var _prev_time := 10.0
var _spawn_pos := Vector3.ZERO
var _age_band := "5-7"
var _stats_timer := 0.0
# 3.0: horda y montura.
var _horde: HordeSystem = null
var _mounted_animal: FriendlyAnimal = null
var _was_night := false
# 3.0: vitales y calor cercano (se recalcula 2×/s).
var _vitals: VitalsSystem = null
var _near_heat := false
# 3.0: personaje separado del mundo.
var _character: CharacterData = null
var _char_save_timer := 0.0
# 3.0: música procedural por bioma y foley.
var _music: MusicSystem = null
# 4.0: perfil, HUD adaptativo, Plaza, neurociencia y noche.
var _profile: CognitiveProfile = null
var _adaptive_hud: AdaptiveHUD = null
var _plaza: CentralPlaza = null
var _neuro: NeuroManager = null
var _night: NightLighting = null
# 3.0: multijugador LAN.
var _lan: LanNet = null
var _remote_avatars := {}
var _remote_names := {}
var _snapshot_count := 0


func _ready() -> void:
	# 4.0.1: Atrás NUNCA cierra la app por defecto. Esto se pone
	# aquí, en la escena principal, y no solo en RefactorController,
	# para que valga en título, mundo, pausa y Ajustes por igual.
	get_tree().set_auto_accept_quit(false)
	_settings = SettingsRefactor.load_settings()
	# 4.0: el perfil es la fuente de verdad; los ajustes son
	# su espejo (SettingsScene actualiza ambos al cambiarlos).
	_profile = CognitiveProfile.load_or_create()
	_settings["perfil_cognitivo"] = _profile.profile_name()
	_settings["modo_desarrollador"] = _profile.developer_mode
	_settings["edad_jugador"] = _profile.age_years
	match _profile.profile:
		CognitiveProfile.Profile.EXPLORER:
			_age_band = "5-7"
		CognitiveProfile.Profile.BUILDER:
			_age_band = "8-12"
		_:
			_age_band = "13+"
	_settings["age_band"] = _age_band
	# 4.0: nuevos sistemas, antes de cablear senales.
	_adaptive_hud = AdaptiveHUD.new()
	_adaptive_hud.profile = _profile
	add_child(_adaptive_hud)
	_adaptive_hud.set_hud_rows_visible(false)
	_neuro = NeuroManager.new()
	_neuro.profile = _profile
	add_child(_neuro)
	_night = NightLighting.new()
	add_child(_night)
	_plaza = CentralPlaza.new()
	_plaza.profile = _profile
	add_child(_plaza)
	_world = get_node_or_null("VoxelWorld") as VoxelWorldGenerator
	_player = get_node_or_null("PlayerBlocky") as PlayerBlocky
	_ui = get_node_or_null("TouchAndTVControls") as UIController
	_modes = get_node_or_null("GameModeManager") as GameModeManager
	_controller = get_node_or_null("RefactorController")
	_build_overlays()
	_wire_signals()
	# 3.0: sistemas nuevos, sin tocar la escena vieja.
	_quests = QuestSystem.new()
	add_child(_quests)
	_quests.load()
	_levels = LevelSystem.new()
	add_child(_levels)
	_levels.load()
	_birds = AmbientBirds.new()
	add_child(_birds)
	_weather = WeatherSystem.new()
	add_child(_weather)
	_horde = HordeSystem.new()
	_horde.ground_func = _column_top
	_horde.attack_player.connect(_on_creature_hit)
	add_child(_horde)
	_vitals = VitalsSystem.new()
	_vitals.died.connect(_on_player_died)
	_character = CharacterData.new()
	_character.load_from_file()
	_character.apply_to_vitals(_vitals)
	if _player != null:
		_player.speed_mult = _character.speed_mult()
	_music = MusicSystem.new()
	add_child(_music)
	_lan = LanNet.new()
	add_child(_lan)
	_lan.host_found.connect(_on_lan_host_found)
	_lan.join_accepted.connect(_on_lan_accepted)
	_lan.join_rejected.connect(func(reason: String): _show_message(reason))
	_lan.peer_joined.connect(_on_lan_peer_joined)
	_lan.peer_left.connect(_on_lan_peer_left)
	_lan.peer_state.connect(_on_lan_peer_state)
	_lan.block_received.connect(_on_lan_block)
	_lan.snapshot_received.connect(_on_lan_snapshot)
	_lan.set_state_sender(func() -> Dictionary:
		if _player == null:
			return {}
		var p := _player.global_position
		return {"pos": [p.x, p.y, p.z], "yaw": _player.yaw})
	if _player != null:
		_player.ground_top_func = _column_top
		_player.camera_sensitivity = SettingsRefactor.camera_sensitivity_factor(_settings)
		_player.invert_y = bool(_settings.get("invert_y", false))
	if _controller != null and _controller.has_method("set_in_world"):
		_controller.set_in_world(false)


func _build_overlays() -> void:
	# Los Control deben colgar de un CanvasLayer, no del Node3D
	# raíz (bajo un Node3D no se dibujan). Toda la UI de esta
	# escena cuelga de _ui_layer.
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 20
	add_child(_ui_layer)
	# Mensaje flotante (voces ausentes, retos, Feynman).
	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.offset_bottom = 48.0
	_message_label.visible = false
	_ui_layer.add_child(_message_label)
	# Título: modo + semilla + nombre, antes de entrar al mundo.
	_title_panel = _panel()
	var vbox := VBoxContainer.new()
	_title_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Bloques Mágicos — 3.0"
	vbox.add_child(title)
	var note := Label.new()
	note.text = "4.0: Plaza Central dentro del mundo voxel, perfil cognitivo, noche visible y APK por GitHub Actions en la rama refactor-4.0."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(note)
	_mode_option = OptionButton.new()
	_mode_option.add_item("Creativo Educativo")
	_mode_option.add_item("Supervivencia Cognitiva")
	vbox.add_child(_mode_option)
	# 3.0 multiedad: la banda abre palabras y operaciones.
	_age_option = OptionButton.new()
	_age_option.add_item("Edad: 5-7 años")
	_age_option.add_item("Edad: 8-12 años")
	_age_option.add_item("Edad: 13+ años")
	var saved_band: String = str(_settings.get("age_band", "5-7"))
	_age_option.selected = ["5-7", "8-12", "13+"].find(saved_band)
	if _age_option.selected < 0:
		_age_option.selected = 0
	vbox.add_child(_age_option)
	# Avatar 2.0: sombrero y camiseta, guardados en avatar.json.
	var saved_avatar := AvatarCustom.load_avatar()
	_hat_option = OptionButton.new()
	for label in AvatarCustom.HAT_LABELS:
		_hat_option.add_item("Sombrero: " + label)
	_hat_option.selected = maxi(0, AvatarCustom.HATS.find(str(saved_avatar["hat"])))
	vbox.add_child(_hat_option)
	_shirt_option = OptionButton.new()
	for label in ["Azul", "Rojo", "Verde", "Amarillo"]:
		_shirt_option.add_item("Camiseta: " + label)
	_shirt_option.selected = maxi(0, AvatarCustom.SHIRTS.find(str(saved_avatar["shirt"])))
	vbox.add_child(_shirt_option)
	_name_field = LineEdit.new()
	_name_field.text = str(_settings.get("world_name", "MundoRefactor"))
	_name_field.placeholder_text = "Nombre del mundo"
	vbox.add_child(_name_field)
	_seed_field = LineEdit.new()
	_seed_field.text = str(_settings.get("seed_text", ""))
	_seed_field.placeholder_text = "Semilla (vacío = aleatoria)"
	vbox.add_child(_seed_field)
	var play := Button.new()
	play.text = "Jugar"
	play.pressed.connect(_start_world)
	vbox.add_child(play)
	_play_btn = play
	var settings_btn := Button.new()
	settings_btn.text = "Ajustes"
	settings_btn.pressed.connect(_open_settings)
	vbox.add_child(settings_btn)
	var plaza_btn := Button.new()
	plaza_btn.text = "Volver a la Plaza"
	plaza_btn.pressed.connect(func(): _go_to_plaza())
	vbox.add_child(plaza_btn)
	_ui_layer.add_child(_title_panel)
	# 3.0.2 TV: sin foco inicial, la cruceta del mando
	# no selecciona nada en el título. El grab_focus
	# va DESPUÉS de entrar al árbol o no hace nada.
	play.grab_focus()
	# Pausa.
	_pause_panel = _panel()
	_pause_panel.visible = false
	var pbox := VBoxContainer.new()
	_pause_panel.add_child(pbox)
	for data in [["Continuar", func(): _set_pause(false)], ["Ajustes", func(): _open_settings()], ["Guardar mundo", func(): _save_world()], ["Exportar mundo (copiar código)", func(): _export_world()], ["Importar mundo (desde portapapeles)", func(): _import_world()], ["Volver a la Plaza", func(): _go_to_plaza()]]:
		var b := Button.new()
		b.text = data[0]
		b.pressed.connect(data[1])
		pbox.add_child(b)
		if _pause_first_btn == null:
			_pause_first_btn = b
	_ui_layer.add_child(_pause_panel)


func _panel() -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 420)
	# Con preset CENTRO los offsets mandan: sin ellos el panel
	# quedaría de 0x0 aunque tenga minimum_size.
	panel.offset_left = -350.0
	panel.offset_top = -210.0
	panel.offset_right = 350.0
	panel.offset_bottom = 210.0
	return panel


func _wire_signals() -> void:
	# 4.0: AdaptiveHUD (telemetria/prompt). Sus botones de
	# accion estan ocultos en 4.0 (ver nota en la cabecera),
	# asi que estas senales solo se dispararan cuando sus
	# filas se muestren en una version posterior.
	if _adaptive_hud != null:
		_adaptive_hud.place_pressed.connect(_on_place)
		_adaptive_hud.remove_pressed.connect(_on_remove)
		_adaptive_hud.jump_pressed.connect(func():
			if _player != null:
				_player.jumping = true)
		_adaptive_hud.pause_pressed.connect(func(): _set_pause(true))
		_adaptive_hud.perspective_pressed.connect(func():
			if _player != null:
				_player.cycle_perspective())
	if _neuro != null:
		_neuro.srs_due_ready.connect(func(_items: Array):
			_show_message("Tienes retos para repasar hoy."))
		_neuro.feynman_requested.connect(func(prompt_text: String, _steps: Array):
			_show_message(prompt_text)
			if _player != null:
				_player.set_perspective(PlayerBlocky.Perspective.SECOND))
		_neuro.feynman_completed.connect(func(_n: int):
			_show_message("¡Le enseñaste a tu mascota!"))
		_neuro.pomodoro_focus_ended.connect(func():
			_show_message("¡Pausa activa! Muévete un poco para recargar cristales."))
		_neuro.active_break_requested.connect(func(activity: String):
			_show_message(activity))
		_neuro.feedback_shown.connect(func(text: String, _kind: String):
			_show_message(text))
		_neuro.night_transition_requested.connect(func(is_night: bool):
			_show_message("Ya es de noche: el cerebro consolida lo aprendido." if is_night else "Amaneció en el mundo."))
	if _plaza != null:
		_plaza.portal_entered.connect(_on_plaza_entered)
		_plaza.portal_locked.connect(_on_plaza_locked)
	if _ui == null:
		return
	_ui.move_input_changed.connect(func(v: Vector2):
		if _player != null:
			_player.set_move_input(v))
	_ui.jump_pressed.connect(func():
		if _player != null:
			_player.jumping = true)
	_ui.crouch_pressed.connect(func():
		if _player != null:
			_player.crouching = true)
	_ui.crouch_released.connect(func():
		if _player != null:
			_player.crouching = false)
	_ui.camera_dragged.connect(func(rel: Vector2):
		if _player != null:
			_player.add_camera_drag(rel))
	_ui.place_pressed.connect(_on_place)
	_ui.remove_pressed.connect(_on_remove)
	_ui.perspective_pressed.connect(func():
		if _player != null:
			_player.cycle_perspective())
	_ui.pause_pressed.connect(func(): _set_pause(true))
	_ui.mount_pressed.connect(_on_mount)
	_ui.attack_pressed.connect(_on_attack)
	_ui.dodge_pressed.connect(_on_dodge)
	_ui.forge_pressed.connect(_on_forge)
	_ui.stations_pressed.connect(_on_stations)
	_ui.character_pressed.connect(_on_character)
	_ui.potion_pressed.connect(_on_potion)
	_ui.food_pressed.connect(_on_food)
	_ui.forge_craft_requested.connect(_on_forge_craft)
	_ui.station_craft_requested.connect(_on_station_craft)
	_ui.race_selected.connect(_on_race_selected)
	_ui.lan_pressed.connect(_on_lan)
	_ui.lan_host_pressed.connect(_on_lan_host)
	_ui.lan_search_pressed.connect(_on_lan_search)
	_ui.lan_join_pressed.connect(_on_lan_join)
	_ui.lan_leave_pressed.connect(_on_lan_leave)
	_ui.workshop_pressed.connect(func():
		if _ui != null:
			_ui.show_workshop(Workshop.recipes()))
	_ui.quests_pressed.connect(_show_quest_panel)
	_ui.craft_requested.connect(_on_craft)
	if _controller != null and _controller.has_signal("back_pressed_handled"):
		_controller.back_pressed_handled.connect(_on_back_action)
	if _modes != null:
		_modes.message_shown.connect(_show_message)
		_modes.word_invoked.connect(func(_word: String):
			if _quests != null:
				_quests.on_word()
			if _levels != null:
				_levels.gain_exp(10)
			if _neuro != null:
				_neuro.record_hit("palabra_" + _word)
				_neuro.feedback_for(true, "¡Buena palabra!"))
		_modes.math_solved.connect(func(_expr: String, _value: int):
			if _quests != null:
				_quests.on_math()
			if _levels != null:
				_levels.gain_exp(10)
			if _neuro != null:
				_neuro.record_hit("suma_" + _expr)
				_neuro.feedback_for(true, "¡Buena cuenta!"))
		_modes.feynman_request.connect(func(text: String):
			_show_message(text)
			if _player != null:
				_player.set_perspective(PlayerBlocky.Perspective.SECOND))
	if _quests != null:
		_quests.quest_completed.connect(func(_id: String, quest_title: String):
			_show_message("¡Misión completada: " + quest_title + "! +15 EXP ⭐")
			if _levels != null:
				_levels.gain_exp(QuestSystem.STAR_EXP)
			if _ui != null:
				_ui.set_progress(_quests.stars()))
	if _levels != null:
		_levels.level_up.connect(func(new_level: int):
			_show_message("¡Nivel " + str(new_level) + "!")
			if _quests != null:
				_quests.on_level(new_level))


func _on_back_action(action: String) -> void:
	# Respaldo del controlador: en 4.0.1 el Atrás lo decide
	# handle_system_back, pero si el controlador emite
	# open_pause, se abre la pausa (nunca hub legacy, nunca
	# quit). back_to_plaza solo guarda, por compatibilidad.
	if action == "open_pause":
		_set_pause(true)
	if action == "back_to_plaza":
		_save_world()


func _set_pause(value: bool) -> void:
	if _pause_panel != null:
		_pause_panel.visible = value
	get_tree().paused = value
	if value:
		if _pause_first_btn != null:
			_pause_first_btn.grab_focus()
	else:
		get_viewport().gui_release_focus()


## 4.0.1 Atrás global, un solo manejador: refactor_main decide
## y RefactorController solo le reenvía la notificación del
## sistema. Antes había dos lógicas distintas (aquí y en el
## controlador), y el controlador al cerrar un panel solo lo
## ocultaba sin despausar ni liberar, y sin panel en mundo
## saltaba a hub.tscn legacy. Resultado en el teléfono: en
## cualquier parte, Atrás sacaba de la aplicación.
## Pila, de dentro hacia fuera:
##   1. Ajustes abierto -> se cierra bien (closed, se libera,
##      se recargan ajustes) y se vuelve a donde estaba.
##   2. Modal abierto (inventario, etc.) -> se cierra.
##   3. Pausa abierta -> se reanuda (despausa de verdad).
##   4. En mundo, sin panel -> se abre la pausa. NUNCA quit().
##   5. En título -> diálogo de salida; solo su botón Salir
##      llama a quit(). NUNCA quit() directo.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		handle_system_back()
		get_viewport().set_input_as_handled()


func handle_system_back() -> void:
	# Un mismo toque de Atrás puede llegar como ui_cancel y
	# como notificación del sistema: el segundo, si llega en
	# menos de 300 ms, se ignora para no abrir y cerrar la
	# pausa en el mismo toque.
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_back_ms < 300:
		return
	_last_back_ms = now_ms
	if _settings_node != null:
		_close_settings_node()
		get_viewport().gui_release_focus()
		return
	if _ui != null and _ui.close_open_modal():
		get_viewport().gui_release_focus()
		return
	if _pause_panel != null and _pause_panel.visible:
		_set_pause(false)
		return
	if _started:
		_set_pause(true)
		return
	if _controller != null and _controller.has_method("show_exit_dialog"):
		_controller.show_exit_dialog()
		return
	# Sin controlador: en título no se sale solo; se abre la
	# pausa no tiene sentido aquí, así que no se hace nada.


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		handle_system_back()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		if _title_panel != null and _title_panel.visible:
			return
		if _started and (_pause_panel == null or not _pause_panel.visible) and _ui != null and not _ui.has_open_modal():
			_on_place()


func _start_world() -> void:
	var seed_text := _seed_field.text.strip_edges() if _seed_field != null else ""
	if seed_text == "":
		seed_text = WorldSeedManager.random_seed_text()
		_seed_field.text = seed_text
	var world_name := _name_field.text.strip_edges() if _name_field != null else "MundoRefactor"
	_settings["seed_text"] = seed_text
	_settings["world_name"] = world_name
	# 3.0: banda de edad del título (palabras y operaciones).
	var bands: Array[String] = ["5-7", "8-12", "13+"]
	_age_band = bands[_age_option.selected] if _age_option != null and _age_option.selected >= 0 and _age_option.selected < bands.size() else "5-7"
	_settings["age_band"] = _age_band
	if _profile != null:
		_profile.set_profile_from_band(_age_band)
		_settings["perfil_cognitivo"] = _profile.profile_name()
		_settings["modo_desarrollador"] = _profile.developer_mode
	SettingsRefactor.save_settings(_settings)
	var seed := WorldSeedManager.seed_from_string(seed_text)
	var biome := str(_settings.get("biome", "croma_isla"))
	if _world != null:
		_world.generate(seed, biome, int(_settings.get("render_radius", 20)))
		var saved := WorldSeedManager.load_world(world_name, seed_text)
		if not saved.is_empty():
			_world.apply_modified(saved.get("modified_blocks", {}))
	if _world != null and _night != null:
		_night.setup(_world.get_node_or_null("Ambiente") as WorldEnvironment, _world.get_node_or_null("Sol") as DirectionalLight3D)
	if _neuro != null:
		_neuro.start_pomodoro()
		_neuro.notify_due()
	if _modes != null:
		_modes.setup(_world)
		_modes.set_mode(GameModeManager.Mode.CREATIVE if _mode_option.selected == 0 else GameModeManager.Mode.SURVIVAL)
	if _player != null:
		var h := _world.terrain_height(0, 0) if _world != null else 2
		_player.global_position = Vector3(0.5, float(h) + 2.0, 0.5)
		_spawn_pos = _player.global_position
		# 4.0: la Plaza Central nace en el punto de aparicion.
		if _plaza != null:
			_plaza.position = _spawn_pos
			_plaza.setup(_profile)
		_prev_time = _modes.time_of_day if _modes != null else 10.0
		if _ui != null and _world != null:
			_ui.setup_minimap(_world)
		if _modes != null:
			_player.flying = _modes.mode == GameModeManager.Mode.CREATIVE
		# Avatar 2.0 elegido en el título.
		var hat := "explorador"
		if _hat_option != null and _hat_option.selected >= 0 and _hat_option.selected < AvatarCustom.HATS.size():
			hat = AvatarCustom.HATS[_hat_option.selected]
		var shirt := "azul"
		if _shirt_option != null and _shirt_option.selected >= 0 and _shirt_option.selected < AvatarCustom.SHIRTS.size():
			shirt = AvatarCustom.SHIRTS[_shirt_option.selected]
		AvatarCustom.save_avatar(hat, shirt)
		_player.apply_avatar(hat, AvatarCustom.shirt_color(shirt))
		_spawn_animals()
	_title_panel.visible = false
	get_viewport().gui_release_focus()
	_started = true
	if _controller != null and _controller.has_method("set_in_world"):
		_controller.set_in_world(true)
	if _controller != null and _controller.has_method("register_panel"):
		_controller.register_panel(_pause_panel)


func _save_world() -> bool:
	if _quests != null:
		_quests.save()
	if _levels != null:
		_levels.save()
	if _world == null or not _started:
		return false
	var ok := WorldSeedManager.save_world(
		str(_settings.get("world_name", "MundoRefactor")),
		str(_settings.get("seed_text", "")),
		str(_settings.get("biome", "croma_isla")),
		_world.modified_blocks)
	# Guardado v2 además del v1 (la v1 sigue mandando): si la
	# v2 falla, el mundo v1 ya está guardado y no se pierde nada.
	if ok and _player != null and _modes != null:
		SaveV2.save_world_v2(
			str(_settings.get("world_name", "MundoRefactor")),
			WorldSeedManager.seed_from_string(str(_settings.get("seed_text", ""))),
			str(_settings.get("seed_text", "")),
			str(_settings.get("biome", "croma_isla")),
			_player.global_position,
			_modes.inventory,
			_world.modified_blocks)
	return ok


## Animales amigos 3.0: las 16 especies en anillo alrededor
## del punto de aparición. Si uno ya existía, se libera
## primero: al reentrar a un mundo no se duplican.
func _spawn_animals() -> void:
	for animal in _animals:
		if animal is Node:
			(animal as Node).queue_free()
	_animals.clear()
	if _world == null or _player == null:
		return
	var species: Array[String] = FriendlyAnimal.all_species()
	for i in range(species.size()):
		var angle: float = float(i) / float(species.size()) * TAU
		var radius: float = 5.0 + float(i % 3) * 2.0
		var start_pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var animal := FriendlyAnimal.new()
		animal.species = species[i]
		animal.ground_func = _column_top
		var h := _world.terrain_height(int(start_pos.x), int(start_pos.z))
		animal.position = Vector3(start_pos.x + 0.5, float(h) + 2.0, start_pos.z + 0.5)
		animal.friend_made.connect(func(species_name: String):
			_show_message("¡Nuevo amigo: " + FriendlyAnimal.display_name(species_name) + "! Te seguirá.")
			if _character != null:
				if _character.pet == "":
					_character.pet = species_name
				_character.gain_skill("doma")
			if _quests != null:
				_quests.on_friend()
			if _levels != null:
				_levels.gain_exp(10))
		animal.attack_player.connect(_on_creature_hit)
		animal.defeated.connect(_on_creature_defeated)
		add_child(animal)
		_animals.append(animal)


func _show_quest_panel() -> void:
	if _ui == null or _quests == null:
		return
	var data: Array[Dictionary] = []
	for q in QuestSystem.QUESTS:
		data.append({
			"title": str(q["title"]), "desc": str(q["desc"]),
			"progress": _quests.progress_of(str(q["id"])),
			"target": int(q["target"]),
			"done": _quests.is_done(str(q["id"])),
		})
	_ui.show_quests(data)


func _on_mount() -> void:
	if _player == null:
		return
	if _mounted_animal != null:
		_mounted_animal.set_mounted(false)
		_mounted_animal = null
		_player.mounted = false
		_show_message("Te bajaste de tu montura.")
		return
	var best: FriendlyAnimal = null
	var best_dist := 4.0
	for animal in _animals:
		if not (animal is FriendlyAnimal):
			continue
		var friend := animal as FriendlyAnimal
		if not friend.tamed or not friend.is_rideable():
			continue
		var dx := friend.global_position.x - _player.global_position.x
		var dz := friend.global_position.z - _player.global_position.z
		var d := sqrt(dx * dx + dz * dz)
		if d < best_dist:
			best_dist = d
			best = friend
	if best == null:
		_show_message("Acércate a un caballo amigo para montar.")
		return
	best.set_mounted(true)
	_mounted_animal = best
	_player.mounted = true
	_show_message("¡Montaste a caballo! Usa el joystick para moverte.")


func _ambient_temp() -> float:
	var biome := ""
	if _world != null:
		biome = _world.biome
	var temp := 50.0
	if biome in ["tundra_nevada", "montana_nevada", "glaciar_eterno", "hielo_eterno", "tundra_azul"]:
		temp = 15.0
	elif biome in ["desierto", "desierto_sal", "desierto_obsidiana", "tierras_magma", "volcan_dormido"]:
		temp = 85.0
	if _modes != null and _modes.is_night():
		temp = maxf(0.0, temp - 10.0)
	return temp


func _on_creature_hit(damage: float) -> void:
	if _vitals != null:
		_vitals.damage(damage)


func _on_creature_defeated(species_name: String) -> void:
	for animal in _animals.duplicate():
		if animal is FriendlyAnimal and (animal as FriendlyAnimal).species == species_name and (animal as FriendlyAnimal).dead:
			_animals.erase(animal)
			(animal as Node).queue_free()
			break
	if _character != null:
		_character.coins += 2
		if _character.gain_skill("combate"):
			_show_message("¡Combate nivel %d!" % _character.skill_rank("combate"))
		# Espíritu según el bioma: calor → fuego, frío → hielo,
		# resto → viento (la horda da veneno al caer).
		var biome := _world.biome if _world != null else ""
		if biome in ["desierto", "desierto_sal", "desierto_obsidiana", "tierras_magma", "volcan_dormido"]:
			_character.add_spirit("fuego")
		elif biome in ["tundra_nevada", "montana_nevada", "glaciar_eterno", "hielo_eterno", "tundra_azul"]:
			_character.add_spirit("hielo")
		else:
			_character.add_spirit("viento")
	_show_message("¡Derrotaste a " + FriendlyAnimal.display_name(species_name) + "!")


func _on_player_died() -> void:
	if _mounted_animal != null:
		_mounted_animal.set_mounted(false)
		_mounted_animal = null
	if _player != null:
		_player.mounted = false
		_player.global_position = _spawn_pos + Vector3(0.0, 2.0, 0.0)
	if _horde != null:
		_horde.stop_horde()
	if _vitals != null:
		_vitals.reset()
	_show_message("Te recuperaste en el inicio.")


## Material de forja que da un bloque al minarlo en
## Supervivencia: cualquier tronco → madera, cualquier
## hoja → tela, cualquier roca → piedra, flora → hierba,
## y las menas a su metal. Los ids viejos (3, 4, 5) igual.
func _grant_material(block_id: int) -> void:
	if _character == null:
		return
	if block_id == 186 or (block_id >= 154 and block_id <= 184 and (block_id - 154) % 2 == 0) or block_id == 4:
		_character.add_material("madera")
	elif (block_id >= 155 and block_id <= 185 and (block_id - 155) % 2 == 0) or block_id == 5:
		_character.add_material("tela")
	elif (block_id >= 118 and block_id <= 144) or block_id == 3:
		_character.add_material("piedra")
	elif (block_id >= 214 and block_id <= 238) or block_id == 1:
		_character.add_material("hierba")
	elif block_id == 145:
		_character.add_material("carbon")
	elif block_id == 148:
		_character.add_material("hierro")
	elif block_id == 150:
		_character.add_material("oro")
	elif block_id == 153:
		_character.add_material("cronolita")


func _on_attack() -> void:
	if _player == null:
		return
	var mult := _character.attack_mult() if _character != null else 1.0
	var ppos := _player.global_position
	# Golpe cuerpo a cuerpo: el objetivo agresivo más cercano.
	var best_animal: FriendlyAnimal = null
	var best_d := 3.5
	for animal in _animals:
		if not (animal is FriendlyAnimal):
			continue
		var foe := animal as FriendlyAnimal
		if foe.tamed or foe.dead or foe.temperament != "aggressive":
			continue
		var dx := foe.global_position.x - ppos.x
		var dz := foe.global_position.z - ppos.z
		var d := sqrt(dx * dx + dz * dz)
		if d < best_d:
			best_d = d
			best_animal = foe
	var horde_member := _horde.nearest_member(ppos, 3.5) if _horde != null else null
	var horde_d := 3.5
	if horde_member != null:
		var hx := horde_member.position.x - ppos.x
		var hz := horde_member.position.z - ppos.z
		horde_d = sqrt(hx * hx + hz * hz)
	if best_animal == null and horde_member == null:
		_show_message("No hay nada que golpear cerca.")
		return
	if best_animal != null and (horde_member == null or best_d <= horde_d):
		best_animal.take_damage(25.0 * mult, ppos)
	else:
		var fallen := _horde.damage_at(horde_member.position, 0.6, 25.0 * mult)
		if fallen > 0 and _character != null:
			_character.add_spirit("veneno", fallen)
	# Ataque con maná: onda que golpea todo en 4 bloques.
	# (Objetivos primero, daño después: derrotar borra de
	# _animals y no se puede borrar mientras se itera.)
	if _vitals != null and _vitals.spend_mana(25.0):
		var foes: Array[FriendlyAnimal] = []
		for animal in _animals:
			if not (animal is FriendlyAnimal):
				continue
			var foe := animal as FriendlyAnimal
			if foe.tamed or foe.dead or foe.temperament != "aggressive":
				continue
			var dx := foe.global_position.x - ppos.x
			var dz := foe.global_position.z - ppos.z
			if sqrt(dx * dx + dz * dz) <= 4.0:
				foes.append(foe)
		for foe in foes:
			foe.take_damage(15.0 * mult, ppos)
		if _horde != null:
			var fallen_wave := _horde.damage_at(ppos, 4.0, 15.0 * mult)
			if fallen_wave > 0 and _character != null:
				_character.add_spirit("veneno", fallen_wave)


func _on_dodge() -> void:
	if _player == null or _vitals == null:
		return
	if not _vitals.spend_stamina(25.0):
		_show_message("Sin estamina para esquivar.")
		return
	_vitals.start_iframes(0.5)
	var facing := Vector3(-sin(_player.yaw), 0.0, -cos(_player.yaw))
	_player.dodge_boost = facing * 12.0


func _forge_nearby() -> bool:
	if _world == null or _player == null:
		return false
	var center := Vector3i(floori(_player.global_position.x), floori(_player.global_position.y), floori(_player.global_position.z))
	for dx in range(-4, 5):
		for dy in range(-2, 3):
			for dz in range(-4, 5):
				if _world.get_block(center + Vector3i(dx, dy, dz)) == StationSystem.BLOCK_FORGE:
					return true
	return false


func _on_forge() -> void:
	if _character == null or _ui == null:
		return
	if not _forge_nearby():
		_show_message("Acércate a una forja de escultura. Se fabrica a mano con 4 hierro y 4 piedra.")
		return
	_ui.show_forge(SculptingForge.recipes(), _character.materials, _character.spirits)


func _on_forge_craft(recipe_id: String) -> void:
	if _character == null:
		return
	var recipe := SculptingForge.recipe_by_id(recipe_id)
	var creative := _modes == null or _modes.mode == GameModeManager.Mode.CREATIVE
	var result := SculptingForge.apply_craft(recipe, _character, creative)
	if result.is_empty():
		_show_message("Te faltan materiales para eso.")
		return
	var item := str(result.get("item", ""))
	if item != "":
		_character.equip(item)
		_character.apply_to_vitals(_vitals)
		if _player != null:
			_player.speed_mult = _character.speed_mult()
		_show_message("¡Forjaste %s y la equipaste!" % EquipmentItems.name_of(item))
	else:
		_show_message("¡Fundiste %s ×%d!" % [str(result.get("material", "")), int(result.get("amount", 0))])
	_character.save_to_file()


func _on_stations() -> void:
	if _character == null or _ui == null or _world == null or _player == null:
		return
	var center := Vector3i(floori(_player.global_position.x), floori(_player.global_position.y), floori(_player.global_position.z))
	var nearby := StationSystem.nearby_stations(center, _world.get_block)
	var sections: Array[Dictionary] = []
	for station in StationSystem.stations():
		var station_id := str(station["id"])
		if station_id == "mano" or station_id in nearby:
			sections.append({"station_id": station_id, "station_name": str(station["name"]), "recipes": station["recipes"]})
	_ui.show_stations(sections)


func _on_station_craft(station_id: String, recipe_id: String) -> void:
	if _character == null or _modes == null:
		return
	var recipe := StationSystem.recipe_by_id(station_id, recipe_id)
	var creative := _modes.mode == GameModeManager.Mode.CREATIVE
	var result := StationSystem.apply_craft(recipe, _character, _modes.inventory, creative)
	if result.is_empty():
		_show_message("Te faltan materiales para eso.")
		return
	if result.has("item"):
		var item := str(result["item"])
		_character.equip(item)
		_character.apply_to_vitals(_vitals)
		if _player != null:
			_player.speed_mult = _character.speed_mult()
		_show_message("¡Fabricaste %s y la equipaste!" % EquipmentItems.name_of(item))
	elif result.has("block"):
		_show_message("¡Fabricaste %s!" % VoxelWorldGenerator.block_label(int(result["block"])))
	elif result.has("material"):
		_show_message("¡Conseguiste %s ×%d!" % [str(result["material"]), int(result["amount"])])
	elif result.has("potion"):
		_show_message("¡Poción de %s lista! Pulsa 🧪 para usarla." % str(result["potion"]))
	elif result.has("food"):
		_show_message("¡Comida lista! Pulsa 🍎 para comerla.")
	if station_id == "cooking_pot":
		_character.gain_skill("cocina")
	elif station_id == "alchemy_table":
		_character.gain_skill("alquimia")
	_character.save_to_file()


func _on_character() -> void:
	if _character == null or _ui == null:
		return
	var data := _character.to_dict()
	var info := _character.race_info()
	data["race_name"] = str(info["name"])
	var races: Array[Dictionary] = []
	for race_id in CharacterData.RACES.keys():
		var race_info: Dictionary = CharacterData.RACES[race_id]
		races.append({"id": str(race_id), "name": str(race_info["name"])})
	_ui.show_character(data, races)


func _on_race_selected(race_id: String) -> void:
	if _character == null:
		return
	_character.race = race_id
	_character.apply_to_vitals(_vitals)
	if _player != null:
		_player.speed_mult = _character.speed_mult()
	_character.save_to_file()
	_show_message("Ahora eres %s." % str(_character.race_info()["name"]))


func _on_potion() -> void:
	if _character == null or _vitals == null:
		return
	if _vitals.health < _vitals.max_health and int(_character.potions.get("salud", 0)) > 0:
		_character.potions["salud"] = int(_character.potions["salud"]) - 1
		_vitals.health = minf(_vitals.max_health, _vitals.health + 40.0)
		_show_message("Poción de salud: +40.")
	elif _vitals.mana < VitalsSystem.MAX_MANA and int(_character.potions.get("mana", 0)) > 0:
		_character.potions["mana"] = int(_character.potions["mana"]) - 1
		_vitals.mana = minf(VitalsSystem.MAX_MANA, _vitals.mana + 50.0)
		_show_message("Poción de maná: +50.")
	else:
		_show_message("No tienes pociones. Se fabrican en la mesa de alquimia.")
	_character.save_to_file()


func _on_food() -> void:
	if _character == null or _vitals == null:
		return
	if _character.food <= 0:
		_show_message("No tienes comida. Se cocina en la olla.")
		return
	_character.food -= 1
	_vitals.health = minf(_vitals.max_health, _vitals.health + 20.0)
	_vitals.stamina = minf(VitalsSystem.MAX_STAMINA, _vitals.stamina + 10.0)
	_show_message("Comida: +20 de salud, +10 de estamina.")
	_character.save_to_file()


func _on_lan() -> void:
	if _lan == null or _ui == null:
		return
	if _lan.is_in_game():
		_ui.show_lan({}, true, "Conectado (jugadores en la partida).")
	else:
		_ui.show_lan(_lan.found_hosts, false, "Sin conexión. Crea o busca una partida en tu Wi-Fi.")


func _on_lan_host() -> void:
	if _lan == null or _world == null:
		return
	_lan.host_game("Bloques", _world.seed_value, _world.biome)
	_show_message("Partida creada. Otros en tu Wi-Fi pueden unirse con 🌐.")


func _on_lan_search() -> void:
	if _lan == null or _ui == null:
		return
	_lan.start_discovery()
	_ui.show_lan(_lan.found_hosts, false, "Buscando partidas en tu Wi-Fi...")


func _on_lan_join(ip: String) -> void:
	if _lan == null:
		return
	_lan.join_game(ip)
	_show_message("Uniéndote a la partida...")


func _on_lan_leave() -> void:
	_clear_remote_avatars()
	if _lan != null:
		_lan.leave()
	_show_message("Saliste de la partida.")


func _clear_remote_avatars() -> void:
	for avatar in _remote_avatars.values():
		(avatar as Node).queue_free()
	_remote_avatars.clear()
	_remote_names.clear()


func _on_lan_host_found(ip: String, host_name: String) -> void:
	if _lan != null and _ui != null and not _lan.is_in_game():
		_ui.show_lan(_lan.found_hosts, false, "Partidas encontradas:")


func _on_lan_accepted(player_id: int, seed: int, biome: String) -> void:
	if _world == null or _player == null:
		return
	_world.generate(seed, biome)
	_player.global_position = Vector3(0.0, float(_world.terrain_height(0, 0)) + 2.0, 0.0)
	_snapshot_count = 0
	_show_message("¡Conectado a la partida!")


func _on_lan_peer_joined(player_id: int, peer_name: String) -> void:
	_remote_names[player_id] = peer_name
	if _lan != null and _lan.mode == "host" and _world != null:
		var blocks: Array = []
		for key in _world.modified_blocks.keys():
			var parts := str(key).split(",")
			if parts.size() == 3:
				blocks.append([int(parts[0]), int(parts[1]), int(parts[2]), int(_world.modified_blocks[key])])
		_lan.send_snapshot(player_id, blocks)


func _on_lan_peer_left(player_id: int) -> void:
	if _remote_avatars.has(player_id):
		(_remote_avatars[player_id] as Node).queue_free()
		_remote_avatars.erase(player_id)
	_remote_names.erase(player_id)


func _on_lan_peer_state(player_id: int, state: Dictionary) -> void:
	var pos_arr: Array = state.get("pos", [])
	if pos_arr.size() != 3:
		return
	var target := Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	var yaw := float(state.get("yaw", 0.0))
	if not _remote_avatars.has(player_id):
		var avatar := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = BoxMesh.new()
		(body.mesh as BoxMesh).size = Vector3(0.6, 1.7, 0.6)
		var mat := StandardMaterial3D.new()
		var palette := [Color(1.0, 0.4, 0.4), Color(0.4, 1.0, 0.4), Color(1.0, 0.9, 0.2), Color(0.6, 0.4, 1.0), Color(0.2, 0.8, 1.0), Color(1.0, 0.5, 0.8)]
		mat.albedo_color = palette[player_id % palette.size()]
		body.material_override = mat
		body.position = Vector3(0.0, 0.85, 0.0)
		avatar.add_child(body)
		var label := Label3D.new()
		label.text = str(_remote_names.get(player_id, "Jugador %d" % player_id))
		label.position = Vector3(0.0, 2.1, 0.0)
		avatar.add_child(label)
		avatar.position = target
		add_child(avatar)
		_remote_avatars[player_id] = avatar
	var avatar_node := _remote_avatars[player_id] as Node3D
	avatar_node.set_meta("target", target)
	avatar_node.rotation.y = yaw


func _on_lan_block(cell: Vector3i, block_id: int) -> void:
	if _world != null:
		_world.set_block(cell, block_id, false)


func _on_lan_snapshot(blocks: Array, done: bool) -> void:
	if _world == null:
		return
	for b in blocks:
		var arr: Array = b
		if arr.size() == 4:
			_world.set_block(Vector3i(int(arr[0]), int(arr[1]), int(arr[2])), int(arr[3]), false)
			_snapshot_count += 1
	if done and _snapshot_count > 0:
		_show_message("Mundo del anfitrión sincronizado (%d bloques)." % _snapshot_count)


func _on_craft(recipe_id: String) -> void:
	var recipe: Dictionary = Workshop.recipe_by_id(recipe_id)
	if recipe.is_empty() or _modes == null or _ui == null:
		return
	var creative: bool = _modes.mode == GameModeManager.Mode.CREATIVE
	var gives: int = Workshop.apply_craft(recipe, _modes.inventory, creative)
	if gives < 0:
		_show_message("Te faltan materiales para " + str(recipe["name"]) + ".")
		return
	_ui.set_hotbar_slot(gives)
	if _quests != null:
		_quests.on_craft()
	if _levels != null:
		_levels.gain_exp(10)
	_show_message("¡Fabricaste " + str(recipe["name"]) + "!")


func _export_world() -> void:
	if not _save_world():
		return
	var encoded := WorldSeedManager.export_base64(
		str(_settings.get("world_name", "MundoRefactor")),
		str(_settings.get("seed_text", "")),
		str(_settings.get("biome", "croma_isla")),
		_world.modified_blocks)
	WorldSeedManager.share_to_clipboard(encoded)
	_show_message("Código del mundo copiado (y guardado en user://worlds/export.txt).")


func _import_world() -> void:
	var encoded := DisplayServer.clipboard_get()
	var data := WorldSeedManager.import_base64(encoded)
	if data.is_empty():
		_show_message("El portapapeles no contiene un mundo válido.")
		return
	_settings["world_name"] = str(data.get("name", "Importado"))
	_settings["seed_text"] = str(data.get("seed_text", ""))
	_settings["biome"] = str(data.get("biome", "croma_isla"))
	SettingsRefactor.save_settings(_settings)
	if _world != null:
		_world.generate(int(data.get("seed", 0)), str(data.get("biome", "croma_isla")))
		_world.apply_modified(data.get("modified_blocks", {}))
	_show_message("Mundo importado: " + str(data.get("name", "")))


func _open_settings() -> void:
	var scene := load("res://scenes/settings_refactor.tscn")
	if scene == null:
		_show_message("No se pudo abrir Ajustes.")
		return
	var node := scene.instantiate() as Control
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_layer.add_child(node)
	_settings_node = node
	if _controller != null and _controller.has_method("register_panel"):
		_controller.register_panel(node)
	node.closed.connect(func(): _close_settings_node())


func _close_settings_node() -> void:
	# Cierre único de Ajustes, usado tanto por su botón
	# "← Volver" (señal closed) como por el Atrás global.
	# Antes el controlador solo ocultaba el panel (visible =
	# false) sin liberar ni recargar: el menú quedaba roto.
	var node := _settings_node
	_settings_node = null
	if node == null:
		return
	if _controller != null and _controller.has_method("unregister_panel"):
		_controller.unregister_panel(node)
	node.queue_free()
	_settings = SettingsRefactor.load_settings()
	if _profile != null:
		_profile = CognitiveProfile.load_or_create()
		_settings["perfil_cognitivo"] = _profile.profile_name()
		_settings["modo_desarrollador"] = _profile.developer_mode
	if _adaptive_hud != null:
		_adaptive_hud.setup(_profile, 0)
		_adaptive_hud.set_hud_rows_visible(false)
	if _plaza != null:
		_plaza.setup(_profile)
	if _player != null:
		_player.camera_sensitivity = SettingsRefactor.camera_sensitivity_factor(_settings)
		_player.invert_y = bool(_settings.get("invert_y", false))
	if _ui != null and _ui.has_method("_apply_settings"):
		_ui._apply_settings()


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false
	if _started and _modes != null:
		# Día completo en ~10 minutos de juego.
		_modes.advance_time(delta * 24.0 / 600.0)
		# 3.0: cambio de día al envolver el reloj 24 h.
		if _modes.time_of_day < _prev_time:
			_day += 1
		_prev_time = _modes.time_of_day
		# 4.0: NightLighting manda en sol/luna/cielo/ambiente.
		# Ya no se baja el sol a 0.4 a mano: la noche tiene
		# suelo azulado minimo y nunca queda negra.
		if _night != null and _modes != null:
			_night.apply_time_of_day(_modes.time_of_day)
		# 3.0: Luna Carmesí cada 8 noches: la horda se acerca
		# al caer la noche y se disuelve al amanecer.
		var is_night := _modes.is_night()
		if is_night != _was_night and _neuro != null:
			_neuro.notify_night_transition(is_night)
		if is_night and not _was_night and _day % 8 == 0 and _horde != null and _player != null:
			_horde.start_horde(12, _player.global_position)
			_show_message("¡Luna Carmesí! La horda se acerca...")
		if not is_night and _was_night and _horde != null:
			_horde.stop_horde()
		_was_night = is_night
		if _horde != null and _player != null and _horde.count() > 0:
			_horde.update(delta, _player.global_position)
	if _started and _player != null:
		var season: String = LevelSystem.season_for_day(_day)
		if _weather != null:
			_weather.set_center(_player.global_position)
			_weather.update(delta, season)
		if _birds != null:
			_birds.set_center(_player.global_position)
		if _quests != null:
			var dx: float = _player.global_position.x - _spawn_pos.x
			var dz: float = _player.global_position.z - _spawn_pos.z
			_quests.on_move(sqrt(dx * dx + dz * dz))
			_quests.on_height(_player.global_position.y)
		if _ui != null:
			_ui.update_minimap(_player.global_position)
		_stats_timer += delta
		if _stats_timer >= 0.5 and _ui != null and _levels != null and _weather != null:
			_stats_timer = 0.0
			var dx2: float = _player.global_position.x - _spawn_pos.x
			var dz2: float = _player.global_position.z - _spawn_pos.z
			var dist: float = sqrt(dx2 * dx2 + dz2 * dz2)
			# 4.0: FPS/vitales SOLO con modo desarrollador.
			# AdaptiveHUD guarda el texto pero no lo muestra si
			# el interruptor esta apagado; UIController ya no
			# recibe set_stats/set_vitals en esta rama.
			var stats_text := "Nv %d · %d/%d EXP · Día %d · %s · Zona %d · %s · %d fps" % [
				_levels.level, _levels.exp, LevelSystem.exp_needed(_levels.level),
				_day, season, LevelSystem.zone_for_distance(dist),
				_weather.weather, Engine.get_frames_per_second()]
			if _adaptive_hud != null:
				_adaptive_hud.set_stats(stats_text)
			elif _ui != null:
				_ui.set_stats(stats_text)
			# 3.0: calor cercano (antorcha/farol/brillo) 2×/s.
			_near_heat = false
			if _world != null:
				var px2 := floori(_player.global_position.x)
				var py2 := floori(_player.global_position.y)
				var pz2 := floori(_player.global_position.z)
				for dx in range(-2, 3):
					for dy in range(-1, 2):
						for dz in range(-2, 3):
							var b := _world.get_block(Vector3i(px2 + dx, py2 + dy, pz2 + dz))
							if b == VoxelWorldGenerator.BLOCK_TORCH or b == VoxelWorldGenerator.BLOCK_LANTERN or b == VoxelWorldGenerator.BLOCK_GLOW:
								_near_heat = true
			if _vitals != null and _adaptive_hud != null:
				_adaptive_hud.set_vitals(_vitals.health, _vitals.mana, _vitals.stamina, _vitals.oxygen, _vitals.temperature)
			# 3.0: la música sigue al bioma.
			if _music != null and _world != null and _world.biome != _music.current_biome:
				_music.start_biome(_world.biome)
		# 3.0: dirección de la montura = la del jugador.
		if _mounted_animal != null and _ui != null and _player != null:
			var steer := PlayerBlocky.move_direction(_ui.move_vector, _player.yaw)
			_mounted_animal.set_steer(steer)
		for animal in _animals:
			if animal.has_method("update_brain"):
				var tame_mult := _character.tame_mult() if _character != null else 1.0
				animal.update_brain(delta, _player.global_position, _player.crouching, _ui.selected_block(), _player.sprinting, _animals, tame_mult)
		# 3.0: el jugador va encima de su montura.
		if _mounted_animal != null and _player != null:
			_player.global_position = _mounted_animal.global_position + Vector3(0.0, 1.7, 0.0)
		# 3.0: guardado del personaje cada 30 s.
		_char_save_timer += delta
		if _char_save_timer >= 30.0 and _character != null:
			_char_save_timer = 0.0
			_character.save_to_file()
		# 3.0: avatares remotos hacia su objetivo.
		for avatar in _remote_avatars.values():
			var node := avatar as Node3D
			if node.has_meta("target"):
				node.position = node.position.lerp(node.get_meta("target"), 0.3)
		# 3.0: vitales por frame.
		if _vitals != null and _world != null:
			var px := floori(_player.global_position.x)
			var pz := floori(_player.global_position.z)
			var col_h := _world.terrain_height(px, pz)
			var in_water := col_h <= _world.water_level
			var submerged := in_water and _player.global_position.y + 1.52 < _world.water_level + 1.0
			_vitals.update(delta, _player.sprinting, submerged, _ambient_temp(), _near_heat)
	if _player != null and _ui != null:
		_player.sprinting = _ui.sprinting
		# Stick derecho del mando: yaw + pitch (Plaza incluida en
		# la variante: este controlador vive en el mundo refactor;
		# la Plaza de 1.15.0 sigue con su propio controlador).
		if Input.get_connected_joypads().size() > 0:
			var rsx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
			var rsy := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
			if absf(rsx) > 0.2 or absf(rsy) > 0.2:
				_player.add_right_stick(rsx, rsy, delta)


## 4.0: «Volver a la Plaza» dentro del mismo mundo voxel.
## Si aun no se entro al mundo, entrar (el spawn ES la Plaza).
func _go_to_plaza() -> void:
	_save_world()
	if not _started:
		_start_world()
		return
	if _player != null:
		_player.global_position = _spawn_pos + Vector3(0.0, 2.0, 0.0)
	_set_pause(false)
	_show_message("Plaza Central: camina hacia un portal y pulsa OK para entrar.")


func _on_plaza_entered(portal_id: String) -> void:
	if _player == null:
		return
	var offsets := {
		"colores": Vector3(100.0, 0.0, 0.0),
		"numeros": Vector3(200.0, 0.0, 0.0),
		"letras": Vector3(300.0, 0.0, 0.0),
		"sumas": Vector3(400.0, 0.0, 0.0),
		"logica": Vector3(500.0, 0.0, 0.0),
	}
	var dest: Vector3 = _spawn_pos + offsets.get(portal_id, Vector3.ZERO)
	var h := _world.terrain_height(int(dest.x), int(dest.z)) if _world != null else 2
	_player.global_position = Vector3(dest.x, float(h) + 2.0, dest.z)
	_show_message("Portal " + portal_id + ": zona en el mismo mundo.")


func _on_plaza_locked(portal_id: String) -> void:
	_show_message("Ese portal está cerrado para tu perfil. ¡Sigue explorando!")


func _show_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_timer = 4.0


## Altura superior de la columna (bloque superior + 1 = suelo).
func _column_top(x: int, z: int) -> float:
	if _world == null:
		return 1.0
	for y in range(24, -1, -1):
		if _world.get_block(Vector3i(x, y, z)) != VoxelWorldGenerator.BLOCK_AIR:
			return float(y) + 1.0
	return 1.0


## Mira por ray-marching: primer bloque sólido y la celda libre
## anterior. Devuelve [sólido, libre] o [] si no hay nada a 6 m.
func _ray_cells() -> Array:
	if _player == null:
		return []
	var cam := _player.get_node_or_null("HeadAnchor/CameraFP")
	if cam == null:
		cam = _player.get_node_or_null("ThirdPersonPivot/CameraTP")
	if cam == null:
		return []
	var origin: Vector3 = (cam as Camera3D).global_position
	var dir: Vector3 = -(cam as Camera3D).global_transform.basis.z
	var prev := Vector3i(-9999, -9999, -9999)
	var t := 0.25
	while t <= 6.0:
		var point := origin + dir * t
		var cell := Vector3i(floori(point.x), floori(point.y), floori(point.z))
		if cell != prev and _world != null and _world.get_block(cell) != VoxelWorldGenerator.BLOCK_AIR:
			return [cell, prev]
		if cell != prev:
			prev = cell
		t += 0.25
	return []


func _on_place() -> void:
	if _world == null or _player == null or _ui == null:
		return
	# 4.0: cerca de un portal de la Plaza, OK entra al portal
	# en lugar de poner un bloque.
	if _started and _plaza != null and _player != null:
		if not _plaza.portal_near(_player.global_position).is_empty():
			_plaza.try_enter_near(_player.global_position)
			return
	var cells := _ray_cells()
	if cells.is_empty():
		return
	var target: Vector3i = cells[1]
	if target.x == -9999:
		target = cells[0] + Vector3i(0, 1, 0)
	var block_id := _ui.selected_block()
	if _modes != null and not _modes.can_place(block_id):
		_show_message("No te queda ese bloque. ¡Recógelo explorando!")
		return
	if _modes != null:
		_modes.consume_place(block_id)
	_world.set_block(target, block_id)
	if _music != null:
		_music.play_foley_for(block_id)
	if _lan != null and _lan.is_in_game():
		_lan.send_block(target, block_id)
	# 3.0: misiones, EXP y antorcha nocturna.
	if _quests != null:
		_quests.on_place(block_id)
		if block_id == VoxelWorldGenerator.BLOCK_TORCH and _modes != null and _modes.is_night():
			_quests.on_torch_night()
	if _levels != null:
		_levels.gain_exp(1)
	if _character != null:
		_character.gain_skill("construccion")
	_after_place(target)


func _on_remove() -> void:
	if _world == null or _player == null:
		return
	var cells := _ray_cells()
	if cells.is_empty():
		return
	var removed := _world.get_block(cells[0])
	# 3.0: roca madre, lava y líquidos no se rompen.
	if VoxelWorldGenerator.is_unbreakable(removed):
		_show_message("Ese bloque no se puede romper.")
		return
	_world.remove_block(cells[0])
	if _music != null:
		_music.play_foley_for(removed)
	if _lan != null and _lan.is_in_game():
		_lan.send_block(cells[0], VoxelWorldGenerator.BLOCK_AIR)
	if _modes != null and _modes.mode == GameModeManager.Mode.SURVIVAL:
		if removed != VoxelWorldGenerator.BLOCK_AIR:
			_modes.collect(removed)
			_grant_material(removed)
			if _character != null:
				_character.gain_skill("mineria")


func _after_place(cell: Vector3i) -> void:
	# Fila horizontal este-oeste a la altura del bloque colocado.
	var start := cell
	while _world.get_block(Vector3i(start.x - 1, start.y, start.z)) != VoxelWorldGenerator.BLOCK_AIR and _is_learning(start.x - 1, start.y, start.z):
		start.x -= 1
	var letters: Array = []
	var tokens: Array = []
	var cursor := start
	while true:
		var block := _world.get_block(cursor)
		if not _is_learning(cursor.x, cursor.y, cursor.z):
			break
		var label := VoxelWorldGenerator.block_label(block)
		if label == "":
			break
		letters.append(label)
		tokens.append(label)
		cursor.x += 1
		if cursor.x - start.x > 12:
			break
	if letters.size() >= 3:
		var word := GameModeManager.detect_word(letters)
		if word == "" and _neuro != null:
			var joined := ""
			for letter in letters:
				joined += str(letter)
			_neuro.record_miss("palabra_" + joined)
			_neuro.feedback_for(false)
		if word != "" and _plaza != null:
			_plaza.try_word(letters)
		# 3.0 multiedad: solo se invoca si la banda la permite.
		if word != "" and _modes != null:
			if word in GameModeManager.words_for_band(_age_band):
				_modes.invoke_word(word, Vector3(float(cell.x), float(cell.y), float(cell.z)))
			else:
				_show_message("Esa palabra es de una edad mayor. ¡Sigue explorando!")
			return
	if tokens.size() == 4 and _modes != null:
		# 3.0 multiedad: el operador debe estar en la banda.
		if not (str(tokens[1]) in GameModeManager.ops_for_band(_age_band)):
			_show_message("Esa operación es de una edad mayor. ¡Sigue explorando!")
			return
		var result := GameModeManager.detect_math(tokens)
		if result[0] != "":
			_modes.solve_math(tokens, Vector3(float(cell.x), float(cell.y), float(cell.z)))


func _is_learning(x: int, y: int, z: int) -> bool:
	var block := _world.get_block(Vector3i(x, y, z))
	return (block >= 10 and block <= 21) or (block >= 30 and block <= 43) or (block >= 50 and block <= 76)
