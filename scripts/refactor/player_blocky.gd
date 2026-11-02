extends CharacterBody3D
## PlayerBlocky — jugador refactorizado de Bloques Mágicos.
##
## Qué cambia respecto a 1.15.0 (ver AUDITORIA-1.15.0.md):
## - 1.15.0 NO tenía PlayerBlocky.gd: el «jugador» era una Camera3D
##   movida a mano desde main.gd (2818 líneas) y un avatar de la
##   Plaza en hub.gd con look_at(), que aplasta cualquier pitch.
## - Aquí el jugador ES un CharacterBody3D con física real
##   (gravedad, salto, move_and_slide), un HeadAnchor para primera
##   persona y un ThirdPersonPivot (SpringArm3D) para tercera /
##   segunda persona / cenital. El pitch vive en esos dos nodos y
##   ya no se descarta ni se sobrescribe con un preset.
##
## CONVENCIÓN CANÓNICA DE ENTRADA (una sola, probada en
## tests/refactor/test_refactor.gd; no hay segundas definiciones):
## - Vector de entrada Vector2(x, y): x = derecha (+), y = adelante
##   (+). Joystick hacia arriba en pantalla = y +1 (la inversión
##   de la Y de pantalla se hace UNA sola vez, en
##   TouchAndTVControls, no aquí). Stick izquierdo hacia arriba
##   (JOY_AXIS_LEFT_Y negativo) = y +1. Tecla W / ui_up = y +1.
## - Adelante en el mundo = -transform.basis.z, aplanado a XZ.
##   Derecha en el mundo = transform.basis.x, aplanado a XZ.
## - Cámara: yaw en el cuerpo (rotate_y). Pitch en HeadAnchor y en
##   ThirdPersonPivot, eje X, clamp ±85°. Arrastrar el dedo hacia
##   arriba (relative.y negativo) = mirar arriba (pitch sube);
##   stick derecho hacia arriba (JOY_AXIS_RIGHT_Y negativo) =
##   mirar arriba. Arrastrar a la derecha = girar a la derecha
##   (yaw baja, como en 1.15.0).
##
## Perspectivas: FIRST (1ª), SECOND (2ª, vista frontal, la que usa
## la Mascota Feynman), THIRD (3ª) y TOP (cenital). En tercera /
## segunda / cenital la cámara mira siempre a la cabeza del
## jugador (look_at): el SpringArm pone la DISTANCIA (y acorta el
## brazo si choca con un bloque) y el look_at pone la DIRECCIÓN.
## Sin look_at, un pitch positivo haría mirar al cielo en vez de
## al jugador; por eso van juntos.

class_name PlayerBlocky

enum Perspective { FIRST, SECOND, THIRD, TOP }

# 3.0: valores del documento §7 (antes 4.0/6.5/2.0/7.0/
# 18.0/1.5). Salto 9.0 con gravedad 26.0 = 1.56 bloques,
# por encima del mínimo de 1.5 del documento.
const WALK_SPEED := 5.5
const SPRINT_SPEED := 8.25
const CROUCH_SPEED := 2.75
const FLY_SPEED := 6.0
const JUMP_VELOCITY := 9.0
const GRAVITY := 26.0
const PITCH_MIN := deg_to_rad(-85.0)
const PITCH_MAX := deg_to_rad(85.0)
const EYE_HEIGHT := 1.52
const TOP_HEIGHT := 9.0
# Ala delta 2.0 (plan de Cube): al caer, la velocidad de caída
# no pasa de -2.5 bloques/s. No es vuelo libre: solo frena la
# caída para que un niño no se asuste al bajar de una montaña.
const GLIDE_MAX_FALL := 2.5

@export var perspective: Perspective = Perspective.THIRD
@export var flying := false
@export var invert_y := false
@export var camera_sensitivity := 1.0

