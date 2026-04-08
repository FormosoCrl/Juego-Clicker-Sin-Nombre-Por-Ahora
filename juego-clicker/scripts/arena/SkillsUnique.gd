extends Node

const SkillsGeneric = preload("res://scripts/arena/SkillsGeneric.gd")

static func execute(
		skill_id: String,
		caster: Combatant,
		targets: Array,
		all_combatants: Array) -> void:
	match skill_id:
		"luck_barrage":      _luck_barrage(caster, targets)
		"overwhelming_luck": _overwhelming_luck(caster)
		_:
			SkillsGeneric.execute(skill_id, caster, targets, all_combatants)

# ─── LUCKAS ───────────────────────────────────────────────────────────────────

static func _luck_barrage(caster: Combatant, targets: Array) -> void:
	if targets.is_empty():
		return
	var suerte: int = caster.character.suerte_combat
	var target: Combatant = targets[0]
	var base_hits: int = int(floor(suerte / 60.0))
	var hits: int

	if caster.next_barrage_max:
		hits = 8
		caster.next_barrage_max = false
	else:
		hits = clamp(base_hits + randi_range(-1, 2), 4, 8)

	var hit_count: int = 0
	for i in range(hits):
		var hit_chance: float = min(0.75 + suerte / 1200.0, 0.95)
		if randf() <= hit_chance:
			target.receive_damage(_barrage_damage(caster))
			hit_count += 1
			if not target.character.is_alive():
				break

	caster.luck_barrage_hits_total += hit_count

	# Pasiva Gambler's Edge
	var max_possible: int = clamp(base_hits + 2, 4, 8)
	if hits == max_possible:
		caster.character.suerte_combat += 5

static func _barrage_damage(caster: Combatant) -> int:
	var s: int = caster.character.suerte_combat
	var f: int = caster.character.fuerza_base
	var base: float = f * 0.4 + s * 0.15
	return max(1, int(base + base * randf_range(-0.12, 0.12)))

static func _overwhelming_luck(caster: Combatant) -> void:
	if caster.luck_barrage_hits_total < 12:
		caster.skill_2_ready = false
		caster.skill_2_timer = 0.0
		return
	var suerte: int = caster.character.suerte_combat
	var duration: float = (2 + int(suerte / 130.0)) * 3.0
	caster.apply_effect("invulnerable", duration)
	caster.overwhelmed_active = true
	var regen_ps: float = (caster.character.vida_max() * 0.15) / 3.0
	caster.apply_effect("regen", duration, regen_ps)
	caster.next_barrage_max = true
