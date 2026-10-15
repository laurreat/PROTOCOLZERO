# PROTOCOL:ZERO — Matriz interna de continuidad (Sector 01)

> Herramienta de diseño. NO se muestra al jugador. Fuente de verdad jugable: `scripts/data/sector01_docs.gd`.
> Canon previo respetado: R. Okonkwo, puertas D2/D5, terminal energy-gated, técnico 3 s, ZERO one-use, drones por ruido, sin armas.

## Cronología interna (historia, no orden de lectura)
1. Meses previos: fluctuaciones red (2 avisos). Revisión cableado OK (primavera).
2. Semana previa: órdenes raras (quitan acceso lab, ocultar armario, sellar D2 18:05 por R. Okonkwo).
3. Día 0, 01:50: drones inquietos, fijan vacío; bloqueo denegado por Dirección.
4. Día 0, 02:12: laboratorio + control ZERO +40% demanda; absorción ordenada.
5. Día 0, 02:40 prealarma; 03:00 evacuación sur (no extracción norte); 03:13 caída total (principal+auxiliar+baterías en 4 s); seguridad ya controlaba terminales y D2/D5.
6. Día 0, 03:17: ocupante hallado en inicio sin credencial ni accesos (registro emergencia). Posible estasis Z-0 (efecto: amnesia corto plazo; no se afirma identidad).
7. Juego: restaurar energía → terminal → técnico repara esclusa → activar ZERO (USER DETECTED, override) → extracción. ZERO sigue tratando ruido/consumo como amenaza (drones activos).
8. Cierre S01: ZERO activo, paso abierto, cajas no listadas a subnivel + luz/señal abajo → pregunta S02.

## Matriz (lectura en cualquier orden; cada doc autocontenido)

| ID | Ubicación real | Momento histórico | Autor / voz | Conocimiento previo | Información nueva | Conexiones | Revelación | Dependencias | Estado |
|---|---|---|---|---|---|---|---|---|---|
| S01-D01 p1 | Inicio (-80,60) LoreInicio | Día 0 03:17 | Sistema emergencia (automático) | Telemetría evacuación 68% | Apagón total 4 s; seguridad tomó terminales/D2/D5 antes; ocupante sin registro; ir a generadores | → D04 (tercera fluctuación), → D03 (D2) | No fue fallo eléctrico ordinario | Ninguna | Integrado |
| S01-D02 p2 | Almacén (800,-340) LoreAlmacen | Día 0 02:40-03:00 | J. M., Logística (práctica) | Inventario 14 bultos | 2 cajas no listadas a subnivel sin firma; evacuación sur ilógica; Okonkwo selló D2 | → D03 (Okonkwo/D2), → D08 (subnivel) | Algo se movía abajo antes del apagón | Ninguna | Integrado |
| S01-D03 p3 | Taller (1050,560) LoreTaller | Día 0 18:05 + previo | R. Okonkwo, Mantenimiento (técnica) | Órdenes sellado | D2 sellada por orden sin motivo escrito; parpadeos + drones mirando techo; no forzar, usar terminal+técnico | → D04 (informe 12), → D05 (drones) | Fallo precedido por anomalías | Ninguna | Integrado |
| S01-D04 p4 | Generadores (860,140) LoreGeneradores | Día 0 02:12 | Mantenimiento, turno (técnico) | Informes 1-11 | +40% lab+ZERO, absorción ordenada, no cableado; manual: energía→terminal→D5; arranques hacen ruido | → D05 (ruido/drones), → D06 (lab) | La red fue priorizada, no rota | Ninguna | Integrado |
| S01-D05 p5 | Seguridad (2150,-60) LoreSeguridad | Día 0 01:50-03:13 | Turno noche, Seguridad (operativa) | Protocolo contención | Drones fijan vacío, bloqueo denegado, terminales bajo seguridad; drones marcan/siguen, no disparan; romper visión | → D06 (ZERO), → D04 (ruido) | Seguridad sabía y fue contenida | Ninguna | Integrado |
| S01-D06 p6 | Laboratorio (2104,-420) LoreLab | Días previos-02:12 | E. V., Investigación (analítica) | Proyecto ZERO | ZERO gestión adaptativa energía/seguridad; simulación fondo ("sueña"); pidió más potencia; Dirección restringió; quemar nota | → D07 (auth denegada) | Qué investigaban y qué se ocultó | Ninguna | Integrado |
| S01-D07 p7 | Control ZERO (2690,-120) LoreTerminal | Día 0 03:13 + juego | Dirección + Sistema ZERO (institucional+sistema) | Sellado BLACK | Apagón = contención ZERO ante cascada; evacuación sur para alejar del lab; estasis Z-0 explica amnesia sin nombrar; activar = operador reconocido, override, paso abierto | ← D01-D06 (evidencias), → D08 | Reinterpretación central verificable | Ninguna obligatoria; rinde más con D04+D06 | Integrado |
| S01-D08 p8 | Extracción (2480,330) LoreExtraccion | Post-activación | Personal, nota manuscrita (humana) | Salida norte | Bajaron, no subieron; seguir luz; lo logrado (ZERO activo, esclusa operativa); queda: identidad, subnivel, señal | ← D07, ← D02 (subnivel) | Cierre S01 + pregunta S02 | Ninguna | Integrado |

## Reglas aplicadas
- Cada doc aporta dato nuevo; pistas preparadas (fluctuaciones→absorción→contención); D07 reinterpreta sin contradecir.
- Mecánicas: energía→terminal (D4), ruido→drones (D4/D5), técnico 3 s esclusa (D3), ZERO one-use USER DETECTED→override (D7), salida tras ZERO (D8).
- Sin armas; drones no disparan. Identidad protagonista: solo estasis posible, sin nombre.
- Nombres: solo R. Okonkwo (canon); resto roles/iniciales. Sin orgs nuevas.
