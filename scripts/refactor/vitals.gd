extends RefCounted
## VitalsSystem — vitales del jugador (documento §7.2):
## salud, maná, estamina, oxígeno sumergido y temperatura
## corporal. Sin muerte permanente: al llegar a 0 de salud
## se emite died y RefactorMain reaparece al jugador en el
## inicio con los vitales llenos (multiedad).
##
## Temperatura: escala 0-100, 50 = cómodo. El ambiente
## tira hacia su valor (frío de glaciares/noche, calor
## de desiertos/volcanes); cerca de una fuente de calor
## (antorcha, farol, cristal brillo) suma calor. Bajo 15
## o sobre 85, la salud baja 2/s.
## Estamina: correr drena 8/s, esquivar cuesta 25,
## regen 10/s en reposo.
## Oxígeno: sumergido drena 10/s; a 0, la salud baja
## 10/s (ignora los i-frames: ahogarse no se esquiva).
## Maná: regen 5/s; el ataque con maná cuesta 25.
## Salud: regen 2/s tras 5 s sin daño.

class_name VitalsSystem

signal died

const MAX_HEALTH := 100.0
const MAX_MANA := 100.0
const MAX_STAMINA := 100.0
const MAX_OXYGEN := 100.0

var health := MAX_HEALTH
var mana := MAX_MANA
var stamina := MAX_STAMINA
var oxygen := MAX_OXYGEN
var temperature := 50.0
var iframes_timer := 0.0
# 3.0 personaje: la raza y el equipo los ajustan.
var max_health := MAX_HEALTH
var max_oxygen := MAX_OXYGEN
var mana_regen_mult := 1.0
var damage_mult := 1.0

var _hurt_timer := 99.0
var _dead := false


func reset() -> void:
	health = max_health
	mana = MAX_MANA
	stamina = MAX_STAMINA
	oxygen = max_oxygen
	temperature = 50.0
	iframes_timer = 0.0
	_hurt_timer = 99.0
	_dead = false


func is_dead() -> bool:
	return _dead


func is_invulnerable() -> bool:
	return iframes_timer > 0.0


func start_iframes(seconds: float) -> void:
	iframes_timer = maxf(iframes_timer, seconds)


## Daño. Devuelve true si entró. Con i-frames activos no
## entra salvo bypass (ahogo, temperatura extrema).
func damage(amount: float, bypass_iframes: bool = false) -> bool:
	if _dead or amount <= 0.0:
		return false
	if iframes_timer > 0.0 and not bypass_iframes:
		return false
	if not bypass_iframes:
		amount *= damage_mult
	health -= amount
	_hurt_timer = 0.0
	if health <= 0.0:
		health = 0.0
		_dead = true
		died.emit()
	return true


func spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	return true


func spend_mana(amount: float) -> bool:
	if mana < amount:
		return false
	mana -= amount
	return true


## Actualización por frame. ambient_temp: temperatura del
## bioma/hora (0-100); near_heat: fuente de calor cerca.
func update(delta: float, sprinting: bool, submerged: bool, ambient_temp: float, near_heat: bool) -> void:
	if _dead:
		return
	_hurt_timer += delta
	if iframes_timer > 0.0:
		iframes_timer -= delta
	# Estamina.
	if sprinting and stamina > 0.0:
		stamina = maxf(0.0, stamina - 8.0 * delta)
	elif not sprinting:
		stamina = minf(MAX_STAMINA, stamina + 10.0 * delta)
	# Maná.
	mana = minf(MAX_MANA, mana + 5.0 * mana_regen_mult * delta)
	# Oxígeno.
	if submerged:
		oxygen = maxf(0.0, oxygen - 10.0 * delta)
		if oxygen <= 0.0:
			damage(10.0 * delta, true)
	else:
		oxygen = minf(max_oxygen, oxygen + 25.0 * delta)
	# Temperatura: deriva hacia el ambiente (+calor cerca).
	var target := ambient_temp + (15.0 if near_heat else 0.0)
	if temperature < target:
		temperature = minf(target, temperature + 3.0 * delta)
	elif temperature > target:
		temperature = maxf(target, temperature - 3.0 * delta)
	if temperature < 15.0 or temperature > 85.0:
		damage(2.0 * delta, true)
	# Salud: regen lenta tras 5 s sin daño.
	if _hurt_timer > 5.0 and health > 0.0 and health < max_health:
		health = minf(max_health, health + 2.0 * delta)
