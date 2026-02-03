# game_registry.gd
# Registre des jeux disponibles dans le DjipiClub Hub
extends Node

# Dictionnaire des jeux enregistres
var games: Dictionary = {
	"SCRABBLE_CLASSIC": {
		"name": "Scrabble Classique",
		"description": "Le jeu de mots croises classique. Placez vos lettres pour former des mots et marquer des points !",
		"scene": "res://scenes/scrabble/ScrabbleGameMultiplayer.tscn",
		"icon": "res://assets/scrabble/images/scrabble_icon.png",
		"min_players": 2,
		"max_players": 4,
		"available": true
	},
	"BOGGLE": {
		"name": "Boggle",
		"description": "Trouvez un maximum de mots dans une grille de lettres en temps limite.",
		"scene": "",
		"icon": "",
		"min_players": 1,
		"max_players": 8,
		"available": false
	},
	"YAM": {
		"name": "Yam / Yahtzee",
		"description": "Le jeu de des classique. Lancez et combinez pour faire les meilleures combinaisons.",
		"scene": "",
		"icon": "",
		"min_players": 2,
		"max_players": 4,
		"available": false
	}
}

# Signal emis quand on lance un jeu
signal game_launched(game_type: String, game_id: String)

func _ready():
	print("GameRegistry initialise avec ", games.size(), " jeu(x) enregistre(s)")

func get_available_games() -> Array:
	"""Retourne la liste des types de jeux disponibles"""
	var available = []
	for game_type in games.keys():
		if games[game_type].get("available", false):
			available.append(game_type)
	return available

func get_all_games() -> Array:
	"""Retourne tous les types de jeux (disponibles ou non)"""
	return games.keys()

func get_game_info(game_type: String) -> Dictionary:
	"""Retourne les informations d'un jeu"""
	return games.get(game_type, {})

func is_game_available(game_type: String) -> bool:
	"""Verifie si un jeu est disponible"""
	return games.has(game_type) and games[game_type].get("available", false)

func launch_game(game_type: String, game_id: String) -> bool:
	"""Lance un jeu et change de scene"""
	if not is_game_available(game_type):
		print("Erreur: Le jeu ", game_type, " n'est pas disponible")
		return false

	var game_info = games[game_type]
	var scene_path = game_info.get("scene", "")

	if scene_path.is_empty():
		print("Erreur: Pas de scene definie pour ", game_type)
		return false

	print("Lancement du jeu: ", game_type, " (", game_id, ")")
	game_launched.emit(game_type, game_id)

	get_tree().change_scene_to_file(scene_path)
	return true

func register_game(game_type: String, game_info: Dictionary) -> void:
	"""Enregistre un nouveau jeu dans le registre"""
	games[game_type] = game_info
	print("Jeu enregistre: ", game_type)
