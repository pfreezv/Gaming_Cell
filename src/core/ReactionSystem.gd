## ReactionSystem.gd
## S1 — Motor de reacciones químicas prebióticas
## Escucha reaction_candidate_detected de MoleculeSystem,
## evalúa la tabla del JSON y ejecuta las reacciones que corresponden.
## NO contiene lógica de render ni de UI.

extends Node

signal reaction_fired(reaction_id: String, product: String, position: Vector2)

var rng := RandomNumberGenerator.new()
var _config    := {}   ## Sección "reactions" del JSON
var _index     := {}   ## "TYPE_A|TYPE_B" → [reaction_id, ...]
var _reactions_this_tick: int = 0

# ──────────────────────────────────────────────
# CICLO DE VIDA
# ──────────────────────────────────────────────

func _ready() -> void:
	rng.randomize()
	MoleculeSystem.reaction_candidate_detected.connect(_on_candidate)

func _load_config() -> void:
	if GameState.science_params.is_empty():
		push_warning("[ReactionSystem] science_params vacío al cargar config")
		return
	_config = GameState.science_params.get("reactions", {})
	_build_index()
	print("[ReactionSystem] Tabla cargada: %d reacciones" % _config.get("table", {}).size())

func _build_index() -> void:
	_index.clear()
	for rid in _config.get("table", {}).keys():
		var r: Dictionary = _config["table"][rid]
		var reactants: Array = r.get("reactants", [])
		if reactants.size() < 2:
			continue
		var key_ab := "%s|%s" % [reactants[0], reactants[1]]
		var key_ba := "%s|%s" % [reactants[1], reactants[0]]
		if not _index.has(key_ab): _index[key_ab] = []
		_index[key_ab].append(rid)
		if key_ab != key_ba:
			if not _index.has(key_ba): _index[key_ba] = []
			_index[key_ba].append(rid)

# ──────────────────────────────────────────────
# TICK
# ──────────────────────────────────────────────

func reset_tick() -> void:
	_reactions_this_tick = 0

# ──────────────────────────────────────────────
# EVALUACIÓN DE CANDIDATOS
# ──────────────────────────────────────────────

func _on_candidate(data: Dictionary) -> void:
	var max_per_tick: int = _config.get("max_reactions_per_tick", 3)
	if _reactions_this_tick >= max_per_tick:
		return

	var key := "%s|%s" % [data.a_type, data.b_type]
	var candidates: Array = _index.get(key, [])
	if candidates.is_empty():
		return

	var table: Dictionary = _config.get("table", {})
	for rid in candidates:
		var r: Dictionary = table.get(rid, {})
		if _try_reaction(r, rid, data):
			_reactions_this_tick += 1
			break

func _try_reaction(r: Dictionary, rid: String, data: Dictionary) -> bool:
	# Temperatura mínima
	if GameState.temperature_c < r.get("min_temp", 0.0):
		return false

	# Reacciones exclusivas de UV
	if r.get("uv_only", false) and not GameState.uv_active:
		return false

	# Probabilidad ajustada por temperatura y pH
	var base_chance: float = r.get("chance", 0.0)
	var temp_boost:  float = GameState.temperature_c / _config.get("temp_boost_divisor", 120.0) * 0.01

	var ph_mult: float
	if GameState.ph >= _config.get("ph_boost_threshold_high", 6.0):
		ph_mult = _config.get("ph_boost_high", 1.2)
	elif GameState.ph >= _config.get("ph_boost_threshold_mid", 5.0):
		ph_mult = _config.get("ph_boost_mid", 0.9)
	else:
		ph_mult = _config.get("ph_boost_low", 0.6)

	var uv_mult  := 1.0 + (_config.get("uv_boost", 0.8) if GameState.uv_active else 0.0)

	# Posición calculada antes del roll para aplicar boost de compartimento
	var pos       := _midpoint_of(data.a_uid, data.b_uid)
	var comp_boost := CompartmentSystem.get_boost_at(pos)
	var final_chance: float = (base_chance + temp_boost) * ph_mult * uv_mult * comp_boost

	if rng.randf() > final_chance:
		return false

	# Producto
	var product: String = r.get("product", "")
	if product.is_empty():
		return false

	var inherited := (_energy_of(data.a_uid) + _energy_of(data.b_uid)) * 0.5

	MoleculeSystem.consume_pair(data.a_uid, data.b_uid)
	MoleculeSystem.spawn_reaction_result(product, pos, inherited)
	GameState.register_molecule(product, 1, inherited)

	emit_signal("reaction_fired", rid, product, pos)
	return true

# ──────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────

func _midpoint_of(uid_a: int, uid_b: int) -> Vector2:
	var ma := _find(uid_a)
	var mb := _find(uid_b)
	if not ma.is_empty() and not mb.is_empty():
		return Vector2((ma.x + mb.x) * 0.5, (ma.y + mb.y) * 0.5)
	if not ma.is_empty(): return Vector2(ma.x, ma.y)
	if not mb.is_empty(): return Vector2(mb.x, mb.y)
	return Vector2(960.0, 540.0)

func _energy_of(uid: int) -> float:
	var m := _find(uid)
	return m.get("energy", 0.1) if not m.is_empty() else 0.1

func _find(uid: int) -> Dictionary:
	for m in MoleculeSystem.molecules:
		if m.uid == uid:
			return m
	return {}
