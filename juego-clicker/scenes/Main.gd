extends Control

const ClickerScene = preload("res://scenes/clicker/Clicker.tscn")
const GachaScene = preload("res://scenes/gacha/Gacha.tscn")
const MarketScene = preload("res://scenes/market/Market.tscn")
const ArenaScene = preload("res://scenes/arena/Arena.tscn")

# ─── NODOS ────────────────────────────────────────────────────────────────────

@onready var clicker_view: Control = $ContentContainer/ClickerView
@onready var gacha_view: Control = $ContentContainer/GachaView
@onready var arena_view: Control = $ContentContainer/ArenaView
@onready var market_view: Control = $ContentContainer/MarketView

@onready var clicker_button: Button = $NavBar/HBoxContainer/ClickerButton
@onready var gacha_button: Button = $NavBar/HBoxContainer/GachaButton
@onready var arena_button: Button = $NavBar/HBoxContainer/ArenaButton
@onready var market_button: Button = $NavBar/HBoxContainer/MarketButton

# ─── ESTADO ───────────────────────────────────────────────────────────────────

enum Tab { CLICKER, GACHA, ARENA, MARKET }
var current_tab: Tab = Tab.CLICKER
var _nav_locked: bool = false

# Instancias de las subescenas
var _clicker_instance = null
var _gacha_instance = null
var _arena_instance = null
var _market_instance = null

# ─── READY ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_buttons()
	_load_all_views()
	_switch_to(Tab.CLICKER)

func _connect_buttons() -> void:
	clicker_button.pressed.connect(func(): _switch_to(Tab.CLICKER))
	gacha_button.pressed.connect(func(): _switch_to(Tab.GACHA))
	arena_button.pressed.connect(func(): _switch_to(Tab.ARENA))
	market_button.pressed.connect(func(): _switch_to(Tab.MARKET))

# ─── CARGA DE SUBESCENAS ──────────────────────────────────────────────────────

func _load_all_views() -> void:
	_clicker_instance = ClickerScene.instantiate()
	clicker_view.add_child(_clicker_instance)
	_fit_to_parent(_clicker_instance)

	_gacha_instance = GachaScene.instantiate()
	gacha_view.add_child(_gacha_instance)
	_fit_to_parent(_gacha_instance)

	_market_instance = MarketScene.instantiate()
	market_view.add_child(_market_instance)
	_fit_to_parent(_market_instance)

	_arena_instance = ArenaScene.instantiate()
	arena_view.add_child(_arena_instance)
	_fit_to_parent(_arena_instance)

func _fit_to_parent(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ─── NAVEGACIÓN ───────────────────────────────────────────────────────────────

func _switch_to(tab: Tab) -> void:
	if _nav_locked and tab != current_tab:
		return

	current_tab = tab

	clicker_view.visible = tab == Tab.CLICKER
	gacha_view.visible = tab == Tab.GACHA
	arena_view.visible = tab == Tab.ARENA
	market_view.visible = tab == Tab.MARKET

	_update_nav_buttons()

func _update_nav_buttons() -> void:
	clicker_button.disabled = false
	gacha_button.disabled = false
	arena_button.disabled = false
	market_button.disabled = false

	# Resaltar el botón activo
	clicker_button.modulate = Color(1, 1, 1, 1)
	gacha_button.modulate = Color(1, 1, 1, 1)
	arena_button.modulate = Color(1, 1, 1, 1)
	market_button.modulate = Color(1, 1, 1, 1)

	match current_tab:
		Tab.CLICKER: clicker_button.modulate = Color(0.4, 0.8, 1, 1)
		Tab.GACHA:   gacha_button.modulate   = Color(0.4, 0.8, 1, 1)
		Tab.ARENA:   arena_button.modulate   = Color(0.4, 0.8, 1, 1)
		Tab.MARKET:  market_button.modulate  = Color(0.4, 0.8, 1, 1)

	if _nav_locked:
		clicker_button.disabled = current_tab != Tab.CLICKER
		gacha_button.disabled   = current_tab != Tab.GACHA
		arena_button.disabled   = current_tab != Tab.ARENA
		market_button.disabled  = current_tab != Tab.MARKET

# ─── BLOQUEO DE NAVEGACIÓN ────────────────────────────────────────────────────
# Llamado desde combat.gd o Gacha.gd cuando empieza/termina algo crítico

func lock_navigation() -> void:
	_nav_locked = true
	_update_nav_buttons()

func unlock_navigation() -> void:
	_nav_locked = false
	_update_nav_buttons()
