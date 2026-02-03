# game_selector.gd
# Ecran de selection du type de jeu pour creer une nouvelle partie
extends Control

# ============================================================================
# REFERENCES AUX NOEUDS
# ============================================================================

@onready var back_button = $VBoxContainer/Header/BackButton
@onready var games_grid = $VBoxContainer/GamesScrollContainer/GamesGridContainer
@onready var status_label = $VBoxContainer/StatusLabel

# ============================================================================
# CONSTANTES
# ============================================================================

const SERVER_API_URL = "http://djipi.club:8080"

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready():
	print("Demarrage du selecteur de jeux")

	# Verifier si le joueur est connecte
	if not PlayerSession.is_logged_in():
		print("Joueur non connecte, retour au login")
		get_tree().change_scene_to_file("res://scenes/hub/login.tscn")
		return

	# Connexion des signaux
	back_button.pressed.connect(_on_back_pressed)

	# Afficher les jeux disponibles
	_display_games()

	print("Selecteur de jeux initialise")

# ============================================================================
# AFFICHAGE DES JEUX
# ============================================================================

func _display_games():
	"""Affiche tous les jeux dans la grille"""
	# Vider la grille
	for child in games_grid.get_children():
		child.queue_free()

	# Recuperer tous les jeux (disponibles ou non)
	var all_games = GameRegistry.get_all_games()

	for game_type in all_games:
		var game_info = GameRegistry.get_game_info(game_type)
		var card = _create_game_card(game_type, game_info)
		games_grid.add_child(card)

	print(all_games.size(), " jeu(x) affiche(s)")

func _create_game_card(game_type: String, game_info: Dictionary) -> PanelContainer:
	"""Cree une carte de jeu"""
	var is_available = game_info.get("available", false)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 200)

	var style = StyleBoxFlat.new()
	if is_available:
		style.bg_color = Color(0.15, 0.25, 0.15)
		style.border_color = Color(0.3, 0.8, 0.3)
	else:
		style.bg_color = Color(0.2, 0.2, 0.2)
		style.border_color = Color(0.4, 0.4, 0.4)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Margin container pour padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(margin)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	# Nom du jeu
	var name_label = Label.new()
	name_label.text = game_info.get("name", game_type)
	name_label.add_theme_font_size_override("font_size", 22)
	if is_available:
		name_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	else:
		name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	# Description
	var desc_label = Label.new()
	desc_label.text = game_info.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(desc_label)

	# Nombre de joueurs
	var players_label = Label.new()
	var min_p = game_info.get("min_players", 2)
	var max_p = game_info.get("max_players", 4)
	players_label.text = str(min_p) + " - " + str(max_p) + " joueurs"
	players_label.add_theme_font_size_override("font_size", 11)
	players_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	players_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(players_label)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	# Bouton
	var btn = Button.new()
	if is_available:
		btn.text = "Creer une partie"
		btn.pressed.connect(func(): _create_game(game_type))
	else:
		btn.text = "Bientot disponible"
		btn.disabled = true
	btn.custom_minimum_size = Vector2(0, 40)
	content.add_child(btn)

	return panel

# ============================================================================
# CREATION DE PARTIE
# ============================================================================

func _create_game(game_type: String) -> void:
	"""Cree une nouvelle partie du type specifie"""
	print("Creation d'une partie: ", game_type)
	update_status("Creation de la partie...")

	var url = SERVER_API_URL + "/api/games"
	var body = JSON.stringify({
		"creatorId": PlayerSession.player_id,
		"gameType": game_type
	})

	_make_http_request(url, func(result, code, headers, response_body):
		_on_game_created(result, code, headers, response_body, game_type),
		HTTPClient.METHOD_POST,
		body
	)

func _on_game_created(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, game_type: String) -> void:
	"""Callback de creation de partie"""
	var response = JSON.parse_string(body.get_string_from_utf8())

	if code == 201:
		var game_id = response.get("gameId", "")
		var game_state = response.get("gameState", {})
		var player_rack = response.get("playerRack", [])

		print("Partie creee ! Game ID: ", game_id)
		update_status("Partie creee !")

		# Stocker l'etat initial
		if not game_state.is_empty():
			NetworkManager.last_game_state = {
				"gameState": game_state,
				"playerRack": player_rack
			}

		# Retour au lobby (la partie apparaitra dans la liste)
		await get_tree().create_timer(0.5).timeout
		get_tree().change_scene_to_file("res://scenes/hub/lobby.tscn")
	else:
		var message = response.get("message", "Erreur lors de la creation") if response else "Erreur"
		update_status(message)
		print("Creation echouee: ", message)

# ============================================================================
# NAVIGATION
# ============================================================================

func _on_back_pressed() -> void:
	"""Retour au lobby"""
	get_tree().change_scene_to_file("res://scenes/hub/lobby.tscn")

# ============================================================================
# HELPER HTTP
# ============================================================================

func _make_http_request(url: String, callback: Callable, method: HTTPClient.Method = HTTPClient.METHOD_GET, body: String = "") -> void:
	"""Cree une requete HTTP avec un callback dedie"""
	var http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(func(r, c, h, b):
		callback.call(r, c, h, b)
		await get_tree().create_timer(0.1).timeout
		http.queue_free()
	, CONNECT_ONE_SHOT)

	var http_headers = ["Content-Type: application/json"]
	http.request(url, http_headers, method, body)

# ============================================================================
# UTILITAIRES
# ============================================================================

func update_status(message: String) -> void:
	"""Met a jour le label de statut"""
	status_label.text = message
