extends Node3D
## VoxelWorldGenerator — terreno voxel con relieve real por semilla.
##
## Renderizado SIN MeshLibrary de editor (una variante solo de
## código no puede depender de un .tres generado en el editor):
## - Bloques de terreno (hierba, tierra, piedra, madera, hojas,
##   arena, flores) van en DOS MultiMeshInstance3D con BoxMesh:
##   uno opaco con color por instancia y uno transparente para
##   el agua. Miles de instancias = pocas llamadas de dibujo.
## - Bloques de aprendizaje (colores, números, letras) que el
##   jugador coloca son MeshInstance3D individuales con Label3D
##   (solo se crean para bloques colocados, que son pocos).
## Un GridMap con MeshLibrary es el camino alternativo si el
## proyecto pasa por el editor; la interfaz (get/set_block) no
## cambia, solo el backend de dibujo.
##
## IDs de bloque:
##   0 aire · 1 hierba · 2 tierra · 3 piedra · 4 madera · 5 hojas
##   6 agua · 7 arena · 8 flor roja · 9 flor amarilla
##   10..21 color (10 + índice de color 0..11, mismo orden que
##     levels_data.gd de 1.15.0)
##   30..39 número (30 + dígito, dígito 0..9: 31 = «1»)
##   50..76 letra (50 + índice 0..26, A..Z con Ñ en 14)
##   80 antorcha (reto nocturno) · 81 cofre (reto) · 82 portal
##
## Rendimiento: NO se promete 60 FPS sin medir (no hay dispositivo
## de prueba en esta VM). Los parámetros render_radius y
## terrain_density son configurables y el radio por defecto (24)
## genera ~49×49 columnas; bajarlo a 16 reduce el trabajo a ~1/3.

class_name VoxelWorldGenerator

signal block_changed(cell: Vector3i, block_id: int)

const BLOCK_AIR := 0
const BLOCK_GRASS := 1
const BLOCK_DIRT := 2
const BLOCK_STONE := 3
const BLOCK_WOOD := 4
const BLOCK_LEAVES := 5
const BLOCK_WATER := 6
const BLOCK_SAND := 7
const BLOCK_FLOWER_RED := 8
const BLOCK_FLOWER_YELLOW := 9
const BLOCK_TORCH := 80
const BLOCK_CHEST := 81
const BLOCK_PORTAL := 82
# Nuevos en 2.0 (catálogo data/blocks.json): tablones, ladrillo,
# vidrio, nieve y cristal brillo. Fuera de los rangos de
# aprendizaje (10-21, 30-43, 50-76) para no romperlos.
const BLOCK_PLANKS := 84
const BLOCK_BRICK := 85
const BLOCK_GLASS := 86
const BLOCK_SNOW := 87
const BLOCK_GLOW := 88

const COLORES: Array[Color] = [
	Color(0.85, 0.15, 0.15), Color(0.15, 0.35, 0.85), Color(0.95, 0.80, 0.15),
	Color(0.20, 0.70, 0.25), Color(0.95, 0.50, 0.10), Color(0.60, 0.20, 0.75),
	Color(0.95, 0.45, 0.65), Color(0.55, 0.35, 0.20), Color(0.10, 0.10, 0.12),
	Color(0.95, 0.95, 0.95), Color(0.55, 0.55, 0.58), Color(0.45, 0.80, 0.95),
]
## 2.0.2 — faltaba la «N»: eran 26 entradas y el bloque 76
## (índice 26) rompía _block_label al abrir el inventario de
## Letras. Orden verificado contra levels_data.gd de la 1.15:
## 27 letras, N en el 13 y Ñ en el 14 (el test viejo que pedía
## Ñ en el 63 quedó corregido a N en el 63, Ñ en el 64).
const LETRAS: Array[String] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "Ñ", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
# Mismo orden que levels_data.gd de 1.15.0 (27 letras): N = 13,
# Ñ = 14, O = 15. No reordenar: los clips letra_* y las palabras
# mágicas dependen de estos índices.

