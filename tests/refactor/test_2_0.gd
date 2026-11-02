extends SceneTree
## Tests headless de Bloques Mágicos 2.0 (solo lógica pura,
## sin instanciar escenas). Uso:
##   godot --headless --path . -s tests/refactor/test_2_0.gd
## Sale 0 si todo pasa y 1 si algo falla.

const Catalog := preload("res://scripts/refactor/block_catalog.gd")
const Biomes := preload("res://scripts/refactor/biomes2.gd")
const Save2 := preload("res://scripts/refactor/save_v2.gd")
const Avatar := preload("res://scripts/refactor/avatar_custom.gd")
const Animal := preload("res://scripts/refactor/friendly_animal.gd")
const Player := preload("res://scripts/refactor/player_blocky.gd")
const VoxelWorld := preload("res://scripts/refactor/voxel_world_generator.gd")

var _failures := 0


func _check(name: String, condition: bool) -> void:
	if condition:
		print("PASS " + name)
	else:
		_failures += 1
		printerr("FAIL " + name)


func _init() -> void:
	# 1. Catálogo de bloques (JSON + fallback).
	_check("catalogo_json_existe", FileAccess.file_exists("res://data/blocks.json"))
	var catalog := Catalog.new()
	_check("catalogo_tiene_cristal", catalog.name_for(88) == "Cristal brillo")
	_check("catalogo_luz_cristal_11", catalog.light_for(88) == 11)
	_check("catalogo_luz_antorcha_14", catalog.light_for(80) == 14)
	_check("catalogo_tablones_madera", catalog.sound_for(84) == "wood")
	_check("catalogo_nieve_solida", catalog.is_solid(87))
	_check("catalogo_agua_no_solida", not catalog.is_solid(6))
	_check("catalogo_aire_no_solido", not catalog.is_solid(0))
	_check("catalogo_color_hierba", catalog.color_for(1).is_equal_approx(Color(0.25, 0.65, 0.25)))
	_check("catalogo_desconocido_no_falla", catalog.name_for(999) == "Bloque")
	# 2. Biomas 2.0.
	_check("bioma_playa_bajo", Biomes.biome_for(2, 0.0) == "playa_mar")
	_check("bioma_montana_alto", Biomes.biome_for(13, 0.0) == "montana_nevada")
	_check("bioma_montana_frio", Biomes.biome_for(6, -0.5) == "montana_nevada")
	_check("bioma_bosque_calido", Biomes.biome_for(6, 0.5) == "bosque_magico")
	_check("bioma_pradera_default", Biomes.biome_for(6, 0.0) == "pradera_verde")
	_check("bioma_superficie_nieve", Biomes.surface_block("montana_nevada") == 87)
	_check("bioma_superficie_arena", Biomes.surface_block("playa_mar") == 7)
	_check("bioma_superficie_hierba", Biomes.surface_block("pradera_verde") == 1)
	_check("bioma_arbol_palmera", Biomes.tree_kind("playa_mar") == "palma")
	_check("bioma_arbol_pino", Biomes.tree_kind("montana_nevada") == "pino")
	_check("bioma_viejo_no_es_2", not Biomes.is_biome2("croma_isla"))
	_check("bioma_nuevo_si_es_2", Biomes.is_biome2("bosque_magico"))
	# 3. Generador: parámetros y colores de los bloques nuevos.
	_check("generador_montana_relieve", VoxelWorld.biome_params("montana_nevada").z > 0.5)
	_check("generador_playa_baja", VoxelWorld.biome_params("playa_mar").x == 1.0)
	_check("generador_color_nieve", VoxelWorld.block_color(87).is_equal_approx(Color(0.95, 0.97, 1.0)))
	_check("generador_color_cristal", VoxelWorld.block_color(88).is_equal_approx(Color(0.20, 0.95, 1.0)))
	_check("generador_color_ladrillo", VoxelWorld.block_color(85).is_equal_approx(Color(0.75, 0.25, 0.20)))
	var world := VoxelWorld.new()
	_check("generador_bloque_nuevo_individual", world._is_learning_block(84))
	# 2.0.1 — regresión pantalla negra: el mundo trae su propio
	# sol y ambiente (la escena refactor nunca los creaba).
	world._build_environment()
	var sun := world.get_node_or_null("Sol") as DirectionalLight3D
	_check("luz_sol_existe", sun != null)
	_check("luz_sol_energia", sun != null and sun.light_energy > 0.0)
	var env_node := world.get_node_or_null("Ambiente") as WorldEnvironment
	_check("ambiente_existe", env_node != null and env_node.environment != null)
	_check("ambiente_luz_cielo", env_node != null and env_node.environment != null and env_node.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY)
	# Sin world.free(): liberar aquí el nodo con WorldEnvironment
	# cuelga el proceso headless (signal 11) al salir; el aviso
	# ObjectDB del test viejo es inofensivo y ya existía.
	_check("generador_bloque_viejo_sigue", world._is_learning_block(50))
	# 4. Guardado diferencial v2: ida y vuelta por regiones.
	var modified := {"1,2,3": 10, "20,2,3": 50, "-1,2,3": 84, "33,5,6": 88}
	var encoded := Save2.encode_world("Prueba", 777, "777", "pradera_verde", Vector3(0.5, 4.0, 0.5), {84: 5}, modified)
	_check("savev2_version_2", int(encoded.get("version", 0)) == 2)
	var edits: Dictionary = encoded.get("edits", {})
	_check("savev2_region_0_0", edits.has("0,0"))
	_check("savev2_region_1_0", edits.has("1,0"))
	_check("savev2_region_menos1_0", edits.has("-1,0"))
	_check("savev2_region_2_0", edits.has("2,0"))
	var decoded := Save2.decode_world(encoded)
	_check("savev2_ida_vuelta", str(decoded.get("modified", {}).get("20,2,3", -1)) == "50")
	_check("savev2_jugador", (decoded.get("player_pos", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(0.5, 4.0, 0.5)))
	_check("savev2_version_vieja_rechazada", Save2.decode_world({"version": 1, "seed": 1, "edits": {}}).is_empty())
	var malformed := Save2.decode_edits({"0,0": [[1, 2], "basura", [1, 2, 3, 10]]})
	_check("savev2_malformado_no_falla", malformed.size() == 1 and int(malformed.get("1,2,3", -1)) == 10)
	# 5. Ala delta y avatar.
	_check("glider_frena_caida", is_equal_approx(Player.glide_fall(-10.0), -2.5))
	_check("glider_no_empuja", is_equal_approx(Player.glide_fall(-1.0), -1.0))
	_check("avatar_default_desconocido", Avatar.decode({"hat": "noexiste", "shirt": "noexiste"})["hat"] == "explorador")
	_check("avatar_rana_verde", Avatar.hat_color("rana").is_equal_approx(Color(0.20, 0.70, 0.25)))
	_check("avatar_camiseta_roja", Avatar.shirt_color("rojo").is_equal_approx(Color(0.85, 0.15, 0.15)))
	# 6. Animales amigos: patas, doma y estados.
	_check("animal_pata_tiempo0", is_equal_approx(Animal.leg_angle(0.0, 1.0), 0.0))
	_check("animal_pata_quieto_cero", is_equal_approx(Animal.leg_angle(1.0, 0.0), 0.0))
	_check("animal_doma_cerca_suma", is_equal_approx(Animal.tame_progress(1.0, 2.0, 1.0), 2.0))
	_check("animal_doma_lejos_resetea", is_equal_approx(Animal.tame_progress(1.0, 5.0, 2.0), 0.0))
	_check("animal_estado_sigue", Animal.state_for(true, 5.0) == "FOLLOW")
	_check("animal_estado_quieto", Animal.state_for(true, 1.0) == "IDLE")
	_check("animal_estado_vaga", Animal.state_for(false, 1.0) == "WANDER")

	if _failures == 0:
		print("TODOS LOS TESTS 2.0 PASARON")
	else:
		printerr("FALLARON %d TESTS 2.0" % _failures)
	quit(1 if _failures > 0 else 0)
