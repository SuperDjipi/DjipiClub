extends Node2D

# ============================================================================
# SCRABBLE GAME - VERSION MULTIJOUEUR POUR DJIPI CLUB HUB
# ============================================================================

# --- MODULES DU JEU ---
var tile_manager: TileManager
var board_manager: BoardManager
var rack_manager: RackManager
var drag_drop_controller: DragDropController
var game_state_sync: GameStateSync
var move_validator: MoveValidator
var scrabble_config: Node
var popup_active: bool = false

# --- REFERENCES RESEAU ---
@onready var network_manager = $"/root/NetworkManager"

# --- VARIABLES GLOBALES ---
var viewport_size: Vector2

# --- REFERENCES UI (depuis la scene) ---
@onready var score_board_container = $CanvasLayer/MainContainer/VBoxContainer/TopContainer/ScoreBoard
@onready var back_button = $CanvasLayer/MainContainer/VBoxContainer/TopContainer/BackButton
@onready var validation_label = $CanvasLayer/MainContainer/VBoxContainer/ValidationPanel/MarginContainer/ValidationLabel
@onready var board_container = $CanvasLayer/MainContainer/VBoxContainer/BoardContainer
@onready var rack_container = $CanvasLayer/MainContainer/VBoxContainer/RackContainer
@onready var undo_button = $CanvasLayer/MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/UndoButton
@onready var shuffle_button = $CanvasLayer/MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/ShuffleButton
@onready var pass_button = $CanvasLayer/MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/PassButton
@onready var play_button = $CanvasLayer/MainContainer/VBoxContainer/ActionButtons/MarginContainer/HBoxContainer/PlayButton

# ============================================================================
# FONCTION : Initialisation du jeu
# ============================================================================
func _ready():
	randomize()
	viewport_size = get_viewport_rect().size

	print("Demarrage du jeu de Scrabble (Mode Multijoueur - DjipiClub Hub)")

	# Verifier qu'on est bien connecte
	if not network_manager.is_connected_to_game():
		print("ERREUR : Pas de connexion au serveur !")
		print("   Retour au lobby...")
		get_tree().change_scene_to_file("res://scenes/hub/lobby.tscn")
		return

	# 0. Creer et initialiser ScrabbleConfig
	scrabble_config = preload("res://scripts/games/scrabble/ScrabbleConfig.gd").new()
	add_child(scrabble_config)

	# 1. Creer et initialiser le TileManager
	tile_manager = preload("res://scripts/games/scrabble/TileManager.gd").new()
	add_child(tile_manager)

	# 2. Creer et initialiser le RackManager
	rack_manager = preload("res://scripts/games/scrabble/RackManager.gd").new()
	add_child(rack_manager)
	rack_manager.initialize(viewport_size, tile_manager, scrabble_config)

	# 3. Creer et initialiser le BoardManager
	board_manager = preload("res://scripts/games/scrabble/BoardManager.gd").new()
	add_child(board_manager)
	board_manager.initialize(viewport_size, rack_manager.tile_size_rack, scrabble_config)
	board_manager.create_board(board_container)
	rack_manager.create_rack(rack_container)

	# 4. Creer et initialiser le MoveValidator
	move_validator = preload("res://scripts/games/scrabble/MoveValidator.gd").new()
	add_child(move_validator)
	move_validator.initialize(board_manager, scrabble_config)

	# 5. Creer et initialiser le DragDropController
	drag_drop_controller = preload("res://scripts/games/scrabble/DragDropController.gd").new()
	add_child(drag_drop_controller)
	drag_drop_controller.initialize(board_manager, rack_manager, tile_manager, scrabble_config)

	# 6. Creer et initialiser le GameStateSync
	game_state_sync = preload("res://scripts/games/scrabble/GameStateSync.gd").new()
	add_child(game_state_sync)
	game_state_sync.initialize(network_manager, self, board_manager, rack_manager, drag_drop_controller, scrabble_config)

	# Connexion aux signaux de synchronisation
	game_state_sync.game_started.connect(_on_game_started)
	game_state_sync.my_turn_started.connect(_on_my_turn_started)
	game_state_sync.my_turn_ended.connect(_on_my_turn_ended)
	game_state_sync.game_ended.connect(_on_game_ended)

	# 7. Connecter les boutons
	_connect_buttons()

	# 8. Initialiser l'UI
	_initialize_ui()

	# Forcer explicitement l'etat unfocused apres l'initialisation complete
	call_deferred("_force_initial_view")
	print("Jeu initialise avec succes !")

