extends RefCounted
## Progreso de Mundos (Fase 2), guardado SEPARADO de mundo.json.
## user://progreso.json: {"version": 1, "completados": {"colores": [0, 4], ...}}
## Guarda los índices (0-4) de los niveles superados por mundo.
## Desbloqueo en orden: el nivel 0 siempre está abierto; el nivel N se
## abre al superar el nivel N-1. Cada nivel superado da 1 estrella.

const SAVE_PATH := "user://progreso.json"
const SAVE_VERSION := 1
const NIVELES_POR_MUNDO := 10


static func load_progress() -> Dictionary:
	var result: Dictionary = {}
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
	var comp: Variant = parsed.get("completados", {})
	if typeof(comp) != TYPE_DICTIONARY:
		return result
	for mundo in comp.keys():
		var arr: Variant = comp[mundo]
		if typeof(arr) != TYPE_ARRAY:
			continue
		var limpios: Array = []
		for v in arr:
			var n := int(v)
			if n >= 0 and n < NIVELES_POR_MUNDO and not limpios.has(n):
				limpios.append(n)
		result[String(mundo)] = limpios
	return result


static func save_progress(progress: Dictionary) -> bool:
	var payload := {"version": SAVE_VERSION, "completados": progress}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


## Marca el nivel como superado. Devuelve true si era nuevo.
static func mark_completed(progress: Dictionary, mundo: String, nivel: int) -> bool:
	if nivel < 0 or nivel >= NIVELES_POR_MUNDO:
		return false
	if not progress.has(mundo):
		progress[mundo] = []
	var arr: Array = progress[mundo]
	if arr.has(nivel):
		return false
	arr.append(nivel)
	return true


static func is_completed(progress: Dictionary, mundo: String, nivel: int) -> bool:
	if not progress.has(mundo):
		return false
	return (progress[mundo] as Array).has(nivel)


static func is_unlocked(progress: Dictionary, mundo: String, nivel: int) -> bool:
	if nivel <= 0:
		return true
	return is_completed(progress, mundo, nivel - 1)


static func stars_for(progress: Dictionary, mundo: String) -> int:
	if not progress.has(mundo):
		return 0
	return (progress[mundo] as Array).size()


static func stars_total(progress: Dictionary) -> int:
	var total := 0
	for mundo in progress.keys():
		total += (progress[mundo] as Array).size()
	return total
