extends Node
class_name RackManager

# ============================================================================
# GESTIONNAIRE DU CHEVALET (RACK MANAGER)
# ============================================================================

# Reference a la configuration
var scrabble_config: Node

# Reference au TileManager
var tile_manager: TileManager

# Donnees du chevalet
var rack: Array = []
var rack_cells: Array = []
var rack_container: Control

# Taille des tuiles du chevalet
var tile_size_rack: float = 0.0

# Reference a la taille de l'ecran
var viewport_size: Vector2

# ============================================================================
# FONCTION : Initialiser le RackManager
# ============================================================================
func initialize(viewport_sz: Vector2, tile_mgr: TileManager, config: Node) -> void:
	viewport_size = viewport_sz
	tile_manager = tile_mgr
	scrabble_config = config

	var rack_width = viewport_size.x - scrabble_config.BOARD_PADDING
	tile_size_rack = floor(rack_width / (scrabble_config.RACK_SIZE + 3))
	print("RackMgr : calcul taille : ", tile_size_rack)

# ============================================================================
# FONCTION : Creer le chevalet
# ============================================================================
func create_rack(parent: Node) -> void:
	rack_container = parent
	rack_container.custom_minimum_size.y = tile_size_rack

	for i in range(scrabble_config.RACK_SIZE):
		rack.append(null)
		var cell = _create_rack_cell(i)
		rack_container.add_child(cell)
		rack_cells.append(cell)

	print("Chevalet cree avec ", scrabble_config.RACK_SIZE, " emplacements")

# ============================================================================
# FONCTION PRIVEE : Creer une cellule du chevalet
# ============================================================================
func _create_rack_cell(index: int) -> Panel:
	var cell = Panel.new()
	cell.custom_minimum_size = Vector2(tile_size_rack, tile_size_rack)
	cell.modulate = Color(0.9, 0.9, 0.8)
	return cell

# ============================================================================
# FONCTION : Remplir le chevalet
# ============================================================================
func fill_rack() -> void:
	for i in range(scrabble_config.RACK_SIZE):
		if rack[i] == null:
			var tile_data = tile_manager.draw_tile()
			if tile_data:
				rack[i] = tile_data
				tile_manager.create_tile_visual(tile_data, rack_cells[i], tile_size_rack)

# ============================================================================
# FONCTION : Vider le chevalet (retirer toutes les tuiles visuelles)
# ============================================================================
func clear_rack() -> void:
	for i in range(scrabble_config.RACK_SIZE):
		if rack[i] != null:
			var cell = rack_cells[i]
			var tile_node = TileManager.get_tile_in_cell(cell)
			if tile_node:
				tile_node.queue_free()
			rack[i] = null

# ============================================================================
# FONCTION : Obtenir une tuile du chevalet a un index donne
# ============================================================================
func get_tile_at(index: int) -> Variant:
	if index >= 0 and index < rack.size():
		return rack[index]
	return null

# ============================================================================
# FONCTION : Retirer une tuile du chevalet
# ============================================================================
func remove_tile_at(index: int) -> Variant:
	if index >= 0 and index < rack.size():
		var tile = rack[index]
		rack[index] = null
		return tile
	return null

# ============================================================================
# FONCTION : Ajouter une tuile au chevalet
# ============================================================================
func add_tile_at(index: int, tile_data: Dictionary) -> bool:
	if index >= 0 and index < rack.size() and rack[index] == null:
		rack[index] = tile_data
		return true
	return false

# ============================================================================
# FONCTION : Obtenir la cellule du chevalet a un index donne
# ============================================================================
func get_cell_at(index: int) -> Panel:
	if index >= 0 and index < rack_cells.size():
		return rack_cells[index]
	return null

# ============================================================================
# FONCTION : Verifier si une position est dans le chevalet
# ============================================================================
func is_position_in_rack(global_pos: Vector2) -> int:
	for i in range(scrabble_config.RACK_SIZE):
		var cell = rack_cells[i]
		var cell_rect = Rect2(cell.global_position, cell.size)
		if cell_rect.has_point(global_pos):
			return i
	return -1

# ============================================================================
# FONCTION : Melanger les tuiles du chevalet
# ============================================================================
func shuffle_rack() -> void:
	print("Melange du chevalet...")

	var tiles_info = []

	for i in range(scrabble_config.RACK_SIZE):
		var data = rack[i]
		if data != null:
			var cell = rack_cells[i]
			var node = TileManager.get_tile_in_cell(cell)

			if node != null:
				tiles_info.append({
					"data": data,
					"node": node
				})

	tiles_info.shuffle()

	for i in range(scrabble_config.RACK_SIZE):
		rack[i] = null

	for i in range(tiles_info.size()):
		var info = tiles_info[i]
		var data = info.data
		var node = info.node
		var cell = rack_cells[i]

		rack[i] = data

		if node != null:
			node.reparent(cell)
			node.position = Vector2(2, 2)
			node.z_index = 0

	print("Chevalet melange : ", tiles_info.size(), " tuiles")
