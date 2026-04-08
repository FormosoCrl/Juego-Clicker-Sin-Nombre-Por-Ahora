extends Node
class_name CombatManager

const SkillsUnique = preload("res://scripts/arena/SkillsUnique.gd")
const SkillsGeneric = preload("res://scripts/arena/SkillsGeneric.gd")

# ─── SEÑALES ──────────────────────────────────────────────────────────────────

signal combat_started()
signal combat_ended(player_won: bool)
signal character_died(character: Character, is_player_side: bool)
signal attack_happened(attacker: Combatant, target: Combatant, damage: int)
signal attack_missed_happened(attacker: Combatant)
signal skill_used(caster: Combatant, skill_id: String, targets: Array)
signal xp_gained(character: Character, amount: int)

# ─── ESTADO DEL COMBATE ───────────────────────────────────────────────────────

enum CombatState { IDLE, ACTIVE, PAUSED, ENDED }

var state: CombatState = CombatState.IDLE
var chapter: int = 1
var is_boss_fight: bool = false

# ─── COMBATANTS ───────────────────────────────────────────────────────────────

var player_combatants: Array = []   # Array de Combatant
var enemy_combatants: Array = []    # Array de Combatant

# ─── TARGETING MANUAL ─────────────────────────────────────────────────────────

var selected_player_combatant: Combatant = null
var manual_targets: Dictionary = {}  # { combatant_id: enemy_combatant }

# ─── XP BASE POR ENEMIGO ─────────────────────────────────────────────────────

const XP_PER_ENEMY: int = 20
const XP_PER_BOSS: int = 100

# ─── SETUP ────────────────────────────────────────────────────────────────────

func setup(team: Array, enemies_data: Array, chapter_num: int, boss: bool) -> void:
	chapter = chapter_num
	is_boss_fight = boss
	player_combatants.clear()
	enemy_combatants.clear()
	manual_targets.clear()
	selected_player_combatant = null

	# Crear combatants del jugador
	for character in team:
		var combatant: Combatant = Combatant.new()
		add_child(combatant)
		combatant.setup(character, true)
		_connect_combatant_signals(combatant)
		player_combatants.append(combatant)

	# Crear combatants enemigos desde datos
	for enemy_data in enemies_data:
		var enemy: Combatant = _create_enemy_combatant(enemy_data)
		add_child(enemy)
		_connect_combatant_signals(enemy)
		enemy_combatants.append(enemy)

func _create_enemy_combatant(data: Dictionary) -> Combatant:
	var character := Character.new()
	character.id = data.get("id", "enemy_%d" % randi())
	character.name = data.get("name", "Enemigo")
	character.rarity = "comun"
	character.char_class = data.get("class", "guerrero")
	character.is_unique = false
	character.vida_base = data.get("vida", 80)
	character.fuerza_base = data.get("fuerza", 10)
	character.mana_base = data.get("mana", 0)
	character.suerte_base = data.get("suerte", 5)
	character.attack_speed_min = data.get("attack_speed", 2.0)
	character.attack_speed_max = data.get("attack_speed", 2.0)
	character.attack_hit_chance = data.get("hit_chance", 0.85)
	character.skill_1_id = data.get("skill_1_id", "")
	character.skill_2_id = data.get("skill_2_id", "")

	var combatant := Combatant.new()
	combatant.setup(character, false)
	combatant.is_boss = data.get("is_boss", false)
	return combatant

func _connect_combatant_signals(combatant: Combatant) -> void:
	combatant.attack_landed.connect(_on_attack_landed)
	combatant.attack_missed.connect(_on_attack_missed)
	combatant.died.connect(_on_combatant_died)

# ─── CONTROL DEL COMBATE ──────────────────────────────────────────────────────

func start() -> void:
	if state != CombatState.IDLE:
		return
	state = CombatState.ACTIVE
	emit_signal("combat_started")

