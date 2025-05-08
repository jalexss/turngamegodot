extends Node2D

const CardScene = preload("res://scenes/Card.tscn")

@onready var deck = $Deck
@onready var hand = $Hand
@onready var card_container = $CardContainer

func _ready():
	deck.shuffle()
	for i in range(3):
		_draw_card()

func _draw_card() -> void:
	var card_data = deck.draw()
	if card_data.empty():
		return
	var card_node = CardScene.instantiate() as Node2D
	if card_node.has_method("set_data"):
		card_node.call("set_data", card_data)
	hand.call("add_card", card_node)
