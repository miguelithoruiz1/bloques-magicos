extends Node3D
## FriendlyAnimal — animales de Bloques Mágicos 3.0.
##
## Las 16 especies amigas, construidas con cubos propios
## (BoxMesh), no con modelos ajenos. Animación procedural:
## las patas giran con sin/cos según la velocidad, sin
## keyframes ni esqueletos.
## IA por temperamento (documento §5.2): passive vaga,
## pasta y huye si el jugador corre hacia él; neutral
## igual pero avisa a su manada; aggressive persigue al
## jugador dentro de su radio de agresión. Las 16 amigas
## son passive; el temperamento se puede cambiar por
## instancia para la fauna salvaje del catálogo.
## Domesticación (documento §5.4, adaptada): acercarse
## 3.5 s sigue funcionando como en la 3.0.0; agachado
## (sigilo) dentro de 5.5 bloques acelera a 1.5× y llevar
## la comida favorita en la mano (bloque seleccionado)
## acelera a 2×. Al ser amigo, sigue al jugador.
## Monturas (documento §5.4): el caballo domado se puede
## montar (botón 🐴): el jugador va encima y el animal se
## mueve con el joystick. Sin daño todavía: el combate
## llega con el item de vitales.
##
## El suelo lo da ground_func (x, z) -> altura, igual que el
## jugador: el terreno MultiMesh no tiene cuerpos de colisión.

class_name FriendlyAnimal

signal friend_made(species_name: String)
signal attack_player(damage: float)
signal defeated(species_name: String)

const TAME_SECONDS := 3.5
const TAME_RADIUS := 3.0
const FEED_RADIUS := 5.5
const FOLLOW_RADIUS := 2.5
const FLEE_RADIUS := 3.0
const AGGRO_RADIUS := 8.0
const CHASE_DISTANCE := 20.0
const CALM_SECONDS := 3.0
const WANDER_SPEED := 1.2
const FOLLOW_SPEED := 2.2
const FLEE_SPEED := 3.0
const CHASE_SPEED := 3.5
const MOUNT_SPEED := 4.5

@export var species := "oveja"
@export var temperament := "passive"

var ground_func: Callable = Callable()
var tamed := false
var tame_timer := 0.0
var mounted := false
# 3.0 combate: salud, jefe con fases y retroceso.
var health := 100.0
var max_health := 100.0
var boss := false
var dead := false

var _time := 0.0
var _target := Vector3.ZERO
var _retarget_timer := 0.0
var _leg_pivots: Array = []
var _heart: Label3D = null
var _built := false
var _chasing := false
var _fleeing := false
var _calm_timer := 0.0
var _steer_dir := Vector3.ZERO
var _attack_timer := 0.0
var _knockback := Vector3.ZERO


## Fase de jefe por % de vida (documento §5.2): 1 sobre
## 66%, 2 sobre 33%, 3 por debajo. Sin jefe, siempre 1.
func phase() -> int:
	if not boss or max_health <= 0.0:
		return 1
	var frac := health / max_health
	if frac > 0.66:
		return 1
	if frac > 0.33:
		return 2
	return 3


func chase_speed() -> float:
	match phase():
		2:
			return CHASE_SPEED * 1.3
		3:
			return CHASE_SPEED * 1.6
		_:
			return CHASE_SPEED


func set_boss(value: bool) -> void:
	boss = value
	if value:
		max_health = 300.0
		health = 300.0


## Daño. Los amigos domados no reciben daño. Devuelve
## true si entró. Al morir emite defeated.
func take_damage(amount: float, from_pos: Vector3) -> bool:
	if dead or tamed or amount <= 0.0:
		return false
	health -= amount
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(1.0, 0.0, 0.0)
	_knockback = away.normalized() * 3.0
	if health <= 0.0:
		health = 0.0
		dead = true
		defeated.emit(species)
	return true


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


## Comida favorita del catálogo (documento §5.4) por especie
## amiga. "pollo" es la gallina del catálogo.
static func food_for_species(species_id: String) -> String:
	match species_id:
		"oveja":
			return "baya"
		"vaca":
			return "trigo"
		"cerdo", "conejo":
			return "zanahoria"
		"pollo", "pato", "loro":
			return "semillas"
		"gato", "pinguino":
			return "pescado"
		"rana":
			return "mosca"
		"caballo":
			return "manzana"
		"tortuga", "ciervo", "capibara":
			return "hierba"
		"perro":
			return "carne"
		_:
			return ""


