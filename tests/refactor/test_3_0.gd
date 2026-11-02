extends SceneTree
## Tests headless de Bloques Mágicos 3.0 (solo lógica pura,
## sin instanciar escenas ni escribir en user://). Uso:
##   godot --headless --path . -s tests/refactor/test_3_0.gd
## Sale 0 si todo pasa y 1 si algo falla.

const Quests := preload("res://scripts/refactor/quest_system.gd")
const Levels := preload("res://scripts/refactor/level_system.gd")
const Workshop := preload("res://scripts/refactor/workshop.gd")
const VoxelWorld := preload("res://scripts/refactor/voxel_world_generator.gd")
const Creatures := preload("res://scripts/refactor/creature_catalog.gd")
const Specials := preload("res://scripts/refactor/biomes_special.gd")
const Biomes2 := preload("res://scripts/refactor/biomes2.gd")
const Animals := preload("res://scripts/refactor/friendly_animal.gd")
const Modes := preload("res://scripts/refactor/game_mode_manager.gd")
const Weather := preload("res://scripts/refactor/weather_system.gd")
const BlockCat := preload("res://scripts/refactor/block_catalog.gd")
const Horde := preload("res://scripts/refactor/horde_system.gd")
const Vitals := preload("res://scripts/refactor/vitals.gd")
const Player := preload("res://scripts/refactor/player_blocky.gd")
const Character := preload("res://scripts/refactor/character.gd")
const Forge := preload("res://scripts/refactor/sculpting_forge.gd")
const Stations := preload("res://scripts/refactor/stations.gd")
const Items := preload("res://scripts/refactor/equipment_items.gd")
const Gen := preload("res://scripts/refactor/voxel_world_generator.gd")
const MusicData := preload("res://scripts/refactor/music_data.gd")
const MusicSys := preload("res://scripts/refactor/music_system.gd")
const Lan := preload("res://scripts/refactor/lan_net.gd")

var _failures := 0


func _check(name: String, condition: bool) -> void:
	if condition:
		print("PASS " + name)
	else:
		_failures += 1
		printerr("FAIL " + name)


