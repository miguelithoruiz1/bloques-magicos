extends RefCounted
## AvatarCustom — sombrero y color de camiseta del jugador.
##
## El plan de Cube Unbound proponía 3-4 sombreros de MagicaVoxel
## y color de camiseta con botones grandes, guardado en
## user://avatar.json. Aquí los sombreros son procedurales
## (cajas propias, no modelos ajenos): Explorador, Caballero,
## Astronauta y Rana. El archivo es propio de 2.0 y no toca
## settings_refactor.cfg ni los ajustes de 1.15.0.

class_name AvatarCustom

const PATH := "user://avatar.json"
const HATS := ["explorador", "caballero", "astronauta", "rana"]
const HAT_LABELS := ["Explorador", "Caballero", "Astronauta", "Rana"]
const HAT_COLORS := {
	"explorador": Color(0.55, 0.35, 0.20),
	"caballero": Color(0.55, 0.55, 0.58),
	"astronauta": Color(0.95, 0.95, 0.95),
	"rana": Color(0.20, 0.70, 0.25),
}
const SHIRTS := ["azul", "rojo", "verde", "amarillo"]
const SHIRT_COLORS := {
	"azul": Color(0.20, 0.45, 0.90),
	"rojo": Color(0.85, 0.15, 0.15),
	"verde": Color(0.20, 0.70, 0.25),
	"amarillo": Color(0.95, 0.80, 0.15),
}


## Normaliza un diccionario cualquiera a un avatar válido.
## Sombrero o camiseta desconocidos caen al default, nunca a
## un error: un niño no debe ver fallos por un archivo viejo.
static func decode(data: Dictionary) -> Dictionary:
	var hat := str(data.get("hat", "explorador"))
	if hat not in HATS:
		hat = "explorador"
	var shirt := str(data.get("shirt", "azul"))
	if shirt not in SHIRTS:
		shirt = "azul"
	return {"hat": hat, "shirt": shirt}


static func encode(hat: String, shirt: String) -> Dictionary:
	return decode({"hat": hat, "shirt": shirt})


static func hat_color(hat: String) -> Color:
	if HAT_COLORS.has(hat):
		return HAT_COLORS[hat]
	return HAT_COLORS["explorador"]


static func shirt_color(shirt: String) -> Color:
	if SHIRT_COLORS.has(shirt):
		return SHIRT_COLORS[shirt]
	return SHIRT_COLORS["azul"]


static func load_avatar() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {"hat": "explorador", "shirt": "azul"}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {"hat": "explorador", "shirt": "azul"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"hat": "explorador", "shirt": "azul"}
	return decode(parsed)


static func save_avatar(hat: String, shirt: String) -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(encode(hat, shirt)))
	file.close()
	return true
