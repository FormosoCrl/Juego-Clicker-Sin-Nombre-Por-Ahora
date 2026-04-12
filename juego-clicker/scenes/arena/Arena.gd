extends Control

# ─── NODOS EXISTENTES ─────────────────────────────────────────────────────────

@onready var energy_label: Label = $VBoxContainer/EnergyLabel
@onready var chapter_label: Label = $VBoxContainer/ChapterLabel
@onready var level1_button: Button = $VBoxContainer/HBoxContainer/Level1Button
@onready var level2_button: Button = $VBoxContainer/HBoxContainer/Level2Button
@onready var boss_button: Button = $VBoxContainer/HBoxContainer/BossButton
@onready var team_label: Label = $VBoxContainer/TeamLabel
@onready var team_container: HBoxContainer = $VBoxContainer/TeamContainer
@onready var start_button: Button = $VBoxContainer/StartButton

# ─── NODOS DEL POPUP ──────────────────────────────────────────────────────────

@onready var popup: PopupPanel = $CharacterSelectPopup
@onready var close_button: Button = $CharacterSelectPopup/PopupVBox/PopupHeader/CloseButton
@onready var search_input: LineEdit = $CharacterSelectPopup/PopupVBox/SearchInput
@onready var character_list: ItemList = $CharacterSelectPopup/PopupVBox/CharacterList

@onready var filter_all: Button        = $CharacterSelectPopup/PopupVBox/RarityFilter/FilterAll
@onready var filter_comun: Button      = $CharacterSelectPopup/PopupVBox/RarityFilter/FilterComun
@onready var filter_especial: Button   = $CharacterSelectPopup/PopupVBox/RarityFilter/FilterEspecial
@onready var filter_raro: Button       = $CharacterSelectPopup/PopupVBox/RarityFilter/FilterRaro
@onready var filter_epico: Button      = $CharacterSelectPopup/PopupVBox/RarityFilter/FilterEpico
@onready var filter_mitico: Button     = $CharacterSelectPopup/PopupVBox/RarityFilter/FilterMitico
@onready var filter_legendario: Button = $CharacterSelectPopup/PopupVBox/RarityFilter/FilterLegendario
@onready var filter_milagro: Button    = $CharacterSelectPopup/PopupVBox/RarityFilter/FilterMilagro

# ─── ESTADO ───────────────────────────────────────────────────────────────────

var selected_level: int = 1
var team_slots: Array = []
var _active_slot_index: int = -1
var _active_rarity_filter: String = ""

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
		slot.pressed.connect(func(): _open_popup(idx))

func _connect_signals() -> void:
	level1_button.pressed.connect(func(): _select_level(1))
	level2_button.pressed.connect(func(): _select_level(2))
	boss_button.pressed.connect(func(): _select_level(3))
	start_button.pressed.connect(_on_start_pressed)
	close_button.pressed.connect(_close_popup)
	search_input.text_changed.connect(_on_search_changed)
	character_list.item_selected.connect(_on_character_selected)

	filter_all.pressed.connect(func(): _set_rarity_filter(""))
	filter_comun.pressed.connect(func(): _set_rarity_filter("comun"))
	filter_especial.pressed.connect(func(): _set_rarity_filter("especial"))
	filter_raro.pressed.connect(func(): _set_rarity_filter("raro"))
	filter_epico.pressed.connect(func(): _set_rarity_filter("epico"))
	filter_mitico.pressed.connect(func(): _set_rarity_filter("mitico"))
	filter_legendario.pressed.connect(func(): _set_rarity_filter("legendario"))
	filter_milagro.pressed.connect(func(): _set_rarity_filter("milagro"))

	GameState.energy_changed.connect(_on_energy_changed)
	GameState.roster_changed.connect(_update_team_display)
	GameState.team_changed.connect(_update_team_display)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_node_ready():
		_update_ui()

# ─── ACTUALIZACIÓN UI PRINCIPAL ───────────────────────────────────────────────

func _update_ui() -> void:
	_update_energy_label()
	_update_chapter_label()
	_update_level_buttons()
	_update_team_display()
	_update_start_button()

func _update_energy_label() -> void:
	energy_label.text = "Energía: %d/%d" % [GameState.energy, GameState.energy_max]

