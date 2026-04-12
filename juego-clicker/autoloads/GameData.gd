extends Node

# ─── GACHA ────────────────────────────────────────────────────────────────────

const GACHA_RARITIES = {
	"comun":      { "weight": 5500, "pool_size": 1500 },
	"especial":   { "weight": 2200, "pool_size": 1000 },
	"raro":       { "weight": 1100, "pool_size": 800  },
	"epico":      { "weight": 700,  "pool_size": 600  },
	"mitico":     { "weight": 300,  "pool_size": 400  },
	"legendario": { "weight": 150,  "pool_size": 200  },
	"milagro":    { "weight": 50,   "pool_size": 50   },
}

const GACHA_TOTAL_WEIGHT: int = 10000
const PITY_LEGENDARIO: int = 200
const GACHA_COST_SINGLE: int = 800
const GACHA_COST_MULTI:  int = 7200

const RARITY_POWER_MULTIPLIER = {
	"comun":      0.70,
	"especial":   0.85,
	"raro":       1.00,
	"epico":      1.20,
	"mitico":     1.40,
	"legendario": 1.65,
	"milagro":    2.00,
}

# Subir puntos base por rareza — la vida escala mucho más
const RARITY_BASE_POINTS = {
	"comun":      300,   # antes 100
	"especial":   400,   # antes 130
	"raro":       520,   # antes 165
	"epico":      650,   # antes 205
	"mitico":     820,   # antes 250
	"legendario": 1000,  # antes 300
	"milagro":    1200,  # antes 360
}

const SKILL_TIER_MIN_RARITY = {
	1: ["comun", "especial", "raro", "epico", "mitico", "legendario", "milagro"],
	2: ["raro", "epico", "mitico", "legendario", "milagro"],
	3: ["epico", "mitico", "legendario", "milagro"],
}

const CROSS_CLASS_CHANCE = {
	"comun":      0.01,
	"especial":   0.10,
	"raro":       0.20,
	"epico":      0.30,
	"mitico":     0.00,
	"legendario": 0.00,
	"milagro":    0.00,
}

const CROSS_CLASS_POOL = {
	"guerrero": ["mana_shield", "barrier", "double_strike", "iron_skin"],
	"mago":     ["heal", "frost_nova", "eagle_eye", "smoke_screen"],
	"picaro":   ["arcane_bolt", "crippling_arrow", "poison_blade", "shadow_step"],
	"sanador":  ["iron_skin", "barrier", "frost_nova", "renew"],
	"arquero":  ["smoke_screen", "poison_blade", "frost_nova", "crippling_arrow"],
}

# ─── CLASES Y STATS ───────────────────────────────────────────────────────────

const CLASSES = ["guerrero", "mago", "picaro", "sanador", "arquero"]

const CLASS_STAT_WEIGHTS = {
	"guerrero": { "vida": 0.55, "fuerza": 0.25, "mana": 0.10, "suerte": 0.10 },
	"mago":     { "vida": 0.30, "fuerza": 0.08, "mana": 0.45, "suerte": 0.17 },
	"picaro":   { "vida": 0.30, "fuerza": 0.28, "mana": 0.08, "suerte": 0.34 },
	"sanador":  { "vida": 0.35, "fuerza": 0.05, "mana": 0.38, "suerte": 0.22 },
	"arquero":  { "vida": 0.30, "fuerza": 0.28, "mana": 0.08, "suerte": 0.34 },
}

const RARITY_MAX_FOCUS = {
	"comun":      0.10,
	"especial":   0.15,
	"raro":       0.22,
	"epico":      0.30,
	"mitico":     0.42,
	"legendario": 0.50,
	"milagro":    0.55,
}

# ─── SKILLS (datos puros) ─────────────────────────────────────────────────────