func _force_initial_view() -> void:
	"""Force la vue initiale (unfocused) apres l'initialisation"""
	board_manager.is_board_focused = true
	board_manager.animate_to_rack_view()
	print("En attente du demarrage de la partie...")

# ============================================================================
# FONCTION : Connecter les boutons
# ============================================================================
func _connect_buttons() -> void:
	undo_button.pressed.connect(_on_undo_pressed)
	shuffle_button.pressed.connect(_on_shuffle_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	play_button.pressed.connect(_on_play_pressed)
	back_button.pressed.connect(_on_back_pressed)

# ============================================================================
# FONCTION : Initialiser l'UI
# ============================================================================
func _initialize_ui() -> void:
	validation_label.text = ""
	validation_label.modulate = Color(1, 1, 1, 0)

	undo_button.disabled = false
	shuffle_button.disabled = false
	pass_button.disabled = true
	play_button.disabled = true

	_show_waiting_message()

# ============================================================================
# FONCTION : Gestion des entrees utilisateur
# ============================================================================
func _input(event):
	if popup_active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_drop_controller.start_drag(event.position, self)
			else:
				drag_drop_controller.end_drag(event.position, self)
				if not _has_unassigned_joker():
					_validate_current_move()

	elif event is InputEventMouseMotion:
		drag_drop_controller.update_drag(event.position)

# ============================================================================
# FONCTION : Mise a jour continue
# ============================================================================
func _process(_delta):
	if game_state_sync:
		_update_score_display()

# ============================================================================
# FONCTION : Valider le mouvement actuel
# ============================================================================
func _validate_current_move() -> void:
	var temp_tiles = drag_drop_controller.get_temp_tiles()

	if temp_tiles.is_empty():
		_hide_validation_ui()
		undo_button.disabled = true
		animate_to_rack_view()
		return
	undo_button.disabled = false
	var validation_result = move_validator.validate_move(temp_tiles)
	_show_validation_result(validation_result)

# ============================================================================
# FONCTION : Afficher le resultat de validation
# ============================================================================
func _show_validation_result(result: Dictionary) -> void:
	var message = ""

	if result.rule_error != "":
		message = "[color=#e74c3c]X %s[/color]" % result.rule_error

	elif result.words.size() > 0:
		for word_info in result.words:
			if word_info.valid:
				message += "<[color=#2ecc71]V %s[/color] [color=#95a5a6]%d pts[/color]>" % [word_info.text, word_info.score]
			else:
				message += "<[color=#e74c3c]X %s[/color]>" % word_info.text

		if result.bonus_scrabble > 0:
			message += "[color=#f39c12]* BONUS[/color]"

		if result.valid and result.total_score > 0:
			message += "\n[color=#bdc3c7]----------[/color]\n"
			message += "[color=#27ae60][b]%d points[/b][/color]" % result.total_score

	else:
		message = "[color=#e74c3c]X Aucun mot forme[/color]"

	validation_label.text = message
	validation_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if result.valid:
		play_button.disabled = not (game_state_sync and game_state_sync.is_my_turn)
		undo_button.disabled = false
	else:
		play_button.disabled = true
		undo_button.disabled = false

# ============================================================================
# FONCTION : Cacher l'UI de validation
# ============================================================================
func _hide_validation_ui() -> void:
	var tween = validation_label.create_tween()
	tween.tween_property(validation_label, "modulate:a", 0.0, 0.3)
	undo_button.disabled = true

# ============================================================================
# FONCTION : Retourner les tuiles temporaires au chevalet
# ============================================================================
func _return_temp_tiles_to_rack() -> void:
	var temp_tiles = drag_drop_controller.get_temp_tiles().duplicate()
	print("  Retour de ", temp_tiles.size(), " tuile(s) au chevalet")
	for pos in temp_tiles:
		var tile_data = board_manager.get_tile_at(pos)
		var cell = board_manager.get_cell_at(pos)
		var tile_node = TileManager.get_tile_in_cell(cell)

		if tile_node and tile_data:
			if tile_data.is_joker and tile_data.assigned_letter != null:
				tile_data.assigned_letter = null
				_reset_joker_visual(tile_node)
			var placed = false
			for i in range(scrabble_config.RACK_SIZE):
				if rack_manager.get_tile_at(i) == null:
					rack_manager.add_tile_at(i, tile_data)
					_animate_tile_to_rack(tile_node, tile_data, i)
					board_manager.set_tile_at(pos, null)
					placed = true
					break
			if not placed:
				print("    ERREUR : Pas de place dans le chevalet pour ", tile_data.letter)
		else:
			print("    Tuile manquante a la position ", pos)

	drag_drop_controller.get_temp_tiles().clear()
	print("  Toutes les tuiles rappelees")

# ============================================================================
# FONCTION : Animer le retour d'une tuile au chevalet
# ============================================================================
func _animate_tile_to_rack(tile_node: Panel, tile_data: Dictionary, rack_index: int) -> void:
	tile_node.reparent(self)
	tile_node.z_index = 100

	var target_cell = rack_manager.get_cell_at(rack_index)
	var target_pos = target_cell.global_position + Vector2(2, 2)

	var tween = tile_node.create_tween()
	tween.set_parallel(true)

	tween.tween_property(tile_node, "global_position", target_pos, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var target_size = Vector2(rack_manager.tile_size_rack - 4, rack_manager.tile_size_rack - 4)
	tween.tween_property(tile_node, "custom_minimum_size", target_size, 0.3)

	var letter_lbl = tile_node.get_node_or_null("LetterLabel")
	var value_lbl = tile_node.get_node_or_null("ValueLabel")
	if letter_lbl and value_lbl:
		tween.tween_property(letter_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.2, rack_manager.tile_size_rack * 0.05), 0.3)
		tween.tween_property(value_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.6, rack_manager.tile_size_rack * 0.55), 0.3)

	tween.tween_property(tile_node, "modulate", Color(1, 1, 1), 0.3)

	tween.finished.connect(func():
		tile_node.reparent(target_cell)
		tile_node.position = Vector2(2, 2)
		tile_node.z_index = 0
		tile_node.remove_meta("temp")
	)

