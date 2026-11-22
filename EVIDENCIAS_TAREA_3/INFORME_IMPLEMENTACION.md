# INFORME DE IMPLEMENTACIÓN — TAREA 3 (UNAD)
## PROTOCOL: ZERO — mejoras de usabilidad CAM-01 a CAM-07

---

## 1. Datos de la ejecución

| Dato | Valor |
|---|---|
| Fecha de ejecución | 22 de noviembre de 2026 |
| Motor | Godot **4.7.2 stable official** (`Godot_v4.7.2-stable_win64_console.exe`) |
| Renderer | Compatibilidad GL (OpenGL 3.3, AMD Radeon) |
| Prototipo | PROTOCOL: ZERO — rama `main`, commit base `9e91711` más los cambios de esta tarea |
| Escena inicial | `scenes/menu/main_menu.tscn` |
| Escena jugable | `scenes/level/sector_01_bloque_0.tscn` |
| Resolución de capturas | 1365 × 768 (ventana real del motor) |

### Cómo se obtuvieron las capturas

El entorno no ofrece captura de escritorio, así que **no se hicieron capturas de pantalla del sistema operativo**. En su lugar se ejecutó el juego real y se guardó el fotograma renderizado por el motor desde dentro del propio juego (`get_viewport().get_texture().get_image().save_png()`), mediante un arnés versionado en `tools/evidencias/captura.gd`.

- Las capturas **ANTES** se generaron ejecutando el código original desde un *worktree* de Git apuntando a `HEAD`, sin los cambios de esta tarea.
- Las capturas **DESPUES** se generaron ejecutando el proyecto modificado.
- El arnés no compone, no retoca y no simula estados: carga las escenas reales, provoca estados reales (reparar el generador, abrir puertas, lanzar el pulso, acercarse a un dron) y guarda el fotograma resultante.
- Los registros de cada ejecución quedan en `EVIDENCIAS_TAREA_3/_logs/` (`antes.log`, `despues.log`, `flujo.log`, `import_check.log`).

---

## 2. Escenas y scripts modificados

| Archivo | Tipo de cambio |
|---|---|
| `scenes/ui/hud.tscn` | Añadidos `PowerHint`, `ThreatChip`, `ControlsCard` y `HelpHint`; `MessageLabel` reubicado |
| `scripts/ui/hud.gd` | Subtítulo de energía, tarjeta de controles (automática y con H), chip de seguridad, objetivo n/5, retroalimentación con color, reubicación de mensajes |
| `scripts/interact/interactable.gd` | Anillo de enfoque discontinuo contextual (CAM-01) |
| `scripts/level/sector_01_bloque_0.gd` | Enfoque del interactuable más cercano, chip de seguridad agregado, avisos del pulso, mensaje de detección |
| `scripts/player/pulse_device.gd` | Señales `pulse_result` y `pulse_ended` (solo lectura; la mecánica queda intacta) |
| `scripts/enemies/security_drone.gd` | Etiqueta de estado en palabras, con tamaño y contorno legibles |
| `scripts/interact/door.gd` | Nombre legible y mensajes de acceso (concedido, denegado, dañado) |
| `scripts/interact/generator.gd` | Mensajes de energía con resultado (encendido, apagado, reparación) |
| `scripts/interact/terminal.gd` | Mensajes de concesión y denegación con el nombre de la puerta |
| `scripts/interact/zero_system.gd` | Denegación y activación con resultado |
| `scripts/interact/exit_zone.gd` | Denegación de salida con resultado |
| `scripts/npc/technician.gd` | Mensajes de estado con resultado |
| `scripts/audio/sfx.gd` | Nuevo `Sfx.feedback(tree, text, kind)` |
| `scripts/systems/objective_manager.gd` | Lectura de progreso (`get_current_index`, `get_total`) |
| `tools/evidencias/captura.gd` y `.tscn` | Arnés de capturas (nuevo, fuera del juego) |
| `tools/evidencias/flujo.gd` y `.tscn` | Prueba funcional del circuito completo (nuevo) |

**No se eliminaron escenas, recursos ni funcionalidades. No se cambió la identidad visual ni la perspectiva 2D top-down.**

---

## 3. CAM-01 — Objetos interactivos

**Problema original:** un participante no reconocía qué objetos del escenario podía usar; solo existía una línea de texto en la parte inferior.

**Solución:** la base `Interactable` construye en código un **anillo discontinuo cian** a partir del radio real de su `CircleShape2D`, de modo que no hay que editar cada escena. El coordinador del nivel enciende **solo el candidato más cercano** que el jugador ejecutaría y apaga el anterior, así que la pantalla no se satura. Se conserva el prompt inferior con la acción y la tecla.

