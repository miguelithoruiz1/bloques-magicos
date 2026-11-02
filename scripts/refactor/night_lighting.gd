extends Node
## 06 — NightLighting: noche visible, nunca negra.
##
## El fallo real en la 3.0.2:
## - VoxelWorldGenerator crea sol (1.15) y cielo procedural,
##   y RefactorMain baja el sol a 0.4 de noche. Pero nadie
##   cambia el cielo ni pone un suelo de luz ambiental: con
##   AMBIENT_SOURCE_SKY y un cielo que no se oscurece de forma
##   controlada, la escena puede quedar casi negra y el jugador
##   pierde visibilidad total.
## - Este controlador es la única fuente de luz nocturna:
##   aplica hora -> cielo + ambiente + sol/luna, con un suelo
##   mínimo azulado que nunca llega a 0. Los bloques de luz
##   (antorcha, cristal, seta) hacen el resto.
##
## Uso en RefactorMain (ver 07_integracion.md):
##   var night := NightLighting.new()
##   add_child(night)
##   night.setup(world_environment, sun_node)
##   night.apply_time_of_day(game_mode.time_of_day)

class_name NightLighting

# Suelo nocturno mínimo: azulado, nunca #000000.
const NIGHT_AMBIENT_COLOR := Color(0.16, 0.23, 0.40)
const NIGHT_AMBIENT_ENERGY := 0.38
const DAY_AMBIENT_ENERGY := 1.0
const MOON_ENERGY := 0.30

var _env: Environment = null
var _sun: DirectionalLight3D = null
var _moon: DirectionalLight3D = null
var _sky_mat: ProceduralSkyMaterial = null


func setup(world_env: WorldEnvironment, sun: DirectionalLight3D) -> bool:
	if world_env == null or world_env.environment == null:
		return false
	_env = world_env.environment
	_sun = sun
	if _env.sky != null and _env.sky.sky_material is ProceduralSkyMaterial:
		_sky_mat = _env.sky.sky_material
	# Luna: luz direccional azulada, creada una sola vez.
	if _moon == null and world_env.get_parent() != null:
		_moon = DirectionalLight3D.new()
		_moon.name = "Luna"
		_moon.light_color = Color(0.65, 0.75, 1.0)
		_moon.light_energy = 0.0
		_moon.rotation_degrees = Vector3(-40.0, 120.0, 0.0)
		_moon.shadow_enabled = false
		world_env.get_parent().add_child(_moon)
	return true


func is_night(hour: float) -> bool:
	return hour < 6.0 or hour >= 19.0


func apply_time_of_day(hour: float) -> void:
	if _env == null:
		return
	if is_night(hour):
		_apply_night()
	elif hour >= 17.0:
		_apply_dusk()
	else:
		_apply_day()


func _apply_day() -> void:
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = DAY_AMBIENT_ENERGY
	if _sun != null:
		_sun.light_energy = 1.15
		_sun.visible = true
	if _moon != null:
		_moon.light_energy = 0.0
	if _sky_mat != null:
		_sky_mat.sky_top_color = Color(0.30, 0.58, 0.95)
		_sky_mat.sky_horizon_color = Color(0.72, 0.87, 1.00)
		_sky_mat.ground_bottom_color = Color(0.42, 0.62, 0.38)
		_sky_mat.ground_horizon_color = Color(0.72, 0.87, 1.00)


func _apply_dusk() -> void:
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.45, 0.35, 0.45)
	_env.ambient_light_energy = 0.65
	if _sun != null:
		_sun.light_energy = 0.7
	if _moon != null:
		_moon.light_energy = 0.0
	if _sky_mat != null:
		_sky_mat.sky_top_color = Color(0.25, 0.30, 0.60)
		_sky_mat.sky_horizon_color = Color(0.95, 0.55, 0.30)


func _apply_night() -> void:
	# Clave: fuente COLOR (no SKY) + suelo 0.38. Así la noche
	# es oscura pero jugable, aunque el cielo falle.
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = NIGHT_AMBIENT_COLOR
	_env.ambient_light_energy = NIGHT_AMBIENT_ENERGY
	if _sun != null:
		_sun.light_energy = 0.0
		_sun.visible = false
	if _moon != null:
		_moon.light_energy = MOON_ENERGY
		_moon.visible = true
	if _sky_mat != null:
		_sky_mat.sky_top_color = Color(0.03, 0.06, 0.16)
		_sky_mat.sky_horizon_color = Color(0.10, 0.16, 0.32)
		_sky_mat.ground_bottom_color = Color(0.05, 0.08, 0.15)
		_sky_mat.ground_horizon_color = Color(0.10, 0.16, 0.32)


func night_ambient_color() -> Color:
	return NIGHT_AMBIENT_COLOR