# ============================================================================
# CALLBACKS BOUTONS UI
# ============================================================================

func _on_undo_pressed() -> void:
	print("Rappel des tuiles au chevalet...")
	var temp_tiles = drag_drop_controller.get_temp_tiles()
	if temp_tiles.is_empty():
		print("  Aucune tuile a rappeler")
		return
	print("  Rappel de ", temp_tiles.size(), " tuile(s)")
	_return_temp_tiles_to_rack()
	_hide_validation_ui()
	animate_to_rack_view()
	play_button.disabled = true

func _on_shuffle_pressed() -> void:
	print("Melange du chevalet...")
	rack_manager.shuffle_rack()

func _on_pass_pressed() -> void:
	print("Ouverture du dialogue de passage...")
	_show_pass_dialog()

func _show_pass_dialog() -> void:
	var canvas_layer = get_node_or_null("CanvasLayer")

	if not canvas_layer:
		print("ERREUR : CanvasLayer introuvable !")
		return
	popup_active = true
	var remaining_tiles = game_state_sync.get_remaining_tiles_in_bag()
	var selected_indices = []

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = viewport_size
	overlay.position = Vector2.ZERO
	overlay.name = "PassOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_layer.add_child(overlay)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(viewport_size.x - 10, 450)
	panel.position = (viewport_size - panel.custom_minimum_size) / 2
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = panel.size - Vector2(40, 40)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Passer votre tour"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	var info_label = Label.new()
	var message = "Tuiles restantes dans le sac : %d" % remaining_tiles
	message = "Plus de tuiles dans le sac" if (remaining_tiles == 0) else message
	info_label.text = message
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info_label)

	if (remaining_tiles > 0):
		var spacer2 = Control.new()
		spacer2.custom_minimum_size = Vector2(0, 10)
		vbox.add_child(spacer2)

		var instruction = Label.new()
		instruction.text = "Cliquez sur les lettres a echanger (0 a 7)"
		instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(instruction)

		var spacer3 = Control.new()
		spacer3.custom_minimum_size = Vector2(0, 10)
		vbox.add_child(spacer3)

		var rack_container_popup = HBoxContainer.new()
		rack_container_popup.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(rack_container_popup)

		for i in range(scrabble_config.RACK_SIZE):
			var tile_data = rack_manager.get_tile_at(i)
			if tile_data:
				var tile_button = _create_selectable_tile(tile_data, i, selected_indices)
				rack_container_popup.add_child(tile_button)
			else:
				var empty = Panel.new()
				empty.custom_minimum_size = Vector2(60, 60)
				empty.modulate = Color(0.5, 0.5, 0.5, 0.3)
				rack_container_popup.add_child(empty)

		var spacer4 = Control.new()
		spacer4.custom_minimum_size = Vector2(0, 20)
		vbox.add_child(spacer4)

		var feedback = Label.new()
		feedback.name = "FeedbackLabel"
		feedback.text = "Aucune lettre selectionnee"
		feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(feedback)

	var spacer5 = Control.new()
	spacer5.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer5)

	var button_container = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_container)

	var cancel_button = Button.new()
	cancel_button.text = "Annuler"
	cancel_button.custom_minimum_size = Vector2(120, 40)
	cancel_button.pressed.connect(func():
		overlay.queue_free()
		popup_active = false
	)
	button_container.add_child(cancel_button)

	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(10, 0)
	button_container.add_child(button_spacer)

	var pass_only_button = Button.new()
	pass_only_button.text = "Passer sans echanger"
	pass_only_button.custom_minimum_size = Vector2(180, 40)
	pass_only_button.pressed.connect(func():
		overlay.queue_free()
		popup_active = false
		game_state_sync.pass_turn()
	)
	button_container.add_child(pass_only_button)

	var button_spacer2 = Control.new()
	button_spacer2.custom_minimum_size = Vector2(10, 0)
	button_container.add_child(button_spacer2)

	if (remaining_tiles > 0):
		var exchange_button = Button.new()
		exchange_button.text = "Echanger et passer"
		exchange_button.custom_minimum_size = Vector2(180, 40)
		exchange_button.disabled = true
		exchange_button.name = "ExchangeButton"
		exchange_button.pressed.connect(func():
			if selected_indices.is_empty():
				return
			overlay.queue_free()
			popup_active = false
			game_state_sync.exchange_tiles(selected_indices)
		)
		button_container.add_child(exchange_button)

