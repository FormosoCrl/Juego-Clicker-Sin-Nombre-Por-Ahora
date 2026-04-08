extends Node
class_name Combatant

const SkillsUnique = preload("res://scripts/arena/SkillsUnique.gd")
const SkillsGeneric = preload("res://scripts/arena/SkillsGeneric.gd")


signal attack_landed(combatant, damage, is_crit)
signal attack_missed(combatant)
signal skill_ready(combatant, skill_slot)  # slot: 1 o 2
signal died(combatant)

var character: Character = null
var is_player_side: bool = true

# ─── TIMERS DE ATAQUE ─────────────────────────────────────────────────────────
var attack_timer: float = 0.0
var next_attack_in: float = 0.0

# ─── COOLDOWNS DE HABILIDADES (en segundos) ───────────────────────────────────
var skill_1_cooldown_max: float = 0.0
var skill_2_cooldown_max: float = 0.0
var skill_1_timer: float = 0.0
var skill_2_timer: float = 0.0
var skill_1_ready: bool = false
var skill_2_ready: bool = false

# ─── EFECTOS ACTIVOS ──────────────────────────────────────────────────────────
var effects: Array[Dictionary] = []
# Cada efecto: { "type": String, "duration": float, "value": Variant }
# tipos: "invulnerable", "regen", "stun", "gamblers_edge_stacks"

# ─── ESTADO ÚNICO DE LUCKAS ───────────────────────────────────────────────────
var luck_barrage_hits_total: int = 0
var overwhelmed_active: bool = false
var next_barrage_max: bool = false  # garantiza 8 golpes tras Overwhelmed

func setup(char: Character, player_side: bool) -> void:
	character = char
	is_player_side = player_side
	character.init_combat()
	_roll_next_attack_time()
	_load_skill_cooldowns()

func _load_skill_cooldowns() -> void:
	if character.skill_1_id != "":
		var skill = GameData.SKILLS.get(character.skill_1_id, {})
		skill_1_cooldown_max = skill.get("cooldown", 5.0)
		skill_1_timer = skill_1_cooldown_max  # empieza lleno, listo desde el inicio
		skill_1_ready = true
	if character.skill_2_id != "":
		var skill = GameData.SKILLS.get(character.skill_2_id, {})
		skill_2_cooldown_max = skill.get("cooldown", 8.0)
		skill_2_timer = 0.0
		skill_2_ready = false

func _roll_next_attack_time() -> void:
	if character.attack_speed_uses_luck:
		# Luckas: la suerte determina qué tan cerca del mínimo está el intervalo
		var luck_factor: float = min(character.suerte_combat / 400.0, 1.0)
		var range_size: float = character.attack_speed_max - character.attack_speed_min
		# A más suerte, más probable que el intervalo sea corto
		var roll: float = randf()
		var luck_bias: float = pow(roll, 1.0 + luck_factor * 2.0)
		next_attack_in = character.attack_speed_min + range_size * luck_bias
	else:
		next_attack_in = character.attack_speed_min

func _process(delta: float) -> void:
	if not character or not character.is_alive():
		return

	_process_effects(delta)
	_process_attack_timer(delta)
	_process_skill_timers(delta)

func _process_attack_timer(delta: float) -> void:
	if _has_effect("stun"):
		return
	attack_timer += delta
	if attack_timer >= next_attack_in:
		attack_timer = 0.0
		_execute_basic_attack()
		_roll_next_attack_time()

func _process_skill_timers(delta: float) -> void:
	if not skill_1_ready:
		skill_1_timer += delta
		if skill_1_timer >= skill_1_cooldown_max:
			skill_1_timer = skill_1_cooldown_max
			skill_1_ready = true
			emit_signal("skill_ready", self, 1)

	if character.skill_2_id != "" and not skill_2_ready:
		skill_2_timer += delta
		if skill_2_timer >= skill_2_cooldown_max:
			skill_2_timer = skill_2_cooldown_max
			skill_2_ready = true
			emit_signal("skill_ready", self, 2)

func _process_effects(delta: float) -> void:
	var to_remove: Array = []
	for effect in effects:
		effect["duration"] -= delta
		if effect["type"] == "regen":
			var heal_amount: int = int(effect["value"] * delta)
			if heal_amount > 0:
				character.heal(heal_amount)
		if effect["duration"] <= 0.0:
			to_remove.append(effect)
			if effect["type"] == "invulnerable":
				overwhelmed_active = false

	for effect in to_remove:
		effects.erase(effect)

func _execute_basic_attack() -> void:
	# El CombatManager escucha esta señal y decide el target
	var hit_roll: float = randf()
	if hit_roll > character.get_hit_chance():
		emit_signal("attack_missed", self)
		return
	var damage: int = _calculate_basic_damage()
	emit_signal("attack_landed", self, damage, false)

func _calculate_basic_damage() -> int:
	var base: float = character.fuerza_base * 0.3  # antes 0.8
	var variance: float = base * 0.1
	return max(1, int(base + randf_range(-variance, variance)))

func use_skill(slot: int, targets: Array, all_combatants: Array) -> void:
	if slot == 1 and skill_1_ready:
		skill_1_ready = false
		skill_1_timer = 0.0
		SkillsUnique.execute(character.skill_1_id, self, targets, all_combatants)
	elif slot == 2 and skill_2_ready:
		skill_2_ready = false
		skill_2_timer = 0.0
		SkillsUnique.execute(character.skill_2_id, self, targets, all_combatants)

func apply_effect(type: String, duration: float, value: Variant = null) -> void:
	# Si ya existe el efecto, refresca duración
	for effect in effects:
		if effect["type"] == type:
			effect["duration"] = max(effect["duration"], duration)
			return
	effects.append({ "type": type, "duration": duration, "value": value })

func _has_effect(type: String) -> bool:
	for effect in effects:
		if effect["type"] == type:
			return true
	return false

func get_skill_progress(slot: int) -> float:
	# Devuelve 0.0 a 1.0 para la barra de cooldown en UI
	if slot == 1:
		if skill_1_ready: return 1.0
		return skill_1_timer / skill_1_cooldown_max if skill_1_cooldown_max > 0 else 0.0
	else:
		if skill_2_ready: return 1.0
		return skill_2_timer / skill_2_cooldown_max if skill_2_cooldown_max > 0 else 0.0

func receive_damage(amount: int) -> void:
	if _has_effect("invulnerable"):
		return
	var real = character.take_damage(amount)
	if not character.is_alive():
		emit_signal("died", self)

var is_boss: bool = false
