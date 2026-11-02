extends RefCounted
## CreatureCatalog — las 246 especies del documento de
## arquitectura (sección 5), en datos, no en código.
##
## Fuente: res://data/creatures.json (generado por
## tools/gen_creatures.py): 22 pacíficas + 20 depredadores
## + 40 fantásticas/jefes + 50 de facciones (10 x 5 roles)
## + 106 variantes por bioma + 8 únicos = 246.
## Cada entrada trae: categoría, arquetipo (quadruped,
## biped, avian, serpent, arachnid, aquatic, hopper),
## temperamento (passive/neutral/aggressive), domable,
## comida favorita, montura, biomas, hora, zonas 1-6,
## grupo, jefe, facción y rol.
## Las criaturas se dibujan con cubos procedurales propios
## (FriendlyAnimal y sus arquetipos), nunca con modelos
## .vox ajenos: el documento describe el sistema, no se
## copian sus archivos.

class_name CreatureCatalog

const PATH := "res://data/creatures.json"
const ARCHETYPES := ["quadruped", "biped", "avian", "serpent",
	"arachnid", "aquatic", "hopper"]
const TEMPERAMENTS := ["passive", "neutral", "aggressive"]

var _data: Dictionary = {}


func _init() -> void:
	_data = load_catalog()


static func load_catalog() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(PATH):
		push_warning("CreatureCatalog: falta " + PATH)
		return out
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var list: Array = parsed.get("creatures", [])
	for entry in list:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			continue
		out[str(entry["id"])] = entry
	return out


func count() -> int:
	return _data.size()


func entry_for(creature_id: String) -> Dictionary:
	if _data.has(creature_id):
		return _data[creature_id]
	return {"id": creature_id, "name": "Criatura",
		"category": "", "archetype": "quadruped",
		"temperament": "passive", "tameable": false,
		"food": "", "rideable": false, "biomes": [],
		"time": "any", "zoneMin": 1, "zoneMax": 1,
		"group": [1, 1], "boss": false,
		"faction": "", "role": "", "base": ""}


func name_for(creature_id: String) -> String:
	return str(entry_for(creature_id)["name"])


func category_for(creature_id: String) -> String:
	return str(entry_for(creature_id)["category"])


func temperament_for(creature_id: String) -> String:
	return str(entry_for(creature_id)["temperament"])


func is_tameable(creature_id: String) -> bool:
	return bool(entry_for(creature_id)["tameable"])


func food_for(creature_id: String) -> String:
	return str(entry_for(creature_id)["food"])


func is_boss(creature_id: String) -> bool:
	return bool(entry_for(creature_id)["boss"])


func all_ids() -> Array:
	return _data.keys()


func by_category(category: String) -> Array[String]:
	var out: Array[String] = []
	for key in _data.keys():
		if str(_data[key]["category"]) == category:
			out.append(str(key))
	return out


func by_biome(biome: String) -> Array[String]:
	var out: Array[String] = []
	for key in _data.keys():
		var biomes: Array = _data[key]["biomes"]
		if biome in biomes:
			out.append(str(key))
	return out


func factions() -> Array[String]:
	var out: Array[String] = []
	for key in _data.keys():
		var f: String = str(_data[key]["faction"])
		if f != "" and f not in out:
			out.append(f)
	return out


func roles_of_faction(faction: String) -> Array[String]:
	var out: Array[String] = []
	for key in _data.keys():
		if str(_data[key]["faction"]) == faction:
			var r: String = str(_data[key]["role"])
			if r != "" and r not in out:
				out.append(r)
	return out