func _create_selectable_tile(tile_data: Dictionary, index: int, selected_indices: Array) -> Button:
	var tile_button = Button.new()
	tile_button.custom_minimum_size = Vector2(60, 60)
	tile_button.modulate = Color(0.95, 0.9, 0.7)

	var letter_lbl = Label.new()
	letter_lbl.text = tile_data.letter
	letter_lbl.add_theme_font_size_override("font_size", 30)
	letter_lbl.position = Vector2(12, 3)
	letter_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_button.add_child(letter_lbl)

	var value_lbl = Label.new()
	var value = tile_data.value
	if value == floor(value):
		value_lbl.text = str(int(value))
	else:
		value_lbl.text = "%.1f" % value
	value_lbl.add_theme_font_size_override("font_size", 15)
	value_lbl.position = Vector2(36, 33)
	value_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_button.add_child(value_lbl)

	tile_button.pressed.connect(func():
		_toggle_tile_selection(tile_button, index, selected_indices)
	)

	return tile_button

func _toggle_tile_selection(tile_button: Button, index: int, selected_indices: Array) -> void:
	var canvas_layer = get_node_or_null("CanvasLayer")

	if not canvas_layer:
		print("ERREUR : CanvasLayer introuvable !")
		return
	var overlay = canvas_layer.get_node_or_null("PassOverlay")
	if not overlay:
		return

	var feedback = overlay.find_child("FeedbackLabel", true, false)
	var exchange_button = overlay.find_child("ExchangeButton", true, false)

	if index in selected_indices:
		selected_indices.erase(index)
		tile_button.modulate = Color(0.95, 0.9, 0.7)
	else:
		selected_indices.append(index)
		tile_button.modulate = Color(1.0, 1.0, 0.3)

	if selected_indices.is_empty():
		feedback.text = "Aucune lettre selectionnee %d" % index
		exchange_button.disabled = true
	else:
		feedback.text = "%d lettre(s) selectionnee(s)" % selected_indices.size()
		exchange_button.disabled = false

