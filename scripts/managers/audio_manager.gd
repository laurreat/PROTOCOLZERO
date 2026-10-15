extends Node
## Process-lifetime audio service (autoload `Audio`, part A + part B).
## Justification for autoload: UI feedback sounds must play from the menu and
## survive menu<->gameplay scene changes, and bus routing must outlive any
## single scene. Owns the AudioServer buses (Master -> Music/SFX/UI/Ambience,
## all children of Master so Master scales the whole mix without remixing);
## Ambience bus added in Fase B (Persona 1 installation beds now exist).
## The `Settings` autoload owns persistence and pushes values here;
## this node only applies them. Volume mapping is perceptual:
## db = linear_to_db(max(v, 0.0001)) with 0% = mute (-80 dB).
## UI sounds are real menu files first (Persona 2 pack, original synthetic
## WAVs per docs/audio-provenance/LEEME.txt), procedural Sfx presets only
## as the missing-file fallback (no duplicated synthesis).
## Persona 4 OGGs (assets/audio/sfx/{doors,security,unsorted}/) are NEVER
## used here: local-tests-only, not approved for publishing (see
## docs/audio-provenance/README_LICENCIAS_Y_CLASIFICACION.txt).
## Part B (adaptive music): enum MusicState + set_music_state() public API,
## 2 base AudioStreamPlayers for crossfade (slow 1.5s, fast 0.6s to CHASE),
## a third danger overlay player at partial volume over the base, calm_down()
## (TENSION 4s -> EXPLORATION), real-file loader with procedural
## `_placeholder` fallback loops, and stop_music() for win/lose.
## Simple per-state tracks (NOT a 3-layer BASE/TENSION/PERCUSSION mixer;
## layers documented as future). Duck (part A) is bus-level, so it applies
## to all present and future Music players untouched.

enum MusicState { MENU, EXPLORATION, STEALTH, TENSION, CHASE, DANGER, NONE }

const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_UI := "UI"
## Ambience bus (Fase B): single looping installation bed (powerplant hum,
## ventilation). Child of Master like the rest; one voice, idempotent plays.
const BUS_AMBIENCE := "Ambience"
const MUTE_DB := -80.0
## Minimum gap between two plays of the same UI sound (anti-spam).
const UI_SPAM_MS := 60
## Crossfade durations (seconds): slow default, fast into CHASE.
const CROSSFADE_SLOW := 1.5
const CROSSFADE_FAST := 0.6
## calm_down() holds TENSION this long before settling to EXPLORATION.
const CALM_DELAY := 4.0
## Danger overlay level under the base (partial volume, never cuts it).
const DANGER_DB := -8.0
## Danger fade-in (pleasant); stops are immediate for determinism.
const DANGER_FADE_IN := 0.8
## Placeholder synth rate (matches Sfx, keeps generation fast).
const MUSIC_MIX_RATE := 22050

## Real menu UI files by sound name (brief techno UI pack, no engines).
## "focus" and "select" share 03 (keyboard focus move IS option selection);
## "cancel" (05) stays available but unwired: the single close path already
## plays "panel_close" (06_volver), and a second play would double up.
## "error" (07) is available; the menu has no error path yet.
const UI_WAV := {
	"hover": "res://assets/audio/sfx/ui/01_hover_sutil.wav",
	"focus": "res://assets/audio/sfx/ui/03_seleccionar_opcion.wav",
	"click": "res://assets/audio/sfx/ui/02_click_interfaz.wav",
	"select": "res://assets/audio/sfx/ui/03_seleccionar_opcion.wav",
	"confirm": "res://assets/audio/sfx/ui/04_confirmacion.wav",
	"cancel": "res://assets/audio/sfx/ui/05_cancelar.wav",
	"panel_open": "res://assets/audio/sfx/ui/08_notificacion.wav",
	"panel_close": "res://assets/audio/sfx/ui/06_volver_menu.wav",
	"error": "res://assets/audio/sfx/ui/07_error_interfaz.wav",
}

