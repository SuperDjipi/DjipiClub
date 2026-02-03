extends Node
class_name MoveValidator

# ============================================================================
# VALIDATEUR DE MOUVEMENT (MOVE VALIDATOR)
# ============================================================================
# Ce module gère :
# - La validation des mouvements du joueur avant envoi au serveur
# - Le calcul du score prévisionnel
# - La vérification des règles du Scrabble
# ============================================================================

var board_manager: BoardManager
var scrabble_config: Node

# ============================================================================
# FONCTION : Initialiser le validateur
# ============================================================================
func initialize(board_mgr: BoardManager, config: Node) -> void:
	board_manager = board_mgr
	scrabble_config = config

# ============================================================================
# FONCTION : Valider un mouvement
# ============================================================================
# Retourne un dictionnaire avec :
# - valid: bool (le mouvement est-il valide ?)
# - score: int (score calculé)
# - errors: Array[String] (liste des erreurs)
# ============================================================================
# ============================================================================
# FONCTION : Valider un mouvement (version améliorée)
# ============================================================================
func validate_move(temp_tiles: Array) -> Dictionary:
	var result = {
		"valid": false,
		"total_score": 0,
		"words": [],
		"bonus_scrabble": 0,
		"rule_error": ""
	}
	
	# Vérifications de règles
	if temp_tiles.is_empty():
		result.rule_error = "Aucune tuile placée"
		return result
	
	if not _are_tiles_aligned(temp_tiles):
		result.rule_error = "Tuiles non alignées"
		return result
	
	if not _are_tiles_continuous(temp_tiles):
		result.rule_error = "Tuiles non continues"
		return result
	
	if not _is_connected_to_board(temp_tiles):
		result.rule_error = "Non connecté au plateau"
		return result
	
	# Extraire tous les mots formés
	var main_word_data = _extract_main_word(temp_tiles)
	var secondary_words_data = _extract_secondary_words(temp_tiles, main_word_data.is_horizontal)
	var all_words_data = [main_word_data] + secondary_words_data
	
	print("MV dbg: main_word = ", main_word_data.word)
	print("MV dbg: secondary_words = ", secondary_words_data)
	
	# Calculer le score de chaque mot
	var score_details = _calculate_score(temp_tiles)
	var total_score = 0
	
	# Pour chaque mot, combiner validation + score
	for i in range(all_words_data.size()):
		var word_data = all_words_data[i]
		var word_text = word_data.word
		
		# Vérifier la validité du mot
		var is_valid = true
		if scrabble_config.is_dictionary_loaded:
			is_valid = scrabble_config.is_valid_word(word_text)
		
		# Trouver le score correspondant
		var word_score = 0
		for detail in score_details.details:
			if detail.word == word_text:
				word_score = detail.score
				break
		
		# Ajouter au résultat
		result.words.append({
			"text": word_text,
			"valid": is_valid,
			"score": word_score
		})
		
		# Accumuler le score si valide
		if is_valid:
			total_score += word_score
	
	# Vérifier si tous les mots sont valides
	var all_valid = true
	for word_info in result.words:
		if not word_info.valid:
			all_valid = false
			break
	
	# Bonus Scrabble
	if all_valid and temp_tiles.size() == scrabble_config.RACK_SIZE:
		result.bonus_scrabble = 50
		total_score += 50
	
	# Résultat final
	result.valid = all_valid
	result.total_score = total_score
	
	return result

# ============================================================================
# FONCTION PRIVÉE : Vérifier l'alignement des tuiles
# ============================================================================
func _are_tiles_aligned(temp_tiles: Array) -> bool:
	if temp_tiles.size() <= 1:
		return true
	
	var first_pos = temp_tiles[0]
	var all_same_row = true
	var all_same_col = true
	
	for i in range(1, temp_tiles.size()):
		var pos = temp_tiles[i]
		if pos.y != first_pos.y:
			all_same_row = false
		if pos.x != first_pos.x:
			all_same_col = false
	
	return all_same_row or all_same_col

