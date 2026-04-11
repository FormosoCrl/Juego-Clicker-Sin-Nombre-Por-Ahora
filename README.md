# [Nombre del juego]

> Clicker idle con gacha, arena roguelite y mercado jugador-a-jugador.  
> Desarrollado en **Godot 4.6.2** (Compatibility Renderer) · PC y móvil · Backend: Firebase

---

## Índice

- [Concepto](#concepto)
- [Sistemas del juego](#sistemas-del-juego)
  - [Clicker y economía](#clicker-y-economía)
  - [Gacha y personajes](#gacha-y-personajes)
  - [Arena](#arena)
  - [Mercado](#mercado)
- [Arquitectura técnica](#arquitectura-técnica)
- [Estado de implementación](#estado-de-implementación)
- [Roadmap](#roadmap)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Contribuir / Issues](#contribuir--issues)

---

## Concepto

Un clicker idle donde los recursos que generas haciendo click alimentan un sistema de gacha para conseguir personajes, una arena roguelite donde esos personajes combaten (y mueren para siempre), y un mercado real entre jugadores donde la economía la mueven ellos mismos.

**Ciclo de juego principal:**

```
Click → Bolas azules → Gacha / Rebirths
                              ↓
                     Personajes → Arena → XP y progreso de capítulo
                                            ↓
                              Vendes pjs sobrantes → Monedas doradas → Mercado
```

---

## Sistemas del juego

### Clicker y economía

El juego tiene **dos monedas independientes** que no se pueden convertir entre sí:

| Moneda | Cómo se obtiene | Para qué sirve |
|--------|----------------|----------------|
| Bolas azules | Haciendo click en el menú principal | Gacha, tiendas básicas del juego |
| Monedas doradas | Vendiendo personajes en el Mercado | Comprar en el Mercado |

#### Rebirths

Al acumular suficientes bolas azules se puede hacer un **Rebirth**: resetea las bolas pero otorga un multiplicador permanente de producción. El umbral sube exponencialmente con cada Rebirth.

#### Antitrampas (multicapa)

- **Rate limiting** en Firebase: máximo de clicks aceptados por segundo por UID.
- **Validación de timestamps**: el servidor rechaza lotes con saltos temporales incoherentes.
- **CAPTCHA suave**: si se detecta un patrón de clicks uniforme (varianza < 5ms), se activa verificación ligera.
- **Event-sourcing**: el cliente nunca envía "dame X bolas", solo eventos. El servidor decide la recompensa.

---

### Gacha y personajes

Hay **4500 personajes** distribuidos en 7 rarezas. Las rarezas altas tienen kits más complejos y stats base superiores.

#### Costes de invocación

| Tipo | Coste |
|------|-------|
| Invocar ×1 | 800 bolas azules |
| Invocar ×10 | 7200 bolas azules |

#### Rarezas y probabilidades

| Rareza | Pool | Probabilidad |
|--------|------|-------------|
| Común | 1500 pjs | 55% |
| Especial | 1000 pjs | 22% |
| Raro | 800 pjs | 11% |
| Épico | 600 pjs | 7% |
| Mítico | 400 pjs | 3% |
| Legendario | 200 pjs | 1.5% |
| Milagro | 50 pjs | 0.5% |

> **Pity system:** A las 200 tiradas sin Legendario+, se garantiza uno.

#### Estadísticas base

Todos los personajes tienen cuatro stats: **Vida · Fuerza · Mana · Suerte**

#### Clases

| Clase | Rol | Stat principal |
|-------|-----|---------------|
| Guerrero | Tanque, absorbe daño | Vida / Fuerza |
| Mago | Daño en área, efectos residuales | Mana |
| Pícaro | DPS burst, críticos | Suerte |
| Sanador | Soporte, cura y buffs | Mana + Suerte |
| Arquero | DPS a distancia, debuffs | Suerte + Fuerza |

#### Personajes únicos

Los personajes únicos son diseñados a mano con stats y mecánicas exclusivas. Tienen una probabilidad de aparecer en los pulls de su rareza correspondiente.

| ID | Rareza | Clase | Mecánica especial |
|----|--------|-------|------------------|
| Luckas | Milagro | Pícaro | Luck Barrage (4–8 hits según suerte) · Overwhelming Luck (invulnerabilidad + regen) · Gambler's Edge (pasiva: +5 suerte por barrage máximo) |

#### Habilidades

Hay **32 habilidades** distribuidas en 5 clases y múltiples tiers de rareza. Cada personaje tiene hasta dos slots de habilidad activa y una pasiva (desbloqueable al llegar a nivel 60).

Las habilidades cubren: daño directo, daño en área, curación, escudos, stun, evasión, regeneración, reducción de daño, y efectos acumulables.

#### Progresión de personajes

Los personajes suben de nivel al derrotar enemigos en la arena (XP individual):

| Nivel | Desbloqueo |
|-------|-----------|
| 1–10 | Stats base · Habilidad 1 disponible |
| 15 | Stat secundaria de clase |
| 25 | Habilidad 2 desbloqueada |
| 40 | Habilidad 1 mejorada (residual o CD reducido) |
| 60 | Pasiva de clase desbloqueada |

---

### Arena

El jugador lleva un equipo de **hasta 5 personajes** al combate. La **muerte es permanente**: si un personaje cae a 0 de vida, desaparece del roster para siempre.

#### Estructura de capítulos

Cada capítulo sigue el patrón: **Nivel normal → Nivel normal → Boss**

Completar el boss de un capítulo desbloquea el siguiente y **aumenta la energía máxima** del jugador de forma equivalente al coste del capítulo.

#### Capítulos implementados

| Capítulo | Nivel 1 | Nivel 2 | Boss |
|----------|---------|---------|------|
| 1 | Goblins | Orcos | Líder de la Horda Orca (2500 HP) |
| 2 | Esqueletos / Nigromantes | Caballeros Esqueleto / Banshee | Rey Liche (5500 HP) |

#### Combate semi-automático

Los personajes atacan solos con IA básica. El juego es de **acción continua** (no por turnos): cada combatiente tiene su propio temporizador de ataque independiente. El jugador ve los **cooldowns de habilidades** de sus 5 personajes en pantalla y decide cuándo activarlas manualmente. También puede asignar objetivos manualmente haciendo click en un enemigo.

Los clicks durante el combate generan **energía de habilidad** (recurso separado, se gasta en el combate y no en el menú principal).

#### Sistema de energía (stamina)

| Parámetro | Valor |
|-----------|-------|
| Energía máxima inicial | 60 (escala con cada boss completado) |
| Recarga | 1 unidad / 5 min (no acumula por encima del máximo) |
| Coste nivel nuevo | 10 + 2 por capítulo |
| Coste nivel antiguo | 5 (fijo) |
| Límite de rejuego antiguo | Semanal por capítulo |

**XP de niveles antiguos** se degrada con cada repetición semanal: 100% → 70% → 40% → 15%. Se reinicia cada lunes.

---

### Mercado

El jugador puede poner personajes en venta indicando un precio libre en monedas doradas. La venta espera a que otro jugador compre. El vendedor recibe las doradas cuando se concreta.

#### Filtros de búsqueda

- **Nombre** — búsqueda de texto parcial
- **Rareza** — multi-select (Común → Milagro)
- **Clase** — Guerrero / Mago / Pícaro / Sanador / Arquero
- **Estadística** — Vida / Fuerza / Mana / Suerte · orden ascendente o descendente
- **Precio** — rango min–max en monedas doradas
- **Nivel** — nivel mínimo del personaje

> Las transacciones usan **Firebase Transactions** para evitar doble compra. Los listings se indexan en Firestore con índices compuestos para los filtros de stat+orden.

---

## Arquitectura técnica

**Motor:** Godot 4.6.2 · Compatibility Renderer  
**Backend:** Firebase (Firestore + Auth + Functions)

### Notas sobre Compatibility Renderer

- Sin shaders de pantalla completa complejos. Efectos de rareza con `CanvasItem` shaders simples.
- Personajes como `AnimatedSprite2D` con spritesheets.
- Compresión de texturas: ETC2 (Android), BPTC (PC).
- Sin `SubViewport` innecesarios en móvil.

### Scripts principales

| Archivo | Descripción |
|---------|-------------|
| `autoloads/GameState.gd` | Singleton global. Estado de sesión, economía, roster, arena, gacha, energía |
| `autoloads/GameData.gd` | Constantes y tablas de datos: rarezas, skills, clases, escalado, costes |
| `autoloads/Firebase.gd` | Auth anónima, Firestore REST, validación de clicks, mercado |
| `scripts/resources/Character.gd` | Resource con todos los datos del personaje (stats, XP, muerte, serialización) |
| `scripts/characters/CharacterFactory.gd` | Generación procedural de personajes (nombre, stats, skills) |
| `scripts/characters/UniqueCharacters.gd` | Roster de personajes únicos diseñados a mano |
| `scripts/arena/CombatManager.gd` | Orquestador de combate: targeting, skills, XP, muerte permanente |
| `scripts/arena/Combatant.gd` | Wrapper de combate con timers, efectos de estado, cooldowns |
| `scripts/arena/EnemyData.gd` | Datos estáticos de enemigos por capítulo y nivel |
| `scripts/arena/SkillsGeneric.gd` | Motor de ejecución de habilidades genéricas |
| `scripts/arena/SkillsUnique.gd` | Handlers de habilidades únicas (Luckas, etc.) |
| `scenes/gacha/Gacha.gd` | UI de invocación: botones, resultado, estado de bolas |
| `scenes/arena/combat.gd` | UI de combate: slots, barras de HP, log, targeting manual |
| `scripts/clicker/clicker.gd` | UI del clicker: botón principal, contador de bolas |

### Escenas Godot

| Escena | Script | Estado |
|--------|--------|--------|
| `scenes/Login.tscn` | `scripts/login.gd` | Implementada (login/registro/invitado — Firebase pendiente de configurar) |
| `scenes/Main.tscn` | `scenes/Main.gd` | Implementada (hub con navegación por tabs, lazy-load de subescenas) |
| `scenes/clicker/Clicker.tscn` | `scripts/clicker/clicker.gd` | Implementada |
| `scenes/gacha/Gacha.tscn` | `scenes/gacha/Gacha.gd` | Implementada |
| `scenes/arena/Arena.tscn` | `scenes/arena/Arena.gd` | Implementada |
| `scenes/arena/combat.tscn` | `scripts/arena/combat.gd` | Implementada |
| `scenes/market/Market.tscn` | `scenes/market/Market.gd` | Implementada |

### Colecciones Firebase

| Colección | Campos clave |
|-----------|-------------|
| `users/{uid}` | blue_balls, doradas, energy, max_energy, rebirth_count, roster[] |
| `characters/{id}` | name, rarity, class, stats{}, skills[], level, xp |
| `market/{listing_id}` | seller_uid, char_id, price, filters{}, listed_at |
| `arena_progress/{uid}` | chapter, weekly_replays{}, energy_log |
| `click_events/{uid}` | batch[], timestamps[], server_validated |

---

## Estado de implementación

### Completamente implementado

- Flujo completo de navegación: Login → Main hub → tabs (Clicker, Gacha, Arena, Mercado)
- Click con batching y validación antitrampas
- Gacha con 7 rarezas, pity, habilidades cross-class
- Generación procedural de personajes (nombre, stats, habilidades)
- Un personaje único: Luckas (mecánicas propias de suerte)
- Progresión de personajes: XP, niveles, muerte permanente
- Combate de acción continua con targeting manual y sistema de habilidades
- 32 habilidades con efectos completos (stun, shields, regen, evasión, etc.)
- Sistema de energía con reset semanal y degradación de XP
- Arena: 2 capítulos, 2 niveles + 1 boss cada uno (6 encuentros)
- Firebase: código de auth + Firestore REST completo (pendiente configurar credenciales)
- UI completa: todas las escenas tienen script y están conectadas

### Implementado parcialmente / bloqueado

- **Login / Firebase**: código completo, bloqueado esperando credenciales del proyecto Firebase
- **Pasivas de personaje**: campo `passive_id` existe, lógica de activación en combate no implementada
- **Stat secundaria (nivel 15)**: umbral definido, no se aplica en combate
- **Mercado (compra)**: backend Firestore listo, la UI de compra activa pero sin datos reales hasta tener Firebase

### Pendiente

- Credenciales de Firebase (FIREBASE_PROJECT_ID y FIREBASE_API_KEY en Firebase.gd)
- Personajes únicos adicionales (solo existe Luckas)
- Capítulos 3 en adelante
- Lógica de pasivas de personaje
- Arte de personajes y UI (carpetas `assets/` vacías)
- Audio
- Port móvil

---

## Roadmap

| Fase | Contenido | Estado |
|------|-----------|--------|
| 1 | Clicker base · economía azules · Firebase auth · antitrampas | Completo |
| 2 | Sistema de personajes · gacha con probabilidades · Luckas | Completo |
| 3 | Arena: capítulos 1–2 · combate continuo · muerte permanente · stamina | Completo |
| 4 | Mercado: Firestore listings · filtros · transacciones · wallet doradas | Completo (bloqueado por credenciales Firebase) |
| 5 | Escenas principales: Login · hub · gacha · mercado · navegación | Completo |
| 6 | Firebase: configurar credenciales · probar flujo completo online | Pendiente |
| 7 | Contenido: capítulo 3+ · más personajes únicos · pasivas | Pendiente |
| 8 | Port móvil: UI responsive · touch · compresión texturas | Pendiente |

---

## Estructura del proyecto

```
juego-clicker/
├── project.godot
├── .gitignore
├── .gitattributes
├── assets/
│   ├── characters/        # Spritesheets por rareza (vacío)
│   ├── ui/                # Iconos, fondos, botones (vacío)
│   └── audio/             # SFX y música (vacío)
├── autoloads/
│   ├── Firebase.gd        # Auth anónima/email, Firestore REST, antitrampas, mercado
│   ├── GameData.gd        # Constantes y tablas de datos
│   └── GameState.gd       # Estado global del juego
├── scenes/
│   ├── Login.tscn / Main.gd (hub con navegación por tabs)
│   ├── Main.tscn  / Main.gd
│   ├── clicker/
│   │   └── Clicker.tscn
│   ├── gacha/
│   │   ├── Gacha.tscn
│   │   └── Gacha.gd
│   ├── arena/
│   │   ├── Arena.tscn / Arena.gd
│   │   └── combat.tscn
│   └── market/
│       ├── Market.tscn
│       └── Market.gd
├── scripts/
│   ├── login.gd           # Lógica de Login/Registro/Invitado
│   ├── arena/
│   │   ├── combat.gd
│   │   ├── CombatManager.gd
│   │   ├── Combatant.gd
│   │   ├── EnemyData.gd
│   │   ├── SkillsGeneric.gd
│   │   └── SkillsUnique.gd
│   ├── characters/
│   │   ├── CharacterFactory.gd
│   │   └── UniqueCharacters.gd
│   ├── clicker/
│   │   └── clicker.gd
│   └── resources/
│       └── Character.gd
└── docs/
    ├── GDD.md
    ├── balancing.md
    └── firebase_schema.md
```

---

## Contribuir / Issues

### Labels de issues

**Tipo:** `feat` · `bug` · `refactor` · `docs`  
**Sistema:** `clicker` · `gacha` · `arena` · `mercado` · `firebase` · `ui`  
**Prioridad:** `critical` · `high` · `low`  
**Plataforma:** `pc` · `mobile` · `both`  
**Estado:** `blocked` · `needs-design`

### Milestones

Los milestones corresponden directamente a las fases del roadmap. Los issues de tipo meta (decisiones de diseño abiertas, preguntas de balanceo) van sin milestone con el label `needs-design`.

---

*Proyecto en desarrollo activo — los sistemas y números están sujetos a cambios durante el balanceo.*
