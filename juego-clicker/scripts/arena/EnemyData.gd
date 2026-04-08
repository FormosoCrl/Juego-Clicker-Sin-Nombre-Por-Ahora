extends Node

# ─── ESTRUCTURA DE UN ENEMIGO ─────────────────────────────────────────────────
# {
#   "id": String,
#   "name": String,
#   "class": String,
#   "vida": int,
#   "fuerza": int,
#   "mana": int,
#   "suerte": int,
#   "attack_speed": float,
#   "hit_chance": float,
#   "skill_1_id": String,   # vacío si no tiene
#   "skill_2_id": String,
#   "is_boss": bool,
#   "xp_reward": int,
# }

# ─── CAPÍTULO 1 ───────────────────────────────────────────────────────────────

const CHAPTER_1 = {
	"level_1": [
		{
			"id": "goblin_1",
			"name": "Goblin",
			"class": "picaro",
			"vida": 40,
			"fuerza": 8,
			"mana": 0,
			"suerte": 10,
			"attack_speed": 1.2,
			"hit_chance": 0.80,
			"skill_1_id": "",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 15,
		},
		{
			"id": "goblin_2",
			"name": "Goblin Arquero",
			"class": "arquero",
			"vida": 30,
			"fuerza": 10,
			"mana": 0,
			"suerte": 15,
			"attack_speed": 1.0,
			"hit_chance": 0.85,
			"skill_1_id": "",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 15,
		},
		{
			"id": "goblin_3",
			"name": "Goblin Bruto",
			"class": "guerrero",
			"vida": 60,
			"fuerza": 12,
			"mana": 0,
			"suerte": 5,
			"attack_speed": 2.0,
			"hit_chance": 0.75,
			"skill_1_id": "",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 20,
		},
	],
	"level_2": [
		{
			"id": "orc_1",
			"name": "Orco",
			"class": "guerrero",
			"vida": 80,
			"fuerza": 15,
			"mana": 0,
			"suerte": 5,
			"attack_speed": 2.2,
			"hit_chance": 0.78,
			"skill_1_id": "shield_bash",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 25,
		},
		{
			"id": "orc_2",
			"name": "Orco Chamán",
			"class": "mago",
			"vida": 50,
			"fuerza": 8,
			"mana": 20,
			"suerte": 10,
			"attack_speed": 2.5,
			"hit_chance": 0.82,
			"skill_1_id": "fireball",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 30,
		},
		{
			"id": "orc_3",
			"name": "Orco Explorador",
			"class": "arquero",
			"vida": 45,
			"fuerza": 14,
			"mana": 0,
			"suerte": 18,
			"attack_speed": 1.1,
			"hit_chance": 0.88,
			"skill_1_id": "crippling_arrow",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 25,
		},
	],
	"boss": [
		{
			"id": "chapter1_boss",
			"name": "Jefe de la Horda",
			"class": "guerrero",
			"vida": 400,
			"fuerza": 25,
			"mana": 10,
			"suerte": 10,
			"attack_speed": 1.8,
			"hit_chance": 0.88,
			"skill_1_id": "war_cry",
			"skill_2_id": "provoke",
			"is_boss": true,
			"xp_reward": 100,
		},
	],
}

# ─── CAPÍTULO 2 (placeholder) ─────────────────────────────────────────────────

const CHAPTER_2 = {
	"level_1": [
		{
			"id": "skeleton_1",
			"name": "Esqueleto",
			"class": "guerrero",
			"vida": 70,
			"fuerza": 18,
			"mana": 0,
			"suerte": 8,
			"attack_speed": 1.6,
			"hit_chance": 0.80,
			"skill_1_id": "",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 30,
		},
		{
			"id": "skeleton_2",
			"name": "Arquero Esqueleto",
			"class": "arquero",
			"vida": 55,
			"fuerza": 20,
			"mana": 0,
			"suerte": 20,
			"attack_speed": 1.0,
			"hit_chance": 0.88,
			"skill_1_id": "double_shot",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 30,
		},
		{
			"id": "necromancer_1",
			"name": "Necromántico",
			"class": "mago",
			"vida": 60,
			"fuerza": 10,
			"mana": 35,
			"suerte": 12,
			"attack_speed": 2.8,
			"hit_chance": 0.84,
			"skill_1_id": "arcane_bolt",
			"skill_2_id": "frost_nova",
			"is_boss": false,
			"xp_reward": 35,
		},
	],
	"level_2": [
		{
			"id": "skeleton_knight",
			"name": "Caballero Esqueleto",
			"class": "guerrero",
			"vida": 120,
			"fuerza": 22,
			"mana": 0,
			"suerte": 8,
			"attack_speed": 1.9,
			"hit_chance": 0.82,
			"skill_1_id": "iron_skin",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 40,
		},
		{
			"id": "banshee",
			"name": "Fantasma",
			"class": "mago",
			"vida": 65,
			"fuerza": 12,
			"mana": 40,
			"suerte": 25,
			"attack_speed": 1.4,
			"hit_chance": 0.86,
			"skill_1_id": "arcane_storm",
			"skill_2_id": "",
			"is_boss": false,
			"xp_reward": 40,
		},
	],
	"boss": [
		{
			"id": "chapter2_boss",
			"name": "El Rey Liche",
			"class": "mago",
			"vida": 700,
			"fuerza": 20,
			"mana": 60,
			"suerte": 20,
			"attack_speed": 2.0,
			"hit_chance": 0.90,
			"skill_1_id": "blizzard",
			"skill_2_id": "arcane_storm",
			"is_boss": true,
			"xp_reward": 200,
		},
	],
}

# ─── ACCESO POR CAPÍTULO Y NIVEL ──────────────────────────────────────────────

const ALL_CHAPTERS = [CHAPTER_1, CHAPTER_2]

static func get_enemies(chapter: int, level: int) -> Array:
	if chapter < 1 or chapter > ALL_CHAPTERS.size():
		push_error("EnemyData: capítulo %d no existe" % chapter)
		return []
	var chapter_data: Dictionary = ALL_CHAPTERS[chapter - 1]
	match level:
		1: return chapter_data.get("level_1", [])
		2: return chapter_data.get("level_2", [])
		3: return chapter_data.get("boss", [])
		_:
			push_error("EnemyData: nivel %d no existe" % level)
			return []

static func is_boss_level(level: int) -> bool:
	return level == 3
