extends Resource
class_name Character

# ─── IDENTIDAD ────────────────────────────────────────────────────────────────
@export var id: String = ""
@export var name: String = ""
@export var rarity: String = "comun"
@export var char_class: String = "guerrero"
@export var is_unique: bool = false
@export var focus_stat: String = ""

# ─── STATS BASE (permanentes, no cambian salvo level up) ──────────────────────
@export var vida_base: int = 0
@export var fuerza_base: int = 0
@export var mana_base: int = 0
@export var suerte_base: int = 0

# ─── STATS DE COMBATE (calculadas en tiempo real, no se guardan) ──────────────
var vida_actual: int = 0
var suerte_combat: int = 0  # suerte_base + stacks de Gambler's Edge u otros buffs

# ─── PROGRESIÓN ───────────────────────────────────────────────────────────────
@export var level: int = 1
@export var xp: int = 0
@export var is_dead: bool = false  # muerte permanente

# ─── HABILIDADES ──────────────────────────────────────────────────────────────
@export var skill_1_id: String = ""
@export var skill_2_id: String = ""     # vacío hasta nivel 25
@export var passive_id: String = ""     # vacío hasta nivel 60

# ─── ATAQUE BÁSICO ────────────────────────────────────────────────────────────
@export var attack_speed_min: float = 1.2  # segundos mínimo entre ataques
@export var attack_speed_max: float = 1.2  # igual que min = velocidad fija
@export var attack_speed_uses_luck: bool = false
@export var attack_damage_formula: String = "fuerza * 0.8"
@export var attack_hit_chance: float = 0.90  # 90% base, suerte lo modifica

# ─── SERIALIZACIÓN FIREBASE ───────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"rarity": rarity,
		"char_class": char_class,
		"is_unique": is_unique,
		"focus_stat": focus_stat,
		"vida_base": vida_base,
		"fuerza_base": fuerza_base,
		"mana_base": mana_base,
		"suerte_base": suerte_base,
		"level": level,
		"xp": xp,
		"is_dead": is_dead,
		"skill_1_id": skill_1_id,
		"skill_2_id": skill_2_id,
		"passive_id": passive_id,
		"attack_speed_min": attack_speed_min,
		"attack_speed_max": attack_speed_max,
		"attack_speed_uses_luck": attack_speed_uses_luck,
	}

static func from_dict(data: Dictionary) -> Character:
	var c := Character.new()
	c.id = data.get("id", "")
	c.name = data.get("name", "")
	c.rarity = data.get("rarity", "comun")
	c.char_class = data.get("char_class", "guerrero")
	c.is_unique = data.get("is_unique", false)
	c.focus_stat = data.get("focus_stat", "")
	c.vida_base = data.get("vida_base", 1)
	c.fuerza_base = data.get("fuerza_base", 1)
	c.mana_base = data.get("mana_base", 1)
	c.suerte_base = data.get("suerte_base", 1)
	c.level = data.get("level", 1)
	c.xp = data.get("xp", 0)
	c.is_dead = data.get("is_dead", false)
	c.skill_1_id = data.get("skill_1_id", "")
	c.skill_2_id = data.get("skill_2_id", "")
	c.passive_id = data.get("passive_id", "")
	c.attack_speed_min = data.get("attack_speed_min", 1.2)
	c.attack_speed_max = data.get("attack_speed_max", 1.2)
	c.attack_speed_uses_luck = data.get("attack_speed_uses_luck", false)
	return c

func init_combat() -> void:
	vida_actual = vida_max()
	suerte_combat = suerte_base

func vida_max() -> int:
	return vida_base + (level - 1) * 3

func get_hit_chance() -> float:
	# suerte añade hasta +15% de precisión adicional (cap en 99%)
	var bonus: float = min(suerte_base / 1000.0, 0.15)
	return min(attack_hit_chance + bonus, 0.99)

func is_alive() -> bool:
	return vida_actual > 0 and not is_dead

func take_damage(amount: int) -> int:
	var real_damage: int = max(1, amount)
	vida_actual = max(0, vida_actual - real_damage)
	return real_damage

func heal(amount: int) -> int:
	var real_heal: int = min(amount, vida_max() - vida_actual)
	vida_actual += real_heal
	return real_heal

func add_xp(amount: int) -> bool:
	xp += amount
	var leveled_up: bool = false
	while xp >= GameData.get_xp_for_level(level):
		xp -= GameData.get_xp_for_level(level)
		level += 1
		leveled_up = true
	return leveled_up