var move_input := Vector2.ZERO
var yaw := 0.0
var pitch := 0.0
var crouching := false
var sprinting := false
var jumping := false
var mounted := false # 3.0: encima de una montura, la física no manda.
var dodge_boost := Vector3.ZERO # 3.0: impulso de esquiva de un frame.
var speed_mult := 1.0 # 3.0: raza y capa lo ajustan.
## Función opcional (x, z) -> altura del suelo (índice del bloque
## superior + 1). La variante la conecta con VoxelWorldGenerator
## porque el terreno MultiMesh no tiene cuerpos de colisión:
## el suelo es por altura de columna, no por física de cuerpos.
## Limitación conocida (ver README): el jugador puede atravesar
## torres colocadas por encima del suelo si no están en la columna
## superior; la mira por ray-marching sí usa los bloques reales.
var ground_top_func: Callable = Callable()
var on_ground := false
## Ala delta 2.0: siempre activa al caer (sin botón nuevo, para
## no complicar el HUD de un niño). gliding dice si este frame
## está frenando la caída, para mostrar las alas.
var glider_enabled := true
var gliding := false

var _head_anchor: Node3D = null
var _camera_fp: Camera3D = null
var _pivot: SpringArm3D = null
var _camera_tp: Camera3D = null
var _visual: MeshInstance3D = null
var _wings: Array = []
var _hat: Node3D = null


func _ready() -> void:
	_head_anchor = get_node_or_null("HeadAnchor") as Node3D
	_camera_fp = get_node_or_null("HeadAnchor/CameraFP") as Camera3D
	_pivot = get_node_or_null("ThirdPersonPivot") as SpringArm3D
	_camera_tp = get_node_or_null("ThirdPersonPivot/CameraTP") as Camera3D
	_visual = get_node_or_null("Visual") as MeshInstance3D
	if _head_anchor != null:
		_head_anchor.position = Vector3(0.0, EYE_HEIGHT, 0.0)
	if _pivot != null:
		_pivot.position = Vector3(0.0, EYE_HEIGHT, 0.0)
		_pivot.spring_length = 3.4
	_build_wings()
	_apply_perspective()


func _build_wings() -> void:
	# Dos alas planas a los lados, solo visibles al planear.
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		wing.mesh = BoxMesh.new()
		(wing.mesh as BoxMesh).size = Vector3(0.9, 0.08, 0.5)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.95, 0.95)
		wing.material_override = mat
		wing.position = Vector3(0.85 * side, 1.35, 0.0)
		wing.visible = false
		add_child(wing)
		_wings.append(wing)


## Caída frenada por el ala delta. Pura, para tests.
static func glide_fall(velocity_y: float) -> float:
	return maxf(velocity_y, -GLIDE_MAX_FALL)


func _hat_box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = BoxMesh.new()
	(inst.mesh as BoxMesh).size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	inst.material_override = mat
	inst.position = pos
	return inst


## Sombrero y camiseta de AvatarCustom, en cubos propios.
## La camiseta cambia el material del cuerpo (nuevo material,
## no el recurso compartido de la escena). El sombrero se
## reconstruye cada vez: un sombrero viejo nunca queda pegado.
func apply_avatar(hat: String, shirt_color: Color) -> void:
	if _visual != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = shirt_color
		_visual.material_override = mat
	if _hat != null:
		remove_child(_hat)
		_hat.queue_free()
		_hat = null
	var group := Node3D.new()
	group.name = "AvatarHat"
	group.position = Vector3(0.0, 1.82, 0.0)
	var hat_color := AvatarCustom.hat_color(hat)
	match hat:
		"caballero":
			group.add_child(_hat_box(Vector3(0.7, 0.25, 0.7), hat_color, Vector3(0.0, 0.12, 0.0)))
			group.add_child(_hat_box(Vector3(0.15, 0.3, 0.15), Color(0.85, 0.15, 0.15), Vector3(0.4, 0.3, 0.0)))
		"astronauta":
			group.add_child(_hat_box(Vector3(0.9, 0.45, 0.9), hat_color, Vector3(0.0, 0.22, 0.0)))
			group.add_child(_hat_box(Vector3(0.6, 0.25, 0.12), Color(0.65, 0.85, 0.95), Vector3(0.0, 0.22, 0.48)))
		"rana":
			group.add_child(_hat_box(Vector3(0.85, 0.18, 0.85), hat_color, Vector3(0.0, 0.09, 0.0)))
			group.add_child(_hat_box(Vector3(0.22, 0.25, 0.22), hat_color, Vector3(-0.25, 0.28, 0.2)))
			group.add_child(_hat_box(Vector3(0.22, 0.25, 0.22), hat_color, Vector3(0.25, 0.28, 0.2)))
		_:
			group.add_child(_hat_box(Vector3(1.0, 0.15, 1.0), hat_color, Vector3(0.0, 0.07, 0.0)))
			group.add_child(_hat_box(Vector3(0.6, 0.3, 0.6), hat_color, Vector3(0.0, 0.22, 0.0)))
	add_child(group)
	_hat = group
	_hat.visible = perspective != Perspective.FIRST