var _ui_player: AudioStreamPlayer = null
var _amb_player: AudioStreamPlayer = null
var _amb_path := ""
var _ui_cache: Dictionary = {}
var _last_ui: Dictionary = {}
## Tracked 0-100 values (duck offset is computed from the music base).
var _master := 100.0
var _music := 100.0
var _sfx := 100.0
var _ducked := false
var _duck_tween: Tween = null
## Part B music state. `_state` is the last request (DANGER included);
## `_base` is the last non-DANGER base driving the crossfade pair.
var _state: MusicState = MusicState.NONE
var _base: MusicState = MusicState.NONE
var _danger_on := false
var _music_players: Array[AudioStreamPlayer] = []
var _danger_player: AudioStreamPlayer = null
var _front := -1
var _cross_tween: Tween = null
var _danger_tween: Tween = null
var _calm_timer: Timer = null
var _stream_cache: Dictionary = {}


func _ready() -> void:
	# Music must keep playing (ducked) while the tree is paused, and the
	# duck/crossfade tweens must tick during pause (open_menu pauses first,
	# then ducks). ALWAYS + TWEEN_PAUSE_PROCESS cover both.
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = "UiPlayer"
	_ui_player.bus = BUS_UI
	add_child(_ui_player)
	_amb_player = AudioStreamPlayer.new()
	_amb_player.name = "AmbiencePlayer"
	_amb_player.bus = BUS_AMBIENCE
	add_child(_amb_player)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.name = "MusicBase%d" % i
		p.bus = BUS_MUSIC
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_music_players.append(p)
	_danger_player = AudioStreamPlayer.new()
	_danger_player.name = "MusicDanger"
	_danger_player.bus = BUS_MUSIC
	_danger_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_danger_player)
	_calm_timer = Timer.new()
	_calm_timer.name = "CalmTimer"
	_calm_timer.one_shot = true
	_calm_timer.wait_time = CALM_DELAY
	_calm_timer.timeout.connect(_on_calm_timeout)
	add_child(_calm_timer)


func _exit_tree() -> void:
	# Release music voices when the tree exits (quit path). Scene changes
	# never exit this autoload, so gameplay is unaffected. Note: quitting
	# while a loop plays still logs an exit-order playback warning
	# engine-side (in-flight AudioStreamPlaybackWAV); benign, exit-only.
	stop_music()


## Idempotent: adds Music/SFX/UI/Ambience buses only when missing, sending to Master.
func ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX, BUS_UI, BUS_AMBIENCE]:
		if bus_missing(bus_name):
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_send(idx, "Master")


func bus_missing(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) < 0


## Perceptual 0-100 to dB. 0% maps to MUTE_DB (-80 dB, linear_to_db(0.0001)).
func volume_to_db(value_0_100: float) -> float:
	var clamped := clampf(value_0_100, 0.0, 100.0)
	if clamped <= 0.0:
		return MUTE_DB
	return linear_to_db(maxf(clamped / 100.0, 0.0001))


func _apply_bus(bus_name: String, value_0_100: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	var clamped := clampf(value_0_100, 0.0, 100.0)
	if clamped <= 0.0:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, MUTE_DB)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, volume_to_db(clamped))


## Immediate 0-100 writers (persistence belongs to Settings, not here).
func set_master(value_0_100: float) -> void:
	_master = clampf(value_0_100, 0.0, 100.0)
	_apply_bus("Master", _master)


func set_music(value_0_100: float) -> void:
	_music = clampf(value_0_100, 0.0, 100.0)
	_kill_duck_tween()
	_apply_music_target()


func set_sfx(value_0_100: float) -> void:
	_sfx = clampf(value_0_100, 0.0, 100.0)
	_apply_bus(BUS_SFX, _sfx)
	# Part A decision: the UI bus tracks the SFX setting (same dB/mute), so
	# the EFECTOS slider also gates menu feedback clicks. Part B may split it.
	_apply_bus(BUS_UI, _sfx)


