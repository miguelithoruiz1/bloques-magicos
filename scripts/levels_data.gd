extends RefCounted
## Tabla de niveles de la Fase 2 — diseño guiado por datos.
## 4 mundos × 10 niveles progresivos (1.11.0: de 5 a 10 por mundo).
## Cada nivel es un diccionario:
## {"titulo", "tipo", "params", "voz", "texto"}.
## Tipos de meta (ver level_logic.gd): poner_color, color_voz, arcoiris,
## contar, numero_pedido, ordenar, letra_voz, palabra, suma.
## Los tipos color_voz y letra_voz eligen su objetivo al azar al empezar
## el nivel (entre params["opciones"]); su voz/texto se completan entonces
## con instruccion_aleatoria(). El niño no necesita saber leer: la voz
## lee cada instrucción.
## "arcoiris" acepta params["secuencia"] (por defecto, el arcoíris
## clásico de 6 colores); el nivel 10 de Colores usa la secuencia de
## los 6 colores nuevos.

const MUNDOS: Array = [
	{"id": "colores", "nombre": "Colores", "emoji": "🌈"},
	{"id": "numeros", "nombre": "Números", "emoji": "🔢"},
	{"id": "letras", "nombre": "Letras", "emoji": "🔤"},
	{"id": "sumas", "nombre": "Sumas", "emoji": "➕"},
]

## Índices de color (igual que main.gd BLOCK_COLORS / palette_ui.gd).
## 1.11.0: 12 colores (los 6 de siempre + rosado, café, negro,
## blanco, gris y celeste).
const COLORES_NOMBRES: Array = ["Rojo", "Azul", "Amarillo", "Verde", "Naranja", "Morado", "Rosado", "Café", "Negro", "Blanco", "Gris", "Celeste"]
## Orden del arcoíris: Rojo, Naranja, Amarillo, Verde, Azul, Morado.
const ARCOIRIS: Array = [0, 4, 2, 3, 1, 5]
## Orden de los colores nuevos (nivel 10 de Colores).
const ARCOIRIS_NUEVOS: Array = [6, 7, 8, 9, 10, 11]
## Cubos con letras: abecedario completo del español, 27 letras.
const LETRAS: Array = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "Ñ", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
## Clip de audio familiar por letra (mismo orden que LETRAS).
## La ñ es "letra_nn" para no usar caracteres especiales en archivos.
const LETRAS_CLIPS: Array = ["letra_a", "letra_b", "letra_c", "letra_d", "letra_e", "letra_f", "letra_g", "letra_h", "letra_i", "letra_j", "letra_k", "letra_l", "letra_m", "letra_n", "letra_nn", "letra_o", "letra_p", "letra_q", "letra_r", "letra_s", "letra_t", "letra_u", "letra_v", "letra_w", "letra_x", "letra_y", "letra_z"]

