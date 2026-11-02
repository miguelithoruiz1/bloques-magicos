extends RefCounted
## SettingsRefactor — ajustes de la variante refactorizada.
##
## Archivo PROPIO de la variante: user://settings_refactor.cfg.
## NO toca user://ajustes.json de 1.15.0: la variante debe poder
## probarse sin borrar ni cambiar la configuración del juego actual
## del niño. Al borrar este archivo, todo vuelve a los defaults.
##
## Sensibilidad de cámara: la UI la muestra de 0 a 100 (default 50,
## como pide la especificación); internamente se guarda también de
## 0 a 100 y se convierte con camera_sensitivity_factor():
## factor = sensibilidad / 50.0 (50 → 1.0, igual que el 1.0 de
## 1.15.0). Así ningún cambio de escala rompe el tacto conocido.

class_name SettingsRefactor

const PATH := "user://settings_refactor.cfg"
const SECTION := "ajustes"

const DEFAULTS := {
	# Táctil.
	"control_mode": "joystick_tap", # joystick_tap | dpad_tap | joystick_crosshair
	"joystick_visibility": "always", # always | hidden | when_used
	"invert_y": false,
	"auto_jump": false,
	"easy_sprint": true,
	"left_handed_inventory": false,
	"perspective_button": true,
	"break_delay": 0.25,
	"camera_sensitivity": 50, # 0..100, default 50.
	"button_size": 1.0,
	"button_opacity": 1.0, # 3.0: opacidad de los botones táctiles.
	"hud_edit_mode": false, # 3.0: editor TouchHud (arrastrar botones).
	"action_offset": [0.0, 0.0], # 3.0: desplazamiento de la columna de acciones.
	"action2_offset": [0.0, 0.0], # 3.0: desplazamiento de la segunda columna.
	# Mando (TV).
	"gamepad_camera_sensitivity": 50,
	"gamepad_cursor_sensitivity": 50,
	"gamepad_invert_y": false,
	"gamepad_auto_jump": false,
	"hide_gamepad_hints": false,
	"hide_gamepad_cursor": false,
	"swap_ab": false,
	"swap_xy": false,
	# Audio y voces.
	"voice_volume": 0.8,
	"music_volume": 0.5,
	# Mundo y semilla.
	"seed_text": "",
	"world_name": "MundoRefactor",
	"biome": "pradera_verde", # 2.0 default para instalaciones nuevas; los 4 viejos siguen en la lista. Usuarios con cfg guardada conservan su bioma.
	"render_radius": 20, # 3.0: menos columnas que 24 (~1/3 menos) para el stick. Usuarios con cfg guardada conservan su radio.
	"age_band": "5-7", # 3.0 multiedad: 5-7 | 8-12 | 13+ (palabras y operaciones por banda).
	# 4.0: perfil cognitivo y modo desarrollador, espejo de
	# CognitiveProfile (personaje.json). SettingsScene los edita
	# y actualiza ambos guardados a la vez (ver settings_scene.gd).
	"perfil_cognitivo": "explorador", # explorador | constructor | maestro
	"modo_desarrollador": false,
	"edad_jugador": 6,
	# Remapeo de mando: acción -> botón Joypad (índices Godot).
	"remap": {
		"jump": 0, "crouch": 1, "inventory": 3,
		"place": 7, "remove": 6, "perspective": 2,
	},
}


static func load_settings() -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return out
	for key in DEFAULTS.keys():
		if cfg.has_section_key(SECTION, str(key)):
			out[key] = cfg.get_value(SECTION, str(key))
	return out


static func save_settings(settings: Dictionary) -> bool:
	var cfg := ConfigFile.new()
	for key in settings.keys():
		cfg.set_value(SECTION, str(key), settings[key])
	return cfg.save(PATH) == OK


static func reset_settings() -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate(true)
	save_settings(out)
	return out


## Factor 0.0..2.0 a partir de la sensibilidad 0..100.
static func camera_sensitivity_factor(settings: Dictionary) -> float:
	return clampf(float(settings.get("camera_sensitivity", 50)) / 50.0, 0.0, 2.0)


static func gamepad_camera_factor(settings: Dictionary) -> float:
	return clampf(float(settings.get("gamepad_camera_sensitivity", 50)) / 50.0, 0.0, 2.0)


static func remap_button(settings: Dictionary, action: String, fallback: int) -> int:
	var remap: Dictionary = settings.get("remap", {})
	if remap.has(action):
		return int(remap[action])
	return fallback