func _on_play_pressed() -> void:
	print("Envoi du coup au serveur...")
	game_state_sync.send_move_to_server()

	play_button.disabled = true
	pass_button.disabled = true
	undo_button.disabled = true

	var temp_tiles = drag_drop_controller.get_temp_tiles()
	for pos in temp_tiles:
		var cell = board_manager.get_cell_at(pos)
		var tile_node = TileManager.get_tile_in_cell(cell)
		if tile_node:
			tile_node.remove_meta("temp")
			tile_node.modulate = Color(1, 1, 1)

	drag_drop_controller.get_temp_tiles().clear()


func _on_back_pressed() -> void:
	print("Retour au lobby...")
	_return_to_lobby()

func _return_to_lobby() -> void:
	print("Retour au lobby...")

	if network_manager and network_manager.is_connected_to_game():
		print("Deconnexion du WebSocket...")
		network_manager.disconnect_from_game()

	await get_tree().create_timer(0.3).timeout

	print("Changement de scene vers lobby...")
	get_tree().change_scene_to_file("res://scenes/hub/lobby.tscn")

# ============================================================================
# FONCTION : Gestion du bouton Back Android
# ============================================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		print("Bouton Back Android presse")
		_on_back_pressed()
		get_tree().set_input_as_handled()

# ============================================================================
# CALLBACKS RESEAU
# ============================================================================

func _on_game_started() -> void:
	print("La partie a commence !")
	_create_score_board()

func _on_my_turn_started() -> void:
	shuffle_button.disabled = false
	pass_button.disabled = false
	play_button.disabled = true
	print("C'est votre tour de jouer !")

func _on_my_turn_ended() -> void:
	var current_player = game_state_sync.get_current_player_name()
	if not drag_drop_controller.get_temp_tiles().is_empty():
		print("Des tuiles temporaires etaient encore presentes...")
		_return_temp_tiles_to_rack()
	play_button.disabled = true
	pass_button.disabled = true
	_hide_validation_ui()
	animate_to_rack_view()
	print("Tour de ", current_player)

func _on_game_ended(winner_name: String) -> void:
	play_button.disabled = true
	pass_button.disabled = true
	undo_button.disabled = true
	shuffle_button.disabled = true
	_hide_validation_ui()
	print("Partie terminee ! Gagnant : ", winner_name)
	_show_end_game_popup(winner_name)

# ============================================================================
# FONCTION : Mettre a jour l'affichage des scores
# ============================================================================
func _update_score_display() -> void:
	if game_state_sync and game_state_sync.current_game_state.has("players"):
		_create_score_board()

# ============================================================================
# FONCTION : Creer le tableau des scores
# ============================================================================
func _create_score_board() -> void:
	for child in score_board_container.get_children():
		child.queue_free()

	var main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 10)
	score_board_container.add_child(main_hbox)

	var all_scores = game_state_sync.get_all_scores()

	for score_data in all_scores:
		var player_card = _create_player_card_horizontal(score_data, all_scores)
		main_hbox.add_child(player_card)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(spacer)

