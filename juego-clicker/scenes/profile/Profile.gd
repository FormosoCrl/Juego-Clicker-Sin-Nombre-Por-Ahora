extends Control

# ─── NODOS ────────────────────────────────────────────────────────────────────

@onready var username_label: Label    = $Root/HeaderBar/HeaderInner/UserInfo/UsernameLabel
@onready var uid_label: Label         = $Root/HeaderBar/HeaderInner/UserInfo/UidLabel
@onready var logout_button: Button    = $Root/HeaderBar/HeaderInner/LogoutButton
@onready var roster_stat: Label       = $Root/StatsBar/RosterStat
@onready var character_list: VBoxContainer = $Root/ScrollContainer/CharacterList

@onready var detail_panel: Panel      = $DetailPanel
@onready var color_header: ColorRect  = $DetailPanel/PanelVBox/ColorHeader
@onready var detail_name: Label       = $DetailPanel/PanelVBox/ContentPad/ContentVBox/NameLabel
@onready var detail_sub: Label        = $DetailPanel/PanelVBox/ContentPad/ContentVBox/SubLabel
@onready var detail_level: Label      = $DetailPanel/PanelVBox/ContentPad/ContentVBox/LevelLabel
@onready var stat_vida: Label         = $DetailPanel/PanelVBox/ContentPad/ContentVBox/StatsGrid/VidaStat
@onready var stat_fuerza: Label       = $DetailPanel/PanelVBox/ContentPad/ContentVBox/StatsGrid/FuerzaStat
@onready var stat_mana: Label         = $DetailPanel/PanelVBox/ContentPad/ContentVBox/StatsGrid/ManaStat
@onready var stat_suerte: Label       = $DetailPanel/PanelVBox/ContentPad/ContentVBox/StatsGrid/SuerteStat
@onready var detail_skills: Label     = $DetailPanel/PanelVBox/ContentPad/ContentVBox/SkillsLabel
@onready var detail_close: Button     = $DetailPanel/PanelVBox/ContentPad/ContentVBox/CloseButton

# ─── RAREZA ───────────────────────────────────────────────────────────────────

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

# ─── CICLO DE VIDA ────────────────────────────────────────────────────────────

func _ready() -> void:
	logout_button.pressed.connect(_on_logout)
	detail_close.pressed.connect(func(): detail_panel.hide())
	detail_panel.hide()
	GameState.roster_changed.connect(_populate)
	_populate()

func _on_visibility_changed() -> void:
	if not is_node_ready() or not visible:
		return
	_populate()

# ─── POPULATE ─────────────────────────────────────────────────────────────────

func _populate() -> void:
	var email: String = Firebase.current_email
	username_label.text = email if email != "" else "Jugador"
	uid_label.text = GameState.uid

	for child in character_list.get_children():
		child.queue_free()

	var roster: Array = GameState.roster
	var alive: int = roster.filter(func(c): return not c.is_dead).size()
	roster_stat.text = "%d personajes  ·  %d activos" % [roster.size(), alive]

	for character in roster:
		character_list.add_child(_make_row(character))

# ─── FILA COMPACTA ────────────────────────────────────────────────────────────

func _make_row(character: Character) -> Control:
	var rarity_color: Color = RARITY_COLORS.get(character.rarity, Color.WHITE)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	# Barra lateral de rareza
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 36)
	bar.color = rarity_color
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(bar)

	# Padding izquierdo
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(8, 0)
	row.add_child(pad)

	# Nombre + subtítulo
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)

	var name_lbl := Label.new()
	name_lbl.text = character.name + (" ☠" if character.is_dead else "")
	name_lbl.add_theme_font_size_override("font_size", 13)
	if character.is_dead:
		name_lbl.modulate = Color(0.6, 0.3, 0.3)

	var sub_lbl := Label.new()
	sub_lbl.text = "%s · %s · Nv.%d" % [
		RARITY_LABELS.get(character.rarity, character.rarity),
		character.char_class.capitalize(),
		character.level
	]
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.modulate = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.75)

	vbox.add_child(name_lbl)
	vbox.add_child(sub_lbl)
	row.add_child(vbox)

	# Botón ver
	var btn := Button.new()
	btn.text = "▶"
	btn.flat = true
	btn.custom_minimum_size = Vector2(32, 0)
	btn.add_theme_font_size_override("font_size", 14)
	var cid: String = character.id
	btn.pressed.connect(func(): _show_detail(cid))
	row.add_child(btn)

	return row

# ─── PANEL DETALLE ────────────────────────────────────────────────────────────

func _show_detail(character_id: String) -> void:
	var c: Character = GameState.get_character_by_id(character_id)
	if c == null:
		return

	var rc: Color = RARITY_COLORS.get(c.rarity, Color.WHITE)
	color_header.color = rc

	detail_name.text = c.name
	detail_name.modulate = rc
	detail_sub.text = "%s  ·  %s%s" % [
		RARITY_LABELS.get(c.rarity, c.rarity),
		c.char_class.capitalize(),
		"  ·  ☠ Muerto" if c.is_dead else ""
	]

	var xp_needed: int = GameData.get_xp_for_level(c.level)
	detail_level.text = "Nivel %d  —  XP %d / %d" % [c.level, c.xp, xp_needed]

	stat_vida.text   = "❤ Vida: %d"   % c.vida_base
	stat_fuerza.text = "⚔ Fuerza: %d" % c.fuerza_base
	stat_mana.text   = "✦ Mana: %d"   % c.mana_base
	stat_suerte.text = "★ Suerte: %d" % c.suerte_base

	var sk1: String = c.skill_1_id if c.skill_1_id != "" else "—"
	var sk2: String = c.skill_2_id if c.skill_2_id != "" else "Nivel 25"
	var skp: String = c.passive_id  if c.passive_id  != "" else "Nivel 60"
	detail_skills.text = "● %s   ● %s\n● Pasiva: %s" % [sk1, sk2, skp]

	detail_panel.show()

# ─── LOGOUT ───────────────────────────────────────────────────────────────────

func _on_logout() -> void:
	Firebase.clear_session()
	get_tree().change_scene_to_file("res://scenes/Login.tscn")
