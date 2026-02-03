extends Node

# ============================================================================
# CONFIGURATION STATIQUE DU JEU DE SCRABBLE
# ============================================================================

static func is_web() -> bool:
	return OS.has_feature("web")

# --- DIMENSIONS DU JEU ---
const BOARD_SIZE = 15
const TILE_SIZE = 70
const RACK_SIZE = 7
const BOARD_PADDING = 20

# --- COULEURS DES CASES BONUS ---
const COLOR_NORMAL = Color(0.8, 0.8, 0.7)
const COLOR_LETTER_DOUBLE = Color(0.6, 0.8, 1.0)
const COLOR_LETTER_TRIPLE = Color(0.2, 0.5, 1.0)
const COLOR_WORD_DOUBLE = Color(1.0, 0.8, 0.8)
const COLOR_WORD_TRIPLE = Color(1.0, 0.3, 0.3)
const COLOR_CENTER = Color(1.0, 0.8, 1.0)

# --- DISTRIBUTION DES LETTRES EN FRANCAIS ---
const LETTER_DISTRIBUTION = {
	"A": {"count": 9, "value": 1.0}, "B": {"count": 2, "value": 3.0},
	"C": {"count": 2, "value": 3.0}, "D": {"count": 3, "value": 2.0},
	"E": {"count": 15, "value": 1.0}, "F": {"count": 2, "value": 4.0},
	"G": {"count": 2, "value": 2.0}, "H": {"count": 2, "value": 4.0},
	"I": {"count": 8, "value": 1.0}, "J": {"count": 1, "value": 8.0},
	"K": {"count": 1, "value": 10.0}, "L": {"count": 5, "value": 1.0},
	"M": {"count": 3, "value": 2.0}, "N": {"count": 6, "value": 1.0},
	"O": {"count": 6, "value": 1.0}, "P": {"count": 2, "value": 3.0},
	"Q": {"count": 1, "value": 8.0}, "R": {"count": 6, "value": 1.0},
	"S": {"count": 6, "value": 1.0}, "T": {"count": 6, "value": 1.0},
	"U": {"count": 6, "value": 1.0}, "V": {"count": 2, "value": 4.0},
	"W": {"count": 1, "value": 10.0}, "X": {"count": 1, "value": 10.0},
	"Y": {"count": 1, "value": 10.0}, "Z": {"count": 1, "value": 10.0},
	"?": {"count": 2, "value": 0.0}
}

# --- PARAMETRES D'AUTO-SCROLL ---
const AUTO_SCROLL_MARGIN = 80.0
const AUTO_SCROLL_SPEED = 8.0
const AUTO_SCROLL_SPEED_WEB = 5.0

# --- PARAMETRES D'ECHELLE ---
const BOARD_SCALE_FOCUSED = 1.0
const BOARD_SCALE_UNFOCUSED = 0.7

# ============================================================================
# FONCTION : Creer la map des bonus du plateau
# ============================================================================
func create_bonus_map() -> Dictionary:
	var bonus_map = {}

	# Mot Compte Triple (W3) - Coins
	for pos in [Vector2i(0,0), Vector2i(0,7), Vector2i(0,14), Vector2i(7,0),
				Vector2i(7,14), Vector2i(14,0), Vector2i(14,7), Vector2i(14,14)]:
		bonus_map[pos] = "W3"

	# Mot Compte Double (W2) - Diagonales
	for i in range(1, 5):
		for pos in [Vector2i(i,i), Vector2i(i,14-i), Vector2i(14-i,i), Vector2i(14-i,14-i)]:
			bonus_map[pos] = "W2"

	# Lettre Compte Triple (L3)
	for pos in [Vector2i(1,5), Vector2i(1,9), Vector2i(5,1), Vector2i(5,5),
				Vector2i(5,9), Vector2i(5,13), Vector2i(9,1), Vector2i(9,5),
				Vector2i(9,9), Vector2i(9,13), Vector2i(13,5), Vector2i(13,9)]:
		bonus_map[pos] = "L3"

	# Lettre Compte Double (L2)
	for pos in [Vector2i(0,3), Vector2i(0,11), Vector2i(2,6), Vector2i(2,8),
				Vector2i(3,0), Vector2i(3,7), Vector2i(3,14), Vector2i(6,2),
				Vector2i(6,6), Vector2i(6,8), Vector2i(6,12), Vector2i(7,3),
				Vector2i(7,11), Vector2i(8,2), Vector2i(8,6), Vector2i(8,8),
				Vector2i(8,12), Vector2i(11,0), Vector2i(11,7), Vector2i(11,14),
				Vector2i(12,6), Vector2i(12,8), Vector2i(14,3), Vector2i(14,11)]:
		bonus_map[pos] = "L2"

	# Case centrale (etoile)
	bonus_map[Vector2i(7,7)] = "CENTER"

	return bonus_map

# ============================================================================
# FONCTION : Obtenir la couleur d'un bonus
# ============================================================================
func get_bonus_color(bonus: String) -> Color:
	match bonus:
		"W3": return COLOR_WORD_TRIPLE
		"W2": return COLOR_WORD_DOUBLE
		"L3": return COLOR_LETTER_TRIPLE
		"L2": return COLOR_LETTER_DOUBLE
		"CENTER": return COLOR_CENTER
		_: return COLOR_NORMAL

# ============================================================================
# DICTIONNAIRE (charge au demarrage)
# ============================================================================

var dictionaries: Dictionary = {}
var is_dictionary_loaded: bool = false

const DICT_FILES = {
	2: "deux.txt",
	3: "trois.txt",
	4: "quatre.txt",
	5: "cinq.txt",
	6: "six.txt",
	7: "sept.txt",
	8: "huit.txt",
	9: "neuf.txt",
	10: "dix.txt",
	11: "onze.txt",
	12: "douze.txt",
	13: "treize.txt",
	14: "quatorze.txt",
	15: "quinze.txt"
}

# ============================================================================
# FONCTION : Initialisation
# ============================================================================
func _ready():
	print("ScrabbleConfig : Chargement des dictionnaires...")
	load_dictionaries()

# ============================================================================
# FONCTION : Charger les dictionnaires
# ============================================================================
func load_dictionaries() -> bool:
	var base_path = "res://assets/scrabble/dictionaries/"

	for length in DICT_FILES:
		var filename = DICT_FILES[length]
		var path = base_path + filename

		if not _load_dictionary_file(path, length):
			print("Erreur chargement : ", filename)
			return false

	is_dictionary_loaded = true
	print("Dictionnaires charges")
	return true

func _load_dictionary_file(path: String, length: int) -> bool:
	if not FileAccess.file_exists(path):
		print("Non trouve : ", path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Ouverture impossible : ", path)
		return false

	dictionaries[length] = {}
	var content = file.get_as_text()
	file.close()

	var words = content.split(",")
	var word_count = 0

	for word in words:
		var cleaned_word = word.strip_edges().to_upper()
		if cleaned_word.length() > 0:
			dictionaries[length][cleaned_word] = true
			word_count += 1

	print("  ", path.get_file(), " : ", word_count, " mots")
	return true

# ============================================================================
# FONCTION : Verifier si un mot existe
# ============================================================================
func is_valid_word(word: String) -> bool:
	if not is_dictionary_loaded:
		print("Dictionnaires non charges")
		return false

	var normalized_word = word.to_upper().strip_edges()
	var length = normalized_word.length()

	if length < 2 or length > 15:
		return false

	if not dictionaries.has(length):
		return false

	return dictionaries[length].has(normalized_word)
