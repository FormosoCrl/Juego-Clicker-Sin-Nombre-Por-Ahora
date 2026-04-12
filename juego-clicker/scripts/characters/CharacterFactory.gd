extends Node

const UniqueCharacters = preload("res://scripts/characters/UniqueCharacters.gd")
const SkillsGeneric = preload("res://scripts/arena/SkillsGeneric.gd")
# ─── POOL DE NOMBRES PROCEDURALES ────────────────────────────────────────────

const NAME_PREFIXES = [
	"Zar", "Mal", "Dra", "Vel", "Kor", "Ash", "Bran", "Sel",
	"Tor", "Fen", "Gar", "Lyr", "Mor", "Nyx", "Ral", "Thal",
	"Ven", "Wyr", "Xan", "Zep", "Aer", "Bel", "Cal", "Dex",
]

const NAME_ROOTS = [
	"ak", "on", "ix", "en", "ar", "el", "or", "an",
	"is", "us", "as", "eth", "ath", "ith", "oth", "un",
	"in", "ek", "ok", "ul", "al", "il", "ol", "ur",
]

const NAME_SUFFIXES = [
	"", "", "",                          # sin sufijo más probable
	"ion", "ius", "ara", "iel", "orn",
	"ash", "ek", "on", "ar", "is",
]

const CLASS_TITLES = {
	"guerrero": ["el Implacable", "el Férreo", "el Colosal", "Rompemuros", "el Invicto"],
	"mago":     ["el Arcano", "de las Llamas", "del Abismo", "el Sabio", "el Etéreo"],
	"picaro":   ["el Veloz", "Sombra", "el Esquivo", "el Furtivo", "Daga Rota"],
	"sanador":  ["la Luz", "el Piadoso", "el Sereno", "el Bendito", "Manos Cálidas"],
	"arquero":  ["Ojo Certero", "el Preciso", "del Bosque", "la Flecha", "el Cazador"],
}

# ─── GENERACIÓN DE NOMBRE ─────────────────────────────────────────────────────

static func generate_name(char_class: String, rarity: String) -> String:
	var prefix: String = NAME_PREFIXES[randi() % NAME_PREFIXES.size()]
	var root: String = NAME_ROOTS[randi() % NAME_ROOTS.size()]
	var suffix: String = NAME_SUFFIXES[randi() % NAME_SUFFIXES.size()]
	var base_name: String = prefix + root + suffix

	# Rarezas altas tienen título de clase
	if rarity in ["epico", "mitico"]:
		var titles: Array = CLASS_TITLES.get(char_class, [])
		if not titles.is_empty():
			base_name += " " + titles[randi() % titles.size()]

	return base_name

# ─── GENERACIÓN DE ID ÚNICO ───────────────────────────────────────────────────

static func generate_id() -> String:
	# ID simple basado en tiempo + random, suficiente hasta tener Firebase
	var time: int = Time.get_ticks_msec()
	var rand: int = randi() % 99999
	return "char_%d_%05d" % [time, rand]

# ─── FACTORY PRINCIPAL ────────────────────────────────────────────────────────

static func create_procedural(rarity: String = "") -> Character:
	# Si no se especifica rareza, tirar gacha
	if rarity == "":
		rarity = GameData.roll_rarity(0)

	var char_class: String = GameData.CLASSES[randi() % GameData.CLASSES.size()]
	var stats: Dictionary = GameData.calculate_stats(rarity, char_class)
	var skills: Dictionary = SkillsGeneric.assign_skills(char_class, rarity)

	var c := Character.new()
	c.id = generate_id()
	c.name = generate_name(char_class, rarity)
	c.rarity = rarity
	c.char_class = char_class
	c.is_unique = false
	c.focus_stat = stats.get("focus_stat", "")
	c.vida_base = stats["vida"]
	c.fuerza_base = stats["fuerza"]
	c.mana_base = stats["mana"]
	c.suerte_base = stats["suerte"]
	c.skill_1_id = skills["skill_1"]
	c.skill_2_id = skills.get("skill_2", "")
	c.passive_id = GameData.CLASS_PASSIVE.get(char_class, "")
	c.attack_speed_min = _get_attack_speed(char_class)
	c.attack_speed_max = _get_attack_speed(char_class) + 0.4
	c.attack_hit_chance = _get_hit_chance(char_class, stats)
	return c

static func create_unique(character_id: String) -> Character:
	return UniqueCharacters.create(character_id)

# ─── HELPERS INTERNOS ─────────────────────────────────────────────────────────

static func _get_attack_speed(char_class: String) -> float:
	match char_class:
		"guerrero": return 1.8   # lento pero pega fuerte
		"mago":     return 2.2   # muy lento, depende de habilidades
		"picaro":   return 0.9   # rápido
		"sanador":  return 1.6   # moderado
		"arquero":  return 1.1   # rápido-moderado
		_:          return 1.5

static func _get_hit_chance(char_class: String, stats: Dictionary) -> float:
	var base: float
	match char_class:
		"guerrero": base = 0.88
		"mago":     base = 0.92   # preciso pero lento
		"picaro":   base = 0.85   # compensa con velocidad
		"sanador":  base = 0.90
		"arquero":  base = 0.87
		_:          base = 0.88
	# suerte añade hasta +8% de precisión
	var luck_bonus: float = min(stats.get("suerte", 0) / 1000.0, 0.08)
	return min(base + luck_bonus, 0.97)
