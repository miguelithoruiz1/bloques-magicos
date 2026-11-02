extends RefCounted
## Workshop — recetas del Taller 3.0, puras (sin nodos).
##
## Regla igual que al colocar: en Creativo gratis, en
## Supervivencia descuenta del inventario. Lo fabricado va
## al slot seleccionado de la hotbar (lo hace RefactorMain).
## Recetas propias + 2 semánticas del GDD (mezcla de color
## y sílaba). IDs de bloque: ver VoxelWorldGenerator
## (90 estrella, 91 corazón, 92 farol, 93 sílaba MA;
## 13 verde ya existía como color; 44 división, 3.0).

class_name Workshop

const BLOCK_STAR := 90
const BLOCK_HEART := 91
const BLOCK_LANTERN := 92
const BLOCK_SYLLABLE_MA := 93
const BLOCK_DIVIDE := 44


static func recipes() -> Array[Dictionary]:
	return [
		{"id": "estrella", "name": "Estrella dorada", "gives": BLOCK_STAR,
			"needs": {12: 3, 88: 2}},
		{"id": "corazon", "name": "Corazón", "gives": BLOCK_HEART,
			"needs": {10: 3, 16: 1}},
		{"id": "farol", "name": "Farol", "gives": BLOCK_LANTERN,
			"needs": {80: 1, 86: 1}},
		{"id": "verde", "name": "Verde (Amarillo + Azul)", "gives": 13,
			"needs": {12: 1, 11: 1}},
		{"id": "silaba_ma", "name": "Sílaba MA (M + A)", "gives": BLOCK_SYLLABLE_MA,
			"needs": {62: 1, 50: 1}},
	]


static func recipe_by_id(recipe_id: String) -> Dictionary:
	for r in recipes():
		if str(r["id"]) == recipe_id:
			return r
	return {}


static func can_craft(recipe: Dictionary, inventory: Dictionary, creative: bool) -> bool:
	if recipe.is_empty():
		return false
	if creative:
		return true
	var needs: Dictionary = recipe["needs"]
	for block_id in needs.keys():
		if int(inventory.get(block_id, 0)) < int(needs[block_id]):
			return false
	return true


## Descuenta en Supervivencia (en Creativo no toca nada) y
## devuelve el bloque fabricado, o -1 si no se puede.
static func apply_craft(recipe: Dictionary, inventory: Dictionary, creative: bool) -> int:
	if not can_craft(recipe, inventory, creative):
		return -1
	if not creative:
		var needs: Dictionary = recipe["needs"]
		for block_id in needs.keys():
			inventory[block_id] = int(inventory.get(block_id, 0)) - int(needs[block_id])
	return int(recipe["gives"])
