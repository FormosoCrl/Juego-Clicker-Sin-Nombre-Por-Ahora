extends Node

const CharacterFactory = preload("res://scripts/characters/CharacterFactory.gd")
const UniqueCharacters = preload("res://scripts/characters/UniqueCharacters.gd")

# ─── SEÑALES ──────────────────────────────────────────────────────────────────

signal blue_balls_changed(new_value: int)
signal doradas_changed(new_value: int)
signal energy_changed(new_value: int, max_value: int)
signal roster_changed()
signal team_changed()
signal rebirth_available()
signal level_unlocked(chapter: int)
signal boost_changed(active: bool, seconds_remaining: float)
signal spirit_purchased(spirit_id: String)
signal spirit_activated(spirit_id: String)

# ─── ESTADO DE SESIÓN ─────────────────────────────────────────────────────────

var is_logged_in: bool = false
var uid: String = ""
var last_sync_timestamp: int = 0

# ─── ECONOMÍA ─────────────────────────────────────────────────────────────────

var blue_balls: int = 0:
	set(value):
		blue_balls = max(0, value)
		emit_signal("blue_balls_changed", blue_balls)
		_check_rebirth_available()

var doradas: int = 0:
	set(value):
		doradas = max(0, value)
		emit_signal("doradas_changed", doradas)

var click_multiplier: float = 1.0
var rebirth_count: int = 0

var boost_active: bool = false
var boost_ends_at: float = 0.0
var boost_multiplier: float = 1.5
var _boost_cycle_used: int = -1

var owned_spirits: Dictionary = {}
var spirit_click_counter: int = 0
var _tide_accumulator: float = 0.0

# ─── ENERGÍA ──────────────────────────────────────────────────────────────────

var energy: int = 0:
	set(value):
		energy = clamp(value, 0, energy_max)
		emit_signal("energy_changed", energy, energy_max)

var energy_max: int = GameData.ENERGY_BASE_MAX
var energy_regen_accumulator: float = 0.0

# ─── GACHA / PITY ─────────────────────────────────────────────────────────────

var pity_legendario: int = 0

# ─── ROSTER ───────────────────────────────────────────────────────────────────

# Todos los personajes del jugador, serializados completos
var roster: Array = []  # Array de Character

# Equipo activo para la arena (máx 5, subconjunto de roster)
var team: Array = []    # Array de Character (referencias a objetos en roster)

# ─── PROGRESO DE ARENA ────────────────────────────────────────────────────────

var current_chapter: int = 1
var pending_combat_chapter: int = 1
var pending_combat_level: int = 1
var bosses_cleared: int = 0
var weekly_replays: Dictionary = {}
var weekly_reset_timestamp: int = 0

# ─── SISTEMA DE CLICKS ────────────────────────────────────────────────────────

var click_batch: Array = []
var last_click_times: Array = []  # timestamps de los últimos clicks para antitrampas
var _click_accumulator: float = 0.0

# ─── CICLO DE VIDA ────────────────────────────────────────────────────────────

func _ready() -> void:
	energy = GameData.ENERGY_BASE_MAX
	_recalculate_energy_max()
	var autosave_timer := Timer.new()
	autosave_timer.wait_time = 60.0
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(_autosave)
	add_child(autosave_timer)

func _autosave() -> void:
	Firebase.save_player_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Firebase.save_session()   # síncrono — escribe en disco antes de salir
		Firebase.save_player_state()  # async a Firestore, best-effort
		get_tree().quit()

func _process(delta: float) -> void:
	_process_energy_regen(delta)
	_process_tide(delta)
	if boost_active:
		var remaining: float = boost_ends_at - Time.get_unix_time_from_system()
		if remaining <= 0.0:
			boost_active = false
			boost_ends_at = 0.0
			emit_signal("boost_changed", false, 0.0)
		else:
			emit_signal("boost_changed", true, remaining)

# ─── ENERGÍA ──────────────────────────────────────────────────────────────────

func _process_energy_regen(delta: float) -> void:
	if energy >= energy_max:
		return
	energy_regen_accumulator += delta
	if energy_regen_accumulator >= GameData.ENERGY_REGEN_SECONDS:
		energy_regen_accumulator -= GameData.ENERGY_REGEN_SECONDS
		energy += 1

func _recalculate_energy_max() -> void:
	energy_max = GameData.get_energy_max_for_bosses(bosses_cleared)
	emit_signal("energy_changed", energy, energy_max)

