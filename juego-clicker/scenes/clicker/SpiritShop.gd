extends Control

@onready var close_button: Button = $VBoxContainer/Header/CloseButton
@onready var doradas_label: Label = $VBoxContainer/DoradasLabel
@onready var spirit_list: VBoxContainer = $VBoxContainer/ScrollContainer/SpiritList

func _ready() -> void:
	close_button.pressed.connect(func(): hide())
	GameState.doradas_changed.connect(_on_doradas_changed)
	GameState.spirit_purchased.connect(func(_id): _populate())
	_populate()

func _on_doradas_changed(value: int) -> void:
	doradas_label.text = "%d monedas doradas" % value

func _populate() -> void:
	doradas_label.text = "%d monedas doradas" % GameState.doradas
	for child in spirit_list.get_children():
		child.queue_free()

	for spirit_id in GameData.SPIRITS:
		var spirit: Dictionary = GameData.SPIRITS[spirit_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = spirit.get("color", Color.WHITE)
		row.add_child(color_rect)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = "%s [%s]" % [spirit["name"], spirit["rarity"].to_upper()]
		var desc_label := Label.new()
		desc_label.text = spirit["description"]
		desc_label.add_theme_font_size_override("font_size", 11)
		desc_label.modulate.a = 0.7
		info.add_child(name_label)
		info.add_child(desc_label)
		row.add_child(info)

		var btn := Button.new()
		if GameState.owned_spirits.has(spirit_id):
			btn.text = "✓ Poseído"
			btn.disabled = true
		else:
			btn.text = "%d 🪙" % spirit["price"]
			btn.disabled = GameState.doradas < spirit["price"]
			var sid := spirit_id
			btn.pressed.connect(func(): GameState.buy_spirit(sid))
		row.add_child(btn)

		spirit_list.add_child(row)
