extends Control

# ─── NODOS ────────────────────────────────────────────────────────────────────

@onready var login_view: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/LoginView
@onready var register_view: VBoxContainer = $CenterContainer/PanelContainer/VBoxContainer/RegisterView

@onready var login_email: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/LoginView/EmailInput
@onready var login_password: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/LoginView/PasswordInput
@onready var login_button: Button = $CenterContainer/PanelContainer/VBoxContainer/LoginView/LoginButton
@onready var to_register_button: Button = $CenterContainer/PanelContainer/VBoxContainer/LoginView/ToRegisterButton

@onready var register_email: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/RegisterView/EmailInput
@onready var register_password: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/RegisterView/PasswordInput
@onready var register_confirm: LineEdit = $CenterContainer/PanelContainer/VBoxContainer/RegisterView/ConfirmInput
@onready var register_button: Button = $CenterContainer/PanelContainer/VBoxContainer/RegisterView/RegisterButton
@onready var to_login_button: Button = $CenterContainer/PanelContainer/VBoxContainer/RegisterView/ToLoginButton

# ─── ESTADO ───────────────────────────────────────────────────────────────────

var _is_loading: bool = false

# ─── READY ────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_show_login()
	_connect_signals()

func _connect_signals() -> void:
	login_button.pressed.connect(_on_login_pressed)
	to_register_button.pressed.connect(_show_register)
	register_button.pressed.connect(_on_register_pressed)
	to_login_button.pressed.connect(_show_login)
	
	# Permitir confirmar con Enter
	login_password.text_submitted.connect(func(_t): _on_login_pressed())
	register_confirm.text_submitted.connect(func(_t): _on_register_pressed())
	
	# Escuchar respuestas de Firebase
	Firebase.auth_completed.connect(_on_auth_completed)
	Firebase.auth_failed.connect(_on_auth_failed)
	Firebase.data_loaded.connect(_on_data_loaded)

# ─── NAVEGACIÓN ENTRE VISTAS ──────────────────────────────────────────────────

func _show_login() -> void:
	login_view.visible = true
	register_view.visible = false
	login_email.grab_focus()
	_clear_fields()

func _show_register() -> void:
	login_view.visible = false
	register_view.visible = true
	register_email.grab_focus()
	_clear_fields()

func _clear_fields() -> void:
	login_email.text = ""
	login_password.text = ""
	register_email.text = ""
	register_password.text = ""
	register_confirm.text = ""

# ─── VALIDACIÓN ───────────────────────────────────────────────────────────────

func _validate_email(email: String) -> bool:
	# Validación básica — contiene @ y al menos un punto después
	return "@" in email and email.find(".") > email.find("@")

func _validate_password(password: String) -> bool:
	return password.length() >= 6

func _show_error(message: String, on_register: bool = false) -> void:
	# Por ahora usamos el título como feedback — en el futuro un Label de error
	if on_register:
		register_button.text = message
		await get_tree().create_timer(2.5).timeout
		if not _is_loading:
			register_button.text = "Crear cuenta"
	else:
		login_button.text = message
		await get_tree().create_timer(2.5).timeout
		if not _is_loading:
			login_button.text = "Iniciar sesión"

func _set_loading(loading: bool, on_register: bool = false) -> void:
	_is_loading = loading
	if on_register:
		register_button.disabled = loading
		register_button.text = "Cargando..." if loading else "Crear cuenta"
		to_login_button.disabled = loading
	else:
		login_button.disabled = loading
		login_button.text = "Cargando..." if loading else "Iniciar sesión"
		to_register_button.disabled = loading

# ─── ACCIONES ─────────────────────────────────────────────────────────────────

func _on_login_pressed() -> void:
	var email: String = login_email.text.strip_edges()
	var password: String = login_password.text

	if email.is_empty() or password.is_empty():
		_show_error("Rellena todos los campos")
		return
	if not _validate_email(email):
		_show_error("Email no válido")
		return
	if not _validate_password(password):
		_show_error("Mínimo 6 caracteres")
		return

	_set_loading(true)
	Firebase.sign_in_with_email(email, password)

func _on_register_pressed() -> void:
	var email: String = register_email.text.strip_edges()
	var password: String = register_password.text
	var confirm: String = register_confirm.text

	if email.is_empty() or password.is_empty() or confirm.is_empty():
		_show_error("Rellena todos los campos", true)
		return
	if not _validate_email(email):
		_show_error("Email no válido", true)
		return
	if not _validate_password(password):
		_show_error("Mínimo 6 caracteres", true)
		return
	if password != confirm:
		_show_error("Las contraseñas no coinciden", true)
		return

	_set_loading(true, true)
	Firebase.register_with_email(email, password)

# ─── RESPUESTAS DE FIREBASE ───────────────────────────────────────────────────

func _on_auth_completed(_uid: String) -> void:
	_set_loading(false)

func _on_auth_failed(error: String) -> void:
	_set_loading(false)
	if error == "NO_SESSION" or error == "SESSION_EXPIRED":
		_show_login()
		return
	var on_register: bool = register_view.visible
	match error:
		"EMAIL_EXISTS":
			_show_error("Email ya registrado", on_register)
		"INVALID_PASSWORD":
			_show_error("Contraseña incorrecta")
		"EMAIL_NOT_FOUND":
			_show_error("Email no encontrado")
		"WEAK_PASSWORD":
			_show_error("Contraseña muy débil", on_register)
		_:
			_show_error("Error: " + error, on_register)

func _on_data_loaded(_data: Dictionary) -> void:
	_go_to_main()

func _go_to_main() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
