extends RefCounted
## Verificación pura de metas de nivel (sin nodos, testeable en headless).
## "colocados" es la lista de bloques puestos DURANTE el nivel, en orden:
## [{"tipo": "color"|"numero"|"letra", "dato": int}, ...].
## "objetivo" solo se usa en los tipos con objetivo al azar (-1 si no aplica).
## Las secuencias (arcoíris, ordenar, palabra) se buscan como subsecuencia
## contigua dentro de lo colocado: un bloque de más antes no bloquea el
## nivel, y borrar corrige (la lista se actualiza al quitar).

static func check_goal(tipo: String, params: Dictionary, objetivo: int, colocados: Array) -> bool:
	match tipo:
		"poner_color":
			return _contar(colocados, "color", int(params.get("color", 0))) >= int(params.get("cantidad", 1))
		"color_voz":
			if objetivo < 0:
				return false
			return _contar(colocados, "color", objetivo) >= 1
		"arcoiris":
			var secuencia: Array = params.get("secuencia", [0, 4, 2, 3, 1, 5])
			return _contiene(_secuencia(colocados, "color"), secuencia)
		"contar":
			return colocados.size() >= int(params.get("cantidad", 1))
		"numero_pedido":
			return _contar(colocados, "numero", int(params.get("numero", 1))) >= 1
		"ordenar":
			return _contiene(_secuencia(colocados, "numero"), [1, 2, 3, 4, 5])
		"letra_voz":
			if objetivo < 0:
				return false
			return _contar(colocados, "letra", objetivo) >= 1
		"palabra":
			var esperadas: Array = params.get("letras", [])
			return _contiene(_secuencia(colocados, "letra"), esperadas)
		"suma":
			return colocados.size() == int(params.get("resultado", 0))
	return false


## Palabras mágicas (1.11.0, pura y testeable en headless).
## "run" es la fila de cubos con letras en orden (un eje, mismo nivel),
## "pos" es el índice del cubo recién colocado dentro de esa fila y
## "palabras" es LevelsData.PALABRAS_MAGICAS (cada una con "letras").
## Devuelve el índice de la palabra formada o -1.
## La palabra debe TERMINAR justo en el cubo nuevo: al construir de
## izquierda a derecha, el segmento que termina en "pos" es la palabra;
## al construir de derecha a izquierda, el segmento que empieza en
## "pos", leído al revés, es la palabra. Así poner otra letra después
## (p. ej. GATOO) no vuelve a disparar la magia.
static func magic_word_in_run(run: Array, pos: int, palabras: Array) -> int:
	if pos < 0 or pos >= run.size():
		return -1
	for wi in range(palabras.size()):
		var esperadas: Array = palabras[wi].get("letras", [])
		var n := esperadas.size()
		if n == 0:
			continue
		# Hacia adelante: la palabra termina en el cubo nuevo.
		if pos - n + 1 >= 0:
			var ok := true
			for i in range(n):
				if int(run[pos - n + 1 + i]) != int(esperadas[i]):
					ok = false
					break
			if ok:
				return wi
		# Hacia atrás: la palabra empieza en el cubo nuevo (lectura
		# de derecha a izquierda).
		if pos + n - 1 < run.size():
			var ok2 := true
			for i in range(n):
				if int(run[pos + i]) != int(esperadas[n - 1 - i]):
					ok2 = false
					break
			if ok2:
				return wi
	return -1


static func _contar(colocados: Array, tipo: String, dato: int) -> int:
	var n := 0
	for c in colocados:
		if String(c.get("tipo", "")) == tipo and int(c.get("dato", -1)) == dato:
			n += 1
	return n


static func _secuencia(colocados: Array, tipo: String) -> Array:
	var seq: Array = []
	for c in colocados:
		if String(c.get("tipo", "")) == tipo:
			seq.append(int(c.get("dato", 0)))
	return seq


## ¿Aparece "esperada" como bloque contiguo dentro de "seq"?
static func _contiene(seq: Array, esperada: Array) -> bool:
	if esperada.is_empty() or seq.size() < esperada.size():
		return false
	for inicio in range(seq.size() - esperada.size() + 1):
		var ok := true
		for i in range(esperada.size()):
			if int(seq[inicio + i]) != int(esperada[i]):
				ok = false
				break
		if ok:
			return true
	return false
