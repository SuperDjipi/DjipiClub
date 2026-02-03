# network_manager.gd
# Gere les connexions WebSocket avec le serveur
# VERSION 3.0 : Support multi-jeux + chat lobby
extends Node

# ============================================================================
# CONFIGURATION
# ============================================================================

const SERVER_URL = "wss://djipi.club:8080"
const SERVER_API_URL = "https://djipi.club:8080"

# ============================================================================
# CONNEXIONS WEBSOCKET
# ============================================================================

# Connexion principale au jeu
var game_socket = WebSocketPeer.new()
var game_connection_status = WebSocketPeer.STATE_CLOSED

# Connexion au lobby pour le chat
var lobby_socket = WebSocketPeer.new()
var lobby_connection_status = WebSocketPeer.STATE_CLOSED

# ============================================================================
# INFORMATIONS DE SESSION
# ============================================================================

var player_id: String = ""
var player_name: String = ""
var game_id: String = ""
var current_game_type: String = ""  # SCRABBLE_CLASSIC, BOGGLE, etc.

# Stocker le dernier etat recu pour les connexions tardives
var last_game_state: Dictionary = {}

# ============================================================================
# SIGNAUX - JEU
# ============================================================================

signal connected_to_server()
signal disconnected_from_server()
signal connection_error(error_message: String)
signal game_state_received(game_state: Dictionary)
signal error_received(error_message: String)

# ============================================================================
# SIGNAUX - LOBBY CHAT
# ============================================================================

signal lobby_connected()
signal lobby_disconnected()
signal chat_message_received(from_player: String, message: String, timestamp: int)
signal player_joined_lobby(player_name: String)
signal player_left_lobby(player_name: String)

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready():
	print("NetworkManager initialise (multi-jeux + lobby)")

func _process(_delta):
	_process_game_socket()
	_process_lobby_socket()

# ============================================================================
# TRAITEMENT DES SOCKETS
# ============================================================================

func _process_game_socket():
	"""Traite les messages du socket de jeu"""
	game_socket.poll()
	var state = game_socket.get_ready_state()

	if state != game_connection_status:
		game_connection_status = state
		match state:
			WebSocketPeer.STATE_OPEN:
				print("Connecte au serveur de jeu")
				connected_to_server.emit()
			WebSocketPeer.STATE_CLOSED:
				print("Deconnecte du serveur de jeu")
				disconnected_from_server.emit()

	while game_socket.get_ready_state() == WebSocketPeer.STATE_OPEN and game_socket.get_available_packet_count():
		var packet = game_socket.get_packet()
		var message = packet.get_string_from_utf8()
		_handle_game_message(message)

func _process_lobby_socket():
	"""Traite les messages du socket lobby"""
	lobby_socket.poll()
	var state = lobby_socket.get_ready_state()

	if state != lobby_connection_status:
		lobby_connection_status = state
		match state:
			WebSocketPeer.STATE_OPEN:
				print("Connecte au lobby")
				lobby_connected.emit()
			WebSocketPeer.STATE_CLOSED:
				print("Deconnecte du lobby")
				lobby_disconnected.emit()

	while lobby_socket.get_ready_state() == WebSocketPeer.STATE_OPEN and lobby_socket.get_available_packet_count():
		var packet = lobby_socket.get_packet()
		var message = packet.get_string_from_utf8()
		_handle_lobby_message(message)

# ============================================================================
# CONNEXION AU JEU
# ============================================================================

func connect_to_game(game_id_param: String, player_id_param: String, game_type: String = "") -> void:
	"""
	Etablit une connexion WebSocket au serveur de jeu
	URL : ws://djipi.club:8080/{gameId}?playerId={playerId}
	"""
	player_id = player_id_param
	game_id = game_id_param
	if not game_type.is_empty():
		current_game_type = game_type

	var full_url = SERVER_URL + "/" + game_id + "?playerId=" + player_id
	print("Connexion au jeu: ", full_url)

	var error = game_socket.connect_to_url(full_url)
	if error != OK:
		print("Erreur de connexion au jeu: ", error)
		connection_error.emit("Impossible de se connecter au serveur de jeu")