## Bloque que representa la comida en la mano, cuando
## existe en el catálogo: baya -> arbusto de bayas (222),
## hierba -> hierba alta (214). El resto aún no tiene
## bloque y su bonus llega con el inventario de objetos.
static func food_block_id(food: String) -> int:
	match food:
		"baya":
			return 222
		"hierba":
			return 214
		_:
			return -1


## Progreso de doma v2 (puro): cerca (3.0) 1× como
## siempre; con la comida favorita en la mano dentro de
## 5.5, 2×; agachado (sigilo) dentro de 5.5, 1.5×; fuera
## de rango, el contador vuelve a cero.
static func tame_progress_v2(delta: float, dist_xz: float, crouched: bool, has_food: bool, current: float, speed_mult: float = 1.0) -> float:
	if has_food and dist_xz < FEED_RADIUS:
		return current + delta * 2.0 * speed_mult
	if crouched and dist_xz < FEED_RADIUS:
		return current + delta * 1.5 * speed_mult
	if dist_xz < TAME_RADIUS:
		return current + delta * speed_mult
	return 0.0


## Estado por temperamento (puro, sin memoria de
## persecución: el latch vive en update_brain).
static func state_for_v2(is_tamed: bool, dist_xz: float, temperament_id: String, player_sprinting: bool, pack_fleeing: bool) -> String:
	if is_tamed:
		if dist_xz > FOLLOW_RADIUS:
			return "FOLLOW"
		return "IDLE"
	match temperament_id:
		"aggressive":
			if dist_xz < AGGRO_RADIUS:
				return "CHASE"
			return "WANDER"
		_:
			if pack_fleeing or (player_sprinting and dist_xz < FLEE_RADIUS):
				return "FLEE"
			return "WANDER"


static func is_rideable_species(species_id: String) -> bool:
	return species_id == "caballo"


func is_rideable() -> bool:
	return is_rideable_species(species)


func set_mounted(value: bool) -> void:
	mounted = value
	if not value:
		_steer_dir = Vector3.ZERO


func set_steer(dir: Vector3) -> void:
	_steer_dir = dir


func _ready() -> void:
	_build()
	_target = global_position


static func all_species() -> Array[String]:
	return ["oveja", "perro", "pollo", "slime", "vaca", "cerdo",
		"gato", "conejo", "pato", "rana", "caballo", "tortuga",
		"ciervo", "loro", "capibara", "pinguino"]


static func display_name(species_id: String) -> String:
	match species_id:
		"pinguino":
			return "Pingüino"
		_:
			return species_id.capitalize()


func _species_colors() -> Dictionary:
	match species:
		"perro":
			return {"body": Color(0.55, 0.35, 0.20), "head": Color(0.45, 0.28, 0.15)}
		"pollo":
			return {"body": Color(0.95, 0.95, 0.95), "head": Color(0.95, 0.80, 0.20)}
		"slime":
			return {"body": Color(0.20, 0.85, 0.30), "head": Color(0.20, 0.85, 0.30)}
		"vaca":
			return {"body": Color(0.95, 0.95, 0.95), "head": Color(0.15, 0.15, 0.15)}
		"cerdo":
			return {"body": Color(0.95, 0.65, 0.70), "head": Color(0.90, 0.55, 0.60)}
		"gato":
			return {"body": Color(0.95, 0.60, 0.25), "head": Color(0.90, 0.55, 0.20)}
		"conejo":
			return {"body": Color(0.90, 0.90, 0.90), "head": Color(0.85, 0.85, 0.85)}
		"pato":
			return {"body": Color(0.95, 0.85, 0.20), "head": Color(0.95, 0.60, 0.15)}
		"rana":
			return {"body": Color(0.20, 0.75, 0.30), "head": Color(0.20, 0.70, 0.25)}
		"caballo":
			return {"body": Color(0.45, 0.30, 0.15), "head": Color(0.35, 0.22, 0.10)}
		"tortuga":
			return {"body": Color(0.25, 0.60, 0.25), "head": Color(0.20, 0.50, 0.20)}
		"ciervo":
			return {"body": Color(0.60, 0.40, 0.20), "head": Color(0.50, 0.32, 0.15)}
		"loro":
			return {"body": Color(0.20, 0.70, 0.30), "head": Color(0.90, 0.20, 0.20)}
		"capibara":
			return {"body": Color(0.55, 0.40, 0.25), "head": Color(0.45, 0.32, 0.18)}
		"pinguino":
			return {"body": Color(0.10, 0.10, 0.12), "head": Color(0.95, 0.95, 0.95)}
		_:
			return {"body": Color(0.95, 0.95, 0.95), "head": Color(0.20, 0.20, 0.22)}


