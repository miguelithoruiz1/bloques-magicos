extends Node
## HordeSystem — hordas del documento §5.2/§5.3, adaptadas
## a nuestra escala: hasta 24 miembros (no 4000; el stick
## no mueve miles de mallas), que avanzan hacia el jugador
## con separación grupal (0.8) y empuje, como el FlowField
## del documento pero sin la malla de flujo completa: la
## dirección es hacia el jugador y la separación evita que
## se solapen. Sin daño todavía: el daño llega con el item
## de combate y vitales.
## Evento Luna Carmesí: RefactorMain la convoca cada 8
## noches (documento §5.2) y la disuelve al amanecer.

class_name HordeSystem

signal attack_player(damage: float)

const MAX_MEMBERS := 24
const SEPARATION := 0.8
const SPEED := 2.6
const SPAWN_MIN := 20.0
const SPAWN_MAX := 30.0
const MEMBER_HEALTH := 50.0

var ground_func: Callable = Callable()
var members: Array[Node3D] = []

var _time := 0.0
var _attack_timer := 0.0


func count() -> int:
	return members.size()


func start_horde(amount: int, center: Vector3) -> void:
	stop_horde()
	var n := mini(amount, MAX_MEMBERS)
	for i in range(n):
		var angle: float = float(i) / float(n) * TAU
		var radius := randf_range(SPAWN_MIN, SPAWN_MAX)
		var member := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = BoxMesh.new()
		(body.mesh as BoxMesh).size = Vector3(0.8, 0.8, 0.8)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.10, 0.30)
		body.material_override = mat
		body.position = Vector3(0.0, 0.4, 0.0)
		member.add_child(body)
		var px := center.x + cos(angle) * radius
		var pz := center.z + sin(angle) * radius
		var py := 0.5
		if ground_func.is_valid():
			py = float(ground_func.call(floori(px), floori(pz))) + 0.5
		member.position = Vector3(px, py, pz)
		member.set_meta("hp", MEMBER_HEALTH)
		add_child(member)
		members.append(member)


func stop_horde() -> void:
	for member in members:
		if member is Node:
			(member as Node).queue_free()
	members.clear()


## Daño en área: todos los miembros dentro del radio
## pierden vida; los que caen a 0 se liberan. Devuelve
## cuántos cayeron.
func damage_at(center: Vector3, radius: float, amount: float) -> int:
	var fallen := 0
	var survivors: Array[Node3D] = []
	for member in members:
		var dx := member.position.x - center.x
		var dz := member.position.z - center.z
		if sqrt(dx * dx + dz * dz) <= radius:
			var hp := float(member.get_meta("hp", MEMBER_HEALTH)) - amount
			if hp <= 0.0:
				member.queue_free()
				fallen += 1
				continue
			member.set_meta("hp", hp)
		survivors.append(member)
	members = survivors
	return fallen


## Miembro más cercano al punto, dentro del radio máximo.
func nearest_member(pos: Vector3, max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_d := max_dist
	for member in members:
		var dx := member.position.x - pos.x
		var dz := member.position.z - pos.z
		var d := sqrt(dx * dx + dz * dz)
		if d < best_d:
			best_d = d
			best = member
	return best


func update(delta: float, player_pos: Vector3) -> void:
	_time += delta
	_attack_timer -= delta
	if _attack_timer <= 0.0:
		for member in members:
			var dx := member.position.x - player_pos.x
			var dz := member.position.z - player_pos.z
			if sqrt(dx * dx + dz * dz) < 1.5:
				attack_player.emit(8.0)
				_attack_timer = 0.5
				break
	for member in members:
		if ground_func.is_valid():
			var gy := float(ground_func.call(floori(member.position.x), floori(member.position.z)))
			member.position.y = gy + 0.5
		var to_player := Vector3(player_pos.x, 0.0, player_pos.z) - Vector3(member.position.x, 0.0, member.position.z)
		var dist := to_player.length()
		var dir := Vector3.ZERO
		if dist > 0.01:
			dir = to_player / dist
		# Separación grupal: empuje si otro miembro está
		# a menos de 0.8 bloques.
		for other in members:
			if other == member:
				continue
			var ox := other.position.x - member.position.x
			var oz := other.position.z - member.position.z
			var od := sqrt(ox * ox + oz * oz)
			if od < SEPARATION and od > 0.001:
				var push := (SEPARATION - od) * 2.0
				dir += Vector3(-ox / od, 0.0, -oz / od) * push
		if dir.length() > 0.01:
			dir = dir.normalized()
			member.position += dir * SPEED * delta
			member.rotation.y = atan2(dir.x, dir.z)
