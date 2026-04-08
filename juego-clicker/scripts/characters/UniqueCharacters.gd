extends Node

const UNIQUE_ROSTER = {
	"luckas": {
		"name": "Luckas",
		"rarity": "milagro",
		"char_class": "picaro",
		"lore": "La suerte no es aleatoria si siempre cae de tu lado.",
		"stats": { "vida": 45, "fuerza": 30, "mana": 20, "suerte": 265 },
		"attack_speed_min": 0.8,
		"attack_speed_max": 2.2,
		"attack_speed_uses_luck": true,
		"attack_hit_chance": 0.82,
		"skill_1_id": "luck_barrage",
		"skill_2_id": "overwhelming_luck",
		"passive_id": "gamblers_edge",
	},
	# Aquí irán el resto de únicos cuando los diseñemos
}

static func create(character_id: String) -> Character:
	var data: Dictionary = UNIQUE_ROSTER.get(character_id, {})
	if data.is_empty():
		push_error("UniqueCharacters: no encontrado -> " + character_id)
		return null

	var c := Character.new()
	c.id = character_id
	c.name = data["name"]
	c.rarity = data["rarity"]
	c.char_class = data["char_class"]
	c.is_unique = true
	c.vida_base = data["stats"]["vida"]
	c.fuerza_base = data["stats"]["fuerza"]
	c.mana_base = data["stats"]["mana"]
	c.suerte_base = data["stats"]["suerte"]
	c.attack_speed_min = data.get("attack_speed_min", 1.2)
	c.attack_speed_max = data.get("attack_speed_max", 1.2)
	c.attack_speed_uses_luck = data.get("attack_speed_uses_luck", false)
	c.attack_hit_chance = data.get("attack_hit_chance", 0.90)
	c.skill_1_id = data.get("skill_1_id", "")
	c.skill_2_id = data.get("skill_2_id", "")
	c.passive_id = data.get("passive_id", "")
	return c

static func is_unique(character_id: String) -> bool:
	return UNIQUE_ROSTER.has(character_id)

static func get_all_ids() -> Array:
	return UNIQUE_ROSTER.keys()
