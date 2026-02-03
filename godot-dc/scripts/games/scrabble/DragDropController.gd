extends Node
class_name DragDropController

# ============================================================================
# CONTRÔLEUR DE DRAG & DROP
# ============================================================================
# Ce module gère :
# - Le drag & drop des tuiles
# - Les animations de resize pendant le drag
# - La détection des zones de dépôt
# - La gestion des tuiles temporaires
# ============================================================================

# References aux managers
var board_manager: BoardManager
var rack_manager: RackManager
var tile_manager: TileManager
var scrabble_config: Node

# Etat du drag
var dragging_tile: Panel = null
var drag_origin: Dictionary = {}
var temp_tiles: Array = []

# Position actuelle de la souris (pour auto-scroll)
var current_mouse_pos: Vector2 = Vector2.ZERO

# ============================================================================
# FONCTION : Initialiser le controleur
# ============================================================================
func initialize(board_mgr: BoardManager, rack_mgr: RackManager, tile_mgr: TileManager, config: Node) -> void:
	board_manager = board_mgr
	rack_manager = rack_mgr
	tile_manager = tile_mgr
	scrabble_config = config

# ============================================================================
# FONCTION : Boucle de mise à jour (appelée à chaque frame)
# ============================================================================
# Cette fonction s'exécute environ 60 fois par seconde et permet :
# - L'auto-scroll continu et fluide pendant le drag
# - Pas besoin de bouger la souris, juste maintenir la tuile près du bord
# ============================================================================
func _process(_delta):
	# Auto-scroll continu quand on drag une tuile
	current_mouse_pos = get_viewport().get_mouse_position()
	if dragging_tile and board_manager.is_board_focused:
		board_manager.auto_scroll_board(current_mouse_pos)

# ============================================================================
# FONCTION : Démarrer un drag
# ============================================================================
func start_drag(pos: Vector2, parent: Node2D) -> void:
	print("=== Start drag at position:", pos)
	
	# 1. Vérifier le chevalet
	# NOTE: Le déplacement intra-chevalet est commenté pour l'instant
	# TODO: Réimplémenter le déplacement intra-chevalet avec gestion correcte des swaps
	var rack_index = rack_manager.is_position_in_rack(pos)
	if rack_index >= 0:
		var tile_data = rack_manager.get_tile_at(rack_index)
		if tile_data:
			var cell = rack_manager.get_cell_at(rack_index)
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node:
				print("  -> Found tile in rack at index", rack_index)
				_start_drag_from_rack(tile_node, rack_index, parent)
				return
	
	# 2. Vérifier le plateau
	var board_pos = board_manager.get_board_position_at(pos)
	if board_pos != null:
		var tile_data = board_manager.get_tile_at(board_pos)
		if tile_data:
			var cell = board_manager.get_cell_at(board_pos)
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node and tile_node.has_meta("temp"):
				print("  -> Found temp tile on board at", board_pos)
				_start_drag_from_board(tile_node, board_pos, parent)
				return

	# 3. Si on n'a trouvé AUCUNE tuile, et que le plateau est focus,
	#    alors on peut essayer de commencer le drag du plateau.
	if board_manager.is_board_focused:
		if board_manager.start_board_drag(pos):
			print("  -> Starting board drag.")
			return # On a réussi à commencer le drag du plateau, on sort.

	# 4. Si on arrive ici, c'est qu'on n'a rien pu faire.
	print("  -> No draggable element found at this position.")


# ============================================================================
# FONCTION PRIVÉE : Démarrer le drag depuis le chevalet
# ============================================================================
func _start_drag_from_rack(tile_node: Panel, index: int, parent: Node2D) -> void:
	dragging_tile = tile_node
	drag_origin = {"type": "rack", "pos": index}
	rack_manager.remove_tile_at(index)
	
	## Animer vers la vue plateau si nécessaire
	#if not board_manager.is_board_focused:
		#board_manager.animate_to_board_view()
	#
	## Redimensionner la tuile
	#var tile_tween = tile_node.create_tween()
	#var target_size = Vector2(board_manager.tile_size_board - 4, board_manager.tile_size_board - 4)
	#tile_tween.tween_property(tile_node, "custom_minimum_size", target_size, 0.2)
	#
	## Repositionner les labels
	#var letter_lbl = tile_node.get_node_or_null("LetterLabel")
	#var value_lbl = tile_node.get_node_or_null("ValueLabel")
	#if letter_lbl and value_lbl:
		#tile_tween.tween_property(letter_lbl, "position", Vector2(board_manager.tile_size_board * 0.2, board_manager.tile_size_board * 0.05), 0.2)
		#tile_tween.tween_property(value_lbl, "position", Vector2(board_manager.tile_size_board * 0.6, board_manager.tile_size_board * 0.55), 0.2)
	
	# ✅ Reparenter dans le CanvasLayer
	var drag_parent = _get_canvas_layer_for_drag(parent)
	tile_node.reparent(drag_parent)
	print("DnD dbg : start rack parent : ", parent)
	tile_node.z_index = 1000

