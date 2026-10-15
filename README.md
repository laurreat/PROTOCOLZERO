# PROTOCOL: ZERO

Top-down 2D stealth prototype in **Godot 4.7.2** (GL Compatibility).
Premise: *"El apagón fue solo el comienzo."* Restore power, use the terminal,
get the technician's help, repair the gate, activate the ZERO system and
reach the exit — while security drones watch and listen.

## Open and run

- Open `project.godot` in Godot 4.7.2 (entry scene: `scenes/menu/main_menu.tscn`).
- Press F5 (or the Play button) to run from the editor.
- Headless check: `godot --headless --editor --path <repo> --quit` (zero errors).
- Controls: WASD/arrows move, Shift dash (loud, 3 s cooldown), E interact,
  Space pulse, Esc pause. No weapons.

## Layout

- `scenes/` + `scripts/` — gameplay, one folder per responsibility
  (`player/`, `interact/`, `enemies/`, `npc/`, `systems/`, `ui/`, `fx/`,
  `level/`, `menu/`; `managers/` holds the Audio/Settings autoloads).
- `scripts/data/sector01_docs.gd` — all 8 Spanish Sector 01 documents.
- `assets/audio/` — `music/`, `ambience/`, `sfx/{ui,doors,terminals,generators,protocol}`.
  Gameplay loads real files first with procedural fallback
  (`scripts/audio/sfx.gd`), so a missing file never breaks a run.
- `assets/visual/`, `assets/ui/`, `img/` — sprites, frames, icons, menu art.
- `docs/` — `audio-provenance/` (sources, licences, integration log),
  narrative continuity, architecture notes, engine captures.
- `project.godot`, `icon.svg`, `export_presets.cfg` — project setup.

## Executable builds

Windows 64-bit builds live under `builds/windows/` (local) and, when
available, attached to a GitHub Release on this repository. The `.exe`
ships next to its `.pck`: both files are required to play.

## Credits and attribution

Original code, scenes, narrative (Spanish) and Blender/Krita art in this
repository are the author's work (no separate code licence file yet).
Third-party audio is used under its own licences — full traceability in
`docs/audio-provenance/`:

**CC-BY 3.0/4.0 (attribution required):**
- bart — `01_instalacion_dark_factory` ([Dark Factory](https://opengameart.org))
- dklon — `02/03_ventilacion_ambient_hum` ([Ambient Spaceship Hums](https://opengameart.org))
- Eric Matyas ([Soundimage.org](https://soundimage.org)) — `05_maquinaria_titan_powerplant` ("Titan Powerplant")
- Little Robot Sound Factory ([littlerobotsoundfactory.com](https://www.littlerobotsoundfactory.com)) — `21/22_peligro_alarm`
- Michael Brigida y estudiantes OLPC/Berklee — `06/07/09/10` machinery, `08_electricidad` ([12 Ambient Machine Sounds](https://opengameart.org))
- Blender Foundation (Yo Frankie!) — `24–27_agua_goteo`

**CC0 (no attribution required, credited here anyway):**
- SRG774 — menu/exploration/stealth/tension/danger/victory music ([Dark Sci-Fi Audio Pack](https://opengameart.org))
- Ruskerdax — `08_tension_menacing_otherworld` ([Menacing Otherworld](https://opengameart.org))
- Spring Spring — `04_tecnologico_scifi_background`
- Kenney — `12–20` servers/engines ([Sci-Fi Sounds](https://opengameart.org))
- rubberduck — generator/electric one-shots ([60 CC0 Sci-Fi SFX](https://opengameart.org/content/60-cc0-sci-fi-sfx))
- yd — terminal/door/bang ([Platformer Sounds](https://opengameart.org/content/platformer-sounds-terminal-interaction-door-shots-bang-and-footsteps))
- Sheyvan, AudioPapkin, prophecy77, RyanKingArt, AardsReal ([freesound.org](https://freesound.org), CC0)
- Independent.nu (via qubodup) — `23_agua_goteo_loop`
- Persona 2 pack — original synthetic UI/terminal/door WAVs (licence-free per `docs/audio-provenance/LEEME.txt`)

UI font: Bahnschrift (system font).
