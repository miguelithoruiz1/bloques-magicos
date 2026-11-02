extends RefCounted
## 01 — CognitiveProfile: perfil cognitivo guardado en personaje.json.
##
## Qué resuelve:
## - La 3.0.2 ya tiene "age_band" (5-7 / 8-12 / 13+) en
##   settings_refactor.cfg, pero NO un perfil cognitivo en el
##   personaje, NO cubre 3-6 años y NO fija dificultad en Pacífico
##   para los pequeños. Este archivo añade eso sin borrar el
##   guardado viejo: lee personaje.json si existe y, si no,
##   migra la banda vieja (settings) a perfil nuevo.
## - NO toca CharacterData (bloques3_character.json: raza,
##   monedas, equipo). Ese archivo sigue siendo el personaje
##   de juego; personaje.json es la capa de perfil / accesibilidad.
##   Si en el futuro se unifican, se hace en una migración
##   explícita, no mezclando diccionarios a ciegas.
##
## Perfiles (los 3 que pide el encargo, con edades reales):
##   EXPLORER  = 3-6 años, Explorador Inicial
##   BUILDER   = 7-12 años, Constructor Creativo
##   MASTER    = 13-50+ años, Maestro y Mente Activa
##
## Uso mínimo en el juego (ver 06_integracion.md):
##   var profile := CognitiveProfile.load_or_create()
##   profile.apply_to_hud(hud)
##   profile.apply_to_world(world_settings_dict)

class_name CognitiveProfile

const SAVE_PATH := "user://personaje.json"
const LEGACY_SETTINGS_PATH := "user://settings_refactor.cfg"

enum Profile { EXPLORER, BUILDER, MASTER }

const PROFILE_NAMES := {
	Profile.EXPLORER: "explorador",
	Profile.BUILDER: "constructor",
	Profile.MASTER: "maestro",
}

const PROFILE_TITLES := {
	Profile.EXPLORER: "Explorador Inicial (3-6)",
	Profile.BUILDER: "Constructor Creativo (7-12)",
	Profile.MASTER: "Maestro y Mente Activa (13-50+)",
}

# Estadísticas que NUNCA se muestran en Explorador.
const HIDDEN_STATS_EXPLORER := [
	"armadura", "critico", "esquiva", "estamina",
	"mana", "oxigeno", "temperatura",
]

# Cámaras permitidas por perfil. Los nombres coinciden con el
# sistema de 4 cámaras del GDD: 1ª, 2ª (Espejo Feynman),
# 3ª y Cenital. En Explorador solo 3ª, para no desorientar.
const CAMERAS_EXPLORER := ["tercera"]
const CAMERAS_BUILDER := ["primera", "segunda", "tercera", "cenital"]
const CAMERAS_MASTER := ["primera", "segunda", "tercera", "cenital"]

# Zonas radiales desbloqueables por perfil (la 3.0.2 ya calcula
# zona por distancia; aquí se pone el techo, no el cálculo).
const MAX_ZONE_EXPLORER := 1
const MAX_ZONE_BUILDER := 3
const MAX_ZONE_MASTER := 6
const MAX_DANGER_MASTER := 999

var player_name := "Héroe"
var age_years := 6
var profile: int = Profile.EXPLORER
var difficulty := "pacifico"
var developer_mode := false
var voice_guide := true
var pomodoro_minutes := 15


static func profile_from_age(age: int) -> int:
	if age <= 6:
		return Profile.EXPLORER
	if age <= 12:
		return Profile.BUILDER
	return Profile.MASTER


static func profile_from_old_band(band: String) -> int:
	match band:
		"8-12":
			return Profile.BUILDER
		"13+":
			return Profile.MASTER
		_:
			# "5-7" y cualquier valor desconocido caen en
			# Explorador: es el perfil más seguro por defecto.
			return Profile.EXPLORER


static func load_or_create() -> CognitiveProfile:
	var p := CognitiveProfile.new()
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				p.from_dict(parsed)
				return p
	# Sin personaje.json: migrar la banda vieja si existe.
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_SETTINGS_PATH) == OK:
		var band := str(cfg.get_value("ajustes", "age_band", "5-7"))
		p.profile = profile_from_old_band(band)
		if band == "5-7":
			p.age_years = 6
		p.save()
		return p
	p.save()
	return p