## Bus readbacks (0 when muted). Note: get_music reflects the duck offset
## while ducked; Settings holds the stored (unducked) truth.
func get_master() -> float:
	return _read_bus("Master")


func get_music() -> float:
	return _read_bus(BUS_MUSIC)


func get_sfx() -> float:
	return _read_bus(BUS_SFX)


func _read_bus(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 100.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)) * 100.0, 0.0, 100.0)


## Pause duck hook (part A): -12 dB on the Music bus with a short tween.
## Bus-level, so it applies to future Music players (part B) untouched.
func set_ducked(ducked: bool) -> void:
	if _ducked == ducked:
		return
	_ducked = ducked
	_kill_duck_tween()
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx < 0:
		return
	var from_db := AudioServer.get_bus_volume_db(idx)
	var to_db := _music_target_db()
	_duck_tween = create_tween()
	_duck_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_duck_tween.tween_method(_set_music_db_direct, from_db, to_db, 0.25)


func is_ducked() -> bool:
	return _ducked


func _music_target_db() -> float:
	if _music <= 0.0:
		return MUTE_DB
	var base := volume_to_db(_music)
	if _ducked:
		return base - 12.0
	return base


func _apply_music_target() -> void:
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx < 0:
		return
	if _music <= 0.0:
		AudioServer.set_bus_mute(idx, true)
		AudioServer.set_bus_volume_db(idx, MUTE_DB)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, _music_target_db())


func _set_music_db_direct(db: float) -> void:
	var idx := AudioServer.get_bus_index(BUS_MUSIC)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, db)


func _kill_duck_tween() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null


## Subtle procedural UI feedback. Returns true when played, false when
## throttled (same name within UI_SPAM_MS) or unknown. Safe headless.
func play_ui(sound_name: String) -> bool:
	if not _ui_cache.has(sound_name):
		var stream := _build_ui_sound(sound_name)
		if stream == null:
			push_warning("Audio: unknown UI sound '%s'." % sound_name)
			return false
		_ui_cache[sound_name] = stream
	var now := Time.get_ticks_msec()
	if _last_ui.has(sound_name) and now - int(_last_ui[sound_name]) < UI_SPAM_MS:
		return false
	_last_ui[sound_name] = now
	if _ui_player == null:
		return false
	_ui_player.stream = _ui_cache[sound_name] as AudioStream
	_ui_player.play()
	return true


## File-first UI sound builder. Returns the real WAV when it loads, else
## the procedural preset so a missing/unimported file never breaks the menu.
func _build_ui_sound(sound_name: String) -> AudioStream:
	if UI_WAV.has(sound_name):
		var loaded := load(String(UI_WAV[sound_name])) as AudioStream
		if loaded != null:
			return loaded
		push_warning("Audio: UI file missing for '%s', using procedural fallback." % sound_name)
	return _build_ui_procedural(sound_name)


## All presets reuse the single Sfx synthesizer (no duplicated generator).
## Doubles as the file-missing fallback so every name still plays headless.
func _build_ui_procedural(sound_name: String) -> AudioStreamWAV:
	match sound_name:
		"hover":
			return Sfx.tone(1200.0, 0.03, 0.12)
		"focus":
			return Sfx.tone(900.0, 0.03, 0.15)
		"click":
			return Sfx.tone(660.0, 0.06, 0.22)
		"select":
			return Sfx.tone(760.0, 0.05, 0.18)
		"panel_open":
			return Sfx.sequence([520.0, 780.0], 0.05, 0.18)
		"panel_close":
			return Sfx.sequence([780.0, 520.0], 0.05, 0.18)
		"confirm":
			return Sfx.tone(880.0, 0.08, 0.22)
		"cancel":
			return Sfx.sequence([660.0, 440.0], 0.05, 0.18)
		"error":
			return Sfx.tone(220.0, 0.15, 0.22)
	return null