# ============================================================================
# FONCTION PRIVÉE : Vérifier la continuité des tuiles
# ============================================================================
func _are_tiles_continuous(temp_tiles: Array) -> bool:
	if temp_tiles.size() <= 1:
		return true
	
	# Trier les positions
	var sorted_tiles = temp_tiles.duplicate()
	var first_pos = sorted_tiles[0]
	
	# Déterminer la direction (horizontal ou vertical)
	var is_horizontal = true
	for pos in sorted_tiles:
		if pos.y != first_pos.y:
			is_horizontal = false
			break
	
	# Trier selon la direction
	if is_horizontal:
		sorted_tiles.sort_custom(func(a, b): return a.x < b.x)
	else:
		sorted_tiles.sort_custom(func(a, b): return a.y < b.y)
	
	# Vérifier la continuité (en incluant les tuiles déjà sur le plateau)
	for i in range(sorted_tiles.size() - 1):
		var current = sorted_tiles[i]
		var next = sorted_tiles[i + 1]
		
		if is_horizontal:
			var expected_x = current.x + 1
			# Vérifier s'il y a des tuiles entre current et next
			var has_gap = true
			for x in range(current.x + 1, next.x):
				if board_manager.get_tile_at(Vector2i(x, current.y)) != null:
					has_gap = false
					break
			
			if next.x > expected_x and has_gap:
				return false
		else:
			var expected_y = current.y + 1
			var has_gap = true
			for y in range(current.y + 1, next.y):
				if board_manager.get_tile_at(Vector2i(current.x, y)) != null:
					has_gap = false
					break
			
			if next.y > expected_y and has_gap:
				return false
	
	return true

# ============================================================================
# FONCTION PRIVÉE : Vérifier la connexion au plateau
# ============================================================================
func _is_connected_to_board(temp_tiles: Array) -> bool:
	# Si c'est le premier coup, vérifier que la case centrale est utilisée
	var board_is_empty = true
	for y in range(scrabble_config.BOARD_SIZE):
		for x in range(scrabble_config.BOARD_SIZE):
			var tile = board_manager.get_tile_at(Vector2i(x, y))
			if tile != null:
				var cell = board_manager.get_cell_at(Vector2i(x, y))
				var tile_node = TileManager.get_tile_in_cell(cell)
				if tile_node and not tile_node.has_meta("temp"):
					board_is_empty = false
					break
		if not board_is_empty:
			break
	
	if board_is_empty:
		# Premier coup : doit inclure la case centrale (7, 7)
		for pos in temp_tiles:
			if pos.x == 7 and pos.y == 7:
				return true
		return false
	
	# Sinon, vérifier qu'au moins une tuile touche une tuile existante
	for pos in temp_tiles:
		# Vérifier les 4 directions
		var neighbors = [
			Vector2i(pos.x - 1, pos.y),
			Vector2i(pos.x + 1, pos.y),
			Vector2i(pos.x, pos.y - 1),
			Vector2i(pos.x, pos.y + 1)
		]
		
		for neighbor_pos in neighbors:
			var tile = board_manager.get_tile_at(neighbor_pos)
			if tile != null:
				var cell = board_manager.get_cell_at(neighbor_pos)
				var tile_node = TileManager.get_tile_in_cell(cell)
				if tile_node and not tile_node.has_meta("temp"):
					return true
	
	return false

# ============================================================================
# FONCTION PRIVÉE : Calculer le score
# ============================================================================
func _calculate_score(temp_tiles: Array) -> Dictionary:
	var result = {
		"score": 0,
		"details": []
	}
	
	# Extraire tous les mots formés
	var main_word_data = _extract_main_word(temp_tiles)
	var secondary_words_data = _extract_secondary_words(temp_tiles, main_word_data.is_horizontal)
	
	var all_words_data = [main_word_data] + secondary_words_data
	
	# Calculer le score de chaque mot
	var total_score = 0
	
	for word_data in all_words_data:
		var word_score = _calculate_word_score(word_data, temp_tiles)
		total_score += word_score.score
		
		result.details.append({
			"word": word_data.word,
			"score": word_score.score,
			"breakdown": word_score.breakdown
		})
	
	# Bonus Scrabble : +50 si on utilise les 7 tuiles
	if temp_tiles.size() == scrabble_config.RACK_SIZE:
		total_score += 50
		result.details.append({
			"word": "BONUS SCRABBLE",
			"score": 50,
			"breakdown": "7 tuiles utilisées"
		})
	
	result.score = total_score
	return result

