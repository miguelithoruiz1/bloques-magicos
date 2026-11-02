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
# Nuevos en 3.0 (Taller): estrella, corazón, farol y sílaba
# MA solo se consiguen fabricando; 44 es la división (banda
# 13+). Fuera de los rangos de aprendizaje para no romperlos.
const BLOCK_DIVIDE := 44
const BLOCK_STAR := 90
const BLOCK_HEART := 91
const BLOCK_LANTERN := 92
const BLOCK_SYLLABLE_MA := 93
# 3.0: bloques del catálogo (data/blocks.json v2, ids 100+).
const BLOCK_BEDROCK := 144
const BLOCK_COAL_ORE := 145
const BLOCK_COPPER_ORE := 146
const BLOCK_TIN_ORE := 147
const BLOCK_IRON_ORE := 148
const BLOCK_SILVER_ORE := 149
const BLOCK_GOLD_ORE := 150
const BLOCK_SULFUR := 151
const BLOCK_GYPSUM := 152
const BLOCK_CHRONOLITE := 153
const BLOCK_LAVA := 203
const BLOCK_MUSHROOM_RED := 230

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


## Ruidos perezosos: terrain_height es pura respecto a
## seed/bioma y debe funcionar sin _ready (tests headless,
## mundos creados con .new()). _ready los reutiliza.
func _ensure_noise() -> void:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.08
	if _noise_detail == null:
		_noise_detail = FastNoiseLite.new()
		_noise_detail.noise_type = FastNoiseLite.TYPE_PERLIN
		_noise_detail.frequency = 0.25


func _ready() -> void:
	_ensure_noise()
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
	# 3.0: los 26 especiales por anillo son datos, no código.
	if BiomesSpecial.is_special(biome_name):
		return BiomesSpecial.params_for(biome_name)
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
		# Biomas base 3.0 del documento (11 base en total).
		"oceano":
			return Vector3(0.0, 1.0, 0.0)
		"rio":
			return Vector3(1.0, 1.0, 0.0)
		"pantano":
			return Vector3(2.0, 1.0, 0.0)
		"tundra_nevada":
			return Vector3(2.0, 3.0, 0.0)
		"sabana":
			return Vector3(2.0, 2.0, 0.0)
		"desierto":
			return Vector3(1.0, 2.0, 0.0)
		"jungla":
			return Vector3(3.0, 3.0, 0.0)
		_:
			return Vector3(2.0, 4.0, 0.0)


func generate(seed: int, biome_name: String, radius: int = -1) -> void:
	seed_value = seed
	biome = biome_name
	if radius > 0:
		render_radius = radius
	_ensure_noise()
	_noise.seed = seed_value
	_noise_detail.seed = seed_value + 7919
	modified_blocks.clear()
	_clear_placed()
	rebuild()


## Altura del terreno en (x, z), solo con la semilla (sin cambios
## del jugador). Función pura respecto a seed/biome: el guardado
## no necesita el terreno, solo el diferencial.
func terrain_height(x: int, z: int) -> int:
	_ensure_noise()
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


## Hash 3D para vetas (misma mezcla, con el término Y).
static func scatter_hash3(x: int, y: int, z: int, seed: int) -> float:
	var h := (x * 73856093) ^ (y * 83492791) ^ (z * 19349663) ^ (seed * 2971215073)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(abs(h % 1000)) / 1000.0


## Veta subterránea por bandas de profundidad (documento §4,
## adaptado a nuestra altura 0-14: la profundidad es h - y).
## Umbrales del documento (th): carbón .67, cobre .72,
## estaño/hierro .75, plata .80, oro .84. Una sola tirada
## por celda, de la más rara a la más común; 0 = sin veta.
static func ore_vein_at(x: int, y: int, z: int, depth: int, seed: int) -> int:
	if depth < 2:
		return 0
	var roll := scatter_hash3(x, y, z, seed)
	# De la más rara (.90) a la más común (.67).
	if depth >= 10 and roll > 0.90:
		return BLOCK_CHRONOLITE
	if depth >= 8 and roll > 0.84:
		return BLOCK_GOLD_ORE
	if depth >= 7 and roll > 0.85:
		return BLOCK_SULFUR
	if depth >= 5 and roll > 0.85:
		return BLOCK_GYPSUM
	if depth >= 6 and roll > 0.80:
		return BLOCK_SILVER_ORE
	if depth >= 4 and roll > 0.75:
		return BLOCK_IRON_ORE
	if depth >= 3 and roll > 0.75:
		return BLOCK_TIN_ORE
	if depth >= 3 and roll > 0.72:
		return BLOCK_COPPER_ORE
	if roll > 0.67:
		return BLOCK_COAL_ORE
	return 0


