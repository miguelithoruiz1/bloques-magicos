extends RefCounted
## SpacedRepetitionManager — prioriza lo que costó, sin castigos.
##
## Cada ítem (una letra, un número o una suma, p. ej. "letra_S",
## "suma_4+3") guarda aciertos y fallos. La prioridad de un ítem
## es: fallos recientes pesan más que aciertos viejos. La fórmula
## es deliberadamente simple y auditable (no una caja negra):
##   prioridad = fallos * 3 - aciertos + (1 si falló la última vez)
## Los retos de cuevas/cofres piden primero los ítems de mayor
## prioridad. Un fallo NUNCA bloquea ni resta puntos: solo sube
## la prioridad del ítem para que vuelva a aparecer con una pista.
## Persistencia: user://spaced_repetition.json (propio de la
## variante; no toca progreso.json de 1.15.0).

class_name SpacedRepetitionManager

const PATH := "user://spaced_repetition.json"

var _stats: Dictionary = {} # item -> {"hit": int, "miss": int, "last_miss": bool}


func _init() -> void:
	load_from_disk()


func load_from_disk() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_stats = parsed


func save_to_disk() -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_stats))
	file.close()
	return true


func record_hit(item: String) -> void:
	var s := _ensure(item)
	s["hit"] = int(s["hit"]) + 1
	s["last_miss"] = false
	save_to_disk()


func record_miss(item: String) -> void:
	var s := _ensure(item)
	s["miss"] = int(s["miss"]) + 1
	s["last_miss"] = true
	save_to_disk()


func _ensure(item: String) -> Dictionary:
	if not _stats.has(item):
		_stats[item] = {"hit": 0, "miss": 0, "last_miss": false}
	return _stats[item]


static func priority_of(stats: Dictionary) -> int:
	return int(stats.get("miss", 0)) * 3 - int(stats.get("hit", 0)) + (1 if bool(stats.get("last_miss", false)) else 0)


func priority(item: String) -> int:
	return priority_of(_ensure(item))


## Ordena los candidatos por prioridad descendente (los que más
## costaron, primero). Empate: orden alfabético, determinista.
func pick_next(candidates: Array) -> Array:
	var scored: Array = []
	for item in candidates:
		var s := _ensure(str(item))
		scored.append({"item": str(item), "p": priority_of(s)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["p"] != b["p"]:
			return a["p"] > b["p"]
		return str(a["item"]) < str(b["item"]))
	var out: Array = []
	for entry in scored:
		out.append(entry["item"])
	return out
