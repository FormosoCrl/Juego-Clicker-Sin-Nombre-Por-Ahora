extends Control

# ─── NODOS ────────────────────────────────────────────────────────────────────

@onready var username_label: Label         = $Root/HeaderBar/HeaderInner/UserInfo/UsernameLabel
@onready var uid_label: Label              = $Root/HeaderBar/HeaderInner/UserInfo/UidLabel
@onready var logout_button: Button         = $Root/HeaderBar/HeaderInner/LogoutButton
@onready var roster_stat: Label            = $Root/FilterBar/FilterPad/FilterInner/SearchRow/RosterStat
@onready var search_input: LineEdit        = $Root/FilterBar/FilterPad/FilterInner/SearchRow/SearchInput
@onready var rarity_row: HBoxContainer     = $Root/FilterBar/FilterPad/FilterInner/RarityRow
@onready var character_list: VBoxContainer = $Root/ScrollContainer/CharacterList

@onready var detail_panel: Panel           = $DetailPanel
@onready var color_header: ColorRect       = $DetailPanel/PanelVBox/ColorHeader
@onready var detail_name: Label            = $DetailPanel/PanelVBox/ContentPad/ContentVBox/NameLabel
@onready var detail_sub: Label             = $DetailPanel/PanelVBox/ContentPad/ContentVBox/SubLabel
@onready var detail_level: Label           = $DetailPanel/PanelVBox/ContentPad/ContentVBox/LevelLabel
@onready var stat_vida: Label              = $DetailPanel/PanelVBox/ContentPad/ContentVBox/StatsGrid/VidaStat
@onready var stat_fuerza: Label            = $DetailPanel/PanelVBox/ContentPad/ContentVBox/StatsGrid/FuerzaStat
@onready var stat_mana: Label              = $DetailPanel/PanelVBox/ContentPad/ContentVBox/StatsGrid/ManaStat
@onready var stat_suerte: Label            = $DetailPanel/PanelVBox/ContentPad/ContentVBox/StatsGrid/SuerteStat
@onready var detail_skills: Label          = $DetailPanel/PanelVBox/ContentPad/ContentVBox/SkillsLabel
@onready var delete_button: Button         = $DetailPanel/PanelVBox/ContentPad/ContentVBox/ButtonRow/DeleteButton
@onready var detail_close: Button          = $DetailPanel/PanelVBox/ContentPad/ContentVBox/ButtonRow/CloseButton

# ─── CONSTANTES ───────────────────────────────────────────────────────────────

const RARITY_COLORS: Dictionary = {
	"comun":      Color(0.65, 0.65, 0.65),
	"especial":   Color(0.35, 0.75, 0.35),
	"raro":       Color(0.25, 0.55, 1.0),
	"epico":      Color(0.65, 0.25, 1.0),
	"legendario": Color(1.0,  0.65, 0.05),
	"mitico":     Color(1.0,  0.25, 0.25),
	"milagro":    Color(1.0,  0.88, 0.35),
}

const RARITY_LABELS: Dictionary = {
	"comun": "Común", "especial": "Especial", "raro": "Raro",
	"epico": "Épico", "legendario": "Legendario", "mitico": "Mítico", "milagro": "Milagro",
}

const RARITY_KEYS: Array = ["", "comun", "especial", "raro", "epico", "legendario", "mitico", "milagro"]

# ─── ESTADO ───────────────────────────────────────────────────────────────────

var _rarity_filter: String = ""
var _current_detail_id: String = ""

# ─── CICLO DE VIDA ────────────────────────────────────────────────────────────

func _ready() -> void:
	logout_button.pressed.connect(_on_logout)
	detail_close.pressed.connect(func(): detail_panel.hide())
	delete_button.pressed.connect(_on_delete_pressed)
	detail_panel.hide()

	search_input.text_changed.connect(func(_t): _apply_filter())

	# Conectar botones de rareza (índice 0 = Todos, 1-7 = rarezas)
	for i in rarity_row.get_child_count():
		var btn: Button = rarity_row.get_child(i)
		var key: String = RARITY_KEYS[i]
		btn.pressed.connect(func(): _set_rarity_filter(key))

	GameState.roster_changed.connect(_apply_filter)
	_populate()

func _on_visibility_changed() -> void:
	if not is_node_ready() or not visible:
		return
	_populate()

# ─── POPULATE / FILTRO ────────────────────────────────────────────────────────

func _populate() -> void:
	username_label.text = Firebase.current_email if Firebase.current_email != "" else "Jugador"
	uid_label.text = GameState.uid
	_apply_filter()

