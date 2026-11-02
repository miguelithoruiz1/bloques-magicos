extends CanvasLayer
## TouchControls 1.14.0 — nodo raíz CanvasLayer para la UI móvil
## del mundo (main.tscn) Y de la Plaza (hub.tscn). La lógica pura
## (joystick normalizado, cámara por arrastre, hold) vive en
## InputController y NO se duplica: esta escena solo construye la
## UI y emite el vector / los deltas.
##
## Variante Plaza (hub.gd la instancia con estos dos parámetros
## antes de añadirla al árbol; el mundo no los toca y queda igual
## que en la 1.13.0):
## - enable_interact = false: el área de cámara solo gira la
##   vista; no emite tap_interact ni hold_interact (en la Plaza
##   no se coloca ni se quita nada).
## - camera_bottom_offset = -200.0: el área de cámara termina
##   200 px antes del borde inferior, por encima de la fila de
##   botones «Entrar» / «Ajustes» (margen 96 + alto 84 = 180 px),
##   para no taparlos. En el mundo el valor es -170.0 (la franja
##   de la paleta queda libre para sus botones).
##
## Layout (horizontal, stretch/mode = canvas_items en
## project.godot, así que escala con la resolución):
## - Joystick virtual, zona FIJA abajo a la izquierda, POR ENCIMA
##   de la paleta (mundo) / de la fila de botones (Plaza):
##   base 240×240, borde inferior a 190 px (por encima de ambas
##   franjas, 170 px mundo / 180 px Plaza).
## - Área de cámara, mitad derecha, desde arriba hasta
##   camera_bottom_offset antes del borde inferior.
## - El área de cámara distingue: arrastre > 24 px = girar cámara;
##   toque corto (< 0.45 s, sin arrastre) = colocar; mantener
##   >= 0.45 s sin arrastre = quitar. Solo con enable_interact.
##
## Foco: si hay un mando conectado, la capa se oculta sola
## (visible = false) y no interfiere; al desconectarse vuelve si
## el ajuste de control es táctil (o la exportación es de celular).
## gesture_active avisa a main.gd para que el tacto emulado como
## ratón NO procese el mismo gesto dos veces.

const InputController := preload("res://scripts/input_controller.gd")
const SettingsSave := preload("res://scripts/settings_save.gd")

signal tap_interact(screen_pos: Vector2)
signal hold_interact(screen_pos: Vector2)

## 1.14.0: parámetros de variante (ver cabecera). El mundo usa
## los valores por defecto; la Plaza los cambia antes de añadir.
@export var enable_interact := true
@export var camera_bottom_offset := -170.0

var move_vector := Vector2.ZERO
var camera_yaw_delta := 0.0
var camera_pitch_delta := 0.0
var gesture_active := false

var _joy_base: Control = null
var _joy_knob: Control = null
var _joy_center := Vector2.ZERO
var _joy_finger := -1
var _joy_radius := 110.0
var _cam_area: Control = null
var _cam_finger := -1
var _cam_start := Vector2.ZERO
var _cam_last := Vector2.ZERO
var _cam_dragged := false
var _cam_hold := InputController.new()
var _cam_hold_fired := false
var _control_cache := "tv"
var _sens_cache := 1.0
var _control_timer := 0.0


