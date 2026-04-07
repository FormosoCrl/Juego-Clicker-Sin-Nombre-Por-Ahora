extends Node

# ─── GACHA ───────────────────────────────────────────────────────────────────

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

const PITY_LEGENDARIO: int = 80
const PITY_MILAGRO:    int = 160

const GACHA_COST_SINGLE: int = 100
const GACHA_COST_MULTI:  int = 900


# ─── CLASES ───────────────────────────────────────────────────────────────────

const CLASSES = ["guerrero", "mago", "picaro", "sanador", "arquero"]

const CLASS_STAT_WEIGHTS = {
	"guerrero": { "vida": 0.45, "fuerza": 0.35, "mana": 0.10, "suerte": 0.10 },
	"mago":     { "vida": 0.20, "fuerza": 0.10, "mana": 0.50, "suerte": 0.20 },
	"picaro":   { "vida": 0.20, "fuerza": 0.30, "mana": 0.10, "suerte": 0.40 },
	"sanador":  { "vida": 0.25, "fuerza": 0.05, "mana": 0.40, "suerte": 0.30 },
	"arquero":  { "vida": 0.20, "fuerza": 0.30, "mana": 0.10, "suerte": 0.40 },
}


# ─── STATS BASE POR RAREZA ───────────────────────────────────────────────────
# Estos son los puntos de stat TOTALES que se reparten según CLASS_STAT_WEIGHTS

const RARITY_BASE_POINTS = {
	"comun":      100,
	"especial":   130,
	"raro":       165,
	"epico":      205,
	"mitico":     250,
	"legendario": 300,
	"milagro":    360,
}


# ─── PROGRESIÓN DE PERSONAJE ─────────────────────────────────────────────────

const LEVEL_XP_BASE:   int = 100
const LEVEL_XP_SCALE:  float = 1.35

const UNLOCK_STAT_SECONDARY:  int = 15
const UNLOCK_SKILL_2:         int = 25
const UNLOCK_SKILL_1_UPGRADE: int = 40
const UNLOCK_CLASS_PASSIVE:   int = 60


# ─── ENERGÍA / STAMINA ───────────────────────────────────────────────────────

const ENERGY_BASE_MAX:        int = 60
const ENERGY_REGEN_SECONDS:   int = 300    # 1 unidad cada 5 min
const ENERGY_COST_NEW_LEVEL:  int = 10
const ENERGY_COST_OLD_LEVEL:  int = 5
const ENERGY_COST_BOSS_BASE:  int = 15
const ENERGY_PER_CHAPTER:     int = 2      # coste extra por capítulo

const WEEKLY_REPLAY_LIMIT:    int = 5      # intentos por capítulo antiguo por semana

# XP degradado por repetición semanal (índice 0 = primer intento, etc.)
const XP_DECAY_TABLE: Array = [1.0, 0.70, 0.40, 0.15, 0.0]


# ─── CLICKER / ECONOMÍA ──────────────────────────────────────────────────────

const CLICK_BASE_VALUE:       int = 1
const CLICK_BATCH_SIZE:       int = 20     # clicks que se agrupan antes de enviar a Firebase
const CLICK_MAX_PER_SECOND:   int = 15     # límite server-side (referencia local)

const REBIRTH_BASE_THRESHOLD: int = 10_000
const REBIRTH_SCALE:          float = 2.5
const REBIRTH_MULTIPLIER_PER: float = 1.5  # multiplicador que suma cada rebirth


# ─── ARENA ───────────────────────────────────────────────────────────────────

const MAX_TEAM_SIZE:     int = 5
const CHAPTERS_PER_WORLD: int = 1          # por ahora 1 mundo, escala después

# Fórmula de HP de enemigo base por capítulo: ENEMY_HP_BASE * (ENEMY_HP_SCALE ^ chapter)
const ENEMY_HP_BASE:   int   = 80
const ENEMY_HP_SCALE:  float = 1.4

const ENEMY_DMG_BASE:  int   = 10
const ENEMY_DMG_SCALE: float = 1.35


# ─── UTILIDADES ──────────────────────────────────────────────────────────────

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

func roll_rarity(pity_legendario: int, pity_milagro: int) -> String:
	if pity_milagro >= PITY_MILAGRO:
		return "milagro"
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
	var weights: Dictionary = CLASS_STAT_WEIGHTS.get(char_class, CLASS_STAT_WEIGHTS["guerrero"])
	return {
		"vida":   max(1, int(total * weights["vida"])),
		"fuerza": max(1, int(total * weights["fuerza"])),
		"mana":   max(1, int(total * weights["mana"])),
		"suerte": max(1, int(total * weights["suerte"])),
	}