## Ruido de valor 3D puro (sin estado): interpolación
## trilineal de la rejilla scatter_hash3, escala 6. Sirve
## para cuevas conectadas, no para agujeros sueltos: el
## ruido blanco daría queso suizo, el valor da túneles.
static func cave_noise(x: int, y: int, z: int, seed: int) -> float:
	var fx := float(x) / 6.0
	var fy := float(y) / 6.0
	var fz := float(z) / 6.0
	var x0 := floori(fx)
	var y0 := floori(fy)
	var z0 := floori(fz)
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	var tz := fz - float(z0)
	var sx := tx * tx * (3.0 - 2.0 * tx)
	var sy := ty * ty * (3.0 - 2.0 * ty)
	var sz := tz * tz * (3.0 - 2.0 * tz)
	var c000 := scatter_hash3(x0, y0, z0, seed)
	var c100 := scatter_hash3(x0 + 1, y0, z0, seed)
	var c010 := scatter_hash3(x0, y0 + 1, z0, seed)
	var c110 := scatter_hash3(x0 + 1, y0 + 1, z0, seed)
	var c001 := scatter_hash3(x0, y0, z0 + 1, seed)
	var c101 := scatter_hash3(x0 + 1, y0, z0 + 1, seed)
	var c011 := scatter_hash3(x0, y0 + 1, z0 + 1, seed)
	var c111 := scatter_hash3(x0 + 1, y0 + 1, z0 + 1, seed)
	var x00 := lerpf(c000, c100, sx)
	var x10 := lerpf(c010, c110, sx)
	var x01 := lerpf(c001, c101, sx)
	var x11 := lerpf(c011, c111, sx)
	var y0v := lerpf(x00, x10, sy)
	var y1v := lerpf(x01, x11, sy)
	return lerpf(y0v, y1v, sz)


## Umbral de cueva por estrato (documento §2, 3 estratos):
## arriba raro, abajo más frecuente. 0-14 es nuestra
## escala (el documento usa 0-192).
static func cave_threshold(y: int) -> float:
	if y >= 8:
		return 0.68
	if y >= 4:
		return 0.64
	return 0.60


static func cave_at(x: int, y: int, z: int, seed: int) -> bool:
	return cave_noise(x, y, z, seed) > cave_threshold(y)


## Tema de cueva por columna (documento §2, 5 temas
## adaptados a 4): normal, cristal, hongo y magma.
static func cave_theme(x: int, z: int, seed: int) -> String:
	var roll := scatter_hash(x + 5011, z, seed)
	if roll < 0.60:
		return "normal"
	if roll < 0.75:
		return "cristal"
	if roll < 0.90:
		return "hongo"
	return "magma"


## Estructura en la columna (documento §2): torre,
## obelisco, portal, árbol o ruina. Solo el tipo: la
## altura y el agua se comprueban en terrain_block_at.
## Densidad 3% por columna, fuera del radio 3 del origen.
static func structure_at(x: int, z: int, seed: int) -> String:
	if abs(x) < 3 and abs(z) < 3:
		return ""
	if scatter_hash(x, z, seed) >= 0.03:
		return ""
	var roll := scatter_hash(x + 1000, z, seed)
	if roll < 0.25:
		return "torre"
	if roll < 0.50:
		return "obelisco"
	if roll < 0.75:
		return "portal"
	if roll < 0.90:
		return "arbol"
	return "ruina"


