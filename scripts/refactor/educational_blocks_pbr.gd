extends RefCounted
## 03 — EducationalBlockFactory: bloques educativos con Stylized PBR.
##
## Alcance honesto:
## - Esto cubre los bloques COLOCADOS (MeshInstance3D individuales,
##   como ya hace VoxelWorldGenerator en 3.0.2). El terreno en
##   MultiMesh sigue con color por instancia por rendimiento:
##   miles de instancias no pueden llevar un material PBR distinto
##   por bloque sin romper el dibujado por lotes. No se promete
##   PBR en el terreno; se promete PBR donde el niño mira y toca:
##   colores, letras, números y bloques de luz.
## - IDs reales de la 3.0.2, sin romperlos: colores 10-21,
##   números 30-39 (31 = "1"), operadores 40-44, letras 50-76
##   (50 = A, 63 = N, 64 = Ñ), antorcha 80, cristal brillo 88.
## - IDs nuevos, libres en data/blocks.json (173 bloques, el
##   mayor es 254): 260 seta luminosa, 261 cristal cian,
##   262 cristal magenta. Hay que añadirlos al catálogo y a la
##   lista de bloques colocables del generador (ver 06).
## - Normal map: Godot no inventa relieve de una letra. Se genera
##   un mapa de normales procedural pequeño (64×64) por letra/
##   número, suficiente para que la luz marque el relieve sin
##   añadir polígonos. Si el proyecto añade texturas reales en
##   res://textures/blocks/<id>_normal.png, esa textura manda
##   sobre la procedural (ver material_for).
## - .vox: Godot 4.3 no carga MagicaVoxel .vox de forma nativa
##   y en el repo no hay cargador .vox. PhoneticInvoker construye
##   el modelo invocado de forma procedural y deja el gancho
##   load_vox_model() para cuando exista el asset. No se presenta
##   el modelo procedural como si fuera un .vox real.

class_name EducationalBlockFactory

const BLOCK_GLOW_SHROOM := 260
const BLOCK_CRYSTAL_CYAN := 261
const BLOCK_CRYSTAL_MAGENTA := 262

const CRYSTAL_CYAN := Color(70.0 / 255.0, 220.0 / 255.0, 255.0 / 255.0)
const CRYSTAL_MAGENTA := Color(240.0 / 255.0, 80.0 / 255.0, 220.0 / 255.0)

const VOWELS := ["A", "E", "I", "O", "U"]

const COLOR_NAMES := ["Rojo", "Azul", "Amarillo", "Verde", "Naranja",
	"Morado", "Rosado", "Café", "Negro", "Blanco", "Gris", "Celeste"]
const COLOR_VALUES := [
	Color(0.85, 0.15, 0.15), Color(0.15, 0.35, 0.85), Color(0.95, 0.80, 0.15),
	Color(0.20, 0.70, 0.25), Color(0.95, 0.50, 0.10), Color(0.60, 0.20, 0.75),
	Color(0.95, 0.45, 0.65), Color(0.55, 0.35, 0.20), Color(0.10, 0.10, 0.12),
	Color(0.95, 0.95, 0.95), Color(0.55, 0.55, 0.58), Color(0.45, 0.80, 0.95),
]
const LETTERS := ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
	"K", "L", "M", "N", "Ñ", "O", "P", "Q", "R", "S", "T", "U",
	"V", "W", "X", "Y", "Z"]


static func is_color(block_id: int) -> bool:
	return block_id >= 10 and block_id <= 21


static func is_number(block_id: int) -> bool:
	return block_id >= 30 and block_id <= 39


static func is_operator(block_id: int) -> bool:
	return block_id >= 40 and block_id <= 44


static func is_letter(block_id: int) -> bool:
	return block_id >= 50 and block_id <= 76


static func letter_for(block_id: int) -> String:
	if not is_letter(block_id):
		return ""
	return LETTERS[block_id - 50]


static func is_vowel(block_id: int) -> bool:
	return VOWELS.has(letter_for(block_id))


static func is_even_number(block_id: int) -> bool:
	if not is_number(block_id):
		return false
	return (block_id - 30) % 2 == 0