**Archivos:** `scripts/interact/interactable.gd`, `scripts/level/sector_01_bloque_0.gd`.

**Prueba:** ejecución del arnés junto al generador y junto a la puerta; el registro muestra `prompt='Turn ON generator [E]'` y `prompt='Open door [E]'`, con el anillo visible sobre el objeto correcto.

**Evidencia:** `ANTES_02` / `DESPUES_02`, `DESPUES_04`.

---

## 4. CAM-02 — Controles

**Problema original:** dudas iniciales sobre las teclas de desplazamiento e interacción; los controles solo estaban en el menú.

**Solución:** tarjeta **CONTROLS** en el HUD que aparece automáticamente al iniciar la partida y se desvanece a los 8 s sin pausar el juego, más la pista persistente `H: CONTROLS` en la esquina inferior izquierda. La tecla **H** muestra u oculta la tarjeta en cualquier momento. Incluye mover, interactuar, pulso, dash, ayuda y pausa, y la nota de que los objetos cercanos se reseñan en cian.

**Archivos:** `scenes/ui/hud.tscn`, `scripts/ui/hud.gd`.

**Prueba:** captura al iniciar la partida con la tarjeta visible; después se ocultó por la misma ruta que usa H (`hide_controls`) antes de las demás tomas.

**Evidencia:** `DESPUES_03`. En ANTES, `ANTES_03` muestra que los controles solo estaban en el panel de instrucciones del menú.

---

## 5. CAM-03 — Energía y accesos

**Problema original:** costaba entender qué sistemas dependían de la energía disponible.

**Solución:**
- El HUD muestra ahora un **subtítulo de estado**: «No grid power — generator offline» o «Grid online — terminals, doors and ZERO energized».
- El generador avisa «POWER RESTORED — terminals and doors energized» y «POWER CUT — systems offline».
- Las puertas tienen nombre legible (`D1`, `D2`…) y responden «ACCESS GRANTED — D2 online», «ACCESS GRANTED — D2 open», «ACCESS DENIED — D2 needs power + terminal» y «DAMAGED — D2 needs a technician».
- El terminal concede o deniega indicando la puerta enlazada; ZERO y la salida también distinguen el resultado.

**Lógica intacta:** no se cambió la regla de escritor único de `EnergySystem`, ni los requisitos de las puertas, ni la secuencia de progresión.

**Archivos:** `hud.gd` y `hud.tscn`, `door.gd`, `generator.gd`, `terminal.gd`, `zero_system.gd`, `exit_zone.gd`.

**Prueba:** toma 04 (POWER: ON y acceso) y prueba de flujo (energía, terminal y puerta).

**Evidencia:** `ANTES_04` / `DESPUES_04`.

---

## 6. CAM-04 — Pulse Device

**Problema original:** dudas sobre qué hace el pulso y a qué afecta.

**Solución:**
- `PulseDevice` emite `pulse_result(stunned, radius)` y `pulse_ended(stunned)`; el coordinador los traduce a mensajes: «✓ PULSE — 1 drone stunned (220 px)», «! PULSE — no security drone in range» y «PULSE OVER — 1 drone back online».
- El dron afectado muestra **STUNNED** y queda congelado, como antes.
- El HUD ya mostraba `PULSE READY` y el cooldown; ahora se distingue la **activación** (anillo y mensaje verde) del **final** (mensaje de retorno).
- La tarjeta de controles explica «SPACE — stuns drones in range».

**Mecánica intacta:** radio de 220, cooldown de 6 s, aturdimiento de 4 s, ruido de 300 px y ausencia total de daño.

**Archivos:** `scripts/player/pulse_device.gd`, `scripts/level/sector_01_bloque_0.gd`, `scripts/ui/hud.gd`.

**Prueba:** `pulse.try_pulse()=true` y `dron stunned=3.9`; captura con el dron en STUNNED y el mensaje de un dron aturdido.

**Evidencia:** `ANTES_05` / `DESPUES_05`.

---

## 7. CAM-05 — Drones

**Problema original:** no era evidente si un dron había detectado al jugador.

**Solución:**
- La etiqueta flotante del dron escribe el estado en palabras, con fuente pequeña y contorno negro: `PATROL`, `DETECTING`, `INVESTIGATING`, `CHASE!`, `SEARCHING`, `STUNNED` y `OFF`.
- Se añade un **chip de seguridad** en el HUD, muestreado unas seis veces por segundo: `SECURITY: PATROL / SUSPICION / SEARCHING / ALERT / STUNNED / OFFLINE`, con color por nivel.
- Se conservan las señales existentes: destello de sospecha y detección, pitido en DETECT y alarma con cooldown en CHASE; la música adaptativa sigue igual.