# ============================================================================
# FONCTION PRIVÉE : Démarrer le drag depuis le plateau
# ============================================================================
func _start_drag_from_board(tile_node: Panel, pos: Vector2i, parent: Node2D) -> void:
	dragging_tile = tile_node
	drag_origin = {"type": "board", "pos": pos}
	board_manager.set_tile_at(pos, null)
	temp_tiles.erase(pos)
	
	# ✅ Reparenter dans le CanvasLayer
	var drag_parent = _get_canvas_layer_for_drag(parent)
	tile_node.reparent(drag_parent)
	print("DnD dbg : start board parent : ", parent)
	tile_node.z_index = 1000

# ============================================================================
# FONCTION : Mettre à jour le drag
# ============================================================================
func update_drag(pos: Vector2) -> void:
	
	if dragging_tile:
		var target_size = Vector2(board_manager.tile_size_board, board_manager.tile_size_board)
		dragging_tile.global_position = pos - target_size / 2
		
		# Auto-scroll si on est en mode plateau
#		if board_manager.is_board_focused:
#			board_manager.auto_scroll_board(pos)
	
	# Mise à jour du drag du plateau
	board_manager.update_board_drag(pos)

# ============================================================================
# FONCTION : Terminer le drag
# ============================================================================
func end_drag(pos: Vector2, parent: Node2D) -> void:
	# Terminer le drag du plateau
	if board_manager.is_dragging_board:
		board_manager.end_board_drag()
		print("  -> Board drag ended")
		return
	
	if not dragging_tile:
		return
	
	print("=== End drag at position:", pos)
	var dropped = false
	
	 # 1. Essayer de déposer sur le chevalet
	dropped = _try_drop_on_rack(pos)
	
	# 2. Essayer le plateau
	if not dropped:
		dropped = _try_drop_on_board(pos)
	
	# 3. Si toujours pas déposé, retourner à l'origine
	if not dropped:
		_return_to_origin()
	
	# Nettoyer l'état du drag
	dragging_tile = null
	drag_origin = {}

# ============================================================================
# FONCTION PRIVÉE : Essayer de déposer sur le chevalet
# ============================================================================
func _try_drop_on_rack(pos: Vector2) -> bool:
	var rack_index = rack_manager.is_position_in_rack(pos)
	if rack_index >= 0:
		print("  -> Dropping on rack at index", rack_index)
		
		var tile_data = dragging_tile.get_meta("tile_data")
		var is_from_rack = (drag_origin.type == "rack")
		var origin_index = drag_origin.pos if is_from_rack else -1
				
		# ✅ Réinitialiser le joker si on le ramène du plateau
		if drag_origin.type == "board" and tile_data.is_joker and tile_data.assigned_letter != null:
			print("    Réinitialisation du joker")
			tile_data.assigned_letter = null
			# Appeler la fonction du ScrabbleGame
			var game = get_parent()
			print("DnD dbg : try_drop rack parent : ", game)
			if game.has_method("_reset_joker_visual"):
				game._reset_joker_visual(dragging_tile)
		
		# Cas 1 : On dépose sur la même case d'origine (simple retour)
		if is_from_rack and origin_index == rack_index:
			print("  -> Dropping on same slot, simple replacement")
			rack_manager.add_tile_at(rack_index, tile_data)
			_resize_tile_for_rack(dragging_tile, rack_index)
			return true
		
		# Cas 2 : Insertion avec décalage
		if _can_insert_in_rack(is_from_rack):
			_insert_tile_in_rack(rack_index, tile_data, origin_index)
			_resize_tile_for_rack(dragging_tile, rack_index)
			return true
		else:
			print("  -> Cannot insert: rack is full")
			return false
	
	return false
	
	# ============================================================================
# FONCTION PRIVÉE : Vérifier si on peut insérer une tuile dans le rack
# ============================================================================
func _can_insert_in_rack(is_from_rack: bool) -> bool:
	# Si la tuile vient du rack, on a déjà une place libre (la sienne)
	if is_from_rack:
		return true
	
	# Sinon, vérifier qu'il y a au moins une case vide
	for i in range(scrabble_config.RACK_SIZE):
		if rack_manager.get_tile_at(i) == null:
			return true
	
	return false
	
