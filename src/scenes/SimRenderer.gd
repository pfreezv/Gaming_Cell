## SimRenderer.gd
## Fase 5 — Renderer visual de la simulación
## Dibuja moléculas y compartimentos en pantalla usando _draw().
## Los colores y radios vienen de science-params.json.
## Se actualiza cada frame llamando queue_redraw() desde _process().

extends Node2D
class_name SimRenderer

## Área de render dentro de la ventana (deja espacio al panel izquierdo de UI)
var render_area := Rect2(310.0, 10.0, 950.0, 600.0)

## Tablas de visualización cargadas desde JSON
var _mol_colors: Dictionary = {}   ## type → Color
var _mol_radii:  Dictionary = {}   ## type → float (px en espacio mundo)

## Factor de escala mundo→pantalla
var _scale := Vector2.ONE

## Color de fondo del área de simulación
const BG_COLOR       := Color(0.04, 0.06, 0.10)
const BORDER_COLOR   := Color(0.2,  0.3,  0.4, 0.6)

# ──────────────────────────────────────────────
# CICLO DE VIDA
# ──────────────────────────────────────────────

func _ready() -> void:
	_recalculate_scale()

func _load_visuals() -> void:
	if GameState.science_params.is_empty():
		push_warning("[SimRenderer] science_params vacío al cargar visuals")
		return

	var mol_defs: Dictionary = GameState.science_params.get("molecules", {})
	for mol_type in mol_defs:
		if mol_type.begins_with("_"):
			continue
		var def: Dictionary = mol_defs[mol_type]
		var color_str: String = def.get("color", "#ffffff")
		_mol_colors[mol_type] = Color(color_str)
		_mol_radii[mol_type]  = float(def.get("r", 6))

	_recalculate_scale()
	print("[SimRenderer] Visuals cargados: %d tipos de molécula" % _mol_colors.size())

func _recalculate_scale() -> void:
	var world := MoleculeSystem.world_size
	_scale = Vector2(
		render_area.size.x / world.x,
		render_area.size.y / world.y
	)

func _process(_delta: float) -> void:
	queue_redraw()

# ──────────────────────────────────────────────
# DRAW
# ──────────────────────────────────────────────

func _draw() -> void:
	_draw_background()
	_draw_compartments()
	_draw_molecules()
	_draw_border()

func _draw_background() -> void:
	draw_rect(render_area, BG_COLOR)

func _draw_border() -> void:
	draw_rect(render_area, BORDER_COLOR, false, 1.5)

func _draw_molecules() -> void:
	for m in MoleculeSystem.molecules:
		var pos   := _to_screen(m.x, m.y)
		var r     := maxf(_mol_radii.get(m.type, 5.0) * _scale.x, 2.0)
		var color: Color = _mol_colors.get(m.type, Color.WHITE)

		## Moléculas no hidratadas → más oscuras
		if not m.get("hydrated", true):
			color = color.darkened(0.45)

		## Moléculas dentro de compartimento → más brillantes
		if m.get("bound_to") != null:
			color = color.lightened(0.25)

		## Degradación visible: opacidad según estabilidad
		var stability: float = m.get("stability", 1.0)
		color.a = clampf(stability, 0.3, 1.0)

		draw_circle(pos, r, color)

func _draw_compartments() -> void:
	var cap_r: float = GameState.science_params \
		.get("vesicle", {}).get("vesicle_detection_radius", 80.0) * _scale.x

	for comp in CompartmentSystem.compartments:
		var pos := _to_screen(comp.x, comp.y)

		var edge_color: Color
		var fill_alpha: float
		match comp.type:
			"protocell":
				edge_color = Color(1.0, 0.85, 0.1)
				fill_alpha = 0.10
			"vesicle":
				edge_color = Color(0.35, 0.75, 1.0)
				fill_alpha = 0.06
			_:  ## micela
				edge_color = Color(0.7, 0.7, 0.4)
				fill_alpha = 0.04

		## Relleno semi-transparente
		draw_circle(pos, cap_r, Color(edge_color.r, edge_color.g, edge_color.b, fill_alpha))
		## Borde
		draw_arc(pos, cap_r, 0.0, TAU, 64, edge_color, 1.5)

		## Etiqueta del tipo
		var lbl := comp.type.to_upper()
		draw_string(
			ThemeDB.fallback_font,
			pos + Vector2(-20.0, -cap_r - 4.0),
			lbl,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			11,
			edge_color
		)

# ──────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────

func _to_screen(wx: float, wy: float) -> Vector2:
	return Vector2(
		render_area.position.x + wx * _scale.x,
		render_area.position.y + wy * _scale.y
	)
