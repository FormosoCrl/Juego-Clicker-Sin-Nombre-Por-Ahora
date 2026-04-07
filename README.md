# 🎮 [Nombre del juego]

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
| 🔵 Bolas azules | Haciendo click en el menú principal | Gacha, tiendas básicas del juego |
| 🟡 Monedas doradas | Vendiendo personajes en el Mercado | Comprar en el Mercado |

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

> **Pity system:** A las 80 tiradas sin Legendario+, se garantiza uno. A las 160, se garantiza Milagro.

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

#### Combate semi-automático

Los personajes atacan solos con IA básica. El jugador ve los **cooldowns de habilidades** de sus 5 personajes en pantalla y decide cuándo activarlas manualmente.

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

### Escenas principales

| Escena | Descripción |
|--------|-------------|
| `Main.tscn` | Hub con pestañas: Clicker, Gacha, Arena, Mercado |
| `Clicker.tscn` | Botón principal, contadores, rebirth |
| `Gacha.tscn` | Animación de invocación, colección |
| `Arena.tscn` | Selección de equipo, capítulos |
| `Combat.tscn` | Instanciada durante pelea. 5 slots + enemigos + HUD de habilidades |
| `Market.tscn` | Búsqueda, listados, panel de venta, wallet |
| `Character.gd` | Resource con todos los datos del personaje |
| `FirebaseManager.gd` | Autoload singleton. Auth, lecturas, escrituras, validaciones |

### Colecciones Firebase

| Colección | Campos clave |
|-----------|-------------|
| `users/{uid}` | blue_balls, doradas, energy, max_energy, rebirth_count, roster[] |
| `characters/{id}` | name, rarity, class, stats{}, skills[], level, xp |
| `market/{listing_id}` | seller_uid, char_id, price, filters{}, listed_at |
| `arena_progress/{uid}` | chapter, weekly_replays{}, energy_log |
| `click_events/{uid}` | batch[], timestamps[], server_validated |

---

## Roadmap

| Fase | Contenido | Milestone |
|------|-----------|-----------|
| 1 | Clicker base · economía azules · Firebase auth · antitrampas | M1 |
| 2 | Sistema de personajes (Resource) · gacha con probabilidades y animación | M2 |
| 3 | Arena: capítulos 1–3 · combate semi-auto · muerte permanente · stamina | M3 |
| 4 | Mercado: Firestore listings · filtros · transacciones · wallet doradas | M4 |
| 5 | Pulido: pity system · rebirth · XP degradado · balanceo de stats | M5 |
| 6 | Port móvil: UI responsive · touch events · compresión texturas · testing | M6 |

---

## Estructura del proyecto

```
/
├── project.godot
├── README.md
├── assets/
│   ├── characters/        # Spritesheets por rareza
│   ├── ui/                # Iconos, fondos, botones
│   └── audio/             # SFX y música
├── scenes/
│   ├── Main.tscn
│   ├── Clicker.tscn
│   ├── Gacha.tscn
│   ├── Arena.tscn
│   ├── Combat.tscn
│   └── Market.tscn
├── scripts/
│   ├── autoloads/
│   │   ├── FirebaseManager.gd
│   │   └── GameState.gd
│   ├── resources/
│   │   └── Character.gd
│   ├── clicker/
│   ├── gacha/
│   ├── arena/
│   └── market/
└── docs/
    ├── GDD.md             # Game Design Document completo
    ├── balancing.md       # Tablas de balanceo y fórmulas
    └── firebase_schema.md # Esquema de Firestore
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

Los milestones corresponden directamente a las 6 fases del roadmap. Los issues de tipo meta (decisiones de diseño abiertas, preguntas de balanceo) van sin milestone con el label `needs-design`.

---

*Proyecto en desarrollo activo — los sistemas y números están sujetos a cambios durante el balanceo.*