func _create_player_card_horizontal(score_data: Dictionary, all_scores: Array) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 60)

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	var current_player_name = game_state_sync.get_current_player_name()

	if score_data.name == current_player_name:
		style.bg_color = Color(0.85, 1.0, 0.85)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(1.3, 0.1, 1.3)
	elif score_data.is_me:
		style.bg_color = Color(0.85, 0.92, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.3, 0.4, 1.0)
	else:
		style.bg_color = Color(0.95, 0.95, 0.95)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.7, 0.7, 0.7)

	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var name_label = Label.new()
	name_label.text = score_data.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.8))

	if score_data.is_me:
		name_label.text = "Moi"
		name_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.8))

	vbox.add_child(name_label)

	var score_hbox = HBoxContainer.new()
	score_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(score_hbox)

	if score_data.name == current_player_name:
		var indicator = Label.new()
		indicator.text = "."
		indicator.add_theme_font_size_override("font_size", 14)
		indicator.add_theme_color_override("font_color", Color(0.4, 0.1, 0.6))
		score_hbox.add_child(indicator)

	var score_label = Label.new()
	score_label.text = str(int(score_data.score))
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	score_hbox.add_child(score_label)

	return panel

func _show_waiting_message() -> void:
	for child in score_board_container.get_children():
		child.queue_free()

	var center = CenterContainer.new()
	score_board_container.add_child(center)

	var label = Label.new()
	label.text = "Chargement ..."
	label.add_theme_font_size_override("font_size", 18)
	center.add_child(label)

func _show_end_game_popup(winner_name: String) -> void:
	var canvas_layer = get_node_or_null("CanvasLayer")

	if not canvas_layer:
		print("ERREUR : CanvasLayer introuvable !")
		return
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = viewport_size
	overlay.position = Vector2.ZERO
	canvas_layer.add_child(overlay)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 300)
	var panelWidth = (viewport_size.x - panel.custom_minimum_size.x) / 2
	panel.position = Vector2(panelWidth, 100)
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = panel.size - Vector2(40, 40)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Partie Terminee !"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var winner = Label.new()
	winner.text = "Gagnant : " + winner_name
	winner.add_theme_font_size_override("font_size", 20)
	winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(winner)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	var scores_title = Label.new()
	scores_title.text = "Scores finaux :"
	scores_title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(scores_title)

	var all_scores = game_state_sync.get_all_scores()
	all_scores.sort_custom(func(a, b): return a.score > b.score)

	for score_data in all_scores:
		var score_line = Label.new()
		var prefix = "1. " if score_data == all_scores[0] else "   "
		score_line.text = prefix + score_data.name + " : " + str(int(score_data.score)) + " points"
		score_line.add_theme_font_size_override("font_size", 16)
		vbox.add_child(score_line)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	var back_btn = Button.new()
	back_btn.text = "Retour au lobby"
	back_btn.custom_minimum_size = Vector2(200, 40)
	back_btn.pressed.connect(_on_back_to_menu)
	vbox.add_child(back_btn)

	var button_container = CenterContainer.new()
	button_container.add_child(back_btn)
	vbox.add_child(button_container)

func _on_back_to_menu() -> void:
	network_manager.disconnect_from_game()
	get_tree().change_scene_to_file("res://scenes/hub/lobby.tscn")

# ============================================================================
# FONCTION : Creer le popup de selection de lettre pour joker
# ============================================================================
func _create_joker_letter_popup(joker_pos: Vector2i, tile_node: Panel) -> void:
	print("Selection de lettre pour joker a la position ", joker_pos)
	var canvas_layer = get_node_or_null("CanvasLayer")

	if not canvas_layer:
		print("ERREUR : CanvasLayer introuvable !")
		return

	popup_active = true
	var overlay = ColorRect.new()
	overlay.name = "JokerOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = viewport_size
	overlay.position = Vector2.ZERO
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_layer.add_child(overlay)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 300)
	panel.position = (viewport_size - panel.custom_minimum_size) / 2
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = panel.size - Vector2(40, 40)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Choisissez une lettre pour le joker"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var grid_container = GridContainer.new()
	grid_container.columns = 7
	grid_container.add_theme_constant_override("h_separation", 5)
	grid_container.add_theme_constant_override("v_separation", 5)
	vbox.add_child(grid_container)

	for letter in letters:
		var button = Button.new()
		button.text = letter
		button.custom_minimum_size = Vector2(40, 40)
		button.add_theme_font_size_override("font_size", 18)

		button.pressed.connect(func():
			_on_joker_letter_selected(letter, joker_pos, tile_node, overlay)
		)

		grid_container.add_child(button)

	var cancel_button = Button.new()
	cancel_button.text = "Annuler"
	cancel_button.custom_minimum_size = Vector2(150, 40)
	cancel_button.pressed.connect(func():
		_on_joker_selection_cancelled(joker_pos, tile_node, overlay)
	)

	var button_center = CenterContainer.new()
	button_center.add_child(cancel_button)
	vbox.add_child(button_center)