const SKILLS = {
	"shield_bash":      { "name": "Shield Bash",      "tier": 1, "class": "guerrero", "target": "ST_enemy",    "cooldown": 4.0,  "mana_cost": 0,   "damage_base": 1.2, "effects": [{ "type": "stun", "duration": 1.5 }] },
	"war_cry":          { "name": "War Cry",           "tier": 1, "class": "guerrero", "target": "AoE_ally",    "cooldown": 12.0, "mana_cost": 0,   "effects": [{ "type": "buff_fuerza", "value": 0.10, "duration": 6.0 }] },
	"provoke":          { "name": "Provoke",           "tier": 1, "class": "guerrero", "target": "AoE_enemy",   "cooldown": 10.0, "mana_cost": 0,   "effects": [{ "type": "taunt", "duration": 4.0 }] },
	"iron_skin":        { "name": "Iron Skin",         "tier": 2, "class": "guerrero", "target": "ST_ally_self","cooldown": 14.0, "mana_cost": 0,   "effects": [{ "type": "damage_reduction", "value": 0.30, "duration": 6.0 }] },
	"battle_roar":      { "name": "Battle Roar",       "tier": 2, "class": "guerrero", "target": "AoE_ally",    "cooldown": 16.0, "mana_cost": 0,   "heal_base": 0.10, "effects": [{ "type": "buff_fuerza", "value": 0.20, "duration": 8.0 }] },
	"colossus_smash":   { "name": "Colossus Smash",    "tier": 2, "class": "guerrero", "target": "ST_enemy",    "cooldown": 12.0, "mana_cost": 0,   "damage_base": 2.0, "effects": [{ "type": "defense_reduction", "value": 0.30, "duration": 5.0 }] },
	"unbreakable":      { "name": "Unbreakable",       "tier": 3, "class": "guerrero", "target": "ST_ally_self","cooldown": 22.0, "mana_cost": 0,   "effects": [{ "type": "damage_reduction", "value": 0.60, "duration": 8.0 }, { "type": "regen", "value": 0.05, "duration": 8.0 }] },
	"earthquake":       { "name": "Earthquake",        "tier": 3, "class": "guerrero", "target": "AoE_enemy",   "cooldown": 25.0, "mana_cost": 0,   "damage_base": 1.5, "effects": [{ "type": "stun", "duration": 2.0 }] },
	"arcane_bolt":      { "name": "Arcane Bolt",       "tier": 1, "class": "mago",     "target": "ST_enemy",    "cooldown": 5.0,  "mana_cost": 20,  "damage_base": 1.8, "variance": false },
	"frost_nova":       { "name": "Frost Nova",        "tier": 1, "class": "mago",     "target": "AoE_enemy",   "cooldown": 10.0, "mana_cost": 25,  "damage_base": 0.6, "effects": [{ "type": "slow_attack", "value": 0.40, "duration": 4.0 }] },
	"fireball":         { "name": "Fireball",          "tier": 1, "class": "mago",     "target": "AoE_enemy",   "cooldown": 8.0,  "mana_cost": 30,  "damage_base": 1.0, "effects": [{ "type": "burn", "damage_per_second": 0.3, "duration": 3.0 }] },
	"mana_shield":      { "name": "Mana Shield",       "tier": 2, "class": "mago",     "target": "ST_ally_self","cooldown": 16.0, "mana_cost": 40,  "effects": [{ "type": "mana_shield", "duration": 6.0 }] },
	"blizzard":         { "name": "Blizzard",          "tier": 2, "class": "mago",     "target": "AoE_enemy",   "cooldown": 18.0, "mana_cost": 45,  "damage_per_second": 0.8, "duration": 4.0, "effects": [{ "type": "slow_attack", "value": 0.25, "duration": 4.0 }] },
	"meteor":           { "name": "Meteor",            "tier": 2, "class": "mago",     "target": "ST_enemy",    "cooldown": 20.0, "mana_cost": 50,  "cast_time": 2.0, "damage_base": 4.0 },
	"arcane_storm":     { "name": "Arcane Storm",      "tier": 3, "class": "mago",     "target": "AoE_enemy",   "cooldown": 28.0, "mana_cost": 70,  "damage_base": 2.5, "effects": [{ "type": "silence", "duration": 4.0 }] },
	"time_warp":        { "name": "Time Warp",         "tier": 3, "class": "mago",     "target": "AoE_ally",    "cooldown": 35.0, "mana_cost": 80,  "effects": [{ "type": "cooldown_reduction", "value": 0.30, "duration": 4.0 }] },
	"double_strike":    { "name": "Double Strike",     "tier": 1, "class": "picaro",   "target": "ST_enemy",    "cooldown": 5.0,  "mana_cost": 0,   "hits": 2, "damage_base": 0.9 },
	"poison_blade":     { "name": "Poison Blade",      "tier": 1, "class": "picaro",   "target": "ST_enemy",    "cooldown": 8.0,  "mana_cost": 0,   "damage_base": 0.8, "effects": [{ "type": "poison", "damage_per_second": 0.4, "duration": 4.0 }] },
	"backstab":         { "name": "Backstab",          "tier": 1, "class": "picaro",   "target": "ST_enemy",    "cooldown": 7.0,  "mana_cost": 0,   "damage_base": 1.0, "crit_multiplier": 2.0, "guaranteed_crit": true },
	"smoke_screen":     { "name": "Smoke Screen",      "tier": 2, "class": "picaro",   "target": "ST_ally_self","cooldown": 14.0, "mana_cost": 0,   "effects": [{ "type": "evasion", "value": 0.50, "duration": 5.0 }] },
	"shadow_step":      { "name": "Shadow Step",       "tier": 2, "class": "picaro",   "target": "ST_enemy",    "cooldown": 12.0, "mana_cost": 0,   "damage_base": 2.2, "ignores_defense": true, "effects": [{ "type": "evasion", "value": 1.0, "duration": 0.8 }] },
	"cripple":          { "name": "Cripple",           "tier": 2, "class": "picaro",   "target": "ST_enemy",    "cooldown": 13.0, "mana_cost": 0,   "damage_base": 0.6, "effects": [{ "type": "slow_attack", "value": 0.60, "duration": 6.0 }, { "type": "poison", "damage_per_second": 0.3, "duration": 6.0 }] },
	"death_mark":       { "name": "Death Mark",        "tier": 3, "class": "picaro",   "target": "ST_enemy",    "cooldown": 20.0, "mana_cost": 0,   "effects": [{ "type": "damage_taken_increase", "value": 0.40, "duration": 8.0 }] },
	"assassinate":      { "name": "Assassinate",       "tier": 3, "class": "picaro",   "target": "ST_enemy",    "cooldown": 25.0, "mana_cost": 0,   "damage_base": 2.5, "execute_damage_base": 8.0, "execute_threshold_normal": 0.30, "execute_threshold_boss": 0.10 },
	"heal":             { "name": "Heal",              "tier": 1, "class": "sanador",  "target": "ST_ally",     "cooldown": 6.0,  "mana_cost": 25,  "heal_base": 0.20 },
	"barrier":          { "name": "Barrier",           "tier": 1, "class": "sanador",  "target": "ST_ally",     "cooldown": 8.0,  "mana_cost": 20,  "shield_base": 0.15 },
	"group_heal":       { "name": "Group Heal",        "tier": 1, "class": "sanador",  "target": "AoE_ally",    "cooldown": 12.0, "mana_cost": 40,  "heal_base": 0.08 },
	"renew":            { "name": "Renew",             "tier": 2, "class": "sanador",  "target": "ST_ally",     "cooldown": 10.0, "mana_cost": 30,  "effects": [{ "type": "regen", "value": 0.06, "duration": 6.0 }] },
	"group_barrier":    { "name": "Group Barrier",     "tier": 2, "class": "sanador",  "target": "AoE_ally",    "cooldown": 18.0, "mana_cost": 50,  "shield_base": 0.08 },
	"greater_heal":     { "name": "Greater Heal",      "tier": 2, "class": "sanador",  "target": "ST_ally",     "cooldown": 14.0, "mana_cost": 45,  "heal_base": 0.45 },
	"revive":           { "name": "Revive",            "tier": 3, "class": "sanador",  "target": "ST_ally",     "cooldown": 45.0, "mana_cost": 120, "revive_hp_percent": 0.25 },
	"divine_hymn":      { "name": "Divine Hymn",       "tier": 3, "class": "sanador",  "target": "AoE_ally",    "cooldown": 30.0, "mana_cost": 80,  "heal_base": 0.30, "effects": [{ "type": "regen", "value": 0.04, "duration": 5.0 }] },
	"crippling_arrow":  { "name": "Crippling Arrow",   "tier": 1, "class": "arquero",  "target": "ST_enemy",    "cooldown": 7.0,  "mana_cost": 0,   "damage_base": 0.7, "effects": [{ "type": "slow_attack", "value": 0.35, "duration": 5.0 }] },
	"double_shot":      { "name": "Double Shot",       "tier": 1, "class": "arquero",  "target": "ST_enemy",    "cooldown": 5.0,  "mana_cost": 0,   "hits": 2, "damage_base": 0.85, "second_hit_multiplier": 0.60 },
	"eagle_eye":        { "name": "Eagle Eye",         "tier": 1, "class": "arquero",  "target": "ST_ally_self","cooldown": 8.0,  "mana_cost": 0,   "effects": [{ "type": "next_crit", "value": 2.0 }] },
	"rain_of_arrows":   { "name": "Rain of Arrows",    "tier": 2, "class": "arquero",  "target": "AoE_enemy",   "cooldown": 14.0, "mana_cost": 0,   "damage_base": 0.9 },
	"piercing_shot":    { "name": "Piercing Shot",     "tier": 2, "class": "arquero",  "target": "AoE_enemy",   "cooldown": 12.0, "mana_cost": 0,   "damage_base": 1.4, "piercing": true },
	"volley":           { "name": "Volley",            "tier": 2, "class": "arquero",  "target": "AoE_enemy",   "cooldown": 15.0, "mana_cost": 0,   "hits": 3, "damage_base": 0.75, "random_targets": true },
	"marked_for_death": { "name": "Marked for Death",  "tier": 3, "class": "arquero",  "target": "ST_enemy",    "cooldown": 22.0, "mana_cost": 0,   "effects": [{ "type": "damage_taken_increase", "value": 0.50, "duration": 6.0 }] },
	"snipe":            { "name": "Snipe",             "tier": 3, "class": "arquero",  "target": "ST_enemy",    "cooldown": 28.0, "mana_cost": 0,   "cast_time": 2.0, "damage_base": 5.0, "ignores_evasion": true },
	"luck_barrage":     { "name": "Luck Barrage",      "tier": 3, "class": "picaro",   "target": "ST_enemy",    "cooldown": 3.0,  "mana_cost": 0,   "unique": true },
	"overwhelming_luck":{ "name": "Overwhelming Luck", "tier": 3, "class": "picaro",   "target": "ST_ally_self","cooldown": 6.0,  "mana_cost": 0,   "unique": true, "requires_barrage_hits": 12 },
}

