extends Node2D

const ENEMY_DECKS_PATH = "res://data/enemy_decks.json"

@export var testing_deck_id: int = -1  # si > 0 fuerza ese deck en vez de random
@onready var deck = $Deck
@onready var ui   = $GameUI as Control

var turn_num := 0
var energy   := 0
var player_chars : Array = []
var enemy_chars  : Array = []
var char_defs    : Dictionary = {}
var enemy_defs   : Dictionary = {}

func _ready() -> void:
	# randomize()  # inicializamos semilla

	# cargar personajes y generar roster...
	char_defs  = _load_char_defs("res://data/characters.json")
	enemy_defs = _load_char_defs("res://data/enemies.json")
	player_chars = _generate_roster(char_defs, 1, 3)
	enemy_chars  = _generate_roster(enemy_defs, 1, 5)

	# elegimos deck aleatorio o forzado por testing_deck_id
	var decks = _load_enemy_decks(ENEMY_DECKS_PATH) 
	var chosen = _find_deck_by_id(decks, testing_deck_id)  if testing_deck_id > 0 else decks[randi() % decks.size()]
	deck.load_deck(chosen.deck)
	_start_turn()

func _start_turn() -> void:
	turn_num += 1
	energy = 3
	ui.set_turn(turn_num)
	ui.set_energy(energy)
	ui.clear_hand()
	ui.update_player_chars(player_chars)
	ui.update_enemy_chars(enemy_chars)
	for i in range(3):
		_draw_and_show()

func _draw_and_show() -> void:
	var cd = deck.draw()
	if cd:
		var card = preload("res://scenes/Card.tscn").instantiate() as Node2D
		card.set_data(cd)
		ui.add_card_to_hand(card)

# Métodos auxiliares para personajes/enemigos
func _load_char_defs(path: String) -> Dictionary:
	var dict := {}
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return dict
	var list = JSON.parse_string(file.get_as_text()).result
	file.close()
	for d in list:
		var c = preload("res://scripts/CharacterData.gd").new()
		c.id       = d.id
		c.name     = d.name
		c.portrait = load(d.portrait)
		c.hp       = d.hp
		c.max_hp   = d.max_hp
		c.attack   = d.attack
		c.defense  = d.defense
		dict[c.id] = c
	return dict

func _load_enemy_decks(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return {}
	var res = JSON.parse_string(file.get_as_text()).result
	file.close()
	return res

func _generate_roster(defs: Dictionary, min_count: int, max_count: int) -> Array:
	var keys = defs.keys()
	keys.shuffle()
	var count = clamp(randi() % (max_count - min_count + 1) + min_count, 1, keys.size())
	var roster := []
	for i in range(count):
		roster.append(defs[keys[i]])
	return roster

func _find_deck_by_id(decks: Array, id: int) -> Dictionary:
	for d in decks:
		if d.id == id:
			return d
	push_error("Deck ID %d no encontrado, usando el primero" % id)
	return decks[0]
