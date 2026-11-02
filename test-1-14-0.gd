extends Node
## Test headless de Bloques Mágicos 1.14.0 (controles duales en
## TODO el juego: Plaza con el mismo esquema que el mundo).
## Uso (¡NO con -s!): los scripts de hub/main/menu usan el
## autoload GameState, que el modo -s de Godot no carga y hace
## fallar la compilación. Con escena normal sí cargan:
##   godot --headless --path <build> res://test-1-14-0.tscn
## Sale con código 1 si algún chequeo falla. Lógica pura +
## instanciación real de escenas + llamadas directas a hub._process
## con el vector del joystick inyectado (sin hardware real: el
## mando físico y el dedo solo se prueban en stick/celular con
## la lista de prueba; el ocultado con mando se verifica a nivel
## de código compartido, ver chequeos 9).

const LD := preload("res://scripts/levels_data.gd")
const PS := preload("res://scripts/progress_save.gd")
const SS := preload("res://scripts/settings_save.gd")
const WS := preload("res://scripts/world_save.gd")
const IC := preload("res://scripts/input_controller.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("OK: ", msg)
	else:
		_fails += 1
		printerr("FAIL: ", msg)


func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	return s


func _ready() -> void:
	# 1. Cuantización Plaza: yaw continuo -> 4 rumbos de rejilla.
	_check(IC.hub_forward_step(0.0) == Vector2i(0, -1), "plaza: yaw 0 avanza -Z")
	_check(IC.hub_forward_step(PI / 2.0) == Vector2i(-1, 0), "plaza: yaw 90 avanza -X")
	_check(IC.hub_forward_step(PI) == Vector2i(0, 1), "plaza: yaw 180 avanza +Z")
	_check(IC.hub_forward_step(-PI / 2.0) == Vector2i(1, 0), "plaza: yaw -90 avanza +X")
	_check(IC.hub_forward_step(PI / 4.0) == Vector2i(0, -1), "plaza: yaw 45 frontera cae a -Z (eje Z)")
	_check(IC.hub_step_interval(1.0, false) == 0.2, "plaza: intervalo base 0.2 s")
	_check(is_equal_approx(IC.hub_step_interval(1.0, true), 0.13), "plaza: sprint acorta a 0.13 s")
	_check(is_equal_approx(IC.hub_turn_rate(1.0), deg_to_rad(120.0)), "plaza: giro 120 deg/s a giro normal")
	_check(is_equal_approx(IC.hub_turn_rate(1.5), deg_to_rad(180.0)), "plaza: giro 1.5 escala el giro")
	# 2. Lógica pura 1.13.0 intacta (joystick, cámara, sprint, hold).
	_check(IC.normalize_joystick(Vector2(0.1, 0.0)) == Vector2.ZERO, "1.13 intacto: zona muerta")
	_check(IC.camera_delta(Vector2(100.0, 0.0), 1.5) == Vector2(-0.75, 0.0), "camara: sensibilidad 1.5 en arrastre")
	var ctrl := IC.new()
	_check(ctrl.update_sprint(1.0, 0.35) == true, "1.13 intacto: sprint a los 0.35 s")
	_check(IC.step_direction(Vector2(0.1, 0.9)) == Vector2i(0, 1), "1.13 intacto: paso dominante Y")
	# 3. TouchControls: variante Plaza por parámetros, sin duplicar.
	var tc_scene = load("res://touch_controls.tscn")
	var tc = tc_scene.instantiate()
	_check(tc is CanvasLayer, "touchcontrols: raiz CanvasLayer")
	_check(tc.enable_interact == true, "touchcontrols: mundo por defecto con interact")
	_check(tc.camera_bottom_offset == -170.0, "touchcontrols: mundo por defecto franja -170")
	tc.enable_interact = false
	tc.camera_bottom_offset = -200.0
	_check(tc.enable_interact == false, "touchcontrols: variante Plaza sin interact")
	_check(tc.camera_bottom_offset == -200.0, "touchcontrols: variante Plaza franja -200")
	add_child(tc)
	# 4. Plaza: instancia real, 8 portales, TouchControls Plaza.
	var hub_scene = load("res://hub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)
	_check(hub._portales.size() == 8, "plaza: 8 portales")
	var tiene_ajustes := false
	for p in hub._portales:
		if String(p["def"].get("tipo", "")) == "ajustes":
			tiene_ajustes = true
	_check(tiene_ajustes, "plaza: portal Ajustes presente")
	_check(hub._touch_controls != null, "plaza: instancia TouchControls")
	_check(hub._touch_controls.enable_interact == false, "plaza: TouchControls sin tap/hold")
	_check(hub._touch_controls.camera_bottom_offset == -200.0, "plaza: camara termina 200 px antes (no tapa botones)")
	_check(hub._input_ctrl != null, "plaza: InputController propio (logica compartida)")
	# 5. Plaza: joystick adelante = pasos repetidos; soltar = parar.
	hub._touch_controls.visible = true
	hub._touch_controls.move_vector = Vector2(0.0, 1.0)
	hub._celda = Vector2i(0, 0)
	hub._yaw = 0.0
	hub._move_timer = 0.0
	hub._process(0.25)
	_check(hub._celda == Vector2i(0, -1), "plaza: joystick adelante da 1 paso")
	hub._process(0.25)
	_check(hub._celda == Vector2i(0, -2), "plaza: joystick mantenido da pasos repetidos")
	hub._touch_controls.move_vector = Vector2.ZERO
	hub._process(0.25)
	_check(hub._celda == Vector2i(0, -2), "plaza: al soltar se detiene")
	_check(hub._move_timer == 0.0, "plaza: al soltar el temporizador resetea")
	# 6. Plaza: joystick atrás y lateral = giro (sin paso lateral).
	hub._touch_controls.move_vector = Vector2(0.0, -1.0)
	hub._move_timer = 0.0
	hub._process(0.25)
	_check(hub._celda == Vector2i(0, -1), "plaza: joystick atras da paso atras")
	var celda_antes: Vector2i = hub._celda
	hub._touch_controls.move_vector = Vector2(1.0, 0.0)
	hub._yaw = 0.0
	hub._process(0.5)
	_check(hub._celda == celda_antes, "plaza: joystick lateral no da pasos")
	_check(hub._yaw < -1.0 and hub._yaw > -1.1, "plaza: joystick lateral gira continuo (~-60 deg en 0.5 s)")
	# 7. Plaza: cámara por arrastre con sensibilidad (delta ya
	# calculado por TouchControls; hub lo consume y lo pone a 0).
	hub._touch_controls.move_vector = Vector2.ZERO
	hub._touch_controls.camera_yaw_delta = -0.5
	var yaw_antes: float = hub._yaw
	hub._process(0.016)
	_check(is_equal_approx(hub._yaw, yaw_antes - 0.5), "plaza: arrastre derecho gira el yaw")
	_check(hub._touch_controls.camera_yaw_delta == 0.0, "plaza: delta de camara consumido")
	# 8. Reglas que NO cambian: Entrar <=4, bloqueo >4 y candado.
	hub._celda = Vector2i(0, 0)
	var cercano: Dictionary = hub._portal_cercano()
	var dist_lejos: int = absi(int(cercano["celda"].x) - hub._celda.x) + absi(int(cercano["celda"].y) - hub._celda.y)
	_check(dist_lejos > 4, "plaza: desde (0,0) el portal mas cercano esta a >4")
	hub._entrar_delante()
	_check(hub._mensaje_label.text == "Acércate más al portal para entrar", "plaza: a >4 pasos pide acercarse (no entra)")
	hub._celda = Vector2i(-2, -4)
	var cerca2: Dictionary = hub._portal_cercano()
	var dist_cerca: int = absi(int(cerca2["celda"].x) - hub._celda.x) + absi(int(cerca2["celda"].y) - hub._celda.y)
	_check(dist_cerca <= 4, "plaza: junto al portal la distancia es <=4")
	hub._entrar_portal({"def": {"id": "colores", "nombre": "Colores", "tipo": "mundo"}, "celda": Vector2i(-2, -4), "bloqueado": true, "texto": "Colores"})
	_check(String(hub._mensaje_label.text).contains("cerrado"), "plaza: portal bloqueado no abre (mensaje cerrado)")
	# 9. Mando que oculta táctiles: mismo código que el mundo
	# 1.13.0 (sin mando físico en headless no se puede emular un
	# joypad; se verifica el código compartido + la lista manual).
	var tc_txt := _read("res://scripts/touch_controls.gd")
	_check(tc_txt.contains("has_gamepad()"), "mando: TouchControls consulta has_gamepad")
	_check(tc_txt.contains("visible = show"), "mando: TouchControls oculta/muestra por mando")
	_check(tc_txt.contains("if InputController.has_gamepad():"), "mando: con mando visible=false")
	var hub_txt := _read("res://scripts/hub.gd")
	_check(hub_txt.contains("TouchControlsScene"), "plaza: hub instancia TouchControlsScene")
	_check(not hub_txt.contains("_touch_dir_button"), "plaza: cruceta vieja eliminada (sin _touch_dir_button)")
	_check(not hub_txt.contains("GridContainer"), "plaza: cruceta vieja eliminada (sin GridContainer)")
	_check(hub_txt.contains("hub_forward_step"), "plaza: paso usa InputController, no copia")
	_check(hub_txt.contains("enable_interact = false"), "plaza: variante sin interact")
	# 10. Mundo 1.13.0 intacto + resto de escenas instancian.
	var main_txt := _read("res://scripts/main.gd")
	_check(main_txt.contains("_current_input_velocity"), "mundo: variable unica intacta")
	_check(main_txt.contains("_step_walk_side"), "mundo: paso lateral intacto")
	_check(main_txt.contains("TouchControlsScene"), "mundo: instancia TouchControls")
	_check(LD.get_niveles("colores").size() == 10, "1.12 intacto: 10 niveles colores")
	_check(LD.COLORES_NOMBRES.size() == 12, "1.12 intacto: 12 colores")
	_check(LD.LETRAS.size() == 27, "1.12 intacto: 27 letras")
	var prog: Dictionary = {"colores": [0, 1]}
	_check(PS.is_unlocked(prog, "colores", 2), "1.12 intacto: desbloqueo")
	_check(WS.SAVE_VERSION == 2, "1.12 intacto: world_save v2")
	var def := SS.defaults()
	_check(float(def["sensibilidad_camara"]) == 1.0, "ajuste: sensibilidad por defecto 1.0")
	var proj_txt := _read("res://project.godot")
	_check(proj_txt.contains('config/version="1.14.0"'), "project: version 1.14.0")
	_check(proj_txt.contains("canvas_items"), "project: stretch canvas_items")
	var main_scene = load("res://main.tscn")
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	_check(main_inst != null, "escena: main.tscn instancia")
	var settings_scene = load("res://settings.tscn")
	var settings_inst = settings_scene.instantiate()
	add_child(settings_inst)
	_check(settings_inst != null, "escena: settings.tscn instancia (sin joystick)")
	var settings_txt := _read("res://scripts/settings.gd")
	_check(not settings_txt.contains("TouchControls"), "ajustes: pantalla de botones, sin joystick")
	var menu_scene = load("res://menu.tscn")
	var menu_inst = menu_scene.instantiate()
	add_child(menu_inst)
	_check(menu_inst != null, "escena: menu.tscn instancia (sin joystick)")

	print("CHECKS: ", _checks, " FAILS: ", _fails)
	if _fails > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