func spend_energy(amount: int) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true

# ─── BOOST ────────────────────────────────────────────────────────────────────

func _get_boost_duration() -> float:
	if owned_spirits.has("aether"):
		return 120.0
	if owned_spirits.has("solaris"):
		return GameData.SPIRITS["solaris"]["boost_duration"]
	if owned_spirits.has("flicker"):
		return GameData.SPIRITS["flicker"]["value"]
	return 60.0

func activate_boost() -> void:
	if boost_active or not get_boost_available():
		return
	_boost_cycle_used = int(Time.get_unix_time_from_system()) / 600
	boost_active = true
	var duration: float = _get_boost_duration()
	boost_ends_at = Time.get_unix_time_from_system() + duration
	emit_signal("boost_changed", true, duration)

func get_boost_available() -> bool:
	var now: int = int(Time.get_unix_time_from_system())
	var current_cycle: int = now / 600
	var seconds_in_cycle: int = now % 600
	return seconds_in_cycle < 300 and not boost_active and _boost_cycle_used != current_cycle

func get_boost_cooldown_seconds() -> int:
	var now: int = int(Time.get_unix_time_from_system())
	var seconds_in_cycle: int = now % 600
	return 600 - seconds_in_cycle

# ─── ESPÍRITUS ────────────────────────────────────────────────────────────────

func can_buy_spirit(spirit_id: String) -> bool:
	if owned_spirits.has(spirit_id):
		return false
	var spirit: Dictionary = GameData.SPIRITS.get(spirit_id, {})
	return doradas >= spirit.get("price", 0)

func buy_spirit(spirit_id: String) -> bool:
	if not can_buy_spirit(spirit_id):
		return false
	var spirit: Dictionary = GameData.SPIRITS.get(spirit_id, {})
	doradas -= spirit.get("price", 0)
	owned_spirits[spirit_id] = true
	emit_signal("spirit_purchased", spirit_id)
	Firebase.save_player_state()
	Firebase.save_session()
	return true

func _process_tide(delta: float) -> void:
	if not owned_spirits.has("tide"):
		return
	_tide_accumulator += delta
	if _tide_accumulator >= 900.0:
		_tide_accumulator -= 900.0
		blue_balls += 200
		emit_signal("spirit_activated", "tide")

# ─── CLICKS ───────────────────────────────────────────────────────────────────

func register_click() -> void:
	var now: int = Time.get_ticks_msec()

	# Antitrampas local: guardar timestamp
	last_click_times.append(now)
	if last_click_times.size() > GameData.CLICK_MAX_PER_SECOND + 5:
		last_click_times.pop_front()

	# Añadir al lote
	click_batch.append(now)

	# Acreditar localmente de inmediato (optimistic update)
	var effective_multiplier: float = click_multiplier * (boost_multiplier if boost_active else 1.0)

	# Espíritus — bonuses pasivos
	if owned_spirits.has("wisp"):
		effective_multiplier *= 1.05
	if owned_spirits.has("volt"):
		effective_multiplier *= 1.15
	if owned_spirits.has("solaris"):
		effective_multiplier *= (1.0 + GameData.SPIRITS["solaris"]["passive_bonus"])

	# Espíritus — ember (cada N clicks x3), se aplica antes de los de azar
	if owned_spirits.has("ember"):
		spirit_click_counter += 1
		if spirit_click_counter >= 25:
			spirit_click_counter = 0
			effective_multiplier *= 3.0
			emit_signal("spirit_activated", "ember")

	# Espíritus — efectos de azar (solo uno actúa por click)
	var rolled: float = randf()
	if owned_spirits.has("nova") or owned_spirits.has("solaris"):
		var chance_x10: float = GameData.SPIRITS["nova"]["value"] if owned_spirits.has("nova") \
				else GameData.SPIRITS["solaris"]["chance_x10"]
		if rolled < chance_x10:
			effective_multiplier *= 10.0
			var src: String = "nova" if owned_spirits.has("nova") else "solaris"
			emit_signal("spirit_activated", src)
	elif owned_spirits.has("gale") and rolled < GameData.SPIRITS["gale"]["value"]:
		effective_multiplier *= 3.0
		emit_signal("spirit_activated", "gale")
	elif owned_spirits.has("blaze") and rolled < GameData.SPIRITS["blaze"]["value"]:
		effective_multiplier *= 2.0
		emit_signal("spirit_activated", "blaze")

	_click_accumulator += GameData.CLICK_BASE_VALUE * effective_multiplier
	var earned: int = int(_click_accumulator)
	_click_accumulator -= earned
	blue_balls += earned

	# Enviar lote cuando alcanza el tamaño definido
	if click_batch.size() >= GameData.CLICK_BATCH_SIZE:
		_flush_click_batch()

