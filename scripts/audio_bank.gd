extends Node
## Banco de audio interno (F2.2): reproduce clips .ogg grabados con voces
## familiares desde res://audio/<nombre>.ogg.
##
## - Si el clip existe, suena la voz familiar y play_clip() devuelve true.
## - Si el clip NO existe, devuelve false y quien llama usa el respaldo
##   (TTS del sistema + anuncio visual). El juego nunca falla por un
##   clip ausente: la carpeta audio/ puede estar vacía.
## - NUNCA sintetiza ni inventa voces: sin archivo, no hay sonido nuevo.
##   Los clips los graba la familia (ver LISTA-GRABACION.md en la entrega).

const AUDIO_DIR := "res://audio/"

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}


func _ready() -> void:
	for i in range(4):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Reproduce el clip <nombre> (sin extensión; se busca <nombre>.ogg).
## Devuelve true si sonó, false si el archivo no existe o no es audio.
func play_clip(nombre: String) -> bool:
	if nombre == "":
		return false
	var path := AUDIO_DIR + nombre + ".ogg"
	if _cache.has(path):
		var cached = _cache[path]
		if cached == null:
			return false
		_play(cached)
		return true
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return false
	var stream = load(path)
	if stream == null or not (stream is AudioStream):
		_cache[path] = null
		return false
	_cache[path] = stream
	_play(stream)
	return true


func _play(stream: AudioStream) -> void:
	if _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.play()
