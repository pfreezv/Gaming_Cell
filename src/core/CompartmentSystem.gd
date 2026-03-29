## CompartmentSystem.gd
## S3 — Compartimentalización: micelas, vesículas y protocélulas
## Detecta clusters de lípidos, forma compartimentos y gestiona
## el contenido interno con permeabilidad diferencial.
## Una vesícula con RNA dentro activa la condición de protocélula.

extends Node

signal compartment_formed(compartment: Dictionary)
signal protocell_emerged(compartment: Dictionary)

var rng := RandomNumberGenerator.new()
var _config       := {}
var _permeability := {}
var _tick_counter: int = 0
var _next_uid:     int = 1
var compartments:  Array = []

# ──────────────────────────────────────────────
# CICLO DE VIDA
# ──────────────────────────────────────────────

func _ready() -> void:
	rng.randomize()

func _load_config() -> void:
	if GameState.science_params.is_empty():
		push_warning("[CompartmentSystem] science_params vacío al cargar config")
		return
	_config       = GameState.science_params.get("vesicle", {})
	_permeability = _config.get("permeability", {})
	print("[CompartmentSystem] Config cargada")

func reset_system() -> void:
	compartments.clear()
	GameState.compartments.clear()
	_tick_counter = 0
	_next_uid     = 1

# ──────────────────────────────────────────────
# TICK
# ──────────────────────────────────────────────

func tick() -> void:
	_tick_counter += 1
	var detect_every: int = _config.get("detection_every_ticks", 30)
	if _tick_counter % detect_every == 0:
		_detect_new_compartment()
	_update_contents()
	_check_protocell_conditions()

# ──────────────────────────────────────────────
# DETECCIÓN DE CLUSTERS DE LÍPIDOS
# ──────────────────────────────────────────────

func _detect_new_compartment() -> void:
	var max_comp: int = _config.get("max_simultaneous", 5)
	if compartments.size() >= max_comp:
		return

	var micelle_r:   float = _config.get("micelle_detection_radius", 60.0)
	var micelle_min: int   = _config.get("micelle_min_lipids", 6)
	var vesicle_min: int   = _config.get("vesicle_min_lipids", 10)

	## Lípidos libres (no ligados a compartimento)
	var free_lipids: Array = []
	for m in MoleculeSystem.molecules:
		if m.type == "LIPID" and m.get("bound_to") == null:
			free_lipids.append(m)

	if free_lipids.size() < micelle_min:
		return

	## Primer cluster que supere el umbral mínimo
	var used := {}
	for i in range(free_lipids.size()):
		if used.has(i): continue
		var center = free_lipids[i]
		var cluster: Array = [center]
		used[i] = true

		for j in range(i + 1, free_lipids.size()):
			if used.has(j): continue
			var other = free_lipids[j]
			var dx := center.x - other.x
			var dy := center.y - other.y
			if dx * dx + dy * dy <= micelle_r * micelle_r:
				cluster.append(other)
				used[j] = true

		if cluster.size() < micelle_min:
			continue

		_form_compartment(cluster, vesicle_min)
		break  ## Una sola formación por ciclo de detección

func _form_compartment(cluster: Array, vesicle_min: int) -> void:
	var cx: float = 0.0
	var cy: float = 0.0
	for lm in cluster:
		cx += lm.x
		cy += lm.y
	cx /= cluster.size()
	cy /= cluster.size()

	var comp_type := "vesicle" if cluster.size() >= vesicle_min else "micelle"
	var comp := {
		"uid":         _next_uid,
		"type":        comp_type,
		"x":           cx,
		"y":           cy,
		"lipid_count": cluster.size(),
		"contents":    [],
		"age":         0
	}
	_next_uid += 1

	for lm in cluster:
		lm["bound_to"] = comp.uid

	compartments.append(comp)
	GameState.compartments.append(comp)
	GameState.telemetry["encapsulation_events"] += 1
	emit_signal("compartment_formed", comp)
	print("[CompartmentSystem] %s formada uid=%d lipids=%d pos=(%.0f,%.0f)" % [
		comp_type, comp.uid, cluster.size(), cx, cy
	])

# ──────────────────────────────────────────────
# CAPTURA DE MOLÉCULAS POR PERMEABILIDAD
# ──────────────────────────────────────────────

func _update_contents() -> void:
	var cap_radius: float = _config.get("vesicle_detection_radius", 80.0)
	var cap_radius_sq     := cap_radius * cap_radius

	for comp in compartments:
		comp.age += 1
		for m in MoleculeSystem.molecules:
			if m.get("bound_to") != null: continue
			if comp.contents.has(m.uid):  continue

			var dx := comp.x - m.x
			var dy := comp.y - m.y
			if dx * dx + dy * dy > cap_radius_sq: continue

			var perm: float = _permeability.get(m.type, 0.0)
			if perm > 0.0 and rng.randf() < perm:
				comp.contents.append(m.uid)
				m["bound_to"] = comp.uid

# ──────────────────────────────────────────────
# CONDICIÓN DE PROTOCÉLULA
# ──────────────────────────────────────────────

func _check_protocell_conditions() -> void:
	for comp in compartments:
		if comp.type == "protocell": continue
		if comp.type != "vesicle":   continue

		for uid in comp.contents:
			for m in MoleculeSystem.molecules:
				if m.uid == uid and m.type == "RNA":
					comp.type = "protocell"
					GameState.milestones["compartment_formed"] = true
					emit_signal("protocell_emerged", comp)
					print("[CompartmentSystem] ¡PROTOCELULA EMERGENTE! uid=%d" % comp.uid)
					break

# ──────────────────────────────────────────────
# API PARA OTROS SISTEMAS
# ──────────────────────────────────────────────

## Devuelve el multiplicador de reacción en una posición dada.
## Usado por ReactionSystem para boost interno de compartimentos.
func get_boost_at(pos: Vector2) -> float:
	var r: float = _config.get("vesicle_detection_radius", 80.0)
	var r_sq     := r * r
	for comp in compartments:
		var dx := comp.x - pos.x
		var dy := comp.y - pos.y
		if dx * dx + dy * dy <= r_sq:
			match comp.type:
				"protocell": return _config.get("reaction_boost_protocell", 10.0)
				"vesicle":   return _config.get("reaction_boost_vesicle",   3.0)
	return 1.0

func get_summary() -> Dictionary:
	var micelles   := 0
	var vesicles   := 0
	var protocells := 0
	for comp in compartments:
		match comp.type:
			"micelle":   micelles   += 1
			"vesicle":   vesicles   += 1
			"protocell": protocells += 1
	return {
		"total":     compartments.size(),
		"micelles":  micelles,
		"vesicles":  vesicles,
		"protocells": protocells
	}
