## GameState.gd
## Autoload — accesible desde cualquier nodo como GameState.temp
## Contiene TODO el estado global del juego. Nunca variables globales sueltas.
## Equivalente al objeto GameState del prototipo HTML.

extends Node

# ======================================================
# META / CICLO GLOBAL
# ======================================================
var tick_count: int = 0
var elapsed_time_sec: float = 0.0
var is_paused: bool = false
var sim_speed: float = 1.0
var current_run_id: String = "run-uninitialized"
var telemetry_schema_version: String = "sim.v1"
var auto_telemetry_enabled: bool = false
var auto_snapshot_every_ticks: int = 60
var telemetry_output_dir: String = "user://telemetry"
var max_in_memory_events: int = 128

# ======================================================
# ENTORNO GLOBAL
# ======================================================
var current_biome: String = "warm_pond"
var temperature_c: float = 40.0
var ph: float = 7.0
var hydration: float = 0.65
var energy_flux: float = 0.4
var mineral_catalysis: float = 0.2

# Eventos globales activos
var active_events: Array = []
var uv_active: bool = false

# ======================================================
# POOLS / MOLÉCULAS / RECURSOS
# ======================================================
var molecules := {}
# Ejemplo:
# {
#   "h2o": {"count": 200, "energy": 0},
#   "amino_gly": {"count": 12, "energy": 0.1}
# }

var molecule_instances: Array = []
# Si decidimos mantener entidades individuales además de pools agregados.

# ======================================================
# ESTRUCTURAS EMERGENTES
# ======================================================
var compartments: Array = []
var catalytic_networks: Array = []
var proto_cells: Array = []

# ======================================================
# ESTADO DE PROGRESIÓN
# ======================================================
var milestones := {
	"concentration_threshold_reached": false,
	"polymer_detected": false,
	"compartment_formed": false,
	"metabolic_cycle_detected": false,
	"proto_cell_emerged": false
}

var progress_score: float = 0.0

# ======================================================
# MÉTRICAS / TELEMETRÍA
# ======================================================
var telemetry := {
	"total_reactions": 0,
	"reaction_candidates_last_tick": 0,
	"reactions_success_last_tick": 0,
	"failed_reactions": 0,
	"degraded_molecules": 0,
	"encapsulation_events": 0,
	"max_complexity_seen": 0.0
}

# ======================================================
# CONFIG CARGADA DESDE JSON
# ======================================================
var science_params := {}

# ======================================================
# API BÁSICA
# ======================================================
func _ready() -> void:
	start_new_run()

func reset_state() -> void:
	start_new_run()
	tick_count = 0
	elapsed_time_sec = 0.0
	is_paused = false
	sim_speed = 1.0

	current_biome = "warm_pond"
	temperature_c = 40.0
	ph = 7.0
	hydration = 0.65
	energy_flux = 0.4
	mineral_catalysis = 0.2

	uv_active = false
	active_events.clear()
	molecules.clear()
	molecule_instances.clear()
	compartments.clear()
	catalytic_networks.clear()
	proto_cells.clear()

	for k in milestones.keys():
		milestones[k] = false

	progress_score = 0.0

	for k in telemetry.keys():
		telemetry[k] = 0 if typeof(telemetry[k]) == TYPE_INT else 0.0

func start_new_run() -> void:
	var unix_time = Time.get_unix_time_from_system()
	current_run_id = "run-%s" % str(unix_time)

func set_auto_telemetry(enabled: bool, snapshot_every_ticks: int = 60, output_dir: String = "user://telemetry") -> void:
	auto_telemetry_enabled = enabled
	auto_snapshot_every_ticks = max(1, snapshot_every_ticks)
	telemetry_output_dir = output_dir

