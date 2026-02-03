# login.gd
# Ecran de connexion du DjipiClub Hub
extends Control

# ============================================================================
# REFERENCES AUX NOEUDS UI
# ============================================================================

@onready var auth_container = $VBoxContainer/AuthContainer
@onready var player_name_input = $VBoxContainer/AuthContainer/MarginContainer/PlayerNameInput
@onready var register_button = $VBoxContainer/AuthContainer/HBoxContainer/RegisterButton
@onready var login_button = $VBoxContainer/AuthContainer/HBoxContainer/LoginButton
@onready var status_label = $VBoxContainer/StatusLabel
@onready var refresh_timer = $RefreshTimer

# ============================================================================
# CONSTANTES
# ============================================================================

const SERVER_API_URL = "https://djipi.club:8080"

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready():
	# Attendre que tout soit chargé
	await get_tree().process_frame
	
	# Forcer le focus
	player_name_input.grab_focus()
	
	# Sur mobile, forcer l'ouverture du clavier
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		player_name_input.selecting_enabled = true
		player_name_input.virtual_keyboard_enabled = true
		# Simuler un clic pour déclencher le clavier
		await get_tree().create_timer(0.2).timeout
		player_name_input.grab_focus()

	# Connexion des signaux UI
	register_button.pressed.connect(_on_register_pressed)
	login_button.pressed.connect(_on_login_pressed)

	# Verifier si deja connecte
	if PlayerSession.is_logged_in():
		print("Joueur deja connecte, redirection vers le lobby")
		_go_to_lobby()
	else:
		# Tenter auto-login avec credentials sauvegardes
		_check_saved_credentials_and_auto_login()

	print("Initialisation terminee")

# ============================================================================
# GESTION DES IDENTIFIANTS
# ============================================================================

func _check_saved_credentials_and_auto_login() -> void:
	"""Verifie les identifiants sauvegardes et tente une connexion automatique"""
	var config = ConfigFile.new()
	var err = config.load("user://player_data.cfg")

	if err == OK:
		var saved_name = config.get_value("player", "name", "")
		if not saved_name.is_empty():
			print("Identifiants trouvés pour '", saved_name, "'. Tentative de connexion automatique...")
			player_name_input.text = saved_name
			_on_login_pressed()

func _save_credentials(name: String, id: String) -> void:
	"""Sauvegarde les identifiants"""
	var config = ConfigFile.new()
	config.set_value("player", "name", name)
	config.set_value("player", "id", id)
	config.save("user://player_data.cfg")
	print("Identifiants sauvegardés")

# ============================================================================
# HELPER : REQUETE HTTP
# ============================================================================

func _make_http_request(url: String, callback: Callable, method: HTTPClient.Method = HTTPClient.METHOD_GET, body: String = "") -> void:
	"""Cree une requete HTTP avec un callback dedie"""
	var http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(result, code, headers, response_body):
		callback.call(result, code, headers, response_body)
		await get_tree().create_timer(0.1).timeout
		http.queue_free()
	, CONNECT_ONE_SHOT)

	var headers = ["Content-Type: application/json"]
	http.request(url, headers, method, body)

	print("Requete HTTP: ", method, " ", url)

# ============================================================================
# INSCRIPTION
# ============================================================================

func _on_register_pressed() -> void:
	"""Inscription d'un nouveau joueur"""
	var name = player_name_input.text.strip_edges()

	if name.is_empty():
		update_status("Le pseudo ne peut pas etre vide")
		return

	update_status("Inscription en cours...")
	register_button.disabled = true
	login_button.disabled = true

	var url = SERVER_API_URL + "/api/register"
	var body = JSON.stringify({
		"name": name,
		"password": "temp123"
	})

	_make_http_request(url, _on_register_completed, HTTPClient.METHOD_POST, body)

func _on_register_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback d'inscription"""
	var response = JSON.parse_string(body.get_string_from_utf8())

	if code == 201:
		var player_id = response.get("playerId", "")
		var player_name = player_name_input.text.strip_edges()
		PlayerSession.set_player_data(player_id, player_name)

		print("Inscription reussie: ", player_name, " (", player_id, ")")
		_save_credentials(player_name, player_id)

		update_status("Bienvenue " + player_name + " !")
		await get_tree().create_timer(0.5).timeout
		_go_to_lobby()
	else:
		var message = response.get("message", "Erreur d'inscription") if response else "Erreur"
		update_status(message)
		print("Inscription echouee: ", message)
		register_button.disabled = false
		login_button.disabled = false

# ============================================================================
# CONNEXION
# ============================================================================

func _on_login_pressed() -> void:
	"""Connexion avec un pseudo existant"""
	var name = player_name_input.text.strip_edges()

	if name.is_empty():
		update_status("Le pseudo ne peut pas etre vide")
		return

	update_status("Connexion en cours...")
	login_button.disabled = true
	register_button.disabled = true

	var url = SERVER_API_URL + "/api/login?name=" + name.uri_encode()
	_make_http_request(url, _on_login_completed)

func _on_login_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback de connexion"""
	var response = JSON.parse_string(body.get_string_from_utf8())

	if code == 200:
		var p_id = response.get("playerId", "")
		var p_name = response.get("name", "")
		PlayerSession.set_player_data(p_id, p_name)

		print("Connexion reussie: ", p_name, " (", p_id, ")")
		_save_credentials(p_name, p_id)

		update_status("Bienvenue " + p_name + " !")
		await get_tree().create_timer(0.5).timeout
		_go_to_lobby()
	else:
		var message = response.get("message", "Joueur non trouve") if response else "Erreur"
		update_status(message)
		print("Connexion echouee: ", message)
		login_button.disabled = false
		register_button.disabled = false

# ============================================================================
# NAVIGATION
# ============================================================================

func _go_to_lobby() -> void:
	"""Navigue vers le lobby"""
	get_tree().change_scene_to_file("res://scenes/hub/lobby.tscn")

# ============================================================================
# UTILITAIRES
# ============================================================================

func update_status(message: String) -> void:
	"""Met a jour le label de statut"""
	status_label.text = message
	print("Status: ", message)