## Dirección de movimiento en el mundo a partir del vector de
## entrada y del yaw. Función estática pura: es la que prueban
## los tests headless, sin instanciar la escena.
static func move_direction(input: Vector2, yaw_rad: float) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	# Adelante = (-sin(yaw), 0, -cos(yaw)) = -basis.z aplanado.
	var forward := Vector3(-sin(yaw_rad), 0.0, -cos(yaw_rad))
	# Derecha = (cos(yaw), 0, -sin(yaw)) = basis.x aplanado.
	var right := Vector3(cos(yaw_rad), 0.0, -sin(yaw_rad))
	var dir := right * input.x + forward * input.y
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()


## Nuevo pitch tras un arrastre o un stick. Estática pura para
## tests: drag_up positivo = dedo hacia arriba.
static func apply_pitch(current: float, drag_up: float, stick_up: float, sensitivity: float, inverted: bool) -> float:
	var delta := (drag_up + stick_up) * 0.005 * sensitivity
	if inverted:
		delta = -delta
	return clampf(current + delta, PITCH_MIN, PITCH_MAX)


## Nuevo yaw tras un arrastre horizontal. drag_right positivo =
## dedo hacia la derecha = girar a la derecha (yaw baja).
static func apply_yaw(current: float, drag_right: float, sensitivity: float) -> float:
	return current - drag_right * 0.005 * sensitivity


func set_move_input(input: Vector2) -> void:
	move_input = input


func add_camera_drag(relative: Vector2, sensitivity: float = -1.0) -> void:
	var sens := camera_sensitivity if sensitivity < 0.0 else sensitivity
	# relative.y negativo = dedo hacia arriba = mirar arriba.
	yaw = apply_yaw(yaw, relative.x, sens)
	pitch = apply_pitch(pitch, -relative.y, 0.0, sens, invert_y)


func add_right_stick(axis_x: float, axis_y: float, delta: float, sensitivity: float = -1.0) -> void:
	var sens := camera_sensitivity if sensitivity < 0.0 else sensitivity
	if absf(axis_x) > 0.2:
		yaw -= axis_x * deg_to_rad(90.0) * sens * delta
	if absf(axis_y) > 0.2:
		# axis_y negativo = stick hacia arriba = mirar arriba.
		pitch = apply_pitch(pitch, 0.0, -axis_y * 160.0 * delta, sens, invert_y)


func cycle_perspective() -> Perspective:
	match perspective:
		Perspective.FIRST:
			perspective = Perspective.SECOND
		Perspective.SECOND:
			perspective = Perspective.THIRD
		Perspective.THIRD:
			perspective = Perspective.TOP
		_:
			perspective = Perspective.FIRST
	_apply_perspective()
	return perspective


func set_perspective(value: Perspective) -> void:
	perspective = value
	_apply_perspective()


func _apply_perspective() -> void:
	if _camera_fp != null:
		_camera_fp.current = perspective == Perspective.FIRST
	if _camera_tp != null:
		_camera_tp.current = perspective != Perspective.FIRST
	if _visual != null:
		# En primera persona el propio cuerpo no debe verse.
		_visual.visible = perspective != Perspective.FIRST
	if _hat != null:
		_hat.visible = perspective != Perspective.FIRST
	if _pivot != null:
		match perspective:
			Perspective.THIRD:
				_pivot.spring_length = 3.4
				_pivot.rotation.y = 0.0
			Perspective.SECOND:
				# Vista frontal (Mascota Feynman): el brazo apunta
				# hacia adelante, la cámara queda frente al jugador.
				_pivot.spring_length = 2.6
				_pivot.rotation.y = PI
			Perspective.TOP:
				_pivot.spring_length = TOP_HEIGHT
				_pivot.rotation.y = 0.0
			_:
				_pivot.spring_length = 3.4
				_pivot.rotation.y = 0.0


