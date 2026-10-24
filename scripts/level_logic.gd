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
			return _contiene(_secuencia(colocados, "color"), [0, 4, 2, 3, 1, 5])
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
