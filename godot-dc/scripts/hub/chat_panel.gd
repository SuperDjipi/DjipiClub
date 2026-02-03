# chat_panel.gd
# Composant de chat reutilisable pour le lobby
extends VBoxContainer

# ============================================================================
# REFERENCES AUX NOEUDS
# ============================================================================

@onready var messages_scroll = $MessagesPanel/MessagesScroll
@onready var messages_container = $MessagesPanel/MessagesScroll/MessagesContainer
@onready var message_input = $InputContainer/MessageInput
@onready var send_button = $InputContainer/SendButton

# ============================================================================
# CONSTANTES
# ============================================================================

const MAX_MESSAGES = 100
const MESSAGE_COLORS = {
	"system": Color(0.5, 0.5, 0.5),
	"self": Color(0.3, 0.8, 0.3),
	"other": Color(0.8, 0.8, 0.8)
}

# ============================================================================
# VARIABLES
# ============================================================================

var messages: Array = []

# ============================================================================
# INITIALISATION
# ============================================================================

func _ready():
	# Connexion des signaux UI
	send_button.pressed.connect(_on_send_pressed)
	message_input.text_submitted.connect(_on_message_submitted)

	# Connexion aux signaux du NetworkManager pour le chat
	NetworkManager.chat_message_received.connect(_on_chat_message_received)
	NetworkManager.player_joined_lobby.connect(_on_player_joined)
	NetworkManager.player_left_lobby.connect(_on_player_left)
	NetworkManager.lobby_connected.connect(_on_lobby_connected)
	NetworkManager.lobby_disconnected.connect(_on_lobby_disconnected)

	# Style du panel de messages
	_setup_style()

	print("ChatPanel initialisé")

func _setup_style():
	"""Configure le style du panel de messages"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.7)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.2, 0.25)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5

	var panel = $MessagesPanel
	panel.add_theme_stylebox_override("panel", style)

# ============================================================================
# ENVOI DE MESSAGES
# ============================================================================

func _on_send_pressed():
	"""Appele quand on clique sur Envoyer"""
	_send_message()

func _on_message_submitted(text: String):
	"""Appele quand on appuie sur Entree dans le champ de texte"""
	_send_message()

func _send_message():
	"""Envoie le message saisi"""
	var text = message_input.text.strip_edges()

	if text.is_empty():
		return

	# Envoyer via NetworkManager
	NetworkManager.send_chat_message(text)

	# Vider le champ de saisie
	message_input.text = ""
	message_input.grab_focus()

# ============================================================================
# RECEPTION DE MESSAGES
# ============================================================================

func _on_chat_message_received(from_player: String, message: String, timestamp: int):
	"""Appele quand un message de chat est recu"""
	var is_self = (from_player == PlayerSession.player_name)
	var color = MESSAGE_COLORS["self"] if is_self else MESSAGE_COLORS["other"]

	_add_message(from_player, message, color, timestamp)

func _on_player_joined(player_name: String):
	"""Appele quand un joueur rejoint le lobby"""
	_add_system_message(player_name + " a rejoint le lobby")

func _on_player_left(player_name: String):
	"""Appele quand un joueur quitte le lobby"""
	_add_system_message(player_name + " a quitté le lobby")

func _on_lobby_connected():
	"""Appele quand on se connecte au lobby"""
	_add_system_message("Connecté au chat")

func _on_lobby_disconnected():
	"""Appele quand on se deconnecte du lobby"""
	_add_system_message("Déconnecté du chat")

# ============================================================================
# AFFICHAGE DES MESSAGES
# ============================================================================

func _add_message(from_player: String, message: String, color: Color, timestamp: int = 0):
	"""Ajoute un message dans l'affichage"""
	var time_str = ""
	if timestamp > 0:
		var datetime = Time.get_datetime_dict_from_unix_time(timestamp)
		time_str = "[%02d:%02d] " % [datetime.hour, datetime.minute]

	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var color_hex = color.to_html(false)
	label.text = "[color=#888888]%s[/color][color=#%s][b]%s:[/b][/color] %s" % [time_str, color_hex, from_player, message]

	messages_container.add_child(label)
	messages.append(label)

	# Limiter le nombre de messages
	_cleanup_old_messages()

	# Scroll vers le bas
	await get_tree().process_frame
	messages_scroll.scroll_vertical = messages_scroll.get_v_scroll_bar().max_value

func _add_system_message(message: String):
	"""Ajoute un message systeme"""
	var label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	label.text = "[i][color=#666666]" + message + "[/color][/i]"

	messages_container.add_child(label)
	messages.append(label)

	_cleanup_old_messages()

	await get_tree().process_frame
	messages_scroll.scroll_vertical = messages_scroll.get_v_scroll_bar().max_value

func _cleanup_old_messages():
	"""Supprime les messages les plus anciens si la limite est atteinte"""
	while messages.size() > MAX_MESSAGES:
		var old_msg = messages.pop_front()
		if is_instance_valid(old_msg):
			old_msg.queue_free()

# ============================================================================
# UTILITAIRES
# ============================================================================

func clear_messages():
	"""Efface tous les messages"""
	for msg in messages:
		if is_instance_valid(msg):
			msg.queue_free()
	messages.clear()

func set_enabled(enabled: bool):
	"""Active ou desactive le chat"""
	message_input.editable = enabled
	send_button.disabled = not enabled
