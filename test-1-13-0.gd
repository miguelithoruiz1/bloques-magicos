extends SceneTree
## Test headless de Bloques Mágicos 1.13.0 (entrada dual Minecraft).
## Uso: godot --headless --path <build> -s test-1-13-0.gd
## Sale con código 1 si algún chequeo falla. Lógica pura + lectura
## de archivos; el hardware real (mando, dedo) solo se prueba en
## stick/celular con la lista de prueba.

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


func _init() -> void:
	# 1. Joystick normalizado [-1, 1] con zona muerta.
	_check(IC.normalize_joystick(Vector2(0.1, 0.0)) == Vector2.ZERO, "joystick: zona muerta a cero")
	_check(IC.normalize_joystick(Vector2(2.0, 0.0)) == Vector2(1.0, 0.0), "joystick: recorte a 1")
	_check(IC.normalize_joystick(Vector2(0.5, 0.0)) == Vector2(0.5, 0.0), "joystick: 0.5 intacto")
	_check(IC.normalize_joystick(Vector2(-0.3, 0.4)) == Vector2(-0.3, 0.4), "joystick: vector medio intacto")
	# 2. Sprint sostenido al 100%.
	var ctrl := IC.new()
	_check(ctrl.update_sprint(1.0, 0.1) == false, "sprint: no a los 0.1 s")
	_check(ctrl.update_sprint(1.0, 0.1) == false, "sprint: no a los 0.2 s")
	_check(ctrl.update_sprint(1.0, 0.15) == true, "sprint: si a los 0.35 s sostenidos")
	_check(ctrl.update_sprint(0.5, 0.1) == false, "sprint: se pierde al bajar de 0.85")
	# 3. Cámara por arrastre derecho (signo = ratón de main.gd).
	var cd := IC.camera_delta(Vector2(100.0, 0.0), 1.0)
	_check(cd == Vector2(-0.5, 0.0), "camara: arrastre derecha gira derecha")
	var cd2 := IC.camera_delta(Vector2(0.0, 50.0), 1.5)
	_check(cd2 == Vector2(0.0, -0.375), "camara: sensibilidad 1.5 aplica")
	# 4. Hold timer: toque corto = tap, mantener = hold una vez.
	var h := IC.new()
	h.hold_press()
	_check(h.hold_update(0.2) == "", "hold: no dispara a los 0.2 s")
	_check(h.hold_update(0.3) == "hold", "hold: dispara a los 0.5 s")
	_check(h.hold_update(0.5) == "", "hold: solo una vez")
	_check(h.hold_release() == "", "hold: soltar tras hold no es tap")
	var h2 := IC.new()
	h2.hold_press()
	_check(h2.hold_release() == "tap", "tap: soltar rapido es tap")
	# 5. Dirección de paso discreta desde vector continuo.
	_check(IC.step_direction(Vector2(0.9, 0.1)) == Vector2i(1, 0), "paso: dominante X")
	_check(IC.step_direction(Vector2(0.1, 0.9)) == Vector2i(0, 1), "paso: dominante Y")
	_check(IC.step_direction(Vector2(0.1, 0.0)) == Vector2i.ZERO, "paso: zona muerta")
	# 6. Ajustes nuevos guardados/cargados, sin tocar progreso/mundo.
	var def := SS.defaults()
	_check(float(def["sensibilidad_camara"]) == 1.0, "ajuste: sensibilidad por defecto 1.0")
	_check(bool(def["volar"]) == false, "ajuste: volar por defecto No")
	var custom := SS.defaults()
	custom["sensibilidad_camara"] = 1.5
	custom["volar"] = true
	_check(SS.save_settings(custom), "ajuste: guardar sensibilidad+volar")
	var cargado := SS.load_settings()
	_check(float(cargado["sensibilidad_camara"]) == 1.5, "ajuste: cargar sensibilidad 1.5")
	_check(bool(cargado["volar"]) == true, "ajuste: cargar volar Si")
	_check(SS.save_settings(SS.defaults()), "ajuste: restaurar por defecto")
	# 7. InputMap: acciones nuevas existen en el proyecto cargado.
	for accion in ["jump", "crouch", "attack", "use_block", "inventory", "palette_prev", "palette_next", "camera_pitch_up", "camera_pitch_down"]:
		_check(InputMap.has_action(accion), "inputmap: existe " + accion)
	for accion in ["place_block", "remove_block", "move_forward", "camera_left"]:
		_check(InputMap.has_action(accion), "inputmap: accion vieja intacta " + accion)
	# 8. Archivos y unificación en código.
	_check(FileAccess.file_exists("res://touch_controls.tscn"), "touchcontrols: escena existe")
	var tscn := _read("res://touch_controls.tscn")
	_check(tscn.contains("CanvasLayer"), "touchcontrols: raiz CanvasLayer")
	_check(tscn.contains("TouchControls"), "touchcontrols: nombre TouchControls")
	var tc := _read("res://scripts/touch_controls.gd")
	_check(tc.contains("InputEventScreenDrag"), "touchcontrols: usa ScreenDrag")
	_check(tc.contains("InputEventScreenTouch"), "touchcontrols: usa ScreenTouch")
	_check(tc.contains("tap_interact"), "touchcontrols: senal tap")
	_check(tc.contains("hold_interact"), "touchcontrols: senal hold")
	var main_txt := _read("res://scripts/main.gd")
	_check(main_txt.contains("_current_input_velocity"), "main: variable unica _current_input_velocity")
	_check(main_txt.contains("TouchControlsScene"), "main: instancia TouchControls")
	_check(main_txt.contains("_step_walk_side"), "main: paso lateral (strafe)")
	_check(main_txt.contains("_cam_pitch"), "main: pitch de camara")
	var pal_txt := _read("res://scripts/palette_ui.gd")
	_check(pal_txt.contains("cycle_selection"), "paleta: LB/RB cycle_selection")
	var proj_txt := _read("res://project.godot")
	_check(proj_txt.contains('config/version="1.13.0"'), "project: version 1.13.0")
	_check(proj_txt.contains("canvas_items"), "project: stretch canvas_items")
	# 9. Nada roto de la 1.12.0: niveles, progreso, guardado.
	_check(LD.get_niveles("colores").size() == 10, "1.12.0 intacto: 10 niveles colores")
	_check(LD.COLORES_NOMBRES.size() == 12, "1.12.0 intacto: 12 colores")
	_check(LD.LETRAS.size() == 27, "1.12.0 intacto: 27 letras")
	var prog: Dictionary = {"colores": [0, 1]}
	_check(PS.is_unlocked(prog, "colores", 2), "1.12.0 intacto: desbloqueo")
	_check(WS.SAVE_VERSION == 2, "1.12.0 intacto: world_save v2")
	_check(FileAccess.file_exists("res://scripts/hub.gd"), "1.12.0 intacto: hub.gd")
	_check(FileAccess.file_exists("res://scripts/settings_save.gd"), "1.12.0 intacto: settings_save.gd")
	_check(FileAccess.file_exists("res://scripts/input_controller.gd"), "1.13.0: input_controller.gd")

	print("CHECKS: ", _checks, " FAILS: ", _fails)
	if _fails > 0:
		quit(1)
	quit(0)