@export var render_radius := 24
@export var water_level := 2

var seed_value := 0
var biome := "croma_isla"
var modified_blocks: Dictionary = {} # "x,y,z" -> int

var _noise: FastNoiseLite = null
var _noise_detail: FastNoiseLite = null
var _solid: MultiMeshInstance3D = null
var _water: MultiMeshInstance3D = null
var _placed: Dictionary = {} # Vector3i -> MeshInstance3D


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.08
	_noise_detail = FastNoiseLite.new()
	_noise_detail.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise_detail.frequency = 0.25
	_solid = _make_multimesh(false)
	_water = _make_multimesh(true)
	add_child(_solid)
	add_child(_water)
	_build_environment()


## 2.0.1 — CORRECCIÓN PANTALLA NEGRA (2026-11-02): la escena
## refactor_main.tscn nunca creaba luz ni ambiente, a diferencia
## de main.gd/hub.gd de la 1.15, que sí añadían sol. Sin luz, los
## materiales sombreados del MultiMesh salen negros puros: el
## terreno se veía como silueta negra contra el cielo. El mundo
## genera su propio sol y cielo para que ninguna escena que lo
## instancie vuelva a quedar a oscuras. Sombras apagadas a
## propósito: el stick onn mueve miles de instancias MultiMesh y
## aquí se prioriza que se vea y rinda; se pueden activar luego.
func _build_environment() -> void:
	if get_node_or_null("Sol") != null:
		return
	var we := WorldEnvironment.new()
	we.name = "Ambiente"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.58, 0.95)
	sky_mat.sky_horizon_color = Color(0.72, 0.87, 1.00)
	sky_mat.ground_bottom_color = Color(0.42, 0.62, 0.38)
	sky_mat.ground_horizon_color = Color(0.72, 0.87, 1.00)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sol"
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)


func _make_multimesh(transparent: bool) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.2, 0.5, 0.9, 0.6)
	inst.material_override = mat
	return inst


## Parámetros de relieve por bioma: (base, amplitud, montañas).
static func biome_params(biome_name: String) -> Vector3:
	match biome_name:
		"forja_numeros":
			return Vector3(2.0, 3.0, 0.0)
		"valle_eco":
			return Vector3(3.0, 2.0, 0.0)
		"ciber_nucleo":
			return Vector3(2.0, 6.0, 1.0)
		# Biomas 2.0 (plan de Cube: pradera, playa, bosque
		# mágico, montaña nevada). Playa baja y plana; montaña
		# alta con relieve de montaña (z > 0.5).
		"pradera_verde":
			return Vector3(2.0, 3.0, 0.0)
		"playa_mar":
			return Vector3(1.0, 1.0, 0.0)
		"bosque_magico":
			return Vector3(3.0, 3.0, 0.0)
		"montana_nevada":
			return Vector3(3.0, 6.0, 1.0)
		_:
			return Vector3(2.0, 4.0, 0.0)


func generate(seed: int, biome_name: String, radius: int = -1) -> void:
	seed_value = seed
	biome = biome_name
	if radius > 0:
		render_radius = radius
	_noise.seed = seed_value
	_noise_detail.seed = seed_value + 7919
	modified_blocks.clear()
	_clear_placed()
	rebuild()


## Altura del terreno en (x, z), solo con la semilla (sin cambios
## del jugador). Función pura respecto a seed/biome: el guardado
## no necesita el terreno, solo el diferencial.
func terrain_height(x: int, z: int) -> int:
	var p := biome_params(biome)
	var n := _noise.get_noise_2d(float(x), float(z))
	var d := _noise_detail.get_noise_2d(float(x), float(z))
	var h := int(p.x + n * p.y + d * 1.5)
	if p.z > 0.5 and n > 0.55:
		h += int((n - 0.55) * 14.0)
	return clampi(h, 1, 14)