func _flush_click_batch() -> void:
	if click_batch.is_empty():
		return
	var batch_to_send: Array = click_batch.duplicate()
	click_batch.clear()
	# Firebase valida y acredita server-side
	# El cliente ya acreditó optimísticamente, Firebase puede corregir
	Firebase.send_click_batch(batch_to_send, click_multiplier)

# ─── REBIRTH ──────────────────────────────────────────────────────────────────

func _check_rebirth_available() -> void:
	if blue_balls >= GameData.get_rebirth_threshold(rebirth_count):
		emit_signal("rebirth_available")

func do_rebirth() -> bool:
	if blue_balls < GameData.get_rebirth_threshold(rebirth_count):
		return false
	blue_balls = 0
	rebirth_count += 1
	click_multiplier = pow(GameData.REBIRTH_MULTIPLIER_PER, rebirth_count)
	Firebase.save_rebirth(rebirth_count, click_multiplier)
	return true

# ─── GACHA ────────────────────────────────────────────────────────────────────

func can_pull_single() -> bool:
	return blue_balls >= GameData.GACHA_COST_SINGLE

func can_pull_multi() -> bool:
	return blue_balls >= GameData.GACHA_COST_MULTI

func pull_single() -> Character:
	if not can_pull_single():
		return null
	blue_balls -= GameData.GACHA_COST_SINGLE
	return _do_pull()

func pull_multi() -> Array:
	if not can_pull_multi():
		return []
	blue_balls -= GameData.GACHA_COST_MULTI
	var results: Array = []
	for i in range(10):
		results.append(_do_pull())
	return results

func _do_pull() -> Character:
	var rarity: String = GameData.roll_rarity(pity_legendario)

	# Actualizar pity
	if rarity in ["legendario", "milagro"]:
		pity_legendario = 0
	else:
		pity_legendario += 1

	# Crear personaje
	var character: Character
	if rarity == "milagro" and randf() < 0.3:
		# 30% de chance de ser un único al sacar milagro
		var unique_ids: Array = UniqueCharacters.get_all_ids()
		if not unique_ids.is_empty():
			character = CharacterFactory.create_unique(
				unique_ids[randi() % unique_ids.size()])
	
	if character == null:
		character = CharacterFactory.create_procedural(rarity)

	add_to_roster(character)
	return character

# ─── ROSTER ───────────────────────────────────────────────────────────────────

func add_to_roster(character: Character) -> void:
	roster.append(character)
	emit_signal("roster_changed")
	Firebase.save_character(character)

func remove_from_roster(character_id: String) -> void:
	for i in range(roster.size()):
		if roster[i].id == character_id:
			# Quitar del equipo si estaba
			team = team.filter(func(c): return c.id != character_id)
			roster.remove_at(i)
			emit_signal("roster_changed")
			emit_signal("team_changed")
			Firebase.delete_character(character_id)
			return

func mark_character_dead(character_id: String) -> void:
	for character in roster:
		if character.id == character_id:
			character.is_dead = true
			# Quitar del equipo inmediatamente
			team = team.filter(func(c): return c.id != character_id)
			emit_signal("team_changed")
			Firebase.save_character(character)
			# Eliminar del roster tras un delay para que la UI pueda mostrar la muerte
			await get_tree().create_timer(3.0).timeout
			remove_from_roster(character_id)
			return

func get_character_by_id(character_id: String) -> Character:
	for character in roster:
		if character.id == character_id:
			return character
	return null

# ─── EQUIPO ───────────────────────────────────────────────────────────────────

func add_to_team(character_id: String) -> bool:
	if team.size() >= GameData.MAX_TEAM_SIZE:
		return false
	var character: Character = get_character_by_id(character_id)
	if character == null or character.is_dead:
		return false
	# Comprobar que no esté ya en el equipo
	for member in team:
		if member.id == character_id:
			return false
	team.append(character)
	emit_signal("team_changed")
	return true

