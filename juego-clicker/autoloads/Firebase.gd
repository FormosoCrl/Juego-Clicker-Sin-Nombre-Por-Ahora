extends Node

# ─── CONFIGURACIÓN ────────────────────────────────────────────────────────────

const FIREBASE_PROJECT_ID: String = ""  # ← rellenar cuando crees el proyecto
const FIREBASE_API_KEY: String = ""     # ← rellenar desde Firebase Console

const FIRESTORE_URL: String = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents"
const AUTH_URL: String = "https://identitytoolkit.googleapis.com/v1/accounts"

# ─── ESTADO ───────────────────────────────────────────────────────────────────

var _id_token: String = ""
var _refresh_token: String = ""
var _token_expiry: int = 0
var _uid: String = ""
var _is_ready: bool = false

# ─── SEÑALES ──────────────────────────────────────────────────────────────────

signal auth_completed(uid: String)
signal auth_failed(error: String)
signal data_loaded(data: Dictionary)
signal sync_failed(error: String)

# ─── COLA DE REQUESTS PENDIENTES ─────────────────────────────────────────────
# Si Firebase no está listo, las operaciones se encolan y se ejecutan después

var _pending_operations: Array = []

# ─── CICLO DE VIDA ────────────────────────────────────────────────────────────

func _ready() -> void:
	if FIREBASE_PROJECT_ID == "" or FIREBASE_API_KEY == "":
		push_warning("Firebase: proyecto no configurado. Modo offline activo.")
		return
	sign_in_anonymous()

# ─── AUTENTICACIÓN ────────────────────────────────────────────────────────────

func sign_in_anonymous() -> void:
	var url: String = AUTH_URL + ":signUp?key=" + FIREBASE_API_KEY
	var body: Dictionary = { "returnSecureToken": true }
	_post(url, body, _on_auth_response, false)

func _on_auth_response(result: int, response_code: int, body: Dictionary) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("auth_failed", "Error de autenticación: %d" % response_code)
		return

	_id_token = body.get("idToken", "")
	_refresh_token = body.get("refreshToken", "")
	_uid = body.get("localId", "")
	_token_expiry = Time.get_unix_time_from_system() + 3600

	GameState.uid = _uid
	GameState.is_logged_in = true
	_is_ready = true

	emit_signal("auth_completed", _uid)
	_flush_pending_operations()
	load_player_data()

func _refresh_token_if_needed() -> void:
	if Time.get_unix_time_from_system() < _token_expiry - 60:
		return
	var url: String = "https://securetoken.googleapis.com/v1/token?key=" + FIREBASE_API_KEY
	var body: Dictionary = {
		"grant_type": "refresh_token",
		"refresh_token": _refresh_token,
	}
	_post(url, body, _on_token_refreshed, false)

func _on_token_refreshed(_result: int, _code: int, body: Dictionary) -> void:
	_id_token = body.get("id_token", _id_token)
	_token_expiry = Time.get_unix_time_from_system() + 3600

# ─── CARGA INICIAL ────────────────────────────────────────────────────────────

func load_player_data() -> void:
	if not _is_ready:
		return
	var path: String = "users/%s" % _uid
	_fetch(path, _on_player_data_loaded)

func _on_player_data_loaded(_result: int, response_code: int, body: Dictionary) -> void:
	if response_code == 404:
		# Jugador nuevo — crear documento inicial
		_create_new_player()
		return
	if response_code != 200:
		emit_signal("sync_failed", "Error cargando datos: %d" % response_code)
		return
	var data: Dictionary = _firestore_to_dict(body)
	GameState.load_from_dict(data)
	emit_signal("data_loaded", data)
	_load_roster()

func _create_new_player() -> void:
	var initial_data: Dictionary = GameState.to_dict()
	var path: String = "users/%s" % _uid
	_patch(path, initial_data, func(_r, _c, _b): pass)

func _load_roster() -> void:
	var path: String = "users/%s/roster" % _uid
	_fetch(path, _on_roster_loaded)

func _on_roster_loaded(_result: int, response_code: int, body: Dictionary) -> void:
	if response_code != 200:
		return
	var documents: Array = body.get("documents", [])
	for doc in documents:
		var char_data: Dictionary = _firestore_to_dict(doc)
		var character: Character = Character.from_dict(char_data)
		if character != null:
			GameState.roster.append(character)
	GameState.emit_signal("roster_changed")

# ─── CLICKS ───────────────────────────────────────────────────────────────────

func send_click_batch(batch: Array, multiplier: float) -> void:
	if not _is_ready:
		_pending_operations.append(func(): send_click_batch(batch, multiplier))
		return

	# Validación local antes de enviar
	if not _validate_click_batch(batch):
		push_warning("Firebase: lote de clicks rechazado localmente")
		return

	var path: String = "click_events/%s" % _uid
	var data: Dictionary = {
		"batch": batch,
		"multiplier": multiplier,
		"timestamp": Time.get_unix_time_from_system(),
		"client_version": "1.0",
	}
	_patch(path, data, _on_click_batch_sent)

