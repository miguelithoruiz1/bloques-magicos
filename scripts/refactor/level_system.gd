extends Node
## LevelSystem — niveles y EXP de la 3.0 (puro, testeable).
##
## Curva: subir del nivel N pide 20 + (N-1)*15 EXP.
## Fuentes (las conecta RefactorMain): colocar 1, palabra /
## suma / amigo / crafteo 10, misión 15. Sin castigos: la
## EXP nunca baja y el nivel nunca retrocede.
## Persistencia: user://bloques3_levels.json.

class_name LevelSystem

signal level_up(new_level: int)
signal exp_changed(level: int, exp: int, needed: int)

const SAVE_PATH := "user://bloques3_levels.json"

var level: int = 1
var exp: int = 0


static func exp_needed(level_value: int) -> int:
	return 20 + (level_value - 1) * 15


## Estaciones del documento de arquitectura, adaptadas: cada
## 5 días cambia la estación, en ciclo. Pura, para tests.
static func season_for_day(day: int) -> String:
	var seasons: Array[String] = ["Primavera", "Verano", "Otoño", "Invierno"]
	var index: int = ((day - 1) / 5) % seasons.size()
	if index < 0:
		index = 0
	return seasons[index]


## Zonas 1-6 del documento, por distancia al origen en
## bloques (el documento usa km; nuestro mundo usa radio
## 20-24, así que la escala se adapta: zona = distancia/20).
## Pura, para tests y para el HUD.
static func zone_for_distance(dist: float) -> int:
	if dist < 20.0:
		return 1
	if dist < 40.0:
		return 2
	if dist < 70.0:
		return 3
	if dist < 110.0:
		return 4
	if dist < 160.0:
		return 5
	return 6


func gain_exp(amount: int) -> void:
	if amount <= 0:
		return
	exp += amount
	var leveled: bool = false
	while exp >= exp_needed(level):
		exp -= exp_needed(level)
		level += 1
		leveled = true
	if leveled:
		level_up.emit(level)
	exp_changed.emit(level, exp, exp_needed(level))


func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"level": level, "exp": exp}))
		file.close()


func load() -> void:
	level = 1
	exp = 0
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if data is Dictionary:
		level = int((data as Dictionary).get("level", 1))
		exp = int((data as Dictionary).get("exp", 0))
		if level < 1:
			level = 1
		if exp < 0:
			exp = 0
