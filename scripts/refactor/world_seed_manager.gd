extends RefCounted
## WorldSeedManager — semillas, guardado y compartición de mundos.
##
## Formato de guardado (nuevo, NO compatible con mundo.json de
## 1.15.0 a propósito: la variante no debe leer ni sobrescribir
## los mundos del niño):
##   user://worlds/{nombre}_{semilla}.json
##   {"version": 1, "name": "...", "seed": 123, "seed_text": "...",
##    "biome": "croma_isla",
##    "modified_blocks": {"x,y,z": block_id, ...}}
## El terreno base es DETERMINISTA a partir de la semilla, así que
## el archivo solo guarda lo que el jugador cambió: un bloque
## colocado guarda su id; un bloque quitado guarda 0 (aire). Al
## cargar, el generador regenera el terreno y aplica encima el
## diccionario diferencial, en ese orden.
##
## Semilla: cualquier texto o número. String.hash() de Godot 4
## devuelve un entero con signo de 32 bits: se usa tal cual como
## noise.seed (FastNoiseLite acepta negativos). Dos textos
## distintos pueden colisionar en hash (es esperable y se
## documenta); el nombre del archivo guarda también el texto
## original para que el jugador lo reconozca.

class_name WorldSeedManager

const WORLDS_DIR := "user://worlds"
const VERSION := 1


## Texto o número → entero de semilla. Vacío = 0 (semilla fija
## «mundo vacío», no aleatoria: la aleatoriedad se pide aparte).
static func seed_from_string(text: String) -> int:
	var t := text.strip_edges()
	if t == "":
		return 0
	if t.is_valid_int():
		return int(t)
	return t.hash()


static func random_seed_text() -> String:
	return str(randi_range(100000, 999999999))


static func sanitize_name(name: String) -> String:
	var out := ""
	for ch in name:
		if ch in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
			out += "_"
		else:
			out += ch
	out = out.strip_edges()
	if out == "":
		out = "Mundo"
	return out


static func world_path(world_name: String, seed_text: String) -> String:
	var seed := seed_from_string(seed_text)
	return "%s/%s_%d.json" % [WORLDS_DIR, sanitize_name(world_name), seed]


static func save_world(world_name: String, seed_text: String, biome: String, modified: Dictionary) -> bool:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("worlds")
	var payload := {
		"version": VERSION,
		"name": world_name,
		"seed": seed_from_string(seed_text),
		"seed_text": seed_text,
		"biome": biome,
		"modified_blocks": modified,
	}
	var path := world_path(world_name, seed_text)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("WorldSeedManager: no se pudo escribir " + path)
		return false
	file.store_string(JSON.stringify(payload))
	file.close()
	return true


static func load_world(world_name: String, seed_text: String) -> Dictionary:
	var path := world_path(world_name, seed_text)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var modified: Dictionary = parsed.get("modified_blocks", {})
	return {
		"version": int(parsed.get("version", 0)),
		"name": String(parsed.get("name", world_name)),
		"seed": int(parsed.get("seed", seed_from_string(seed_text))),
		"seed_text": String(parsed.get("seed_text", seed_text)),
		"biome": String(parsed.get("biome", "croma_isla")),
		"modified_blocks": modified,
	}


## Exportación compartible: JSON compacto → Base64. Incluye
## semilla + bloques modificados, NO el terreno base (se regenera
## al importar con la misma semilla). Devuelve "" si no hay nada
## que exportar (sin semilla ni cambios no hay mundo que dar).
static func export_base64(world_name: String, seed_text: String, biome: String, modified: Dictionary) -> String:
	var payload := {
		"version": VERSION,
		"name": world_name,
		"seed": seed_from_string(seed_text),
		"seed_text": seed_text,
		"biome": biome,
		"modified_blocks": modified,
	}
	var raw := JSON.stringify(payload).to_utf8_buffer()
	return Marshalls.raw_to_base64(raw)


## Importación: Base64 → diccionario del mundo, o {} si el texto
## no es un mundo válido. No escribe ningún archivo: quien llama
## decide si guarda (save_world) o solo lo muestra.
static func import_base64(encoded: String) -> Dictionary:
	var raw := Marshalls.base64_to_raw(encoded.strip_edges())
	if raw.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("version", 0)) != VERSION:
		return {}
	if not parsed.has("seed") or not parsed.has("modified_blocks"):
		return {}
	return {
		"version": VERSION,
		"name": String(parsed.get("name", "Importado")),
		"seed": int(parsed.get("seed")),
		"seed_text": String(parsed.get("seed_text", "")),
		"biome": String(parsed.get("biome", "croma_isla")),
		"modified_blocks": parsed.get("modified_blocks"),
	}


## Copia al portapapeles y, como respaldo (en TV el portapapeles
## puede no existir), también a user://worlds/export.txt.
static func share_to_clipboard(encoded: String) -> bool:
	DisplayServer.clipboard_set(encoded)
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("worlds")
	var file := FileAccess.open(WORLDS_DIR + "/export.txt", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(encoded)
	file.close()
	return true


static func key_of(cell: Vector3i) -> String:
	return "%d,%d,%d" % [cell.x, cell.y, cell.z]


static func cell_of(key: String) -> Vector3i:
	var parts := key.split(",")
	if parts.size() != 3:
		return Vector3i(-9999, -9999, -9999)
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
