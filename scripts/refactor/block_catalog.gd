extends RefCounted
## BlockCatalog — catálogo de bloques en datos, no en código.
##
## Idea tomada del informe de Cube Unbound (mods/*.json): los
## bloques se describen en un JSON (res://data/blocks.json) con
## id, nombre, color, dureza, forma, luz y familia de sonido.
## El generador sigue mandando en el terreno; este catálogo es
## la fuente para la paleta, la ayuda y los bloques nuevos de
## 2.0 (tablones 84, ladrillo 85, vidrio 86, nieve 87 y cristal
## brillo 88). Si el JSON no está en la exportación, se usa la
## misma tabla incrustada en FALLBACK: el juego nunca falla
## por un archivo ausente.
##
## IDs: se conservan los del generador de la variante (hierba
## 1, tierra 2, piedra 3, madera 4, hojas 5, agua 6, arena 7),
## no los del plan de Cube, para no romper colores (10-21),
## números (30-39), operadores (40-43) ni letras (50-76).

class_name BlockCatalog

const PATH := "res://data/blocks.json"

const FALLBACK := {
	0: {"name": "Aire", "color": [0.0, 0.0, 0.0], "hardness": -1.0, "shape": "none", "light": 0, "sound": "none"},
	1: {"name": "Hierba", "color": [0.25, 0.65, 0.25], "hardness": 0.55, "shape": "solid", "light": 0, "sound": "grass"},
	2: {"name": "Tierra", "color": [0.55, 0.40, 0.25], "hardness": 0.5, "shape": "solid", "light": 0, "sound": "dirt"},
	3: {"name": "Piedra", "color": [0.50, 0.50, 0.52], "hardness": 1.5, "shape": "solid", "light": 0, "sound": "stone"},
	4: {"name": "Madera", "color": [0.45, 0.30, 0.15], "hardness": 1.2, "shape": "solid", "light": 0, "sound": "wood"},
	5: {"name": "Hojas", "color": [0.15, 0.55, 0.20], "hardness": 0.2, "shape": "solid", "light": 0, "sound": "foliage"},
	6: {"name": "Agua", "color": [0.20, 0.50, 0.90], "hardness": -1.0, "shape": "liquid", "light": 0, "sound": "water"},
	7: {"name": "Arena", "color": [0.85, 0.78, 0.55], "hardness": 0.45, "shape": "solid", "light": 0, "sound": "sand"},
	8: {"name": "Flor roja", "color": [0.90, 0.20, 0.30], "hardness": 0.1, "shape": "cross", "light": 0, "sound": "foliage"},
	9: {"name": "Flor amarilla", "color": [0.95, 0.85, 0.20], "hardness": 0.1, "shape": "cross", "light": 0, "sound": "foliage"},
	80: {"name": "Antorcha", "color": [1.0, 0.75, 0.25], "hardness": 0.3, "shape": "solid", "light": 14, "sound": "wood"},
	81: {"name": "Cofre", "color": [0.65, 0.45, 0.15], "hardness": 1.0, "shape": "solid", "light": 0, "sound": "wood"},
	82: {"name": "Portal", "color": [0.55, 0.20, 0.90], "hardness": -1.0, "shape": "solid", "light": 8, "sound": "crystal"},
	84: {"name": "Tablones", "color": [0.70, 0.50, 0.30], "hardness": 1.0, "shape": "solid", "light": 0, "sound": "wood"},
	85: {"name": "Ladrillo", "color": [0.75, 0.25, 0.20], "hardness": 1.6, "shape": "solid", "light": 0, "sound": "stone"},
	86: {"name": "Vidrio", "color": [0.65, 0.85, 0.95], "hardness": 0.3, "shape": "solid", "light": 0, "sound": "crystal"},
	87: {"name": "Nieve", "color": [0.95, 0.97, 1.0], "hardness": 0.4, "shape": "solid", "light": 0, "sound": "snow"},
	88: {"name": "Cristal brillo", "color": [0.20, 0.95, 1.0], "hardness": 0.8, "shape": "solid", "light": 11, "sound": "crystal"},
	# 4.0: bloques de luz nuevos (tambien en data/blocks.json).
	260: {"name": "Seta luminosa", "color": [0.45, 0.95, 0.55], "hardness": 0.3, "shape": "solid", "light": 10, "sound": "crystal"},
	261: {"name": "Cristal cian", "color": [0.275, 0.863, 1.0], "hardness": 0.8, "shape": "solid", "light": 12, "sound": "crystal"},
	262: {"name": "Cristal magenta", "color": [0.941, 0.314, 0.863], "hardness": 0.8, "shape": "solid", "light": 12, "sound": "crystal"},
}

var _data: Dictionary = {}


func _init() -> void:
	_data = load_catalog()


## Lee el JSON y devuelve id (int) -> ficha. Si algo falla,
## devuelve la tabla incrustada, nunca un diccionario vacío.
static func load_catalog() -> Dictionary:
	var out: Dictionary = FALLBACK.duplicate(true)
	if not FileAccess.file_exists(PATH):
		return out
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	var blocks: Array = parsed.get("blocks", [])
	if blocks.is_empty():
		return out
	var loaded: Dictionary = {}
	for entry in blocks:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			continue
		loaded[int(entry["id"])] = {
			"name": str(entry.get("name", "Bloque")),
			"color": entry.get("color", [0.8, 0.8, 0.8]),
			"hardness": float(entry.get("hardness", 1.0)),
			"shape": str(entry.get("shape", "solid")),
			"light": int(entry.get("light", 0)),
			"sound": str(entry.get("sound", "stone")),
		}
	if loaded.is_empty():
		return out
	return loaded


func entry_for(block_id: int) -> Dictionary:
	if _data.has(block_id):
		return _data[block_id]
	return {"name": "Bloque", "color": [0.8, 0.8, 0.8], "hardness": 1.0, "shape": "solid", "light": 0, "sound": "stone"}


func name_for(block_id: int) -> String:
	return str(entry_for(block_id)["name"])


func color_for(block_id: int) -> Color:
	var c: Array = entry_for(block_id)["color"]
	if c.size() < 3:
		return Color(0.8, 0.8, 0.8)
	return Color(float(c[0]), float(c[1]), float(c[2]))


func hardness_for(block_id: int) -> float:
	return float(entry_for(block_id)["hardness"])


func shape_for(block_id: int) -> String:
	return str(entry_for(block_id)["shape"])


func light_for(block_id: int) -> int:
	return int(entry_for(block_id)["light"])


func sound_for(block_id: int) -> String:
	return str(entry_for(block_id)["sound"])


func is_solid(block_id: int) -> bool:
	if block_id == 0:
		return false
	var shape := shape_for(block_id)
	return shape != "cross" and shape != "liquid" and shape != "none"


func all_ids() -> Array:
	return _data.keys()
