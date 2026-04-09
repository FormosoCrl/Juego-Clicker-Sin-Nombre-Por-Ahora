extends Control

# ─── NODOS ────────────────────────────────────────────────────────────────────

@onready var energy_label: Label = $VBoxContainer/EnergyLabel
@onready var chapter_label: Label = $VBoxContainer/ChapterLabel
@onready var level1_button: Button = $VBoxContainer/HBoxContainer/Level1Button
@onready var level2_button: Button = $VBoxContainer/HBoxContainer/Level2Button
@onready var boss_button: Button = $VBoxContainer/HBoxContainer/BossButton
@onready var team_label: Label = $VBoxContainer/TeamLabel
@onready var team_container: HBoxContainer = $VBoxContainer/TeamContainer
@onready var roster_list: ItemList = $VBoxContainer/RosterList
@onready var start_button: Button = $VBoxContainer/StartButton

# ─── ESTADO ───────────────────────────────────────────────────────────────────

var selected_level: int = 1
var team_slots: Array = []

# ─── READY ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_team_slots()
	_connect_signals()
	_update_ui()

func _build_team_slots() -> void:
	for i in range(1, 6):
		var slot: Button = team_container.get_node("TeamSlot%d" % i)
		team_slots.append(slot)
		var idx: int = i - 1
		slot.pressed.connect(func(): _on_team_slot_pressed(idx))

func _connect_signals() -> void:
	level1_button.pressed.connect(func(): _select_level(1))
	level2_button.pressed.connect(func(): _select_level(2))
	boss_button.pressed.connect(func(): _select_level(3))
	start_button.pressed.connect(_on_start_pressed)
	roster_list.item_activated.connect(_on_roster_item_activated)
	GameState.energy_changed.connect(_on_energy_changed)
	GameState.roster_changed.connect(_update_roster_list)
	GameState.team_changed.connect(_update_team_display)

# ─── VISIBILIDAD ──────────────────────────────────────────────────────────────

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_update_ui()

# ─── ACTUALIZACIÓN UI ─────────────────────────────────────────────────────────

func _update_ui() -> void:
	_update_energy_label()
	_update_chapter_label()
	_update_level_buttons()
	_update_team_display()
	_update_roster_list()
	_update_start_button()

func _update_energy_label() -> void:
	energy_label.text = "Energía: %d/%d" % [GameState.energy, GameState.energy_max]

func _update_chapter_label() -> void:
	chapter_label.text = "Capítulo %d" % GameState.current_chapter

func _update_level_buttons() -> void:
	var chapter: int = GameState.current_chapter

	level1_button.disabled = not GameState.can_play_level(chapter, true)
	level2_button.disabled = not GameState.can_play_level(chapter, true)
	boss_button.disabled = not GameState.can_play_level(chapter, true)

	level1_button.modulate = Color(0.4, 0.8, 1) if selected_level == 1 else Color(1, 1, 1)
	level2_button.modulate = Color(0.4, 0.8, 1) if selected_level == 2 else Color(1, 1, 1)
	boss_button.modulate   = Color(0.4, 0.8, 1) if selected_level == 3 else Color(1, 1, 1)

func _update_team_display() -> void:
	team_label.text = "Equipo (%d/5)" % GameState.team.size()
	for i in range(team_slots.size()):
		if i < GameState.team.size():
			var character: Character = GameState.team[i]
			team_slots[i].text = "%s\n[%s]" % [character.name, character.rarity.to_upper()]
			team_slots[i].modulate = _rarity_color(character.rarity)
		else:
			team_slots[i].text = "Vacío"
			team_slots[i].modulate = Color(1, 1, 1)
	_update_start_button()

func _update_roster_list() -> void:
	roster_list.clear()
	for character in GameState.roster:
		if character.is_dead:
			continue
		var in_team: bool = false
		for member in GameState.team:
			if member.id == character.id:
				in_team = true
				break
		var prefix: String = "[EN EQUIPO] " if in_team else ""
		var text: String = "%s%s — %s %s (Vida:%d Fuerza:%d)" % [
			prefix,
			character.name,
			character.rarity.to_upper(),
			character.char_class,
			character.vida_base,
			character.fuerza_base,
		]
		roster_list.add_item(text)
		roster_list.set_item_metadata(roster_list.item_count - 1, character.id)

func _update_start_button() -> void:
	var can_start: bool = not GameState.team.is_empty() and \
		GameState.can_play_level(GameState.current_chapter, selected_level != 3)
	start_button.disabled = not can_start

# ─── INTERACCIÓN ──────────────────────────────────────────────────────────────

func _select_level(level: int) -> void:
	selected_level = level
	_update_level_buttons()
	_update_start_button()

func _on_team_slot_pressed(idx: int) -> void:
	if idx < GameState.team.size():
		var character: Character = GameState.team[idx]
		GameState.remove_from_team(character.id)

func _on_roster_item_activated(index: int) -> void:
	var character_id: String = roster_list.get_item_metadata(index)
	# Si ya está en el equipo, quitarlo
	for member in GameState.team:
		if member.id == character_id:
			GameState.remove_from_team(character_id)
			return
	# Si no está, añadirlo
	GameState.add_to_team(character_id)

func _on_start_pressed() -> void:
	if GameState.team.is_empty():
		return
	var is_new: bool = selected_level != 3
	if not GameState.start_level(GameState.current_chapter, is_new):
		return
	# Pasar capítulo y nivel a la escena de combate
	var combat_scene = load("res://scenes/arena/combat.tscn").instantiate()
	combat_scene.chapter = GameState.current_chapter
	combat_scene.level = selected_level
	get_tree().root.add_child(combat_scene)
	get_tree().current_scene = combat_scene

# ─── SEÑALES DE GAMESTATE ─────────────────────────────────────────────────────

func _on_energy_changed(_current: int, _maximum: int) -> void:
	_update_energy_label()
	_update_level_buttons()
	_update_start_button()

# ─── HELPERS ──────────────────────────────────────────────────────────────────

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"comun":      return Color(0.8, 0.8, 0.8)
		"especial":   return Color(0.4, 0.6, 1.0)
		"raro":       return Color(0.2, 0.8, 0.4)
		"epico":      return Color(0.7, 0.3, 1.0)
		"mitico":     return Color(1.0, 0.6, 0.1)
		"legendario": return Color(1.0, 0.8, 0.1)
		"milagro":    return Color(1.0, 0.3, 0.5)
		_:            return Color(1, 1, 1)