func _validate_click_batch(batch: Array) -> bool:
	if batch.is_empty():
		return false
	if batch.size() > GameData.CLICK_BATCH_SIZE * 2:
		return false

	# Comprobar que los timestamps son coherentes
	for i in range(1, batch.size()):
		var delta: int = batch[i] - batch[i - 1]
		if delta < 0:
			return false  # timestamps no crecientes
		if delta < 30:
			return false  # menos de 30ms entre clicks = bot

	# Comprobar varianza — clicks perfectamente uniformes = bot
	if batch.size() >= 5:
		var deltas: Array = []
		for i in range(1, batch.size()):
			deltas.append(batch[i] - batch[i - 1])
		var mean: float = 0.0
		for d in deltas:
			mean += d
		mean /= deltas.size()
		var variance: float = 0.0
		for d in deltas:
			variance += pow(d - mean, 2)
		variance /= deltas.size()
		if variance < 5.0:
			push_warning("Firebase: patrón de clicks uniforme detectado")
			return false

	return true

func _on_click_batch_sent(_result: int, response_code: int, _body: Dictionary) -> void:
	if response_code != 200:
		push_warning("Firebase: error enviando clicks: %d" % response_code)

# ─── GUARDADO DE PERSONAJE ────────────────────────────────────────────────────

func save_character(character: Character) -> void:
	if not _is_ready:
		_pending_operations.append(func(): save_character(character))
		return
	var path: String = "users/%s/roster/%s" % [_uid, character.id]
	_patch(path, character.to_dict(), func(_r, _c, _b): pass)

func delete_character(character_id: String) -> void:
	if not _is_ready:
		_pending_operations.append(func(): delete_character(character_id))
		return
	var path: String = "users/%s/roster/%s" % [_uid, character_id]
	_delete(path, func(_r, _c, _b): pass)

# ─── REBIRTH ──────────────────────────────────────────────────────────────────

func save_rebirth(rebirth_count: int, multiplier: float) -> void:
	if not _is_ready:
		_pending_operations.append(func(): save_rebirth(rebirth_count, multiplier))
		return
	var path: String = "users/%s" % _uid
	_patch(path, {
		"rebirth_count": rebirth_count,
		"click_multiplier": multiplier,
		"blue_balls": 0,
	}, func(_r, _c, _b): pass)

# ─── ARENA ────────────────────────────────────────────────────────────────────

func save_arena_progress() -> void:
	if not _is_ready:
		_pending_operations.append(func(): save_arena_progress())
		return
	var path: String = "users/%s" % _uid
	_patch(path, {
		"current_chapter": GameState.current_chapter,
		"bosses_cleared": GameState.bosses_cleared,
		"weekly_replays": GameState.weekly_replays,
		"weekly_reset_timestamp": GameState.weekly_reset_timestamp,
		"energy": GameState.energy,
		"energy_max": GameState.energy_max,
	}, func(_r, _c, _b): pass)

# ─── MERCADO ──────────────────────────────────────────────────────────────────

func list_on_market(character: Character, price: int) -> void:
	if not _is_ready:
		_pending_operations.append(func(): list_on_market(character, price))
		return
	var listing_id: String = "listing_%s_%d" % [character.id, Time.get_unix_time_from_system()]
	var data: Dictionary = character.to_dict()
	data["price"] = price
	data["seller_uid"] = _uid
	data["listed_at"] = Time.get_unix_time_from_system()
	_patch("market/%s" % listing_id, data, func(_r, _c, _b): pass)

func fetch_market_listings(filters: Dictionary, callback: Callable) -> void:
	if not _is_ready:
		return
	# Por ahora carga todos y filtra localmente
	# Cuando tengamos índices en Firestore usaremos queries nativas
	_fetch("market", func(_r, code, body):
		if code != 200:
			callback.call([])
			return
		var listings: Array = []
		for doc in body.get("documents", []):
			var listing: Dictionary = _firestore_to_dict(doc)
			if _matches_filters(listing, filters):
				listings.append(listing)
		callback.call(listings)
	)

func _matches_filters(listing: Dictionary, filters: Dictionary) -> bool:
	if filters.has("name") and filters["name"] != "":
		if not listing.get("name", "").to_lower().contains(filters["name"].to_lower()):
			return false
	if filters.has("rarity") and not filters["rarity"].is_empty():
		if not listing.get("rarity", "") in filters["rarity"]:
			return false
	if filters.has("char_class") and filters["char_class"] != "":
		if listing.get("char_class", "") != filters["char_class"]:
			return false
	if filters.has("min_price"):
		if listing.get("price", 0) < filters["min_price"]:
			return false
	if filters.has("max_price"):
		if listing.get("price", 0) > filters["max_price"]:
			return false
	if filters.has("stat") and filters.has("min_stat"):
		if listing.get(filters["stat"] + "_base", 0) < filters["min_stat"]:
			return false
	return true