# ---------------------------------------------------------------------------
# Part B: adaptive music (public API first, synthesis last).
# ---------------------------------------------------------------------------

## Last requested music state (DANGER/NONE included). Probes read this.
func get_music_state() -> MusicState:
	return _state


## Last non-DANGER base (what the crossfade pair plays). Probes read this.
func get_base_state() -> MusicState:
	return _base


func is_danger_active() -> bool:
	return _danger_on


## True while any base music voice is playing (headless-safe).
func is_music_playing() -> bool:
	return _is_base_playing() or (_danger_player != null and _danger_player.playing)


## Front base voice for probes (null when stopped). Never null-guarded by callers.
func get_active_player() -> AudioStreamPlayer:
	if _front >= 0 and _front < _music_players.size():
		return _music_players[_front]
	return null


func get_danger_player() -> AudioStreamPlayer:
	return _danger_player


## Public gameplay API. Idempotent: requesting the playing base (or the
## active DANGER overlay) never restarts the stream, so CONFIG sliders and
## repeated calls cannot cut the music. CHASE crossfades fast (0.6s),
## everything else slow (1.5s). DANGER starts the overlay without touching
## the base; any later non-DANGER request stops the overlay first.
func set_music_state(state: MusicState) -> void:
	if state == MusicState.DANGER:
		if _danger_on:
			return
		_danger_on = true
		_state = MusicState.DANGER
		_cancel_calm()
		_start_danger()
		return
	if _danger_on:
		_danger_on = false
		_stop_danger()
	if state == MusicState.NONE:
		_state = MusicState.NONE
		_base = MusicState.NONE
		_cancel_calm()
		_stop_all_base()
		return
	if state == _base and _is_base_playing():
		_state = state
		_cancel_calm()
		return
	var duration := CROSSFADE_FAST if state == MusicState.CHASE else CROSSFADE_SLOW
	_state = state
	_base = state
	_cancel_calm()
	_cross_to(state, duration)


## Escape path after CHASE: hold TENSION for CALM_DELAY, then settle to
## EXPLORATION unless a newer explicit state arrives first. Never disturbs
## the menu (MENU) or silence (NONE). Clears the danger overlay.
func calm_down() -> void:
	if _danger_on:
		_danger_on = false
		_stop_danger()
	if _base == MusicState.MENU or _base == MusicState.NONE:
		return
	if _base == MusicState.EXPLORATION:
		_cancel_calm()
		_state = MusicState.EXPLORATION
		return
	_state = MusicState.TENSION
	_base = MusicState.TENSION
	_cross_to(MusicState.TENSION, CROSSFADE_SLOW)
	_cancel_calm()
	if _calm_timer != null:
		_calm_timer.start(CALM_DELAY)


## Hard stop for win/lose (the sting plays on the SFX bus, untouched).
## Immediate (no fade) so probes and scene changes are deterministic.
func stop_music() -> void:
	_state = MusicState.NONE
	_base = MusicState.NONE
	_danger_on = false
	_cancel_calm()
	_stop_danger()
	_stop_all_base()


# ---------------------------------------------------------------------------
# Ambience bed (Fase B): one looping installation voice on the Ambience bus.
# Idempotent: requesting the playing path never restarts the stream, so
# energy toggles and repeated calls cannot cut or stack the loop.
# ---------------------------------------------------------------------------

## Powerplant hum while energy is ON (Persona 1, CC-BY Eric Matyas — credit
## before publishing). Returns true when the loop is (now) playing.
func play_ambience(res_path: String, volume_db := -6.0) -> bool:
	if _amb_player == null:
		return false
	if _amb_player.playing and _amb_path == res_path:
		return true
	var loaded := load(res_path) as AudioStream
	if loaded == null:
		push_warning("Audio: ambience file missing '%s'." % res_path)
		return false
	_amb_player.stream = _as_looped(loaded)
	_amb_player.volume_db = volume_db
	_amb_player.play()
	_amb_path = res_path
	return true


