extends Node
const SkillsGeneric = preload("res://scripts/arena/SkillsGeneric.gd")

# Punto de entrada único — el CombatManager llama esto
static func execute(
		skill_id: String,
		caster: Combatant,
		targets: Array,
		all_combatants: Array) -> void:
	match skill_id:
		"luck_barrage":      _luck_barrage(caster, targets)
		"overwhelming_luck": _overwhelming_luck(caster, all_combatants)
		_:
			SkillsGeneric.execute(skill_id, caster, targets, all_combatants)

# ─── LUCKAS ───────────────────────────────────────────────────────────────────

static func _luck_barrage(caster: Combatant, targets: Array) -> void:
	if targets.is_empty():
		return

	var suerte: int = caster.character.suerte_combat
	var target: Combatant = targets[0]  # single target

	# Número de golpes
	var base_hits: int = int(floor(suerte / 60.0))
	var hits: int

	if caster.next_barrage_max:
		hits = 8
		caster.next_barrage_max = false
	else:
		hits = clamp(base_hits + randi_range(-1, 2), 4, 8)

	# Ejecutar cada golpe
	var hit_count: int = 0
	for i in range(hits):
		var hit_roll: float = randf()
		# Luck Barrage tiene su propia precisión mejorada por suerte
		var hit_chance: float = min(0.75 + suerte / 1200.0, 0.95)
		if hit_roll <= hit_chance:
			var damage: int = _luck_barrage_damage(caster)
			target.receive_damage(damage)
			hit_count += 1
			if not target.character.is_alive():
				break

	# Contador global para desbloquear Overwhelming Luck
	caster.luck_barrage_hits_total += hit_count

	# Pasiva Gambler's Edge: si sacó el máximo posible en esta tirada
	var max_possible: int = clamp(base_hits + 2, 4, 8)
	if hits == max_possible and not caster.next_barrage_max:
		caster.character.suerte_combat += 5

static func _luck_barrage_damage(caster: Combatant) -> int:
	var suerte: int = caster.character.suerte_combat
	var fuerza: int = caster.character.fuerza_base
	var base: float = fuerza * 0.4 + suerte * 0.15
	var variance: float = base * 0.12
	return max(1, int(base + randf_range(-variance, variance)))

static func _overwhelming_luck(caster: Combatant, all_combatants: Array) -> void:
	# Requiere al menos 12 golpes acumulados con Luck Barrage
	if caster.luck_barrage_hits_total < 12:
		# Devolvemos el cooldown — la habilidad no se consume si no hay condición
		caster.skill_2_ready = false
		caster.skill_2_timer = 0.0
		# Notificar al CombatManager para mostrar mensaje en UI
		return

	var suerte: int = caster.character.suerte_combat

	# Duración: 2 turnos base + 1 por cada 130 de suerte
	# En tiempo real usamos segundos: cada "turno" equivale a ~3 segundos
	var duration_ticks: int = 2 + int(suerte / 130.0)
	var duration_seconds: float = duration_ticks * 3.0

	# Inmunidad total
	caster.apply_effect("invulnerable", duration_seconds)
	caster.overwhelmed_active = true

	# Regeneración: 15% vida máxima por "turno" = por cada 3 segundos
	# Lo convertimos a HP/segundo para el procesador de efectos
	var regen_per_second: float = (caster.character.vida_max() * 0.15) / 3.0
	caster.apply_effect("regen", duration_seconds, regen_per_second)

	# Al salir de Overwhelmed el siguiente Barrage será máximo
	# Esto lo marcamos ahora, el efecto "invulnerable" al expirar
	# activa next_barrage_max en _process_effects de Combatant
	caster.next_barrage_max = true