func from_dict(data: Dictionary) -> void:
	player_name = str(data.get("nombre", "Héroe"))
	age_years = int(data.get("edad", 6))
	var name := str(data.get("perfil", "explorador"))
	profile = Profile.EXPLORER
	for key in PROFILE_NAMES:
		if PROFILE_NAMES[key] == name:
			profile = key
			break
	# Si la edad y el perfil no cuadran, manda la edad:
	# un niño de 5 años no debe quedar en Maestro por un
	# archivo editado a mano.
	var by_age := profile_from_age(age_years)
	if profile != by_age and age_years <= 12:
		profile = by_age
	difficulty = str(data.get("dificultad", "pacifico"))
	developer_mode = bool(data.get("modo_desarrollador", false))
	voice_guide = bool(data.get("guia_por_voz", true))
	pomodoro_minutes = int(data.get("pomodoro_minutos", 15))
	_apply_profile_rules()


func to_dict() -> Dictionary:
	_apply_profile_rules()
	return {
		"nombre": player_name,
		"edad": age_years,
		"perfil": PROFILE_NAMES[profile],
		"perfil_titulo": PROFILE_TITLES[profile],
		"dificultad": difficulty,
		"modo_desarrollador": developer_mode,
		"guia_por_voz": voice_guide,
		"pomodoro_minutos": pomodoro_minutes,
		"version": 1,
	}


func save() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return true


func _apply_profile_rules() -> void:
	match profile:
		Profile.EXPLORER:
			# Regla dura del encargo: dificultad fija en Pacífico.
			difficulty = "pacifico"
			voice_guide = true
			pomodoro_minutes = 15
		Profile.BUILDER:
			pomodoro_minutes = 20
		Profile.MASTER:
			pomodoro_minutes = 25
	pomodoro_minutes = clampi(pomodoro_minutes, 15, 25)


func profile_name() -> String:
	return PROFILE_NAMES[profile]


func set_profile_from_name(name: String) -> void:
	for key in PROFILE_NAMES:
		if PROFILE_NAMES[key] == name:
			profile = key
			break
	_apply_profile_rules()
	save()


func set_profile_from_band(band: String) -> void:
	profile = CognitiveProfile.profile_from_old_band(band)
	match profile:
		Profile.EXPLORER:
			age_years = 6
		Profile.BUILDER:
			age_years = 10
		_:
			age_years = 20
	_apply_profile_rules()
	save()


func title() -> String:
	return PROFILE_TITLES[profile]


func is_explorer() -> bool:
	return profile == Profile.EXPLORER


func is_builder() -> bool:
	return profile == Profile.BUILDER


func is_master() -> bool:
	return profile == Profile.MASTER


func allowed_cameras() -> Array:
	match profile:
		Profile.EXPLORER:
			return CAMERAS_EXPLORER.duplicate()
		Profile.BUILDER:
			return CAMERAS_BUILDER.duplicate()
		_:
			return CAMERAS_MASTER.duplicate()


func max_zone() -> int:
	match profile:
		Profile.EXPLORER:
			return MAX_ZONE_EXPLORER
		Profile.BUILDER:
			return MAX_ZONE_BUILDER
		_:
			return MAX_ZONE_MASTER


func max_danger_level() -> int:
	if profile == Profile.MASTER:
		return MAX_DANGER_MASTER
	return 10


func hidden_stats() -> Array:
	if profile == Profile.EXPLORER:
		return HIDDEN_STATS_EXPLORER.duplicate()
	return []


func show_complex_stats() -> bool:
	return profile != Profile.EXPLORER


func show_first_steps_panel() -> bool:
	# El panel "Primeros pasos (0 de 14)" se oculta en
	# Explorador: es texto de progreso, no juego.
	return profile != Profile.EXPLORER


func giant_buttons_only() -> bool:
	# Explorador: joystick + 3 botones gigantes, nada más.
	return profile == Profile.EXPLORER


func words_allowed() -> Array[String]:
	match profile:
		Profile.EXPLORER:
			return ["SOL", "CASA", "MAMA", "PAPA"]
		Profile.BUILDER:
			return ["SOL", "CASA", "ARBOL", "PUENTE", "MAMA", "PAPA"]
		_:
			return ["SOL", "CASA", "ARBOL", "PUENTE", "MAMA", "PAPA", "LIBRO", "MUNDO"]


func operators_allowed() -> Array[String]:
	match profile:
		Profile.EXPLORER:
			return ["+"]
		Profile.BUILDER:
			return ["+", "-", "×"]
		_:
			return ["+", "-", "×", "÷"]


func can_use_logic_gates() -> bool:
	return profile == Profile.MASTER


func can_use_tycoon() -> bool:
	return profile == Profile.MASTER


func can_use_memory_palaces() -> bool:
	return profile == Profile.MASTER


func can_tame_pets() -> bool:
	return profile != Profile.EXPLORER
