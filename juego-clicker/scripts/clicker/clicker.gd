extends Control

const SpiritNodeScript = preload("res://scripts/clicker/SpiritNode.gd")

@onready var score_label: Label = $CenterContainer/VBoxContainer/ScoreLabel
@onready var click_button: Button = $CenterContainer/VBoxContainer/ClickButton
@onready var boost_button: Button = $CenterContainer/VBoxContainer/BoostButton
@onready var boost_label: Label = $CenterContainer/VBoxContainer/BoostLabel
@onready var spirits_button: Button = $CenterContainer/VBoxContainer/SpiritsButton
@onready var spirit_shop: Control = $SpiritShopPanel

var _check_timer: float = 0.0
var _spirit_nodes: Dictionary = {}

func _ready() -> void:
	score_label.add_theme_font_size_override("font_size", 32)
	click_button.custom_minimum_size = Vector2(200, 200)
	click_button.pressed.connect(_on_click)
	boost_button.pressed.connect(_on_boost_pressed)
	spirits_button.pressed.connect(func(): spirit_shop.show())
	GameState.blue_balls_changed.connect(_on_balls_changed)
	GameState.boost_changed.connect(_on_boost_changed)
	GameState.spirit_purchased.connect(_on_spirit_purchased)
	GameState.spirit_activated.connect(_on_spirit_activated)
	score_label.text = "%d Core Energy" % GameState.blue_balls
	for spirit_id in GameState.owned_spirits:
		_spawn_spirit(spirit_id)

func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer >= 1.0:
		_check_timer = 0.0
		_update_boost_button()

func _update_boost_button() -> void:
	if GameState.boost_active:
		boost_button.visible = false
		return
	var available: bool = GameState.get_boost_available()
	boost_button.visible = available
	if available:
		var seconds_in_cycle: int = int(Time.get_unix_time_from_system()) % 600
		var seconds_left: int = 300 - seconds_in_cycle
		boost_button.text = "⚡ ¡BOOST! (%ds)" % seconds_left

func _spawn_spirit(spirit_id: String) -> void:
	if _spirit_nodes.has(spirit_id):
		return
	var spirit_data: Dictionary = GameData.SPIRITS.get(spirit_id, {})
	var node := Node2D.new()
	node.set_script(SpiritNodeScript)
	add_child(node)
	node.setup(
		spirit_id,
		spirit_data.get("color", Color.WHITE),
		spirit_data.get("name", "?"),
		get_viewport_rect().size
	)
	_spirit_nodes[spirit_id] = node

func _on_click() -> void:
	GameState.register_click()

func _on_boost_pressed() -> void:
	GameState.activate_boost()

func _on_boost_changed(active: bool, seconds_remaining: float) -> void:
	if active:
		boost_button.visible = false
		boost_label.visible = true
		boost_label.text = "⚡ x1.5 activo — %ds" % int(seconds_remaining)
	else:
		boost_label.visible = false
		_update_boost_button()

func _on_spirit_purchased(spirit_id: String) -> void:
	_spawn_spirit(spirit_id)

func _on_spirit_activated(spirit_id: String) -> void:
	var node = _spirit_nodes.get(spirit_id, null)
	if node != null:
		node.activate_glow(1.5)

func _on_balls_changed(new_value: int) -> void:
	score_label.text = "%d Core Energy" % new_value
