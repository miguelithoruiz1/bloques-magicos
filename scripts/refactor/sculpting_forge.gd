extends RefCounted
## SculptingForge — forja de escultura (documento §6.3):
## cubos de madera/hierro/acero/oro + espíritus de fuego,
## hielo, viento y veneno, esculpidos en armas. El acero
## no se mina: se funde (2 hierro + 1 carbón). Puro, sin
## nodos: RefactorMain le pasa el personaje y el modo.
## En Creativo no consume nada, igual que el taller.

class_name SculptingForge


static func recipes() -> Array[Dictionary]:
	return [
		{"id": "acero", "name": "Lingote de acero", "needs_materials": {"hierro": 2, "carbon": 1}, "needs_spirits": {}, "gives_material": "acero", "gives_amount": 1, "gives_item": ""},
		{"id": "espada_madera", "name": "Espada de madera", "needs_materials": {"madera": 3}, "needs_spirits": {}, "gives_material": "", "gives_amount": 0, "gives_item": "espada_madera"},
		{"id": "espada_hierro", "name": "Espada de hierro", "needs_materials": {"hierro": 3}, "needs_spirits": {}, "gives_material": "", "gives_amount": 0, "gives_item": "espada_hierro"},
		{"id": "espada_acero", "name": "Espada de acero", "needs_materials": {"acero": 3}, "needs_spirits": {}, "gives_material": "", "gives_amount": 0, "gives_item": "espada_acero"},
		{"id": "espada_oro", "name": "Espada de oro", "needs_materials": {"oro": 3}, "needs_spirits": {}, "gives_material": "", "gives_amount": 0, "gives_item": "espada_oro"},
		{"id": "espada_fuego", "name": "Espada de fuego", "needs_materials": {"hierro": 3}, "needs_spirits": {"fuego": 1}, "gives_material": "", "gives_amount": 0, "gives_item": "espada_fuego"},
		{"id": "espada_hielo", "name": "Espada de hielo", "needs_materials": {"hierro": 3}, "needs_spirits": {"hielo": 1}, "gives_material": "", "gives_amount": 0, "gives_item": "espada_hielo"},
		{"id": "espada_viento", "name": "Espada de viento", "needs_materials": {"hierro": 3}, "needs_spirits": {"viento": 1}, "gives_material": "", "gives_amount": 0, "gives_item": "espada_viento"},
		{"id": "espada_veneno", "name": "Espada de veneno", "needs_materials": {"hierro": 3}, "needs_spirits": {"veneno": 1}, "gives_material": "", "gives_amount": 0, "gives_item": "espada_veneno"},
	]


static func recipe_by_id(recipe_id: String) -> Dictionary:
	for r in recipes():
		if str(r["id"]) == recipe_id:
			return r
	return {}


static func can_craft(recipe: Dictionary, character: CharacterData, creative: bool) -> bool:
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
	return true


## Forja y devuelve el resultado, o {} si no se puede.
## El equipo se equipa en RefactorMain, no aquí.
static func apply_craft(recipe: Dictionary, character: CharacterData, creative: bool) -> Dictionary:
	if not can_craft(recipe, character, creative):
		return {}
	if not creative:
		var needs_m: Dictionary = recipe["needs_materials"]
		for kind in needs_m.keys():
			character.materials[kind] = int(character.materials.get(kind, 0)) - int(needs_m[kind])
		var needs_s: Dictionary = recipe["needs_spirits"]
		for kind in needs_s.keys():
			character.spirits[kind] = int(character.spirits.get(kind, 0)) - int(needs_s[kind])
	var item := str(recipe["gives_item"])
	if item != "":
		return {"item": item}
	var material := str(recipe["gives_material"])
	if material != "":
		character.materials[material] = int(character.materials.get(material, 0)) + int(recipe["gives_amount"])
		return {"material": material, "amount": int(recipe["gives_amount"])}
	return {}