# ============================================================================
# FONCTION PRIVÉE : Calculer le score d'un mot
# ============================================================================
func _calculate_word_score(word_data: Dictionary, temp_tiles: Array) -> Dictionary:
	"""
	Calcule le score d'un mot en tenant compte des multiplicateurs
	"""
	var positions = word_data.positions
	var word = word_data.word
	
	var letter_score = 0
	var word_multiplier = 1
	var breakdown = []
	
	for pos in positions:
		var tile_data = board_manager.get_tile_at(pos)
		if not tile_data:
			continue
		
		var letter_value = tile_data.value
		var is_new_tile = temp_tiles.has(pos)
		
		# Appliquer les multiplicateurs seulement pour les nouvelles tuiles
		if is_new_tile:
			var bonus = board_manager.bonus_map.get(pos, "")
			
			match bonus:
				"L2":
					letter_value *= 2
					breakdown.append("%s×2 (L2)" % tile_data.letter)
				"L3":
					letter_value *= 3
					breakdown.append("%s×3 (L3)" % tile_data.letter)
				"W2":
					word_multiplier *= 2
					breakdown.append("%s + W2" % tile_data.letter)
				"W3":
					word_multiplier *= 3
					breakdown.append("%s + W3" % tile_data.letter)
				"CENTER":
					word_multiplier *= 2
					breakdown.append("%s + CENTER(W2)" % tile_data.letter)
				_:
					breakdown.append("%s" % tile_data.letter)
		else:
			breakdown.append("%s (déjà)" % tile_data.letter)
		
		letter_score += letter_value
	
	var final_score = letter_score * word_multiplier
	
	return {
		"score": final_score,
		"breakdown": "%s = %d × %d = %d" % [word, letter_score, word_multiplier, final_score]
	}
# ============================================================================
# FONCTION : Obtenir un message de validation formaté
# ============================================================================
func get_validation_message(validation_result: Dictionary) -> String:
	if validation_result.valid:
		return "✅ Mouvement valide ! Score : %d points" % validation_result.score
	else:
		var errors = "\n".join(validation_result.errors)
		return "❌ Mouvement invalide :\n%s" % errors

# ============================================================================
# FONCTION PRIVÉE : Extraire le mot principal
# ============================================================================
func _extract_main_word(temp_tiles: Array) -> Dictionary:
	"""
	Retourne : {
		"word": "CHAT",
		"positions": [Vector2i(7,7), Vector2i(8,7), Vector2i(9,7), Vector2i(10,7)],
		"is_horizontal": false
	}
	"""
	
	if temp_tiles.is_empty():
		return {"word": "", "positions": [], "is_horizontal": true}
	# ✅ CAS SPÉCIAL : Si on place UNE SEULE tuile
	if temp_tiles.size() == 1:
		var pos = temp_tiles[0]
		
		# Extraire dans les deux directions
		var horizontal_word = _extract_word_at_position(pos, true)
		var vertical_word = _extract_word_at_position(pos, false)
		
		print("MV dbg single tile: horizontal = ", horizontal_word.word, ", vertical = ", vertical_word.word)
		
		# Prendre le mot le plus long (ou horizontal si égalité)
		if vertical_word.word.length() > horizontal_word.word.length():
			return vertical_word
		else:
			return horizontal_word
	
	# Déterminer la direction (plusieurs tuiles)
	var first_pos = temp_tiles[0]
	var is_horizontal = true
	for pos in temp_tiles:
		if pos.y != first_pos.y:
			is_horizontal = false
			break
	
	# Trier les positions
	var sorted_tiles = temp_tiles.duplicate()
	if is_horizontal:
		sorted_tiles.sort_custom(func(a, b): return a.x < b.x)
	else:
		sorted_tiles.sort_custom(func(a, b): return a.y < b.y)
	
	# Trouver les extrémités (en incluant les tuiles déjà sur le plateau)
	var start_pos = sorted_tiles[0]
	var end_pos = sorted_tiles[-1]
	
	# Étendre vers le début
	if is_horizontal:
		while start_pos.x > 0:
			var prev_pos = Vector2i(start_pos.x - 1, start_pos.y)
			if board_manager.get_tile_at(prev_pos) == null:
				break
			var cell = board_manager.get_cell_at(prev_pos)
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node and not tile_node.has_meta("temp"):
				start_pos = prev_pos
			else:
				break
	else:
		while start_pos.y > 0:
			var prev_pos = Vector2i(start_pos.x, start_pos.y - 1)
			if board_manager.get_tile_at(prev_pos) == null:
				break
			var cell = board_manager.get_cell_at(prev_pos)
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node and not tile_node.has_meta("temp"):
				start_pos = prev_pos
			else:
				break
	
	# Étendre vers la fin
	if is_horizontal:
		while end_pos.x < scrabble_config.BOARD_SIZE - 1:
			var next_pos = Vector2i(end_pos.x + 1, end_pos.y)
			if board_manager.get_tile_at(next_pos) == null:
				break
			var cell = board_manager.get_cell_at(next_pos)
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node and not tile_node.has_meta("temp"):
				end_pos = next_pos
			else:
				break
	else:
		while end_pos.y < scrabble_config.BOARD_SIZE - 1:
			var next_pos = Vector2i(end_pos.x, end_pos.y + 1)
			if board_manager.get_tile_at(next_pos) == null:
				break
			var cell = board_manager.get_cell_at(next_pos)
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node and not tile_node.has_meta("temp"):
				end_pos = next_pos
			else:
				break
	
	# Construire le mot et la liste des positions
	var word = ""
	var positions = []
	
	if is_horizontal:
		for x in range(start_pos.x, end_pos.x + 1):
			var pos = Vector2i(x, start_pos.y)
			var tile_data = board_manager.get_tile_at(pos)
			if tile_data:
			# ✅ Utiliser assigned_letter si c'est un joker
				var letter = tile_data.assigned_letter if tile_data.is_joker else tile_data.letter
			# ✅ PROTECTION : Si le joker n'a pas de lettre, utiliser "?"
				if letter == null:
					letter = "?"
				word += letter
				positions.append(pos)
	else:
		for y in range(start_pos.y, end_pos.y + 1):
			var pos = Vector2i(start_pos.x, y)
			var tile_data = board_manager.get_tile_at(pos)
			if tile_data:
			# ✅ Utiliser assigned_letter si c'est un joker
				var letter = tile_data.assigned_letter if tile_data.is_joker else tile_data.letter
							# ✅ PROTECTION : Si le joker n'a pas de lettre, utiliser "?"
				if letter == null:
					letter = "?"
				word += letter
				positions.append(pos)
	
	return {
		"word": word,
		"positions": positions,
		"is_horizontal": is_horizontal
	}
	
	# ============================================================================