func stop_ambience() -> void:
	_amb_path = ""
	if _amb_player != null:
		_amb_player.stop()


func is_ambience_playing() -> bool:
	if _amb_player == null:
		return false
	return _amb_player.playing


func _on_calm_timeout() -> void:
	if _danger_on:
		return
	if _base != MusicState.TENSION:
		return
	_base = MusicState.EXPLORATION
	_state = MusicState.EXPLORATION
	_cross_to(MusicState.EXPLORATION, CROSSFADE_SLOW)


func _is_base_playing() -> bool:
	if _front < 0 or _front >= _music_players.size():
		return false
	return _music_players[_front].playing


func _stop_all_base() -> void:
	_kill_cross_tween()
	for p in _music_players:
		p.stop()
	_front = -1


func _start_danger() -> void:
	if _danger_player == null:
		return
	var stream := _resolve_stream(MusicState.DANGER)
	if stream == null:
		return
	_kill_danger_tween()
	# Same-stream replay still restarts the overlay voice on purpose: the
	# guard lives in set_music_state (idempotent), this is the player op.
	_danger_player.stream = stream
	_danger_player.volume_db = MUTE_DB
	_danger_player.play()
	_danger_tween = create_tween()
	_danger_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_danger_tween.tween_property(_danger_player, "volume_db", DANGER_DB, DANGER_FADE_IN)


func _stop_danger() -> void:
	_kill_danger_tween()
	if _danger_player != null:
		_danger_player.stop()


## Crossfade to a base state. Same-stream requests never restart the front
## voice (CONFIG/retry safe). First play fades in from silence.
func _cross_to(base: MusicState, duration: float) -> void:
	if _music_players.size() < 2:
		return
	var stream := _resolve_stream(base)
	if stream == null:
		return
	var safe_dur := maxf(duration, 0.05)
	if _front < 0 or _front >= _music_players.size() or not _music_players[_front].playing:
		_kill_cross_tween()
		_front = 0
		var first := _music_players[0]
		var second := _music_players[1]
		second.stop()
		first.stream = stream
		first.volume_db = MUTE_DB
		first.play()
		_cross_tween = create_tween()
		_cross_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_cross_tween.tween_property(first, "volume_db", 0.0, safe_dur)
		return
	var old := _music_players[_front]
	if old.stream == stream and old.playing:
		return
	var back_idx := 1 - _front
	var back := _music_players[back_idx]
	_kill_cross_tween()
	back.stream = stream
	back.volume_db = MUTE_DB
	back.play()
	_cross_tween = create_tween()
	_cross_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_cross_tween.set_parallel(true)
	_cross_tween.tween_property(back, "volume_db", 0.0, safe_dur)
	_cross_tween.tween_property(old, "volume_db", MUTE_DB, safe_dur)
	_cross_tween.set_parallel(false)
	_cross_tween.tween_callback(_finish_cross.bind(old, back_idx))


func _finish_cross(old: AudioStreamPlayer, back_idx: int) -> void:
	if old != null and old.playing:
		old.stop()
	_front = back_idx


func _kill_cross_tween() -> void:
	if _cross_tween != null and _cross_tween.is_valid():
		_cross_tween.kill()
	_cross_tween = null


func _kill_danger_tween() -> void:
	if _danger_tween != null and _danger_tween.is_valid():
		_danger_tween.kill()
	_danger_tween = null


func _cancel_calm() -> void:
	if _calm_timer != null and not _calm_timer.is_stopped():
		_calm_timer.stop()


# ---------------------------------------------------------------------------
# Part B: track loader (real files win, `_placeholder` synths otherwise).
# Expected layout (Persona 1 CC0 beds, authored as seamless loops):
# assets/audio/music/menu/*.mp3, exploration/*.mp3, stealth/*.mp3,
# tension/*.mp3, chase/*.mp3, danger/*.mp3 (first sorted file wins).
# ---------------------------------------------------------------------------

