## MoleculeSystem.gd
## S1 — Motor molecular
## Gestiona la creación, movimiento y estado de todas las moléculas.
## NO contiene lógica de render. NO sabe que existe el canvas.
## Comunica cambios a otros sistemas o UI por señal / lectura de estado.

extends Node
class_name MoleculeSystem

signal molecule_spawned(molecule_id, position)
signal molecule_removed(molecule_id)
signal reaction_candidate_detected(data)

var rng := RandomNumberGenerator.new()

## Carga desde JSON o GameState
var config := {}

## Instancias activas
## Cada molécula individual puede representarse así:
## {
##   "uid": 123,
##   "type": "amino_gly",
##   "x": 120.0,
##   "y": 88.0,
##   "vx": 0.3,
##   "vy": -0.1,
##   "energy": 0.2,
##   "stability": 0.8,
##   "hydrated": true,
##   "age": 0.0,
##   "bound_to": null
## }
var molecules: Array = []
var next_uid: int = 1

## Área simulada
var world_size := Vector2(1920, 1080)

func _ready() -> void:
	rng.randomize()
	_load_config()

func _load_config() -> void:
	if GameState.science_params.is_empty():
		push_warning("Science params not loaded yet in GameState")
		return
	config = GameState.science_params

func reset_system() -> void:
	molecules.clear()
	next_uid = 1

func spawn_molecule(type: String, count: int = 1, area: Rect2 = Rect2(0,0,1920,1080)) -> void:
	for i in range(count):
		var m = _build_molecule(type, area)
		molecules.append(m)
		GameState.molecule_instances.append(m)
		emit_signal("molecule_spawned", type, Vector2(m.x, m.y))

func _build_molecule(type: String, area: Rect2) -> Dictionary:
	var defs = config.get("molecules", {})
	var def = defs.get(type, {})

	var molecule = {
		"uid": next_uid,
		"type": type,
		"x": rng.randf_range(area.position.x, area.position.x + area.size.x),
		"y": rng.randf_range(area.position.y, area.position.y + area.size.y),
		"vx": rng.randf_range(-1.0, 1.0),
		"vy": rng.randf_range(-1.0, 1.0),
		"energy": def.get("initial_energy", 0.1),
		"stability": def.get("stability", 0.5),
		"hydrated": true,
		"age": 0.0,
		"bound_to": null,
		"reactive": def.get("reactive", true),
		"tags": def.get("tags", [])
	}

	next_uid += 1
	return molecule

func tick(delta: float) -> void:
	_begin_tick_metrics()

	if molecules.is_empty():
		return

	_update_motion(delta)
	_apply_environmental_effects(delta)
	_detect_reaction_candidates()
	_cleanup_destroyed()

func _begin_tick_metrics() -> void:
	GameState.telemetry["reaction_candidates_last_tick"] = 0
	GameState.telemetry["reactions_success_last_tick"] = 0

func _update_motion(delta: float) -> void:
	var diffusion_base = config.get("environment", {}).get("diffusion_base", 12.0)
	var temp_factor = clamp(GameState.temperature_c / 40.0, 0.2, 3.0)
	var hydration_factor = clamp(GameState.hydration + 0.2, 0.05, 1.5)

	for m in molecules:
		var noise_x = rng.randf_range(-1.0, 1.0)
		var noise_y = rng.randf_range(-1.0, 1.0)
		m.vx += noise_x * diffusion_base * temp_factor * delta * 0.1
		m.vy += noise_y * diffusion_base * hydration_factor * delta * 0.1

		# drag suave para que no aceleren infinito
		m.vx *= 0.985
		m.vy *= 0.985

		m.x += m.vx
		m.y += m.vy
		m.age += delta

		_bounce_inside_world(m)

func _bounce_inside_world(m: Dictionary) -> void:
	if m.x < 0:
		m.x = 0
		m.vx *= -0.6
	elif m.x > world_size.x:
		m.x = world_size.x
		m.vx *= -0.6

	if m.y < 0:
		m.y = 0
		m.vy *= -0.6
	elif m.y > world_size.y:
		m.y = world_size.y
		m.vy *= -0.6

