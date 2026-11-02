extends Node
## GameModeManager — Creativo Educativo y Supervivencia Cognitiva.
##
## Voces: se reproducen SOLO si el archivo .ogg existe, con el
## mismo contrato que audio_bank.gd de 1.15.0 (play_clip() devuelve
## false si falta). Integración 2026-11-02: audio/ tiene los 105
## .ogg del banco completo (69 de la lista original + 36 extra);
## las 27 letras de LETTER_CLIP resuelven todas. NO se inventa
## ningún clip: cuando falta, el juego muestra el texto en
## pantalla y sigue (degradación con silencio + texto, nunca un
## error). Los extra color_* en inglés y accion_* están en el
## banco pero ningún script de la variante los llama todavía:
## suenan solo cuando un código los pida por audio_bank.
##
## Sin pantallas de castigo: un error en un reto muestra una
## pista visual y auditiva suave, sube la prioridad del ítem en
## SpacedRepetitionManager y deja seguir jugando. No hay «game
## over», no se quitan estrellas por fallar.
##
## Modelos 3D invocados: procedurales (esfera sol, cajas casa,
## cilindro + esfera árbol), no arte final. Son modelos reales
## que aparecen en el mundo, no placeholders vacíos: el arte
## definitivo queda como trabajo pendiente, documentado.

class_name GameModeManager

enum Mode { CREATIVE, SURVIVAL }

signal mode_changed(mode: Mode)
signal energy_changed(value: int)
signal message_shown(text: String)
signal word_invoked(word: String)
signal math_solved(expression: String, result: int)
signal feynman_request(text: String)

const WORDS := {
	"SOL": ["S", "O", "L"],
	"CASA": ["C", "A", "S", "A"],
	"ARBOL": ["A", "R", "B", "O", "L"],
	"PUENTE": ["P", "U", "E", "N", "T", "E"],
}
const LETTER_CLIP := {
	"A": "letra_a", "B": "letra_b", "C": "letra_c", "D": "letra_d",
	"E": "letra_e", "F": "letra_f", "G": "letra_g", "H": "letra_h",
	"I": "letra_i", "J": "letra_j", "K": "letra_k", "L": "letra_l",
	"M": "letra_m", "N": "letra_n", "Ñ": "letra_nn", "O": "letra_o",
	"P": "letra_p", "Q": "letra_q", "R": "letra_r", "S": "letra_s",
	"T": "letra_t", "U": "letra_u", "V": "letra_v", "W": "letra_w",
	"X": "letra_x", "Y": "letra_y", "Z": "letra_z",
}

var mode := Mode.CREATIVE
var energy := 100
var inventory: Dictionary = {} # block_id -> cantidad (Supervivencia)
var time_of_day := 10.0 # 0..24; noche = < 6 o >= 19.
var feynman_active := false

var _audio_bank = null
var _world: Node3D = null
var _repetition := SpacedRepetitionManager.new()


func _ready() -> void:
	_audio_bank = load("res://scripts/audio_bank.gd").new()
	add_child(_audio_bank)


func setup(world: Node3D) -> void:
	_world = world


func set_mode(value: Mode) -> void:
	mode = value
	if mode == Mode.CREATIVE:
		energy = 100
		energy_changed.emit(energy)
	mode_changed.emit(mode)


func is_night() -> bool:
	return time_of_day < 6.0 or time_of_day >= 19.0


func advance_time(hours: float) -> void:
	time_of_day = fmod(time_of_day + hours, 24.0)
	if is_night() and not feynman_active:
		feynman_active = true
		# Método Feynman en 2ª persona: la mascota pide ayuda, no
		# castiga. El jugador recarga antorchas y recupera energía.
		feynman_request.emit("¡Ayúdame a recargar las antorchas! Pon antorchas para recuperar energía.")
		message_shown.emit("De noche aparecen retos brillantes. ¡Ayuda a tu mascota!")


