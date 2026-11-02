extends RefCounted
## Biomes2 — los 4 biomas del plan de Cube Unbound, adaptados
## a la escala de Bloques Mágicos y a un niño de 5 años.
##
## El plan proponía 4 biomas por ruido de temperatura: Pradera
## Verde, Playa y Mar, Bosque Otoñal/Mágico y Montaña Nevada.
## Aquí son Pradera Verde, Playa y Mar, Bosque Mágico y Montaña
## Nevada, sin peligro ni enemigos: la diferencia es visual y
## de aprendizaje (superficie, árbol y decoración), nunca de
## castigo. Los 4 biomas viejos de la variante (Croma-Isla,
## Forja, Valle, Ciber-Núcleo) siguen intactos en Ajustes.
##
## Escala: el generador de la variante mide alturas 1..14 con
## nivel de agua 2, no 8..36 del plan. Por eso playa = altura
## <= agua + 1 y montaña = altura >= 12 o temperatura < -0.3.

class_name Biomes2

const BIOMES := ["pradera_verde", "playa_mar", "bosque_magico", "montana_nevada"]
const WATER_LEVEL := 2


## Bioma por altura y temperatura (ruido -1..1). Pura, para
## tests: la misma entrada da siempre el mismo bioma.
static func biome_for(height: int, temp: float, water_level: int = WATER_LEVEL) -> String:
	if height <= water_level + 1:
		return "playa_mar"
	if height >= 12 or temp < -0.3:
		return "montana_nevada"
	if temp > 0.3:
		return "bosque_magico"
	return "pradera_verde"


## Bloque de superficie del bioma (IDs del generador).
static func surface_block(biome: String) -> int:
	match biome:
		"playa_mar":
			return 7 # arena
		"montana_nevada":
			return 87 # nieve (nuevo en 2.0)
		_:
			return 1 # hierba


## Tipo de árbol/decoración principal del bioma.
static func tree_kind(biome: String) -> String:
	match biome:
		"playa_mar":
			return "palma"
		"bosque_magico":
			return "magico"
		"montana_nevada":
			return "pino"
		_:
			return "roble"


static func decoration(biome: String) -> String:
	match biome:
		"bosque_magico":
			return "seta_brillo"
		"playa_mar":
			return "palma"
		"montana_nevada":
			return "pino_nevado"
		_:
			return "flor"


static func is_biome2(biome: String) -> bool:
	return biome in BIOMES
