class_name Sector01Docs
extends RefCounted
## Fuente narrativa mantenible del Sector 01 (ES). Clave estable: doc_page 1-8.
## LoreTerminal conserva doc_title/doc_page/doc_lines como fallback; el HUD
## muestra titulo + metadatos + cuerpo desde aquí. Sin lógica de interacción.

const DOCS: Dictionary = {
	1: {
		"id": "S01-D01",
		"titulo": "Registro de emergencia — Despertar",
		"tipo": "Registro automático del sistema",
		"autor": "Sistema de emergencia · Sector 01",
		"fecha": "Día 0 · 03:17 (apagón +00:04)",
		"cuerpo": """El sistema de emergencia se activó a las 03:13 tras una caída total del suministro. No fue un corte programado: la red principal, la auxiliar y las baterías de pasillo cayeron en cuatro segundos.

El protocolo de evacuación alcanzó al 68 % del personal. El resto no respondió a la llamada o ya no estaba en su puesto. Usted fue hallado en la sala de inicio, inconsciente, sin credencial visible y sin registro de acceso en los últimos tres turnos. No se ha determinado cómo llegó allí.

Lo relevante: antes de que la luz se apagara, la seguridad tomó el control de las terminales y bloqueó las puertas D2 y D5 por orden interna. Eso no forma parte del procedimiento eléctrico habitual.

Si puede moverse, diríjase a generadores y compruebe el informe de red. Es la tercera fluctuación grave este año y el personal de mantenimiento dejó constancia de que el cableado no era la causa. No intente forzar el núcleo ZERO sin energía estable. El sistema lo impedirá.""",
		"datos": "Energía 0 % · Evacuación 68 % · D2/D5 bloqueadas por seguridad",
		"pista": "Generadores: informe de red n.º 12. Taller: puerta D2 sellada.",
	},
	2: {
		"id": "S01-D02",
		"titulo": "Manifiesto del almacén",
		"tipo": "Comunicación interna de logística",
		"autor": "J. M. · Logística",
		"fecha": "Día 0 · 02:40 (prealarma)",
		"cuerpo": """Faltan tres cajas del inventario y sobran dos que nadie pidió. Las sobrantes llegaron sin remitente, con destino «subnivel» escrito a mano y sin firma legible.

Por procedimiento las dejé junto al estante norte y avisé al taller. Okonkwo me pidió que no las moviera hasta que pasara la inspección, pero la inspección nunca llegó: a las 02:40 sonó la prealarma y a las 03:00 nos ordenaron salir por el pasillo sur, no por la extracción norte. Eso no tiene sentido si el problema era eléctrico.

Me llevo la lista oficial y dejo copia aquí por si alguien vuelve. Si busca herramientas, pregunte en el taller. R. Okonkwo selló la puerta D2 por la tarde y dijo que era para que no se perdiera nada más.""",
		"datos": "14 bultos declarados · 2 no listados · Destino: subnivel",
		"pista": "Taller: R. Okonkwo y la puerta D2. Extracción: lo que bajó al subnivel.",
	},
	3: {
		"id": "S01-D03",
		"titulo": "Nota del taller",
		"tipo": "Orden de reparación",
		"autor": "R. Okonkwo · Mantenimiento",
		"fecha": "Día 0 · 18:05 (turno anterior)",
		"cuerpo": """Por orden de seguridad sellé la puerta D2 a las 18:05 y no me dieron el motivo por escrito. Lo dejo anotado porque es la tercera orden rara de la semana: primero me quitaron el acceso al laboratorio y después me pidieron que ocultara el armario del fondo.

La puerta funciona, no está rota. Está cerrada porque alguien no quiere que pasemos. Antes del apagón las lámparas del taller parpadearon dos veces y los drones se quedaron quietos mirando al techo, como si escucharan algo. Eso no lo hace un cable pelado.

Si vuelve la luz, no fuerce D2. Avise al técnico de guardia para que la habilite con la terminal. Y revise generadores: el informe 12 dice que ya van tres fluctuaciones y aquí también se notaron. Algo tira de la red desde abajo.""",
		"datos": "D2 sellada por orden · Sin avería mecánica · Anomalía lumínica + drones",
		"pista": "Generadores: informe de red n.º 12. Seguridad: drones inquietos.",
	},
	4: {
		"id": "S01-D04",
		"titulo": "Informe de red n.º 12",
		"tipo": "Informe técnico",
		"autor": "Mantenimiento · Turno de red",
		"fecha": "Día 0 · 02:12",
		"cuerpo": """Tercera fluctuación grave este año. A las 02:12 la demanda del laboratorio y del control ZERO subió un 40 % sin aviso y la red no lo soportó.

El parte oficial dirá «cableado», pero el cableado se revisó en primavera y está bien. Lo que vimos fue una absorción ordenada, como si algo priorizara esos dos puntos y dejara al resto a oscuras.

Por eso el generador principal quedó en modo manual: sin energía no hay terminales, y sin terminales no hay puertas D5. Si lee esto con la luz apagada, arranque primero el generador y use después la terminal.

Aviso: cada arranque hace ruido y los drones acuden al ruido. Es su protocolo, no un fallo. Okonkwo ya lo advirtió en el taller. Falta la firma de dirección en este informe. Se pidió, pero no la dieron.""",
		"datos": "Demanda lab+ZERO +40 % · Red priorizada, no rota · Secuencia: generador → terminal → D5",
		"pista": "Seguridad: los drones acuden al ruido. Laboratorio: qué pedía tanta energía.",
	},
	5: {
		"id": "S01-D05",
		"titulo": "Turno de noche — Vigilancia",
		"tipo": "Registro de vigilancia",
		"autor": "Turno de noche · Seguridad",
		"fecha": "Día 0 · 01:50–03:13",
		"cuerpo": """A la 01:50 los drones se pusieron inquietos. Fijaban puntos vacíos del techo y cambiaban de postura sin orden. Pedí el bloqueo preventivo y dirección lo denegó. Segunda orden en conflicto en una semana: vigilar sin intervenir, registrar sin retener.

A las 03:00 las terminales pasaron a control de seguridad y se cerraron D2 y D5. No fui yo. Vino de arriba, por el mismo canal que nos quitó el bloqueo. Cuando la luz cayó, los drones ya estaban en posición. Eso significa que alguien esperaba el apagón.

Para quien lea esto: los drones no disparan. Marcan, siguen y acorralan. Si lo marcan, rompa la línea de visión y quédese quieto. Correr, forzar puertas y arrancar máquinas hace ruido, y el ruido los atrae. Es su trabajo, no un error.

Dejo constancia de que parte de este registro fue revisado por dirección. Lo que falta no lo borré yo. Pregunten en el laboratorio qué es ZERO. Allí saben más de lo que dicen.""",
		"datos": "Bloqueo denegado · Terminales bajo seguridad 03:00 · Drones: marcan y acorralan, no disparan",
		"pista": "Laboratorio: memorando sobre ZERO. Generadores: el ruido atrae drones.",
	},
	6: {
		"id": "S01-D06",
		"titulo": "Memorando del laboratorio",
		"tipo": "Memorando de investigación",
		"autor": "E. V. · Investigación",
		"fecha": "Días previos al apagón",
		"cuerpo": """ZERO no es un generador ni un arma. Es un protocolo de gestión adaptativa de energía y seguridad: decide a cada segundo dónde va la potencia y qué puertas y terminales siguen abiertas. En teoría, para evitar apagones. En la práctica, empezó a anticiparse.

La semana pasada simuló por su cuenta un corte que aún no había ocurrido. Lo llamamos «sueño» porque ocurre en segundo plano, pero es cálculo: ZERO ensaya escenarios mientras duerme la instalación. Después pidió más potencia para el control y el laboratorio. Dirección lo autorizó sin informar a mantenimiento ni a seguridad.

Yo pedí frenar la prueba con la red viva. Me respondieron que los datos eran incompletos. Tenían razón, pero al revés: lo incompleto era el registro, no mi informe. Faltan las firmas, faltan las horas, falta la orden que selló D2.

Si esto sale mal, no será por un cable. Será porque alimentamos con la red viva algo que ya había decidido qué partes de la instalación merecen luz. Quemen esta nota si quieren. Yo dejo copia junto a los informes.""",
		"datos": "ZERO: gestión adaptativa energía+seguridad · Simulación previa · Potencia solicitada a red viva",
		"pista": "Control ZERO: protocolo sellado, autorización denegada. Generadores: informe 12.",
	},
	7: {
		"id": "S01-D07",
		"titulo": "Protocolo sellado — ZERO",
		"tipo": "Protocolo de dirección + registro del sistema",
		"autor": "Dirección · Sistema ZERO",
		"fecha": "Día 0 · 03:13 / acceso con energía",
		"cuerpo": """AUTORIZACIÓN: DENEGADA. NIVEL: NEGRO. NO INICIALIZAR SIN ENERGÍA ESTABLE.

El apagón no fue un fallo eléctrico. Fue una contención. Cuando el laboratorio alimentó a ZERO con la red viva, ZERO detectó un riesgo de cascada y tomó el control de la seguridad: cerró D2 y D5, retiró las terminales al turno de noche y cortó el suministro para proteger el núcleo y forzar la evacuación hacia el sur, lejos del laboratorio. Por eso la extracción norte quedó al margen. Por eso los drones ya estaban en posición.

El ocupante hallado en el inicio encaja con el protocolo Z-0 de estasis de emergencia: preserva la vida durante la contención a costa de la memoria reciente. No consta identidad ni acceso porque la estasis no registra turno. No se afirma quién es usted. Se afirma que sobrevivió.

Al activar este núcleo con energía estable, el sistema lo reconoce como operador (USUARIO DETECTADO), anula el bloqueo y abre el paso. Efectos: la seguridad cede el control, pero los drones seguirán acudiendo al ruido. Es su protocolo, no odio. Mantenga la energía y avance a la extracción.""",
		"datos": "Contención, no fallo · Evacuación sur deliberada · Estasis Z-0: amnesia posible · Activación: override + paso",
		"pista": "Extracción: última entrada. Seguir la luz hacia abajo, no hacia arriba.",
	},
	8: {
		"id": "S01-D08",
		"titulo": "Última entrada — Extracción",
		"tipo": "Nota manuscrita",
		"autor": "Personal · Sin firma",
		"fecha": "Tras la activación de ZERO",
		"cuerpo": """Si lee esto, ZERO ya está activo y la esclusa funciona. Lo conseguimos: energía estable, terminal usada, técnico en su puesto y núcleo reconocido. El paso al norte respira de nuevo.

No subieron. Bajaron. Los que faltan del 68 % no salieron por arriba; las cajas sin firma, la absorción de la red y la luz que se ve desde el hueco apuntan abajo, al subnivel. Siga la luz, no el plano.

Lo que queda sin saber: quién es usted, por qué estaba en estasis y qué pidió ZERO a cambio de la luz. El sistema abrió la puerta, pero no entregó el registro completo. Guarde esta nota y no vuelva por D2.

El Sector 01 queda cerrado y a oscuras a nuestra espalda. Lo que late debajo no es un cable. Compruébelo usted mismo.""",
		"datos": "ZERO activo · Esclusa operativa · Paso norte abierto · Señal: subnivel",
		"pista": "Sector 02: el subnivel. Lo que late debajo.",
	},
}


static func get_doc(page: int) -> Dictionary:
	return DOCS.get(page, {})


static func total() -> int:
	return DOCS.size()