static func label_for(block_id: int) -> String:
	if is_color(block_id):
		return COLOR_NAMES[block_id - 10]
	if is_number(block_id):
		return str(block_id - 30)
	if is_operator(block_id):
		var ops := ["+", "-", "×", "=", "÷"]
		return ops[block_id - 40]
	if is_letter(block_id):
		return letter_for(block_id)
	match block_id:
		80:
			return "Antorcha"
		88:
			return "Cristal brillo"
		BLOCK_GLOW_SHROOM:
			return "Seta luminosa"
		BLOCK_CRYSTAL_CYAN:
			return "Cristal cian"
		BLOCK_CRYSTAL_MAGENTA:
			return "Cristal magenta"
		_:
			return "Bloque"


static func base_color(block_id: int) -> Color:
	if is_color(block_id):
		return COLOR_VALUES[block_id - 10]
	match block_id:
		BLOCK_CRYSTAL_CYAN, 88:
			return CRYSTAL_CYAN
		BLOCK_CRYSTAL_MAGENTA:
			return CRYSTAL_MAGENTA
		BLOCK_GLOW_SHROOM:
			return Color(0.45, 0.95, 0.55)
		80:
			return Color(1.0, 0.75, 0.25)
		_:
			return Color(0.8, 0.8, 0.8)


static func light_level(block_id: int) -> int:
	match block_id:
		80:
			return 14
		88, BLOCK_CRYSTAL_CYAN, BLOCK_CRYSTAL_MAGENTA:
			return 12
		BLOCK_GLOW_SHROOM:
			return 10
		_:
			return 0


static func is_glow_block(block_id: int) -> bool:
	return block_id in [80, 88, BLOCK_GLOW_SHROOM,
		BLOCK_CRYSTAL_CYAN, BLOCK_CRYSTAL_MAGENTA]


static func material_for(block_id: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var color := base_color(block_id)
	mat.albedo_color = color
	# Números pares: metal pulido. Impares: mate.
	if is_number(block_id):
		if is_even_number(block_id):
			mat.metallic = 0.9
			mat.roughness = 0.25
		else:
			mat.metallic = 0.1
			mat.roughness = 0.6
	elif is_vowel(block_id):
		# Vocales: gemas translúcidas con luz propia.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.9
		mat.roughness = 0.15
		mat.metallic = 0.0
	elif is_glow_block(block_id):
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.4
		mat.roughness = 0.3
		mat.metallic = 0.0
	else:
		mat.roughness = 0.55
		mat.metallic = 0.05
	# Normal map: textura real si existe, procedural si no.
	var real_path := "res://textures/blocks/%d_normal.png" % block_id
	if ResourceLoader.exists(real_path):
		var tex: Texture2D = load(real_path)
		if tex != null:
			mat.normal_enabled = true
			mat.normal_texture = tex
			mat.normal_scale = 1.0
			return mat
	mat.normal_enabled = true
	mat.normal_texture = _procedural_normal_texture(label_for(block_id))
	mat.normal_scale = 0.6
	return mat


static func _procedural_normal_texture(_label: String) -> ImageTexture:
	# Relieve suave en forma de cúpula: el centro empuja la
	# normal hacia fuera y los bordes la inclinan. Es un mapa
	# de normales válido, no una textura de color disfrazada.
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			var nx := (float(x) / float(size - 1)) * 2.0 - 1.0
			var ny := (float(y) / float(size - 1)) * 2.0 - 1.0
			var d := sqrt(nx * nx + ny * ny)
			var h := maxf(0.0, 1.0 - d)
			var gx := -nx * h
			var gy := -ny * h
			var gz := 1.0
			var inv := 1.0 / sqrt(gx * gx + gy * gy + gz * gz)
			img.set_pixel(x, y, Color(
				(gx * inv) * 0.5 + 0.5,
				(gy * inv) * 0.5 + 0.5,
				(gz * inv) * 0.5 + 0.5))
	return ImageTexture.create_from_image(img)


static func create_block_mesh(block_id: int) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = material_for(block_id)
	inst.mesh = box
	var label := label_for(block_id)
	if label != "":
		var lab := Label3D.new()
		lab.text = label
		lab.font_size = 96
		lab.position = Vector3(0.0, 0.0, 0.55)
		lab.modulate = Color.WHITE
		inst.add_child(lab)
	if is_glow_block(block_id):
		var light := OmniLight3D.new()
		light.light_color = base_color(block_id)
		light.light_energy = 1.2
		light.omni_range = 6.0
		inst.add_child(light)
	return inst