# ─── PROGRESIÓN ───────────────────────────────────────────────────────────────

const LEVEL_XP_BASE: int = 100
const LEVEL_XP_SCALE: float = 1.35
const UNLOCK_STAT_SECONDARY: int = 15
const UNLOCK_SKILL_2: int = 25
const UNLOCK_SKILL_1_UPGRADE: int = 40
const UNLOCK_CLASS_PASSIVE: int = 60

# Stat secundaria que se potencia al llegar a nivel 15
const CLASS_SECONDARY_STAT = {
	"guerrero": "fuerza",
	"mago":     "suerte",
	"picaro":   "fuerza",
	"sanador":  "mana",
	"arquero":  "fuerza",
}
const SECONDARY_STAT_BONUS: float = 0.15  # +15% del stat secundario en combate

# Pasivas de clase: se activan al llegar a nivel 60
const CLASS_PASSIVE = {
	"guerrero": "iron_will",
	"mago":     "arcane_mastery",
	"picaro":   "lethal_precision",
	"sanador":  "blessed_aura",
	"arquero":  "keen_eye",
}

const PASSIVES = {
	"iron_will":        { "name": "Voluntad de Hierro", "class": "guerrero", "vida_bonus_pct":   0.20 },
	"arcane_mastery":   { "name": "Maestría Arcana",    "class": "mago",     "skill_damage_mult": 0.20 },
	"lethal_precision": { "name": "Precisión Letal",    "class": "picaro",   "hit_bonus": 0.15, "damage_bonus_pct": 0.10 },
	"blessed_aura":     { "name": "Aura Bendita",       "class": "sanador",  "regen_pct": 0.03, "regen_duration": 999.0 },
	"keen_eye":         { "name": "Ojo Agudo",          "class": "arquero",  "damage_bonus_pct": 0.10, "crit_chance": 0.20 },
}

