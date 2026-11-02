extends Node
## Test headless de Bloques Mágicos 1.15.0 (fallo reportado con
## captura en construcción: ningún botón funcionaba, la cámara
## solo giraba a los lados y el joystick no caminaba).
## Uso (¡NO con -s!): hub/main/menu usan el autoload GameState.
##   godot --headless --path <build> res://test-1-15-0.tscn
## Sale con código 1 si algún chequeo falla.
##
## Geometría de referencia (viewport 1280×720 de project.godot,
## rects sacados de las constantes del código, no inventados):
## - TouchControls mundo: joystick (36,100,240,240), cámara
##   (640,210,410,120): x mitad derecha hasta 1280-230, y 210
##   hasta 720-390. Plaza: cámara (640,210,410,310) con bottom
##   -200 (y hasta 520).
## - Botones palette_ui: barra superior y~96-176 (botones a la
##   derecha), acciones (1072,210,112,300) CENTER_RIGHT ±150,
##   girar (80,572,218,52), dock paleta (96,370,820,254),
##   paseo (952,336,232,288) BOTTOM_RIGHT -328..-96, -384..-96.
## - Plaza: Entrar/Ajustes centrados (388,540,504,84).
## El radial de paseo NO entra en la lista de rects disjuntos:
## su botón Poner roza 4 px el borde de la cámara, pero es
## modal y se neutraliza con TouchControls.suppress (ver abajo).

const LD := preload("res://scripts/levels_data.gd")
const PS := preload("res://scripts/progress_save.gd")
const SS := preload("res://scripts/settings_save.gd")
const WS := preload("res://scripts/world_save.gd")
const IC := preload("res://scripts/input_controller.gd")
const TC := preload("res://scripts/touch_controls.gd")

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


func _no_overlap(a: Rect2, b: Rect2) -> bool:
	return not a.intersects(b)