func _apply_environmental_effects(delta: float) -> void:
	var degradation_base = config.get("environment", {}).get("degradation_base", 0.002)
	var dry_penalty = max(0.0, 0.4 - GameState.hydration)
	var heat_penalty = max(0.0, GameState.temperature_c - 55.0) * 0.00015
	var energy_bonus = GameState.energy_flux * 0.0005

	for m in molecules:
		var degrade_chance = degradation_base + dry_penalty * 0.004 + heat_penalty
		if rng.randf() < degrade_chance:
			m.stability -= rng.randf_range(0.03, 0.08)
			GameState.telemetry["degraded_molecules"] += 1

		m.energy += energy_bonus * delta
		m.energy = clamp(m.energy, 0.0, 5.0)
		m.hydrated = GameState.hydration > 0.25

func _detect_reaction_candidates() -> void:
	var reaction_radius = config.get("environment", {}).get("reaction_radius", 14.0)
	var reaction_radius_sq = reaction_radius * reaction_radius
	var total = molecules.size()
	var candidates_detected := 0

	for i in range(total):
		var a = molecules[i]
		if not a.reactive:
			continue

		for j in range(i + 1, total):
			var b = molecules[j]
			if not b.reactive:
				continue

			var dx = a.x - b.x
			var dy = a.y - b.y
			var dist_sq = dx * dx + dy * dy

			if dist_sq <= reaction_radius_sq:
				candidates_detected += 1
				var candidate = {
					"a_uid": a.uid,
					"b_uid": b.uid,
					"a_type": a.type,
					"b_type": b.type,
					"distance_sq": dist_sq,
					"local_temp": GameState.temperature_c,
					"local_ph": GameState.ph,
					"energy_flux": GameState.energy_flux
				}
				emit_signal("reaction_candidate_detected", candidate)

	GameState.telemetry["reaction_candidates_last_tick"] = candidates_detected

func consume_pair(uid_a: int, uid_b: int) -> void:
	_mark_destroy(uid_a)
	_mark_destroy(uid_b)

func spawn_reaction_result(type: String, position: Vector2, inherited_energy: float = 0.2) -> void:
	var defs = config.get("molecules", {})
	var def = defs.get(type, {})
	var molecule = {
		"uid": next_uid,
		"type": type,
		"x": position.x,
		"y": position.y,
		"vx": rng.randf_range(-0.4, 0.4),
		"vy": rng.randf_range(-0.4, 0.4),
		"energy": max(inherited_energy, def.get("initial_energy", 0.1)),
		"stability": def.get("stability", 0.5),
		"hydrated": GameState.hydration > 0.25,
		"age": 0.0,
		"bound_to": null,
		"reactive": def.get("reactive", true),
		"tags": def.get("tags", []),
		"to_destroy": false
	}
	next_uid += 1
	molecules.append(molecule)
	GameState.molecule_instances.append(molecule)
	GameState.telemetry["total_reactions"] += 1
	GameState.telemetry["reactions_success_last_tick"] += 1
	emit_signal("molecule_spawned", type, position)

func _mark_destroy(uid: int) -> void:
	for m in molecules:
		if m.uid == uid:
			m["to_destroy"] = true
			return

func _cleanup_destroyed() -> void:
	if molecules.is_empty():
		return

	var survivors: Array = []
	for m in molecules:
		if m.get("to_destroy", false):
			emit_signal("molecule_removed", m.type)
		else:
			if m.stability > 0.0:
				survivors.append(m)
			else:
				GameState.telemetry["degraded_molecules"] += 1
				emit_signal("molecule_removed", m.type)

	molecules = survivors
	GameState.molecule_instances = survivors.duplicate(true)

func count_by_type() -> Dictionary:
	var summary := {}
	for m in molecules:
		summary[m.type] = summary.get(m.type, 0) + 1
	return summary

func get_system_snapshot() -> Dictionary:
	return {
		"total_molecules": molecules.size(),
		"by_type": count_by_type(),
		"tick": GameState.tick_count,
		"temperature": GameState.temperature_c,
		"hydration": GameState.hydration,
		"energy_flux": GameState.energy_flux
	}
