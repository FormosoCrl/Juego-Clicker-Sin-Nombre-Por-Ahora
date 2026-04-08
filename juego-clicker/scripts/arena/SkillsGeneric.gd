extends Node

const Combatant = preload("res://scripts/arena/Combatant.gd")

const CLASS_SKILLS = {
	"guerrero": {
		1: ["shield_bash", "war_cry", "provoke"],
		2: ["iron_skin", "battle_roar", "colossus_smash"],
		3: ["unbreakable", "earthquake"],
	},
	"mago": {
		1: ["arcane_bolt", "frost_nova", "fireball"],
		2: ["mana_shield", "blizzard", "meteor"],
		3: ["arcane_storm", "time_warp"],
	},
	"picaro": {
		1: ["double_strike", "poison_blade", "backstab"],
		2: ["smoke_screen", "shadow_step", "cripple"],
		3: ["death_mark", "assassinate"],
	},
	"sanador": {
		1: ["heal", "barrier", "group_heal"],
		2: ["renew", "group_barrier", "greater_heal"],
		3: ["revive", "divine_hymn"],
	},
	"arquero": {
		1: ["crippling_arrow", "double_shot", "eagle_eye"],
		2: ["rain_of_arrows", "piercing_shot", "volley"],
		3: ["marked_for_death", "snipe"],
	},
}

static func get_available_skills(char_class: String, rarity: String) -> Array:
	var available: Array = []
	var class_pool: Dictionary = CLASS_SKILLS.get(char_class, {})
	for tier in [1, 2, 3]:
		if rarity in GameData.SKILL_TIER_MIN_RARITY[tier]:
			available.append_array(class_pool.get(tier, []))
	return available

static func assign_skills(char_class: String, rarity: String) -> Dictionary:
	var available: Array = get_available_skills(char_class, rarity)
	if available.is_empty():
		return { "skill_1": "", "skill_2": "" }

	var skill_1: String = available[randi() % available.size()]
	var skill_2: String = ""

	if randf() < GameData.CROSS_CLASS_CHANCE.get(rarity, 0.0):
		var cross_pool: Array = GameData.CROSS_CLASS_POOL.get(char_class, [])
		if not cross_pool.is_empty():
			skill_2 = cross_pool[randi() % cross_pool.size()]

	if skill_2 == "":
		var remaining: Array = available.filter(func(s): return s != skill_1)
		if not remaining.is_empty():
			skill_2 = remaining[randi() % remaining.size()]

	return { "skill_1": skill_1, "skill_2": skill_2 }

static func execute(
		skill_id: String,
		caster: Combatant,
		targets: Array,
		all_combatants: Array) -> void:

	var skill: Dictionary = GameData.SKILLS.get(skill_id, {})
	if skill.is_empty():
		push_warning("SkillsGeneric: skill no encontrada -> " + skill_id)
		return

	var mult: float = GameData.RARITY_POWER_MULTIPLIER.get(
			caster.character.rarity, 1.0)

	match skill.get("target", ""):
		"ST_enemy", "ST_ally", "ST_ally_self":
			if not targets.is_empty():
				_apply_to_single(skill, caster, targets[0], mult)
		"AoE_enemy", "AoE_ally":
			for t in targets:
				_apply_to_single(skill, caster, t, mult)

static func _apply_to_single(
		skill: Dictionary,
		caster: Combatant,
		target: Combatant,
		mult: float) -> void:

	if skill.has("execute_damage_base"):
		_apply_execute(skill, caster, target, mult)
		return

	if skill.has("damage_base"):
		var dmg: int = _calc_damage(skill, caster, mult)
		if skill.get("guaranteed_crit", false):
			dmg = int(dmg * skill.get("crit_multiplier", 2.0))
		if skill.get("ignores_defense", false):
			target.character.take_damage(dmg)
		else:
			target.receive_damage(dmg)

		if skill.get("hits", 1) > 1:
			for i in range(1, skill.get("hits", 1)):
				var hit_dmg: int = _calc_damage(skill, caster, mult)
				if i == 1 and skill.has("second_hit_multiplier"):
					hit_dmg = int(hit_dmg * skill["second_hit_multiplier"])
				target.receive_damage(hit_dmg)

	if skill.has("heal_base"):
		var amt: int = int(target.character.vida_max() * skill["heal_base"] * mult)
		target.character.heal(amt)

	if skill.has("shield_base"):
		var amt: int = int(target.character.vida_max() * skill["shield_base"] * mult)
		target.apply_effect("shield", 0.0, amt)

	if skill.has("revive_hp_percent") and not target.character.is_alive():
		target.character.vida_actual = int(
				target.character.vida_max() * skill["revive_hp_percent"] * mult)

	for effect in skill.get("effects", []):
		_apply_effect(effect, caster, target, mult)

