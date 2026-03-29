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
func reset_state() -> void:
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

func advance_time(delta: float) -> void:
	if is_paused:
		return
	elapsed_time_sec += delta * sim_speed
	tick_count += 1

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
