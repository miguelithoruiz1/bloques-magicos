extends Node3D
## AmbientBirds — 5 pájaros ambientales del mundo en vivo
## (3.0). Cubos propios, sin colisión, sin interacción: solo
## vida en el cielo. Cada pájaro vuela en círculo alrededor
## del centro (la posición del jugador, que RefactorMain
## actualiza con set_center) y aletea con sin/cos.
## Presupuesto fijo: 5 pájaros, 3 cajas cada uno. No hay
## sonidos ni partículas: el stick onn manda.

class_name AmbientBirds

const BIRD_COUNT := 5

var _center := Vector3.ZERO
var _birds: Array = []
var _time := 0.0


func _ready() -> void:
	var colors: Array[Color] = [
		Color(0.20, 0.60, 0.95), Color(0.95, 0.85, 0.20),
		Color(0.95, 0.95, 0.95), Color(0.20, 0.75, 0.30),
		Color(0.90, 0.30, 0.30),
	]
	for i in range(BIRD_COUNT):
		var bird := Node3D.new()
		var body := MeshInstance3D.new()
		body.mesh = BoxMesh.new()
		(body.mesh as BoxMesh).size = Vector3(0.5, 0.25, 0.7)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[i % colors.size()]
		body.material_override = mat
		bird.add_child(body)
		var wings: Array = []
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(0.25 * side, 0.1, 0.0)
			var wing := MeshInstance3D.new()
			wing.mesh = BoxMesh.new()
			(wing.mesh as BoxMesh).size = Vector3(0.7, 0.08, 0.4)
			wing.material_override = mat
			wing.position = Vector3(0.35 * side, 0.0, 0.0)
			pivot.add_child(wing)
			bird.add_child(pivot)
			wings.append(pivot)
		add_child(bird)
		_birds.append({
			"node": bird, "wings": wings,
			"radius": 8.0 + float(i) * 2.0,
			"height": 10.0 + float(i) * 1.5,
			"speed": 0.25 + float(i) * 0.05,
			"phase": float(i) * 1.3,
		})


func set_center(pos: Vector3) -> void:
	_center = pos


func _process(delta: float) -> void:
	_time += delta
	for b in _birds:
		var bird: Node3D = b["node"]
		var angle: float = _time * float(b["speed"]) + float(b["phase"])
		var target := Vector3(
			_center.x + cos(angle) * float(b["radius"]),
			_center.y + float(b["height"]),
			_center.z + sin(angle) * float(b["radius"]))
		bird.global_position = target
		bird.rotation.y = -angle
		var flap: float = sin(_time * 10.0 + float(b["phase"])) * 0.7
		var wings: Array = b["wings"]
		(wings[0] as Node3D).rotation.z = flap
		(wings[1] as Node3D).rotation.z = -flap