func _ready() -> void:
	layer = 5
	_control_cache = String(SettingsSave.load_settings().get("control", "tv"))
	_build_ui()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Joystick fijo abajo a la izquierda, por encima de la paleta.
	_joy_base = Control.new()
	_joy_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy_base.offset_left = 36.0
	_joy_base.offset_top = -430.0
	_joy_base.offset_right = 36.0 + 240.0
	_joy_base.offset_bottom = -190.0
	_joy_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_joy_base.gui_input.connect(_on_joy_gui_input)
	root.add_child(_joy_base)
	# Sin fondo de pantalla completa: un ColorRect a pantalla
	# completa taparía los botones de la paleta. La zona del
	# joystick es su propio rect (240×240) y el knob la marca.
	_joy_knob = Control.new()
	_joy_knob.custom_minimum_size = Vector2(96, 96)
	_joy_knob.position = Vector2(72, 72)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_bg := ColorRect.new()
	knob_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	knob_bg.color = Color(1.0, 1.0, 1.0, 0.55)
	_joy_knob.add_child(knob_bg)
	_joy_base.add_child(_joy_knob)
	# Área de cámara: mitad derecha, sin la franja de la paleta.
	_cam_area = Control.new()
	_cam_area.set_anchor(SIDE_LEFT, 0.5)
	_cam_area.set_anchor(SIDE_TOP, 0.0)
	_cam_area.set_anchor(SIDE_RIGHT, 1.0)
	_cam_area.set_anchor(SIDE_BOTTOM, 1.0)
	_cam_area.offset_left = 0.0
	_cam_area.offset_top = 0.0
	_cam_area.offset_right = 0.0
	_cam_area.offset_bottom = camera_bottom_offset
	_cam_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_cam_area.gui_input.connect(_on_cam_gui_input)
	root.add_child(_cam_area)


func _process(delta: float) -> void:
	_control_timer -= delta
	if _control_timer <= 0.0:
		_control_timer = 1.0
		var aj := SettingsSave.load_settings()
		_control_cache = String(aj.get("control", "tv"))
		_sens_cache = float(aj.get("sensibilidad_camara", 1.0))
	var show := not InputController.has_gamepad() and (_control_cache == "tactil" or OS.has_feature("phone"))
	# Si el ajuste dice mando TV y hay mando, se oculta (caso TV);
	# si el ajuste dice táctil, el mando lo oculta igual (foco).
	if InputController.has_gamepad():
		show = false
	visible = show
	if not visible:
		move_vector = Vector2.ZERO
		gesture_active = false
		return
	# Hold del área de cámara (quitar al mantener). Solo con
	# interacción activa: en la Plaza no hay nada que quitar.
	if enable_interact and _cam_finger >= 0 and not _cam_dragged:
		if _cam_hold.hold_update(delta) == "hold":
			_cam_hold_fired = true
			hold_interact.emit(_cam_start)


func _on_joy_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _joy_finger < 0:
			_joy_finger = t.index
			_joy_center = _joy_base.get_global_rect().get_center()
			gesture_active = true
			_update_joy(t.position)
		elif not t.pressed and t.index == _joy_finger:
			_joy_finger = -1
			move_vector = Vector2.ZERO
			_joy_knob.position = Vector2(72, 72)
			gesture_active = false
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_finger:
			_update_joy(d.position)


func _update_joy(pos: Vector2) -> void:
	var offset := pos - _joy_center
	if offset.length() > _joy_radius:
		offset = offset.normalized() * _joy_radius
	_joy_knob.position = Vector2(72, 72) + offset - Vector2(48, 48)
	# Arriba en pantalla = adelante: y positivo = adelante.
	move_vector = InputController.normalize_joystick(Vector2(offset.x, -offset.y) / _joy_radius)


func _on_cam_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _cam_finger < 0:
			_cam_finger = t.index
			_cam_start = t.position
			_cam_last = t.position
			_cam_dragged = false
			_cam_hold_fired = false
			_cam_hold.hold_press()
			gesture_active = true
		elif not t.pressed and t.index == _cam_finger:
			var result := _cam_hold.hold_release()
			if enable_interact and result == "tap" and not _cam_dragged:
				tap_interact.emit(_cam_start)
			_cam_finger = -1
			gesture_active = false
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _cam_finger:
			if (d.position - _cam_start).length() > InputController.TAP_MAX_DRAG:
				_cam_dragged = true
			if _cam_dragged:
				var rel := d.position - _cam_last
				_cam_last = d.position
				var cd := InputController.camera_delta(rel, _sens_cache)
				camera_yaw_delta += cd.x
				camera_pitch_delta += cd.y
