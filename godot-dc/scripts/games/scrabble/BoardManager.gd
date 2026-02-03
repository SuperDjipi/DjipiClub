extends Node
class_name BoardManager

# ============================================================================
# GESTIONNAIRE DU PLATEAU (BOARD MANAGER)
# ============================================================================

# Reference a la configuration
var scrabble_config: Node

# Donnees du plateau
var board: Array = []
var board_cells: Array = []
var board_container: Control
var bonus_map: Dictionary = {}

# Taille des tuiles
var tile_size_board: float = 40.0
var tile_size_rack: float = 0.0

# Etat du focus
var is_board_focused: bool = false
var board_scale_focused: float = 1.0
var board_scale_unfocused: float = 0.7

# Variables pour le deplacement du plateau
var is_dragging_board: bool = false
var board_drag_start_pos: Vector2 = Vector2.ZERO
var board_initial_pos: Vector2 = Vector2.ZERO
var board_min_x: float = 0.0
var board_max_x: float = 0.0
var board_min_y: float = 0.0
var board_max_y: float = 0.0

# Reference a la taille de l'ecran
var viewport_size: Vector2

# ============================================================================
# FONCTION : Initialiser le BoardManager
# ============================================================================
func initialize(viewport_sz: Vector2, rack_tile_size: float, config: Node) -> void:
	viewport_size = viewport_sz
	scrabble_config = config
	bonus_map = scrabble_config.create_bonus_map()
	tile_size_board = rack_tile_size

# ============================================================================
# FONCTION : Creer le plateau
# ============================================================================
func create_board(parent: MarginContainer) -> void:
	board_container = Control.new()
	parent.add_child(board_container)

	var total_board_pixel_size = scrabble_config.BOARD_SIZE * (tile_size_board + 2)
	board_container.pivot_offset = Vector2(total_board_pixel_size / 2, total_board_pixel_size / 2)

	var board_width = viewport_size.x - scrabble_config.BOARD_PADDING
	board_scale_unfocused = board_width / total_board_pixel_size
	board_container.scale = Vector2(board_scale_unfocused, board_scale_unfocused)

	var visible_width = total_board_pixel_size * board_scale_unfocused
	var visible_height = total_board_pixel_size * board_scale_unfocused
	var start_x = (viewport_size.x - visible_width) / 2
	var start_y = 0  # Le parent MarginContainer gère déjà le positionnement vertical
	board_container.position = Vector2(start_x, start_y)

	print("Echelles calculees :")
	print("   - board_scale_unfocused : ", board_scale_unfocused," - board_scale_focused : ", board_scale_focused)
	print("   - tile_size_board : ", tile_size_board)

	for y in range(scrabble_config.BOARD_SIZE):
		board.append([])
		board_cells.append([])
		for x in range(scrabble_config.BOARD_SIZE):
			board[y].append(null)
			var cell = _create_board_cell(Vector2i(x, y))
			board_container.add_child(cell)
			board_cells[y].append(cell)

	calculate_board_limits()
	is_board_focused = false
	print("Plateau cree : ", scrabble_config.BOARD_SIZE, "x", scrabble_config.BOARD_SIZE)

# ============================================================================
# FONCTION PRIVEE : Creer une cellule du plateau
# ============================================================================
func _create_board_cell(pos: Vector2i) -> Panel:
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(tile_size_board, tile_size_board)
	cell.position = Vector2(pos.x * (tile_size_board + 2), pos.y * (tile_size_board + 2))

	var bonus = bonus_map.get(pos, "")
	var color = scrabble_config.get_bonus_color(bonus)

	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.5, 0.4)

	cell.add_theme_stylebox_override("panel", style)

	if bonus:
		var lbl = Label.new()
		if bonus == "CENTER":
			lbl.text = "*"
			lbl.add_theme_font_size_override("font_size", 20)
			lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.8))
		else:
			lbl.text = bonus
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))

		lbl.position = Vector2(5, 10)
		cell.add_child(lbl)

	return cell

