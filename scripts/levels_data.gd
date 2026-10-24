extends RefCounted
## Tabla de niveles de la Fase 2 — diseño guiado por datos.
## 4 mundos × 5 niveles progresivos. Cada nivel es un diccionario:
## {"titulo", "tipo", "params", "voz", "texto"}.
## Tipos de meta (ver level_logic.gd): poner_color, color_voz, arcoiris,
## contar, numero_pedido, ordenar, letra_voz, palabra, suma.
## Los tipos color_voz y letra_voz eligen su objetivo al azar al empezar
## el nivel (entre params["opciones"]); su voz/texto se completan entonces
## con instruccion_aleatoria(). El niño no necesita saber leer: la voz
## lee cada instrucción.

const MUNDOS: Array = [
	{"id": "colores", "nombre": "Colores", "emoji": "🌈"},
	{"id": "numeros", "nombre": "Números", "emoji": "🔢"},
	{"id": "letras", "nombre": "Letras", "emoji": "🔤"},
	{"id": "sumas", "nombre": "Sumas", "emoji": "➕"},
]

## Índices de color (igual que main.gd BLOCK_COLORS / palette_ui.gd).
const COLORES_NOMBRES: Array = ["Rojo", "Azul", "Amarillo", "Verde", "Naranja", "Morado"]
## Orden del arcoíris: Rojo, Naranja, Amarillo, Verde, Azul, Morado.
const ARCOIRIS: Array = [0, 4, 2, 3, 1, 5]
## Cubos con letras: vocales + M, P, S, T, L, N.
const LETRAS: Array = ["A", "E", "I", "O", "U", "M", "P", "S", "T", "L", "N"]


static func get_mundo(mundo_id: String) -> Dictionary:
	for m in MUNDOS:
		if String(m["id"]) == mundo_id:
			return m
	return {}


static func get_niveles(mundo_id: String) -> Array:
	match mundo_id:
		"colores":
			return [
				{"titulo": "Nivel 1", "tipo": "poner_color", "params": {"color": 0, "cantidad": 2}, "voz": "Pon 2 bloques rojos", "texto": "Pon 2 bloques rojos"},
				{"titulo": "Nivel 2", "tipo": "poner_color", "params": {"color": 1, "cantidad": 3}, "voz": "Pon 3 bloques azules", "texto": "Pon 3 bloques azules"},
				{"titulo": "Nivel 3", "tipo": "color_voz", "params": {"opciones": [0, 1, 2, 3, 4, 5]}, "voz": "", "texto": ""},
				{"titulo": "Nivel 4", "tipo": "poner_color", "params": {"color": 2, "cantidad": 4}, "voz": "Pon 4 bloques amarillos", "texto": "Pon 4 bloques amarillos"},
				{"titulo": "Nivel 5", "tipo": "arcoiris", "params": {}, "voz": "Pon el arcoíris en orden: rojo, naranja, amarillo, verde, azul y morado", "texto": "Arcoíris en orden: rojo, naranja, amarillo, verde, azul, morado"},
			]
		"numeros":
			return [
				{"titulo": "Nivel 1", "tipo": "contar", "params": {"cantidad": 3}, "voz": "Pon 3 bloques", "texto": "Pon 3 bloques"},
				{"titulo": "Nivel 2", "tipo": "contar", "params": {"cantidad": 6}, "voz": "Pon 6 bloques", "texto": "Pon 6 bloques"},
				{"titulo": "Nivel 3", "tipo": "numero_pedido", "params": {"numero": 4}, "voz": "Pon el cubo con el número 4", "texto": "Pon el cubo con el número 4"},
				{"titulo": "Nivel 4", "tipo": "numero_pedido", "params": {"numero": 2}, "voz": "Pon el cubo con el número 2", "texto": "Pon el cubo con el número 2"},
				{"titulo": "Nivel 5", "tipo": "ordenar", "params": {}, "voz": "Pon los números en orden: 1, 2, 3, 4, 5", "texto": "Números en orden: 1, 2, 3, 4, 5"},
			]
		"letras":
			return [
				{"titulo": "Nivel 1", "tipo": "letra_voz", "params": {"opciones": [0, 1, 2, 3, 4]}, "voz": "", "texto": ""},
				{"titulo": "Nivel 2", "tipo": "palabra", "params": {"letras": [5, 0, 5, 0]}, "voz": "Forma la palabra mamá", "texto": "Forma la palabra MAMÁ"},
				{"titulo": "Nivel 3", "tipo": "palabra", "params": {"letras": [6, 0, 6, 0]}, "voz": "Forma la palabra papá", "texto": "Forma la palabra PAPÁ"},
				{"titulo": "Nivel 4", "tipo": "palabra", "params": {"letras": [7, 3, 9]}, "voz": "Forma la palabra sol", "texto": "Forma la palabra SOL"},
				{"titulo": "Nivel 5", "tipo": "palabra", "params": {"letras": [9, 4, 10, 0]}, "voz": "Forma la palabra luna", "texto": "Forma la palabra LUNA"},
			]
		"sumas":
			return [
				{"titulo": "Nivel 1", "tipo": "suma", "params": {"a": 1, "b": 1, "resultado": 2}, "voz": "¿Cuánto es 1 más 1? Pon esa cantidad de bloques", "texto": "1 + 1 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 2", "tipo": "suma", "params": {"a": 2, "b": 1, "resultado": 3}, "voz": "¿Cuánto es 2 más 1? Pon esa cantidad de bloques", "texto": "2 + 1 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 3", "tipo": "suma", "params": {"a": 3, "b": 2, "resultado": 5}, "voz": "¿Cuánto es 3 más 2? Pon esa cantidad de bloques", "texto": "3 + 2 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 4", "tipo": "suma", "params": {"a": 4, "b": 3, "resultado": 7}, "voz": "¿Cuánto es 4 más 3? Pon esa cantidad de bloques", "texto": "4 + 3 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 5", "tipo": "suma", "params": {"a": 5, "b": 5, "resultado": 10}, "voz": "¿Cuánto es 5 más 5? Pon esa cantidad de bloques", "texto": "5 + 5 = ?  ·  Pon esa cantidad de bloques"},
			]
	return []


static func get_nivel(mundo_id: String, indice: int) -> Dictionary:
	var niveles := get_niveles(mundo_id)
	if indice < 0 or indice >= niveles.size():
		return {}
	return niveles[indice]


## Texto de la instrucción cuando el objetivo se eligió al azar.
static func instruccion_aleatoria(tipo: String, objetivo: int) -> Dictionary:
	match tipo:
		"color_voz":
			if objetivo < 0 or objetivo >= COLORES_NOMBRES.size():
				return {"voz": "", "texto": ""}
			var nombre := String(COLORES_NOMBRES[objetivo])
			return {"voz": "Pon un bloque " + nombre.to_lower(), "texto": "Pon un bloque " + nombre}
		"letra_voz":
			if objetivo < 0 or objetivo >= LETRAS.size():
				return {"voz": "", "texto": ""}
			var letra := String(LETRAS[objetivo])
			return {"voz": "Pon la letra " + letra, "texto": "Pon la letra " + letra}
	return {"voz": "", "texto": ""}
