extends RefCounted
## Ajustes de Bloques Mágicos (1.12.0), guardado SEPARADO de
## progreso.json y de mundo.json: user://ajustes.json.
## Si el archivo no existe o está roto, se usan los valores por
## defecto y el juego sigue funcionando. Nunca se toca el progreso
## ni los mundos libres desde aquí.
##
## Campos (todos con valor por defecto):
##   control: "tv" | "tactil" | "teclado"
##   giro: 0.5 (lento) | 1.0 (normal) | 1.5 (rápido)
##   caminar: 0.7 (lento) | 1.0 (normal) | 1.4 (rápido)
##   volumen_voces: 0.0 | 0.5 | 1.0
##   volumen_musica: 0.0 | 0.5 | 1.0
##   texto: 0.85 (pequeño) | 1.0 (normal) | 1.25 (grande)
##   vista: 0 (primera persona) | 1 (segunda persona, Blocky)
##   menos_movimiento: false | true
##   mas_contraste: false | true

const SAVE_PATH := "user://ajustes.json"
const SAVE_VERSION := 1

const LevelsData := preload("res://scripts/levels_data.gd")
const ProgressSave := preload("res://scripts/progress_save.gd")


static func defaults() -> Dictionary:
	return {
		"control": "tv",
		"giro": 1.0,
		"caminar": 1.0,
		"volumen_voces": 1.0,
		"volumen_musica": 1.0,
		"texto": 1.0,
		"vista": 0,
		"menos_movimiento": false,
		"mas_contraste": false,
	}


static func load_settings() -> Dictionary:
	var result := defaults()
	# 1.12.0 TV + celular: sin archivo guardado, el táctil queda por
	# defecto solo en la exportación de celular (feature "phone" del
	# preset); en TV y en el resto, el mando TV sigue siendo el
	# defecto. Un archivo guardado siempre manda sobre esto.
	if OS.has_feature("phone"):
		result["control"] = "tactil"
	if not FileAccess.file_exists(SAVE_PATH):
		return result
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return result
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return result
	var d: Dictionary = parsed
	if d.has("control") and String(d["control"]) in ["tv", "tactil", "teclado"]:
		result["control"] = String(d["control"])
	if d.has("giro") and float(d["giro"]) in [0.5, 1.0, 1.5]:
		result["giro"] = float(d["giro"])
	if d.has("caminar") and float(d["caminar"]) in [0.7, 1.0, 1.4]:
		result["caminar"] = float(d["caminar"])
	if d.has("volumen_voces") and float(d["volumen_voces"]) in [0.0, 0.5, 1.0]:
		result["volumen_voces"] = float(d["volumen_voces"])
	if d.has("volumen_musica") and float(d["volumen_musica"]) in [0.0, 0.5, 1.0]:
		result["volumen_musica"] = float(d["volumen_musica"])
	if d.has("texto") and float(d["texto"]) in [0.85, 1.0, 1.25]:
		result["texto"] = float(d["texto"])
	if d.has("vista") and int(d["vista"]) in [0, 1]:
		result["vista"] = int(d["vista"])
	if d.has("menos_movimiento"):
		result["menos_movimiento"] = bool(d["menos_movimiento"])
	if d.has("mas_contraste"):
		result["mas_contraste"] = bool(d["mas_contraste"])
	return result


static func save_settings(settings: Dictionary) -> bool:
	var payload := defaults()
	for k in payload.keys():
		if settings.has(k):
			payload[k] = settings[k]
	payload["version"] = SAVE_VERSION
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


## Siguiente nivel pendiente de un mundo: el primer índice no
## completado; si están todos, el último (para rejugar).
static func next_pending_level(progress: Dictionary, mundo: String) -> int:
	var niveles := LevelsData.get_niveles(mundo)
	if niveles.is_empty():
		return 0
	for i in range(niveles.size()):
		if not ProgressSave.is_completed(progress, mundo, i):
			return i
	return niveles.size() - 1


## Un portal de mundo está bloqueado solo si su siguiente nivel
## pendiente no está desbloqueado según el progreso existente.
## En un progreso normal eso no pasa (el siguiente pendiente
## siempre está desbloqueado), pero la regla existe, se muestra
## con candado y bloquea la entrada: así un progreso inconsistente
## nunca abre un nivel que no corresponde.
static func portal_locked(progress: Dictionary, mundo: String) -> bool:
	if LevelsData.get_niveles(mundo).is_empty():
		return false
	return not ProgressSave.is_unlocked(progress, mundo, next_pending_level(progress, mundo))
