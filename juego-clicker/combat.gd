extends Control

const EnemyData = preload("res://scripts/arena/EnemyData.gd")
const CombatManagerScript = preload("res://scripts/arena/CombatManager.gd")

# ─── NODOS ────────────────────────────────────────────────────────────────────

@onready var combat_manager: CombatManager = $CombatManager
@onready var combat_log: RichTextLabel = $CombatLog

# Slots del jugador — array de diccionarios con referencias a los nodos
var player_slots: Array = []
var enemy_slots: Array = []

# ─── CONFIGURACIÓN DEL COMBATE ────────────────────────────────────────────────

var chapter: int = 1
var level: int = 1

# ─── READY ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_slot_references()
	_connect_combat_manager()
	_start_combat()

func _build_slot_references() -> void:
	# Referencias a los slots del jugador
	for i in range(1, 6):
		var slot_path: String = "HBoxContainer/PlayerSide/PlayerSlot%d" % i
		if not has_node(slot_path):
			continue
		var slot_node = get_node(slot_path)
		player_slots.append({
			"root":         slot_node,
			"name_label":   slot_node.get_node("NameLabel"),
			"hp_bar":       slot_node.get_node("HPBar"),
			"skill1_btn":   slot_node.get_node("Skill1Button"),
			"skill2_btn":   slot_node.get_node("Skill2Button"),
			"combatant":    null,
		})

	# Referencias a los slots de enemigo
	for i in range(1, 4):
		var slot_path: String = "HBoxContainer/EnemySide/EnemySlot%d" % i
		if not has_node(slot_path):
			continue
		var slot_node = get_node(slot_path)
		enemy_slots.append({
			"root":       slot_node,
			"name_label": slot_node.get_node("NameLabel"),
			"hp_bar":     slot_node.get_node("HPBar"),
			"combatant":  null,
		})

func _connect_combat_manager() -> void:
	combat_manager.combat_started.connect(_on_combat_started)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.attack_happened.connect(_on_attack_happened)
	combat_manager.attack_missed_happened.connect(_on_attack_missed)
	combat_manager.character_died.connect(_on_character_died)
	combat_manager.skill_used.connect(_on_skill_used)
	combat_manager.xp_gained.connect(_on_xp_gained)

# ─── INICIO DE COMBATE ────────────────────────────────────────────────────────

func _start_combat() -> void:
	var enemies: Array = EnemyData.get_enemies(chapter, level)
	var is_boss: bool = EnemyData.is_boss_level(level)

	if enemies.is_empty():
		_log("[color=red]Error: no hay enemigos para cap %d nivel %d[/color]" % [chapter, level])
		return

	if GameState.team.is_empty():
		_log("[color=red]Error: el equipo está vacío[/color]")
		return

	combat_manager.setup(GameState.team, enemies, chapter, is_boss)
	_setup_player_slots()
	_setup_enemy_slots()
	combat_manager.start()

func _setup_player_slots() -> void:
	for i in range(player_slots.size()):
		var slot: Dictionary = player_slots[i]
		if i >= combat_manager.player_combatants.size():
			slot["root"].hide()
			continue

		var combatant: Combatant = combat_manager.player_combatants[i]
		slot["combatant"] = combatant
		slot["root"].show()

		# Nombre y rareza
		slot["name_label"].text = combatant.character.name

		# HP bar
		slot["hp_bar"].max_value = combatant.character.vida_max()
		slot["hp_bar"].value = combatant.character.vida_actual

		# Skill 1
		var skill_1_data: Dictionary = GameData.SKILLS.get(
				combatant.character.skill_1_id, {})
		slot["skill1_btn"].text = skill_1_data.get("name", "—")
		slot["skill1_btn"].disabled = not combatant.skill_1_ready
		slot["skill1_btn"].pressed.connect(
			func(): _on_skill_button_pressed(combatant, 1))

		# Skill 2
		if combatant.character.skill_2_id != "":
			var skill_2_data: Dictionary = GameData.SKILLS.get(
					combatant.character.skill_2_id, {})
			slot["skill2_btn"].text = skill_2_data.get("name", "—")
			slot["skill2_btn"].disabled = not combatant.skill_2_ready
			slot["skill2_btn"].pressed.connect(
				func(): _on_skill_button_pressed(combatant, 2))
		else:
			slot["skill2_btn"].hide()

		# Click en el slot para seleccionar el personaje
		slot["root"].gui_input.connect(
			func(event): _on_player_slot_clicked(event, combatant))

