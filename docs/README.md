# PROTOCOL: ZERO

Top-down 2D stealth prototype in **Godot 4.7.2** (GL Compatibility, Windows x86_64).
Premise: *"El apagón fue solo el comienzo."* Restore power, use the terminal,
get the technician's help, repair the gate, reach the exit — while a patrol
drone watches.

## Run

- Open `project.godot` in Godot 4.7.2 (entry scene: `scenes/menu/main_menu.tscn`).
- Headless check: `godot --headless --editor --path <repo> --quit` (zero errors).
- Smoke: `godot --headless --path <repo> --quit-after 120`.
- Controls: WASD/arrows move, Shift sprint (loud), E interact, Space pulse,
  Esc pause. No test runner (TDD disabled); temporary SceneTree probes only.

## Layout

- `scenes/` + `scripts/` — gameplay, one folder per responsibility
  (`player/`, `interact/`, `enemies/`, `npc/`, `systems/`, `ui/`, `fx/`,
  `level/`, `menu/`, `main/`, `managers/` for the Audio/Settings autoloads).
- `assets/audio/` — `music/` (reserved; `audio_manager` falls back to
  procedural placeholders until loops land there) + `sfx/{ui, doors,
  terminals, security, unsorted}` (Block A classification; `machines/` and
  `player/` stay pending until files need them).
- `assets/ui`, `assets/room_blender`, `assets/tiles`, `assets/tiles_hd`,
  `img/` — kept as-is (Block A changed nothing there).
- `docs/` — this file + `audio-provenance/` (original Persona 2/4 notes).
- `_archive/` — reserved for Block B (superseded scenes/backups).
- `odd/tasks/protocol-zero-mvp.md` — build log (single feature doc).
- `tools/` — level-builder utilities, not runtime code.

## Audio note

SFX are unused files for now: gameplay uses procedural tones
(`scripts/audio/sfx.gd`); the music manager scans `audio/music/` and
synthesizes placeholders when empty. Wiring real files in is Block B work.

## Known pending (Block A audit)

- `main.tscn` is minimal (Player + RoomBlenderTest) while `main.gd`
  expects HUD/Level/EnergySystem nodes — pre-existing mismatch, untouched.
- `level1_map.tscn` is not on disk (tool output only); several
  `assets/tiles*` / `img/` references dangle — documented, not fixed here.
