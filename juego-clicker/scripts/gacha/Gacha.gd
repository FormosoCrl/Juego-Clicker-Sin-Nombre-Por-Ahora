extends Control

# ─── NODOS ────────────────────────────────────────────────────────────────────

@onready var orbs_label: Label          = $Root/TopBar/TopInner/OrbsBox/OrbsLabel
@onready var pity_label: Label          = $Root/TopBar/TopInner/PityBox/PityLabel
@onready var portal_glyph: Label        = $Root/PortalArea/PortalPanel/PortalVBox/PortalGlyph
@onready var pull_1_button: Button      = $Root/ButtonBar/Pull1Button
@onready var pull_10_button: Button     = $Root/ButtonBar/Pull10Button
@onready var results_overlay: Panel     = $ResultsOverlay
@onready var cards_container: HFlowContainer = $ResultsOverlay/OverlayVBox/CardsScroll/CardsContainer
@onready var dismiss_button: Button     = $ResultsOverlay/OverlayVBox/DismissButton

# ─── RAREZA ───────────────────────────────────────────────────────────────────

const RARITY_COLORS: Dictionary = {
	"comun":      Color(0.55, 0.55, 0.55),
	"especial":   Color(0.25, 0.65, 0.25),
	"raro":       Color(0.20, 0.45, 0.95),
	"epico":      Color(0.55, 0.15, 0.90),
	"legendario": Color(0.95, 0.55, 0.02),
	"mitico":     Color(0.95, 0.18, 0.18),
	"milagro":    Color(0.95, 0.80, 0.20),
}

const RARITY_LABELS: Dictionary = {
	"comun": "Común", "especial": "Especial", "raro": "Raro",
	"epico": "Épico", "legendario": "Legendario", "mitico": "Mítico", "milagro": "Milagro",
}

const RARITY_GLYPHS: Dictionary = {
	"comun": "○", "especial": "◇", "raro": "◆",
	"epico": "★", "legendario": "✦", "mitico": "⚡", "milagro": "✸",
}

const PITY_MAX: int = 90

# ─── ESTADO ───────────────────────────────────────────────────────────────────

var _glyph_time: float = 0.0

# ─── CICLO DE VIDA ────────────────────────────────────────────────────────────

func _ready() -> void:
	pull_1_button.pressed.connect(_on_pull_1)
	pull_10_button.pressed.connect(_on_pull_10)
	dismiss_button.pressed.connect(_dismiss_results)
	GameState.blue_balls_changed.connect(func(_v): _update_ui())
	_update_ui()

func _process(delta: float) -> void:
	_glyph_time += delta
	var pulse: float = 0.7 + sin(_glyph_time * 1.8) * 0.3
	portal_glyph.modulate = Color(0.6 * pulse, 0.4 * pulse, 1.0, 0.9)

# ─── UI ───────────────────────────────────────────────────────────────────────

func _update_ui() -> void:
	orbs_label.text = "%d" % GameState.blue_balls
	pity_label.text = "%d / %d" % [GameState.pity_legendario, PITY_MAX]

	var can1: bool = GameState.can_pull_single()
	var can10: bool = GameState.can_pull_multi()
	pull_1_button.disabled = not can1
	pull_10_button.disabled = not can10
	pull_1_button.modulate = Color.WHITE if can1 else Color(1, 1, 1, 0.4)
	pull_10_button.modulate = Color.WHITE if can10 else Color(1, 1, 1, 0.4)

# ─── PULL ─────────────────────────────────────────────────────────────────────

func _on_pull_1() -> void:
	var character: Character = GameState.pull_single()
	if character == null:
		return
	_show_results([character])

func _on_pull_10() -> void:
	var results: Array = GameState.pull_multi()
	if results.is_empty():
		return
	_show_results(results)

# ─── RESULTADOS ───────────────────────────────────────────────────────────────

func _show_results(characters: Array) -> void:
	for child in cards_container.get_children():
		child.queue_free()

	for character in characters:
		cards_container.add_child(_make_card(character))

	_update_ui()
	results_overlay.show()

func _dismiss_results() -> void:
	results_overlay.hide()

func _make_card(character: Character) -> Control:
	var rarity: String = character.rarity
	var rc: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var glyph: String = RARITY_GLYPHS.get(rarity, "?")

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(110, 150)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)

	# Franja superior de rareza
	var top_bar := ColorRect.new()
	top_bar.custom_minimum_size = Vector2(0, 5)
	top_bar.color = rc

	# Glifo de rareza
	var glyph_lbl := Label.new()
	glyph_lbl.text = glyph
	glyph_lbl.add_theme_font_size_override("font_size", 32)
	glyph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_lbl.modulate = rc

	# Nombre
	var name_lbl := Label.new()
	name_lbl.text = character.name
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Rareza
	var rarity_lbl := Label.new()
	rarity_lbl.text = RARITY_LABELS.get(rarity, rarity)
	rarity_lbl.add_theme_font_size_override("font_size", 9)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.modulate = Color(rc.r, rc.g, rc.b, 0.85)

	# Clase
	var class_lbl := Label.new()
	class_lbl.text = character.char_class.capitalize()
	class_lbl.add_theme_font_size_override("font_size", 9)
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_lbl.modulate = Color(1, 1, 1, 0.45)

	vbox.add_child(top_bar)
	vbox.add_child(glyph_lbl)
	vbox.add_child(name_lbl)
	vbox.add_child(rarity_lbl)
	vbox.add_child(class_lbl)
	card.add_child(vbox)

	# Resaltar legendario+
	if rarity in ["legendario", "mitico", "milagro"]:
		card.modulate = Color(1.1, 1.05, 0.9)

	return card