# ─── ENERGÍA ──────────────────────────────────────────────────────────────────

const ENERGY_BASE_MAX: int = 60
const ENERGY_REGEN_SECONDS: int = 300
const ENERGY_COST_NEW_LEVEL: int = 10
const ENERGY_COST_OLD_LEVEL: int = 5
const ENERGY_COST_BOSS_BASE: int = 15
const ENERGY_PER_CHAPTER: int = 2
const WEEKLY_REPLAY_LIMIT: int = 5
const XP_DECAY_TABLE: Array = [1.0, 0.70, 0.40, 0.15, 0.0]

# ─── CLICKER ──────────────────────────────────────────────────────────────────

const CLICK_BASE_VALUE: int = 1
const CLICK_BATCH_SIZE: int = 20
const CLICK_MAX_PER_SECOND: int = 15
const REBIRTH_BASE_THRESHOLD: int = 10_000
const REBIRTH_SCALE: float = 2.5
const REBIRTH_MULTIPLIER_PER: float = 1.5

# ─── ARENA ────────────────────────────────────────────────────────────────────

const MAX_TEAM_SIZE: int = 5
const ENEMY_HP_BASE: int = 80
const ENEMY_HP_SCALE: float = 1.4
const ENEMY_DMG_BASE: int = 10
const ENEMY_DMG_SCALE: float = 1.35

