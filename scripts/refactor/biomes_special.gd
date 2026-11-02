extends RefCounted
## BiomesSpecial — los 26 biomas especiales por anillo (3.0).
##
## El documento de arquitectura los define por ANILLOS de
## distancia (Zonas 1-6) con niveles de peligro, sin darles
## nombre uno a uno en el texto: los nombres de esta tabla
## son NUESTROS, siguiendo el vocabulario del documento
## (cristal, setas, glaciar, volcán, magma, vacío, celestial,
## corrupto). No se presentan como citas del documento.
## Adaptación multiedad: el «peligro» del documento entra
## como zona de reto (ver LevelSystem.zone_for_distance),
## sin enemigos: a más zona, retos de aprendizaje más duros.
##
## Cada especial es DATOS: base/amplitud/montaña para el
## relieve, bloque de superficie y tipo de decoración. La
## decoración reutiliza los patrones del generador (palma,
## pino, seta brillo, cactus, árbol/flor genérico, ninguna).

class_name BiomesSpecial

# key, nombre, zona, base, amplitud, montaña, superficie, decor.
const SPECIALS: Array[Dictionary] = [
	{"key": "valle_tranquilo", "name": "Valle Tranquilo", "zone": 1, "base": 2.0, "amp": 2.0, "mountain": false, "surface": 1, "decor": "flor"},
	{"key": "bosque_luciernagas", "name": "Bosque de Luciérnagas", "zone": 1, "base": 3.0, "amp": 2.0, "mountain": false, "surface": 1, "decor": "seta_brillo"},
	{"key": "colinas_cristal", "name": "Colinas de Cristal", "zone": 2, "base": 2.0, "amp": 3.0, "mountain": false, "surface": 1, "decor": "seta_brillo"},
	{"key": "pantano_luminoso", "name": "Pantano Luminoso", "zone": 2, "base": 2.0, "amp": 1.0, "mountain": false, "surface": 2, "decor": "flor"},
	{"key": "desierto_sal", "name": "Desierto de Sal", "zone": 2, "base": 1.0, "amp": 1.0, "mountain": false, "surface": 87, "decor": "ninguna"},
	{"key": "bosque_otonal", "name": "Bosque Otoñal", "zone": 2, "base": 3.0, "amp": 2.0, "mountain": false, "surface": 1, "decor": "roble"},
	{"key": "montanas_cobre", "name": "Montañas de Cobre", "zone": 3, "base": 2.0, "amp": 4.0, "mountain": true, "surface": 3, "decor": "pino"},
	{"key": "selva_bambu", "name": "Selva de Bambú", "zone": 3, "base": 3.0, "amp": 2.0, "mountain": false, "surface": 1, "decor": "palma"},
	{"key": "tundra_azul", "name": "Tundra Azul", "zone": 3, "base": 2.0, "amp": 2.0, "mountain": false, "surface": 87, "decor": "pino"},
	{"key": "meseta_roja", "name": "Meseta Roja", "zone": 3, "base": 3.0, "amp": 3.0, "mountain": false, "surface": 85, "decor": "cactus"},
	{"key": "llanura_girasoles", "name": "Llanura de Girasoles", "zone": 3, "base": 2.0, "amp": 1.0, "mountain": false, "surface": 1, "decor": "flor"},
	{"key": "tierras_cristal", "name": "Tierras de Cristal", "zone": 4, "base": 2.0, "amp": 3.0, "mountain": false, "surface": 1, "decor": "seta_brillo"},
	{"key": "bosque_setas", "name": "Bosque de Setas Gigantes", "zone": 4, "base": 3.0, "amp": 3.0, "mountain": false, "surface": 1, "decor": "seta_brillo"},
	{"key": "glaciar_eterno", "name": "Glaciar Eterno", "zone": 4, "base": 2.0, "amp": 2.0, "mountain": false, "surface": 87, "decor": "pino"},
	{"key": "volcan_dormido", "name": "Volcán Dormido", "zone": 4, "base": 3.0, "amp": 6.0, "mountain": true, "surface": 3, "decor": "ninguna"},
	{"key": "altiplano_nubes", "name": "Altiplano de Nubes", "zone": 4, "base": 5.0, "amp": 2.0, "mountain": false, "surface": 1, "decor": "flor"},
	{"key": "bosque_petrificado", "name": "Bosque Petrificado", "zone": 5, "base": 3.0, "amp": 3.0, "mountain": false, "surface": 3, "decor": "pino"},
	{"key": "desierto_obsidiana", "name": "Desierto de Obsidiana", "zone": 5, "base": 1.0, "amp": 2.0, "mountain": false, "surface": 3, "decor": "cactus"},
	{"key": "pantano_niebla", "name": "Pantano de Niebla", "zone": 5, "base": 2.0, "amp": 1.0, "mountain": false, "surface": 2, "decor": "roble"},
	{"key": "montanas_eco", "name": "Montañas del Eco", "zone": 5, "base": 3.0, "amp": 6.0, "mountain": true, "surface": 3, "decor": "pino"},
	{"key": "suelo_corrupto", "name": "Suelo Corrupto", "zone": 5, "base": 2.0, "amp": 3.0, "mountain": false, "surface": 3, "decor": "seta_brillo"},
	{"key": "tierras_celestiales", "name": "Tierras Celestiales", "zone": 6, "base": 5.0, "amp": 3.0, "mountain": false, "surface": 1, "decor": "flor"},
	{"key": "abismo_cristal", "name": "Abismo de Cristal", "zone": 6, "base": 1.0, "amp": 6.0, "mountain": true, "surface": 3, "decor": "seta_brillo"},
	{"key": "hielo_eterno", "name": "Hielo Eterno", "zone": 6, "base": 2.0, "amp": 3.0, "mountain": false, "surface": 87, "decor": "pino"},
	{"key": "tierras_magma", "name": "Tierras de Magma", "zone": 6, "base": 2.0, "amp": 4.0, "mountain": false, "surface": 3, "decor": "ninguna"},
	{"key": "jardin_vacio", "name": "Jardín del Vacío", "zone": 6, "base": 3.0, "amp": 2.0, "mountain": false, "surface": 1, "decor": "seta_brillo"},
]


static func special_for(key: String) -> Dictionary:
	for s in SPECIALS:
		if str(s["key"]) == key:
			return s
	return {}


static func is_special(key: String) -> bool:
	return not special_for(key).is_empty()


static func params_for(key: String) -> Vector3:
	var s: Dictionary = special_for(key)
	if s.is_empty():
		return Vector3(2.0, 4.0, 0.0)
	return Vector3(float(s["base"]), float(s["amp"]), 1.0 if bool(s["mountain"]) else 0.0)


static func surface_for(key: String) -> int:
	var s: Dictionary = special_for(key)
	if s.is_empty():
		return 1
	return int(s["surface"])


static func decor_for(key: String) -> String:
	var s: Dictionary = special_for(key)
	if s.is_empty():
		return "flor"
	return str(s["decor"])


static func zone_for(key: String) -> int:
	var s: Dictionary = special_for(key)
	if s.is_empty():
		return 1
	return int(s["zone"])


static func count_by_zone(zone: int) -> int:
	var count: int = 0
	for s in SPECIALS:
		if int(s["zone"]) == zone:
			count += 1
	return count