# ============================================================================
# FONCTION : Calculer les limites de deplacement du plateau
# ============================================================================
func calculate_board_limits() -> void:
	var total_board_pixel_size = scrabble_config.BOARD_SIZE * (tile_size_board + 2)
	
	# Limites horizontales
	var overflow_width = total_board_pixel_size - viewport_size.x
	if overflow_width > 0:
		board_max_x = 0
		board_min_x = -overflow_width
	else:
		var start_x = (viewport_size.x - total_board_pixel_size) / 2
		board_min_x = start_x
		board_max_x = start_x
	
	# Limites verticales - utiliser la hauteur du parent si disponible
	var available_height = viewport_size.y
	if board_container and board_container.get_parent():
		available_height = board_container.get_parent().size.y
	
	var overflow_height = total_board_pixel_size - available_height
	if overflow_height > 0:
		board_max_y = 0
		board_min_y = -overflow_height
	else:
		var start_y = (available_height - total_board_pixel_size) / 2
		board_min_y = start_y
		board_max_y = start_y
	
	print("Limites du plateau: X[", board_min_x, " -> ", board_max_x, "] Y[", board_min_y, " -> ", board_max_y, "]")
	print("  Hauteur disponible: ", available_height, " | Taille plateau: ", total_board_pixel_size)

# ============================================================================
# FONCTION : Animer vers la vue "plateau"
# ============================================================================
func animate_to_board_view(col_shift: int) -> void:
	if is_board_focused:
		return
	is_board_focused = true

	print("Animation -> Vue Plateau")
	var tween = board_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(board_container, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_SINE)

	var total_board_pixel_size = scrabble_config.BOARD_SIZE * (tile_size_board + 2)
	
	# Position X (existant)
	var start_x = (viewport_size.x - total_board_pixel_size) / 2
	start_x -= (col_shift - 7) * (tile_size_board + 3) * board_scale_unfocused / 2
	tween.tween_property(board_container, "position:x", start_x, 0.3).set_trans(Tween.TRANS_SINE)
	
	# Position Y (nouveau) - centrer verticalement dans l'espace disponible
	var parent_height = board_container.get_parent().size.y if board_container.get_parent() else viewport_size.y
	var start_y = (parent_height - total_board_pixel_size) / 2
	# Clamper pour ne pas dépasser
	start_y = clamp(start_y, board_min_y, board_max_y)
	tween.tween_property(board_container, "position:y", start_y, 0.3).set_trans(Tween.TRANS_SINE)

