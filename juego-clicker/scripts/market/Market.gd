extends Control

# ─── NODOS ────────────────────────────────────────────────────────────────────

@onready var doradas_label: Label = $VBoxContainer/DoradasLabel
@onready var search_input: LineEdit = $VBoxContainer/SearchContainer/SearchInput
@onready var search_button: Button = $VBoxContainer/SearchContainer/SearchButton
@onready var rarity_option: OptionButton = $VBoxContainer/FilterContainer/RarityOption
@onready var class_option: OptionButton = $VBoxContainer/FilterContainer/ClassOption
@onready var sort_option: OptionButton = $VBoxContainer/FilterContainer/SortOption
@onready var results_list: ItemList = $VBoxContainer/ResultsList
@onready var sell_char_option: OptionButton = $VBoxContainer/SellContainer/SellCharOption
@onready var price_input: LineEdit = $VBoxContainer/SellContainer/PriceInput
@onready var sell_button: Button = $VBoxContainer/SellContainer/SellButton

# ─── ESTADO ───────────────────────────────────────────────────────────────────

var _listings: Array = []

# ─── READY ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_setup_filters()
	_connect_signals()
	_update_ui()

func _setup_filters() -> void:
	rarity_option.add_item("Todas las rarezas")
	for rarity in ["comun", "especial", "raro", "epico", "mitico", "legendario", "milagro"]:
		rarity_option.add_item(rarity.capitalize())

	class_option.add_item("Todas las clases")
	for char_class in ["guerrero", "mago", "picaro", "sanador", "arquero"]:
		class_option.add_item(char_class.capitalize())

	sort_option.add_item("Precio: menor a mayor")
	sort_option.add_item("Precio: mayor a menor")
	sort_option.add_item("Vida: mayor a menor")
	sort_option.add_item("Fuerza: mayor a menor")
	sort_option.add_item("Mana: mayor a menor")
	sort_option.add_item("Suerte: mayor a menor")

func _connect_signals() -> void:
	search_button.pressed.connect(_on_search_pressed)
	search_input.text_submitted.connect(_on_search_submitted)
	sell_button.pressed.connect(_on_sell_pressed)
	results_list.item_activated.connect(_on_result_activated)
	GameState.doradas_changed.connect(_on_doradas_changed)
	GameState.roster_changed.connect(_update_sell_options)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and is_node_ready():
		_update_ui()

# ─── ACTUALIZACIÓN UI ─────────────────────────────────────────────────────────

func _update_ui() -> void:
	doradas_label.text = "%d monedas doradas" % GameState.doradas
	_update_sell_options()
	_on_search_pressed()

func _on_doradas_changed(value: int) -> void:
	doradas_label.text = "%d monedas doradas" % value

func _update_sell_options() -> void:
	sell_char_option.clear()
	sell_char_option.add_item("Selecciona un personaje")
	for character in GameState.roster:
		if character.is_dead:
			continue
		sell_char_option.add_item(
			"%s [%s]" % [character.name, character.rarity.to_upper()])
		sell_char_option.set_item_metadata(
			sell_char_option.item_count - 1, character.id)

# ─── BÚSQUEDA ─────────────────────────────────────────────────────────────────

func _on_search_submitted(_text: String) -> void:
	_on_search_pressed()

func _on_search_pressed() -> void:
	var filters: Dictionary = _build_filters()
	Firebase.fetch_market_listings(filters, _on_listings_received)
	results_list.clear()
	results_list.add_item("Buscando...")

func _build_filters() -> Dictionary:
	var filters: Dictionary = {}

	var search_text: String = search_input.text.strip_edges()
	if search_text != "":
		filters["name"] = search_text

	var rarity_idx: int = rarity_option.selected
	if rarity_idx > 0:
		var rarities: Array = ["comun","especial","raro","epico","mitico","legendario","milagro"]
		filters["rarity"] = [rarities[rarity_idx - 1]]

	var class_idx: int = class_option.selected
	if class_idx > 0:
		var classes: Array = ["guerrero","mago","picaro","sanador","arquero"]
		filters["char_class"] = classes[class_idx - 1]

	return filters

func _on_listings_received(listings: Array) -> void:
	_listings = _sort_listings(listings)
	_display_listings()

func _sort_listings(listings: Array) -> Array:
	var sorted: Array = listings.duplicate()
	match sort_option.selected:
		0: sorted.sort_custom(func(a, b): return a.get("price", 0) < b.get("price", 0))
		1: sorted.sort_custom(func(a, b): return a.get("price", 0) > b.get("price", 0))
		2: sorted.sort_custom(func(a, b): return a.get("vida_base", 0) > b.get("vida_base", 0))
		3: sorted.sort_custom(func(a, b): return a.get("fuerza_base", 0) > b.get("fuerza_base", 0))
		4: sorted.sort_custom(func(a, b): return a.get("mana_base", 0) > b.get("mana_base", 0))
		5: sorted.sort_custom(func(a, b): return a.get("suerte_base", 0) > b.get("suerte_base", 0))
	return sorted

func _display_listings() -> void:
	results_list.clear()
	if _listings.is_empty():
		results_list.add_item("No se encontraron resultados")
		return
	for listing in _listings:
		var text: String = "%s [%s] %s — Vida:%d Fuerza:%d Mana:%d Suerte:%d — %d doradas" % [
			listing.get("name", "?"),
			listing.get("rarity", "?").to_upper(),
			listing.get("char_class", "?"),
			listing.get("vida_base", 0),
			listing.get("fuerza_base", 0),
			listing.get("mana_base", 0),
			listing.get("suerte_base", 0),
			listing.get("price", 0),
		]
		results_list.add_item(text)
		results_list.set_item_metadata(results_list.item_count - 1, listing)

# ─── COMPRA ───────────────────────────────────────────────────────────────────

func _on_result_activated(index: int) -> void:
	var listing: Dictionary = results_list.get_item_metadata(index)
	if listing.is_empty():
		return
	var price: int = listing.get("price", 0)
	if GameState.doradas < price:
		sell_button.text = "Sin doradas suficientes"
		await get_tree().create_timer(2.0).timeout
		sell_button.text = "Poner en venta"
		return
	GameState.purchase_character(listing, price)
	_on_search_pressed()

# ─── VENTA ────────────────────────────────────────────────────────────────────

func _on_sell_pressed() -> void:
	var char_idx: int = sell_char_option.selected
	if char_idx <= 0:
		return

	var price_text: String = price_input.text.strip_edges()
	if not price_text.is_valid_int():
		sell_button.text = "Precio no válido"
		await get_tree().create_timer(2.0).timeout
		sell_button.text = "Poner en venta"
		return

	var price: int = int(price_text)
	if price <= 0:
		sell_button.text = "Precio debe ser mayor a 0"
		await get_tree().create_timer(2.0).timeout
		sell_button.text = "Poner en venta"
		return

	var character_id: String = sell_char_option.get_item_metadata(char_idx)
	if GameState.list_character_for_sale(character_id, price):
		price_input.text = ""
		sell_char_option.selected = 0
		sell_button.text = "¡Publicado!"
		await get_tree().create_timer(2.0).timeout
		sell_button.text = "Poner en venta"
