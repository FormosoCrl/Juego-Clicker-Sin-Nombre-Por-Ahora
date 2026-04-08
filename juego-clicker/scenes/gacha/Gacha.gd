extends Control

@onready var balls_label: Label = $VBoxContainer/BallsLabel
@onready var pull_button_1: Button = $VBoxContainer/PullButton1
@onready var pull_button_10: Button = $VBoxContainer/PullButton10
@onready var result_label: Label = $VBoxContainer/ResultLabel

func _ready() -> void:
	pull_button_1.text = "Invocar x1 (800 bolas)"
	pull_button_10.text = "Invocar x10 (7200 bolas)"
	pull_button_1.pressed.connect(_on_pull_1)
	pull_button_10.pressed.connect(_on_pull_10)
	GameState.blue_balls_changed.connect(_on_balls_changed)
	_update_ui()

func _on_balls_changed(_value: int) -> void:
	_update_ui()

func _update_ui() -> void:
	balls_label.text = "%d bolas azules" % GameState.blue_balls
	pull_button_1.disabled = not GameState.can_pull_single()
	pull_button_10.disabled = not GameState.can_pull_multi()

func _on_pull_1() -> void:
	var character: Character = GameState.pull_single()
	if character == null:
		return
	result_label.text = _format_result([character])

func _on_pull_10() -> void:
	var results: Array = GameState.pull_multi()
	if results.is_empty():
		return
	result_label.text = _format_result(results)

func _format_result(characters: Array) -> String:
	var text: String = "── Resultado ──\n"
	for character in characters:
		text += "[%s] %s — %s\n" % [
			character.rarity.to_upper(),
			character.name,
			character.char_class
		]
	return text
