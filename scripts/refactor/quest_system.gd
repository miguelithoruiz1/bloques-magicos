extends Node
## QuestSystem — 20 misiones «Aventuras para empezar» (3.0).
##
## Textos propios, no copiados de ningún otro juego. Sin
## castigos: una misión sin completar simplemente sigue
## abierta; completar da 1 estrella + 15 EXP (lo entrega
## RefactorMain al escuchar quest_completed).
## Persistencia: user://bloques3_quests.json (JSON, no binario).
##
## Ganchos que llama RefactorMain (nada de esto lee input):
##   on_place(block_id) · on_friend() · on_word()
##   on_math() · on_craft() · on_move(dist_del_inicio)
##   on_height(y) · on_torch_night() · on_level(level)

class_name QuestSystem

signal quest_completed(quest_id: String, title: String)
signal progress_changed

const SAVE_PATH := "user://bloques3_quests.json"
const STAR_EXP := 15

# kind: place (suma), distance/height/level (máximo),
# colors_kinds / letters_kinds (distintos), resto (suma).
const QUESTS: Array[Dictionary] = [
	{"id": "primeros", "title": "Primeros bloques", "desc": "Pon 3 bloques.", "target": 3, "kind": "place"},
	{"id": "amigo", "title": "Un amigo nuevo", "desc": "Hazte amigo de 1 animal.", "target": 1, "kind": "friend"},
	{"id": "palabra", "title": "Palabra mágica", "desc": "Forma 1 palabra con letras.", "target": 1, "kind": "word"},
	{"id": "suma", "title": "Cuenta conmigo", "desc": "Resuelve 1 suma con bloques.", "target": 1, "kind": "math"},
	{"id": "explorador", "title": "Explorador", "desc": "Aléjate 30 bloques del inicio.", "target": 30, "kind": "distance"},
	{"id": "arquitecto", "title": "Pequeño arquitecto", "desc": "Pon 10 bloques de Construcción.", "target": 10, "kind": "build"},
	{"id": "altura", "title": "En lo más alto", "desc": "Sube a 12 bloques de altura.", "target": 12, "kind": "height"},
	{"id": "antorcha", "title": "Noche de antorchas", "desc": "Pon 1 antorcha de noche.", "target": 1, "kind": "torch_night"},
	{"id": "taller", "title": "Manos a la obra", "desc": "Fabrica 1 cosa en el Taller.", "target": 1, "kind": "craft"},
	{"id": "arcoiris", "title": "Arcoíris", "desc": "Pon bloques de 5 colores distintos.", "target": 5, "kind": "colors_kinds"},
	{"id": "diez", "title": "Cuenta hasta diez", "desc": "Pon 10 bloques de números.", "target": 10, "kind": "number_blocks"},
	{"id": "letras", "title": "Letras viajeras", "desc": "Pon bloques de 5 letras distintas.", "target": 5, "kind": "letters_kinds"},
	{"id": "doble", "title": "Doble creación", "desc": "Fabrica 2 cosas en el Taller.", "target": 2, "kind": "craft"},
	{"id": "manada", "title": "Manada de amigos", "desc": "Hazte amigo de 3 animales.", "target": 3, "kind": "friend"},
	{"id": "gran_constructor", "title": "Gran constructor", "desc": "Pon 50 bloques en total.", "target": 50, "kind": "place"},
	{"id": "gran_viajero", "title": "Gran viajero", "desc": "Aléjate 100 bloques del inicio.", "target": 100, "kind": "distance"},
	{"id": "segunda_palabra", "title": "Segunda palabra", "desc": "Forma 2 palabras con letras.", "target": 2, "kind": "word"},
	{"id": "matematico", "title": "Matemático", "desc": "Resuelve 3 sumas con bloques.", "target": 3, "kind": "math"},
	{"id": "noche_estrellada", "title": "Noche estrellada", "desc": "Pon 5 antorchas de noche.", "target": 5, "kind": "torch_night"},
	{"id": "leyenda", "title": "Leyenda", "desc": "Alcanza el nivel 5.", "target": 5, "kind": "level"},
]

var _progress: Dictionary = {}
var _done: Dictionary = {}
var _colors: Dictionary = {}
var _letters: Dictionary = {}


func _quest(quest_id: String) -> Dictionary:
	for q in QUESTS:
		if str(q["id"]) == quest_id:
			return q
	return {}


func _add(quest_id: String, amount: int, absolute: bool = false) -> void:
	if bool(_done.get(quest_id, false)):
		return
	var cur: int = int(_progress.get(quest_id, 0))
	if absolute:
		cur = maxi(cur, amount)
	else:
		cur += amount
	_progress[quest_id] = cur
	var q: Dictionary = _quest(quest_id)
	if q.is_empty():
		return
	if cur >= int(q["target"]):
		_done[quest_id] = true
		quest_completed.emit(quest_id, str(q["title"]))
	progress_changed.emit()


func progress_of(quest_id: String) -> int:
	return int(_progress.get(quest_id, 0))


func is_done(quest_id: String) -> bool:
	return bool(_done.get(quest_id, false))


func stars() -> int:
	var count: int = 0
	for quest_id in _done.keys():
		if bool(_done[quest_id]):
			count += 1
	return count


func on_place(block_id: int) -> void:
	_add("primeros", 1)
	_add("gran_constructor", 1)
	if block_id >= 84 and block_id <= 88:
		_add("arquitecto", 1)
	if block_id >= 10 and block_id <= 21:
		if not _colors.has(block_id):
			_colors[block_id] = true
			_add("arcoiris", 1)
	if block_id >= 30 and block_id <= 39:
		_add("diez", 1)
	if block_id >= 50 and block_id <= 76:
		if not _letters.has(block_id):
			_letters[block_id] = true
			_add("letras", 1)


func on_friend() -> void:
	_add("amigo", 1)
	_add("manada", 1)


func on_word() -> void:
	_add("palabra", 1)
	_add("segunda_palabra", 1)


func on_math() -> void:
	_add("suma", 1)
	_add("matematico", 1)


func on_craft() -> void:
	_add("taller", 1)
	_add("doble", 1)


func on_move(dist_from_spawn: float) -> void:
	_add("explorador", int(dist_from_spawn), true)
	_add("gran_viajero", int(dist_from_spawn), true)


func on_height(y: float) -> void:
	_add("altura", int(y), true)


func on_torch_night() -> void:
	_add("antorcha", 1)
	_add("noche_estrellada", 1)


func on_level(level: int) -> void:
	_add("leyenda", level, true)


func save() -> void:
	var colors: Array[int] = []
	for key in _colors.keys():
		colors.append(int(key))
	var letters: Array[int] = []
	for key in _letters.keys():
		letters.append(int(key))
	var data: Dictionary = {
		"progress": _progress, "done": _done,
		"colors": colors, "letters": letters,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()


func load() -> void:
	_progress.clear()
	_done.clear()
	_colors.clear()
	_letters.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (data is Dictionary):
		return
	var d: Dictionary = data
	if d.get("progress") is Dictionary:
		_progress = (d["progress"] as Dictionary).duplicate()
	if d.get("done") is Dictionary:
		_done = (d["done"] as Dictionary).duplicate()
	if d.get("colors") is Array:
		for c in (d["colors"] as Array):
			_colors[int(c)] = true
	if d.get("letters") is Array:
		for c in (d["letters"] as Array):
			_letters[int(c)] = true
