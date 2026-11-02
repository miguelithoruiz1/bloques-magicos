extends RefCounted
## Entrada dual 1.13.0 — estilo Minecraft clásico («Joystick y pulsar
## para interactuar»), lógica PURA sin nodos, para que las pruebas
## headless la ejerciten sin escena.
##
## Contrato de unificación (lo que pide la especificación):
## tanto el joystick virtual táctil como el mando físico escriben en
## UNA sola variable del jugador, `_current_input_velocity` en
## main.gd (Vector2: x = lateral, y = adelante, ambos en [-1, 1]).
## Ninguna fuente duplica la lógica de movimiento: main.gd solo lee
## esa variable (o el vector táctil, que es la misma fuente).
##
## Mapa de fuentes (contexto, no magia):
## - Construcción: A/OK = colocar (ya existía), B = quitar (ya
##   existía), RT/LT = altura del cursor (ya existía). En ese modo
##   los gatillos NO son atacar/usar: no hay a quién atacar.
## - Paseo (avatar): A = saltar (o subir si vuela), B = agacharse
##   (o bajar si vuela), RT = quitar el bloque apuntado, LT =
##   poner el bloque apuntado, X = abrir la paleta (inventario:
##   NO hay crafteo en el juego, ver huecos abajo), LB/RB = cambiar
##   la selección de la paleta. El joystick izquierdo mueve y el
##   derecho gira la cámara.
##
## Huecos explícitos (versión mínima, documentada, no fingida):
## - Volar: solo como modo opcional en Ajustes (volar: No/Sí). Si
##   está apagado, A salta con gravedad simple y B agacha. Si está
##   encendido, A/B suben/bajan la altura de cámara sin colisión
##   nueva: el avatar sigue en su celda 2D, solo la cámara sube.
## - Fabricar: NO existe en el juego. X abre la paleta (la
##   selección de bloques = inventario). No se inventó un sistema
##   de crafteo.
## - Agacharse: reduce velocidad y baja la cámara; no cambia la
##   colisión (el juego no tiene colisión por altura en paseo).

const DEADZONE := 0.2
const SPRINT_MAGNITUDE := 0.98
const SPRINT_HOLD_SECONDS := 0.30
const HOLD_SECONDS := 0.45
const TAP_MAX_DRAG := 24.0

var move_vector := Vector2.ZERO
var sprinting := false
var _sprint_timer := 0.0
var _hold_timer := 0.0
var _hold_fired := false
var _hold_active := false


## Vector normalizado con zona muerta: fuera del radio máximo se
## recorta a longitud 1, dentro de la zona muerta es cero.
static func normalize_joystick(raw: Vector2, deadzone: float = DEADZONE) -> Vector2:
	if raw.length() < deadzone:
		return Vector2.ZERO
	if raw.length() > 1.0:
		return raw.normalized()
	return raw


## Vector del mando desde las acciones ya existentes (move_*).
## Devuelve Vector2(lateral, adelante): adelante positivo.
static func pad_vector() -> Vector2:
	var raw := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return Vector2(raw.x, -raw.y)


static func has_gamepad() -> bool:
	return Input.get_connected_joypads().size() > 0


## Sprint «correr sencillo»: el joystick (virtual o físico) debe
## mantenerse al 100% (magnitud >= 0.98) de forma sostenida
## SPRINT_HOLD_SECONDS. Se pierde al bajar de 0.85.
func update_sprint(magnitude: float, delta: float) -> bool:
	if magnitude >= SPRINT_MAGNITUDE:
		_sprint_timer += delta
		if _sprint_timer >= SPRINT_HOLD_SECONDS:
			sprinting = true
	elif magnitude < 0.85:
		_sprint_timer = 0.0
		sprinting = false
	return sprinting


## Delta de cámara para un arrastre: arrastrar a la derecha gira a
## la derecha (mismo signo que el arrastre con ratón de main.gd:
## _yaw_target -= relative.x * 0.01). Sensibilidad en Ajustes.
static func camera_delta(drag: Vector2, sensitivity: float) -> Vector2:
	return Vector2(-drag.x * 0.005 * sensitivity, -drag.y * 0.005 * sensitivity)


## Temporizador de presión táctil. hold_press() al bajar el dedo,
## hold_update(delta) cada frame: devuelve "hold" UNA sola vez al
## cumplir HOLD_SECONDS. hold_release() al soltar: devuelve "tap"
## si no se disparó el hold, "" en caso contrario.
func hold_press() -> void:
	_hold_timer = 0.0
	_hold_fired = false
	_hold_active = true


func hold_update(delta: float) -> String:
	if not _hold_active or _hold_fired:
		return ""
	_hold_timer += delta
	if _hold_timer >= HOLD_SECONDS:
		_hold_fired = true
		return "hold"
	return ""


func hold_release() -> String:
	var result := ""
	if _hold_active and not _hold_fired:
		result = "tap"
	_hold_active = false
	_hold_fired = false
	_hold_timer = 0.0
	return result


## Dirección de paso discreta (rejilla) a partir de un vector
## continuo: el eje dominante manda; si no supera la zona muerta,
## Vector2i.ZERO.
static func step_direction(vec: Vector2) -> Vector2i:
	if vec.length() < DEADZONE:
		return Vector2i.ZERO
	if absf(vec.x) >= absf(vec.y):
		return Vector2i(1 if vec.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if vec.y > 0.0 else -1)


## 1.14.0 — Plaza: paso hacia adelante a partir de un yaw
## CONTINUO. El vector de avance es (-sin(yaw), -cos(yaw)) y se
## cuantiza al eje dominante, igual que hacía hub.gd con pasos de
## 45°: el yaw continuo de la cámara por arrastre sigue dando
## pasos coherentes en la rejilla (4 rumbos), sin movimiento
## continuo ni diagonales. Es la única fuente de esta cuantización:
## hub.gd `_paso()` la usa, no la duplica.
static func hub_forward_step(yaw: float) -> Vector2i:
	var f := Vector2(-sin(yaw), -cos(yaw))
	if absf(f.x) > absf(f.y):
		return Vector2i(1 if f.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if f.y > 0.0 else -1)


## 1.14.0 — Plaza: intervalo entre pasos repetidos. Base
## 0.2 / caminar (la de siempre); con sprint del joystick
## sostenido al 100% se acorta a 0.65×, como el paseo de main.gd.
static func hub_step_interval(caminar: float, sprinting: bool) -> float:
	var base := 0.2 / caminar
	return base * 0.65 if sprinting else base


## 1.14.0 — Plaza: velocidad de giro continuo del joystick
## lateral, en rad/s a deflexión máxima, escalada por el ajuste
## «giro» (0.5 lento / 1.0 normal / 1.5 rápido). Signo: el
## llamador resta (joystick a la derecha = girar a la derecha,
## igual que move_right, que resta 45° al yaw).
static func hub_turn_rate(giro: float) -> float:
	return deg_to_rad(120.0) * giro
