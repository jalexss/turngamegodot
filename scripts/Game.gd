extends Node2D

const CardScene = preload("res://scenes/Card.tscn")

@onready var deck = $Deck
@onready var ui   = $GameUI as Control

var turn_num := 0
var energy   := 0

func _ready() -> void:
    _start_turn()

func _start_turn() -> void:
    turn_num += 1
    energy = 3  # o lo que toque según reglas
    ui.set_turn(turn_num)
    ui.set_energy(energy)
    ui.clear_hand()

    # ejemplo de personajes, reemplaza por tu lógica real
    ui.update_player_chars([
        {"name":"Hero1", "portrait":load("res://assets/…png"), "hp":30, "max_hp":30},
        {"name":"Hero2", "portrait":load("res://assets/…png"), "hp":28, "max_hp":30}
    ])
    ui.update_enemy_chars([
        {"name":"Goblin", "portrait":load("res://assets/…png"), "hp":15, "max_hp":15}
    ])

    # roba cartas iniciales
    for i in range(3):
        _draw_and_show()

func _draw_and_show() -> void:
    var cd = deck.draw()
    if cd.empty():
        return
    var card = CardScene.instantiate() as Node2D
    if card.has_method("set_data"):
        card.call("set_data", cd)
    ui.add_card_to_hand(card)

# Ejemplo de método al jugar carta
func play_card(card_node: Node2D) -> void:
    var cd : CardData = card_node.data
    if energy < cd.cost:
        return
    energy -= cd.cost
    ui.set_energy(energy)
    # aquí resuelves effects: daño, cura, buffs…
    card_node.queue_free()