# ============================================================================
# FONCTION PRIVÉE : Insérer une tuile dans le rack avec décalage
# ============================================================================
func _insert_tile_in_rack(target_index: int, tile_data: Dictionary, origin_index: int) -> void:
	print("    Inserting tile at index ", target_index, " (origin: ", origin_index, ")")
	
	var is_from_rack = (origin_index >= 0)
	
	# Étape 1 : Collecter toutes les tuiles SAUF celle qu'on déplace
	var other_tiles = []  # Tuiles qui ne bougent pas (ou qui se décalent)
	
	for i in range(scrabble_config.RACK_SIZE):
		if is_from_rack and i == origin_index:
			continue  # Ignorer la tuile d'origine
		
		var data = rack_manager.get_tile_at(i)
		if data != null:
			var cell = rack_manager.get_cell_at(i)
			var node = TileManager.get_tile_in_cell(cell)
			
			if node != null:
				other_tiles.append({
					"data": data,
					"node": node,
					"index": i
				})
	
	print("    Collected ", other_tiles.size(), " other tiles")
	
	# Étape 2 : Vider le rack
	for i in range(scrabble_config.RACK_SIZE):
		rack_manager.remove_tile_at(i)
	
	# Étape 3 : Placer la tuile draggée à target_index
	rack_manager.add_tile_at(target_index, tile_data)
	print("    Placed dragged tile at index ", target_index)
	
	# Étape 4 : Replacer les autres tuiles en évitant target_index
	var next_slot = 0
	for tile_info in other_tiles:
		# Trouver le prochain slot disponible
		while next_slot == target_index or next_slot >= scrabble_config.RACK_SIZE:
			next_slot += 1
			if next_slot >= scrabble_config.RACK_SIZE:
				break
		
		if next_slot >= scrabble_config.RACK_SIZE:
			print("    WARNING: No more slots available!")
			break
		
		var data = tile_info.data
		var node = tile_info.node
		var cell = rack_manager.get_cell_at(next_slot)
		
		rack_manager.add_tile_at(next_slot, data)
		
		if node != null:
			node.reparent(cell)
			node.position = Vector2(2, 2)
			node.z_index = 0
		
		print("    Placed tile at slot ", next_slot)
		next_slot += 1
	
	print("    Insert completed")
# ============================================================================
# FONCTION PRIVÉE : Animer le réarrangement du rack
# ============================================================================
func _animate_rack_reorganization(tiles_data: Array, tiles_nodes: Array) -> void:
	print("    Animating rack reorganization with ", tiles_data.size(), " tiles")
	
	var animation_duration = 0.2  # Durée de l'animation en secondes
	
	for i in range(min(tiles_data.size(), scrabble_config.RACK_SIZE)):
		var data = tiles_data[i]
		var node = tiles_nodes[i]
		var target_cell = rack_manager.get_cell_at(i)
		
		if node == null:
			print("    ERROR: null node at index ", i)
			continue
		
		# Ajouter les données au rack
		rack_manager.add_tile_at(i, data)
		
		# Calculer la position cible (globale)
		var target_global_pos = target_cell.global_position + Vector2(2, 2)
		
		# Créer l'animation
		var tween = node.create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		
		# Animer la position globale
		tween.tween_property(node, "global_position", target_global_pos, animation_duration)
		
		# À la fin de l'animation, reparenter correctement
		if node != dragging_tile:
			tween.finished.connect(func():
				_finalize_tile_position(node, target_cell, i)
			)
	
	print("    Animations started")
	
# ============================================================================
# FONCTION PRIVÉE : Finaliser la position d'une tuile après animation
# ============================================================================
func _finalize_tile_position(tile_node: Panel, cell: Panel, index: int) -> void:
	# Reparenter dans la cellule cible
	tile_node.reparent(cell)
	tile_node.position = Vector2(2, 2)
	tile_node.z_index = 0
	
	print("    Tile finalized at index ", index)
	
# ============================================================================
# FONCTION PRIVÉE : Échanger deux tuiles du chevalet
# ============================================================================
func _swap_rack_tiles(index_a: int, index_b: int) -> void:
	print("  -> Swapping rack tiles at indices ", index_a, " and ", index_b)
	
	# Récupérer les deux tuiles
	var tile_a_data = dragging_tile.get_meta("tile_data")
	var tile_b_data = rack_manager.get_tile_at(index_b)
	
	var cell_a = rack_manager.get_cell_at(index_a)
	var cell_b = rack_manager.get_cell_at(index_b)
	
	var tile_b_node = TileManager.get_tile_in_cell(cell_b)
	
	# Échanger les données
	rack_manager.add_tile_at(index_b, tile_a_data)
	rack_manager.add_tile_at(index_a, tile_b_data)
	
	# Replacer visuellement la tuile A (celle qu'on draggait)
	_resize_tile_for_rack(dragging_tile, index_b)
	
	# Déplacer visuellement la tuile B vers la position A
	if tile_b_node:
		tile_b_node.reparent(cell_a)
		tile_b_node.position = Vector2(2, 2)
		
