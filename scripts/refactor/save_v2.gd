extends RefCounted
## SaveV2 — guardado diferencial v2 de Bloques Mágicos 2.0.
##
## Idea de Cube Unbound (EditStore): no se guarda el terreno
## entero, solo la semilla y lo que el jugador cambió. La v1 de
## la variante ya hacía eso con modified_blocks plano. La v2
## añade lo que pedía el plan de Cube: nombre, semilla, jugador
## (posición + inventario) y ediciones agrupadas por región de
## 16x16 columnas en XZ, en el formato del ejemplo del plan:
##   {"world_name": ..., "seed": ..., "player": {"position": [...],
##    "inventory": {...}}, "edits": {"0,0": [[x, y, z, id], ...]}}
## La v1 sigue siendo el guardado principal (compatibilidad);
## la v2 se escribe además al guardar, y sirve para exportar
## e importar sin tocar los mundos de 1.15.0.

class_name SaveV2

const VERSION := 2
const DIR := "user://worlds_v2"
const REGION := 16


static func region_key(cell: Vector3i) -> String:
	var cx := floori(float(cell.x) / float(REGION))
	var cz := floori(float(cell.z) / float(REGION))
	return "%d,%d" % [cx, cz]


static func region_of_key(key: String) -> Vector2i:
	var parts := key.split(",")
	if parts.size() != 2:
		return Vector2i(0, 0)
	return Vector2i(int(parts[0]), int(parts[1]))


## modified plano ("x,y,z" -> id) -> ediciones por región.
static func encode_edits(modified: Dictionary) -> Dictionary:
	var edits: Dictionary = {}
	for key in modified.keys():
		var cell := WorldSeedManager.cell_of(str(key))
		if cell.x == -9999:
			continue
		var region := region_key(cell)
		if not edits.has(region):
			edits[region] = []
		(edits[region] as Array).append([cell.x, cell.y, cell.z, int(modified[key])])
	return edits


## Ediciones por región -> modified plano. Ignora entradas
## mal formadas en vez de fallar: un archivo viejo no debe
## romper la carga de un mundo.
static func decode_edits(edits: Dictionary) -> Dictionary:
	var modified: Dictionary = {}
	for region in edits.keys():
		var entries: Array = edits[region]
		for entry in entries:
			if typeof(entry) != TYPE_ARRAY or entry.size() != 4:
				continue
			var cell := Vector3i(int(entry[0]), int(entry[1]), int(entry[2]))
			modified[WorldSeedManager.key_of(cell)] = int(entry[3])
	return modified


static func encode_world(world_name: String, seed: int, seed_text: String, biome: String, player_pos: Vector3, inventory: Dictionary, modified: Dictionary) -> Dictionary:
	return {
		"version": VERSION,
		"name": world_name,
		"seed": seed,
		"seed_text": seed_text,
		"biome": biome,
		"player": {"position": [player_pos.x, player_pos.y, player_pos.z], "inventory": inventory},
		"edits": encode_edits(modified),
	}


static func decode_world(data: Dictionary) -> Dictionary:
	if int(data.get("version", 0)) != VERSION:
		return {}
	if not data.has("seed") or not data.has("edits"):
		return {}
	var player: Dictionary = data.get("player", {})
	var pos: Array = player.get("position", [0.5, 4.0, 0.5])
	if pos.size() < 3:
		pos = [0.5, 4.0, 0.5]
	return {
		"version": VERSION,
		"name": str(data.get("name", "Mundo")),
		"seed": int(data.get("seed", 0)),
		"seed_text": str(data.get("seed_text", "")),
		"biome": str(data.get("biome", "pradera_verde")),
		"player_pos": Vector3(float(pos[0]), float(pos[1]), float(pos[2])),
		"inventory": data.get("player", {}).get("inventory", {}),
		"modified": decode_edits(data.get("edits", {})),
	}


static func _path(world_name: String, seed: int) -> String:
	return "%s/%s_%d.json" % [DIR, WorldSeedManager.sanitize_name(world_name), seed]


static func save_world_v2(world_name: String, seed: int, seed_text: String, biome: String, player_pos: Vector3, inventory: Dictionary, modified: Dictionary) -> bool:
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.make_dir_recursive("worlds_v2")
	var file := FileAccess.open(_path(world_name, seed), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(encode_world(world_name, seed, seed_text, biome, player_pos, inventory, modified)))
	file.close()
	return true


static func load_world_v2(world_name: String, seed: int) -> Dictionary:
	var path := _path(world_name, seed)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return decode_world(parsed)
