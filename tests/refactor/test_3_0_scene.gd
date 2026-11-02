extends SceneTree
## Test de escena 3.0: instancia refactor_main.tscn headless
## y comprueba que el HUD y los sistemas nuevos existen.
## (Lección 2.0.2: un script que no compila deja el HUD en
## 0 hijos y solo se ve instanciando la escena.)
## Uso: godot --headless --path . -s tests/refactor/test_3_0_scene.gd
## Nota: las comprobaciones van en el primer _process, no en
## _init: los _ready de la escena solo se disparan cuando el
## bucle principal itera, y un quit() en _init los mataría.
## No se libera la raíz (el WorldEnvironment cuelga el
## headless al liberar, como ya se documentó en test_2_0).

var _failures := 0
var _root: Node = null
var _checked := false


func _check(name: String, condition: bool) -> void:
	if condition:
		print("PASS " + name)
	else:
		_failures += 1
		printerr("FAIL " + name)


func _count_descendants(node: Node) -> int:
	var count: int = 0
	for child in node.get_children():
		count += 1 + _count_descendants(child)
	return count


func _has_script_class(node: Node, script_name: String) -> bool:
	var script: Script = node.get_script()
	if script != null and script.get_global_name() == script_name:
		return true
	for child in node.get_children():
		if _has_script_class(child, script_name):
			return true
	return false


func _init() -> void:
	var scene: PackedScene = load("res://scenes/refactor_main.tscn")
	if scene == null:
		printerr("FAIL escena_existe")
		quit(1)
		return
	_root = scene.instantiate()
	get_root().add_child(_root)


func _process(_delta: float) -> bool:
	if _checked:
		return true
	_checked = true
	_check("escena_existe", _root != null)
	var ui := _root.get_node_or_null("TouchAndTVControls")
	_check("ui_existe", ui != null)
	if ui != null:
		_check("hud_tiene_hijos", _count_descendants(ui) > 30)
	_check("minimapa_en_hud", ui != null and _has_script_class(ui, "Minimap"))
	_check("quests_nodo", _has_script_class(_root, "QuestSystem"))
	_check("levels_nodo", _has_script_class(_root, "LevelSystem"))
	_check("birds_nodo", _has_script_class(_root, "AmbientBirds"))
	_check("weather_nodo", _has_script_class(_root, "WeatherSystem"))
	_check("horde_nodo", _has_script_class(_root, "HordeSystem"))
	_check("mundo_existe", _root.get_node_or_null("VoxelWorld") != null)
	_check("jugador_existe", _root.get_node_or_null("PlayerBlocky") != null)
	if _failures > 0:
		printerr("test_3_0_scene: " + str(_failures) + " FALLOS")
		quit(1)
	else:
		print("test_3_0_scene: TODO OK")
		quit(0)
	return true
