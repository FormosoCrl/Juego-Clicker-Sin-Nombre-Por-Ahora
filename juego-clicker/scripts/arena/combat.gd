extends Control

const EnemyData = preload("res://scripts/arena/EnemyData.gd")

@onready var combat_manager = $CombatManager
@onready var combat_log: RichTextLabel = $CombatLog

var player_slots: Array = []
var enemy_slots: Array = []

var chapter: int = 1
var level: int = 1

func _ready() -> void:
	chapter = GameState.pending_combat_chapter
	level = GameState.pending_combat_level
	_build_slot_references()
	_connect_combat_manager()
	_start_combat()

func _build_slot_references() -> void:
	for i in range(1, 6):
		var slot_path: String = "HBoxContainer/PlayerSide/PlayerSlot%d" % i
		if not has_node(slot_path):
			continue
		var slot_node = get_node(slot_path)
		player_slots.append({
			"root":       slot_node,
			"name_label": slot_node.get_node("NameLabel"),
			"hp_bar": slot_node.get_node("ProgressBar"),
			"skill1_btn": slot_node.get_node("Skill1Button"),
			"skill2_btn": slot_node.get_node("Skill2Button"),
			"combatant":  null,
		})
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

func _start_combat() -> void:
	var enemies: Array = EnemyData.get_enemies(chapter, level)
	var is_boss: bool = EnemyData.is_boss_level(level)
	if enemies.is_empty():
		_log("[color=red]Error: no hay enemigos[/color]")
		return
	if GameState.team.is_empty():
		_log("[color=red]Error: equipo vacío[/color]")
		return
	combat_manager.setup(GameState.team, enemies, chapter, is_boss)
	_setup_player_slots()
	_setup_enemy_slots()

	# DEBUG
	for c in combat_manager.player_combatants:
		print("PJ: ", c.character.name,
			" vida_base=", c.character.vida_base,
			" vida_actual=", c.character.vida_actual,
			" vida_max=", c.character.vida_max())

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
		slot["name_label"].text = combatant.character.name
		slot["hp_bar"].min_value = 0
		slot["hp_bar"].max_value = combatant.character.vida_max()
		slot["hp_bar"].value = combatant.character.vida_actual
		var skill_1_data: Dictionary = GameData.SKILLS.get(combatant.character.skill_1_id, {})
		slot["skill1_btn"].text = skill_1_data.get("name", "—")
		slot["skill1_btn"].disabled = not combatant.skill_1_ready
		slot["skill1_btn"].pressed.connect(func(): _on_skill_button_pressed(combatant, 1))
		if combatant.character.skill_2_id != "":
			var skill_2_data: Dictionary = GameData.SKILLS.get(combatant.character.skill_2_id, {})
			slot["skill2_btn"].text = skill_2_data.get("name", "—")
			slot["skill2_btn"].disabled = not combatant.skill_2_ready
			slot["skill2_btn"].pressed.connect(func(): _on_skill_button_pressed(combatant, 2))
		else:
			slot["skill2_btn"].hide()
		slot["root"].gui_input.connect(func(event): _on_player_slot_clicked(event, combatant))

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
		slot["hp_bar"].min_value = 0
		slot["hp_bar"].max_value = combatant.character.vida_max()
		slot["hp_bar"].value = combatant.character.vida_actual
		slot["root"].gui_input.connect(func(event): _on_enemy_slot_clicked(event, combatant))

func _process(_delta: float) -> void:
	_update_player_slots()
	_update_enemy_slots()

func _update_player_slots() -> void:
	for slot in player_slots:
		var combatant = slot["combatant"]
		if combatant == null or not is_instance_valid(combatant):
			continue
		slot["hp_bar"].max_value = combatant.character.vida_max()
		slot["hp_bar"].value = combatant.character.vida_actual
		slot["skill1_btn"].disabled = not combatant.skill_1_ready
		if combatant.character.skill_2_id != "":
			slot["skill2_btn"].disabled = not combatant.skill_2_ready

func _update_enemy_slots() -> void:
	for slot in enemy_slots:
		var combatant = slot["combatant"]
		if combatant == null or not is_instance_valid(combatant):
			continue
		slot["hp_bar"].max_value = combatant.character.vida_max()
		slot["hp_bar"].value = combatant.character.vida_actual

func _on_player_slot_clicked(event: InputEvent, combatant: Combatant) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not combatant.character.is_alive():
		return
	combat_manager.select_player_combatant(combatant)
	_log("Seleccionado: [b]%s[/b]" % combatant.character.name)

func _on_enemy_slot_clicked(event: InputEvent, combatant: Combatant) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not combatant.character.is_alive():
		return
	combat_manager.set_manual_target(combatant)
	_log("Target: [b]%s[/b]" % combatant.character.name)

func _on_skill_button_pressed(combatant: Combatant, slot: int) -> void:
	combat_manager.player_use_skill(combatant, slot)

func _on_combat_started() -> void:
	_log("[color=green]¡Combate iniciado![/color]")

func _on_combat_ended(player_won: bool) -> void:
	if player_won:
		_log("[color=green][b]¡Victoria![/b][/color]")
	else:
		_log("[color=red][b]Derrota...[/b][/color]")
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_attack_happened(attacker: Combatant, target: Combatant, damage: int) -> void:
	_log("[b]%s[/b] → [b]%s[/b] [color=red]-%d[/color]" \
		% [attacker.character.name, target.character.name, damage])

func _on_attack_missed(attacker: Combatant) -> void:
	_log("[b]%s[/b] falla" % attacker.character.name)

func _on_character_died(character: Character, is_player_side: bool) -> void:
	if is_player_side:
		_log("[color=red][b]%s[/b] ha muerto[/color]" % character.name)
		for slot in player_slots:
			if slot["combatant"] != null and \
					slot["combatant"].character.id == character.id:
				slot["root"].modulate.a = 0.3
	else:
		_log("[color=yellow][b]%s[/b] derrotado[/color]" % character.name)
		for slot in enemy_slots:
			if slot["combatant"] != null and \
					slot["combatant"].character.id == character.id:
				slot["root"].modulate.a = 0.3

func _on_skill_used(caster: Combatant, skill_id: String, _targets: Array) -> void:
	var skill_name: String = GameData.SKILLS.get(skill_id, {}).get("name", skill_id)
	_log("[color=cyan][b]%s[/b] usa %s[/color]" % [caster.character.name, skill_name])

func _on_xp_gained(character: Character, amount: int) -> void:
	_log("[color=green]+%d XP → [b]%s[/b][/color]" % [amount, character.name])

func _log(text: String) -> void:
	combat_log.append_text(text + "\n")
	await get_tree().process_frame
	combat_log.scroll_to_line(combat_log.get_line_count() - 1)