# ─── FUNCIONES PURAS ──────────────────────────────────────────────────────────

func get_xp_for_level(level: int) -> int:
	return int(LEVEL_XP_BASE * pow(LEVEL_XP_SCALE, level - 1))

func get_rebirth_threshold(rebirth_count: int) -> int:
	return int(REBIRTH_BASE_THRESHOLD * pow(REBIRTH_SCALE, rebirth_count))

func get_energy_cost_new(chapter: int) -> int:
	return ENERGY_COST_NEW_LEVEL + (chapter * ENERGY_PER_CHAPTER)

func get_energy_max_for_bosses(bosses_cleared: int) -> int:
	var bonus: int = 0
	for i in range(bosses_cleared):
		bonus += ENERGY_COST_BOSS_BASE + (i * ENERGY_PER_CHAPTER)
	return ENERGY_BASE_MAX + bonus

func roll_rarity(pity_legendario: int) -> String:
	if pity_legendario >= PITY_LEGENDARIO:
		return "legendario"
	var roll: int = randi() % GACHA_TOTAL_WEIGHT
	var accumulated: int = 0
	for rarity in GACHA_RARITIES:
		accumulated += GACHA_RARITIES[rarity]["weight"]
		if roll < accumulated:
			return rarity
	return "comun"

func calculate_stats(rarity: String, char_class: String) -> Dictionary:
	var total: int = RARITY_BASE_POINTS.get(rarity, 100)
	var weights: Dictionary = CLASS_STAT_WEIGHTS.get(
			char_class, CLASS_STAT_WEIGHTS["guerrero"]).duplicate()
	var stat_names: Array = weights.keys()
	var focus_stat: String = stat_names[randi() % stat_names.size()]
	var max_focus: float = RARITY_MAX_FOCUS.get(rarity, 0.10)
	var focus_amount: float = randf() * max_focus
	var steal_per_stat: float = focus_amount / (stat_names.size() - 1)
	for stat in stat_names:
		if stat == focus_stat:
			weights[stat] += focus_amount
		else:
			weights[stat] = max(0.02, weights[stat] - steal_per_stat)
	var total_weight: float = 0.0
	for stat in weights:
		total_weight += weights[stat]
	for stat in weights:
		weights[stat] /= total_weight
	return {
		"vida":       max(1, int(total * weights["vida"])),
		"fuerza":     max(1, int(total * weights["fuerza"])),
		"mana":       max(1, int(total * weights["mana"])),
		"suerte":     max(1, int(total * weights["suerte"])),
		"focus_stat": focus_stat,
	}
