extends Node
## MusicSystem — audio procedural en vivo: melodía por
## bioma con AudioStreamGenerator (seno con envolvente)
## y foley de un golpe por material (ruido + seno).
## Sin archivos de audio: todo se sintetiza. Volumen
## bajo a propósito (0.15): ambiente, no protagonista.
## En headless (tests) el driver es mudo y no falla: si
## no hay playback, se salta el envío.

class_name MusicSystem

const SAMPLE_RATE := 22000
const VOLUME := 0.15

var current_biome := ""

var _music_player: AudioStreamPlayer = null
var _foley_player: AudioStreamPlayer = null
var _beat_timer := 0.0
var _step := 0


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = AudioStreamGenerator.new()
	(_music_player.stream as AudioStreamGenerator).mix_rate = float(SAMPLE_RATE)
	_music_player.volume_db = linear_to_db(VOLUME)
	add_child(_music_player)
	_foley_player = AudioStreamPlayer.new()
	_foley_player.stream = AudioStreamGenerator.new()
	(_foley_player.stream as AudioStreamGenerator).mix_rate = float(SAMPLE_RATE)
	_foley_player.volume_db = linear_to_db(VOLUME)
	add_child(_foley_player)


func start_biome(biome: String) -> void:
	current_biome = biome
	_step = 0
	_beat_timer = 0.0
	if _music_player != null and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	current_biome = ""
	if _music_player != null:
		_music_player.stop()


func _push(player: AudioStreamPlayer, samples: PackedVector2Array) -> void:
	if player == null or not player.playing:
		return
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	if playback.get_frames_available() < samples.size():
		return
	playback.push_buffer(samples)


## Seno con caída exponencial: freq Hz durante decay s.
static func tone_samples(freq: float, decay: float, volume: float = VOLUME) -> PackedVector2Array:
	var total := int(SAMPLE_RATE * decay)
	var out := PackedVector2Array()
	out.resize(total)
	for i in range(total):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 6.0 / decay)
		var v := sin(TAU * freq * t) * env * volume
		out[i] = Vector2(v, v)
	return out


## Golpe de foley: ruido mezclado con seno según el
## material (noise 0 = tono puro, 1 = ruido puro).
static func foley_samples(params: Dictionary) -> PackedVector2Array:
	var freq := float(params["freq"])
	var decay := float(params["decay"])
	var noise_mix := float(params["noise"])
	var total := int(SAMPLE_RATE * decay)
	var out := PackedVector2Array()
	out.resize(total)
	var seed := 12345
	for i in range(total):
		var t := float(i) / float(SAMPLE_RATE)
		var env := exp(-t * 6.0 / decay)
		seed = (seed * 1103515245 + 12345) % 2147483648
		var noise := (float(seed % 1000) / 500.0) - 1.0
		var v := (sin(TAU * freq * t) * (1.0 - noise_mix) + noise * noise_mix) * env * VOLUME
		out[i] = Vector2(v, v)
	return out


func play_foley_for(block_id: int) -> void:
	var sound := VoxelWorldGenerator.block_sound(block_id)
	var params := MusicData.foley_params(sound)
	if _foley_player != null and not _foley_player.playing:
		_foley_player.play()
	_push(_foley_player, foley_samples(params))


func _process(delta: float) -> void:
	if current_biome == "" or _music_player == null:
		return
	if not _music_player.playing:
		_music_player.play()
		return
	var scale: Dictionary = MusicData.scale_for_biome(current_biome)
	var beats: float = scale["beats"]
	_beat_timer += delta
	var interval := 1.0 / beats
	if _beat_timer >= interval:
		_beat_timer -= interval
		var midi := MusicData.note_for(current_biome, _step)
		_step += 1
		_push(_music_player, tone_samples(MusicData.midi_freq(midi), 0.6))