## Palabras mágicas (1.11.0): al formarlas con cubos de letras en
## fila, el objeto aparece y suena su clip (si el clip no existe aún,
## el respaldo TTS + visual dice la palabra; jamás se sintetiza nada).
## "tipo" es el modelo que aparece: "corazon" para mamá/papá (un
## corazón grande con la palabra), el resto es el objeto nombrado.
const PALABRAS_MAGICAS: Array = [
	{"palabra": "MAMÁ", "letras": [12, 0, 12, 0], "clip": "palabra_mama", "tipo": "corazon"},
	{"palabra": "PAPÁ", "letras": [16, 0, 16, 0], "clip": "palabra_papa", "tipo": "corazon"},
	{"palabra": "GATO", "letras": [6, 0, 20, 15], "clip": "palabra_gato", "tipo": "gato"},
	{"palabra": "PERRO", "letras": [16, 4, 18, 18, 15], "clip": "palabra_perro", "tipo": "perro"},
	{"palabra": "SOL", "letras": [19, 15, 11], "clip": "palabra_sol", "tipo": "sol"},
	{"palabra": "LUNA", "letras": [11, 21, 13, 0], "clip": "palabra_luna", "tipo": "luna"},
	{"palabra": "CASA", "letras": [2, 0, 19, 0], "clip": "palabra_casa", "tipo": "casa"},
	{"palabra": "FLOR", "letras": [5, 11, 15, 18], "clip": "palabra_flor", "tipo": "flor"},
	{"palabra": "PEZ", "letras": [16, 4, 26], "clip": "palabra_pez", "tipo": "pez"},
	{"palabra": "OSO", "letras": [15, 19, 15], "clip": "palabra_oso", "tipo": "oso"},
]


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
				{"titulo": "Nivel 6", "tipo": "poner_color", "params": {"color": 6, "cantidad": 2}, "voz": "Pon 2 bloques rosados", "texto": "Pon 2 bloques rosados"},
				{"titulo": "Nivel 7", "tipo": "poner_color", "params": {"color": 11, "cantidad": 3}, "voz": "Pon 3 bloques celestes", "texto": "Pon 3 bloques celestes"},
				{"titulo": "Nivel 8", "tipo": "color_voz", "params": {"opciones": [6, 7, 8, 9, 10, 11]}, "voz": "", "texto": ""},
				{"titulo": "Nivel 9", "tipo": "poner_color", "params": {"color": 9, "cantidad": 4}, "voz": "Pon 4 bloques blancos", "texto": "Pon 4 bloques blancos"},
				{"titulo": "Nivel 10", "tipo": "arcoiris", "params": {"secuencia": [6, 7, 8, 9, 10, 11]}, "voz": "Pon los colores nuevos en orden: rosado, café, negro, blanco, gris y celeste", "texto": "Colores nuevos en orden: rosado, café, negro, blanco, gris, celeste"},
			]
		"numeros":
			return [
				{"titulo": "Nivel 1", "tipo": "contar", "params": {"cantidad": 3}, "voz": "Pon 3 bloques", "texto": "Pon 3 bloques"},
				{"titulo": "Nivel 2", "tipo": "contar", "params": {"cantidad": 6}, "voz": "Pon 6 bloques", "texto": "Pon 6 bloques"},
				{"titulo": "Nivel 3", "tipo": "numero_pedido", "params": {"numero": 4}, "voz": "Pon el cubo con el número 4", "texto": "Pon el cubo con el número 4"},
				{"titulo": "Nivel 4", "tipo": "numero_pedido", "params": {"numero": 2}, "voz": "Pon el cubo con el número 2", "texto": "Pon el cubo con el número 2"},
				{"titulo": "Nivel 5", "tipo": "ordenar", "params": {}, "voz": "Pon los números en orden: 1, 2, 3, 4, 5", "texto": "Números en orden: 1, 2, 3, 4, 5"},
				{"titulo": "Nivel 6", "tipo": "contar", "params": {"cantidad": 8}, "voz": "Pon 8 bloques", "texto": "Pon 8 bloques"},
				{"titulo": "Nivel 7", "tipo": "contar", "params": {"cantidad": 10}, "voz": "Pon 10 bloques", "texto": "Pon 10 bloques"},
				{"titulo": "Nivel 8", "tipo": "numero_pedido", "params": {"numero": 1}, "voz": "Pon el cubo con el número 1", "texto": "Pon el cubo con el número 1"},
				{"titulo": "Nivel 9", "tipo": "numero_pedido", "params": {"numero": 3}, "voz": "Pon el cubo con el número 3", "texto": "Pon el cubo con el número 3"},
				{"titulo": "Nivel 10", "tipo": "numero_pedido", "params": {"numero": 5}, "voz": "Pon el cubo con el número 5", "texto": "Pon el cubo con el número 5"},
			]
		"letras":
			return [
				{"titulo": "Nivel 1", "tipo": "letra_voz", "params": {"opciones": [0, 4, 8, 15, 21]}, "voz": "", "texto": ""},
				{"titulo": "Nivel 2", "tipo": "palabra", "params": {"letras": [12, 0, 12, 0]}, "voz": "Forma la palabra mamá", "texto": "Forma la palabra MAMÁ"},
				{"titulo": "Nivel 3", "tipo": "palabra", "params": {"letras": [16, 0, 16, 0]}, "voz": "Forma la palabra papá", "texto": "Forma la palabra PAPÁ"},
				{"titulo": "Nivel 4", "tipo": "palabra", "params": {"letras": [19, 15, 11]}, "voz": "Forma la palabra sol", "texto": "Forma la palabra SOL"},
				{"titulo": "Nivel 5", "tipo": "palabra", "params": {"letras": [11, 21, 13, 0]}, "voz": "Forma la palabra luna", "texto": "Forma la palabra LUNA"},
				{"titulo": "Nivel 6", "tipo": "palabra", "params": {"letras": [6, 0, 20, 15]}, "voz": "Forma la palabra gato", "texto": "Forma la palabra GATO"},
				{"titulo": "Nivel 7", "tipo": "palabra", "params": {"letras": [16, 4, 18, 18, 15]}, "voz": "Forma la palabra perro", "texto": "Forma la palabra PERRO"},
				{"titulo": "Nivel 8", "tipo": "palabra", "params": {"letras": [2, 0, 19, 0]}, "voz": "Forma la palabra casa", "texto": "Forma la palabra CASA"},
				{"titulo": "Nivel 9", "tipo": "palabra", "params": {"letras": [5, 11, 15, 18]}, "voz": "Forma la palabra flor", "texto": "Forma la palabra FLOR"},
				{"titulo": "Nivel 10", "tipo": "palabra", "params": {"letras": [15, 19, 15]}, "voz": "Forma la palabra oso", "texto": "Forma la palabra OSO"},
			]
		"sumas":
			return [
				{"titulo": "Nivel 1", "tipo": "suma", "params": {"a": 1, "b": 1, "resultado": 2}, "voz": "¿Cuánto es 1 más 1? Pon esa cantidad de bloques", "texto": "1 + 1 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 2", "tipo": "suma", "params": {"a": 2, "b": 1, "resultado": 3}, "voz": "¿Cuánto es 2 más 1? Pon esa cantidad de bloques", "texto": "2 + 1 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 3", "tipo": "suma", "params": {"a": 3, "b": 2, "resultado": 5}, "voz": "¿Cuánto es 3 más 2? Pon esa cantidad de bloques", "texto": "3 + 2 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 4", "tipo": "suma", "params": {"a": 4, "b": 3, "resultado": 7}, "voz": "¿Cuánto es 4 más 3? Pon esa cantidad de bloques", "texto": "4 + 3 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 5", "tipo": "suma", "params": {"a": 5, "b": 5, "resultado": 10}, "voz": "¿Cuánto es 5 más 5? Pon esa cantidad de bloques", "texto": "5 + 5 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 6", "tipo": "suma", "params": {"a": 2, "b": 2, "resultado": 4}, "voz": "¿Cuánto es 2 más 2? Pon esa cantidad de bloques", "texto": "2 + 2 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 7", "tipo": "suma", "params": {"a": 3, "b": 3, "resultado": 6}, "voz": "¿Cuánto es 3 más 3? Pon esa cantidad de bloques", "texto": "3 + 3 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 8", "tipo": "suma", "params": {"a": 4, "b": 4, "resultado": 8}, "voz": "¿Cuánto es 4 más 4? Pon esa cantidad de bloques", "texto": "4 + 4 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 9", "tipo": "suma", "params": {"a": 5, "b": 4, "resultado": 9}, "voz": "¿Cuánto es 5 más 4? Pon esa cantidad de bloques", "texto": "5 + 4 = ?  ·  Pon esa cantidad de bloques"},
				{"titulo": "Nivel 10", "tipo": "suma", "params": {"a": 6, "b": 4, "resultado": 10}, "voz": "¿Cuánto es 6 más 4? Pon esa cantidad de bloques", "texto": "6 + 4 = ?  ·  Pon esa cantidad de bloques"},
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
