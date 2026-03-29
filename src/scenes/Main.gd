## Main.gd
## Escena raíz del juego. Orquesta la carga inicial y el bucle de simulación.
## Responsabilidades:
##   - Cargar science-params.json en GameState
##   - Inicializar moléculas desde init_counts
##   - Correr el tick loop
##   - Mostrar panel de telemetría en pantalla

extends Node2D

const SCIENCE_PARAMS_PATH := "res://src/data/science-params.json"
const TICK_INTERVAL := 0.1  ## 10 ticks por segundo

var _tick_accumulator: float = 0.0
var _debug_label: Label

# ──────────────────────────────────────────────
# CICLO DE VIDA
# ──────────────────────────────────────────────

func _ready() -> void:
	_load_science_params()
	_init_molecules()
	_setup_debug_ui()
	print("[Main] Bucle iniciado. SPACE = pausa.")

func _process(delta: float) -> void:
	if GameState.is_paused:
		return

	_tick_accumulator += delta
	while _tick_accumulator >= TICK_INTERVAL:
		_tick_accumulator -= TICK_INTERVAL
		_run_tick(TICK_INTERVAL)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				GameState.is_paused = !GameState.is_paused
				print("[Main] Simulación %s" % ("pausada" if GameState.is_paused else "reanudada"))
			KEY_R:
				_restart()

# ──────────────────────────────────────────────
# INICIALIZACIÓN
# ──────────────────────────────────────────────

func _load_science_params() -> void:
	var file := FileAccess.open(SCIENCE_PARAMS_PATH, FileAccess.READ)
	if file == null:
		push_error("[Main] No se pudo abrir %s (error %d)" % [SCIENCE_PARAMS_PATH, FileAccess.get_open_error()])
		return

	var raw := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		push_error("[Main] JSON parse error en línea %d: %s" % [json.get_error_line(), json.get_error_message()])
		return

	GameState.science_params = json.get_data()
	MoleculeSystem._load_config()
	print("[Main] science-params.json cargado OK")

func _init_molecules() -> void:
	if GameState.science_params.is_empty():
		push_warning("[Main] science_params vacío — abortando init de moléculas")
		return

	var counts: Dictionary = GameState.science_params.get("init_counts", {})
	var area := Rect2(0.0, 0.0, 1920.0, 1080.0)

	for mol_type in counts:
		if mol_type.begins_with("_"):
			continue
		var amount: int = counts[mol_type]
		if amount > 0:
			MoleculeSystem.spawn_molecule(mol_type, amount, area)

	print("[Main] Moléculas iniciales: ", MoleculeSystem.count_by_type())

func _restart() -> void:
	GameState.reset_state()
	MoleculeSystem.reset_system()
	_load_science_params()
	_init_molecules()
	print("[Main] Simulación reiniciada.")

# ──────────────────────────────────────────────
# DEBUG UI
# ──────────────────────────────────────────────

func _setup_debug_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugCanvas"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(10.0, 10.0)
	canvas.add_child(panel)

	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 13)
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel.add_child(_debug_label)

func _run_tick(delta: float) -> void:
	GameState.advance_time(delta)
	MoleculeSystem.tick(delta)
	_update_debug_panel()

func _update_debug_panel() -> void:
	var snap := MoleculeSystem.get_system_snapshot()
	var lines: PackedStringArray = []

	lines.append("PRIMORDIAL  tick %d  (SPACE=pausa  R=reiniciar)" % GameState.tick_count)
	lines.append("─────────────────────────────────────────────")
	lines.append("Entorno   Temp %.1f°C  |  pH %.1f  |  Humedad %.0f%%" % [
		GameState.temperature_c,
		GameState.ph,
		GameState.hydration * 100.0
	])
	lines.append("          Energía %.2f  |  Cat. mineral %.2f" % [
		GameState.energy_flux,
		GameState.mineral_catalysis
	])
	lines.append("─────────────────────────────────────────────")
	lines.append("Moléculas activas: %d" % snap.total_molecules)

	var by_type: Dictionary = snap.by_type
	for t in by_type:
		lines.append("  %-12s %d" % [t, by_type[t]])

	lines.append("─────────────────────────────────────────────")
	lines.append("Reacciones totales : %d" % GameState.telemetry.total_reactions)
	lines.append("Moléculas degradadas: %d" % GameState.telemetry.degraded_molecules)

	_debug_label.text = "\n".join(lines)
