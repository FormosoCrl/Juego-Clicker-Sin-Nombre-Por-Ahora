extends Control

# ─── NODOS ────────────────────────────────────────────────────────────────────

@onready var username_label: Label = $VBox/Header/HeaderInfo/UsernameLabel
@onready var uid_label: Label = $VBox/Header/HeaderInfo/UidLabel
@onready var logout_button: Button = $VBox/Header/LogoutButton
@onready var roster_count_label: Label = $VBox/RosterCountLabel
@onready var character_list: VBoxContainer = $VBox/ScrollContainer/CharacterList
@onready var detail_panel: Panel = $DetailPanel
@onready var detail_name: Label = $DetailPanel/VBox/NameLabel
@onready var detail_rarity: Label = $DetailPanel/VBox/RarityLabel
@onready var detail_class: Label = $DetailPanel/VBox/ClassLabel
@onready var detail_level: Label = $DetailPanel/VBox/LevelLabel
@onready var detail_stats: Label = $DetailPanel/VBox/StatsLabel
@onready var detail_skills: Label = $DetailPanel/VBox/SkillsLabel
@onready var detail_close: Button = $DetailPanel/VBox/CloseButton

# ─── COLORES POR RAREZA ────────────────────────────────────────────────────────

const RARITY_COLORS: Dictionary = {
	"comun":      Color(0.7, 0.7, 0.7),
	"especial":   Color(0.4, 0.8, 0.4),
	"raro":       Color(0.3, 0.6, 1.0),
	"epico":      Color(0.7, 0.3, 1.0),
	"legendario": Color(1.0, 0.7, 0.1),
	"mitico":     Color(1.0, 0.3, 0.3),
	"milagro":    Color(1.0, 0.9, 0.4),
}

# ─── READY ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	logout_button.pressed.connect(_on_logout)
	detail_close.pressed.connect(func(): detail_panel.hide())
	detail_panel.hide()
	GameState.roster_changed.connect(_populate)
	_populate()

func _on_visibility_changed() -> void:
	if not is_node_ready():
		return
	if visible:
		_populate()

# ─── POPULATE ─────────────────────────────────────────────────────────────────

func _populate() -> void:
	var email: String = Firebase.current_email
	username_label.text = email if email != "" else "Jugador"
	uid_label.text = "UID: " + GameState.uid

	for child in character_list.get_children():
		child.queue_free()

	var roster: Array = GameState.roster
	roster_count_label.text = "Personajes: %d" % roster.size()

	for character in roster:
		character_list.add_child(_make_character_row(character))

func _make_character_row(character: Character) -> Control:
	var row := PanelContainer.new()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	# Franja de color por rareza
	var color_bar := ColorRect.new()
	color_bar.custom_minimum_size = Vector2(6, 0)
	color_bar.color = RARITY_COLORS.get(character.rarity, Color.WHITE)
	color_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(color_bar)

	# Info principal
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_row := HBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = character.name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_row.add_child(name_lbl)

	if character.is_dead:
		var dead_lbl := Label.new()
		dead_lbl.text = " [MUERTO]"
		dead_lbl.modulate = Color(1, 0.2, 0.2)
		dead_lbl.add_theme_font_size_override("font_size", 12)
		name_row.add_child(dead_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "%s · %s · Nv.%d" % [
		character.rarity.to_upper(),
		character.char_class.capitalize(),
		character.level
	]
	sub_lbl.modulate.a = 0.7
	sub_lbl.add_theme_font_size_override("font_size", 11)

	info.add_child(name_row)
	info.add_child(sub_lbl)
	hbox.add_child(info)

	# Botón detalle
	var btn := Button.new()
	btn.text = "Ver"
	var cid: String = character.id
	btn.pressed.connect(func(): _show_detail(cid))
	hbox.add_child(btn)

	row.add_child(hbox)
	return row

# ─── DETALLE ──────────────────────────────────────────────────────────────────

func _show_detail(character_id: String) -> void:
	var character: Character = GameState.get_character_by_id(character_id)
	if character == null:
		return

	var rarity_color: Color = RARITY_COLORS.get(character.rarity, Color.WHITE)
	detail_name.text = character.name
	detail_name.modulate = rarity_color
	detail_rarity.text = "Rareza: %s" % character.rarity.to_upper()
	detail_class.text = "Clase: %s" % character.char_class.capitalize()
	detail_level.text = "Nivel %d  ·  XP: %d / %d" % [
		character.level,
		character.xp,
		GameData.get_xp_for_level(character.level)
	]
	detail_stats.text = "❤ Vida: %d   ⚔ Fuerza: %d   ✦ Mana: %d   ★ Suerte: %d" % [
		character.vida_base,
		character.fuerza_base,
		character.mana_base,
		character.suerte_base,
	]
	var skills_text: String = "Habilidades:\n"
	skills_text += "  · %s\n" % (character.skill_1_id if character.skill_1_id != "" else "—")
	skills_text += "  · %s\n" % (character.skill_2_id if character.skill_2_id != "" else "Disponible a nivel 25")
	skills_text += "  · Pasiva: %s" % (character.passive_id if character.passive_id != "" else "Disponible a nivel 60")
	detail_skills.text = skills_text

	detail_panel.show()

# ─── LOGOUT ───────────────────────────────────────────────────────────────────

func _on_logout() -> void:
	Firebase.clear_session()
	get_tree().change_scene_to_file("res://scenes/Login.tscn")