func _on_joker_letter_selected(letter: String, joker_pos: Vector2i, tile_node: Panel, overlay: ColorRect) -> void:
	print("Lettre selectionnee pour joker : ", letter)

	var tile_data = board_manager.get_tile_at(joker_pos)
	if tile_data:
		tile_data.assigned_letter = letter
		_update_joker_visual(tile_node, letter)

	overlay.queue_free()
	popup_active = false
	_validate_current_move()

func _on_joker_selection_cancelled(joker_pos: Vector2i, tile_node: Panel, overlay: ColorRect) -> void:
	print("Selection annulee, retour du joker au chevalet")

	var tile_data = board_manager.get_tile_at(joker_pos)
	board_manager.set_tile_at(joker_pos, null)
	drag_drop_controller.get_temp_tiles().erase(joker_pos)

	if tile_data:
		for i in range(scrabble_config.RACK_SIZE):
			if rack_manager.get_tile_at(i) == null:
				rack_manager.add_tile_at(i, tile_data)
				_animate_tile_to_rack(tile_node, tile_data, i)
				break

	overlay.queue_free()
	popup_active = false
	_validate_current_move()

func _has_unassigned_joker() -> bool:
	var temp_tiles = drag_drop_controller.get_temp_tiles()

	for pos in temp_tiles:
		var tile_data = board_manager.get_tile_at(pos)
		if tile_data and tile_data.is_joker and tile_data.assigned_letter == null:
			return true

	return false

func _reset_joker_visual(tile_node: Panel) -> void:
	var letter_lbl = tile_node.get_node_or_null("LetterLabel")
	if letter_lbl:
		letter_lbl.text = "?"

	var joker_indicator = tile_node.get_node_or_null("JokerIndicator")
	if joker_indicator:
		joker_indicator.queue_free()

func _update_joker_visual(tile_node: Panel, assigned_letter: String) -> void:
	var letter_lbl = tile_node.get_node_or_null("LetterLabel")

	if letter_lbl:
		letter_lbl.text = assigned_letter

func _show_server_error(error_message: String) -> void:
	print("Affichage erreur serveur : ", error_message)

	var canvas_layer = get_node_or_null("CanvasLayer")
	if not canvas_layer:
		return

	var overlay = ColorRect.new()
	overlay.name = "ErrorOverlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = viewport_size
	overlay.position = Vector2.ZERO
	canvas_layer.add_child(overlay)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 200)
	panel.position = (viewport_size - panel.custom_minimum_size) / 2
	overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	vbox.size = panel.size - Vector2(40, 40)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "Erreur"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(title)

	var message = Label.new()
	message.text = error_message
	message.add_theme_font_size_override("font_size", 16)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(message)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var ok_button = Button.new()
	ok_button.text = "OK"
	ok_button.custom_minimum_size = Vector2(150, 40)
	ok_button.pressed.connect(func():
		overlay.queue_free()
	)

	var button_center = CenterContainer.new()
	button_center.add_child(ok_button)
	vbox.add_child(button_center)

# ============================================================================
# FONCTIONS D'ANIMATION
# ============================================================================

func animate_to_board_view(col_shift) -> void:
	board_manager.animate_to_board_view(col_shift)

func animate_to_rack_view() -> void:
	board_manager.animate_to_rack_view()