func _update_chapter_label() -> void:
	chapter_label.text = "Capítulo %d" % GameState.current_chapter

func _update_level_buttons() -> void:
	level1_button.disabled = not GameState.can_play_level(GameState.current_chapter, true)
	level2_button.disabled = not GameState.can_play_level(GameState.current_chapter, true)
	boss_button.disabled   = not GameState.can_play_level(GameState.current_chapter, true)

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

func _update_start_button() -> void:
	var can_start: bool = not GameState.team.is_empty() and \
		GameState.can_play_level(GameState.current_chapter, selected_level != 3)
	start_button.disabled = not can_start

# ─── POPUP ────────────────────────────────────────────────────────────────────

func _open_popup(slot_index: int) -> void:
	_active_slot_index = slot_index
	# Si el slot tiene personaje, quitarlo al abrir
	if slot_index < GameState.team.size():
		GameState.remove_from_team(GameState.team[slot_index].id)
	search_input.text = ""
	_active_rarity_filter = ""
	_update_filter_buttons()
	_populate_character_list()
	popup.popup_centered()

func _close_popup() -> void:
	popup.hide()
	_active_slot_index = -1

func _set_rarity_filter(rarity: String) -> void:
	_active_rarity_filter = rarity
	_update_filter_buttons()
	_populate_character_list()

func _update_filter_buttons() -> void:
	filter_all.modulate        = Color(0.4, 0.8, 1) if _active_rarity_filter == "" else Color(1, 1, 1)
	filter_comun.modulate      = Color(0.4, 0.8, 1) if _active_rarity_filter == "comun" else Color(1, 1, 1)
	filter_especial.modulate   = Color(0.4, 0.8, 1) if _active_rarity_filter == "especial" else Color(1, 1, 1)
	filter_raro.modulate       = Color(0.4, 0.8, 1) if _active_rarity_filter == "raro" else Color(1, 1, 1)
	filter_epico.modulate      = Color(0.4, 0.8, 1) if _active_rarity_filter == "epico" else Color(1, 1, 1)
	filter_mitico.modulate     = Color(0.4, 0.8, 1) if _active_rarity_filter == "mitico" else Color(1, 1, 1)
	filter_legendario.modulate = Color(0.4, 0.8, 1) if _active_rarity_filter == "legendario" else Color(1, 1, 1)
	filter_milagro.modulate    = Color(0.4, 0.8, 1) if _active_rarity_filter == "milagro" else Color(1, 1, 1)

func _populate_character_list() -> void:
	character_list.clear()
	var search: String = search_input.text.strip_edges().to_lower()

	for character in GameState.roster:
		if character.is_dead:
			continue

		# Excluir los que ya están en el equipo
		var in_team: bool = false
		for member in GameState.team:
			if member.id == character.id:
				in_team = true
				break
		if in_team:
			continue

		# Filtro de rareza
		if _active_rarity_filter != "" and character.rarity != _active_rarity_filter:
			continue

		# Filtro de búsqueda
		if search != "" and not character.name.to_lower().contains(search):
			continue

		var text: String = "%s  [%s] %s — Vida:%d Fuerza:%d Mana:%d Suerte:%d" % [
			character.name,
			character.rarity.to_upper(),
			character.char_class.capitalize(),
			character.vida_base,
			character.fuerza_base,
			character.mana_base,
			character.suerte_base,
		]
		character_list.add_item(text)
		character_list.set_item_metadata(character_list.item_count - 1, character.id)
		character_list.set_item_custom_fg_color(
			character_list.item_count - 1,
			_rarity_color(character.rarity)
		)

func _on_search_changed(_text: String) -> void:
	_populate_character_list()

func _on_character_selected(index: int) -> void:
	var character_id: String = character_list.get_item_metadata(index)
	GameState.add_to_team(character_id)
	_close_popup()
	_update_team_display()

# ─── NIVEL Y COMBATE ──────────────────────────────────────────────────────────

func _select_level(level: int) -> void:
	selected_level = level
	_update_level_buttons()
	_update_start_button()

func _on_start_pressed() -> void:
	if GameState.team.is_empty():
		return
	var is_new: bool = selected_level != 3
	if not GameState.start_level(GameState.current_chapter, is_new):
		return
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