func pause() -> void:
	if state == CombatState.ACTIVE:
		state = CombatState.PAUSED

func resume() -> void:
	if state == CombatState.PAUSED:
		state = CombatState.ACTIVE

func _process(_delta: float) -> void:
	if state != CombatState.ACTIVE:
		return
	# Los Combatant tienen su propio _process, aquí solo
	# verificamos condiciones de victoria/derrota cada frame
	_check_combat_end()

# ─── TARGETING ────────────────────────────────────────────────────────────────

# Llamado desde la UI cuando el jugador selecciona un combatant propio
func select_player_combatant(combatant: Combatant) -> void:
	selected_player_combatant = combatant

# Llamado desde la UI cuando el jugador hace click en un enemigo
# después de haber seleccionado un personaje propio
func set_manual_target(enemy: Combatant) -> void:
	if selected_player_combatant == null:
		return
	if not enemy.character.is_alive():
		return
	manual_targets[selected_player_combatant.character.id] = enemy
	selected_player_combatant = null

func _get_target_for(combatant: Combatant) -> Combatant:
	# Target manual si existe y sigue vivo
	var manual: Combatant = manual_targets.get(combatant.character.id, null)
	if manual != null and manual.character.is_alive():
		return manual

	# Limpiar target manual muerto
	if manual != null:
		manual_targets.erase(combatant.character.id)

	# Targeting inteligente por clase — solo autoataques básicos, daño puro
	var alive_enemies: Array = enemy_combatants.filter(
		func(e): return e.character.is_alive())
	if alive_enemies.is_empty():
		return null

	match combatant.character.char_class:
		"guerrero", "mago", "arquero":
			return _get_highest_hp(alive_enemies)
		"picaro", "sanador":
			return _get_lowest_hp(alive_enemies)
		_:
			return alive_enemies[randi() % alive_enemies.size()]

func _get_enemy_target_for(_enemy: Combatant) -> Combatant:
	# Enemigos — targeting aleatorio entre jugadores vivos por ahora
	var alive_players: Array = player_combatants.filter(
		func(c): return c.character.is_alive())
	if alive_players.is_empty():
		return null
	return alive_players[randi() % alive_players.size()]

func _get_highest_hp(combatants: Array) -> Combatant:
	var best: Combatant = combatants[0]
	for c in combatants:
		if c.character.vida_actual > best.character.vida_actual:
			best = c
	return best

func _get_lowest_hp(combatants: Array) -> Combatant:
	var best: Combatant = combatants[0]
	for c in combatants:
		if c.character.vida_actual < best.character.vida_actual:
			best = c
	return best

# ─── SEÑALES DE COMBATANT ────────────────────────────────────────────────────

func _on_attack_landed(attacker: Combatant, damage: int, _is_crit: bool) -> void:
	if state != CombatState.ACTIVE:
		return

	# Resolver target
	var target: Combatant
	if attacker.is_player_side:
		target = _get_target_for(attacker)
	else:
		target = _get_enemy_target_for(attacker)

	if target == null:
		return

	# Aplicar daño — autoataque básico, daño puro sin efectos
	# Comprobar evasión del target
	var evasion_effect = _get_effect_value(target, "evasion")
	if evasion_effect > 0.0 and randf() < evasion_effect:
		emit_signal("attack_missed_happened", attacker)
		return

	# Comprobar daño_taken_increase
	var damage_increase: float = _get_effect_value(target, "damage_taken_increase")
	var final_damage: int = int(damage * (1.0 + damage_increase))

	# Comprobar damage_reduction del target
	var reduction: float = _get_effect_value(target, "damage_reduction")
	final_damage = int(final_damage * (1.0 - reduction))

	target.receive_damage(max(1, final_damage))
	emit_signal("attack_happened", attacker, target, final_damage)

func _on_attack_missed(attacker: Combatant) -> void:
	emit_signal("attack_missed_happened", attacker)

