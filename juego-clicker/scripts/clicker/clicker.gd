extends Control

@onready var score_label: Label = $CenterContainer/VBoxContainer/ScoreLabel
@onready var click_button: Button = $CenterContainer/VBoxContainer/ClickButton

func _ready() -> void:
	score_label.add_theme_font_size_override("font_size", 32)
	click_button.custom_minimum_size = Vector2(200, 200)
	click_button.pressed.connect(_on_click)
	GameState.blue_balls_changed.connect(_on_balls_changed)
	score_label.text = "%d Core Energy" % GameState.blue_balls

func _on_click() -> void:
	GameState.register_click()

func _on_balls_changed(new_value: int) -> void:
	score_label.text = "%d Core Energy" % new_value
