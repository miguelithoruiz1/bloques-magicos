extends Node3D
## WeatherSystem — clima SOLO visual de la 3.0 (adaptación
## del WeatherSystem del documento: lluvia, nieve y cambios
## estacionales, sin tormentas, sin rayos, sin efectos sobre
## el jugador ni castigos). Una sola nube de partículas que
## sigue al jugador; el clima cambia cada ~60 s según la
## estación: en Invierno puede nevar, en el resto puede
## llover, y casi siempre está despejado.
## Presupuesto fijo: 1 sistema, 200 partículas, sin sombras.

class_name WeatherSystem

signal weather_changed(weather: String)

const CHANGE_EVERY := 60.0

var weather := "Despejado"
var _timer := 0.0
var _particles: GPUParticles3D = null
var _center := Vector3.ZERO


func _ready() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 200
	_particles.lifetime = 3.0
	_particles.emitting = false
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.4, 0.12)
	_particles.draw_pass_1 = mesh
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 20.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0.0, -2.0, 0.0)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(20.0, 1.0, 20.0)
	_particles.process_material = mat
	add_child(_particles)


func set_center(pos: Vector3) -> void:
	_center = pos
	if _particles != null:
		_particles.global_position = Vector3(pos.x, pos.y + 8.0, pos.z)


## Estación -> clima posible (puro, para tests y para el
## ciclo). Despejado siempre puede salir.
static func possible_weathers(season: String) -> Array[String]:
	if season == "Invierno":
		return ["Despejado", "Nieve"]
	return ["Despejado", "Lluvia"]


func update(delta: float, season: String) -> void:
	_timer += delta
	if _timer < CHANGE_EVERY:
		return
	_timer = 0.0
	var options: Array[String] = possible_weathers(season)
	# 60% despejado: el clima bonito es lo normal.
	var roll: float = randf()
	var next: String = "Despejado"
	if roll > 0.6:
		next = options[randi() % options.size()]
	if next != weather:
		weather = next
		_apply()
		weather_changed.emit(weather)


func _apply() -> void:
	if _particles == null:
		return
	match weather:
		"Lluvia":
			_particles.emitting = true
			var mat := _particles.process_material as ParticleProcessMaterial
			if mat != null:
				mat.initial_velocity_min = 8.0
				mat.initial_velocity_max = 12.0
				mat.gravity = Vector3(0.0, -2.0, 0.0)
		"Nieve":
			_particles.emitting = true
			var mat2 := _particles.process_material as ParticleProcessMaterial
			if mat2 != null:
				mat2.initial_velocity_min = 1.0
				mat2.initial_velocity_max = 2.5
				mat2.gravity = Vector3(0.0, -0.5, 0.0)
		_:
			_particles.emitting = false
