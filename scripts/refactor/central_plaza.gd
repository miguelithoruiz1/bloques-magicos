extends Node3D
## 04 — CentralPlaza: la Plaza Central DENTRO del mundo voxel.
##
## Qué cambia respecto a la 3.0.2:
## - Antes había DOS plazas: hub.tscn (1.14, 8 portales: Jugar
##   libre, Ciudad, Espacio, Colores, Números, Letras, Sumas,
##   Ajustes) y el mundo voxel de refactor_main.tscn, conectados
##   por "Volver a la Plaza" (cambio de escena). Eso es la
##   "deuda de dos entornos": dos controladores, dos HUD, dos
##   formas de moverse.
## - Ahora la Plaza es un Node3D que se instancia EN el mundo
##   voxel, en el punto de aparición, con 5 portales educativos.
##   No hay cambio de escena para entrar a un portal: el portal
##   emite portal_entered y RefactorMain teletransporta o carga
##   la zona pedida dentro del mismo mundo.
## - Los 5 portales del encargo: Colores, Números, Letras,
##   Sumas y Lógica. Los mundos libres (Ciudad, Espacio) no se
##   borran: quedan como zonas del mundo, no como portales
##   separados, para no duplicar entornos.
##
## Bloqueo por perfil: Explorador solo ve abiertos Colores y
## Letras; los demás portales se muestran grises con candado
## y no emiten entrada. Constructor abre Sumas; Maestro abre
## los 5 y Lógica incluye compuertas AND / OR / NOT.
##
## Invocación fonética (Croma-Isla y Valle del Eco):
##   PhoneticInvoker.try_word(["M", "A", "M", "A"]) -> "MAMA"
##   Si la palabra está permitida por el perfil, devuelve un
##   Node3D animado (rebote + giro suave) y el clip .ogg real
##   si existe en audio/ (palabra_mama.ogg, etc.). Si el clip
##   no existe, no falla: devuelve el modelo y texto.
##   El modelo es procedural hasta que haya arte .vox real;
##   ver la nota en 03 sobre el cargador .vox.

class_name CentralPlaza

signal portal_entered(portal_id: String)
signal portal_locked(portal_id: String)
signal word_invoked(word: String)

const PORTALS := [
	{"id": "colores", "nombre": "Colores", "color": Color(0.90, 0.25, 0.22), "min_profile": 0},
	{"id": "numeros", "nombre": "Números", "color": Color(0.98, 0.80, 0.15), "min_profile": 1},
	{"id": "letras", "nombre": "Letras", "color": Color(0.60, 0.35, 0.90), "min_profile": 0},
	{"id": "sumas", "nombre": "Sumas", "color": Color(0.98, 0.55, 0.15), "min_profile": 1},
	{"id": "logica", "nombre": "Lógica", "color": Color(0.20, 0.75, 0.90), "min_profile": 2},
]

const WORD_MODELS := {
	"SOL": "sol", "CASA": "casa", "MAMA": "mama", "PAPA": "papa",
	"ARBOL": "arbol", "PUENTE": "puente", "LIBRO": "libro", "MUNDO": "mundo",
}

var profile: CognitiveProfile = null
var _portals: Array[Dictionary] = []
var _invoked: Node3D = null


func _ready() -> void:
	if profile == null:
		profile = CognitiveProfile.load_or_create()
	_build_floor()
	_build_portals()


func setup(p: CognitiveProfile) -> void:
	profile = p
	if _portals.is_empty():
		_build_floor()
		_build_portals()
	else:
		_refresh_locks()


func _build_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "PlazaSuelo"
	var box := BoxMesh.new()
	box.size = Vector3(24.0, 0.5, 24.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.42, 0.48)
	mat.roughness = 0.8
	box.material = mat
	floor_mesh.mesh = box
	floor_mesh.position = Vector3(0.0, -0.25, 0.0)
	add_child(floor_mesh)


