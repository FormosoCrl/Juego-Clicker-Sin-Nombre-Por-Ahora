extends Node2D

var spirit_id: String = ""
var spirit_color: Color = Color.WHITE
var spirit_name: String = ""

var _velocity: Vector2 = Vector2.ZERO
var _screen_size: Vector2 = Vector2.ZERO
var _is_glowing: bool = false
var _glow_timer: float = 0.0
var _base_scale: float = 1.0
var _bob_offset: float = 0.0

func setup(id: String, color: Color, sname: String, screen_size: Vector2) -> void:
	spirit_id = id
	spirit_color = color
	spirit_name = sname
	_screen_size = screen_size
	position = Vector2(
		randf_range(40, screen_size.x - 40),
		randf_range(40, screen_size.y - 100)
	)
	var angle: float = randf() * TAU
	var speed: float = randf_range(20.0, 50.0)
	_velocity = Vector2(cos(angle), sin(angle)) * speed
	_base_scale = randf_range(0.8, 1.2)
	_bob_offset = randf() * TAU
	scale = Vector2(_base_scale, _base_scale)
	modulate = Color(spirit_color.r, spirit_color.g, spirit_color.b, 0.85)

func activate_glow(duration: float) -> void:
	_is_glowing = true
	_glow_timer = duration
	modulate = Color(
		min(spirit_color.r * 2.0, 1.0),
		min(spirit_color.g * 2.0, 1.0),
		min(spirit_color.b * 2.0, 1.0),
		1.0
	)

func _process(delta: float) -> void:
	position += _velocity * delta
	if position.x < 20 or position.x > _screen_size.x - 20:
		_velocity.x *= -1
		position.x = clamp(position.x, 20, _screen_size.x - 20)
	if position.y < 20 or position.y > _screen_size.y - 100:
		_velocity.y *= -1
		position.y = clamp(position.y, 20, _screen_size.y - 100)
	if _is_glowing:
		_glow_timer -= delta
		if _glow_timer <= 0.0:
			_is_glowing = false
			modulate = Color(spirit_color.r, spirit_color.g, spirit_color.b, 0.85)
	var bob: float = sin(Time.get_ticks_msec() * 0.002 + _bob_offset) * 3.0
	position.y += bob * delta
	queue_redraw()

func _draw() -> void:
	var c: Color = spirit_color
	draw_circle(Vector2.ZERO, 18.0, Color(c.r, c.g, c.b, 0.3))
	draw_circle(Vector2.ZERO, 12.0, Color(c.r, c.g, c.b, 0.9))
	draw_circle(Vector2.ZERO, 5.0, Color(1, 1, 1, 0.7))