# ============================================================================
# FONCTION : Animer vers la vue "chevalet"
# ============================================================================
func animate_to_rack_view() -> void:
	if not is_board_focused:
		return
	is_board_focused = false

	print("Animation -> Vue Chevalet")
	var tween = board_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(board_container, "scale", Vector2(board_scale_unfocused, board_scale_unfocused), 0.3).set_trans(Tween.TRANS_SINE)

	var total_board_pixel_size = scrabble_config.BOARD_SIZE * (tile_size_board + 2)
	var start_x = (viewport_size.x - total_board_pixel_size) / 2
	var start_y = 0  # Recentrer verticalement
	
	tween.tween_property(board_container, "position:x", start_x, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_property(board_container, "position:y", start_y, 0.3).set_trans(Tween.TRANS_SINE)

# ============================================================================
# FONCTION : Auto-scroll du plateau
# ============================================================================
func auto_scroll_board(mouse_pos: Vector2) -> void:
	var should_scroll_left = false
	var should_scroll_right = false
	var should_scroll_up = false
	var should_scroll_down = false
	var intensity_x = 1.0
	var intensity_y = 1.0
	
	# Scroll horizontal
	if mouse_pos.x < scrabble_config.AUTO_SCROLL_MARGIN:
		intensity_x = 1.0 - (mouse_pos.x / scrabble_config.AUTO_SCROLL_MARGIN)
		should_scroll_left = true
	
	if mouse_pos.x > viewport_size.x - scrabble_config.AUTO_SCROLL_MARGIN:
		var distance_from_right = viewport_size.x - mouse_pos.x
		intensity_x = 1.0 - (distance_from_right / scrabble_config.AUTO_SCROLL_MARGIN)
		should_scroll_right = true
	
	# Scroll vertical
	# Souris près du HAUT → on veut voir plus haut → déplacer le plateau vers le BAS (positif)
	if mouse_pos.y < scrabble_config.AUTO_SCROLL_MARGIN:
		intensity_y = 1.0 - (mouse_pos.y / scrabble_config.AUTO_SCROLL_MARGIN)
		should_scroll_down = true  # ← INVERSÉ
	
	# Souris près du BAS → on veut voir plus bas → déplacer le plateau vers le HAUT (négatif)
	if mouse_pos.y > viewport_size.y - scrabble_config.AUTO_SCROLL_MARGIN:
		var distance_from_bottom = viewport_size.y - mouse_pos.y
		intensity_y = 1.0 - (distance_from_bottom / scrabble_config.AUTO_SCROLL_MARGIN)
		should_scroll_up = true  # ← INVERSÉ
	
	# Vitesse
	var speed = scrabble_config.AUTO_SCROLL_SPEED
	if scrabble_config.is_web():
		speed = scrabble_config.AUTO_SCROLL_SPEED_WEB
	
	# Calcul des deltas
	var scroll_delta_x = 0.0
	var scroll_delta_y = 0.0
	
	if should_scroll_right:
		scroll_delta_x -= speed * intensity_x
	if should_scroll_left:
		scroll_delta_x += speed * intensity_x
	
	if should_scroll_down:
		scroll_delta_y += speed * intensity_y  # ← INVERSÉ : + pour descendre le plateau (voir plus haut)
	if should_scroll_up:
		scroll_delta_y -= speed * intensity_y  # ← INVERSÉ : - pour monter le plateau (voir plus bas)
	
	# Application des deltas
	if scroll_delta_x != 0.0:
		var new_x = board_container.position.x + scroll_delta_x
		new_x = clamp(new_x, board_min_x, board_max_x)
		board_container.position.x = new_x
	
	if scroll_delta_y != 0.0:
		var new_y = board_container.position.y + scroll_delta_y
		new_y = clamp(new_y, board_min_y, board_max_y)
		board_container.position.y = new_y

# ============================================================================
# FONCTION : Demarrer le drag du plateau
# ============================================================================
func start_board_drag(pos: Vector2) -> bool:
	if not is_board_focused:
		return false

	var board_rect = Rect2(
		board_container.global_position,
		Vector2(scrabble_config.BOARD_SIZE * (tile_size_board + 2),
				scrabble_config.BOARD_SIZE * (tile_size_board + 2)) * board_container.scale
	)

	if board_rect.has_point(pos):
		is_dragging_board = true
		board_drag_start_pos = pos
		board_initial_pos = board_container.position
		return true

	return false

# ============================================================================
# FONCTION : Mettre a jour le drag du plateau
# ============================================================================
func update_board_drag(pos: Vector2) -> void:
	if is_dragging_board:
		var delta = pos - board_drag_start_pos
		
		# Déplacement horizontal
		var new_x = board_initial_pos.x + delta.x
		new_x = clamp(new_x, board_min_x, board_max_x)
		board_container.position.x = new_x
		
		# Déplacement vertical
		var new_y = board_initial_pos.y + delta.y
		new_y = clamp(new_y, board_min_y, board_max_y)
		board_container.position.y = new_y

# ============================================================================
# FONCTION : Terminer le drag du plateau
# ============================================================================
func end_board_drag() -> void:
	is_dragging_board = false

# ============================================================================
# FONCTION : Verifier si une position est sur le plateau
# ============================================================================
func get_board_position_at(global_pos: Vector2) -> Variant:
	for y in range(scrabble_config.BOARD_SIZE):
		for x in range(scrabble_config.BOARD_SIZE):
			var cell = board_cells[y][x]
			var cell_rect = Rect2(cell.global_position, cell.size * board_container.scale)
			if cell_rect.has_point(global_pos):
				return Vector2i(x, y)
	return null

# ============================================================================
# FONCTION : Obtenir une tuile du plateau
# ============================================================================
func get_tile_at(pos: Vector2i) -> Variant:
	if pos.y >= 0 and pos.y < board.size() and pos.x >= 0 and pos.x < board[pos.y].size():
		return board[pos.y][pos.x]
	return null

# ============================================================================
# FONCTION : Placer une tuile sur le plateau
# ============================================================================
func set_tile_at(pos: Vector2i, tile_data: Variant) -> void:
	if pos.y >= 0 and pos.y < board.size() and pos.x >= 0 and pos.x < board[pos.y].size():
		board[pos.y][pos.x] = tile_data

# ============================================================================
# FONCTION : Obtenir la cellule du plateau
# ============================================================================
func get_cell_at(pos: Vector2i) -> Panel:
	if pos.y >= 0 and pos.y < board_cells.size() and pos.x >= 0 and pos.x < board_cells[pos.y].size():
		return board_cells[pos.y][pos.x]
	return null
