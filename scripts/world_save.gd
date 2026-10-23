extends RefCounted
## Persistencia del mundo de Bloques Mágicos.
## Guarda los bloques en user://mundo.json con un formato simple:
## {"version": 1, "blocks": [{"x":0,"y":0,"z":0,"t":"color","d":0}, ...]}
## "t" = tipo ("color" | "numero"); "d" = dato (índice de color 0-5 o número 1-5).
## main.gd lo precarga y llama a estas funciones estáticas.

const SAVE_PATH := "user://mundo.json"
const SAVE_VERSION := 1


static func save_world(blocks: Dictionary) -> bool:
	var arr: Array = []
	for cell in blocks.keys():
		var data: Dictionary = blocks[cell]
		arr.append({
			"x": int(cell.x),
			"y": int(cell.y),
			"z": int(cell.z),
			"t": String(data.get("tipo", "color")),
			"d": int(data.get("dato", 0)),
		})
	var payload := {"version": SAVE_VERSION, "blocks": arr}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Bloques Mágicos: no se pudo abrir el archivo de guardado.")
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


static func load_world() -> Dictionary:
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
	var arr: Variant = parsed.get("blocks", [])
	if typeof(arr) != TYPE_ARRAY:
		return result
	for item in arr:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var cell := Vector3i(
			int(item.get("x", 0)),
			int(item.get("y", 0)),
			int(item.get("z", 0))
		)
		result[cell] = {
			"tipo": String(item.get("t", "color")),
			"dato": int(item.get("d", 0)),
		}
	return result
