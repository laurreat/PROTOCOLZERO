# PROTOCOL: ZERO

Videojuego 2D top-down de sigilo, exploración y ciencia ficción con atmósfera
de terror industrial. Desarrollado con **Godot 4.7.2**. Prototipo funcional
en desarrollo. Versión disponible: Windows de 64 bits.

## Sinopsis

Una instalación tecnológica queda a oscuras tras un apagón total. El
protagonista despierta sin memoria en el Sector 01 y debe restaurar la
energía, usar las terminales, conseguir la ayuda del técnico, activar el
sistema ZERO y alcanzar la extracción, mientras los drones de seguridad
patrullan la instalación y reaccionan al ruido.

## Características implementadas

Comprobadas en el ejecutable de Windows:
- Exploración top-down del Sector 01 con cámara seguidora.
- Movimiento por teclado en 8 direcciones.
- Interacción con documentos (8 archivos coleccionables en español),
  terminales y puntos de interés.
- HUD con energía, objetivo, tiempos de pulso y dash, y mensajes.
- Pulso (onda de detección) y dash evasivo con tiempos de recarga.
- Menú principal (Jugar, Instrucciones, Configuración, Salir) y menú de
  pausa (Continuar, Reiniciar, Configuración, Instrucciones, Volver al menú).
- Sistemas de energía, terminales con bloqueo de puertas y drones con
  estados de patrulla, investigación y persecución.
- Audio integrado: música adaptativa, ambiente de maquinaria con energía,
  efectos de interfaz, puertas, terminales, generador y alarmas.

Pendiente de validación manual en el ejecutable: escucha de niveles y mezcla,
recorrido completo de progresión (reparación, técnico, ZERO, extracción) y
volúmenes finales.

## Controles

| Acción     | Tecla          |
|------------|----------------|
| Movimiento | WASD o flechas |
| Interactuar | E              |
| Pulso      | Espacio        |
| Dash       | Shift          |
| Pausa      | Esc            |

El dash tiene 3 segundos de recarga y hace ruido: los drones acuden al ruido.

## Cómo ejecutar el juego

### Opción 1: desde Godot

1. Instalar Godot 4.7.2 (misma versión del proyecto).
2. Abrir el editor e importar el proyecto con `project.godot`.
3. Esperar a que termine la importación de recursos.
4. Pulsar F5 o el botón Play del editor (escena inicial:
   `scenes/menu/main_menu.tscn`).

Comprobación sin ventana:
`godot --headless --editor --path <repo> --quit` (cero errores).

### Opción 2: versión de Windows

Repositorio: `https://github.com/laurreat/PROTOCOLZERO`

Releases: `https://github.com/laurreat/PROTOCOLZERO/releases`

Cuando se publique una versión, el ejecutable estará adjunto a la release
(etiqueta actual: `v0.1.0`). Para jugar hacen falta los dos archivos juntos
en la misma carpeta: `PROTOCOL-ZERO.exe` y `PROTOCOL-ZERO.pck`.
La carpeta local `builds/windows/` no forma parte del repositorio.

## Requisitos técnicos

- Windows de 64 bits para el ejecutable.
- Godot 4.7.2 para abrir el proyecto desde el editor.

## Estructura del proyecto

- `assets/`: recursos visuales y de audio (`audio/` con `music/`,
  `ambience/` y `sfx/`; sprites, marcos e iconos).
- `scenes/`: escenas del juego (menú, nivel, jugador, drones, interfaz).
- `scripts/`: lógica y sistemas; `scripts/data/sector01_docs.gd` contiene
  los 8 documentos del Sector 01.
- `docs/`: registros técnicos, procedencia del audio, continuidad
  narrativa y capturas del motor.
- `img/`: arte del menú principal y referencia visual.
- `project.godot`, `icon.svg`, `export_presets.cfg`: configuración.

## Estado del desarrollo

Prototipo funcional del Sector 01. Implementado y comprobado: arranque,
menús, movimiento, interacciones, lectura de documentos, pulso, dash, pausa,
HUD, drones y audio integrado con respaldo procedural.
Pendiente (requiere partidas manuales): mezcla y niveles de audio,
circuito completo en el ejecutable y pulido final. Sin fechas de
lanzamiento comprometidas.

## Créditos y licencias

El código, las escenas, la narrativa en español y el arte Blender/Krita de
este repositorio son obra del autor (sin archivo de licencia general por el
momento). El audio de terceros se usa bajo sus propias licencias, con
trazabilidad completa en `docs/audio-provenance/`:

**CC-BY 3.0/4.0 (atribución obligatoria):**
- bart — `01_instalacion_dark_factory` ([Dark Factory](https://opengameart.org))
- dklon — `02/03_ventilacion_ambient_hum` ([Ambient Spaceship Hums](https://opengameart.org))
- Eric Matyas ([Soundimage.org](https://soundimage.org)) — `05_maquinaria_titan_powerplant` ("Titan Powerplant")
- Little Robot Sound Factory ([littlerobotsoundfactory.com](https://www.littlerobotsoundfactory.com)) — `21/22_peligro_alarm`
- Michael Brigida y estudiantes OLPC/Berklee — maquinaria `06/07/09/10` y `08_electricidad` ([12 Ambient Machine Sounds](https://opengameart.org))
- Blender Foundation (Yo Frankie!) — `24–27_agua_goteo`

**CC0 (sin atribución obligatoria, aquí reconocidos):**
- SRG774 — música de menú, exploración, sigilo, tensión, peligro y victoria ([Dark Sci-Fi Audio Pack](https://opengameart.org))
- Ruskerdax — `08_tension_menacing_otherworld` ([Menacing Otherworld](https://opengameart.org))
- Spring Spring — `04_tecnologico_scifi_background`
- Kenney — servidores y motores `12–20` ([Sci-Fi Sounds](https://opengameart.org))
- rubberduck — arranques eléctricos y engranajes ([60 CC0 Sci-Fi SFX](https://opengameart.org/content/60-cc0-sci-fi-sfx))
- yd — terminales, puertas y golpes ([Platformer Sounds](https://opengameart.org/content/platformer-sounds-terminal-interaction-door-shots-bang-and-footsteps))
- Sheyvan, AudioPapkin, prophecy77, RyanKingArt, AardsReal ([freesound.org](https://freesound.org), CC0)
- Independent.nu (vía qubodup) — `23_agua_goteo_loop`
- Pack Persona 2 — efectos UI, terminales y puertas sintetizados originales (libres según `docs/audio-provenance/LEEME.txt`)

Tipografía de interfaz: Bahnschrift (fuente del sistema).