func _state_dir(state: MusicState) -> String:
	match state:
		MusicState.MENU:
			return "menu"
		MusicState.EXPLORATION:
			return "exploration"
		MusicState.STEALTH:
			return "stealth"
		MusicState.TENSION:
			return "tension"
		MusicState.CHASE:
			return "chase"
		MusicState.DANGER:
			return "danger"
	return ""


func _resolve_stream(state: MusicState) -> AudioStream:
	if _stream_cache.has(state):
		return _stream_cache[state] as AudioStream
	var stream: AudioStream = null
	var real_path := _find_real_file(_state_dir(state))
	if real_path != "":
		var loaded := load(real_path)
		if loaded is AudioStream:
			stream = _as_looped(loaded as AudioStream)
	if stream == null:
		stream = _placeholder_stream(state)
	if stream != null:
		_stream_cache[state] = stream
	return stream


func _find_real_file(dir_name: String) -> String:
	if dir_name == "":
		return ""
	var dir_path := "res://assets/audio/music/" + dir_name
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	var candidates: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			var lower := f.to_lower()
			var is_audio := lower.ends_with(".ogg") or lower.ends_with(".wav") or lower.ends_with(".mp3") or lower.ends_with(".oga") or lower.ends_with(".flac")
			var is_sidecar := lower.ends_with(".import") or lower.ends_with(".uid")
			if is_audio and not is_sidecar:
				candidates.append(dir_path + "/" + f)
		f = dir.get_next()
	dir.list_dir_end()
	if candidates.is_empty():
		return ""
	candidates.sort()
	return candidates[0]


