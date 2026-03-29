## ProgressSystem.gd
## S4 — Evaluación de milestones y condición de protocélula
## Evalúa cada tick si se alcanzan los umbrales de complejidad.
## Cuando todos los milestones están activos → victoria inicial.

extends Node

signal milestone_reached(milestone_id: String)
signal progress_updated(score: float)
signal victory()

## Umbrales para cada milestone
const CONCENTRATION_THRESHOLD := 5   ## moléculas complejas de un mismo tipo
const POLYMER_MIN_COUNT       := 1   ## PEPTID o RNA para "polímero"
const ATP_MIN_COUNT           := 1   ## ATP para ciclo metabólico

## Etiquetas legibles por milestone
const MILESTONE_LABELS := {
	"concentration_threshold_reached": "Concentración molecular",
	"polymer_detected":                "Polímero detectado",
	"compartment_formed":              "Compartimento formado",
	"metabolic_cycle_detected":        "Ciclo metabólico (ATP)",
	"proto_cell_emerged":              "PROTOCÉLULA EMERGENTE"
}

var _victory_fired: bool = false

# ──────────────────────────────────────────────
# CICLO DE VIDA
# ──────────────────────────────────────────────

func _ready() -> void:
	CompartmentSystem.protocell_emerged.connect(_on_protocell_emerged)

func _load_config() -> void:
	if GameState.science_params.is_empty():
		push_warning("[ProgressSystem] science_params vacío al cargar config")
		return
	print("[ProgressSystem] Config cargada")

func reset_system() -> void:
	_victory_fired = false

# ──────────────────────────────────────────────
# TICK
# ──────────────────────────────────────────────

func tick() -> void:
	_evaluate_milestones()
	_update_score()

func _evaluate_milestones() -> void:
	var by_type := MoleculeSystem.count_by_type()

	## Concentración: alguna molécula compleja alcanza el umbral
	if not GameState.milestones["concentration_threshold_reached"]:
		for mol_type in ["AMINO", "BASE", "LIPID", "NMP", "NUCLEOSID"]:
			if by_type.get(mol_type, 0) >= CONCENTRATION_THRESHOLD:
				_reach("concentration_threshold_reached")
				break

	## Polímero: PEPTID o RNA presente
	if not GameState.milestones["polymer_detected"]:
		if by_type.get("PEPTID", 0) >= POLYMER_MIN_COUNT or \
		   by_type.get("RNA",    0) >= POLYMER_MIN_COUNT:
			_reach("polymer_detected")

	## Ciclo metabólico rudimentario: ATP sintetizado
	if not GameState.milestones["metabolic_cycle_detected"]:
		if by_type.get("ATP", 0) >= ATP_MIN_COUNT:
			_reach("metabolic_cycle_detected")

func _reach(id: String) -> void:
	if GameState.milestones.get(id, false):
		return
	GameState.milestones[id] = true
	emit_signal("milestone_reached", id)
	print("[ProgressSystem] ✓ Milestone: %s" % MILESTONE_LABELS.get(id, id))

func _on_protocell_emerged(_comp: Dictionary) -> void:
	_reach("compartment_formed")
	_reach("proto_cell_emerged")

func _update_score() -> void:
	var total   := float(GameState.milestones.size())
	var reached := 0.0
	for k in GameState.milestones:
		if GameState.milestones[k]:
			reached += 1.0
	var new_score := reached / total
	if new_score != GameState.progress_score:
		GameState.progress_score = new_score
		GameState.telemetry["max_complexity_seen"] = maxf(
			GameState.telemetry["max_complexity_seen"], new_score
		)
		emit_signal("progress_updated", new_score)

	## Condición de victoria: todos los milestones activos
	if not _victory_fired and GameState.progress_score >= 1.0:
		_victory_fired = true
		emit_signal("victory")
		print("[ProgressSystem] ¡¡¡ PROTOCÉLULA VIABLE EMERGIDA — VICTORIA !!! ")

# ──────────────────────────────────────────────
# API DE DISPLAY
# ──────────────────────────────────────────────

func get_status_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for k in GameState.milestones:
		var icon := "✓" if GameState.milestones[k] else "○"
		lines.append("  %s %s" % [icon, MILESTONE_LABELS.get(k, k)])
	return lines

func get_progress_percent() -> int:
	return int(GameState.progress_score * 100.0)
