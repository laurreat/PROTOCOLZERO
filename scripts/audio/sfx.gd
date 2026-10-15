class_name Sfx
extends RefCounted
## Procedural sound effects (FASE 6, synthesis core kept in part A).
## No external assets: every sound is a sine tone with linear decay rendered
## into an 8-bit 22050 Hz AudioStreamWAV. Streams are generated lazily on
## demand (never in _ready), so headless editor import and the AudioServer
## dummy driver stay clean. Playback goes through the single scene-local
## "SfxPlayer" (Main child in group "sfx_player", bus set in main.tscn);
## HUD/context messages go through group "hud". UI menu feedback lives in
## the Audio autoload and reuses tone()/sequence() (single generator).

const MIX_RATE := 22050
const DEFAULT_VOL := 0.5

## Bus/cfg/display ownership moved to the autoloads (part A): `Audio` owns
## the buses (Master -> Music/SFX/UI) and `Settings` owns persistence plus
## display/FPS application. This helper keeps the pure synthesizer
## (tone/sequence + presets) and the scene-local playback helpers
## (get_player/play/message) so gameplay call sites are unchanged.


## Renders one sine tone with linear decay. Always returns a valid stream.
static func tone(freq: float, dur: float, vol := DEFAULT_VOL) -> AudioStreamWAV:
	var frames := maxi(1, int(MIX_RATE * dur))
	var data := PackedByteArray()
	data.resize(frames)
	for i in frames:
		var t := float(i) / float(MIX_RATE)
		var env := 1.0 - float(i) / float(frames)
		var s := sin(TAU * freq * t) * env * vol
		data[i] = int(clampf(s * 0.5 + 0.5, 0.0, 1.0) * 255.0)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


## Concatenates one decaying tone per frequency with a short gap of silence.
static func sequence(freqs: Array, note_dur: float, vol := DEFAULT_VOL, gap := 0.03) -> AudioStreamWAV:
	var data := PackedByteArray()
	var gap_frames := int(MIX_RATE * gap)
	for f in freqs:
		var freq := float(f)
		var frames := maxi(1, int(MIX_RATE * note_dur))
		var start := data.size()
		data.resize(start + frames + gap_frames)
		for i in frames:
			var t := float(i) / float(MIX_RATE)
			var env := 1.0 - float(i) / float(frames)
			var s := sin(TAU * freq * t) * env * vol
			data[start + i] = int(clampf(s * 0.5 + 0.5, 0.0, 1.0) * 255.0)
		for g in gap_frames:
			data[start + frames + g] = 128
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav


## Real-file presets (FASE INTEGRAL Fase B): Persona 2 synthetic WAVs
## (originals, licence-clear per docs/audio-provenance/LEEME.txt) and
## Persona 1 CC0 tracks. Every preset loads the real file first and falls
## back to the previous procedural timbre when the file is missing, so a
## missing/unimported file never breaks gameplay or headless runs.
## Persona 4 OGGs (sfx/{doors,security,unsorted}/*.ogg) are NEVER referenced:
## licence unclear, local-tests-only (see README_LICENCIAS_Y_CLASIFICACION).
static var _file_cache: Dictionary = {}


## File-first loader with procedural fallback. Cached per path.
static func _file(path: String, fallback: AudioStream) -> AudioStream:
	if _file_cache.has(path):
		return _file_cache[path] as AudioStream
	var loaded := load(path) as AudioStream
	var chosen: AudioStream = loaded if loaded != null else fallback
	if loaded == null:
		push_warning("Sfx: file missing '%s', using procedural fallback." % path)
	_file_cache[path] = chosen
	return chosen


static func ui_ok() -> AudioStream:
	return _file("res://assets/audio/sfx/ui/04_confirmacion.wav", tone(880.0, 0.08))


static func ui_deny() -> AudioStream:
	return _file("res://assets/audio/sfx/ui/07_error_interfaz.wav", tone(220.0, 0.15))


