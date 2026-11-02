extends Node3D
## RefactorMain — escena principal de la variante refactorizada.
##
## Cableado (sin tocar hub.tscn, main.tscn ni ningún nivel):
##   VoxelWorldGenerator  → terreno por semilla + bloques
##   PlayerBlocky         → movimiento/cámara (ver su convención)
##   UIController         → HUD Minecraft (hotbar, inventario, TV)
##   GameModeManager      → Creativo / Supervivencia, voces, retos
##   RefactorController   → Atrás nunca cierra la app por accidente
##   SettingsScene        → Ajustes (se instancia al pulsar Ajustes)
##
## La Plaza y los niveles de 1.15.0 quedan intactos y accesibles:
## «Volver a la Plaza» cambia a res://hub.tscn, que es el mismo
## archivo de 1.15.0 copiado sin cambios.
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
var _pause_panel: Control = null
var _message_label: Label = null
var _message_timer := 0.0
var _seed_field: LineEdit = null
var _name_field: LineEdit = null
var _mode_option: OptionButton = null
var _hat_option: OptionButton = null
var _shirt_option: OptionButton = null
var _animals: Array = []
var _started := false


func _ready() -> void:
	_settings = SettingsRefactor.load_settings()
	_world = get_node_or_null("VoxelWorld") as VoxelWorldGenerator
	_player = get_node_or_null("PlayerBlocky") as PlayerBlocky
	_ui = get_node_or_null("TouchAndTVControls") as UIController
	_modes = get_node_or_null("GameModeManager") as GameModeManager
	_controller = get_node_or_null("RefactorController")
	_build_overlays()
	_wire_signals()
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
	title.text = "Bloques Mágicos — 2.0"
	vbox.add_child(title)
	var note := Label.new()
	note.text = "2.0: biomas nuevos, animales amigos, ala delta y avatar con sombrero. La Plaza y los niveles de 1.15.0 siguen intactos: 'Volver a la Plaza' los abre."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(note)
	_mode_option = OptionButton.new()
	_mode_option.add_item("Creativo Educativo")
	_mode_option.add_item("Supervivencia Cognitiva")
	vbox.add_child(_mode_option)
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
	var settings_btn := Button.new()
	settings_btn.text = "Ajustes"
	settings_btn.pressed.connect(_open_settings)
	vbox.add_child(settings_btn)
	var plaza_btn := Button.new()
	plaza_btn.text = "Volver a la Plaza"
	plaza_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://hub.tscn"))
	vbox.add_child(plaza_btn)
	_ui_layer.add_child(_title_panel)
	# Pausa.
	_pause_panel = _panel()
	_pause_panel.visible = false
	var pbox := VBoxContainer.new()
	_pause_panel.add_child(pbox)
	for data in [["Continuar", func(): _set_pause(false)], ["Ajustes", func(): _open_settings()], ["Guardar mundo", func(): _save_world()], ["Exportar mundo (copiar código)", func(): _export_world()], ["Importar mundo (desde portapapeles)", func(): _import_world()], ["Volver a la Plaza", func(): _save_world(); get_tree().change_scene_to_file("res://hub.tscn")]]:
		var b := Button.new()
		b.text = data[0]
		b.pressed.connect(data[1])
		pbox.add_child(b)
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
	if _controller != null and _controller.has_signal("back_pressed_handled"):
		_controller.back_pressed_handled.connect(_on_back_action)
	if _modes != null:
		_modes.message_shown.connect(_show_message)
		_modes.feynman_request.connect(func(text: String):
			_show_message(text)
			if _player != null:
				_player.set_perspective(PlayerBlocky.Perspective.SECOND))


func _on_back_action(action: String) -> void:
	# Se ejecuta ANTES de que RefactorController cambie de escena:
	# guardar aquí es seguro y síncrono.
	if action == "back_to_plaza":
		_save_world()


func _set_pause(value: bool) -> void:
	if _pause_panel != null:
		_pause_panel.visible = value
	get_tree().paused = value