func _species_body_size() -> Vector3:
	match species:
		"pollo", "conejo", "pato", "rana", "tortuga", "pinguino":
			return Vector3(0.6, 0.5, 0.6)
		"caballo", "vaca", "ciervo", "capibara":
			return Vector3(1.1, 0.7, 1.1)
		_:
			return Vector3(0.9, 0.6, 0.9)


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
		var body_size: Vector3 = _species_body_size()
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
## jugador, si está agachado, el bloque en la mano, si
## corre y sus compañeros de manada. No mueve nada si el
## animal aún no está construido.
func update_brain(delta: float, player_pos: Vector3, crouched: bool = false, held_block: int = -1, sprinting: bool = false, packmates: Array = [], tame_mult: float = 1.0) -> void:
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
		var has_food := held_block == food_block_id(food_for_species(species))
		tame_timer = tame_progress_v2(delta, dist_xz, crouched, has_food, tame_timer, tame_mult)
		if tame_timer >= TAME_SECONDS:
			tamed = true
			if _heart != null:
				_heart.visible = true
			friend_made.emit(species)
	# Montura: el animal se mueve con el joystick, no con IA.
	if mounted:
		if _steer_dir.length() > 0.01:
			global_position += _steer_dir.normalized() * MOUNT_SPEED * delta
			rotation.y = atan2(_steer_dir.x, _steer_dir.z)
			var mangle := leg_angle(_time, 1.0)
			for i in range(_leg_pivots.size()):
				var mpivot := _leg_pivots[i] as Node3D
				if mpivot == null:
					continue
				mpivot.rotation.x = mangle if i % 2 == 0 else -mangle
		return
	# Manada: si un compañero de la misma especie huye cerca,
	# este también huye (packHelp del documento).
	var pack_fleeing := false
	for mate in packmates:
		if mate == self or not (mate is FriendlyAnimal):
			continue
		var other := mate as FriendlyAnimal
		if other.species != species or not other._fleeing:
			continue
		var mdx := other.global_position.x - global_position.x
		var mdz := other.global_position.z - global_position.z
		if sqrt(mdx * mdx + mdz * mdz) < 8.0:
			pack_fleeing = true
			break
	# Latches: persecución con histéresis (entra a 8, sale
	# a 20) y huida con tiempo de calma de 3 s.
	if temperament == "aggressive" and not tamed:
		if dist_xz < AGGRO_RADIUS:
			_chasing = true
		elif dist_xz > CHASE_DISTANCE:
			_chasing = false
	if temperament != "aggressive":
		if pack_fleeing or (sprinting and dist_xz < FLEE_RADIUS):
			_fleeing = true
			_calm_timer = CALM_SECONDS
		elif _fleeing:
			_calm_timer -= delta
			if _calm_timer <= 0.0:
				_fleeing = false
	var moving := false
	var speed := WANDER_SPEED
	if tamed:
		if dist_xz > FOLLOW_RADIUS:
			_target = Vector3(player_pos.x, global_position.y, player_pos.z)
			moving = true
			speed = FOLLOW_SPEED
	elif _chasing:
		_target = Vector3(player_pos.x, global_position.y, player_pos.z)
		moving = true
		speed = chase_speed()
	elif _fleeing:
		var away := global_position - Vector3(player_pos.x, global_position.y, player_pos.z)
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3(1.0, 0.0, 0.0)
		_target = global_position + away.normalized() * 6.0
		moving = true
		speed = FLEE_SPEED
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
	# Un solo desplazamiento por frame: movimiento de IA +
	# retroceso por golpe (con decaimiento). Dos escrituras
	# seguidas a global_position fuera del árbol se
	# sobrescriben; dentro del juego también es más limpio.
	var step := Vector3.ZERO
	if moving:
		var dir := (_target - global_position)
		dir.y = 0.0
		dir = dir.normalized()
		step += dir * speed * delta
		rotation.y = atan2(dir.x, dir.z)
	if _knockback.length() > 0.01:
		step += _knockback * delta
		_knockback = _knockback.move_toward(Vector3.ZERO, 8.0 * delta)
	if step.length() > 0.001:
		global_position += step
	# Ataque cuerpo a cuerpo del agresor (sin daño al
	# jugador aquí: emite y RefactorMain aplica vitales).
	if _chasing and not tamed and dist_xz < 1.5:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_attack_timer = 1.0
			attack_player.emit(10.0)
	var angle := leg_angle(_time, 1.0 if moving else 0.0)
	for i in range(_leg_pivots.size()):
		var pivot := _leg_pivots[i] as Node3D
		if pivot == null:
			continue
		pivot.rotation.x = angle if i % 2 == 0 else -angle