func _init() -> void:
	# 1. Las 20 misiones existen.
	var q := Quests.new()
	_check("misiones_son_20", Quests.QUESTS.size() == 20)
	# 2. Flujo básico: 3 bloques = primeros + gran_constructor 3.
	q.on_place(10)
	q.on_place(11)
	q.on_place(12)
	_check("mision_primeros", q.is_done("primeros"))
	_check("mision_primeros_estrella", q.stars() >= 1)
	_check("gran_constructor_3", q.progress_of("gran_constructor") == 3)
	# 3. Arcoíris: 5 colores distintos (el 12 repetido no suma).
	var q2 := Quests.new()
	q2.on_place(10)
	q2.on_place(11)
	q2.on_place(12)
	q2.on_place(12)
	q2.on_place(13)
	q2.on_place(14)
	_check("mision_arcoiris", q2.is_done("arcoiris"))
	# 4. Letras distintas y números.
	var q3 := Quests.new()
	q3.on_place(50)
	q3.on_place(50)
	q3.on_place(51)
	q3.on_place(52)
	q3.on_place(53)
	q3.on_place(54)
	_check("mision_letras", q3.is_done("letras"))
	for i in range(10):
		q3.on_place(31)
	_check("mision_diez", q3.is_done("diez"))
	# 5. Amigos, palabras, sumas, crafteos.
	var q4 := Quests.new()
	q4.on_friend()
	_check("mision_amigo", q4.is_done("amigo"))
	q4.on_friend()
	q4.on_friend()
	_check("mision_manada", q4.is_done("manada"))
	q4.on_word()
	_check("mision_palabra", q4.is_done("palabra"))
	q4.on_word()
	_check("mision_segunda_palabra", q4.is_done("segunda_palabra"))
	q4.on_math()
	_check("mision_suma", q4.is_done("suma"))
	q4.on_math()
	q4.on_math()
	_check("mision_matematico", q4.is_done("matematico"))
	q4.on_craft()
	_check("mision_taller", q4.is_done("taller"))
	q4.on_craft()
	_check("mision_doble", q4.is_done("doble"))
	# 6. Distancia y altura son máximos (no suman): alejarse
	# y volver no infla el progreso.
	var q5 := Quests.new()
	q5.on_move(35.0)
	_check("mision_explorador", q5.is_done("explorador"))
	q5.on_move(5.0)
	_check("explorador_no_baja", q5.progress_of("explorador") == 35)
	_check("gran_viajero_no", not q5.is_done("gran_viajero"))
	q5.on_move(120.0)
	_check("mision_gran_viajero", q5.is_done("gran_viajero"))
	q5.on_height(12.0)
	_check("mision_altura", q5.is_done("altura"))
	# 7. Antorchas de noche y nivel.
	var q6 := Quests.new()
	q6.on_torch_night()
	_check("mision_antorcha", q6.is_done("antorcha"))
	for i in range(4):
		q6.on_torch_night()
	_check("mision_noche_estrellada", q6.is_done("noche_estrellada"))
	q6.on_level(5)
	_check("mision_leyenda", q6.is_done("leyenda"))
	# 8. Niveles: curva 20 + (N-1)*15.
	_check("nivel_exp_1", Levels.exp_needed(1) == 20)
	_check("nivel_exp_2", Levels.exp_needed(2) == 35)
	_check("nivel_exp_5", Levels.exp_needed(5) == 80)
	var lv := Levels.new()
	lv.gain_exp(20)
	_check("nivel_sube_2", lv.level == 2 and lv.exp == 0)
	lv.gain_exp(15)
	_check("nivel_exp_acumula", lv.level == 2 and lv.exp == 15)
	lv.gain_exp(20)
	_check("nivel_sube_3", lv.level == 3 and lv.exp == 0)
	# 9. Estaciones cada 5 días, en ciclo.
	_check("estacion_d1", Levels.season_for_day(1) == "Primavera")
	_check("estacion_d6", Levels.season_for_day(6) == "Verano")
	_check("estacion_d11", Levels.season_for_day(11) == "Otoño")
	_check("estacion_d16", Levels.season_for_day(16) == "Invierno")
	_check("estacion_d21", Levels.season_for_day(21) == "Primavera")
	# 10. Zonas 1-6 por distancia.
	_check("zona_1", Levels.zone_for_distance(0.0) == 1)
	_check("zona_2", Levels.zone_for_distance(25.0) == 2)
	_check("zona_3", Levels.zone_for_distance(50.0) == 3)
	_check("zona_4", Levels.zone_for_distance(80.0) == 4)
	_check("zona_5", Levels.zone_for_distance(130.0) == 5)
	_check("zona_6", Levels.zone_for_distance(200.0) == 6)
	# 11. Taller: 5 recetas, creativo gratis, supervivencia
	# descuenta y sin materiales no fabrica.
	_check("taller_5_recetas", Workshop.recipes().size() == 5)
	var inv: Dictionary = {}
	_check("taller_creativo_gratis", Workshop.can_craft(Workshop.recipe_by_id("estrella"), inv, true))
	_check("taller_sin_materiales_no", not Workshop.can_craft(Workshop.recipe_by_id("estrella"), inv, false))
	inv = {12: 3, 88: 2}
	_check("taller_estrella_si", Workshop.can_craft(Workshop.recipe_by_id("estrella"), inv, false))
	var gives: int = Workshop.apply_craft(Workshop.recipe_by_id("estrella"), inv, false)
	_check("taller_estrella_da_90", gives == 90)
	_check("taller_estrella_descuenta", int(inv.get(12, -1)) == 0 and int(inv.get(88, -1)) == 0)
	inv = {12: 1, 11: 1}
	_check("taller_verde_da_13", Workshop.apply_craft(Workshop.recipe_by_id("verde"), inv, false) == 13)
	inv = {62: 1, 50: 1}
	_check("taller_ma_da_93", Workshop.apply_craft(Workshop.recipe_by_id("silaba_ma"), inv, false) == 93)
	inv = {80: 1}
	_check("taller_farol_sin_vidrio_no", Workshop.apply_craft(Workshop.recipe_by_id("farol"), inv, false) == -1)
	# 12. Bloques 3.0 en el generador: color, etiqueta y malla.
	var world := VoxelWorld.new()
	_check("bloque_estrella_individual", world._is_learning_block(90))
	_check("bloque_corazon_individual", world._is_learning_block(91))
	_check("bloque_farol_individual", world._is_learning_block(92))
	_check("bloque_ma_individual", world._is_learning_block(93))
	_check("bloque_division_individual", world._is_learning_block(44))
	_check("color_estrella", VoxelWorld.block_color(90).is_equal_approx(Color(1.0, 0.85, 0.20)))
	_check("color_corazon", VoxelWorld.block_color(91).is_equal_approx(Color(0.90, 0.20, 0.30)))
	_check("color_farol", VoxelWorld.block_color(92).is_equal_approx(Color(1.0, 0.75, 0.25)))
	_check("color_ma", VoxelWorld.block_color(93).is_equal_approx(Color(0.65, 0.30, 0.85)))
	_check("etiqueta_division", VoxelWorld.block_label(44) == "÷")
	_check("etiqueta_ma", VoxelWorld.block_label(93) == "MA")
	_check("etiqueta_estrella", VoxelWorld.block_label(90) == "⭐")
	# 13. Catálogo de criaturas: 246 exactas, sin recortes.
	var cat := Creatures.new()
	_check("criaturas_246", cat.count() == 246)
	_check("criaturas_pacificas", cat.by_category("pacifica").size() == 88)
	_check("criaturas_depredadores", cat.by_category("depredador").size() == 60)
	_check("criaturas_fantasticas", cat.by_category("fantastica").size() == 40)
	_check("criaturas_facciones", cat.by_category("faccion").size() == 50)
	_check("criaturas_unicos", cat.by_category("unico").size() == 8)
	_check("criaturas_10_facciones", cat.factions().size() == 10)
	var roles_ok: bool = true
	for f in cat.factions():
		if cat.roles_of_faction(f).size() != 5:
			roles_ok = false
	_check("criaturas_5_roles_por_faccion", roles_ok)
	_check("criaturas_unicornio_domable", cat.is_tameable("unicorn"))
	_check("criaturas_titan_jefe", cat.is_boss("titan_colossus"))
	_check("criaturas_lobo_carne", cat.food_for("lobo") == "carne")
	var fields_ok: bool = true
	var zones_ok: bool = true
	for key in cat.all_ids():
		var e: Dictionary = cat.entry_for(str(key))
		for field in ["name", "category", "archetype", "temperament",
			"biomes", "zoneMin", "zoneMax"]:
			if not e.has(field):
				fields_ok = false
		if str(e["archetype"]) not in Creatures.ARCHETYPES:
			fields_ok = false
		if str(e["temperament"]) not in Creatures.TEMPERAMENTS:
			fields_ok = false
		if int(e["zoneMin"]) < 1 or int(e["zoneMax"]) > 6 or int(e["zoneMin"]) > int(e["zoneMax"]):
			zones_ok = false
		if bool(e["tameable"]) and str(e["food"]) == "":
			fields_ok = false
	_check("criaturas_campos_completos", fields_ok)
	_check("criaturas_zonas_validas", zones_ok)
	_check("criaturas_bioma_jungla", cat.by_biome("jungla").size() > 0)
	_check("criaturas_bioma_oceano", cat.by_biome("oceano").size() > 0)
	# 14. Biomas 3.0: 7 base nuevos + 26 especiales por anillo.
	_check("biomas_nuevos_en_lista", Biomes2.is_biome2("tundra_nevada") and Biomes2.is_biome2("jungla") and Biomes2.is_biome2("desierto"))
	_check("bioma_tundra_nieve", Biomes2.surface_block("tundra_nevada") == 87)
	_check("bioma_pantano_lodo", Biomes2.surface_block("pantano") == 2)
	_check("bioma_desierto_arena", Biomes2.surface_block("desierto") == 7)
	_check("especiales_26", Specials.SPECIALS.size() == 26)
	_check("especiales_z1_2", Specials.count_by_zone(1) == 2)
	_check("especiales_z2_4", Specials.count_by_zone(2) == 4)
	_check("especiales_z3_5", Specials.count_by_zone(3) == 5)
	_check("especiales_z4_5", Specials.count_by_zone(4) == 5)
	_check("especiales_z5_5", Specials.count_by_zone(5) == 5)
	_check("especiales_z6_5", Specials.count_by_zone(6) == 5)
	_check("especial_celestial", Specials.zone_for("tierras_celestiales") == 6)
	_check("especial_params", Specials.params_for("volcan_dormido").z > 0.5)
	_check("generador_especial", VoxelWorld.biome_params("tierras_cristal").x == 2.0)
	_check("generador_oceano_bajo", VoxelWorld.biome_params("oceano").x == 0.0)
	# 15. Multiedad: palabras y operaciones por banda + división.
	_check("banda_5_palabras", Modes.words_for_band("5-7").size() == 2)
	_check("banda_8_palabras", Modes.words_for_band("8-12").size() == 6)
	_check("banda_13_palabras", Modes.words_for_band("13+").size() == 8)
	_check("banda_5_ops", Modes.ops_for_band("5-7") == ["+", "-"])
	_check("banda_13_div", "÷" in Modes.ops_for_band("13+"))
	var div_ok: Array = Modes.detect_math(["6", "÷", "2", "="])
	_check("division_exacta", div_ok[0] != "" and int(div_ok[1]) == 3)
	_check("division_no_exacta", Modes.detect_math(["7", "÷", "2", "="])[0] == "")
	_check("division_cero", Modes.detect_math(["6", "÷", "0", "="])[0] == "")
	# 16. Animales 3.0: 16 especies amigas.
	_check("animales_16", Animals.all_species().size() == 16)
	_check("animal_pinguino", "pinguino" in Animals.all_species())
	_check("animal_nombre_pinguino", Animals.display_name("pinguino") == "Pingüino")
	# 17. Clima por estación.
	_check("clima_invierno_nieve", "Nieve" in Weather.possible_weathers("Invierno"))
	_check("clima_primavera_lluvia", "Lluvia" in Weather.possible_weathers("Primavera"))
	_check("clima_primavera_sin_nieve", "Nieve" not in Weather.possible_weathers("Primavera"))
	# 18. Catálogo de bloques 160+ (documento §4).
	var bcat := BlockCat.new()
	_check("bloques_165", bcat.all_ids().size() >= 160)
	_check("bloque_roca_madre_dura", bcat.hardness_for(144) == -1.0)
	_check("bloque_lava_luz", bcat.light_for(203) == 15)
	_check("bloque_oro_nombre", bcat.name_for(150) == "Mena de oro")
	_check("bloque_color_oro", VoxelWorld.block_color(150) == Color(1.0, 0.85, 0.20))
	_check("bloque_etiqueta_roca", VoxelWorld.block_label(144) == "Roca madre")
	_check("bloque_irrompible", VoxelWorld.is_unbreakable(144))
	_check("bloque_rompible", not VoxelWorld.is_unbreakable(145))
	_check("bloque_viejo_sin_cambio", not VoxelWorld.is_unbreakable(6))
	# 19. Vetas subterráneas por bandas de profundidad.
	_check("veta_poca_profundidad", VoxelWorld.ore_vein_at(3, 2, 4, 1, 123) == 0)
	_check("veta_determinista", VoxelWorld.ore_vein_at(3, 2, 4, 5, 123) == VoxelWorld.ore_vein_at(3, 2, 4, 5, 123))
	var found_coal := false
	var found_gold := false
	var found_chrono := false
	for gx in range(-20, 21):
		for gz in range(-20, 21):
			var v3 := VoxelWorld.ore_vein_at(gx, 2, gz, 3, 123)
			if v3 == 145:
				found_coal = true
			var v10 := VoxelWorld.ore_vein_at(gx, 2, gz, 10, 123)
			if v10 == 150:
				found_gold = true
			var v12 := VoxelWorld.ore_vein_at(gx, 2, gz, 12, 123)
			if v12 == 153:
				found_chrono = true
	_check("veta_carbon_existe", found_coal)
	_check("veta_oro_existe", found_gold)
	_check("veta_cronolita_existe", found_chrono)
	# 20. Roca madre y vetas en un mundo real generado.
	var world3 := VoxelWorld.new()
	world3.generate(123, "pradera_verde", 8)
	_check("mundo_roca_madre", world3.terrain_block_at(Vector3i(5, 0, 5)) == 144)
	var ore_in_world := false
	for wx in range(-10, 11):
		for wz in range(-10, 11):
			var wh := world3.terrain_height(wx, wz)
			for wy in range(1, wh):
				var wb := world3.terrain_block_at(Vector3i(wx, wy, wz))
				if wb >= 145 and wb <= 153:
					ore_in_world = true
	_check("mundo_veta_existe", ore_in_world)
	# 21. IA por temperamento, doma con sigilo/comida y monturas.
	_check("doma_cerca_1x", Animals.tame_progress_v2(1.0, 2.0, false, false, 0.0) == 1.0)
	_check("doma_sigilo_15x", Animals.tame_progress_v2(1.0, 5.0, true, false, 0.0) == 1.5)
	_check("doma_comida_2x", Animals.tame_progress_v2(1.0, 5.0, false, true, 0.0) == 2.0)
	_check("doma_lejos_cero", Animals.tame_progress_v2(1.0, 6.0, true, true, 2.0) == 0.0)
	_check("doma_comida_oveja", Animals.food_block_id(Animals.food_for_species("oveja")) == 222)
	_check("doma_comida_caballo_sin_bloque", Animals.food_block_id(Animals.food_for_species("caballo")) == -1)
	_check("estado_persecucion", Animals.state_for_v2(false, 5.0, "aggressive", false, false) == "CHASE")
	_check("estado_persecucion_lejos", Animals.state_for_v2(false, 15.0, "aggressive", false, false) == "WANDER")
	_check("estado_huida_sprint", Animals.state_for_v2(false, 2.0, "passive", true, false) == "FLEE")
	_check("estado_huida_manada", Animals.state_for_v2(false, 6.0, "neutral", false, true) == "FLEE")
	_check("estado_domado_sigue", Animals.state_for_v2(true, 5.0, "passive", false, false) == "FOLLOW")
	_check("montura_solo_caballo", Animals.is_rideable_species("caballo") and not Animals.is_rideable_species("oveja"))
	var hunter := Animals.new()
	hunter._build()
	hunter.temperament = "aggressive"
	hunter.position = Vector3.ZERO
	hunter.update_brain(1.0, Vector3(5.0, 0.0, 0.0))
	_check("ia_persigue", hunter.position.x > 0.5)
	var prey := Animals.new()
	prey._build()
	prey.temperament = "passive"
	prey.position = Vector3.ZERO
	prey.update_brain(1.0, Vector3(2.0, 0.0, 0.0), false, -1, true, [])
	_check("ia_huye", prey.position.x < -0.5)
	var horse := Animals.new()
	horse._build()
	horse.species = "caballo"
	horse.tamed = true
	horse.set_mounted(true)
	horse.set_steer(Vector3(1.0, 0.0, 0.0))
	horse.position = Vector3.ZERO
	horse.update_brain(1.0, Vector3(50.0, 0.0, 0.0))
	_check("montura_avanza", horse.position.x > 0.5)
	# 22. Horda: se acerca, se separa y se disuelve.
	var horde := Horde.new()
	horde.ground_func = func(_x: int, _z: int) -> float: return 0.0
	horde.start_horde(5, Vector3.ZERO)
	_check("horda_cuenta", horde.count() == 5)
	var d_before := 0.0
	for m in horde.members:
		d_before += m.position.length()
	horde.update(1.0, Vector3.ZERO)
	var d_after := 0.0
	for m in horde.members:
		d_after += m.position.length()
	_check("horda_se_acerca", d_after < d_before)
	horde.members[0].position = Vector3(0.0, 0.5, 0.0)
	horde.members[1].position = Vector3(0.3, 0.5, 0.0)
	horde.update(1.0, Vector3(100.0, 0.0, 0.0))
	var sep := horde.members[0].position.distance_to(horde.members[1].position)
	_check("horda_separacion", sep > 0.8)
	horde.stop_horde()
	_check("horda_disuelta", horde.count() == 0)
	# 23. Combate y vitales (documento §7).
	_check("jugador_velocidades_doc", Player.WALK_SPEED == 5.5 and Player.SPRINT_SPEED == 8.25 and Player.CROUCH_SPEED == 2.75)
	_check("jugador_salto_gravedad_doc", Player.JUMP_VELOCITY == 9.0 and Player.GRAVITY == 26.0 and Player.EYE_HEIGHT == 1.52)
	var vit := Vitals.new()
	vit.damage(25.0)
	_check("vitales_dano", vit.health == 75.0)
	vit.start_iframes(1.0)
	vit.damage(25.0)
	_check("vitales_iframes_bloquean", vit.health == 75.0)
	vit.update(1.5, false, false, 50.0, false)
	vit.damage(10.0)
	_check("vitales_iframes_expiran", vit.health < 75.0)
	var vit2 := Vitals.new()
	vit2.update(1.0, true, false, 50.0, false)
	_check("vitales_sprint_drena", vit2.stamina == 92.0)
	vit2.update(1.0, false, false, 50.0, false)
	_check("vitales_reposo_regen", vit2.stamina == 100.0)
	var vit3 := Vitals.new()
	vit3.update(10.0, false, true, 50.0, false)
	_check("vitales_oxigeno_cero", vit3.oxygen == 0.0)
	_check("vitales_ahogo_dana", vit3.health < 100.0)
	var vit4 := Vitals.new()
	vit4.update(20.0, false, false, 0.0, false)
	_check("vitales_frio_dana", vit4.health < 100.0)
	var died_box := [false]
	var vit5 := Vitals.new()
	vit5.died.connect(func(): died_box[0] = true)
	vit5.damage(150.0)
	_check("vitales_muerte_emite", died_box[0] and vit5.is_dead())
	var foe := Animals.new()
	foe._build()
	foe.temperament = "aggressive"
	foe.position = Vector3.ZERO
	foe.take_damage(25.0, Vector3(5.0, 0.0, 0.0))
	_check("combate_dano", foe.health == 75.0)
	foe.update_brain(0.1, Vector3(50.0, 0.0, 0.0))
	_check("combate_retroceso_mueve", foe.position.x < 0.0)
	var friend := Animals.new()
	friend._build()
	friend.tamed = true
	_check("combate_amigo_inmune", not friend.take_damage(25.0, Vector3.ZERO))
	var boss := Animals.new()
	boss._build()
	boss.set_boss(true)
	_check("jefe_vida", boss.max_health == 300.0 and boss.phase() == 1)
	boss.take_damage(110.0, Vector3(5.0, 0.0, 0.0))
	_check("jefe_fase2", boss.phase() == 2)
	boss.take_damage(110.0, Vector3(5.0, 0.0, 0.0))
	_check("jefe_fase3", boss.phase() == 3)
	_check("jefe_fase3_veloz", boss.chase_speed() > boss.CHASE_SPEED)
	var defeated_box := [""]
	var victim := Animals.new()
	victim._build()
	victim.temperament = "aggressive"
	victim.defeated.connect(func(name: String): defeated_box[0] = name)
	victim.take_damage(200.0, Vector3.ZERO)
	_check("combate_derrota", victim.dead and defeated_box[0] == victim.species)
	var horde2 := Horde.new()
	horde2.ground_func = func(_x: int, _z: int) -> float: return 0.0
	horde2.start_horde(3, Vector3.ZERO)
	var target := horde2.members[0].position
	_check("horda_dano_area", horde2.damage_at(target, 0.6, 60.0) >= 1 and horde2.count() < 3)
	# 24. Personaje, razas, forja y estaciones (documento §6 y §7.4).
	var chara := Character.new()
	_check("personaje_raza_defecto", chara.race == "human" and chara.attack_mult() == 1.0)
	chara.race = "orc"
	_check("personaje_orco_dano", chara.attack_mult() == 1.25)
	chara.equip("espada_hierro")
	_check("personaje_arma_equipada", chara.equipment["arma"] == "espada_hierro" and chara.attack_mult() == 1.25 * 1.25)
	chara.race = "dwarf"
	var vit6 := Vitals.new()
	chara.apply_to_vitals(vit6)
	_check("personaje_enano_salud", vit6.max_health == 125.0)
	chara.race = "elf"
	chara.apply_to_vitals(vit6)
	vit6.mana = 0.0
	vit6.update(1.0, false, false, 50.0, false)
	_check("personaje_elfo_mana", vit6.mana == 7.5)
	chara.race = "golem"
	chara.equipment["armadura"] = "armadura_hierro"
	chara.apply_to_vitals(vit6)
	vit6.health = 100.0
	vit6.damage(40.0)
	_check("personaje_golem_defensa", absf(vit6.health - 74.5) < 0.01)
	_check("personaje_rango_sube", chara.gain_skill("combate", 10) and chara.skill_rank("combate") == 1)
	_check("personaje_rango_no_sube", not chara.gain_skill("combate", 5) and chara.skill_rank("combate") == 1)
	_check("personaje_doma_mult", chara.gain_skill("doma", 10) and chara.tame_mult() == 1.1)
	_check("doma_mult_aplica", Animals.tame_progress_v2(1.0, 2.0, false, false, 0.0, 1.1) == 1.1)
	var smith := Character.new()
	smith.materials["hierro"] = 3
	var sword_recipe := Forge.recipe_by_id("espada_hierro")
	_check("forja_puede", Forge.can_craft(sword_recipe, smith, false))
	var forged := Forge.apply_craft(sword_recipe, smith, false)
	_check("forja_consume_y_da", forged.get("item", "") == "espada_hierro" and smith.materials["hierro"] == 0)
	_check("forja_creativo_gratis", Forge.can_craft(sword_recipe, Character.new(), true))
	var smelter := Character.new()
	smelter.materials["hierro"] = 2
	smelter.materials["carbon"] = 1
	var steel := Forge.apply_craft(Forge.recipe_by_id("acero"), smelter, false)
	_check("forja_acero", steel.get("material", "") == "acero" and smelter.materials["acero"] == 1)
	_check("estaciones_ocho", Stations.stations().size() == 8)
	_check("estaciones_bloques", Stations.BLOCK_WORKBENCH == 247 and Stations.BLOCK_FORGE == 254)
	var near := Stations.nearby_stations(Vector3i.ZERO, func(cell: Vector3i) -> int: return 247 if cell == Vector3i(0, 0, 0) else 0)
	_check("estaciones_cercania", near == ["workbench"])
	var crafter := Character.new()
	crafter.materials["madera"] = 4
	var craft_inv := {}
	var table := Stations.apply_craft(Stations.recipe_by_id("mano", "mesa_trabajo"), crafter, craft_inv, false)
	_check("estaciones_mesa", table.get("block", -1) == 247 and craft_inv[247] == 1 and crafter.materials["madera"] == 0)
	var smelt_inv := {148: 1}
	var smelted := Stations.apply_craft(Stations.recipe_by_id("furnace", "fundir_hierro"), crafter, smelt_inv, false)
	_check("estaciones_fundir", smelted.get("material", "") == "hierro" and smelted.get("amount", 0) == 2 and smelt_inv[148] == 0)
	var bcat2 := BlockCat.new()
	_check("catalogo_estaciones", bcat2.name_for(247) == "Mesa de trabajo" and bcat2.name_for(254) == "Forja de escultura")
	_check("equipo_nombres", Items.name_of("espada_titan") == "Espada titán" and Items.slot_of("capa_viento") == "capa")
	# 25. Cuevas, estructuras, música y foley (documento §1 y §2).
	_check("cueva_determinista", Gen.cave_noise(5, 3, 7, 777) == Gen.cave_noise(5, 3, 7, 777))
	_check("cueva_umbral_estratos", Gen.cave_threshold(10) > Gen.cave_threshold(2))
	var gen2 := Gen.new()
	gen2.biome = "croma_isla"
	gen2.seed_value = 777
	var under_total := 0
	var under_air := 0
	var bedrock_ok := true
	var surface_ok := true
	for sx in range(20):
		for sz in range(20):
			var h := gen2.terrain_height(sx, sz)
			if gen2.terrain_block_at(Vector3i(sx, 0, sz)) != Gen.BLOCK_BEDROCK:
				bedrock_ok = false
			if gen2.terrain_block_at(Vector3i(sx, h, sz)) == Gen.BLOCK_AIR:
				surface_ok = false
			for sy in range(1, h - 1):
				under_total += 1
				if gen2.terrain_block_at(Vector3i(sx, sy, sz)) == Gen.BLOCK_AIR:
					under_air += 1
	var carve_rate := float(under_air) / float(maxi(under_total, 1))
	_check("cueva_tasa", carve_rate > 0.02 and carve_rate < 0.45)
	_check("cueva_roca_madre", bedrock_ok)
	_check("cueva_superficie_intacta", surface_ok)
	_check("estructura_determinista", Gen.structure_at(10, 10, 777) == Gen.structure_at(10, 10, 777))
	_check("estructura_fuera_spawn", Gen.structure_at(0, 0, 777) == "" and Gen.structure_at(2, 2, 777) == "")
	var found_types := {}
	var tower_cell := Vector3i.ZERO
	for sx in range(60):
		for sz in range(60):
			var t := Gen.structure_at(sx, sz, 777)
			if t != "":
				found_types[t] = true
				if t == "torre" and tower_cell == Vector3i.ZERO and gen2.terrain_height(sx, sz) > gen2.water_level:
					tower_cell = Vector3i(sx, 0, sz)
	_check("estructura_tipos", found_types.size() == 5)
	if tower_cell != Vector3i.ZERO:
		var th := gen2.terrain_height(tower_cell.x, tower_cell.z)
		_check("estructura_torre_bloques", th > gen2.water_level and gen2.terrain_block_at(Vector3i(tower_cell.x, th + 1, tower_cell.z)) == Gen.BLOCK_STONE)
	_check("musica_grupos", MusicData.group_for_biome("montana_nevada") == "nieve" and MusicData.group_for_biome("desierto") == "desierto" and MusicData.group_for_biome("croma_isla") == "pradera")
	_check("musica_nota_determinista", MusicData.note_for("bosque", 5) == MusicData.note_for("bosque", 5))
	_check("musica_midi", absf(MusicData.midi_freq(69) - 440.0) < 0.01)
	_check("foley_difiere", MusicData.foley_params("wood")["freq"] != MusicData.foley_params("stone")["freq"])
	var music := MusicSys.new()
	root.add_child(music)
	music.start_biome("bosque")
	_check("musica_nodo_bioma", music.current_biome == "bosque")
	music.stop_music()
	_check("musica_nodo_para", music.current_biome == "")
	# 26. LAN con transporte en memoria (el backend UDP
	# real cuelga en esta VM: listen() no vuelve; el
	# protocolo es el mismo que en Wi-Fi).
	var lan_host := Lan.new()
	var lan_client := Lan.new()
	lan_host.set_transport(Lan.MemoryTransport.new())
	lan_client.set_transport(Lan.MemoryTransport.new())
	root.add_child(lan_host)
	root.add_child(lan_client)
	var lan_found := []
	var lan_accepted := []
	var lan_joined := []
	var lan_host_states := []
	var lan_client_states := []
	var lan_host_blocks := []
	lan_client.host_found.connect(func(ip: String, _n: String): lan_found.append(ip))
	lan_client.join_accepted.connect(func(pid: int, seed: int, biome: String): lan_accepted.append([pid, seed, biome]))
	lan_host.peer_joined.connect(func(pid: int, _n: String): lan_joined.append(pid))
	lan_host.peer_state.connect(func(pid: int, _s: Dictionary): lan_host_states.append(pid))
	lan_client.peer_state.connect(func(pid: int, _s: Dictionary): lan_client_states.append(pid))
	lan_host.block_received.connect(func(cell: Vector3i, block: int): lan_host_blocks.append([cell, block]))
	lan_host.host_game("Prueba", 777, "croma_isla")
	lan_client.start_discovery()
	lan_client.host_name = "Cliente"
	lan_host.set_state_sender(func() -> Dictionary: return {"pos": [9.0, 9.0, 9.0], "yaw": 1.0})
	lan_client.set_state_sender(func() -> Dictionary: return {"pos": [1.0, 2.0, 3.0], "yaw": 0.5})
	var lan_block_sent := false
	for i in range(80):
		lan_host._process(0.1)
		lan_client._process(0.1)
		if not lan_found.is_empty() and lan_accepted.is_empty():
			lan_client.join_game(lan_found[0])
		if not lan_accepted.is_empty() and not lan_block_sent:
			lan_block_sent = true
			lan_client.send_block(Vector3i(5, 5, 5), 3)
	_check("lan_descubre", not lan_found.is_empty())
	_check("lan_acepta", not lan_accepted.is_empty() and lan_accepted[0][1] == 777 and lan_accepted[0][2] == "croma_isla")
	_check("lan_anfitrion_ve_cliente", not lan_joined.is_empty())
	_check("lan_estado_cliente_a_host", not lan_host_states.is_empty())
	_check("lan_estado_host_a_cliente", not lan_client_states.is_empty())
	_check("lan_bloque_fiable", not lan_host_blocks.is_empty() and lan_host_blocks[0][0] == Vector3i(5, 5, 5) and lan_host_blocks[0][1] == 3)
	lan_host.leave()
	lan_client.leave()
	_check("lan_sale", not lan_host.is_active() and not lan_client.is_active())

	# 27. Editor TouchHud (§7.3): ajustes nuevos, clamp y
	# lectura de desplazamientos.
	_check("hud_opacity_default", float(SettingsRefactor.DEFAULTS["button_opacity"]) == 1.0)
	_check("hud_edit_default", SettingsRefactor.DEFAULTS["hud_edit_mode"] == false)
	_check("hud_offset_default", SettingsRefactor.DEFAULTS["action_offset"] == [0.0, 0.0])
	_check("hud_clamp_x", UIController.clamp_hud_offset(Vector2(1000, 0)) == Vector2(150, 0))
	_check("hud_clamp_y", UIController.clamp_hud_offset(Vector2(0, -1000)) == Vector2(0, -500))
	_check("hud_clamp_low", UIController.clamp_hud_offset(Vector2(-1000, 1000)) == Vector2(-400, 150))
	_check("hud_offset_array", UIController.offset_from_settings({"action_offset": [10.0, -20.0]}, "action_offset") == Vector2(10, -20))
	_check("hud_offset_missing", UIController.offset_from_settings({}, "action_offset") == Vector2.ZERO)

	if _failures > 0:
		printerr("test_3_0: " + str(_failures) + " FALLOS")
		quit(1)
	else:
		print("test_3_0: TODO OK")
		quit(0)