func complete_feynman_help(torch_count: int) -> void:
	if not feynman_active:
		return
	feynman_active = false
	energy = mini(100, energy + 10 * torch_count)
	energy_changed.emit(energy)
	message_shown.emit("¡Gracias! Energía recuperada.")


## Voz si existe; si no, texto. Devuelve true si sonó.
func speak_clip(clip: String, fallback_text: String) -> bool:
	if _audio_bank != null and _audio_bank.play_clip(clip):
		return true
	if fallback_text != "":
		message_shown.emit(fallback_text)
	return false


## Supervivencia: colocar cuesta 1 de inventario (si hay); en
## Creativo los bloques son infinitos y no se descuenta nada.
func can_place(block_id: int) -> bool:
	if mode == Mode.CREATIVE:
		return true
	return int(inventory.get(block_id, 0)) > 0


func consume_place(block_id: int) -> bool:
	if mode == Mode.CREATIVE:
		return true
	var count := int(inventory.get(block_id, 0))
	if count <= 0:
		return false
	inventory[block_id] = count - 1
	return true


func collect(block_id: int, amount: int = 1) -> void:
	inventory[block_id] = int(inventory.get(block_id, 0)) + amount


## Detecta una palabra formada por bloques de letras en fila
## horizontal (este-oeste) a partir de cells (Vector3i -> letra).
## Devuelve la palabra o "". No usa clips inexistentes como
## prueba: la palabra se detecta por letras, la voz es aparte.
static func detect_word(row_letters: Array) -> String:
	var text := ""
	for letter in row_letters:
		text += str(letter)
	for word in WORDS.keys():
		if text.contains(word):
			return word
	return ""


## Invocación semántica: suena cada letra (si su clip existe),
## luego acorde triunfal, partículas y modelo procedural.
func invoke_word(word: String, origin: Vector3) -> void:
	for letter in WORDS[word]:
		speak_clip(LETTER_CLIP[letter], letter)
	_play_triumph_chord()
	_spawn_particles(origin)
	_spawn_word_model(word, origin)
	word_invoked.emit(word)
	message_shown.emit("¡" + word + "!")


## Detecta [n] [op] [m] [=] en fila. Devuelve [expresión, resultado]
## o ["", 0] si no es una operación válida.
static func detect_math(tokens: Array) -> Array:
	# tokens: [3, "+", 2, "="] como strings.
	if tokens.size() != 4 or tokens[3] != "=":
		return ["", 0]
	if not tokens[0].is_valid_int() or not tokens[2].is_valid_int():
		return ["", 0]
	var a := int(tokens[0])
	var b := int(tokens[2])
	match tokens[1]:
		"+":
			return ["%d + %d" % [a, b], a + b]
		"-":
			return ["%d - %d" % [a, b], a - b]
		"x", "*":
			return ["%d x %d" % [a, b], a * b]
		_:
			return ["", 0]


## Torre de [resultado] bloques brillantes + voz (o texto).
func solve_math(tokens: Array, origin: Vector3) -> void:
	var result := detect_math(tokens)
	if result[0] == "":
		return
	var expr: String = result[0]
	var value: int = result[1]
	_play_triumph_chord()
	for i in range(value):
		_spawn_glowing_block(origin + Vector3(0.0, float(i), 0.0))
	math_solved.emit(expr, value)
	message_shown.emit(expr + " = " + str(value) + " ¡Torre de " + str(value) + " bloques!")
	for item in [tokens[0], tokens[2]]:
		_repetition.record_hit("numero_" + item)