## Imported streams may carry no loop flag; duplicate and force it so real
## files behave like the seamless placeholder loops. WAV uses loop_mode,
## OGG/MP3 use the `loop` property when present (guarded, no hard dependency).
func _as_looped(stream: AudioStream) -> AudioStream:
	var dup := stream.duplicate() as AudioStream
	var target: AudioStream = dup if dup != null else stream
	if target is AudioStreamWAV:
		(target as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		return target
	var has_loop := false
	for p in target.get_property_list():
		if String(p.get("name", "")) == "loop":
			has_loop = true
			break
	if has_loop:
		target.set("loop", true)
	return target


# ---------------------------------------------------------------------------
# Part B: `_placeholder` procedural loops (clearly marked, test-only timbre).
# Dark abandoned-installation beds: grave slow pads (MENU root A1 55 Hz,
# EXPLORATION root C2 65.41 Hz), soft-pulse tension (STEALTH/TENSION),
# faster low percussion (CHASE), faint two-tone alarm bed (DANGER).
# All sine-only below ~370 Hz at modest levels: acceptable low, never shrill.
# Every oscillator is quantized to an integer cycle count per duration, so
# LOOP_FORWARD wraps without clicks (no edge fade dip needed).
# ---------------------------------------------------------------------------

func _placeholder_stream(state: MusicState) -> AudioStreamWAV:
	match state:
		MusicState.MENU:
			return _placeholder_pad(8.0, 55.0, 82.5, 110.0, 0.30, 0.18, 0.12)
		MusicState.EXPLORATION:
			return _placeholder_pad(8.0, 65.41, 98.0, 130.81, 0.30, 0.18, 0.10)
		MusicState.STEALTH:
			return _placeholder_pulse(6.0, 55.0, 110.0, 220.0, 0.8, 0.35)
		MusicState.TENSION:
			return _placeholder_pulse(6.0, 58.27, 116.54, 233.08, 1.2, 0.40)
		MusicState.CHASE:
			return _placeholder_chase()
		MusicState.DANGER:
			return _placeholder_danger()
	return _placeholder_pad(8.0, 55.0, 82.5, 110.0, 0.30, 0.18, 0.12)


## Integer-cycle quantization: the nearest frequency completing whole
## cycles in `duration`, so the loop wraps seamlessly.
func _quant_freq(freq: float, duration: float) -> float:
	var cycles := roundf(freq * duration)
	return maxf(cycles, 1.0) / duration


func _finish_wav(data: PackedByteArray, frames: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MUSIC_MIX_RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav


func _put16(data: PackedByteArray, i: int, s: float) -> void:
	var v := int(clampf(s, -1.0, 1.0) * 32767.0)
	if v < 0:
		v += 65536
	data[2 * i] = v & 0xFF
	data[2 * i + 1] = (v >> 8) & 0xFF


## Grave slow pad with a one-cycle swell per loop (MENU/EXPLORATION beds).
func _placeholder_pad(duration: float, root: float, fifth: float, octave: float, a_root: float, a_fifth: float, a_oct: float) -> AudioStreamWAV:
	var frames := int(MUSIC_MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var f1 := _quant_freq(root, duration)
	var f2 := _quant_freq(fifth, duration)
	var f3 := _quant_freq(octave, duration)
	var swell_rate := 1.0 / duration
	for i in frames:
		var t := float(i) / float(MUSIC_MIX_RATE)
		var swell := 0.7 + 0.3 * sin(TAU * swell_rate * t)
		var s := (a_root * sin(TAU * f1 * t) + a_fifth * sin(TAU * f2 * t) + a_oct * sin(TAU * f3 * t)) * swell
		_put16(data, i, s)
	return _finish_wav(data, frames)


## Pad with a soft sinusoidal pulse gate (STEALTH/TENSION beds).
func _placeholder_pulse(duration: float, root: float, octave: float, faint: float, pulse_hz: float, depth: float) -> AudioStreamWAV:
	var frames := int(MUSIC_MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var f1 := _quant_freq(root, duration)
	var f2 := _quant_freq(octave, duration)
	var f3 := _quant_freq(faint, duration)
	var fp := _quant_freq(pulse_hz, duration)
	var base := 1.0 - depth
	for i in frames:
		var t := float(i) / float(MUSIC_MIX_RATE)
		var gate := base + depth * (0.5 + 0.5 * sin(TAU * fp * t))
		var s := (0.25 * sin(TAU * f1 * t) + 0.08 * sin(TAU * f2 * t) + 0.035 * sin(TAU * f3 * t)) * gate
		_put16(data, i, s)
	return _finish_wav(data, frames)


## Faster low percussion over a grave drone (CHASE bed, 2.5 Hz thumps).
func _placeholder_chase() -> AudioStreamWAV:
	var duration := 4.0
	var frames := int(MUSIC_MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var f55 := _quant_freq(55.0, duration)
	var f82 := _quant_freq(82.5, duration)
	var f330 := _quant_freq(330.0, duration)
	var rate := 2.5
	for i in frames:
		var t := float(i) / float(MUSIC_MIX_RATE)
		var phase := fmod(t * rate, 1.0)
		var perc := exp(-phase * 5.0)
		var s := 0.22 * sin(TAU * f55 * t) + 0.10 * sin(TAU * f82 * t) + perc * (0.28 * sin(TAU * f55 * t) + 0.06 * sin(TAU * f330 * t))
		_put16(data, i, s)
	return _finish_wav(data, frames)


## Faint two-tone alarm bed over a sub drone (DANGER overlay, never shrill).
func _placeholder_danger() -> AudioStreamWAV:
	var duration := 4.0
	var frames := int(MUSIC_MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var f49 := _quant_freq(49.0, duration)
	var fa := _quant_freq(330.0, duration)
	var fb := _quant_freq(370.0, duration)
	var alt := 0.25
	for i in frames:
		var t := float(i) / float(MUSIC_MIX_RATE)
		var g := 0.5 + 0.5 * sin(TAU * alt * t)
		var s := 0.20 * sin(TAU * f49 * t) + 0.08 * (g * sin(TAU * fa * t) + (1.0 - g) * sin(TAU * fb * t))
		_put16(data, i, s)
	return _finish_wav(data, frames)
