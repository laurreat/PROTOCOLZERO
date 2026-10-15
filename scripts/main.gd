extends Node2D
## Main scene coordinator (FASE 1 boot + FASE 2 prompt + FASE 3 hooks +
## FASE 6 win/lose flow + Sector 01 level). Owns level wiring: EnergySystem
## state, interactable instances, the bottom-center prompt (InteractionPrompt
## stays the single prompt label; the HUD owns the message label), the
## code-built Sector 01 navmesh (LevelBuilder.walk_rects), run timing, the
## SECURITY ONLINE wake-up, the CHASE alarm sting, and the game_over/game_win
## transitions. End-of-run freezes gameplay via tree pause; the HUD layer runs
## ALWAYS so its retry input still works. Duplicate transitions are guarded.

## First CHASE sting plays immediately; repeats are rate-limited by this.
const ALARM_COOLDOWN := 5.0

## Part B: PATROL restores STEALTH while the player stays close to the drone.
const STEALTH_DISTANCE := 400.0

enum GameState { PLAYING, WON, LOST }

signal game_over_triggered(reason: String)
signal game_won_triggered

var game_over_reason := ""
var game_state: GameState = GameState.PLAYING

var _run_time := 0.0
var _alarm_left := 0.0

@onready var _player: Player = $Player
@onready var _prompt_label: Label = $InteractionPrompt/Label
@onready var _hud: CanvasLayer = $HUD
## Level 1 controlled reset: authored Level owns geometry/nav; runtime
## generation is bypassed (see _build_level/_build_navmesh guards). The old
## root $NavigationRegion no longer exists; nav lives at Level/Navigation and
## gameplay actors are staged under Gameplay (x+4000) so lookups resolve late.
var _nav_region: NavigationRegion2D
var _drone: SecurityDrone


func _ready() -> void:
	add_to_group("game")
	# Part A: saved settings are applied by the Settings autoload (ready
	# before this scene) and SfxPlayer carries bus "SFX" in main.tscn.
	# Part B: gameplay bed (idempotent: coming from JUGAR it is already
	# EXPLORATION, direct boot fades in, retry after stop restarts it).
	Audio.set_music_state(Audio.MusicState.EXPLORATION)
	# Level 1 controlled reset: resolve authored/staged nodes (never fails).
	_nav_region = get_node_or_null("Level/Navigation") as NavigationRegion2D
	_drone = get_node_or_null("Gameplay/SecurityDrone") as SecurityDrone
	_build_level()
	_build_navmesh()
	if _drone != null:
		_drone.state_changed.connect(_on_drone_state_changed)
	_wire_security_online()


func _process(delta: float) -> void:
	if game_state == GameState.PLAYING:
		_run_time += delta
	if _alarm_left > 0.0:
		_alarm_left = maxf(0.0, _alarm_left - delta)
	if _player == null or _prompt_label == null:
		return
	var best: Interactable = _player.get_best_interactable()
	if best == null:
		_prompt_label.visible = false
		return
	_prompt_label.visible = true
	_prompt_label.text = best.get_prompt()


## FASE 3 catch hook (FASE 6 owns the flow): single LOST transition with the
## lose overlay + sting + pause. Only "caught" exists in the MVP.
func game_over(reason: String) -> void:
	if game_state != GameState.PLAYING or game_over_reason != "":
		return
	game_state = GameState.LOST
	game_over_reason = reason
	game_over_triggered.emit(reason)
	print("Main: game over (%s)." % reason)
	Sfx.play(get_tree(), Sfx.lose())
	Audio.stop_music()
	if _hud != null and _hud.has_method("show_lose"):
		_hud.show_lose()
	get_tree().paused = true


## Win transition via the ExitZone: single WON transition with time, overlay,
## sting + pause. Symmetric guard with game_over (no double transitions).
func game_win() -> void:
	if game_state != GameState.PLAYING:
		return
	game_state = GameState.WON
	game_won_triggered.emit()
	print("Main: mission complete.")
	Sfx.play(get_tree(), Sfx.win())
	Audio.stop_music()
	if _hud != null and _hud.has_method("show_win"):
		_hud.show_win(_run_time)
	get_tree().paused = true


## Pause gate (FASE 7): the pause overlay only opens while the run is live
## (never in WON/LOST/menu). Read by the scene-local PauseMenu overlay.
func is_playing() -> bool:
	return game_state == GameState.PLAYING


## Part B adaptive music + FASE 6 CHASE sting: DETECT/INVESTIGATE/SEARCH
## hold TENSION, CHASE crossfades fast with the rate-limited alarm,
## PATROL keeps STEALTH while the player stays close (< STEALTH_DISTANCE)
## or eases out via calm_down() (TENSION 4s -> EXPLORATION) when far.
## Survives a missing drone. The alarm path is unchanged from FASE 6.
func _on_drone_state_changed(new_state: SecurityDrone.State) -> void:
	match new_state:
		SecurityDrone.State.DETECT:
			Audio.set_music_state(Audio.MusicState.TENSION)
		SecurityDrone.State.INVESTIGATE:
			Audio.set_music_state(Audio.MusicState.TENSION)
		SecurityDrone.State.CHASE:
			Audio.set_music_state(Audio.MusicState.CHASE)
			_play_chase_alarm()
		SecurityDrone.State.SEARCH:
			Audio.set_music_state(Audio.MusicState.TENSION)
		SecurityDrone.State.PATROL:
			_on_patrol_restore()