## Reto de entorno: la fisura pide 4 + 3; el puente pide PUENTE.
## Devuelve true si está resuelto. Un fallo da pista, no castigo.
func check_challenge(challenge_id: String, answer: String) -> bool:
	match challenge_id:
		"fisura_4_3":
			if answer.strip_edges() == "7":
				_repetition.record_hit("suma_4+3")
				message_shown.emit("¡Correcto! 4 + 3 = 7. La fisura se abre.")
				return true
			_repetition.record_miss("suma_4+3")
			message_shown.emit("Pista: 4 + 3… cuenta 4 y luego 3 más. ¡Inténtalo de nuevo!")
			return false
		"puente":
			if answer.strip_edges().to_upper() == "PUENTE":
				_repetition.record_hit("palabra_PUENTE")
				message_shown.emit("¡Correcto! El puente está completo.")
				return true
			_repetition.record_miss("palabra_PUENTE")
			message_shown.emit("Pista: P-U-E-N-T-E. ¡Casi lo tienes!")
			return false
		_:
			return false


## Próximos retos priorizando lo que más costó (sin repetir lo
## último si hay alternativa).
func next_challenges(candidates: Array) -> Array:
	return _repetition.pick_next(candidates)


func _play_triumph_chord() -> void:
	# Acorde mayor simple con tonos generados (C-E-G), sin
	# depender de ningún archivo de audio.
	for freq in [523.25, 659.25, 783.99]:
		var player := AudioStreamPlayer.new()
		player.stream = _make_tone(freq, 0.6)
		add_child(player)
		player.play()


func _make_tone(freq: float, duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var samples := int(sample_rate * duration)
	var data := PackedByteArray()
	for i in range(samples):
		var t := float(i) / float(sample_rate)
		var v := sin(TAU * freq * t) * 0.5 * (1.0 - float(i) / float(samples))
		var s := int(v * 32767)
		data.append(s & 0xFF)
		data.append((s >> 8) & 0xFF)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav


func _spawn_particles(origin: Vector3) -> void:
	if _world == null:
		return
	var particles := GPUParticles3D.new()
	particles.position = origin + Vector3(0.5, 1.0, 0.5)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 45.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0.0, -4.0, 0.0)
	particles.process_material = mat
	_world.add_child(particles)


func _spawn_word_model(word: String, origin: Vector3) -> void:
	if _world == null:
		return
	var root := Node3D.new()
	root.position = origin + Vector3(0.5, 1.5, 0.5)
	match word:
		"SOL":
			var sun := MeshInstance3D.new()
			sun.mesh = SphereMesh.new()
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(1.0, 0.85, 0.2)
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.8, 0.2)
			sun.material_override = mat
			root.add_child(sun)
		"CASA":
			var base := MeshInstance3D.new()
			base.mesh = BoxMesh.new()
			base.scale = Vector3(1.6, 1.2, 1.6)
			root.add_child(base)
			var roof := MeshInstance3D.new()
			roof.mesh = BoxMesh.new()
			roof.scale = Vector3(1.9, 0.6, 1.9)
			roof.rotation.z = deg_to_rad(30.0)
			roof.position.y = 0.9
			var roof_mat := StandardMaterial3D.new()
			roof_mat.albedo_color = Color(0.8, 0.2, 0.2)
			roof.material_override = roof_mat
			root.add_child(roof)
		_:
			# ÁRBOL y resto: tronco + copa (modelo procedural).
			var trunk := MeshInstance3D.new()
			trunk.mesh = CylinderMesh.new()
			trunk.scale = Vector3(0.4, 1.4, 0.4)
			trunk.position.y = 0.2
			root.add_child(trunk)
			var top := MeshInstance3D.new()
			top.mesh = SphereMesh.new()
			top.scale = Vector3(1.4, 1.4, 1.4)
			top.position.y = 1.4
			var leaf_mat := StandardMaterial3D.new()
			leaf_mat.albedo_color = Color(0.2, 0.65, 0.25)
			top.material_override = leaf_mat
			root.add_child(top)
	_world.add_child(root)


func _spawn_glowing_block(pos: Vector3) -> void:
	if _world == null:
		return
	var block := MeshInstance3D.new()
	block.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	block.material_override = mat
	block.position = pos
	_world.add_child(block)
