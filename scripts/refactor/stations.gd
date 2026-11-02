extends RefCounted
## StationSystem — las 8 estaciones de artesanía
## (documento §7.4): mano, mesa de trabajo, horno,
## yunque, yunque titán, telar, mesa de alquimia y
## olla de cocina. Cada estación es un bloque que se
## coloca en el mundo (ids 247-254 del catálogo); sus
## recetas aparecen cuando el bloque está cerca (radio
## 4), salvo la mano, que siempre está disponible.
## Los bloques de estación se fabrican en cadena: la
## mano hace la mesa, la mesa hace el resto.
## Puro, sin nodos: RefactorMain le pasa personaje,
## inventario y modo. En Creativo no consume nada.

class_name StationSystem

const BLOCK_WORKBENCH := 247
const BLOCK_FURNACE := 248
const BLOCK_ANVIL := 249
const BLOCK_TITAN_ANVIL := 250
const BLOCK_LOOM := 251
const BLOCK_COOKING_POT := 252
const BLOCK_ALCHEMY_TABLE := 253
const BLOCK_FORGE := 254

const SCAN_RADIUS := 4


static func stations() -> Array[Dictionary]:
	return [
		{"id": "mano", "name": "Mano", "block": -1, "recipes": [
			{"id": "mesa_trabajo", "name": "Mesa de trabajo", "needs_materials": {"madera": 4}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": BLOCK_WORKBENCH, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "forja_mano", "name": "Forja de escultura", "needs_materials": {"hierro": 4, "piedra": 4}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": BLOCK_FORGE, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "antorcha_mano", "name": "Antorcha", "needs_materials": {"carbon": 1, "madera": 1}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": 80, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
		]},
		{"id": "workbench", "name": "Mesa de trabajo", "block": BLOCK_WORKBENCH, "recipes": [
			{"id": "cofre", "name": "Cofre", "needs_materials": {"madera": 4}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": 81, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "horno", "name": "Horno", "needs_materials": {"piedra": 8}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": BLOCK_FURNACE, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "yunque", "name": "Yunque", "needs_materials": {"hierro": 3}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": BLOCK_ANVIL, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "telar", "name": "Telar", "needs_materials": {"madera": 2}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": BLOCK_LOOM, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "olla", "name": "Olla de cocina", "needs_materials": {"hierro": 3}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": BLOCK_COOKING_POT, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "mesa_alquimia", "name": "Mesa de alquimia", "needs_materials": {"madera": 2, "hierba": 2}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": BLOCK_ALCHEMY_TABLE, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
		]},
		{"id": "furnace", "name": "Horno", "block": BLOCK_FURNACE, "recipes": [
			{"id": "fundir_hierro", "name": "Fundir hierro ×2", "needs_materials": {}, "needs_spirits": {}, "needs_blocks": {148: 1}, "gives_block": -1, "gives_item": "", "gives_material": "hierro", "gives_amount": 2, "gives_potion": "", "gives_food": 0},
			{"id": "fundir_carbon", "name": "Fundir carbón ×2", "needs_materials": {}, "needs_spirits": {}, "needs_blocks": {145: 1}, "gives_block": -1, "gives_item": "", "gives_material": "carbon", "gives_amount": 2, "gives_potion": "", "gives_food": 0},
			{"id": "fundir_oro", "name": "Fundir oro ×2", "needs_materials": {}, "needs_spirits": {}, "needs_blocks": {150: 1}, "gives_block": -1, "gives_item": "", "gives_material": "oro", "gives_amount": 2, "gives_potion": "", "gives_food": 0},
			{"id": "fundir_cronolita", "name": "Fundir cronolita", "needs_materials": {}, "needs_spirits": {}, "needs_blocks": {153: 1}, "gives_block": -1, "gives_item": "", "gives_material": "cronolita", "gives_amount": 1, "gives_potion": "", "gives_food": 0},
		]},
		{"id": "anvil", "name": "Yunque", "block": BLOCK_ANVIL, "recipes": [
			{"id": "armadura_hierro", "name": "Armadura de hierro", "needs_materials": {"hierro": 4}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": -1, "gives_item": "armadura_hierro", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "armadura_acero", "name": "Armadura de acero", "needs_materials": {"acero": 3}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": -1, "gives_item": "armadura_acero", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "yunque_titan", "name": "Yunque titán", "needs_materials": {"acero": 3, "cronolita": 1}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": BLOCK_TITAN_ANVIL, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
		]},
		{"id": "titan_anvil", "name": "Yunque titán", "block": BLOCK_TITAN_ANVIL, "recipes": [
			{"id": "espada_titan", "name": "Espada titán", "needs_materials": {"acero": 2, "cronolita": 1}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": -1, "gives_item": "espada_titan", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "armadura_titan", "name": "Armadura titán", "needs_materials": {"acero": 3, "cronolita": 1}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": -1, "gives_item": "armadura_titan", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "armadura_oro", "name": "Armadura de oro", "needs_materials": {"oro": 4}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": -1, "gives_item": "armadura_oro", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
		]},
		{"id": "loom", "name": "Telar", "block": BLOCK_LOOM, "recipes": [
			{"id": "capa_tela", "name": "Capa de tela", "needs_materials": {"tela": 4}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": -1, "gives_item": "capa_tela", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
			{"id": "capa_viento", "name": "Capa de viento", "needs_materials": {"tela": 4}, "needs_spirits": {"viento": 1}, "needs_blocks": {}, "gives_block": -1, "gives_item": "capa_viento", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 0},
		]},
		{"id": "alchemy_table", "name": "Mesa de alquimia", "block": BLOCK_ALCHEMY_TABLE, "recipes": [
			{"id": "pocion_salud", "name": "Poción de salud", "needs_materials": {"hierba": 2}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": -1, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "salud", "gives_food": 0},
			{"id": "pocion_mana", "name": "Poción de maná", "needs_materials": {"hierba": 3}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": -1, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "mana", "gives_food": 0},
		]},
		{"id": "cooking_pot", "name": "Olla de cocina", "block": BLOCK_COOKING_POT, "recipes": [
			{"id": "comida", "name": "Comida", "needs_materials": {"hierba": 2}, "needs_spirits": {}, "needs_blocks": {}, "gives_block": -1, "gives_item": "", "gives_material": "", "gives_amount": 0, "gives_potion": "", "gives_food": 1},
		]},
	]


static func station_by_id(station_id: String) -> Dictionary:
	for s in stations():
		if str(s["id"]) == station_id:
			return s
	return {}


static func recipe_by_id(station_id: String, recipe_id: String) -> Dictionary:
	var station := station_by_id(station_id)
	if station.is_empty():
		return {}
	var recipes: Array = station["recipes"]
	for r in recipes:
		if str(r["id"]) == recipe_id:
			return r
	return {}


## Estaciones con bloque cerca del punto (radio 4).
## get_block es del generador; se llama solo al abrir
## el panel, no cada frame.
static func nearby_stations(center: Vector3i, get_block: Callable) -> Array[String]:
	var found: Array[String] = []
	var cx := center.x
	var cy := center.y
	var cz := center.z
	for s in stations():
		var block_id := int(s["block"])
		if block_id < 0:
			continue
		var hit := false
		for dx in range(-SCAN_RADIUS, SCAN_RADIUS + 1):
			for dy in range(-2, 3):
				for dz in range(-SCAN_RADIUS, SCAN_RADIUS + 1):
					if int(get_block.call(Vector3i(cx + dx, cy + dy, cz + dz))) == block_id:
						hit = true
						break
				if hit:
					break
			if hit:
				break
		if hit:
			found.append(str(s["id"]))
	return found


static func can_craft(recipe: Dictionary, character: CharacterData, inventory: Dictionary, creative: bool) -> bool:
	if recipe.is_empty():
		return false
	if creative:
		return true
	var needs_m: Dictionary = recipe["needs_materials"]
	for kind in needs_m.keys():
		if int(character.materials.get(kind, 0)) < int(needs_m[kind]):
			return false
	var needs_s: Dictionary = recipe["needs_spirits"]
	for kind in needs_s.keys():
		if int(character.spirits.get(kind, 0)) < int(needs_s[kind]):
			return false
	var needs_b: Dictionary = recipe["needs_blocks"]
	for block_id in needs_b.keys():
		if int(inventory.get(int(block_id), 0)) < int(needs_b[block_id]):
			return false
	return true


## Fabrica y devuelve el resultado, o {} si no se puede.
static func apply_craft(recipe: Dictionary, character: CharacterData, inventory: Dictionary, creative: bool) -> Dictionary:
	if not can_craft(recipe, character, inventory, creative):
		return {}
	if not creative:
		var needs_m: Dictionary = recipe["needs_materials"]
		for kind in needs_m.keys():
			character.materials[kind] = int(character.materials.get(kind, 0)) - int(needs_m[kind])
		var needs_s: Dictionary = recipe["needs_spirits"]
		for kind in needs_s.keys():
			character.spirits[kind] = int(character.spirits.get(kind, 0)) - int(needs_s[kind])
		var needs_b: Dictionary = recipe["needs_blocks"]
		for block_id in needs_b.keys():
			inventory[int(block_id)] = int(inventory.get(int(block_id), 0)) - int(needs_b[block_id])
	var gives_block := int(recipe["gives_block"])
	if gives_block >= 0:
		inventory[gives_block] = int(inventory.get(gives_block, 0)) + 1
		return {"block": gives_block}
	var item := str(recipe["gives_item"])
	if item != "":
		return {"item": item}
	var material := str(recipe["gives_material"])
	if material != "":
		character.materials[material] = int(character.materials.get(material, 0)) + int(recipe["gives_amount"])
		return {"material": material, "amount": int(recipe["gives_amount"])}
	var potion := str(recipe["gives_potion"])
	if potion != "":
		character.potions[potion] = int(character.potions.get(potion, 0)) + 1
		return {"potion": potion}
	var food := int(recipe["gives_food"])
	if food > 0:
		character.food += food
		return {"food": food}
	return {}