func _ready() -> void:
	# 1. Rects de TouchControls 1.15.0 (valores por defecto).
	var joy := TC.joy_rect()
	var cam := TC.cam_rect()
	_check(joy == Rect2(36.0, 100.0, 240.0, 240.0), "rects: joystick (36,100,240,240) por encima del dock")
	_check(cam == Rect2(640.0, 210.0, 410.0, 120.0), "rects: camara mundo (640,210,410,120) zona libre")
	var cam_plaza := TC.cam_rect(1280.0, 720.0, -200.0)
	_check(cam_plaza == Rect2(640.0, 210.0, 410.0, 310.0), "rects: camara Plaza (640,210,410,310)")
	var tc_scene = load("res://touch_controls.tscn")
	var tc = tc_scene.instantiate()
	_check(tc.camera_bottom_offset == -390.0, "touchcontrols: mundo bottom -390 por defecto")
	_check(tc.camera_top_offset == 210.0, "touchcontrols: camara top 210 por defecto")
	_check(tc.camera_right_offset == -230.0, "touchcontrols: camara right -230 por defecto")
	_check(tc.joy_top_offset == -620.0 and tc.joy_bottom_offset == -380.0, "touchcontrols: joystick -620..-380 por defecto")
	_check(tc.suppress == false, "touchcontrols: suppress apagado por defecto")
	add_child(tc)
	# 2. NINGÚN solapamiento con botones de palette_ui.
	var top_bar := Rect2(700.0, 96.0, 484.0, 80.0)
	var acciones := Rect2(1072.0, 210.0, 112.0, 300.0)
	var girar := Rect2(80.0, 572.0, 218.0, 52.0)
	var dock := Rect2(96.0, 370.0, 820.0, 254.0)
	var paseo := Rect2(952.0, 336.0, 232.0, 288.0)
	for par in [[top_bar, "barra superior"], [acciones, "columna acciones"], [girar, "botones Girar"], [dock, "dock paleta"], [paseo, "caja paseo"]]:
		_check(_no_overlap(joy, par[0]), "rects: joystick NO tapa " + String(par[1]))
		_check(_no_overlap(cam, par[0]), "rects: camara NO tapa " + String(par[1]))
	# 3. Simulación de toque: un toque en cada botón NO cae en
	# joystick ni en cámara (antes caía en la cámara, capa 5).
	for par in [[Vector2(1100.0, 120.0), "Plaza/Ajustes superior"], [Vector2(1128.0, 300.0), "Poner"], [Vector2(1128.0, 450.0), "Caminar"], [Vector2(200.0, 500.0), "color paleta"], [Vector2(1060.0, 360.0), "Menu paseo"], [Vector2(190.0, 600.0), "Girar"]]:
		var pt: Vector2 = par[0]
		_check(not joy.has_point(pt) and not cam.has_point(pt), "toque: " + String(par[1]) + " llega al boton, no a TouchControls")
	# 4. Plaza: Entrar/Ajustes fuera de joystick y de cámara.
	var plaza_btns := Rect2(388.0, 540.0, 504.0, 84.0)
	_check(_no_overlap(joy, plaza_btns), "plaza: joystick NO tapa Entrar/Ajustes")
	_check(_no_overlap(cam_plaza, plaza_btns), "plaza: camara NO tapa Entrar/Ajustes")
	var hub_scene = load("res://hub.tscn")
	var hub = hub_scene.instantiate()
	add_child(hub)
	_check(hub._touch_controls != null and hub._touch_controls.camera_bottom_offset == -200.0, "plaza: camara termina 200 px antes (intacto)")
	_check(hub._portales.size() == 8, "plaza: 8 portales intactos")
	# 5. Pitch en construcción = preset + pitch, clampado.
	var main_txt := _read("res://scripts/main.gd")
	_check(main_txt.contains("deg_to_rad(float(cp[\"rot_x\"])) + _cam_pitch"), "pitch: construccion suma preset + pitch (antes solo preset)")
	_check(main_txt.contains("build_rot_x"), "pitch: variable build_rot_x presente")
	_check(main_txt.contains("deg_to_rad(-80.0), deg_to_rad(20.0)"), "pitch: clamp -80..20 para no voltear")
	_check(main_txt.contains("rad_to_deg(_cam_pitch)"), "pitch: al salir del paseo no se resetea a ciegas")
	# Aritmética del mismo cálculo que hace main.gd.
	var rot_arriba := clampf(deg_to_rad(-45.0) + 0.5, deg_to_rad(-80.0), deg_to_rad(20.0))
	_check(absf(rad_to_deg(rot_arriba) - (-16.352)) < 0.01, "pitch: preset Arriba -45 + 0.5 rad = -16.35 deg")
	var rot_lado := clampf(deg_to_rad(-14.0) + (-0.5), deg_to_rad(-80.0), deg_to_rad(20.0))
	_check(absf(rad_to_deg(rot_lado) - (-42.648)) < 0.01, "pitch: preset Lado -14 - 0.5 rad = -42.65 deg")
	_check(is_equal_approx(rad_to_deg(clampf(deg_to_rad(-45.0) + 2.0, deg_to_rad(-80.0), deg_to_rad(20.0))), 20.0), "pitch: pitch extremo se clampa a 20 deg")
	# 6. Radial modal: suppress existe y main lo pone con _radial_open.
	_check(main_txt.contains("_touch_controls.suppress = _radial_open"), "radial: main pone suppress = _radial_open")
	var tc_txt := _read("res://scripts/touch_controls.gd")
	_check(tc_txt.contains("not suppress"), "radial: TouchControls se oculta con suppress")
	# 7. Texto de ayuda: táctil real vs TV intacto.
	var pal_txt := _read("res://scripts/palette_ui.gd")
	_check(pal_txt.contains("Joystick: mueve"), "ayuda: texto tactil con joystick/camara/toque/mantener")
	_check(pal_txt.contains("Botones: Poner, Quitar, Caminar"), "ayuda: texto tactil nombra Poner/Quitar/Caminar")
	_check(pal_txt.contains("Mando: cruceta mueve"), "ayuda: texto TV sin tocar")
	# 8. Lógica 1.13/1.14 intacta + versión.
	_check(IC.normalize_joystick(Vector2(0.1, 0.0)) == Vector2.ZERO, "1.13 intacto: zona muerta")
	_check(IC.camera_delta(Vector2(100.0, 0.0), 1.5) == Vector2(-0.75, 0.0), "1.13 intacto: camara sensibilidad")
	_check(IC.hub_forward_step(0.0) == Vector2i(0, -1), "1.14 intacto: plaza yaw 0 avanza -Z")
	var ctrl := IC.new()
	_check(ctrl.update_sprint(1.0, 0.35) == true, "1.13 intacto: sprint 0.35 s")
	_check(main_txt.contains("_current_input_velocity"), "mundo: variable unica intacta")
	_check(LD.get_niveles("colores").size() == 10, "1.12 intacto: 10 niveles colores")
	_check(LD.COLORES_NOMBRES.size() == 12, "1.12 intacto: 12 colores")
	_check(LD.LETRAS.size() == 27, "1.12 intacto: 27 letras")
	_check(WS.SAVE_VERSION == 2, "1.12 intacto: world_save v2")
	var proj_txt := _read("res://project.godot")
	_check(proj_txt.contains('config/version="1.15.0"'), "project: version 1.15.0")
	_check(proj_txt.contains("config/version_code=7"), "project: version_code 7")
	var main_scene = load("res://main.tscn")
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	_check(main_inst != null, "escena: main.tscn instancia")
	var settings_scene = load("res://settings.tscn")
	var settings_inst = settings_scene.instantiate()
	add_child(settings_inst)
	_check(settings_inst != null, "escena: settings.tscn instancia")

	print("CHECKS: ", _checks, " FAILS: ", _fails)
	if _fails > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
