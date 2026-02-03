# lobby.gd
# Menu principal du DjipiClub Hub apres connexion
extends Control

# ============================================================================
# REFERENCES AUX NOEUDS
# ============================================================================

@onready var welcome_label = $MainContainer/Header/WelcomeLabel
@onready var logout_button = $MainContainer/Header/LogoutButton
@onready var new_game_button = $MainContainer/ContentContainer/LeftPanel/GamesSection/GamesSectionHeader/NewGameButton
@onready var games_list_container = $MainContainer/ContentContainer/LeftPanel/GamesSection/GamesScrollContainer/GamesListContainer
@onready var players_list_container = $MainContainer/ContentContainer/LeftPanel/PlayersSection/PlayersScrollContainer/PlayersListContainer
@onready var chat_panel = $MainContainer/ContentContainer/RightPanel/ChatPanel
@onready var status_label = $MainContainer/StatusLabel
@onready var refresh_timer = $RefreshTimer

# ============================================================================
# CONSTANTES
# ============================================================================

const SERVER_API_URL = "https://djipi.club:8080"

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready():
	print("Demarrage du lobby")

	# Verifier si le joueur est connecte
	if not PlayerSession.is_logged_in():
		print("Joueur non connecte, retour au login")
		get_tree().change_scene_to_file("res://scenes/hub/login.tscn")
		return

	# Afficher le message de bienvenue
	welcome_label.text = "Bienvenue, " + PlayerSession.player_name + " !"

	# Connexion des signaux UI
	logout_button.pressed.connect(_on_logout_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	refresh_timer.timeout.connect(_refresh_all)

	# Connexion aux signaux du NetworkManager
	NetworkManager.connected_to_server.connect(_on_connected_to_game)
	NetworkManager.error_received.connect(_on_error_received)

	# Charger les donnees
	_refresh_all()
	refresh_timer.start()

	# Se connecter au lobby pour le chat
	NetworkManager.connect_to_lobby(PlayerSession.player_id)

	print("Lobby initialise")

func _notification(what: int) -> void:
	"""Gere les notifications de l'application"""
	if what == NOTIFICATION_APPLICATION_RESUMED:
		print("Application revenue au premier plan, rafraichissement...")
		if PlayerSession.is_logged_in():
			_refresh_all()

func _exit_tree() -> void:
	"""Appele quand on quitte la scene"""
	print("Arret du polling et deconnexion du lobby")
	refresh_timer.stop()
	NetworkManager.disconnect_from_lobby()

# ============================================================================
# RAFRAICHISSEMENT DES DONNEES
# ============================================================================

func _refresh_all():
	"""Rafraichit toutes les listes"""
	refresh_games_list()
	refresh_players_list()

func refresh_games_list() -> void:
	"""Demande la liste des parties du joueur"""
	if PlayerSession.player_id.is_empty():
		return

	print("Rafraichissement de la liste des parties...")
	var url = SERVER_API_URL + "/api/players/" + PlayerSession.player_id + "/games"
	_make_http_request(url, _on_games_list_received)

func _on_games_list_received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback de la liste des parties"""
	var response = JSON.parse_string(body.get_string_from_utf8())

	if code == 200 and response is Array:
		print(response.size(), " partie(s) recue(s)")
		_display_games_list(response)
	else:
		print("Erreur lors de la recuperation des parties")
		_display_games_list([])

func _display_games_list(games: Array) -> void:
	"""Affiche les parties dans l'UI"""
	# Vider la liste actuelle
	for child in games_list_container.get_children():
		child.queue_free()

	if games.is_empty():
		var empty = Label.new()
		empty.text = "Aucune partie en cours"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		games_list_container.add_child(empty)
		return

	# Creer les cartes de parties
	for game_info in games:
		var card = _create_game_card(game_info)
		games_list_container.add_child(card)

	print(games.size(), " carte(s) de partie(s) affichee(s)")

func _create_game_card(game_info: Dictionary) -> PanelContainer:
	"""Cree une carte de partie"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 90)

	var is_playing = game_info.get("status", "") == "PLAYING"
	var is_my_turn = game_info.get("isMyTurn", false)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.25, 0.15) if is_playing else Color(0.2, 0.2, 0.25)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.3, 0.8, 0.3) if is_my_turn else Color(0.5, 0.5, 0.5)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	# Ligne 1 : Type de jeu + Tour
	var hbox1 = HBoxContainer.new()
	vbox.add_child(hbox1)

	var game_type = game_info.get("gameType", "SCRABBLE_CLASSIC")
	var game_type_info = GameRegistry.get_game_info(game_type)
	var game_name = game_type_info.get("name", game_type)
	
	var tile_count = int(game_info.get("tileCount", 0))
	var tile_info = (
		"Sac vide" if tile_count == 0 else
		"1 tuile" if tile_count == 1 else
		str(tile_count) + " tuiles"
	)

	var type_label = Label.new()
	type_label.text = game_name + " - " + tile_info
	type_label.add_theme_font_size_override("font_size", 14)
	hbox1.add_child(type_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox1.add_child(spacer)

	var turn_label = Label.new()
	if is_my_turn:
		turn_label.text = "Votre tour"
		turn_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	else:
		turn_label.text = "Adversaire"
		turn_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	turn_label.add_theme_font_size_override("font_size", 12)
	hbox1.add_child(turn_label)

	# Ligne 2 : Adversaires
	var opp_label = Label.new()
	var opponents = game_info.get("opponents", [])
	opp_label.text = "contre " + ", ".join(PackedStringArray(opponents))
	opp_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	opp_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(opp_label)

	# Ligne 3 : Scores
	var scores_label = Label.new()
	scores_label.text = "Vous: %d | Adversaire: %d" % [game_info.get("myScore", 0), game_info.get("opponentScore", 0)]
	scores_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	scores_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(scores_label)

	# Bouton Reprendre
	var btn = Button.new()
	btn.text = "Reprendre"
	btn.custom_minimum_size = Vector2(0, 25)
	var gid = game_info.get("gameId", "")
	var gtype = game_type
	btn.pressed.connect(func(): _connect_and_start_game(gid, gtype))
	vbox.add_child(btn)

	return panel

# ============================================================================
# LISTE DES JOUEURS
# ============================================================================

func refresh_players_list() -> void:
	"""Demande la liste des joueurs"""
	print("Rafraichissement de la liste des joueurs...")
	var url = SERVER_API_URL + "/api/players"
	_make_http_request(url, _on_players_list_received)

func _on_players_list_received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback de la liste des joueurs"""
	var response = JSON.parse_string(body.get_string_from_utf8())

	if code == 200 and response is Array:
		print(response.size(), " joueur(s) recu(s)")
		_display_players_list(response)
	else:
		print("Erreur lors de la recuperation des joueurs")
		_display_players_list([])

func _display_players_list(players: Array) -> void:
	"""Affiche les joueurs dans l'UI"""
	for child in players_list_container.get_children():
		child.queue_free()

	if players.is_empty():
		var empty = Label.new()
		empty.text = "Aucun joueur inscrit"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		players_list_container.add_child(empty)
		return

	var displayed_count = 0
	for player_info in players:
		var pid = player_info.get("id", "")
		if pid == PlayerSession.player_id:
			continue

		var card = _create_player_card(player_info)
		players_list_container.add_child(card)
		displayed_count += 1

	if displayed_count == 0:
		var empty = Label.new()
		empty.text = "Aucun autre joueur"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		players_list_container.add_child(empty)

func _create_player_card(player_info: Dictionary) -> PanelContainer:
	"""Cree une carte joueur"""
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 40)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.25)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	panel.add_child(hbox)

	var name_label = Label.new()
	name_label.text = player_info.get("name", "???")
	name_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(name_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var challenge_btn = Button.new()
	challenge_btn.text = "Defier"
	challenge_btn.custom_minimum_size = Vector2(80, 30)
	var opponent_id = player_info.get("id", "")
	challenge_btn.pressed.connect(func(): _challenge_player(opponent_id))
	hbox.add_child(challenge_btn)

	return panel

# ============================================================================
# DEFIER UN JOUEUR
# ============================================================================

func _challenge_player(opponent_id: String) -> void:
	"""Lance un defi a un joueur"""
	print("Defi lance a: ", opponent_id)
	update_status("Envoi du defi...")

	var url = SERVER_API_URL + "/api/challenge/" + opponent_id
	var body = JSON.stringify({"playerId": PlayerSession.player_id})

	_make_http_request(url, _on_challenge_completed, HTTPClient.METHOD_POST, body)

func _on_challenge_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	"""Callback de defi"""
	var response = JSON.parse_string(body.get_string_from_utf8())

	if code == 201:
		var game_id = response.get("gameId", "")
		var game_state = response.get("gameState", {})
		var player_rack = response.get("playerRack", [])
		var game_type = response.get("gameType", "SCRABBLE_CLASSIC")

		print("Defi envoye ! Game ID: ", game_id)
		update_status("Defi envoye !")

		if not game_state.is_empty():
			NetworkManager.last_game_state = {
				"gameState": game_state,
				"playerRack": player_rack
			}

		await get_tree().create_timer(0.3).timeout
		_connect_and_start_game(game_id, game_type)
	else:
		var message = response.get("message", "Erreur lors du defi") if response else "Erreur"
		update_status(message)
		print("Defi echoue: ", message)

# ============================================================================
# CONNEXION A UNE PARTIE
# ============================================================================

func _connect_and_start_game(game_id: String, game_type: String) -> void:
	"""Lance la connexion a une partie"""
	print("Tentative de connexion a la partie: ", game_id, " (", game_type, ")")
	update_status("Connexion a la partie...")

	# Stocker le type de jeu
	NetworkManager.current_game_type = game_type

	# Etape 1 : Essayer de reconnecter
	_try_reconnect(game_id, game_type)

func _try_reconnect(game_id: String, game_type: String) -> void:
	"""Etape 1 : Tenter de reconnecter a une partie existante"""
	print("Etape 1: Reconnexion...")

	var url = SERVER_API_URL + "/api/games/" + game_id + "/reconnect"
	var body = JSON.stringify({"playerId": PlayerSession.player_id})

	_make_http_request(
		url,
		func(result, code, headers, response_body):
			_on_reconnect_completed(result, code, headers, response_body, game_id, game_type),
		HTTPClient.METHOD_POST,
		body
	)

func _on_reconnect_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, game_id: String, game_type: String) -> void:
	"""Callback de reconnexion"""
	if code == 200:
		print("Reconnexion autorisee")
		update_status("Reconnexion reussie !")
		await get_tree().create_timer(0.3).timeout
		_start_websocket(game_id, game_type)
	else:
		print("Reconnexion echouee, tentative de join...")
		_try_join(game_id, game_type)