# FONCTION PRIVÉE : Extraire les mots secondaires (perpendiculaires)
# ============================================================================
func _extract_secondary_words(temp_tiles: Array, is_main_horizontal: bool) -> Array:
	"""
	Retourne : [
		{"word": "CHAT", "positions": [...]},
		{"word": "CHIEN", "positions": [...]},
		...
	]
	"""
	
	var secondary_words = []
	
	for tile_pos in temp_tiles:
		var word_data = _extract_word_at_position(tile_pos, not is_main_horizontal)
		
		# Ne garder que les mots de 2 lettres ou plus
		if word_data.word.length() >= 2:
			secondary_words.append(word_data)
	
	return secondary_words

# ============================================================================
# FONCTION PRIVÉE : Extraire un mot à une position donnée
# ============================================================================
func _extract_word_at_position(pos: Vector2i, is_horizontal: bool) -> Dictionary:
	"""
	Extrait le mot qui passe par la position donnée dans la direction spécifiée
	"""
	
	var start_pos = pos
	var end_pos = pos
	
	# Trouver le début
	if is_horizontal:
		while start_pos.x > 0:
			var prev_pos = Vector2i(start_pos.x - 1, start_pos.y)
			if board_manager.get_tile_at(prev_pos) != null:
				start_pos = prev_pos
			else:
				break
	else:
		while start_pos.y > 0:
			var prev_pos = Vector2i(start_pos.x, start_pos.y - 1)
			if board_manager.get_tile_at(prev_pos) != null:
				start_pos = prev_pos
			else:
				break
	
	# Trouver la fin
	if is_horizontal:
		while end_pos.x < scrabble_config.BOARD_SIZE - 1:
			var next_pos = Vector2i(end_pos.x + 1, end_pos.y)
			if board_manager.get_tile_at(next_pos) != null:
				end_pos = next_pos
			else:
				break
	else:
		while end_pos.y < scrabble_config.BOARD_SIZE - 1:
			var next_pos = Vector2i(end_pos.x, end_pos.y + 1)
			if board_manager.get_tile_at(next_pos) != null:
				end_pos = next_pos
			else:
				break
	
	# Construire le mot
	var word = ""
	var positions = []
	
	if is_horizontal:
		for x in range(start_pos.x, end_pos.x + 1):
			var p = Vector2i(x, start_pos.y)
			var tile_data = board_manager.get_tile_at(p)
			if tile_data:
			# ✅ Utiliser assigned_letter si c'est un joker
				var letter = tile_data.assigned_letter if tile_data.is_joker else tile_data.letter
							# ✅ PROTECTION : Si le joker n'a pas de lettre, utiliser "?"
				if letter == null:
					letter = "?"
				word += letter
				positions.append(p)
	else:
		for y in range(start_pos.y, end_pos.y + 1):
			var p = Vector2i(start_pos.x, y)
			var tile_data = board_manager.get_tile_at(p)
			if tile_data:
			# ✅ Utiliser assigned_letter si c'est un joker
				var letter = tile_data.assigned_letter if tile_data.is_joker else tile_data.letter
							# ✅ PROTECTION : Si le joker n'a pas de lettre, utiliser "?"
				if letter == null:
					letter = "?"
				word += letter
				positions.append(p)
	
	return {
		"word": word,
		"positions": positions,
		"is_horizontal": is_horizontal
	}
