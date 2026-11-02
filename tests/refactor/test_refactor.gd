extends SceneTree
## Tests headless de la variante refactorizada.
## Uso (con Godot 4.3 instalado, que NO hay en esta VM):
##   godot --headless --path . -s tests/refactor/test_refactor.gd
## Solo ejercita lógica PURA (sin instanciar escenas): dirección de
## movimiento, pitch/yaw, semillas, Base64, repetición espaciada,
## detección de palabras y de operaciones. La salida es 0 si todo
## pasa y 1 si algo falla, con una línea por comprobación.

const PlayerBlockyScript := preload("res://scripts/refactor/player_blocky.gd")
const SeedManager := preload("res://scripts/refactor/world_seed_manager.gd")
const Repetition := preload("res://scripts/refactor/spaced_repetition_manager.gd")
const GameModes := preload("res://scripts/refactor/game_mode_manager.gd")
const VoxelWorld := preload("res://scripts/refactor/voxel_world_generator.gd")

var _failures := 0


func _check(name: String, condition: bool) -> void:
	if condition:
		print("PASS " + name)
	else:
		_failures += 1
		printerr("FAIL " + name)


func _init() -> void:
	# 1. Movimiento: adelante = -basis.z aplanado.
	var fwd := PlayerBlockyScript.move_direction(Vector2(0, 1), 0.0)
	_check("adelante_yaw0_es_menos_Z", fwd.is_equal_approx(Vector3(0, 0, -1)))
	var right := PlayerBlockyScript.move_direction(Vector2(1, 0), 0.0)
	_check("derecha_yaw0_es_mas_X", right.is_equal_approx(Vector3(1, 0, 0)))
	var fwd90 := PlayerBlockyScript.move_direction(Vector2(0, 1), PI / 2.0)
	_check("adelante_yaw90_es_menos_X", fwd90.is_equal_approx(Vector3(-1, 0, 0)))
	# Joystick arriba (y +1) mueve adelante, abajo (y -1) atrás.
	var up := PlayerBlockyScript.move_direction(Vector2(0, 1), 0.0)
	var down := PlayerBlockyScript.move_direction(Vector2(0, -1), 0.0)
	_check("joystick_arriba_adelante_y_abajo_atras", up.z < 0.0 and down.z > 0.0)
	# 2. Cámara: arrastrar arriba sube el pitch, a la derecha baja yaw.
	_check("pitch_arrastrar_arriba_sube", PlayerBlockyScript.apply_pitch(0.0, 100.0, 0.0, 1.0, false) > 0.0)
	_check("pitch_clamp_85", is_equal_approx(PlayerBlockyScript.apply_pitch(1.4, 100.0, 0.0, 1.0, false), deg_to_rad(85.0)))
	_check("pitch_invertido_invierte", PlayerBlockyScript.apply_pitch(0.0, 100.0, 0.0, 1.0, true) < 0.0)
	_check("yaw_arrastrar_derecha_baja", PlayerBlockyScript.apply_yaw(0.0, 100.0, 1.0) < 0.0)
	# 3. Semillas: determinista, vacío = 0, número = número.
	_check("semilla_determinista", SeedManager.seed_from_string("MUNDO-PAPA-HIJO-777") == SeedManager.seed_from_string("MUNDO-PAPA-HIJO-777"))
	_check("semilla_vacia_cero", SeedManager.seed_from_string("") == 0)
	_check("semilla_numero", SeedManager.seed_from_string("777") == 777)
	# 4. Base64: ida y vuelta conserva semilla y bloques.
	var modified := {"1,2,3": 10, "4,5,6": 50}
	var encoded := SeedManager.export_base64("Prueba", "MUNDO-PAPA-HIJO-777", "croma_isla", modified)
	var decoded := SeedManager.import_base64(encoded)
	_check("base64_semilla", int(decoded.get("seed", -1)) == SeedManager.seed_from_string("MUNDO-PAPA-HIJO-777"))
	_check("base64_bloques", str(decoded.get("modified_blocks", {}).get("1,2,3", -1)) == "10")
	_check("base64_basura_rechazada", SeedManager.import_base64("!!!no-es-base64!!!").is_empty())
	# 5. Repetición espaciada: lo que falló, primero.
	var rep := Repetition.new()
	rep.record_miss("suma_4+3")
	rep.record_miss("suma_4+3")
	# 2 fallos, último fallo: 2*3 - 0 + 1 = 7.
	_check("prioridad_fallo_pesa", rep.priority("suma_4+3") == 7)
	rep.record_hit("suma_4+3")
	rep.record_hit("letra_S")
	_check("pick_next_prioriza_fallo", rep.pick_next(["letra_S", "suma_4+3"])[0] == "suma_4+3")
	# 6. Palabras y matemáticas.
	_check("palabra_SOL", GameModes.detect_word(["X", "S", "O", "L", "Y"]) == "SOL")
	_check("palabra_PUENTE", GameModes.detect_word(["P", "U", "E", "N", "T", "E"]) == "PUENTE")
	_check("palabra_inexistente", GameModes.detect_word(["A", "B", "C"]) == "")
	var math := GameModes.detect_math(["3", "+", "2", "="])
	_check("suma_3_mas_2", math[0] == "3 + 2" and math[1] == 5)
	_check("suma_invalida", GameModes.detect_math(["3", "+", "2"])[0] == "")
	# 7. Biomas y etiquetas.
	_check("bioma_ciber_montanas", VoxelWorld.biome_params("ciber_nucleo").z > 0.5)
	# 2.0.2: la N faltaba en LETRAS (63 era Ñ por error); orden 1.15: N=63, Ñ=64, Z=76.
	_check("etiqueta_letra_N", VoxelWorld.block_label(63) == "N")
	_check("etiqueta_letra_NN", VoxelWorld.block_label(64) == "Ñ")
	_check("etiqueta_letra_Z", VoxelWorld.block_label(76) == "Z")
	_check("etiqueta_numero_1", VoxelWorld.block_label(31) == "1")
	_check("scatter_determinista", is_equal_approx(VoxelWorld.scatter_hash(3, 7, 42), VoxelWorld.scatter_hash(3, 7, 42)))

	if _failures == 0:
		print("TODOS LOS TESTS PASARON")
	else:
		printerr("FALLARON %d TESTS" % _failures)
	quit(1 if _failures > 0 else 0)
