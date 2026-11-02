extends Node
## 05 — NeuroManager: SRS + Feynman + BioRhythm + Growth Mindset.
##
## Qué cambia respecto a la 3.0.2:
## - SpacedRepetitionManager ya existe, pero NO agenda por días:
##   solo ordena por prioridad (fallos × 3 − aciertos). Aquí se
##   mantiene esa prioridad y se AÑADE la agenda 1 / 3 / 7 días
##   que pide el GDD. La migración lee el archivo viejo
##   (user://spaced_repetition.json) y lo convierte: un ítem
##   con last_miss = true queda vencido hoy; sin fallo reciente,
##   queda programado a 3 días. El archivo viejo no se borra.
## - Feynman ya existe como señal nocturna en GameModeManager
##   ("ayúdame a recargar antorchas"), pero NO cambia la cámara
##   a 2ª persona ni pide explicar un mecanismo paso a paso.
##   Aquí FeynmanCompanion pide la cámara 2ª y emite pasos.
## - BioRhythmTimer NO existe en la 3.0.2. Se crea aquí:
##   Pomodoro 15 / 20 / 25 min según perfil, pausa activa y
##   transición nocturna (señal, no pantalla de bloqueo).
## - GrowthMindsetFeedback NO existe como archivo. Se crea aquí
##   como función pura: nunca castiga, nunca resta, nunca muestra
##   "game over". Un fallo solo sube la prioridad SRS y devuelve
##   una pista concreta.
##
## Persistencia: user://neuro_srs.json (nuevo) + personaje.json
## para el Pomodoro. No toca progreso.json ni el personaje de
## juego. Todo es local, sin cuentas ni internet.

class_name NeuroManager

signal srs_due_ready(items: Array)
signal feynman_requested(prompt: String, steps: Array)
signal feynman_completed(steps_done: int)
signal pomodoro_focus_ended()
signal pomodoro_break_ended()
signal active_break_requested(activity: String)
signal night_transition_requested(is_night: bool)
signal feedback_shown(text: String, kind: String)

const SRS_PATH := "user://neuro_srs.json"
const OLD_SRS_PATH := "user://spaced_repetition.json"

# Agenda: tras un fallo, el reto vuelve a los 1, 3 y 7 días.
# Tras un acierto, se alarga un paso; tras 3 aciertos seguidos
# el ítem se considera consolidado y sale de la cola diaria.
const SRS_INTERVALS_DAYS := [1, 3, 7]
const SECONDS_PER_DAY := 86400.0

const BREAK_ACTIVITIES := [
	"Salta 10 veces frente al televisor para recargar tus cristales",
	"Estira los brazos hacia arriba y respira 3 veces despacio",
	"Camina hasta la puerta y vuelve, como si exploraras el mapa",
	"Baila 30 segundos con tu mascota del juego",
]

var profile: CognitiveProfile = null
var _srs: Dictionary = {}
var _pomodoro_time_left := 0.0
var _pomodoro_running := false
var _pomodoro_in_break := false
var _break_index := 0
var _feynman_active := false
var _feynman_steps: Array = []
var _feynman_step_index := 0


func _ready() -> void:
	if profile == null:
		profile = CognitiveProfile.load_or_create()
	_load_srs()
	_reset_pomodoro()


func setup(p: CognitiveProfile) -> void:
	profile = p
	_load_srs()
	_reset_pomodoro()


# ---------------- SRS: repetición espaciada 1 / 3 / 7 días ----------------

func _load_srs() -> void:
	_srs = {}
	if FileAccess.file_exists(SRS_PATH):
		var file := FileAccess.open(SRS_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				_srs = parsed
				return
	# Migración desde el SRS viejo (prioridad, sin fechas).
	if FileAccess.file_exists(OLD_SRS_PATH):
		var file2 := FileAccess.open(OLD_SRS_PATH, FileAccess.READ)
		if file2 != null:
			var parsed2: Variant = JSON.parse_string(file2.get_as_text())
			file2.close()
			if typeof(parsed2) == TYPE_DICTIONARY:
				var now := Time.get_unix_time_from_system()
				for item in parsed2.keys():
					var old: Dictionary = parsed2[item]
					var last_miss := bool(old.get("last_miss", false))
					_srs[str(item)] = {
						"hit": int(old.get("hit", 0)),
						"miss": int(old.get("miss", 0)),
						"stage": 0,
						"due": now if last_miss else now + 3.0 * SECONDS_PER_DAY,
						"streak": 0,
					}
				_save_srs()


func _save_srs() -> bool:
	var file := FileAccess.open(SRS_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_srs, "\t"))
	file.close()
	return true


func _ensure_item(item: String) -> Dictionary:
	if not _srs.has(item):
		_srs[item] = {"hit": 0, "miss": 0, "stage": 0,
			"due": Time.get_unix_time_from_system(), "streak": 0}
	return _srs[item]


func record_hit(item: String) -> void:
	var s := _ensure_item(item)
	s["hit"] = int(s["hit"]) + 1
	s["streak"] = int(s["streak"]) + 1
	if int(s["streak"]) >= 3:
		# Consolidado: fuera de la cola diaria, pero no borrado.
		s["due"] = Time.get_unix_time_from_system() + 30.0 * SECONDS_PER_DAY
		s["stage"] = SRS_INTERVALS_DAYS.size()
	else:
		var stage := mini(int(s["stage"]) + 1, SRS_INTERVALS_DAYS.size() - 1)
		s["stage"] = stage
		s["due"] = Time.get_unix_time_from_system() + float(SRS_INTERVALS_DAYS[stage]) * SECONDS_PER_DAY
	_save_srs()