static func alarm() -> AudioStream:
	return _file("res://assets/audio/ambience/21_peligro_alarm_00.mp3", tone(660.0, 0.25, 0.4))


static func door_open() -> AudioStream:
	return _file("res://assets/audio/sfx/doors/01_puerta_abrir.wav", tone(880.0, 0.08))


static func door_close() -> AudioStream:
	return _file("res://assets/audio/sfx/doors/02_puerta_cerrar.wav", tone(660.0, 0.08))


static func door_locked() -> AudioStream:
	return _file("res://assets/audio/sfx/doors/04_puerta_bloqueada.wav", tone(220.0, 0.15))


static func door_unlock() -> AudioStream:
	return _file("res://assets/audio/sfx/doors/03_desbloqueo_cerrojo.wav", tone(880.0, 0.08))


static func door_damaged() -> AudioStream:
	return _file("res://assets/audio/sfx/doors/05_fallo_mecanismo.wav", tone(220.0, 0.15))


static func terminal_ok() -> AudioStream:
	return _file("res://assets/audio/sfx/terminals/06_acceso_permitido.wav", tone(880.0, 0.08))


static func terminal_deny() -> AudioStream:
	return _file("res://assets/audio/sfx/terminals/07_acceso_denegado.wav", tone(220.0, 0.15))


static func terminal_beep() -> AudioStream:
	return _file("res://assets/audio/sfx/terminals/03_beep_terminal.wav", tone(900.0, 0.05))


static func terminal_boot() -> AudioStream:
	return _file("res://assets/audio/sfx/terminals/01_terminal_encendido.wav", tone(520.0, 0.08))


static func terminal_scan() -> AudioStream:
	return _file("res://assets/audio/sfx/terminals/05_escaneo.wav", tone(660.0, 0.08))


## Arranque del generador (Fase H): surge electrico real (Persona 5,
## rubberduck CC0). El hum sostenido sigue por Audio.play_ambience con ON.
static func generator_on() -> AudioStream:
	return _file("res://assets/audio/sfx/generators/01_arranque_generador.ogg", tone(880.0, 0.08))


## Corte de energia (Fase H): chasquido electrico real (Persona 5 CC0).
static func power_cut() -> AudioStream:
	return _file("res://assets/audio/sfx/generators/02_corte_electrico.ogg", tone(440.0, 0.08))


## Inicio de reparacion mecanica 3 s (Fase H): engranajes reales
## (Persona 5 CC0). One-shot al empezar; sin loop dedicado por diseño
## (la voz ambience ya la ocupa el powerplant con energia ON).
static func repair_start() -> AudioStream:
	return _file("res://assets/audio/sfx/generators/03_reparacion_mecanica.ogg", tone(660.0, 0.08))


static func pulse_sweep() -> AudioStreamWAV:
	return sequence([440.0, 880.0], 0.12)


## Impulso de dash (C5): barrido descendente breve. Procedural porque ningun
## pack del proyecto trae un whoosh apto con licencia clara.
static func dash() -> AudioStreamWAV:
	return sequence([880.0, 440.0], 0.09)


static func win() -> AudioStream:
	return _file("res://assets/audio/sfx/protocol/07_victoria_victory.mp3", sequence([660.0, 880.0, 1320.0], 0.15))


static func lose() -> AudioStreamWAV:
	return sequence([220.0, 164.0], 0.25)


## Scene-local player lookup (mirrors the energy/noise group pattern).
static func get_player(tree: SceneTree) -> AudioStreamPlayer:
	if tree == null:
		return null
	return tree.get_first_node_in_group("sfx_player") as AudioStreamPlayer


## Assigns the stream and plays it. Safe to call with nulls (no-op).
static func play(tree: SceneTree, stream: AudioStream) -> void:
	if stream == null:
		return
	var player := get_player(tree)
	if player == null:
		return
	player.stream = stream
	player.play()


## One-line contextual feedback on the HUD message label. Safe no-op.
static func message(tree: SceneTree, text: String) -> void:
	if tree == null:
		return
	var hud := tree.get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_message"):
		hud.show_message(text)