func _setup_enemy_slots() -> void:
	for i in range(enemy_slots.size()):
		var slot: Dictionary = enemy_slots[i]
		if i >= combat_manager.enemy_combatants.size():
			slot["root"].hide()
			continue

		var combatant: Combatant = combat_manager.enemy_combatants[i]
		slot["combatant"] = combatant
		slot["root"].show()

		slot["name_label"].text = combatant.character.name
		slot["hp_bar"].max_value = combatant.character.vida_max()
		slot["hp_bar"].value = combatant.character.vida_actual

		# Click en enemigo para asignar target manual
		slot["root"].gui_input.connect(
			func(event): _on_enemy_slot_clicked(event, combatant))

# ─── PROCESO (actualizar UI cada frame) ───────────────────────────────────────

func _process(_delta: float) -> void:
	_update_player_slots()
	_update_enemy_slots()

func _update_player_slots() -> void:
	for slot in player_slots:
		var combatant: Combatant = slot["combatant"]
		if combatant == null:
			continue
		slot["hp_bar"].value = combatant.character.vida_actual
		slot["skill1_btn"].disabled = not combatant.skill_1_ready
		if combatant.character.skill_2_id != "":
			slot["skill2_btn"].disabled = not combatant.skill_2_ready

func _update_enemy_slots() -> void:
	for slot in enemy_slots:
		var combatant: Combatant = slot["combatant"]
		if combatant == null:
			continue
		slot["hp_bar"].value = combatant.character.vida_actual

# ─── INPUT ────────────────────────────────────────────────────────────────────

func _on_player_slot_clicked(event: InputEvent, combatant: Combatant) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not combatant.character.is_alive():
		return
	combat_manager.select_player_combatant(combatant)
	_log("Seleccionado: [b]%s[/b] — ahora haz click en un enemigo" \
			% combatant.character.name)

func _on_enemy_slot_clicked(event: InputEvent, combatant: Combatant) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not combatant.character.is_alive():
		return
	combat_manager.set_manual_target(combatant)
	_log("Target asignado: [b]%s[/b]" % combatant.character.name)

func _on_skill_button_pressed(combatant: Combatant, slot: int) -> void:
	combat_manager.player_use_skill(combatant, slot)

# ─── SEÑALES DEL COMBAT MANAGER ───────────────────────────────────────────────

func _on_combat_started() -> void:
	_log("[color=green]¡Combate iniciado![/color]")

func _on_combat_ended(player_won: bool) -> void:
	if player_won:
		_log("[color=green][b]¡Victoria![/b][/color]")
	else:
		_log("[color=red][b]Derrota...[/b][/color]")
	# Volver al menú tras 2 segundos
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_attack_happened(attacker: Combatant, target: Combatant, damage: int) -> void:
	_log("[b]%s[/b] golpea a [b]%s[/b] por [color=red]%d[/color]" \
			% [attacker.character.name, target.character.name, damage])

func _on_attack_missed(attacker: Combatant) -> void:
	_log("[b]%s[/b] falla el ataque" % attacker.character.name)

func _on_character_died(character: Character, is_player_side: bool) -> void:
	if is_player_side:
		_log("[color=red][b]%s[/b] ha muerto para siempre[/color]" % character.name)
		# Ocultar slot del jugador
		for slot in player_slots:
			if slot["combatant"] != null and \
					slot["combatant"].character.id == character.id:
				slot["root"].modulate.a = 0.3
	else:
		_log("[color=yellow][b]%s[/b] ha sido derrotado[/color]" % character.name)
		for slot in enemy_slots:
			if slot["combatant"] != null and \
					slot["combatant"].character.id == character.id:
				slot["root"].modulate.a = 0.3

func _on_skill_used(caster: Combatant, skill_id: String, _targets: Array) -> void:
	var skill_name: String = GameData.SKILLS.get(skill_id, {}).get("name", skill_id)
	_log("[color=cyan][b]%s[/b] usa [b]%s[/b][/color]" \
			% [caster.character.name, skill_name])

func _on_xp_gained(character: Character, amount: int) -> void:
	_log("[color=green]+%d XP para [b]%s[/b][/color]" % [amount, character.name])

# ─── LOG ──────────────────────────────────────────────────────────────────────

func _log(text: String) -> void:
	combat_log.append_text(text + "\n")
	# Auto-scroll al final
	await get_tree().process_frame
	combat_log.scroll_to_line(combat_log.get_line_count() - 1)
