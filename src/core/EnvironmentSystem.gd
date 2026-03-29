## EnvironmentSystem.gd
## S2 — Gestión dinámica del entorno prebiótico
## Maneja eventos (UV, fumarolas), biomas y cambios de variables ambientales.
## El jugador interactúa con el entorno a través de este sistema.
## NO contiene lógica de render ni de UI.

extends Node

signal biome_changed(biome_name: String)
signal event_started(event_name: String)
signal event_ended(event_name: String)

var _config        := {}   ## Sección "ui" del JSON (parámetros de eventos)
var _vent_active:  bool = false
var _uv_ticks_remaining:   int = 0
var _vent_ticks_remaining: int = 0
var _vent_temp_boost: float = 0.0   ## Para revertir el boost al terminar

# ──────────────────────────────────────────────
# CICLO DE VIDA
# ──────────────────────────────────────────────

func _load_config() -> void:
	if GameState.science_params.is_empty():
		push_warning("[EnvironmentSystem] science_params vacío al cargar config")
		return
	_config = GameState.science_params.get("ui", {})
	print("[EnvironmentSystem] Config cargada")

func reset_system() -> void:
	_uv_ticks_remaining   = 0
	_vent_ticks_remaining = 0
	_vent_active          = false
	GameState.uv_active   = false
	if _vent_temp_boost > 0.0:
		GameState.temperature_c -= _vent_temp_boost
		GameState.temperature_c  = clamp(GameState.temperature_c, 0.0, 100.0)
	_vent_temp_boost = 0.0

# ──────────────────────────────────────────────
# TICK
# ──────────────────────────────────────────────

func tick() -> void:
	_tick_uv()
	_tick_vent()

func _tick_uv() -> void:
	if _uv_ticks_remaining <= 0:
		return
	_uv_ticks_remaining -= 1
	if _uv_ticks_remaining == 0:
		GameState.uv_active = false
		emit_signal("event_ended", "uv_flash")

func _tick_vent() -> void:
	if _vent_ticks_remaining <= 0:
		return
	_vent_ticks_remaining -= 1
	if _vent_ticks_remaining == 0:
		GameState.temperature_c -= _vent_temp_boost
		GameState.temperature_c  = clamp(GameState.temperature_c, 0.0, 100.0)
		_vent_temp_boost = 0.0
		_vent_active     = false
		emit_signal("event_ended", "hydrothermal_vent")

# ──────────────────────────────────────────────
# EVENTOS JUGABLES
# ──────────────────────────────────────────────

func trigger_uv_flash() -> void:
	var duration: int = _config.get("flash_duration_ticks", 25)
	_uv_ticks_remaining = duration
	GameState.uv_active = true
	emit_signal("event_started", "uv_flash")
	print("[EnvironmentSystem] UV flash activado (%d ticks)" % duration)

func trigger_vent() -> void:
	if _vent_active:
		return
	var duration: int   = _config.get("vent_duration_ticks", 240)
	_vent_temp_boost    = _config.get("vent_temp_boost", 12.0)
	_vent_ticks_remaining = duration
	_vent_active        = true

	GameState.temperature_c = clamp(GameState.temperature_c + _vent_temp_boost, 0.0, 100.0)

	var h2s_burst: int = _config.get("vent_h2s_burst", 4)
	var fe2_burst: int = _config.get("vent_fe2_burst", 2)
	MoleculeSystem.spawn_molecule("H2S", h2s_burst)
	MoleculeSystem.spawn_molecule("FE2", fe2_burst)

	emit_signal("event_started", "hydrothermal_vent")
	print("[EnvironmentSystem] Fumarola activada (%d ticks)" % duration)

# ──────────────────────────────────────────────
# CONTROLES DIRECTOS DEL ENTORNO
# ──────────────────────────────────────────────

func set_temperature(value: float) -> void:
	GameState.temperature_c = clamp(value, 0.0, 100.0)

func set_ph(value: float) -> void:
	GameState.ph = clamp(value, 0.0, 14.0)

func set_hydration(value: float) -> void:
	GameState.hydration = clamp(value, 0.0, 1.0)

# ──────────────────────────────────────────────
# ESTADO
# ──────────────────────────────────────────────

func is_vent_active() -> bool:
	return _vent_active

func uv_ticks_left() -> int:
	return _uv_ticks_remaining

func vent_ticks_left() -> int:
	return _vent_ticks_remaining
