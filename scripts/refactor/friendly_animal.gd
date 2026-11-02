extends Node3D
## FriendlyAnimal — animales amigos de Bloques Mágicos 2.0.
##
## Del plan de Cube Unbound, solo lo amable y para un niño:
## sin combate, sin monstruos que asusten, sin hambre ni
## muerte. Oveja, perro, pollo y slime amistoso, construidos
## con cubos propios (BoxMesh), no con modelos ajenos.
## Animación procedural como en Cube: las patas giran con
## sin/cos según la velocidad, sin keyframes ni esqueletos.
## IA de 3 estados del plan: IDLE, WANDER y FOLLOW_PLAYER.
## Domesticación para un niño: acercarse y quedarse cerca
## 3.5 segundos (el mismo tiempo del plan) = amigo, con un
## corazón ♥ encima. No pide comida ni agacharse: la barra
## de Bloques no tiene alimentos y un niño no debe frustrarse
## por un requisito escondido. Al ser amigo, sigue al jugador.
##
## El suelo lo da ground_func (x, z) -> altura, igual que el
## jugador: el terreno MultiMesh no tiene cuerpos de colisión.

class_name FriendlyAnimal

signal friend_made(species_name: String)

const TAME_SECONDS := 3.5
const TAME_RADIUS := 3.0
const FOLLOW_RADIUS := 2.5
const WANDER_SPEED := 1.2
const FOLLOW_SPEED := 2.2

@export var species := "oveja"

var ground_func: Callable = Callable()
var tamed := false
var tame_timer := 0.0

var _time := 0.0
var _target := Vector3.ZERO
var _retarget_timer := 0.0
var _leg_pivots: Array = []
var _heart: Label3D = null
var _built := false


static func leg_angle(time: float, speed_factor: float) -> float:
	return sin(time * 10.0) * 0.6 * speed_factor


static func tame_progress(delta: float, dist_xz: float, current: float) -> float:
	if dist_xz < TAME_RADIUS:
		return current + delta
	return 0.0


static func state_for(is_tamed: bool, dist_xz: float) -> String:
	if is_tamed:
		if dist_xz > FOLLOW_RADIUS:
			return "FOLLOW"
		return "IDLE"
	return "WANDER"


func _ready() -> void:
	_build()
	_target = global_position


func _species_colors() -> Dictionary:
	match species:
		"perro":
			return {"body": Color(0.55, 0.35, 0.20), "head": Color(0.45, 0.28, 0.15)}
		"pollo":
			return {"body": Color(0.95, 0.95, 0.95), "head": Color(0.95, 0.80, 0.20)}
		"slime":
			return {"body": Color(0.20, 0.85, 0.30), "head": Color(0.20, 0.85, 0.30)}
		_:
			return {"body": Color(0.95, 0.95, 0.95), "head": Color(0.20, 0.20, 0.22)}


func _box(size: Vector3, color: Color, pos: Vector3, transparent: bool = false) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = BoxMesh.new()
	(inst.mesh as BoxMesh).size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	inst.material_override = mat
	inst.position = pos
	return inst


func _build() -> void:
	if _built:
		return
	_built = true
	var colors := _species_colors()
	var body_color: Color = colors["body"]
	var head_color: Color = colors["head"]
	if species == "slime":
		add_child(_box(Vector3(1.0, 0.7, 1.0), body_color, Vector3(0.0, 0.55, 0.0), true))
	else:
		var body_size := Vector3(0.9, 0.6, 0.9)
		if species == "pollo":
			body_size = Vector3(0.6, 0.5, 0.6)
		add_child(_box(body_size, body_color, Vector3(0.0, 0.7, 0.0)))
		add_child(_box(Vector3(0.5, 0.5, 0.5), head_color, Vector3(0.0, 1.15, 0.55)))
		for px in [-0.3, 0.3]:
			for pz in [-0.3, 0.3]:
				var pivot := Node3D.new()
				pivot.position = Vector3(px, 0.45, pz)
				var leg := _box(Vector3(0.22, 0.45, 0.22), head_color, Vector3(0.0, -0.22, 0.0))
				pivot.add_child(leg)
				add_child(pivot)
				_leg_pivots.append(pivot)
	_heart = Label3D.new()
	_heart.text = "♥ Amigo"
	_heart.font_size = 64
	_heart.position = Vector3(0.0, 1.8, 0.0)
	_heart.visible = false
	add_child(_heart)


## Llamado cada frame por RefactorMain con la posición del
## jugador. No mueve nada si el animal aún no está construido.
func update_brain(delta: float, player_pos: Vector3) -> void:
	if not _built:
		return
	_time += delta
	if ground_func.is_valid():
		var gy := float(ground_func.call(floori(global_position.x), floori(global_position.z)))
		global_position.y = gy
	var dx := player_pos.x - global_position.x
	var dz := player_pos.z - global_position.z
	var dist_xz := sqrt(dx * dx + dz * dz)
	if not tamed:
		tame_timer = tame_progress(delta, dist_xz, tame_timer)
		if tame_timer >= TAME_SECONDS:
			tamed = true
			if _heart != null:
				_heart.visible = true
			friend_made.emit(species)
	var moving := false
	if tamed:
		if dist_xz > FOLLOW_RADIUS:
			_target = Vector3(player_pos.x, global_position.y, player_pos.z)
			moving = true
	else:
		_retarget_timer -= delta
		var to_target := _target - global_position
		to_target.y = 0.0
		if _retarget_timer <= 0.0 or to_target.length() < 0.3:
			_target = global_position + Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
			_retarget_timer = 4.0
			to_target = _target - global_position
			to_target.y = 0.0
		if to_target.length() > 0.3:
			moving = true
	if moving:
		var dir := (_target - global_position)
		dir.y = 0.0
		dir = dir.normalized()
		var speed := FOLLOW_SPEED if tamed else WANDER_SPEED
		global_position += dir * speed * delta
		rotation.y = atan2(dir.x, dir.z)
	var angle := leg_angle(_time, 1.0 if moving else 0.0)
	for i in range(_leg_pivots.size()):
		var pivot := _leg_pivots[i] as Node3D
		if pivot == null:
			continue
		pivot.rotation.x = angle if i % 2 == 0 else -angle