# Alias pour compatibilite avec l'ancien code
func connect_to_server(game_id_param: String, player_id_param: String) -> void:
	connect_to_game(game_id_param, player_id_param)

func disconnect_from_game() -> void:
	"""Ferme la connexion WebSocket au jeu"""
	if game_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		game_socket.close()
		print("Deconnexion du jeu")
	clear_last_game_state()

# Alias pour compatibilite
func disconnect_from_server() -> void:
	disconnect_from_game()

# ============================================================================
# CONNEXION AU LOBBY
# ============================================================================

func connect_to_lobby(player_id_param: String) -> void:
	"""
	Etablit une connexion WebSocket au lobby pour le chat
	URL : ws://djipi.club:8080/lobby?playerId={playerId}
	"""
	var full_url = SERVER_URL + "/lobby?playerId=" + player_id_param
	print("Connexion au lobby: ", full_url)

	var error = lobby_socket.connect_to_url(full_url)
	if error != OK:
		print("Erreur de connexion au lobby: ", error)

func disconnect_from_lobby() -> void:
	"""Ferme la connexion WebSocket au lobby"""
	if lobby_socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		lobby_socket.close()
		print("Deconnexion du lobby")

# ============================================================================
# GESTION DES MESSAGES - JEU
# ============================================================================

func _handle_game_message(message: String) -> void:
	"""Traite les messages JSON du serveur de jeu"""
	var json = JSON.new()
	var parse_result = json.parse(message)

	if parse_result != OK:
		print("Erreur de parsing JSON (jeu)")
		return

	var data = json.data
	if not data is Dictionary:
		print("Format de message invalide (jeu)")
		return

	var event_type = data.get("type", "")

	match event_type:
		"GAME_STATE_UPDATE":
			_handle_game_state_update(data)
		"ERROR":
			_handle_error(data)
		_:
			print("Type d'evenement jeu inconnu: ", event_type)

func _handle_game_state_update(data: Dictionary) -> void:
	"""Traite une mise a jour de l'etat du jeu"""
	var payload = data.get("payload", {})
	var game_state = payload.get("gameState", {})
	var player_rack = payload.get("playerRack", [])

	print("Etat du jeu mis a jour")
	print("  - Joueurs: ", game_state.get("players", []).size())
	print("  - Chevalet: ", player_rack.size(), " tuiles")
	print("  - Status: ", game_state.get("status", ""))

	last_game_state = payload
	game_state_received.emit(payload)

func _handle_error(data: Dictionary) -> void:
	"""Traite un message d'erreur du serveur"""
	var payload = data.get("payload", {})
	var error_message = payload.get("message", "Erreur inconnue")

	print("Erreur du serveur: ", error_message)
	error_received.emit(error_message)

# ============================================================================
# GESTION DES MESSAGES - LOBBY
# ============================================================================

func _handle_lobby_message(message: String) -> void:
	"""Traite les messages JSON du lobby"""
	var json = JSON.new()
	var parse_result = json.parse(message)

	if parse_result != OK:
		print("Erreur de parsing JSON (lobby)")
		return

	var data = json.data
	if not data is Dictionary:
		print("Format de message invalide (lobby)")
		return

	var event_type = data.get("type", "")

	match event_type:
		"CHAT_BROADCAST":
			_handle_chat_broadcast(data)
		"PLAYER_JOINED":
			_handle_player_joined(data)
		"PLAYER_LEFT":
			_handle_player_left(data)
		_:
			print("Type d'evenement lobby inconnu: ", event_type)

func _handle_chat_broadcast(data: Dictionary) -> void:
	"""Traite un message de chat"""
	var payload = data.get("payload", {})
	var from_player = payload.get("from", "Inconnu")
	var msg = payload.get("message", "")
	var timestamp = payload.get("timestamp", 0)

	chat_message_received.emit(from_player, msg, timestamp)