## Hash determinista para árboles/flores: mismo (x, z, seed) da
## siempre el mismo resultado, en cualquier dispositivo.
static func scatter_hash(x: int, z: int, seed: int) -> float:
	var h := (x * 73856093) ^ (z * 19349663) ^ (seed * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(abs(h % 1000)) / 1000.0


func terrain_block_at(cell: Vector3i) -> int:
	if cell.y < 0:
		return BLOCK_STONE
	var h := terrain_height(cell.x, cell.z)
	if cell.y > h:
		if cell.y <= water_level and h <= water_level:
			return BLOCK_WATER
		return BLOCK_AIR
	if cell.y == h:
		# Biomas 2.0: la superficie la decide Biomes2. En
		# montaña, un valle bajo junto al agua sigue siendo
		# playa (arena), no nieve sobre el agua.
		if Biomes2.is_biome2(biome):
			if biome == "montana_nevada" and h <= water_level + 1:
				return BLOCK_SAND
			return Biomes2.surface_block(biome)
		if h <= water_level + 1:
			return BLOCK_SAND
		return BLOCK_GRASS
	if cell.y == 0:
		return BLOCK_STONE
	return BLOCK_DIRT


func get_block(cell: Vector3i) -> int:
	var key := WorldSeedManager.key_of(cell)
	if modified_blocks.has(key):
		return int(modified_blocks[key])
	return terrain_block_at(cell)


func set_block(cell: Vector3i, block_id: int, record: bool = true) -> void:
	if record:
		modified_blocks[WorldSeedManager.key_of(cell)] = block_id
	_refresh_placed(cell, block_id)
	block_changed.emit(cell, block_id)


func remove_block(cell: Vector3i) -> void:
	set_block(cell, BLOCK_AIR)


func apply_modified(modified: Dictionary) -> void:
	modified_blocks = modified.duplicate()
	for key in modified_blocks.keys():
		var cell := WorldSeedManager.cell_of(str(key))
		_refresh_placed(cell, int(modified_blocks[key]))
	rebuild()


func _clear_placed() -> void:
	for node in _placed.values():
		(node as Node).queue_free()
	_placed.clear()


## Bloques que se dibujan como malla individual al colocarlos
## (aprendizaje + construcción 2.0). El resto del terreno va
## en el MultiMesh. El nombre viejo se conserva para no tocar
## a sus llamadores; en 2.0 ya no es solo aprendizaje.
func _is_learning_block(block_id: int) -> bool:
	return (block_id >= 10 and block_id <= 21) or (block_id >= 30 and block_id <= 39) or (block_id >= 40 and block_id <= 43) or (block_id >= 50 and block_id <= 76) or block_id == BLOCK_TORCH or block_id == BLOCK_CHEST or block_id == BLOCK_PORTAL or (block_id >= 84 and block_id <= 88)


func _refresh_placed(cell: Vector3i, block_id: int) -> void:
	if _placed.has(cell):
		(_placed[cell] as Node).queue_free()
		_placed.erase(cell)
	if block_id == BLOCK_AIR or not _is_learning_block(block_id):
		return
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = block_color(block_id)
	# Antorcha: luz real (pocas, son retos). Cristal brillo:
	# solo emisión, sin luz puntual, para no cargar el stick
	# si el niño pone muchos cristales.
	mat.emission_enabled = block_id == BLOCK_TORCH or block_id == BLOCK_GLOW
	if mat.emission_enabled:
		mat.emission = Color(0.2, 0.9, 1.0) if block_id == BLOCK_GLOW else Color(1.0, 0.7, 0.2)
	if block_id == BLOCK_TORCH:
		mesh_inst.add_child(_make_point_light())
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(float(cell.x) + 0.5, float(cell.y) + 0.5, float(cell.z) + 0.5)
	var label := block_label(block_id)
	if label != "":
		var lab := Label3D.new()
		lab.text = label
		lab.font_size = 96
		lab.position = Vector3(0.0, 0.0, 0.55)
		mesh_inst.add_child(lab)
	add_child(mesh_inst)
	_placed[cell] = mesh_inst


func _make_point_light() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_energy = 1.2
	light.omni_range = 6.0
	return light


static func block_color(block_id: int) -> Color:
	match block_id:
		BLOCK_GRASS:
			return Color(0.25, 0.65, 0.25)
		BLOCK_DIRT:
			return Color(0.55, 0.40, 0.25)
		BLOCK_STONE:
			return Color(0.50, 0.50, 0.52)
		BLOCK_WOOD:
			return Color(0.45, 0.30, 0.15)
		BLOCK_LEAVES:
			return Color(0.15, 0.55, 0.20)
		BLOCK_WATER:
			return Color(0.20, 0.50, 0.90, 0.6)
		BLOCK_SAND:
			return Color(0.85, 0.78, 0.55)
		BLOCK_FLOWER_RED:
			return Color(0.90, 0.20, 0.30)
		BLOCK_FLOWER_YELLOW:
			return Color(0.95, 0.85, 0.20)
		BLOCK_TORCH:
			return Color(1.0, 0.75, 0.25)
		BLOCK_CHEST:
			return Color(0.65, 0.45, 0.15)
		BLOCK_PORTAL:
			return Color(0.55, 0.20, 0.90)
		BLOCK_PLANKS:
			return Color(0.70, 0.50, 0.30)
		BLOCK_BRICK:
			return Color(0.75, 0.25, 0.20)
		BLOCK_GLASS:
			return Color(0.65, 0.85, 0.95)
		BLOCK_SNOW:
			return Color(0.95, 0.97, 1.0)
		BLOCK_GLOW:
			return Color(0.20, 0.95, 1.0)
		_:
			pass
	if block_id >= 10 and block_id <= 21:
		return COLORES[block_id - 10]
	if block_id >= 30 and block_id <= 39:
		return Color(0.20, 0.45, 0.90)
	if block_id >= 40 and block_id <= 43:
		return Color(0.95, 0.95, 0.95)
	if block_id >= 50 and block_id <= 76:
		return Color(0.90, 0.65, 0.15)
	return Color(0.80, 0.80, 0.80)


static func block_label(block_id: int) -> String:
	if block_id >= 40 and block_id <= 43:
		return ["+", "-", "×", "="][block_id - 40]
	if block_id >= 30 and block_id <= 39:
		return str(block_id - 30)
	if block_id >= 50 and block_id <= 76:
		return LETRAS[block_id - 50]
	match block_id:
		BLOCK_TORCH:
			return "🔥"
		BLOCK_CHEST:
			return "📦"
		BLOCK_PORTAL:
			return "🌀"
		_:
			return ""


## Reconstruye los MultiMesh desde la semilla + modificaciones.
## Árboles: tronco de 3 maderas + copa 3×3×2 de hojas, solo si el
## hash disperso < 0.06 y la columna es hierba (no junto al origen,
## para que el punto de aparición quede despejado).
func rebuild() -> void:
	if _solid == null or _noise == null:
		return
	var solid_transforms: Array[Transform3D] = []
	var solid_colors: Array[Color] = []
	var water_transforms: Array[Transform3D] = []
	for x in range(-render_radius, render_radius + 1):
		for z in range(-render_radius, render_radius + 1):
			var h := terrain_height(x, z)
			for y in range(0, h + 1):
				var cell := Vector3i(x, y, z)
				var key := WorldSeedManager.key_of(cell)
				var block := terrain_block_at(cell)
				if modified_blocks.has(key):
					block = int(modified_blocks[key])
				if block == BLOCK_AIR:
					continue
				var tr := Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(y) + 0.5, float(z) + 0.5))
				if block == BLOCK_WATER:
					water_transforms.append(tr)
				elif block == BLOCK_SNOW and not modified_blocks.has(key):
					# Nieve del terreno de montaña: va en el
					# MultiMesh; la nieve colocada por el jugador
					# ya tiene su malla individual.
					solid_transforms.append(tr)
					solid_colors.append(block_color(block))
				elif not _is_learning_block(block):
					solid_transforms.append(tr)
					solid_colors.append(block_color(block))
			# Decoración 2.0: visual solamente, como los árboles
			# viejos (no entra en get_block). Fuera del origen
			# para que el punto de aparición quede despejado.
			var r := scatter_hash(x, z, seed_value)
			if biome == "playa_mar" and h >= water_level and (abs(x) > 2 or abs(z) > 2) and r < 0.08:
				# Palmera: tronco alto de 4 y copa en cruz.
				for ty in range(h + 1, h + 5):
					solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(ty) + 0.5, float(z) + 0.5)))
					solid_colors.append(block_color(BLOCK_WOOD))
				for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x + off.x) + 0.5, float(h + 5) + 0.5, float(z + off.y) + 0.5)))
					solid_colors.append(block_color(BLOCK_LEAVES))
			elif biome == "bosque_magico" and h > water_level + 1 and (abs(x) > 2 or abs(z) > 2):
				if r < 0.05:
					for ty in range(h + 1, h + 4):
						solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(ty) + 0.5, float(z) + 0.5)))
						solid_colors.append(block_color(BLOCK_WOOD))
					for lx in range(x - 1, x + 2):
						for lz in range(z - 1, z + 2):
							for ly in range(h + 3, h + 5):
								if lx == x and lz == z and ly == h + 3:
									continue
								solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(lx) + 0.5, float(ly) + 0.5, float(lz) + 0.5)))
								solid_colors.append(block_color(BLOCK_LEAVES))
				elif r < 0.10:
					# Seta brillo: un cristal sobre la hierba.
					solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(h) + 1.5, float(z) + 0.5)))
					solid_colors.append(block_color(BLOCK_GLOW))
			elif biome == "montana_nevada" and h > water_level + 1 and (abs(x) > 2 or abs(z) > 2) and r < 0.06:
				# Pino: tronco de 3, copa 3x3 y punta de nieve.
				for ty in range(h + 1, h + 4):
					solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(ty) + 0.5, float(z) + 0.5)))
					solid_colors.append(block_color(BLOCK_WOOD))
				for lx in range(x - 1, x + 2):
					for lz in range(z - 1, z + 2):
						solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(lx) + 0.5, float(h + 4) + 0.5, float(lz) + 0.5)))
						solid_colors.append(block_color(BLOCK_LEAVES))
				solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(h + 5) + 0.5, float(z) + 0.5)))
				solid_colors.append(block_color(BLOCK_SNOW))
			elif h > water_level + 1 and (abs(x) > 2 or abs(z) > 2):
				# Árboles y flores de los biomas viejos y pradera.
				if r < 0.06:
					for ty in range(h + 1, h + 4):
						solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(ty) + 0.5, float(z) + 0.5)))
						solid_colors.append(block_color(BLOCK_WOOD))
					for lx in range(x - 1, x + 2):
						for lz in range(z - 1, z + 2):
							for ly in range(h + 3, h + 5):
								# Sin duplicar la punta del tronco.
								if lx == x and lz == z and ly == h + 3:
									continue
								solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(lx) + 0.5, float(ly) + 0.5, float(lz) + 0.5)))
								solid_colors.append(block_color(BLOCK_LEAVES))
				elif r < 0.12:
					solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(h) + 1.5, float(z) + 0.5)))
					solid_colors.append(block_color(BLOCK_FLOWER_RED if r < 0.09 else BLOCK_FLOWER_YELLOW))
	_set_multimesh(_solid, solid_transforms, solid_colors)
	_set_multimesh(_water, water_transforms, [])


func _set_multimesh(inst: MultiMeshInstance3D, transforms: Array[Transform3D], colors: Array[Color]) -> void:
	var mm := inst.multimesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		if i < colors.size():
			mm.set_instance_color(i, colors[i])