# ─── COLA DE OPERACIONES PENDIENTES ──────────────────────────────────────────

func _flush_pending_operations() -> void:
	var ops: Array = _pending_operations.duplicate()
	_pending_operations.clear()
	for op in ops:
		op.call()

# ─── HTTP HELPERS ─────────────────────────────────────────────────────────────

func _fetch(path: String, callback: Callable) -> void:
	_refresh_token_if_needed()
	var url: String = (FIRESTORE_URL % FIREBASE_PROJECT_ID) + "/" + path
	var headers: Array = _get_headers()
	var http: HTTPRequest = _make_http_request()
	http.request_completed.connect(
		func(result, code, _headers, body):
			var parsed: Dictionary = _parse_body(body)
			callback.call(result, code, parsed)
			http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_GET)

func _post(url: String, body: Dictionary, callback: Callable, auth: bool = true) -> void:
	var headers: Array = _get_headers(auth)
	var http: HTTPRequest = _make_http_request()
	http.request_completed.connect(
		func(result, code, _headers, resp_body):
			var parsed: Dictionary = _parse_body(resp_body)
			callback.call(result, code, parsed)
			http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _patch(path: String, data: Dictionary, callback: Callable) -> void:
	_refresh_token_if_needed()
	var url: String = (FIRESTORE_URL % FIREBASE_PROJECT_ID) + "/" + path
	var headers: Array = _get_headers()
	var http: HTTPRequest = _make_http_request()
	var firestore_body: Dictionary = _dict_to_firestore(data)
	http.request_completed.connect(
		func(result, code, _headers, body):
			var parsed: Dictionary = _parse_body(body)
			callback.call(result, code, parsed)
			http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(firestore_body))

func _delete(path: String, callback: Callable) -> void:
	_refresh_token_if_needed()
	var url: String = (FIRESTORE_URL % FIREBASE_PROJECT_ID) + "/" + path
	var headers: Array = _get_headers()
	var http: HTTPRequest = _make_http_request()
	http.request_completed.connect(
		func(result, code, _headers, body):
			var parsed: Dictionary = _parse_body(body)
			callback.call(result, code, parsed)
			http.queue_free()
	)
	http.request(url, headers, HTTPClient.METHOD_DELETE)

func _make_http_request() -> HTTPRequest:
	var http: HTTPRequest = HTTPRequest.new()
	add_child(http)
	return http

func _get_headers(use_auth: bool = true) -> Array:
	var headers: Array = ["Content-Type: application/json"]
	if use_auth and _id_token != "":
		headers.append("Authorization: Bearer " + _id_token)
	return headers

func _parse_body(raw_body: PackedByteArray) -> Dictionary:
	var text: String = raw_body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}

# ─── CONVERSIÓN FIRESTORE ────────────────────────────────────────────────────
# Firestore usa un formato de tipos explícito:
# { "fields": { "clave": { "stringValue": "valor" } } }

func _dict_to_firestore(data: Dictionary) -> Dictionary:
	var fields: Dictionary = {}
	for key in data:
		fields[key] = _value_to_firestore(data[key])
	return { "fields": fields }

func _value_to_firestore(value) -> Dictionary:
	match typeof(value):
		TYPE_STRING:  return { "stringValue": value }
		TYPE_INT:     return { "integerValue": str(value) }
		TYPE_FLOAT:   return { "doubleValue": value }
		TYPE_BOOL:    return { "booleanValue": value }
		TYPE_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(_value_to_firestore(item))
			return { "arrayValue": { "values": arr } }
		TYPE_DICTIONARY:
			var fields: Dictionary = {}
			for k in value:
				fields[k] = _value_to_firestore(value[k])
			return { "mapValue": { "fields": fields } }
		_:
			return { "stringValue": str(value) }

func _firestore_to_dict(doc: Dictionary) -> Dictionary:
	var fields: Dictionary = doc.get("fields", {})
	var result: Dictionary = {}
	for key in fields:
		result[key] = _firestore_to_value(fields[key])
	return result

func _firestore_to_value(field: Dictionary):
	if field.has("stringValue"):  return field["stringValue"]
	if field.has("integerValue"): return int(field["integerValue"])
	if field.has("doubleValue"):  return float(field["doubleValue"])
	if field.has("booleanValue"): return field["booleanValue"]
	if field.has("arrayValue"):
		var arr: Array = []
		for item in field["arrayValue"].get("values", []):
			arr.append(_firestore_to_value(item))
		return arr
	if field.has("mapValue"):
		var map: Dictionary = {}
		for k in field["mapValue"].get("fields", {}):
			map[k] = _firestore_to_value(field["mapValue"]["fields"][k])
		return map
	return null