func _handle_player_joined(data: Dictionary) -> void:
	"""Traite l'arrivee d'un joueur dans le lobby"""
	var payload = data.get("payload", {})
	var pname = payload.get("playerName", "Inconnu")
	player_joined_lobby.emit(pname)

func _handle_player_left(data: Dictionary) -> void:
	"""Traite le depart d'un joueur du lobby"""
	var payload = data.get("payload", {})
	var pname = payload.get("playerName", "Inconnu")
	player_left_lobby.emit(pname)

# ============================================================================
# ENVOI DE MESSAGES - JEU
# ============================================================================

func send_game_event(event_type: String, payload: Dictionary = {}) -> void:
	"""Envoie un evenement au serveur de jeu"""
	if game_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("Impossible d'envoyer: non connecte au jeu")
		return

	var event = {
		"type": event_type,
		"payload": payload
	}

	var json_string = JSON.stringify(event)
	print("Envoi (jeu): ", json_string)
	game_socket.send_text(json_string)

# Alias pour compatibilite
func send_event(event_type: String, payload: Dictionary = {}) -> void:
	send_game_event(event_type, payload)

# ============================================================================
# ENVOI DE MESSAGES - LOBBY
# ============================================================================

func send_chat_message(message: String) -> void:
	"""Envoie un message dans le chat du lobby"""
	if lobby_socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("Impossible d'envoyer: non connecte au lobby")
		return

	var event = {
		"type": "CHAT_MESSAGE",
		"payload": {
			"message": message
		}
	}

	var json_string = JSON.stringify(event)
	print("Envoi (lobby): ", json_string)
	lobby_socket.send_text(json_string)

# ============================================================================
# ACTIONS DE JEU (specifiques Scrabble, mais utilisables par d'autres jeux)
# ============================================================================

func start_game() -> void:
	"""Demande au serveur de demarrer la partie"""
	send_game_event("START_GAME")

func play_move(placed_tiles: Array) -> void:
	"""Envoie un coup au serveur pour validation"""
	var payload = {
		"placedTiles": placed_tiles
	}
	send_game_event("PLAY_MOVE", payload)

func pass_turn() -> void:
	"""Passe son tour"""
	send_game_event("PASS_TURN")

func exchange_tiles(tiles: Array) -> void:
	"""Envoie une demande d'echange de lettres"""
	var payload = {
		"tilesToExchange": tiles
	}
	send_game_event("EXCHANGE_TILES", payload)

# ============================================================================
# GESTION DE L'ETAT STOCKE
# ============================================================================

func get_last_game_state() -> Dictionary:
	"""Recupere le dernier etat recu"""
	return last_game_state

func clear_last_game_state() -> void:
	"""Efface l'etat stocke"""
	last_game_state = {}

func has_stored_state() -> bool:
	"""Verifie si un etat est stocke"""
	return not last_game_state.is_empty()

# ============================================================================
# UTILITAIRES
# ============================================================================

func is_connected_to_game() -> bool:
	"""Verifie si on est connecte au serveur de jeu"""
	return game_socket.get_ready_state() == WebSocketPeer.STATE_OPEN

func is_connected_to_lobby() -> bool:
	"""Verifie si on est connecte au lobby"""
	return lobby_socket.get_ready_state() == WebSocketPeer.STATE_OPEN

# Alias pour compatibilite
func is_connected_to_server() -> bool:
	return is_connected_to_game()

func get_connection_status_string() -> String:
	"""Retourne le statut de connexion au jeu en texte"""
	match game_socket.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			return "Connexion en cours..."
		WebSocketPeer.STATE_OPEN:
			return "Connecte"
		WebSocketPeer.STATE_CLOSING:
			return "Deconnexion..."
		WebSocketPeer.STATE_CLOSED:
			return "Deconnecte"
		_:
			return "Statut inconnu"