func terrain_block_at(cell: Vector3i) -> int:
	if cell.y < 0:
		return BLOCK_STONE
	var h := terrain_height(cell.x, cell.z)
	if cell.y > h:
		# 3.0 estructuras sobre la superficie (tierra seca).
		# La propia manda sobre la vecina.
		if h > water_level:
			var own := structure_at(cell.x, cell.z, seed_value)
			if own == "torre":
				if cell.y <= h + 3:
					return BLOCK_STONE
				if cell.y == h + 4:
					return BLOCK_TORCH
			elif own == "obelisco":
				if cell.y <= h + 2:
					return 187
				if cell.y == h + 3:
					return BLOCK_GLOW
			elif own == "portal":
				if cell.y <= h + 2:
					return BLOCK_PORTAL
			elif own == "arbol":
				if cell.y <= h + 3:
					return 154
				if cell.y == h + 4:
					return 155
			elif own == "ruina":
				if cell.y <= h + 2:
					return 187
			# Árbol y ruina miran a los centros vecinos.
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					var ntype := structure_at(cell.x + dx, cell.z + dz, seed_value)
					if ntype == "":
						continue
					var th := terrain_height(cell.x + dx, cell.z + dz)
					if th <= water_level:
						continue
					if ntype == "arbol":
						if cell.y == th + 3:
							return 155
					elif ntype == "ruina":
						if cell.y == th + 1:
							return BLOCK_STONE
		if cell.y <= water_level and h <= water_level:
			return BLOCK_WATER
		return BLOCK_AIR
	if cell.y == h:
		# 3.0: los especiales por anillo mandan su superficie.
		if BiomesSpecial.is_special(biome):
			return BiomesSpecial.surface_for(biome)
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
		# 3.0: roca madre en el fondo, indestructible.
		return BLOCK_BEDROCK
	# 3.0: cuevas bajo la superficie (se conservan la
	# superficie y una capa de techo: se entra picando
	# hacia abajo o volando; el suelo por columna no
	# soporta techos transitables).
	if cell.y <= h - 2 and cave_at(cell.x, cell.y, cell.z, seed_value):
		return BLOCK_AIR
	# 3.0: vetas minerales en la banda de tierra.
	var vein := ore_vein_at(cell.x, cell.y, cell.z, h - cell.y, seed_value)
	if vein != 0:
		return vein
	# 3.0: tema de cueva en las paredes de tierra junto
	# al aire de cueva (no pisa vetas).
	if cell.y < h - 1:
		var theme := cave_theme(cell.x, cell.z, seed_value)
		if theme != "normal":
			var near_cave := false
			var offsets: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
			for d in offsets:
				var n := cell + d
				if n.y >= 1 and n.y <= h - 2 and cave_at(n.x, n.y, n.z, seed_value):
					near_cave = true
					break
			if near_cave:
				var roll := scatter_hash3(cell.x, cell.y, cell.z, seed_value)
				if theme == "cristal" and roll < 0.20:
					return BLOCK_GLOW
				if theme == "hongo" and roll < 0.20:
					return BLOCK_MUSHROOM_RED
				if theme == "magma" and cell.y <= 3 and roll < 0.30:
					return BLOCK_LAVA
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
	return (block_id >= 10 and block_id <= 21) or (block_id >= 30 and block_id <= 39) or (block_id >= 40 and block_id <= 44) or (block_id >= 50 and block_id <= 76) or block_id == BLOCK_TORCH or block_id == BLOCK_CHEST or block_id == BLOCK_PORTAL or (block_id >= 84 and block_id <= 88) or (block_id >= 90 and block_id <= 93)


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
	mat.emission_enabled = block_id == BLOCK_TORCH or block_id == BLOCK_GLOW or block_id == BLOCK_STAR or block_id == BLOCK_LANTERN
	if mat.emission_enabled:
		if block_id == BLOCK_GLOW:
			mat.emission = Color(0.2, 0.9, 1.0)
		elif block_id == BLOCK_STAR or block_id == BLOCK_LANTERN:
			mat.emission = Color(1.0, 0.85, 0.2)
		else:
			mat.emission = Color(1.0, 0.7, 0.2)
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


## Caché estática del catálogo para block_color/block_label:
## se carga una vez (el rebuild llama a block_color por celda).
static var _catalog_cache: Dictionary = {}


static func _catalog_entry(block_id: int) -> Dictionary:
	if _catalog_cache.is_empty():
		_catalog_cache = BlockCatalog.load_catalog()
	if _catalog_cache.has(block_id):
		return _catalog_cache[block_id]
	return {}