func _build_portals() -> void:
	var positions := [
		Vector3(-8.0, 0.0, -6.0), Vector3(0.0, 0.0, -9.0),
		Vector3(8.0, 0.0, -6.0), Vector3(-5.0, 0.0, 7.0),
		Vector3(5.0, 0.0, 7.0),
	]
	for i in range(PORTALS.size()):
		var def: Dictionary = PORTALS[i]
		var locked := _is_locked(def)
		var portal := Node3D.new()
		portal.name = "Portal_" + str(def["id"])
		portal.position = positions[i]
		portal.add_child(_pillar_mesh(def, locked, Vector3(-1.2, 1.5, 0.0)))
		portal.add_child(_pillar_mesh(def, locked, Vector3(1.2, 1.5, 0.0)))
		var plane := MeshInstance3D.new()
		var plane_mesh := PlaneMesh.new()
		plane_mesh.size = Vector2(2.0, 3.0)
		var plane_mat := StandardMaterial3D.new()
		if locked:
			plane_mat.albedo_color = Color(0.35, 0.35, 0.38)
			plane_mat.emission_enabled = false
		else:
			plane_mat.albedo_color = Color(def["color"])
			plane_mat.emission_enabled = true
			plane_mat.emission = Color(def["color"])
			plane_mat.emission_energy_multiplier = 1.2
			plane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			plane_mat.albedo_color.a = 0.85
		plane_mesh.material = plane_mat
		plane.mesh = plane_mesh
		plane.position = Vector3(0.0, 1.5, 0.0)
		plane.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		portal.add_child(plane)
		var label := Label3D.new()
		label.text = str(def["nombre"]) + (" 🔒" if locked else "")
		label.font_size = 96
		label.position = Vector3(0.0, 3.4, 0.0)
		portal.add_child(label)
		add_child(portal)
		_portals.append({"def": def, "node": portal, "locked": locked})


func _pillar_mesh(def: Dictionary, locked: bool, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 3.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.38) if locked else Color(def["color"])
	mat.roughness = 0.5
	box.material = mat
	m.mesh = box
	m.position = pos
	return m


func _is_locked(def: Dictionary) -> bool:
	if profile == null:
		return false
	return profile.profile < int(def["min_profile"])


func _refresh_locks() -> void:
	for entry in _portals:
		var def: Dictionary = entry["def"]
		entry["locked"] = _is_locked(def)


func portal_near(player_pos: Vector3, max_dist: float = 3.0) -> Dictionary:
	var best := {}
	var best_d := max_dist
	for entry in _portals:
		var node: Node3D = entry["node"]
		var d := player_pos.distance_to(node.global_position)
		if d < best_d:
			best_d = d
			best = entry
	return best


func try_enter_near(player_pos: Vector3) -> bool:
	var entry := portal_near(player_pos)
	if entry.is_empty():
		return false
	var def: Dictionary = entry["def"]
	if bool(entry["locked"]):
		portal_locked.emit(str(def["id"]))
		return false
	portal_entered.emit(str(def["id"]))
	return true


func portal_ids() -> Array[String]:
	var out: Array[String] = []
	for def in PORTALS:
		out.append(str(def["id"]))
	return out


# --- Invocación fonética: juntar bloques letra en orden ---

func try_word(letters: Array) -> String:
	# letters: ["M", "A", "M", "A"] tal como se colocaron.
	var word := ""
	for l in letters:
		word += str(l)
	if profile != null and not profile.words_allowed().has(word):
		return ""
	if not WORD_MODELS.has(word):
		return ""
	_invoke_model(word)
	word_invoked.emit(word)
	return word


func _invoke_model(word: String) -> void:
	if _invoked != null:
		_invoked.queue_free()
		_invoked = null
	var model := Node3D.new()
	model.name = "Invocado_" + word
	match word:
		"SOL":
			model.add_child(_ball(Color(1.0, 0.85, 0.2), 0.8, Vector3.ZERO))
		"CASA", "MAMA", "PAPA":
			model.add_child(_box(Color(0.95, 0.85, 0.6), Vector3(1.2, 1.0, 1.2), Vector3(0.0, 0.5, 0.0)))
			model.add_child(_box(Color(0.85, 0.2, 0.2), Vector3(1.5, 0.6, 1.5), Vector3(0.0, 1.3, 0.0)))
		"ARBOL":
			model.add_child(_box(Color(0.45, 0.30, 0.15), Vector3(0.3, 1.0, 0.3), Vector3(0.0, 0.5, 0.0)))
			model.add_child(_ball(Color(0.20, 0.70, 0.25), 0.8, Vector3(0.0, 1.5, 0.0)))
		_:
			model.add_child(_box(Color(0.60, 0.35, 0.90), Vector3(1.0, 1.0, 1.0), Vector3(0.0, 0.5, 0.0)))
	model.position = global_position + Vector3(0.0, 1.0, -3.0)
	add_child(model)
	_invoked = model
	# Animación: rebote + giro suave, sin depender de assets.
	var tween := create_tween()
	tween.tween_property(model, "position:y", model.position.y + 0.6, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position:y", model.position.y, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(model, "rotation:y", TAU, 1.2)


func _box(color: Color, size: Vector3, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	box.material = mat
	m.mesh = box
	m.position = pos
	return m


func _ball(color: Color, radius: float, pos: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	mat.roughness = 0.4
	sphere.material = mat
	m.mesh = sphere
	m.position = pos
	return m