## CHASE sting (FASE 6 audio hook): plays the alarm on entering CHASE with a
## cooldown so a long chase does not spam it. Survives a missing drone.
func _play_chase_alarm() -> void:
	if _alarm_left > 0.0:
		return
	_alarm_left = ALARM_COOLDOWN
	Sfx.play(get_tree(), Sfx.alarm())
	Sfx.message(get_tree(), "Detected! Break line of sight!")


## PATROL music restore: near drone (< STEALTH_DISTANCE) keeps STEALTH,
## far eases out through calm_down(). Positions come straight from the
## drone/player nodes (the only proximity source the drone exposes).
func _on_patrol_restore() -> void:
	if _player != null and _drone != null and is_instance_valid(_player) and is_instance_valid(_drone):
		if _player.global_position.distance_to(_drone.global_position) < STEALTH_DISTANCE:
			Audio.set_music_state(Audio.MusicState.STEALTH)
			return
	Audio.calm_down()


## NIVEL 1 real tilemap: main.tscn instances scenes/level/level1_map.tscn (built
## by tools/build_level1_map.gd from its authored grid). When the baked Level
## node is present, runtime geometry/nav generation is skipped (flag below);
## LevelBuilder/LevelDressing stay in the repo as the frozen-data source and
## as the fallback when the flag is off. Nothing else changes: all gameplay,
## objectives, AI, noise, pulse, HUD, music and settings scripts are intact.
const USE_REAL_MAP := true
## Doorway portals (industrial re-layout): the coarse walk_rects polygons do
## NOT reliably auto-connect across rooms (verified by probe: area overlaps
## never link, shared-edge bake is timing-fragile), so every doorway gets an
## explicit bidirectional NavigationLink2D (start/end seated inside the rooms
## on both sides, traversal line through the open gap). The canonical Godot
## solution for doors/gaps; agents route islands -> link -> island. Doors
## still block bodies physically until opened; the drone keeps its direct
## steering fallback for off-link pursuit.
const NAV_LINKS: Array = [
	[Vector2(-232, 440), Vector2(-168, 440)], # ab gap
	[Vector2(-40, 350), Vector2(-40, 200)], # DoorA (needs OPEN door)
	[Vector2(-440, 180), Vector2(-440, 0)], # C-D link
	[Vector2(-440, -100), Vector2(-440, -260)], # D-E link
	[Vector2(40, 180), Vector2(40, 0)], # C-F link
	[Vector2(200, 200), Vector2(200, 300)], # W door
	[Vector2(190, -40), Vector2(330, -40)], # DoorB (needs OPEN door)
	[Vector2(240, 180), Vector2(340, 180)], # C-G entry preview
	[Vector2(440, -240), Vector2(440, -380)], # G-H link
	[Vector2(640, -470), Vector2(760, -470)], # H-I link
]


## Level 1 controlled reset: CERO generacion en runtime. Level/Floor/Walls/
## Structures/Decoration/Navigation son nodos explicitos en main.tscn; no se
## llama a LevelBuilder/LevelDressing/nav por codigo (desactivados, no
## eliminados: scripts/level/level_builder.gd, level_dressing.gd y
## tileset_factory.gd quedan en el repo como cinta metrica congelada).
func _build_navmesh() -> void:
	if USE_REAL_MAP and _has_baked_nav():
		return # authored Level/Navigation owns the navmesh.
	# Controlled-reset guard: never generate nav at runtime even if the
	# authored polygon were missing (a missing nav must be fixed in the .tscn,
	# not synthesized from LevelBuilder.walk_rects).
	return


## Sector 01 static geometry: authored nodes in main.tscn are the only wall
## source (UNA sola geometria en ejecucion). The old tilemap instance
## (scenes/level/level1_map.tscn), LevelBuilder and LevelDressing are
## bypassed here (desactivados, no eliminados) while the authored Level node
## is present.
func _build_level() -> void:
	if USE_REAL_MAP and has_node("Level"):
		return
	# Controlled-reset guard: never call LevelBuilder/LevelDressing at runtime.
	# If Level is missing, fail visibly so the .tscn gets fixed (no fallback).
	push_warning("Main: authored Level missing; runtime level build is disabled by controlled reset.")
	return


## True when the authored Level/Navigation node provides a navigation polygon.
func _has_baked_nav() -> bool:
	var baked := get_node_or_null("Level/Navigation") as NavigationRegion2D
	if baked == null:
		baked = _nav_region
	return baked != null and baked.navigation_polygon != null and baked.navigation_polygon.get_polygon_count() > 0


## SECURITY ONLINE: first energy ON wakes the dormant drone with message +
## sting; red security lights already flare via LevelBuilder energy link.
func _wire_security_online() -> void:
	var energy := get_node_or_null("EnergySystem") as EnergySystem
	if energy == null:
		energy = get_tree().get_first_node_in_group("energy_system") as EnergySystem
	if energy != null and energy.has_signal("energy_changed"):
		energy.energy_changed.connect(_on_energy_security)


func _on_energy_security(on: bool) -> void:
	if not on or _drone == null or not is_instance_valid(_drone):
		return
	if _drone.get("dormant") == true:
		_drone.activate()
		print("Main: SECURITY SYSTEM ONLINE.")
		Sfx.play(get_tree(), Sfx.alarm())
		Sfx.message(get_tree(), "SECURITY SYSTEM: ONLINE")