## Bloques indestructibles del catálogo (dureza < 0, ids 3.0):
## roca madre, lava y líquidos. Los viejos (aire, agua,
## portal) mantienen su comportamiento anterior.
static func is_unbreakable(block_id: int) -> bool:
	if block_id < 100:
		return false
	var entry := _catalog_entry(block_id)
	if entry.is_empty():
		return false
	return float(entry["hardness"]) < 0.0


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
		BLOCK_STAR:
			return Color(1.0, 0.85, 0.20)
		BLOCK_HEART:
			return Color(0.90, 0.20, 0.30)
		BLOCK_LANTERN:
			return Color(1.0, 0.75, 0.25)
		BLOCK_SYLLABLE_MA:
			return Color(0.65, 0.30, 0.85)
		_:
			pass
	if block_id >= 10 and block_id <= 21:
		return COLORES[block_id - 10]
	if block_id >= 30 and block_id <= 39:
		return Color(0.20, 0.45, 0.90)
	if block_id >= 40 and block_id <= 44:
		return Color(0.95, 0.95, 0.95)
	if block_id >= 50 and block_id <= 76:
		return Color(0.90, 0.65, 0.15)
	# 3.0: bloques del catálogo (ids 100+) con su color.
	if block_id >= 100:
		var entry := _catalog_entry(block_id)
		if not entry.is_empty():
			var c: Array = entry["color"]
			if c.size() >= 3:
				return Color(float(c[0]), float(c[1]), float(c[2]))
	return Color(0.80, 0.80, 0.80)


static func block_sound(block_id: int) -> String:
	var entry := _catalog_entry(block_id)
	return str(entry.get("sound", ""))


static func block_label(block_id: int) -> String:
	# 3.0: bloques del catálogo con su nombre.
	if block_id >= 100:
		var entry := _catalog_entry(block_id)
		if not entry.is_empty():
			return str(entry["name"])
	if block_id >= 40 and block_id <= 44:
		return ["+", "-", "×", "=", "÷"][block_id - 40]
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
		BLOCK_STAR:
			return "⭐"
		BLOCK_HEART:
			return "♥"
		BLOCK_LANTERN:
			return "🏮"
		BLOCK_SYLLABLE_MA:
			return "MA"
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
			elif BiomesSpecial.is_special(biome) and h > water_level + 1 and (abs(x) > 2 or abs(z) > 2):
				# 3.0: decoración del especial por anillo, según
				# su decor (palma, pino, seta brillo, cactus,
				# ninguna o genérico). Patrones reutilizados del
				# generador, no arte nuevo.
				var decor := BiomesSpecial.decor_for(biome)
				if decor == "palma" and r < 0.08:
					for ty in range(h + 1, h + 5):
						solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(ty) + 0.5, float(z) + 0.5)))
						solid_colors.append(block_color(BLOCK_WOOD))
					for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x + off.x) + 0.5, float(h + 5) + 0.5, float(z + off.y) + 0.5)))
						solid_colors.append(block_color(BLOCK_LEAVES))
				elif decor == "pino" and r < 0.06:
					for ty in range(h + 1, h + 4):
						solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(ty) + 0.5, float(z) + 0.5)))
						solid_colors.append(block_color(BLOCK_WOOD))
					for lx in range(x - 1, x + 2):
						for lz in range(z - 1, z + 2):
							solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(lx) + 0.5, float(h + 4) + 0.5, float(lz) + 0.5)))
							solid_colors.append(block_color(BLOCK_LEAVES))
					solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(h + 5) + 0.5, float(z) + 0.5)))
					solid_colors.append(block_color(BLOCK_SNOW))
				elif decor == "seta_brillo" and r < 0.10:
					solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(h) + 1.5, float(z) + 0.5)))
					solid_colors.append(block_color(BLOCK_GLOW))
				elif decor == "cactus" and r < 0.08:
					for ty in range(h + 1, h + 3):
						solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(ty) + 0.5, float(z) + 0.5)))
						solid_colors.append(block_color(BLOCK_LEAVES))
				elif decor == "ninguna":
					pass
				elif r < 0.06:
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
				elif r < 0.12:
					solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(h) + 1.5, float(z) + 0.5)))
					solid_colors.append(block_color(BLOCK_FLOWER_RED if r < 0.09 else BLOCK_FLOWER_YELLOW))
			elif biome == "desierto" and h > water_level + 1 and (abs(x) > 2 or abs(z) > 2) and r < 0.08:
				# Cactus del desierto: columna verde de 2.
				for ty in range(h + 1, h + 3):
					solid_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x) + 0.5, float(ty) + 0.5, float(z) + 0.5)))
					solid_colors.append(block_color(BLOCK_LEAVES))
			elif biome == "tundra_nevada" and h > water_level + 1 and (abs(x) > 2 or abs(z) > 2) and r < 0.06:
				# Pino nevado de la tundra, como en montaña.
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
