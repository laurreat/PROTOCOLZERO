class_name LoreTerminal
extends Interactable
## Archivo del Sector 01. Modal de lectura con E, sin ruido y sin efecto en
## objetivos. Contenido ES desde Sector01Docs por doc_page (1-8); doc_lines y
## doc_title quedan como fallback por instancia para no romper identificadores.
## Lectura solo en memoria (sin guardado: el proyecto solo persiste settings).

const LINES: Array[String] = [
	"REGISTRO",
	"SIN ENERGÍA",
	"ARCHIVO INCOMPLETO",
	"RESTAURE LA LUZ",
]

## Documento propio de la instancia: si esta vacio se usa Sector01Docs.
@export var doc_lines: Array[String] = []
## Titulo y pagina narrativa del modal. Orden de descubrimiento: 1 Inicio,
## 2 Almacen, 3 Taller, 4 Generadores, 5 Seguridad, 6 Lab, 7 ZERO, 8 Extraccion.
@export var doc_title := "ARCHIVO"
@export var doc_page := 1
const DOC_TOTAL := 8

const COLOR_IDLE := Color(0.55, 0.60, 0.70)
const COLOR_READ := Color(0.70, 0.85, 0.95)

## Registro de lectura en memoria (sesión). Sin save: documentado en el informe.
static var _read_pages: Dictionary = {}

@onready var _visual: Polygon2D = $Visual


static func is_page_read(page: int) -> bool:
	return _read_pages.get(page, false)


static func mark_page_read(page: int) -> void:
	_read_pages[page] = true


func get_prompt() -> String:
	if is_page_read(doc_page):
		return "Archivo leído [E]"
	return "Leer archivo [E]"


func interact(_player: Node2D) -> void:
	var total: int = Sector01Docs.total() if Sector01Docs.total() > 0 else DOC_TOTAL
	var doc: Dictionary = Sector01Docs.get_doc(doc_page)
	print("LoreTerminal: p%d %s." % [doc_page, str(doc.get("titulo", doc_title))])
	Sfx.play(get_tree(), Sfx.tone(520.0, 0.06))
	var tree := get_tree()
	var hud: Node = tree.get_first_node_in_group("hud") if tree != null else null
	if doc.is_empty():
		var pool: Array[String] = doc_lines if not doc_lines.is_empty() else LINES
		if hud != null and hud.has_method("show_document"):
			hud.call("show_document", doc_title, pool, doc_page, total)
		else:
			Sfx.message(get_tree(), pool[0])
	else:
		if hud != null and hud.has_method("show_lore"):
			hud.call("show_lore", doc, doc_page, total)
		elif hud != null and hud.has_method("show_document"):
			var body: Array[String] = [str(doc.get("cuerpo", ""))]
			hud.call("show_document", str(doc.get("titulo", doc_title)), body, doc_page, total)
		else:
			Sfx.message(get_tree(), str(doc.get("titulo", doc_title)))
	mark_page_read(doc_page)
	if _visual != null:
		_visual.color = COLOR_READ