func build_state_snapshot(extra_data: Dictionary = {}) -> Dictionary:
	var by_type := {}
	var total_count := 0

	if not molecule_instances.is_empty():
		for molecule in molecule_instances:
			var molecule_type = molecule.get("type", "unknown")
			by_type[molecule_type] = by_type.get(molecule_type, 0) + 1
			total_count += 1
	else:
		for molecule_id in molecules.keys():
			var pool = molecules[molecule_id]
			var pool_count = int(pool.get("count", 0))
			if pool_count <= 0:
				continue
			by_type[molecule_id] = pool_count
			total_count += pool_count

	return {
		"schema_version": telemetry_schema_version,
		"run_id": current_run_id,
		"tick": tick_count,
		"time_sec": elapsed_time_sec,
		"environment": {
			"temperature": temperature_c,
			"ph": ph,
			"hydration": hydration,
			"energy_flux": energy_flux
		},
		"molecules": {
			"total": total_count,
			"by_type": by_type
		},
		"reactions": {
			"candidates_last_tick": telemetry.get("reaction_candidates_last_tick", 0),
			"success_last_tick": telemetry.get("reactions_success_last_tick", 0),
			"success_total": telemetry.get("total_reactions", 0),
			"failed_total": telemetry.get("failed_reactions", 0)
		},
		"progress": {
			"score": progress_score,
			"milestones": milestones.duplicate(true)
		},
		"extra": extra_data
	}

func build_event(event_type: String, payload: Dictionary = {}, severity: String = "info") -> Dictionary:
	return {
		"schema_version": telemetry_schema_version,
		"run_id": current_run_id,
		"tick": tick_count,
		"time_sec": elapsed_time_sec,
		"event_type": event_type,
		"severity": severity,
		"payload": payload
	}

func write_snapshot_json(path: String, extra_data: Dictionary = {}) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to write snapshot file at: %s" % path)
		return false
	file.store_string(JSON.stringify(build_state_snapshot(extra_data), "\t"))
	return true

func append_event_jsonl(path: String, event_type: String, payload: Dictionary = {}, severity: String = "info") -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE_READ)
	if file == null:
		push_warning("Unable to append event file at: %s" % path)
		return false
	var event_data = build_event(event_type, payload, severity)
	file.seek_end()
	file.store_line(JSON.stringify(event_data))
	active_events.append(event_data)
	if active_events.size() > max_in_memory_events:
		active_events = active_events.slice(active_events.size() - max_in_memory_events, active_events.size())
	return true

func advance_time(delta: float) -> void:
	if is_paused:
		return
	elapsed_time_sec += delta * sim_speed
	tick_count += 1
	_auto_record_telemetry()

func _auto_record_telemetry() -> void:
	if not auto_telemetry_enabled:
		return
	if tick_count <= 0:
		return
	if tick_count % auto_snapshot_every_ticks != 0:
		return
	if not _ensure_telemetry_output_dir():
		return

	var snapshot_path = "%s/snapshot-latest.json" % telemetry_output_dir
	var events_path = "%s/events.jsonl" % telemetry_output_dir
	var extra = {"source": "auto_recorder", "interval_ticks": auto_snapshot_every_ticks}
	var snapshot_ok = write_snapshot_json(snapshot_path, extra)
	if snapshot_ok:
		append_event_jsonl(events_path, "snapshot_recorded", {"snapshot_path": snapshot_path}, "info")

func _ensure_telemetry_output_dir() -> bool:
	var err = DirAccess.make_dir_recursive_absolute(telemetry_output_dir)
	if err != OK:
		push_warning("Unable to create telemetry output dir: %s" % telemetry_output_dir)
		return false
	return true

func register_molecule(id: String, amount: int, energy: float = 0.0) -> void:
	if not molecules.has(id):
		molecules[id] = {"count": 0, "energy": energy}
	molecules[id]["count"] += amount

func consume_molecule(id: String, amount: int) -> bool:
	if not molecules.has(id):
		return false
	if molecules[id]["count"] < amount:
		return false
	molecules[id]["count"] -= amount
	return true
