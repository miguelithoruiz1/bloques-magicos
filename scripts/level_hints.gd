extends RefCounted
## Pistas visuales 1.6 (MVP1): solo muestran, nunca cambian la meta.
## Cada pista es un diccionario {"x": int, "z": int, "color": Color,
## "texto": String, "kind": String}. "kind" puede ser "pista" (casilla
## a rellenar), "sumando" (bloque ya puesto de ejemplo, no contable)
## o "puente" (hueco a cerrar hacia la estrella).
## Las celdas son SUGERENCIA: la meta sigue contando lo colocado en
## orden (level_logic.gd), ponga el niño el bloque encima de la pista
## o en cualquier otra celda. Por eso las pistas nunca entran en el
## diccionario de bloques, nunca se guardan y nunca bloquean el paseo
## (la colisión del avatar solo mira blocks).
## Testeable en headless sin escena: items_for_level() es pura.

const LevelsData := preload("res://scripts/levels_data.gd")

const COLORS: Array = [
	Color(0.90, 0.25, 0.22),
	Color(0.20, 0.45, 0.95),
	Color(0.98, 0.80, 0.15),
	Color(0.30, 0.75, 0.35),
	Color(0.98, 0.55, 0.15),
	Color(0.60, 0.35, 0.90),
]
const NUMBER_TILE_COLOR := Color(1.0, 0.95, 0.78)
const SUMANDO_COLOR := Color(0.20, 0.45, 0.95)
const PUENTE_COLOR := Color(0.98, 0.80, 0.15)


## Fila horizontal centrada en x=8, en la fila z dada.
static func _fila(z: int, count: int) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var start_x := 8 - count / 2
	for i in range(count):
		out.append(Vector2i(start_x + i, z))
	return out


static func _item(cell: Vector2i, color: Color, texto := "", kind := "pista") -> Dictionary:
	return {"x": int(cell.x), "z": int(cell.y), "color": color, "texto": texto, "kind": kind}


static func items_for_level(tipo: String, params: Dictionary, objetivo: int) -> Array:
	var out: Array = []
	match tipo:
		"poner_color":
			var color := int(params.get("color", 0))
			var cantidad := int(params.get("cantidad", 1))
			for cell in _fila(8, cantidad):
				out.append(_item(cell, COLORS[clampi(color, 0, COLORS.size() - 1)]))
		"color_voz":
			if objetivo >= 0 and objetivo < COLORS.size():
				out.append(_item(Vector2i(8, 8), COLORS[objetivo]))
		"arcoiris":
			var orden: Array = [0, 4, 2, 3, 1, 5]
			var cells := _fila(8, orden.size())
			for i in range(orden.size()):
				out.append(_item(cells[i], COLORS[int(orden[i])]))
		"contar":
			var cantidad := int(params.get("cantidad", 1))
			var cells := _fila(8, cantidad)
			for i in range(cells.size()):
				out.append(_item(cells[i], NUMBER_TILE_COLOR, str(i + 1)))
		"numero_pedido":
			var numero := int(params.get("numero", 1))
			out.append(_item(Vector2i(8, 8), NUMBER_TILE_COLOR, str(numero)))
		"ordenar":
			var cells := _fila(8, 5)
			for i in range(cells.size()):
				out.append(_item(cells[i], NUMBER_TILE_COLOR, str(i + 1)))
		"letra_voz":
			if objetivo >= 0 and objetivo < LevelsData.LETRAS.size():
				out.append(_item(Vector2i(8, 8), Color(0.62, 0.85, 1.0), String(LevelsData.LETRAS[objetivo])))
		"palabra":
			var letras: Array = params.get("letras", [])
			var cells := _fila(8, letras.size())
			for i in range(letras.size()):
				var li := int(letras[i])
				if li >= 0 and li < LevelsData.LETRAS.size():
					out.append(_item(cells[i], Color(0.62, 0.85, 1.0), String(LevelsData.LETRAS[li])))
		"suma":
			var a := int(params.get("a", 0))
			var b := int(params.get("b", 0))
			var resultado := int(params.get("resultado", 0))
			for i in range(a):
				out.append(_item(Vector2i(3 + i, 5), SUMANDO_COLOR, "", "sumando"))
			for i in range(b):
				out.append(_item(Vector2i(3 + i, 10), SUMANDO_COLOR, "", "sumando"))
			for cell in _fila(8, resultado):
				out.append(_item(cell, PUENTE_COLOR, "", "puente"))
	return out
