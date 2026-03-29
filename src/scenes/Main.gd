## Main.gd
## Escena raíz del juego. Orquesta la carga inicial y el bucle de simulación.
## Responsabilidades:
##   - Cargar science-params.json en GameState
##   - Inicializar moléculas desde init_counts
##   - Correr el tick loop
##   - Mostrar panel de telemetría y panel de controles del jugador

extends Node2D

const SCIENCE_PARAMS_PATH := "res://src/data/science-params.json"
const TICK_INTERVAL := 0.1  ## 10 ticks por segundo

var _tick_accumulator: float = 0.0
var _debug_label:  Label
var _event_label:  Label

## Referencias a sliders para sincronizar display
var _slider_temp: HSlider
var _slider_ph:   HSlider
var _slider_hyd:  HSlider

# ──────────────────────────────────────────────
# CICLO DE VIDA
# ──────────────────────────────────────────────

func _ready() -> void:
	_load_science_params()
	_init_molecules()
	_setup_ui()
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
	var err   := json.parse(raw)
	if err != OK:
		push_error("[Main] JSON parse error en línea %d: %s" % [json.get_error_line(), json.get_error_message()])
		return

	GameState.science_params = json.get_data()
	MoleculeSystem._load_config()
	ReactionSystem._load_config()
	EnvironmentSystem._load_config()
	CompartmentSystem._load_config()
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
	EnvironmentSystem.reset_system()
	CompartmentSystem.reset_system()
	_load_science_params()
	_init_molecules()
	_sync_sliders()
	print("[Main] Simulación reiniciada.")

# ──────────────────────────────────────────────
# TICK
# ──────────────────────────────────────────────

func _run_tick(delta: float) -> void:
	ReactionSystem.reset_tick()
	GameState.advance_time(delta)
	MoleculeSystem.tick(delta)
	EnvironmentSystem.tick()
	CompartmentSystem.tick()
	_update_debug_panel()

# ──────────────────────────────────────────────
# UI
# ──────────────────────────────────────────────

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UICanvas"
	add_child(canvas)

	_setup_telemetry_panel(canvas)
	_setup_controls_panel(canvas)

func _setup_telemetry_panel(canvas: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(10.0, 10.0)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 13)
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	vbox.add_child(_debug_label)

	_event_label = Label.new()
	_event_label.add_theme_font_size_override("font_size", 13)
	_event_label.modulate = Color(1.0, 0.85, 0.2)
	vbox.add_child(_event_label)

func _setup_controls_panel(canvas: CanvasLayer) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(10.0, 500.0)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "── CONTROLES DEL ENTORNO ──"
	title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(title)

	_slider_temp = _make_slider(vbox, "Temperatura (°C)", 0.0, 100.0, GameState.temperature_c, _on_temp_changed)
	_slider_ph   = _make_slider(vbox, "pH",               0.0,  14.0, GameState.ph,            _on_ph_changed)
	_slider_hyd  = _make_slider(vbox, "Hidratación",      0.0,   1.0, GameState.hydration,     _on_hyd_changed)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)

	var btn_uv := Button.new()
	btn_uv.text = "⚡ UV Flash"
	btn_uv.pressed.connect(_on_uv_pressed)
	hbox.add_child(btn_uv)

	var btn_vent := Button.new()
	btn_vent.text = "🌋 Fumarola"
	btn_vent.pressed.connect(_on_vent_pressed)
	hbox.add_child(btn_vent)

func _make_slider(parent: Control, label_text: String, min_v: float, max_v: float,
		initial: float, callback: Callable) -> HSlider:
	var vbox := VBoxContainer.new()
	parent.add_child(vbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value    = min_v
	slider.max_value    = max_v
	slider.value        = initial
	slider.step         = 0.1
	slider.custom_minimum_size = Vector2(220.0, 20.0)
	slider.value_changed.connect(callback)
	vbox.add_child(slider)

	return slider

func _sync_sliders() -> void:
	if _slider_temp: _slider_temp.value = GameState.temperature_c
	if _slider_ph:   _slider_ph.value   = GameState.ph
	if _slider_hyd:  _slider_hyd.value  = GameState.hydration

# ──────────────────────────────────────────────
# CALLBACKS DE CONTROLES
# ──────────────────────────────────────────────

func _on_temp_changed(value: float) -> void:
	EnvironmentSystem.set_temperature(value)

func _on_ph_changed(value: float) -> void:
	EnvironmentSystem.set_ph(value)

func _on_hyd_changed(value: float) -> void:
	EnvironmentSystem.set_hydration(value)

func _on_uv_pressed() -> void:
	EnvironmentSystem.trigger_uv_flash()

func _on_vent_pressed() -> void:
	EnvironmentSystem.trigger_vent()

# ──────────────────────────────────────────────
# TELEMETRÍA
# ──────────────────────────────────────────────

func _update_debug_panel() -> void:
	var snap     := MoleculeSystem.get_system_snapshot()
	var lines: PackedStringArray = []

	lines.append("PRIMORDIAL  tick %d  (SPACE=pausa  R=reiniciar)" % GameState.tick_count)
	lines.append("─────────────────────────────────────────────")
	lines.append("Entorno   Temp %.1f°C  |  pH %.1f  |  Humedad %.0f%%" % [
		GameState.temperature_c, GameState.ph, GameState.hydration * 100.0
	])
	lines.append("          Energía %.2f  |  Cat. mineral %.2f" % [
		GameState.energy_flux, GameState.mineral_catalysis
	])
	lines.append("─────────────────────────────────────────────")
	lines.append("Moléculas activas: %d" % snap.total_molecules)
	for t in snap.by_type:
		lines.append("  %-12s %d" % [t, snap.by_type[t]])
	lines.append("─────────────────────────────────────────────")
	var comp_sum := CompartmentSystem.get_summary()
	lines.append("Compartimentos: micelas %d  vesículas %d  protocélulas %d" % [
		comp_sum.micelles, comp_sum.vesicles, comp_sum.protocells
	])
	lines.append("─────────────────────────────────────────────")
	lines.append("Reacciones : %d  |  Degradadas: %d" % [
		GameState.telemetry.total_reactions,
		GameState.telemetry.degraded_molecules
	])
	_debug_label.text = "\n".join(lines)

	## Indicadores de eventos activos
	var events: PackedStringArray = []
	if GameState.uv_active:
		events.append("⚡ UV (%d ticks)" % EnvironmentSystem.uv_ticks_left())
	if EnvironmentSystem.is_vent_active():
		events.append("🌋 FUMAROLA (%d ticks)" % EnvironmentSystem.vent_ticks_left())
	_event_label.text = "  ".join(events)
