# PROTOCOL: ZERO — Current Architecture (post-cleanup 2026-10-11)

Top-down 2D stealth prototype, Godot 4.7.2, GL Compatibility. Entry:
`scenes/menu/main_menu.tscn` → JUGAR loads `scenes/level/protocol_zero_level_01.tscn`.

## Structure

- `scenes/` + `scripts/` — one folder per responsibility: `player/`, `interact/`
  (door/generator/terminal/lore/zero/exit + ranges), `enemies/`, `npc/`,
  `systems/`, `ui/`, `fx/`, `menu/`, `level/` (level_01 scene only).
- `assets/audio/sfx/{ui,doors,terminals,security,unsorted}` + `assets/ui/`
  (icons/frames) + `img/` (menu background + top_down reference art).
- `docs/` — README + audio-provenance + this file. No `tools/`, no `_archive/`,
  no `scenes/main/`, no tile/room_blender sources (all removed; see backup below).
- Autoloads: `Audio` + `Settings` (`scripts/managers/`). `scripts/main.gd` is
  legacy (belonged to the retired main.tscn) and is currently unwired.

## Systems

Energy / Noise / Objective (`scripts/systems/`) idle in level_01, verified safe
unwired. Player (CharacterBody2D + Camera2D + pulse device), SecurityDrone
patrol AI, Technician NPC, HUD/pause/fx, procedural SFX + music manager.
Settings (`user://settings.cfg`) owns audio/display/FPS; the menu stages
window/resolution as pending until APLICAR CAMBIOS commits (real
`resolution_matches()` read-back), reverting on close-without-apply.

## level_01

`ProtocolZeroLevel01` (Node2D): Player spawn (288, 672) + empty `Level`
(Floor/Walls/Doors/Props/Decals TileMapLayers, NO tilesets, NO cells) +
Energy/Noise/Objective nodes + SFX bus player. Clean base awaiting paint pass.

## Decisions

- Deleted with zero live refs verified by grep: `assets/tiles/`,
  `assets/tiles_hd/`, `assets/room_blender/`, `_archive/` (legacy main +
  room test), empty `scenes/main/`, `scripts/level/` (builder/dressing/factory/
  map/mask/overlay), `tools/` (map/mask builders; mask generator unused),
  `odd/tasks/protocol-zero-mvp.md` (history; Engram memory persists).
- `.godot/` untouched (cache, regenerates). External backups + Blender out
  of scope. Full pre-cleanup backup:
  `protocol-zero-backups/full-PRE-CLEANUP-20261011-2245/`.