func _start_world() -> void:
	var seed_text := _seed_field.text.strip_edges() if _seed_field != null else ""
	if seed_text == "":
		seed_text = WorldSeedManager.random_seed_text()
		_seed_field.text = seed_text
	var world_name := _name_field.text.strip_edges() if _name_field != null else "MundoRefactor"
	_settings["seed_text"] = seed_text
	_settings["world_name"] = world_name
	SettingsRefactor.save_settings(_settings)
	var seed := WorldSeedManager.seed_from_string(seed_text)
	var biome := str(_settings.get("biome", "croma_isla"))
	if _world != null:
		_world.generate(seed, biome, int(_settings.get("render_radius", 24)))
		var saved := WorldSeedManager.load_world(world_name, seed_text)
		if not saved.is_empty():
			_world.apply_modified(saved.get("modified_blocks", {}))
	if _modes != null:
		_modes.setup(_world)
		_modes.set_mode(GameModeManager.Mode.CREATIVE if _mode_option.selected == 0 else GameModeManager.Mode.SURVIVAL)
	if _player != null:
		var h := _world.terrain_height(0, 0) if _world != null else 2
		_player.global_position = Vector3(0.5, float(h) + 2.0, 0.5)
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
	_started = true
	if _controller != null and _controller.has_method("set_in_world"):
		_controller.set_in_world(true)
	if _controller != null and _controller.has_method("register_panel"):
		_controller.register_panel(_pause_panel)


func _save_world() -> bool:
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


## Animales amigos 2.0: 4 animales procedurales cerca del
## punto de aparición. Si uno ya existía, se libera primero:
## al reentrar a un mundo no se duplican.
func _spawn_animals() -> void:
	for animal in _animals:
		if animal is Node:
			(animal as Node).queue_free()
	_animals.clear()
	if _world == null or _player == null:
		return
	for data in [["oveja", Vector3(5, 0, 5)], ["perro", Vector3(-5, 0, -3)], ["pollo", Vector3(3, 0, -6)], ["slime", Vector3(-4, 0, 6)]]:
		var animal := FriendlyAnimal.new()
		animal.species = str(data[0])
		animal.ground_func = _column_top
		var start_pos: Vector3 = data[1]
		var h := _world.terrain_height(int(start_pos.x), int(start_pos.z))
		animal.position = Vector3(start_pos.x + 0.5, float(h) + 2.0, start_pos.z + 0.5)
		animal.friend_made.connect(func(species_name: String):
			_show_message("¡Nuevo amigo: " + species_name + "! Te seguirá."))
		add_child(animal)
		_animals.append(animal)


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
	if _controller != null and _controller.has_method("register_panel"):
		_controller.register_panel(node)
	node.closed.connect(func():
		if _controller != null and _controller.has_method("unregister_panel"):
			_controller.unregister_panel(node)
		node.queue_free()
		_settings = SettingsRefactor.load_settings()
		if _player != null:
			_player.camera_sensitivity = SettingsRefactor.camera_sensitivity_factor(_settings)
			_player.invert_y = bool(_settings.get("invert_y", false)))


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_label.visible = false
	if _started and _modes != null:
		# Día completo en ~10 minutos de juego.
		_modes.advance_time(delta * 24.0 / 600.0)
	if _started and _player != null:
		for animal in _animals:
			if animal.has_method("update_brain"):
				animal.update_brain(delta, _player.global_position)
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
	_after_place(target)


func _on_remove() -> void:
	if _world == null or _player == null:
		return
	var cells := _ray_cells()
	if cells.is_empty():
		return
	var removed := _world.get_block(cells[0])
	_world.remove_block(cells[0])
	if _modes != null and _modes.mode == GameModeManager.Mode.SURVIVAL:
		if removed != VoxelWorldGenerator.BLOCK_AIR:
			_modes.collect(removed)


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
		if word != "" and _modes != null:
			_modes.invoke_word(word, Vector3(float(cell.x), float(cell.y), float(cell.z)))
			return
	if tokens.size() == 4 and _modes != null:
		var result := GameModeManager.detect_math(tokens)
		if result[0] != "":
			_modes.solve_math(tokens, Vector3(float(cell.x), float(cell.y), float(cell.z)))


func _is_learning(x: int, y: int, z: int) -> bool:
	var block := _world.get_block(Vector3i(x, y, z))
	return (block >= 10 and block <= 21) or (block >= 30 and block <= 43) or (block >= 50 and block <= 76)