func _on_combatant_died(combatant: Combatant) -> void:
	emit_signal("character_died", combatant.character, combatant.is_player_side)

	if combatant.is_player_side:
		# Muerte permanente — avisar a GameState
		GameState.mark_character_dead(combatant.character.id)
		# Limpiar target manual si apuntaba a este
		manual_targets.erase(combatant.character.id)
		if selected_player_combatant == combatant:
			selected_player_combatant = null

# ─── HABILIDADES (lanzadas por el jugador desde la UI) ────────────────────────

func player_use_skill(combatant: Combatant, slot: int) -> void:
	if state != CombatState.ACTIVE:
		return
	if not combatant.is_player_side:
		return

	var skill_id: String = combatant.character.skill_1_id if slot == 1 \
			else combatant.character.skill_2_id
	if skill_id == "":
		return

	var skill_data: Dictionary = GameData.SKILLS.get(skill_id, {})
	var targets: Array = _resolve_skill_targets(combatant, skill_data)

	combatant.use_skill(slot, targets, player_combatants + enemy_combatants)
	emit_signal("skill_used", combatant, skill_id, targets)

func _resolve_skill_targets(caster: Combatant, skill_data: Dictionary) -> Array:
	var target_type: String = skill_data.get("target", "ST_enemy")
	var alive_enemies: Array = enemy_combatants.filter(
		func(e): return e.character.is_alive())
	var alive_allies: Array = player_combatants.filter(
		func(c): return c.character.is_alive())

	match target_type:
		"ST_enemy":
			# Target manual si hay uno seleccionado, si no el de menor vida
			var manual: Combatant = manual_targets.get(caster.character.id, null)
			if manual != null and manual.character.is_alive():
				return [manual]
			if not alive_enemies.is_empty():
				return [_get_lowest_hp(alive_enemies)]
			return []
		"AoE_enemy":
			return alive_enemies
		"ST_ally":
			# El aliado con menos vida
			if not alive_allies.is_empty():
				return [_get_lowest_hp(alive_allies)]
			return []
		"ST_ally_self":
			return [caster]
		"AoE_ally":
			return alive_allies
		_:
			return []

# ─── HELPERS DE EFECTOS ───────────────────────────────────────────────────────

func _get_effect_value(combatant: Combatant, effect_type: String) -> float:
	for effect in combatant.effects:
		if effect["type"] == effect_type:
			return float(effect.get("value", 0.0))
	return 0.0

# ─── FIN DE COMBATE ───────────────────────────────────────────────────────────

func _check_combat_end() -> void:
	var all_enemies_dead: bool = enemy_combatants.all(
		func(e): return not e.character.is_alive())
	var all_players_dead: bool = player_combatants.all(
		func(c): return not c.character.is_alive())

	if all_enemies_dead:
		_end_combat(true)
	elif all_players_dead:
		_end_combat(false)

func _end_combat(player_won: bool) -> void:
	if state == CombatState.ENDED:
		return
	state = CombatState.ENDED

	if player_won:
		_distribute_xp()
		if is_boss_fight:
			GameState.complete_boss(chapter)

	# Limpiar combatants
	for c in player_combatants + enemy_combatants:
		c.queue_free()

	emit_signal("combat_ended", player_won)

func _distribute_xp() -> void:
	var base_xp: int = XP_PER_BOSS if is_boss_fight else XP_PER_ENEMY
	base_xp = int(base_xp * GameState.get_xp_decay(chapter))

	# XP se reparte entre los personajes vivos del equipo
	var survivors: Array = player_combatants.filter(
		func(c): return c.character.is_alive())
	if survivors.is_empty():
		return

	for combatant in survivors:
		var leveled_up: bool = combatant.character.add_xp(base_xp)
		emit_signal("xp_gained", combatant.character, base_xp)
		if leveled_up:
			Firebase.save_character(combatant.character)
