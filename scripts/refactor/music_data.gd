extends RefCounted
## MusicData — música procedural por bioma y foley por
## material (documento §1: biome_music.json y foley.json,
## aquí como datos, no como archivos: el audio se
## sintetiza en MusicSystem, sin .ogg). Puro, sin nodos.
##
## Escalas: grados sobre una raíz (Do = 60 MIDI). Cada
## bioma tiene su escala, su tempo y su carácter. La
## melodía es determinista: el mismo (bioma, paso) da
## siempre la misma nota, así que dos dispositivos con
## la misma semilla suenan igual.

class_name MusicData

const SCALES := {
	"pradera": {"root": 60, "steps": [0, 2, 4, 7, 9], "beats": 2.0},
	"bosque": {"root": 57, "steps": [0, 3, 5, 7, 10], "beats": 1.6},
	"desierto": {"root": 50, "steps": [0, 2, 3, 7, 8], "beats": 1.2},
	"nieve": {"root": 72, "steps": [0, 5, 7, 12], "beats": 1.0},
	"magma": {"root": 36, "steps": [0, 0, 7], "beats": 0.8},
	"ciber": {"root": 60, "steps": [0, 3, 6, 10], "beats": 2.4},
	"playa": {"root": 60, "steps": [0, 4, 7, 9], "beats": 1.8},
}

const FOLEY := {
	"wood": {"freq": 180.0, "decay": 0.12, "noise": 0.3},
	"stone": {"freq": 900.0, "decay": 0.05, "noise": 0.2},
	"grass": {"freq": 800.0, "decay": 0.15, "noise": 0.8},
	"foliage": {"freq": 1200.0, "decay": 0.18, "noise": 0.9},
	"dirt": {"freq": 300.0, "decay": 0.10, "noise": 0.6},
	"sand": {"freq": 1000.0, "decay": 0.12, "noise": 0.9},
	"metal": {"freq": 1400.0, "decay": 0.08, "noise": 0.2},
	"water": {"freq": 600.0, "decay": 0.20, "noise": 0.7},
	"snow": {"freq": 900.0, "decay": 0.15, "noise": 0.8},
}


## Grupo musical de un bioma por su nombre.
static func group_for_biome(biome: String) -> String:
	if "nevada" in biome or "glaciar" in biome or "hielo" in biome or "tundra" in biome:
		return "nieve"
	if "desierto" in biome:
		return "desierto"
	if "magma" in biome or "volcan" in biome:
		return "magma"
	if "bosque" in biome:
		return "bosque"
	if "ciber" in biome or "nucleo" in biome:
		return "ciber"
	if "playa" in biome or "mar" in biome:
		return "playa"
	return "pradera"


static func scale_for_biome(biome: String) -> Dictionary:
	return SCALES[group_for_biome(biome)]


## Nota MIDI del paso de la melodía (paseo determinista
## por la escala con un hash del paso).
static func note_for(biome: String, step: int) -> int:
	var scale: Dictionary = scale_for_biome(biome)
	var steps: Array = scale["steps"]
	var h := (step * 2654435761) % 1000
	var idx := (step + int(h / 250)) % steps.size()
	return int(scale["root"]) + int(steps[idx])


## Frecuencia de la nota MIDI (temperamento igual).
static func midi_freq(midi: int) -> float:
	return 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)


static func foley_params(sound: String) -> Dictionary:
	return FOLEY.get(sound, {"freq": 500.0, "decay": 0.08, "noise": 0.4})