func _physics_process(delta: float) -> void:
	# 3.0 montura: quieto, sin gravedad ni entrada; la
	# montura mueve al jugador desde RefactorMain.
	if mounted:
		velocity = Vector3.ZERO
		return
	# Entrada efectiva de este frame. move_input lo alimenta el HUD
	# táctil cada frame; si viene en cero, se lee teclado/mando
	# como respaldo EN UNA VARIABLE LOCAL (nunca se escribe en
	# move_input, o la entrada de teclado quedaría pegada al
	# soltar la tecla).
	var effective := move_input
	if effective == Vector2.ZERO:
		if not Input.get_connected_joypads().is_empty():
			var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
			# get_vector devuelve y = atrás - adelante; adelante es +y.
			effective = Vector2(raw.x, -raw.y)
		if effective == Vector2.ZERO:
			if Input.is_action_pressed("ui_up"):
				effective.y += 1.0
			if Input.is_action_pressed("ui_down"):
				effective.y -= 1.0
			if Input.is_action_pressed("ui_left"):
				effective.x -= 1.0
			if Input.is_action_pressed("ui_right"):
				effective.x += 1.0

	rotation.y = yaw
	if _head_anchor != null:
		_head_anchor.rotation.x = pitch
	if _pivot != null:
		if perspective == Perspective.TOP:
			# Cenital: brazo casi vertical (80°) para quedar alto;
			# el look_at de abajo apunta la cámara al jugador.
			_pivot.rotation.x = deg_to_rad(80.0)
		else:
			_pivot.rotation.x = pitch

	var speed := WALK_SPEED
	if sprinting:
		speed = SPRINT_SPEED
	if crouching and not flying:
		speed = CROUCH_SPEED
	if flying:
		speed = FLY_SPEED
	speed *= speed_mult

	var dir := move_direction(effective, yaw)
	if flying:
		var vy := 0.0
		if jumping:
			vy += FLY_SPEED
		if crouching:
			vy -= FLY_SPEED
		velocity = dir * speed
		velocity.y = vy
		on_ground = false
	else:
		var ground_y := 1.0
		if ground_top_func.is_valid():
			ground_y = float(ground_top_func.call(floori(global_position.x), floori(global_position.z)))
		on_ground = global_position.y <= ground_y + 0.01
		if on_ground and jumping:
			velocity.y = JUMP_VELOCITY
			on_ground = false
		elif not on_ground:
			velocity.y -= GRAVITY * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	# Ala delta 2.0: frenar la caída, nunca empujar hacia arriba.
	gliding = false
	if not flying and not on_ground and glider_enabled and velocity.y < -GLIDE_MAX_FALL:
		velocity.y = glide_fall(velocity.y)
		gliding = true
	# 3.0 esquiva: impulso de un frame, se consume aquí.
	if dodge_boost.length() > 0.01:
		velocity += dodge_boost
		dodge_boost = Vector3.ZERO
	move_and_slide()
	for wing in _wings:
		(wing as MeshInstance3D).visible = gliding and perspective != Perspective.FIRST
	if not flying and ground_top_func.is_valid():
		var gy := float(ground_top_func.call(floori(global_position.x), floori(global_position.z)))
		if global_position.y < gy and velocity.y <= 0.0:
			global_position.y = gy
			velocity.y = 0.0
			on_ground = true
	# La cámara de tercera/segunda/cenital mira a la cabeza.
	if perspective != Perspective.FIRST and _camera_tp != null and _head_anchor != null:
		_camera_tp.look_at(_head_anchor.global_position, Vector3.UP)
	# Consumir el salto de un frame: el llamador pone jumping=true
	# el frame que se pulsa Saltar; aquí se aplica y se limpia.
	jumping = false