func _try_join(game_id: String, game_type: String) -> void:
	"""Etape 2 : Tenter de rejoindre la partie"""
	print("Etape 2: Join...")

	var url = SERVER_API_URL + "/api/games/" + game_id + "/join"
	var body = JSON.stringify({"playerId": PlayerSession.player_id})

	_make_http_request(
		url,
		func(result, code, headers, response_body):
			_on_join_completed(result, code, headers, response_body, game_id, game_type),
		HTTPClient.METHOD_POST,
		body
	)

func _on_join_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, game_id: String, game_type: String) -> void:
	"""Callback de join"""
	if code == 200:
		print("Join autorise")
		update_status("Partie rejointe !")
		await get_tree().create_timer(0.3).timeout
		_start_websocket(game_id, game_type)
	else:
		var response = JSON.parse_string(body.get_string_from_utf8())
		var message = response.get("message", "Impossible de rejoindre la partie") if response else "Erreur"
		update_status(message)
		print("Erreur: ", message)

func _start_websocket(game_id: String, game_type: String) -> void:
	"""Lance la connexion WebSocket apres validation REST"""
	print("Demarrage WebSocket...")
	update_status("Connexion WebSocket...")

	# Deconnexion du lobby avant de rejoindre une partie
	NetworkManager.disconnect_from_lobby()

	# Configurer le NetworkManager
	NetworkManager.player_id = PlayerSession.player_id
	NetworkManager.player_name = PlayerSession.player_name
	NetworkManager.game_id = game_id
	NetworkManager.current_game_type = game_type

	# Connexion WebSocket
	NetworkManager.connect_to_game(game_id, PlayerSession.player_id, game_type)

	# Attendre la connexion puis lancer le jeu
	await NetworkManager.connected_to_server
	await get_tree().create_timer(0.3).timeout

	print("Lancement du jeu: ", game_type)
	GameRegistry.launch_game(game_type, game_id)

func _on_connected_to_game() -> void:
	"""Appele quand la connexion WebSocket est etablie"""
	print("WebSocket connecte")

func _on_error_received(error: String) -> void:
	"""Appele quand le serveur envoie une erreur"""
	print("Erreur WebSocket: ", error)
	update_status(error)

# ============================================================================
# ACTIONS UI
# ============================================================================

func _on_logout_pressed() -> void:
	"""Deconnexion du joueur"""
	print("Deconnexion...")
	PlayerSession.clear_player_data()
	NetworkManager.disconnect_from_lobby()
	get_tree().change_scene_to_file("res://scenes/hub/login.tscn")

func _on_new_game_pressed() -> void:
	"""Ouvre le selecteur de jeu"""
	get_tree().change_scene_to_file("res://scenes/hub/game_selector.tscn")

# ============================================================================
# HELPER HTTP
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

	var http_headers = ["Content-Type: application/json"]
	http.request(url, http_headers, method, body)

# ============================================================================
# UTILITAIRES
# ============================================================================

func update_status(message: String) -> void:
	"""Met a jour le label de statut"""
	status_label.text = message
	print("Status: ", message)
