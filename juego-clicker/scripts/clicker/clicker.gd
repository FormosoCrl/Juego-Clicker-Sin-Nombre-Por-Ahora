extends Control

@onready var score_label: Label = $CenterContainer/VBoxContainer/ScoreLabel
@onready var click_button: Button = $CenterContainer/VBoxContainer/ClickButton
@onready var boost_button: Button = $CenterContainer/VBoxContainer/BoostButton
@onready var boost_label: Label = $CenterContainer/VBoxContainer/BoostLabel

var _check_timer: float = 0.0

func _ready() -> void:
	score_label.add_theme_font_size_override("font_size", 32)
	click_button.custom_minimum_size = Vector2(200, 200)
	click_button.pressed.connect(_on_click)
	boost_button.pressed.connect(_on_boost_pressed)
	GameState.blue_balls_changed.connect(_on_balls_changed)
	GameState.boost_changed.connect(_on_boost_changed)
	score_label.text = "%d Core Energy" % GameState.blue_balls

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

func _on_balls_changed(new_value: int) -> void:
	score_label.text = "%d Core Energy" % new_value