func _set_rarity_filter(rarity: String) -> void:
	_rarity_filter = rarity
	# Actualizar estado visual de los botones
	for i in rarity_row.get_child_count():
		var btn: Button = rarity_row.get_child(i)
		btn.button_pressed = (RARITY_KEYS[i] == rarity)
	_apply_filter()

func _apply_filter() -> void:
	for child in character_list.get_children():
		child.queue_free()

	var search: String = search_input.text.strip_edges().to_lower()
	var roster: Array = GameState.roster

	var filtered: Array = roster.filter(func(c: Character) -> bool:
		if _rarity_filter != "" and c.rarity != _rarity_filter:
			return false
		if search != "" and not c.name.to_lower().contains(search):
			return false
		return true
	)

	var alive: int = roster.filter(func(c): return not c.is_dead).size()
	roster_stat.text = "%d / %d" % [filtered.size(), roster.size()]
	# Actualiza texto del stat si no hay filtro
	if _rarity_filter == "" and search == "":
		roster_stat.text = "%d · %d vivos" % [roster.size(), alive]

	for character in filtered:
		character_list.add_child(_make_row(character))

# ─── FILA COMPACTA ────────────────────────────────────────────────────────────

func _make_row(character: Character) -> Control:
	var rarity_color: Color = RARITY_COLORS.get(character.rarity, Color.WHITE)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 30)
	bar.color = rarity_color
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(7, 0)
	row.add_child(pad)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)

	var name_lbl := Label.new()
	name_lbl.text = character.name + (" ☠" if character.is_dead else "")
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.modulate = Color(0.55, 0.25, 0.25) if character.is_dead else Color.WHITE

	var sub_lbl := Label.new()
	sub_lbl.text = "%s · %s · Nv.%d" % [
		RARITY_LABELS.get(character.rarity, character.rarity),
		character.char_class.capitalize(),
		character.level
	]
	sub_lbl.add_theme_font_size_override("font_size", 9)
	sub_lbl.modulate = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.7)

	vbox.add_child(name_lbl)
	vbox.add_child(sub_lbl)
	row.add_child(vbox)

	var btn := Button.new()
	btn.text = "▶"
	btn.flat = true
	btn.custom_minimum_size = Vector2(28, 0)
	btn.add_theme_font_size_override("font_size", 13)
	var cid: String = character.id
	btn.pressed.connect(func(): _show_detail(cid))
	row.add_child(btn)

	return row

# ─── PANEL DETALLE ────────────────────────────────────────────────────────────

func _show_detail(character_id: String) -> void:
	var c: Character = GameState.get_character_by_id(character_id)
	if c == null:
		return

	_current_detail_id = character_id
	var rc: Color = RARITY_COLORS.get(c.rarity, Color.WHITE)
	color_header.color = rc

	detail_name.text = c.name
	detail_name.modulate = rc
	detail_sub.text = "%s  ·  %s%s" % [
		RARITY_LABELS.get(c.rarity, c.rarity),
		c.char_class.capitalize(),
		"  ·  ☠ Muerto" if c.is_dead else ""
	]

	detail_level.text = "Nivel %d  —  XP %d / %d" % [
		c.level, c.xp, GameData.get_xp_for_level(c.level)
	]

	stat_vida.text   = "❤ Vida: %d"   % c.vida_base
	stat_fuerza.text = "⚔ Fuerza: %d" % c.fuerza_base
	stat_mana.text   = "✦ Mana: %d"   % c.mana_base
	stat_suerte.text = "★ Suerte: %d" % c.suerte_base

	var sk1: String = c.skill_1_id if c.skill_1_id != "" else "—"
	var sk2: String = c.skill_2_id if c.skill_2_id != "" else "Nivel 25"
	var skp: String = c.passive_id  if c.passive_id  != "" else "Nivel 60"
	detail_skills.text = "● %s   ● %s\n● Pasiva: %s" % [sk1, sk2, skp]

	delete_button.visible = c.is_dead
	detail_panel.show()

func _on_delete_pressed() -> void:
	if _current_detail_id == "":
		return
	var c: Character = GameState.get_character_by_id(_current_detail_id)
	if c == null or not c.is_dead:
		return
	detail_panel.hide()
	GameState.remove_from_roster(_current_detail_id)
	_current_detail_id = ""

# ─── LOGOUT ───────────────────────────────────────────────────────────────────

func _on_logout() -> void:
	Firebase.clear_session()
	get_tree().change_scene_to_file("res://scenes/Login.tscn")