static func _apply_effect(
		effect: Dictionary,
		caster: Combatant,
		target: Combatant,
		mult: float) -> void:
	var duration: float = effect.get("duration", 0.0)
	match effect.get("type", ""):
		"stun":               target.apply_effect("stun", duration)
		"taunt":              target.apply_effect("taunt", duration)
		"silence":            target.apply_effect("silence", duration)
		"mana_shield":        target.apply_effect("mana_shield", duration)
		"evasion":            target.apply_effect("evasion", duration, effect.get("value", 0.0))
		"slow_attack":        target.apply_effect("slow_attack", duration, effect.get("value", 0.0))
		"damage_reduction":   target.apply_effect("damage_reduction", duration, effect.get("value", 0.0))
		"damage_taken_increase": target.apply_effect("damage_taken_increase", duration, effect.get("value", 0.0))
		"defense_reduction":  target.apply_effect("defense_reduction", duration, effect.get("value", 0.0))
		"buff_fuerza":        target.apply_effect("buff_fuerza", duration, effect.get("value", 0.0))
		"next_crit":          target.apply_effect("next_crit", 999.0, effect.get("value", 2.0))
		"burn":
			var dps: float = effect.get("damage_per_second", 0.0) * caster.character.mana_base * mult
			target.apply_effect("burn", duration, dps)
		"poison":
			var dps: float = effect.get("damage_per_second", 0.0) * caster.character.fuerza_base * mult
			target.apply_effect("poison", duration, dps)
		"regen":
			var rps: float = target.character.vida_max() * effect.get("value", 0.0) * mult
			target.apply_effect("regen", duration, rps)
		"cooldown_reduction":
			var val: float = effect.get("value", 0.0)
			target.skill_1_timer = min(target.skill_1_timer + target.skill_1_cooldown_max * val, target.skill_1_cooldown_max)
			target.skill_2_timer = min(target.skill_2_timer + target.skill_2_cooldown_max * val, target.skill_2_cooldown_max)

static func _calc_damage(skill: Dictionary, caster: Combatant, mult: float) -> int:
	var base: float = skill.get("damage_base", 0.0)
	var stat: int = _get_primary_stat(caster, skill.get("class", "guerrero"))
	var raw: float = base * stat * mult
	if skill.get("variance", true):
		raw += raw * randf_range(-0.10, 0.10)
	return max(1, int(raw))

static func _get_primary_stat(caster: Combatant, skill_class: String) -> int:
	match skill_class:
		"mago", "sanador": return caster.character.mana_base
		"picaro", "arquero": return caster.character.suerte_base
		_: return caster.character.fuerza_base

static func _apply_execute(
		skill: Dictionary,
		caster: Combatant,
		target: Combatant,
		mult: float) -> void:
	var hp_pct: float = float(target.character.vida_actual) / float(target.character.vida_max())
	var threshold: float = skill.get("execute_threshold_boss", 0.10) \
			if target.is_boss \
			else skill.get("execute_threshold_normal", 0.30)
	var dmg_key: String = "execute_damage_base" if hp_pct <= threshold else "damage_base"
	var stat: int = _get_primary_stat(caster, skill.get("class", "picaro"))
	var dmg: int = max(1, int(skill.get(dmg_key, 1.0) * stat * mult))
	target.receive_damage(dmg)
