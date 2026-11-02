extends RefCounted
## EquipmentItems — base de datos de equipo (documento
## §6): armas, armaduras y capas que salen de la forja,
## el yunque, el yunque titán y el telar. Un solo lugar
## para que personaje, forja y estaciones no diverjan.
## damage_mult multiplica el daño que hace el jugador;
## armor_mult multiplica el daño que recibe; speed_mult
## multiplica su velocidad.

class_name EquipmentItems

const ITEMS := {
	"espada_madera": {"name": "Espada de madera", "slot": "arma", "damage_mult": 1.0, "element": ""},
	"espada_hierro": {"name": "Espada de hierro", "slot": "arma", "damage_mult": 1.25, "element": ""},
	"espada_acero": {"name": "Espada de acero", "slot": "arma", "damage_mult": 1.5, "element": ""},
	"espada_oro": {"name": "Espada de oro", "slot": "arma", "damage_mult": 2.0, "element": ""},
	"espada_titan": {"name": "Espada titán", "slot": "arma", "damage_mult": 2.5, "element": ""},
	"espada_fuego": {"name": "Espada de fuego", "slot": "arma", "damage_mult": 1.75, "element": "fuego"},
	"espada_hielo": {"name": "Espada de hielo", "slot": "arma", "damage_mult": 1.75, "element": "hielo"},
	"espada_viento": {"name": "Espada de viento", "slot": "arma", "damage_mult": 1.75, "element": "viento"},
	"espada_veneno": {"name": "Espada de veneno", "slot": "arma", "damage_mult": 1.75, "element": "veneno"},
	"armadura_hierro": {"name": "Armadura de hierro", "slot": "armadura", "armor_mult": 0.85, "element": ""},
	"armadura_acero": {"name": "Armadura de acero", "slot": "armadura", "armor_mult": 0.75, "element": ""},
	"armadura_oro": {"name": "Armadura de oro", "slot": "armadura", "armor_mult": 0.65, "element": ""},
	"armadura_titan": {"name": "Armadura titán", "slot": "armadura", "armor_mult": 0.5, "element": ""},
	"capa_tela": {"name": "Capa de tela", "slot": "capa", "speed_mult": 1.1, "element": ""},
	"capa_viento": {"name": "Capa de viento", "slot": "capa", "speed_mult": 1.25, "element": "viento"},
}


static func item_by_id(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


static func name_of(item_id: String) -> String:
	var item := item_by_id(item_id)
	if item.is_empty():
		return item_id
	return str(item["name"])


static func slot_of(item_id: String) -> String:
	var item := item_by_id(item_id)
	if item.is_empty():
		return ""
	return str(item["slot"])