**Lógica intacta:** la máquina de estados, la visión por cono y raycast, la navegación, el aturdimiento y el retorno no se tocaron. Solo cambió lo que se muestra.

**Archivos:** `scripts/enemies/security_drone.gd`, `scripts/level/sector_01_bloque_0.gd`, `scripts/ui/hud.gd`.

**Prueba:** estado real `CHASE` con `player_visible=true` a 119 px; captura con `CHASE!`, cono rojo y chip `SECURITY: ALERT`.

**Evidencia:** `ANTES_06` (solo el signo «!») / `DESPUES_06`.

---

## 8. CAM-06 — Retroalimentación

**Problema original:** hacía falta experimentar para entender que las acciones modificaban puertas y sistemas; además el prompt repetía el mensaje y se solapaba con él.

**Solución:**
- Nuevo `Sfx.feedback(tree, text, kind)` que llama a `HUD.show_feedback`: la misma línea transitoria, pero **con color y prefijo según el resultado**: verde con ✓ (éxito), rojo con ✕ (fallo), ámbar con ! (aviso) y blanco (informativo).
- Se aplicó a generador, terminal, puertas, técnico, ZERO, salida y detección.
- El mensaje subió de la banda −140/−108 a −182/−150 para no solaparse con el prompt de interacción.
- El prompt de una puerta dañada pasó de repetir el fallo a indicar la acción disponible: «Inspect damage [E]».

**Archivos:** `scripts/audio/sfx.gd`, `scripts/ui/hud.gd` y `hud.tscn`, y los scripts de interacción citados.

**Prueba:** la misma acción (interactuar con D2 dañada) antes y después.

**Evidencia:** `ANTES_07` (dos líneas idénticas solapadas) / `DESPUES_07` (mensaje `✕ DAMAGED — D2 needs a technician` y prompt `Inspect damage [E]`).

---

## 9. CAM-07 — Objetivo actual

**Problema original:** el flujo se entendía al recorrerlo, pero el objetivo no era evidente durante la exploración.

**Solución:**
- El HUD muestra `OBJECTIVE n/5 · <texto>` en la parte superior central. El manager expone `get_current_index()` y `get_total()` sin cambiar la señal existente.
- Al cambiar de objetivo se anuncia `✓ OBJECTIVE COMPLETE — next: <texto>`, de modo que el jugador ve que completó el paso anterior.
- Se mantiene la exploración: no hay flechas ni marcadores en el mundo.

**Archivos:** `scripts/systems/objective_manager.gd`, `scripts/ui/hud.gd`.

**Prueba:** toma 08 y prueba de flujo (índice 4, es decir 5/5, antes de la extracción).

**Evidencia:** `ANTES_08` / `DESPUES_08`.

---

## 10. Tabla de seguimiento

| Código | Mejora | Implementación | Prueba funcional | Evidencia |
|---|---|---|---|---|
| CAM-01 | Objetos interactivos | Anillo discontinuo cian en `Interactable` y enfoque del más cercano desde el coordinador | Captura con anillo en generador y puerta; prompt correcto en el registro | `ANTES_02` → `DESPUES_02`, `DESPUES_04` |
| CAM-02 | Controles | `ControlsCard` (automática 8 s y tecla H) y pista `H: CONTROLS` | Captura al iniciar; ocultación por la ruta real de H | `ANTES_03` → `DESPUES_03` |
| CAM-03 | Energía y accesos | Subtítulo de energía, mensajes con nombre de puerta, acceso concedido y denegado | Toma 04 y flujo completo (energía, terminal, D1) | `ANTES_04` → `DESPUES_04` |
| CAM-04 | Pulse Device | Señales `pulse_result` y `pulse_ended` con mensajes de activación y fin | Pulso real: un dron aturdido durante 3,9 s | `ANTES_05` → `DESPUES_05` |
| CAM-05 | Drones | Etiqueta de estado en palabras y chip `SECURITY:` | Estado real CHASE a 119 px, captura y registro | `ANTES_06` → `DESPUES_06` |
| CAM-06 | Retroalimentación | `Sfx.feedback` con color y prefijo, reubicación y prompt sin duplicado | La misma interacción en D2 dañada, antes y después | `ANTES_07` → `DESPUES_07` |
| CAM-07 | Objetivo actual | `OBJECTIVE n/5 · texto` y aviso de completado | Toma 08 y flujo con 5/5 | `ANTES_08` → `DESPUES_08` |

---

## 11. Pruebas ejecutadas y resultados

### 11.1 Compilación e importación

