extends SceneTree
## Test headless de Bloques Mágicos 1.12.0 (Hub + portales + Ajustes).
## Uso: godot --headless --path <build> -s test-1-12-0.gd
## Sale con código 1 si algún chequeo falla. Lógica pura, sin escena
## (la escena del Hub se prueba aparte con el smoke de frames).

const LD := preload("res://scripts/levels_data.gd")
const PS := preload("res://scripts/progress_save.gd")
const SS := preload("res://scripts/settings_save.gd")
const WS := preload("res://scripts/world_save.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if cond:
		print("OK: ", msg)
	else:
		_fails += 1
		printerr("FAIL: ", msg)


func _init() -> void:
	# 1. Niveles intactos: 10 por mundo, los 5 viejos sin cambios.
	for mundo in ["colores", "numeros", "letras", "sumas"]:
		_check(LD.get_niveles(mundo).size() == 10, "10 niveles en " + mundo)
	_check(String(LD.get_niveles("colores")[0]["tipo"]) == "poner_color", "colores N1 intacto")
	_check(String(LD.get_niveles("colores")[4]["tipo"]) == "arcoiris", "colores N5 arcoiris intacto")
	_check(String(LD.get_niveles("numeros")[4]["tipo"]) == "ordenar", "numeros N5 ordenar intacto")
	_check(String(LD.get_niveles("letras")[1]["tipo"]) == "palabra", "letras N2 palabra intacto")
	_check(String(LD.get_niveles("sumas")[4]["tipo"]) == "suma", "sumas N5 suma intacto")
	_check(LD.MUNDOS.size() == 4, "4 mundos de enseñanza")
	_check(LD.COLORES_NOMBRES.size() == 12, "12 colores intactos")
	_check(LD.LETRAS.size() == 27, "27 letras intactas")

	# 2. Progreso: formato y desbloqueo sin cambios.
	var prog: Dictionary = {"colores": [0, 1], "numeros": []}
	_check(PS.is_unlocked(prog, "colores", 0), "nivel 0 siempre abierto")
	_check(PS.is_unlocked(prog, "colores", 2), "nivel 2 abierto tras 0 y 1")
	_check(not PS.is_unlocked(prog, "colores", 3), "nivel 3 bloqueado sin nivel 2")
	_check(PS.stars_for(prog, "colores") == 2, "2 estrellas en colores")
	_check(PS.stars_total(prog) == 2, "2 estrellas en total")

	# 3. Ajustes: valores por defecto.
	var def := SS.defaults()
	_check(String(def["control"]) == "tv", "ajuste por defecto: control tv")
	_check(float(def["giro"]) == 1.0, "ajuste por defecto: giro normal")
	_check(float(def["caminar"]) == 1.0, "ajuste por defecto: caminar normal")
	_check(float(def["volumen_voces"]) == 1.0, "ajuste por defecto: voces alto")
	_check(float(def["volumen_musica"]) == 1.0, "ajuste por defecto: musica alto")
	_check(float(def["texto"]) == 1.0, "ajuste por defecto: texto normal")
	_check(int(def["vista"]) == 0, "ajuste por defecto: primera persona")
	_check(bool(def["menos_movimiento"]) == false, "ajuste por defecto: movimiento normal")
	_check(bool(def["mas_contraste"]) == false, "ajuste por defecto: contraste normal")

	# 4. Ajustes: guardar y cargar (archivo propio, separado).
	var custom := SS.defaults()
	custom["control"] = "tactil"
	custom["giro"] = 1.5
	custom["vista"] = 1
	custom["menos_movimiento"] = true
	_check(SS.save_settings(custom), "guardar ajustes")
	var cargado := SS.load_settings()
	_check(String(cargado["control"]) == "tactil", "cargar ajustes: control tactil")
	_check(float(cargado["giro"]) == 1.5, "cargar ajustes: giro rapido")
	_check(int(cargado["vista"]) == 1, "cargar ajustes: segunda persona")
	_check(bool(cargado["menos_movimiento"]) == true, "cargar ajustes: menos movimiento")
	_check(float(cargado["volumen_voces"]) == 1.0, "cargar ajustes: resto por defecto intacto")

	# 5. Hub: siguiente nivel pendiente y candado.
	_check(SS.next_pending_level(prog, "colores") == 2, "hub: siguiente pendiente colores = nivel 3")
	_check(SS.next_pending_level(prog, "numeros") == 0, "hub: siguiente pendiente numeros = nivel 1")
	_check(SS.next_pending_level({"colores": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]}, "colores") == 9, "hub: mundo completo rejuega nivel 10")
	_check(not SS.portal_locked(prog, "colores"), "hub: portal colores abierto (siguiente desbloqueado)")
	_check(not SS.portal_locked(prog, "numeros"), "hub: portal numeros abierto")
	_check(not SS.portal_locked({}, "colores"), "hub: portal abierto sin progreso")
	# La regla de candado en sí: un nivel más allá del siguiente sí está bloqueado.
	_check(not PS.is_unlocked(prog, "colores", 5), "candado: nivel 6 bloqueado con solo 2 estrellas")

	# 5b. Celular: controles táctiles reales en código (no solo texto).
	var hub_txt := ""
	var hf := FileAccess.open("res://scripts/hub.gd", FileAccess.READ)
	if hf != null:
		hub_txt = hf.get_as_text()
		hf.close()
	_check(hub_txt.contains("_touch_dir_button"), "celular: cruceta tactil en la Plaza")
	_check(hub_txt.contains("_send_touch_action"), "celular: cruceta inyecta acciones move_*")
	var pal_txt := ""
	var pf := FileAccess.open("res://scripts/palette_ui.gd", FileAccess.READ)
	if pf != null:
		pal_txt = pf.get_as_text()
		pf.close()
	_check(pal_txt.contains("next_requested"), "celular: boton Siguiente en niveles")
	_check(pal_txt.contains("set_next_visible"), "celular: Siguiente solo visible al completar")
	_check(pal_txt.contains("settings_requested"), "celular: boton Ajustes en la paleta")
	# Sin archivo guardado y sin feature phone (headless), el defecto es mando TV.
	_check(SS.save_settings(SS.defaults()), "restaurar ajustes por defecto")
	_check(String(SS.load_settings()["control"]) == "tv", "defecto headless: control tv (en celular phone sera tactil)")

	# 6. Guardado libre: formato intacto (no se tocó world_save.gd).
	_check(WS.SAVE_VERSION == 2, "world_save version 2 intacta")
	_check(FileAccess.file_exists("res://scripts/world_save.gd"), "world_save.gd existe")
	_check(FileAccess.file_exists("res://scripts/progress_save.gd"), "progress_save.gd existe")
	_check(FileAccess.file_exists("res://scripts/hub.gd"), "hub.gd existe")
	_check(FileAccess.file_exists("res://scripts/settings.gd"), "settings.gd existe")
	_check(FileAccess.file_exists("res://scripts/settings_save.gd"), "settings_save.gd existe")
	_check(FileAccess.file_exists("res://hub.tscn"), "hub.tscn existe")
	_check(FileAccess.file_exists("res://settings.tscn"), "settings.tscn existe")

	print("CHECKS: ", _checks, " FAILS: ", _fails)
	if _fails > 0:
		quit(1)
	quit(0)