func record_miss(item: String) -> void:
	# Un fallo NUNCA resta puntos ni bloquea. Solo reprograma:
	# vuelve mañana (1 día), luego a los 3 y a los 7 días.
	var s := _ensure_item(item)
	s["miss"] = int(s["miss"]) + 1
	s["streak"] = 0
	s["stage"] = 0
	s["due"] = Time.get_unix_time_from_system() + float(SRS_INTERVALS_DAYS[0]) * SECONDS_PER_DAY
	_save_srs()


func due_items() -> Array:
	var now := Time.get_unix_time_from_system()
	var out: Array = []
	for item in _srs.keys():
		if float(_srs[item].get("due", 0.0)) <= now:
			out.append(str(item))
	# Orden determinista: primero los que más costaron
	# (más fallos, menos aciertos), luego alfabético.
	out.sort_custom(func(a: String, b: String) -> bool:
		var sa: Dictionary = _srs[a]
		var sb: Dictionary = _srs[b]
		var pa := int(sa.get("miss", 0)) * 3 - int(sa.get("hit", 0))
		var pb := int(sb.get("miss", 0)) * 3 - int(sb.get("hit", 0))
		if pa != pb:
			return pa > pb
		return a < b)
	return out


func pick_next(candidates: Array) -> Array:
	# Los vencidos primero; el resto, en el orden dado.
	var due := due_items()
	var due_set := {}
	for item in due:
		due_set[item] = true
	var out: Array = []
	for item in due:
		if candidates.has(item):
			out.append(item)
	for item in candidates:
		if not due_set.has(item):
			out.append(item)
	return out


func notify_due() -> void:
	var due := due_items()
	if not due.is_empty():
		srs_due_ready.emit(due)


# ---------------- Feynman: la mascota pide que le enseñes ----------------

func start_feynman(challenge: String, steps: Array) -> void:
	_feynman_active = true
	_feynman_steps = steps.duplicate()
	_feynman_step_index = 0
	# La escena principal debe responder a esta señal poniendo
	# la cámara en 2ª persona (Espejo Feynman): la cámara mira
	# al jugador desde la mascota. Este manager no mueve cámaras
	# directamente para no duplicar el controlador de cámara.
	feynman_requested.emit(
		"¡Ayúdame a entender esto! Explícame paso a paso: " + challenge,
		_feynman_steps)


func feynman_next_step() -> String:
	if not _feynman_active or _feynman_step_index >= _feynman_steps.size():
		return ""
	var step: String = str(_feynman_steps[_feynman_step_index])
	_feynman_step_index += 1
	if _feynman_step_index >= _feynman_steps.size():
		_feynman_active = false
		feynman_completed.emit(_feynman_steps.size())
	return step


func feynman_is_active() -> bool:
	return _feynman_active


# ---------------- BioRhythm: Pomodoro + pausa activa + noche ----------------

func _reset_pomodoro() -> void:
	var minutes := 15
	if profile != null:
		minutes = profile.pomodoro_minutes
	_pomodoro_time_left = float(minutes) * 60.0
	_pomodoro_running = true
	_pomodoro_in_break = false


func start_pomodoro() -> void:
	_reset_pomodoro()


func _process(delta: float) -> void:
	if not _pomodoro_running:
		return
	_pomodoro_time_left -= delta
	if _pomodoro_time_left > 0.0:
		return
	if _pomodoro_in_break:
		_pomodoro_in_break = false
		pomodoro_break_ended.emit()
		_reset_pomodoro()
	else:
		_pomodoro_in_break = true
		_pomodoro_time_left = 180.0
		pomodoro_focus_ended.emit()
		var activity: String = BREAK_ACTIVITIES[_break_index % BREAK_ACTIVITIES.size()]
		_break_index += 1
		active_break_requested.emit(activity)


func pomodoro_minutes_left() -> int:
	return maxi(0, int(ceilf(_pomodoro_time_left / 60.0)))


func pomodoro_in_break() -> bool:
	return _pomodoro_in_break


func notify_night_transition(is_night: bool) -> void:
	# La escena principal responde bajando la luz azulada
	# (ver 06_night_lighting.gd) y mostrando el mensaje de
	# consolidación. No se bloquea el juego de noche.
	night_transition_requested.emit(is_night)


# ---------------- Growth Mindset: sin castigo, con pista ----------------

func feedback_for(success: bool, effort_note: String = "") -> Dictionary:
	if success:
		var text := "¡Muy bien! Lo lograste con estrategia."
		if effort_note != "":
			text += " " + effort_note
		feedback_shown.emit(text, "exito")
		return {"text": text, "kind": "exito", "punish": false}
	var text := "Casi lo tienes. Inténtalo de nuevo con esta pista: "
	text += "mira el bloque que cambió de color y prueba otro orden."
	if effort_note != "":
		text += " " + effort_note
	feedback_shown.emit(text, "pista")
	return {"text": text, "kind": "pista", "punish": false}
