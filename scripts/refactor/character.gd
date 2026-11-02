extends RefCounted
## CharacterData — el personaje, separado del mundo
## (documento §6.2, personaje.json): raza, monedas,
## rangos de habilidad, equipo, mascota, materiales de
## la forja, espíritus, pociones y comida. Vive en
## user://bloques3_character.json, no en el guardado
## del mundo: cambiar de mundo no pierde al personaje.
## Nivel y EXP viven en LevelSystem (fuente única, sin
## duplicar: el personaje no copia lo que otro sistema
## ya guarda).

class_name CharacterData

const SAVE_PATH := "user://bloques3_character.json"

const RACES := {
	"human": {"name": "Humano", "desc": "Equilibrado: +10% EXP.", "exp_mult": 1.1, "health_bonus": 0.0, "mana_regen_mult": 1.0, "damage_out": 1.0, "damage_in": 1.0, "oxygen_bonus": 0.0, "speed_mult": 1.0},
	"elf": {"name": "Elfo", "desc": "Maná del bosque: regen ×1.5.", "exp_mult": 1.0, "health_bonus": 0.0, "mana_regen_mult": 1.5, "damage_out": 1.0, "damage_in": 1.0, "oxygen_bonus": 0.0, "speed_mult": 1.0},
	"dwarf": {"name": "Enano", "desc": "Resistente: +25 de salud.", "exp_mult": 1.0, "health_bonus": 25.0, "mana_regen_mult": 1.0, "damage_out": 1.0, "damage_in": 1.0, "oxygen_bonus": 0.0, "speed_mult": 1.0},
	"orc": {"name": "Orco", "desc": "Fuerte: daño ×1.25.", "exp_mult": 1.0, "health_bonus": 0.0, "mana_regen_mult": 1.0, "damage_out": 1.25, "damage_in": 1.0, "oxygen_bonus": 0.0, "speed_mult": 1.0},
	"frogman": {"name": "Hombre rana", "desc": "Buceador: +50 de oxígeno.", "exp_mult": 1.0, "health_bonus": 0.0, "mana_regen_mult": 1.0, "damage_out": 1.0, "damage_in": 1.0, "oxygen_bonus": 50.0, "speed_mult": 1.0},
	"golem": {"name": "Gólem", "desc": "Rocoso: recibe 25% menos daño.", "exp_mult": 1.0, "health_bonus": 0.0, "mana_regen_mult": 1.0, "damage_out": 1.0, "damage_in": 0.75, "oxygen_bonus": 0.0, "speed_mult": 1.0},
}

const SKILLS := ["combate", "doma", "mineria", "construccion", "cocina", "alquimia"]

var race := "human"
var coins := 0
var skill_xp := {}
var equipment := {"arma": "", "armadura": "", "capa": ""}
var pet := ""
var materials := {"madera": 0, "hierro": 0, "acero": 0, "oro": 0, "carbon": 0, "cronolita": 0, "piedra": 0, "tela": 0, "hierba": 0}
var spirits := {"fuego": 0, "hielo": 0, "viento": 0, "veneno": 0}
var potions := {"salud": 0, "mana": 0}
var food := 0


func race_info() -> Dictionary:
	return RACES.get(race, RACES["human"])


func skill_rank(skill: String) -> int:
	return int(skill_xp.get(skill, 0)) / 10


## Suma EXP de habilidad. Devuelve true si subió de rango.
func gain_skill(skill: String, amount: int = 1) -> bool:
	var before := skill_rank(skill)
	skill_xp[skill] = int(skill_xp.get(skill, 0)) + amount
	return skill_rank(skill) > before


## Multiplicador de daño que hace: raza × arma × rango
## de combate (+5% por rango).
func attack_mult() -> float:
	var mult := float(race_info()["damage_out"])
	var weapon := str(equipment.get("arma", ""))
	var item := EquipmentItems.item_by_id(weapon)
	if not item.is_empty():
		mult *= float(item.get("damage_mult", 1.0))
	mult *= 1.0 + 0.05 * skill_rank("combate")
	return mult


## Multiplicador de daño que recibe: raza × armadura.
func defense_mult() -> float:
	var mult := float(race_info()["damage_in"])
	var armor := str(equipment.get("armadura", ""))
	var item := EquipmentItems.item_by_id(armor)
	if not item.is_empty():
		mult *= float(item.get("armor_mult", 1.0))
	return mult


func speed_mult() -> float:
	var mult := float(race_info()["speed_mult"])
	var cape := str(equipment.get("capa", ""))
	var item := EquipmentItems.item_by_id(cape)
	if not item.is_empty():
		mult *= float(item.get("speed_mult", 1.0))
	return mult


## Velocidad de doma: +10% por rango de doma.
func tame_mult() -> float:
	return 1.0 + 0.1 * skill_rank("doma")


func apply_to_vitals(vitals: VitalsSystem) -> void:
	if vitals == null:
		return
	var info := race_info()
	vitals.max_health = 100.0 + float(info["health_bonus"])
	vitals.max_oxygen = 100.0 + float(info["oxygen_bonus"])
	vitals.mana_regen_mult = float(info["mana_regen_mult"])
	vitals.damage_mult = defense_mult()
	vitals.health = minf(vitals.health, vitals.max_health)
	vitals.oxygen = minf(vitals.oxygen, vitals.max_oxygen)


func add_material(kind: String, amount: int = 1) -> void:
	if materials.has(kind):
		materials[kind] = int(materials[kind]) + amount


func add_spirit(kind: String, amount: int = 1) -> void:
	if spirits.has(kind):
		spirits[kind] = int(spirits[kind]) + amount


func equip(item_id: String) -> void:
	var slot := EquipmentItems.slot_of(item_id)
	if slot != "":
		equipment[slot] = item_id


func to_dict() -> Dictionary:
	return {
		"race": race, "coins": coins, "skill_xp": skill_xp,
		"equipment": equipment, "pet": pet, "materials": materials,
		"spirits": spirits, "potions": potions, "food": food,
	}


func from_dict(data: Dictionary) -> void:
	race = str(data.get("race", "human"))
	if not RACES.has(race):
		race = "human"
	coins = int(data.get("coins", 0))
	skill_xp = data.get("skill_xp", {})
	var eq: Dictionary = data.get("equipment", {})
	for slot in ["arma", "armadura", "capa"]:
		equipment[slot] = str(eq.get(slot, ""))
	pet = str(data.get("pet", ""))
	# Mezcla con los valores por defecto: un guardado viejo
	# sin una clave nueva no deja ese material en blanco.
	var mat: Dictionary = data.get("materials", {})
	for kind in materials.keys():
		materials[kind] = int(mat.get(kind, 0))
	var spi: Dictionary = data.get("spirits", {})
	for kind in spirits.keys():
		spirits[kind] = int(spi.get(kind, 0))
	var pot: Dictionary = data.get("potions", {})
	for kind in potions.keys():
		potions[kind] = int(pot.get(kind, 0))
	food = int(data.get("food", 0))


func save_to_file() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(to_dict()))
		file.close()


func load_from_file() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	if data.is_empty():
		return false
	from_dict(data)
	return true