func remove_from_team(character_id: String) -> void:
	team = team.filter(func(c): return c.id != character_id)
	emit_signal("team_changed")

# ─── ARENA ────────────────────────────────────────────────────────────────────

func can_play_level(chapter: int, is_new: bool) -> bool:
	var cost: int = GameData.get_energy_cost_new(chapter) if is_new \
			else GameData.ENERGY_COST_OLD_LEVEL
	if energy < cost:
		return false
	if not is_new:
		_check_weekly_reset()
		var replays: int = weekly_replays.get(str(chapter), 0)
		if replays >= GameData.WEEKLY_REPLAY_LIMIT:
			return false
	return true

func start_level(chapter: int, is_new: bool) -> bool:
	if not can_play_level(chapter, is_new):
		return false
	var cost: int = GameData.get_energy_cost_new(chapter) if is_new \
			else GameData.ENERGY_COST_OLD_LEVEL
	spend_energy(cost)
	if not is_new:
		var key: String = str(chapter)
		weekly_replays[key] = weekly_replays.get(key, 0) + 1
		Firebase.save_arena_progress()
	return true

func complete_boss(chapter: int) -> void:
	bosses_cleared += 1
	current_chapter = chapter + 1
	_recalculate_energy_max()
	emit_signal("level_unlocked", current_chapter)
	Firebase.save_arena_progress()

func get_xp_decay(chapter: int) -> float:
	_check_weekly_reset()
	var replays: int = weekly_replays.get(str(chapter), 0)
	var idx: int = min(replays, GameData.XP_DECAY_TABLE.size() - 1)
	return GameData.XP_DECAY_TABLE[idx]

func _check_weekly_reset() -> void:
	var now: int = Time.get_unix_time_from_system()
	# Resetear si ha pasado más de una semana
	if now - weekly_reset_timestamp >= 604800:  # 7 días en segundos
		weekly_replays.clear()
		weekly_reset_timestamp = now
		Firebase.save_arena_progress()

# ─── MERCADO ──────────────────────────────────────────────────────────────────

func list_character_for_sale(character_id: String, price: int) -> bool:
	var character: Character = get_character_by_id(character_id)
	if character == null or character.is_dead:
		return false
	# El personaje sigue en el roster pero marcado como en venta
	Firebase.list_on_market(character, price)
	return true

func complete_sale(character_id: String, price: int) -> void:
	doradas += price
	remove_from_roster(character_id)

func purchase_character(character_dict: Dictionary, price: int) -> bool:
	if doradas < price:
		return false
	doradas -= price
	var character: Character = Character.from_dict(character_dict)
	# Nuevo ID para el comprador
	character.id = CharacterFactory.generate_id()
	add_to_roster(character)
	return true

# ─── SERIALIZACIÓN (carga inicial desde Firebase) ─────────────────────────────

func load_from_dict(data: Dictionary) -> void:
	blue_balls = data.get("blue_balls", 0)
	doradas = data.get("doradas", 0)
	rebirth_count = data.get("rebirth_count", 0)
	click_multiplier = data.get("click_multiplier", 1.0)
	pity_legendario = data.get("pity_legendario", 0)
	energy = data.get("energy", GameData.ENERGY_BASE_MAX)
	bosses_cleared = data.get("bosses_cleared", 0)
	current_chapter = data.get("current_chapter", 1)
	weekly_replays = data.get("weekly_replays", {})
	weekly_reset_timestamp = data.get("weekly_reset_timestamp", 0)
	owned_spirits = data.get("owned_spirits", {})
	spirit_click_counter = data.get("spirit_click_counter", 0)
	_boost_cycle_used = data.get("boost_cycle_used", -1)
	_recalculate_energy_max()

func to_dict() -> Dictionary:
	return {
		"blue_balls": blue_balls,
		"doradas": doradas,
		"rebirth_count": rebirth_count,
		"click_multiplier": click_multiplier,
		"pity_legendario": pity_legendario,
		"energy": energy,
		"bosses_cleared": bosses_cleared,
		"current_chapter": current_chapter,
		"weekly_replays": weekly_replays,
		"weekly_reset_timestamp": weekly_reset_timestamp,
		"owned_spirits": owned_spirits,
		"spirit_click_counter": spirit_click_counter,
		"boost_cycle_used": _boost_cycle_used,
		"last_sync": Time.get_unix_time_from_system(),
	}