# ============================================================================
# FONCTION PRIVÉE : Redimensionner une tuile pour le chevalet
# ============================================================================
func _resize_tile_for_rack(tile_node: Panel, rack_index: int) -> void:
	print("    [_resize_tile_for_rack] Resizing tile for rack index ", rack_index)
	# Redimensionner la tuile pour le chevalet
	var tween = tile_node.create_tween()
	var target_size = Vector2(rack_manager.tile_size_rack - 4, rack_manager.tile_size_rack - 4)
	tween.tween_property(tile_node, "custom_minimum_size", target_size, 0.2)
	
	# Repositionner les labels
	var letter_lbl = tile_node.get_node_or_null("LetterLabel")
	var value_lbl = tile_node.get_node_or_null("ValueLabel")
	if letter_lbl and value_lbl:
		tween.tween_property(letter_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.2, rack_manager.tile_size_rack * 0.05), 0.2)
		tween.tween_property(value_lbl, "position", Vector2(rack_manager.tile_size_rack * 0.6, rack_manager.tile_size_rack * 0.55), 0.2)
	
	var cell = rack_manager.get_cell_at(rack_index)
	tile_node.reparent(cell)
	tile_node.position = Vector2(2, 2)
	tile_node.z_index = 0
	tile_node.remove_meta("temp")
	print("    [_resize_tile_for_rack] Done")

# ============================================================================
# FONCTION PRIVÉE : Essayer de déposer sur le plateau
# ============================================================================
func _try_drop_on_board(pos: Vector2) -> bool:
	var board_pos = board_manager.get_board_position_at(pos)
	if board_pos != null and board_manager.get_tile_at(board_pos) == null:
		print("  -> Dropping on board at", board_pos)
		# ✅ NOUVEAU : Passer en mode focused au premier drop sur le plateau
		if not board_manager.is_board_focused:
			board_manager.animate_to_board_view(board_pos.x)
		var tile_data = dragging_tile.get_meta("tile_data")
		board_manager.set_tile_at(board_pos, tile_data)
		
		var cell = board_manager.get_cell_at(board_pos)
		dragging_tile.reparent(cell)
		dragging_tile.position = Vector2(2, 2)
		dragging_tile.z_index = 0
		dragging_tile.set_meta("temp", true)
		
		if not temp_tiles.has(board_pos):
			temp_tiles.append(board_pos)
				
		# ✅ NOUVEAU : Si c'est un joker, demander la lettre
		if tile_data.is_joker and tile_data.assigned_letter == null:
			# Appeler le popup via le ScrabbleGame
			var game = get_parent()
			print("DnD dbg : try_drop board parent : ", game)
			if game.has_method("_create_joker_letter_popup"):
				game._create_joker_letter_popup(board_pos, dragging_tile)
	
		return true
	
	return false

# ============================================================================
# FONCTION PRIVÉE : Retourner à l'origine
# ============================================================================
func _return_to_origin() -> void:
	print("  -> Returning to origin")
	
	if drag_origin.type == "rack":
		var index = drag_origin.pos
		var tile_data = dragging_tile.get_meta("tile_data")
		rack_manager.add_tile_at(index, tile_data)
		
		var cell = rack_manager.get_cell_at(index)
		dragging_tile.reparent(cell)
		dragging_tile.position = Vector2(2, 2)
		dragging_tile.z_index = 0
		dragging_tile.remove_meta("temp")
	
	elif drag_origin.type == "board":
		var pos_vec = drag_origin.pos
		var tile_data = dragging_tile.get_meta("tile_data")
		board_manager.set_tile_at(pos_vec, tile_data)
		
		var cell = board_manager.get_cell_at(pos_vec)
		dragging_tile.reparent(cell)
		dragging_tile.position = Vector2(2, 2)
		dragging_tile.z_index = 0
		dragging_tile.set_meta("temp", true)
		
		if not temp_tiles.has(pos_vec):
			temp_tiles.append(pos_vec)

# ============================================================================
# FONCTION : Obtenir les tuiles temporaires
# ============================================================================
func get_temp_tiles() -> Array:
	return temp_tiles

# ============================================================================
# FONCTION : Vérifier si on est en train de dragger
# ============================================================================
func is_dragging() -> bool:
	return dragging_tile != null or board_manager.is_dragging_board

# ============================================================================
# FONCTION PRIVÉE : Obtenir le CanvasLayer pour le drag
# ============================================================================
func _get_canvas_layer_for_drag(game_node: Node2D) -> Node:
	"""Récupère le CanvasLayer pour afficher les tuiles en drag au-dessus de tout"""
	var canvas_layer = game_node.get_node_or_null("CanvasLayer")
	if canvas_layer:
		return canvas_layer
	else:
		print("⚠️ CanvasLayer introuvable, utilisation du parent par défaut")
		return game_node
