extends RefCounted
## Persistencia del mundo de Bloques Mágicos.
## Cada mundo libre tiene su propio archivo (1.11.0): la pradera de
## siempre sigue en user://mundo.json, Ciudad en user://mundo_ciudad.json
## y Espacio en user://mundo_espacio.json. Así los bloques de un mundo
## nunca aparecen en otro. Formato simple:
## {"version": 2, "blocks": [{"x":0,"y":0,"z":0,"t":"color","d":0}, ...]}
## "t" = tipo ("color" | "numero" | "letra" | "magia" | objeto libre);
## "d" = dato (índice de color 0-11, número 1-5, índice de letra 0-26,
## índice de palabra mágica 0-9, 0 para objetos libres).
## main.gd lo precarga y llama a estas funciones estáticas.
##
## Migración 1 → 2: en 1.10.0 las letras eran solo 11 (A, E, I, O, U,
## M, P, S, T, L, N); en 1.11.0 el abecedario tiene 27. Al cargar un
## guardado versión 1, los cubos con letras se reasignan con el mapa
## de abajo para que sigan diciendo la misma letra. Los colores 0-5,
## los números y los objetos libres no cambian de índice.

const SAVE_PATH := "user://mundo.json"
const SAVE_VERSION := 2

## Índice nuevo de cada letra vieja (versión 1 → 1.11.0):
## vieja: A E I O U M P S T L N
## nueva: A E I O U M P S T L N en el abecedario completo.
const _LETRA_MAP_V1: Array = [0, 4, 8, 15, 21, 12, 16, 19, 20, 11, 13]


## Archivo de guardado del mundo libre indicado ("" = pradera).
static func path_for(mundo_id: String) -> String:
	if mundo_id == "" or mundo_id == "libre":
		return SAVE_PATH
	return "user://mundo_%s.json" % mundo_id


static func save_world(blocks: Dictionary) -> bool:
	return save_world_for("", blocks)


static func save_world_for(mundo_id: String, blocks: Dictionary) -> bool:
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
	var file := FileAccess.open(path_for(mundo_id), FileAccess.WRITE)
	if file == null:
		push_warning("Bloques Mágicos: no se pudo abrir el archivo de guardado.")
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


static func load_world() -> Dictionary:
	return load_world_for("")


static func load_world_for(mundo_id: String) -> Dictionary:
	var result: Dictionary = {}
	var path := path_for(mundo_id)
	if not FileAccess.file_exists(path):
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return result
	var version := int(parsed.get("version", 1))
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
		var tipo := String(item.get("t", "color"))
		var dato := int(item.get("d", 0))
		# Migración 1 → 2: reasignar los cubos con letras viejos.
		if version < 2 and tipo == "letra":
			if dato >= 0 and dato < _LETRA_MAP_V1.size():
				dato = int(_LETRA_MAP_V1[dato])
			else:
				continue
		result[cell] = {
			"tipo": tipo,
			"dato": dato,
		}
	return result