```
godot --headless --editor --path . --quit
→ exit 0, sin SCRIPT ERROR ni Parse Error
```

### 11.2 Capturas sobre las escenas reales

Ejecución del arnés en modo `despues` y en modo `antes` (worktree en `HEAD`): 8 + 8 capturas guardadas, `err=0` en todas.

### 11.3 Prueba funcional del circuito completo (`flujo.log`)

| Paso | Resultado |
|---|---|
| Energía ON tras la reparación de 3 s | OK (`energy_on=true`) |
| El terminal desbloquea D1 | OK (`terminal_unlocked=true`) |
| D1 se abre con E | OK (`state=OPEN`) |
| El técnico completa la reparación | OK (`state=DONE`) |
| D2 reparada y operable | OK (`repair_required=false`) |
| D2 se abre | OK (`state=OPEN`) |
| ZERO activado | OK (`zero_used=true`) |
| Objetivo 5/5 | OK (`index=4`) |
| Victoria en la extracción | OK (`win_visible=true`) |

**Resultado: 9 de 9 comprobaciones correctas.**

---

## 12. Problemas encontrados y soluciones aplicadas

| # | Problema | Solución |
|---|---|---|
| 1 | Errores de parseo en el arnés (`load(...).instantiate()` sin tipo) | Tipado explícito `var menu: Node` |
| 2 | `weakref()` inferido como Variant (los avisos se tratan como errores en 4.7) | Tipado `WeakRef` y `SceneTreeTimer` |
| 3 | Capturas descentradas por el suavizado de la cámara | `reset_smoothing()` después de cada teleporte de cámara |
| 4 | La derrota por captura cubría las tomas 05, 06 y 07 | Ritmo más corto y anulación del agarre **solo en el arnés** durante esas tomas |
| 5 | Mensaje y prompt solapados en la parte inferior | `MessageLabel` reubicado a −182/−150 |
| 6 | Texto duplicado en la puerta dañada | Prompt «Inspect damage [E]» y fallo en el mensaje |
| 7 | El primer intento de capturas ANTES se interrumpió por el tiempo de importación del worktree | Importación previa con `--headless --editor` y ejecución posterior |

---

## 13. Alcance y limitaciones

- **No se utilizó captura de escritorio:** las imágenes son fotogramas reales renderizados por Godot desde el propio juego, no recortes ni montajes.
- **El arnés de capturas y la prueba de flujo anulan el agarre del dron** (`catch_distance = 0`) para poder documentar estados sin que la pantalla de derrota los cubra. Ese ajuste **no existe en el juego**: vive únicamente en `tools/evidencias/`.
- El contador **FPS** aparece en las capturas porque está activado en la configuración del usuario (`user://settings.cfg`); no se modificó esa preferencia.
- La tarjeta de controles se ocultó con la misma ruta que usa la tecla H antes de las tomas 02 a 08, para no tapar la evidencia.
- No se condujo una sesión manual con teclado y ratón: la interacción se ejercitó por el despacho real del jugador (`InteractionDetector` → `Interactable.interact`). El movimiento, el dash y la cámara no se alteraron en esta tarea.
- El panel de instrucciones del menú no se rediseñó (los controles ya estaban allí); la mejora se concentró en la partida, que es donde el participante tuvo la duda.

---

## 14. Ubicación de las evidencias

```
EVIDENCIAS_TAREA_3/
├── ANTES/
│   ├── ANTES_01_Menu_principal.png
│   ├── ANTES_02_Exploracion_y_objetos.png
│   ├── ANTES_03_Controles_HUD.png
│   ├── ANTES_04_Energia_y_accesos.png
│   ├── ANTES_05_Pulse_Device.png
│   ├── ANTES_06_Dron_seguridad.png
│   ├── ANTES_07_Retroalimentacion.png
│   └── ANTES_08_Objetivo_actual.png
├── DESPUES/
│   ├── DESPUES_01_Menu_principal.png
│   ├── DESPUES_02_Exploracion_y_objetos.png
│   ├── DESPUES_03_Controles_HUD.png
│   ├── DESPUES_04_Energia_y_accesos.png
│   ├── DESPUES_05_Pulse_Device.png
│   ├── DESPUES_06_Dron_seguridad.png
│   ├── DESPUES_07_Retroalimentacion.png
│   └── DESPUES_08_Objetivo_actual.png
├── _logs/
│   ├── antes.log
│   ├── despues.log
│   ├── flujo.log
│   └── import_check.log
└── INFORME_IMPLEMENTACION.md
```

Arneses reproducibles: `tools/evidencias/captura.tscn` (capturas) y `tools/evidencias/flujo.tscn` (prueba de regresión).
