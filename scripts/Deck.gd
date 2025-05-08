extends Node2D

const CdData = preload("res://scripts/CardData.gd")
const JSON_PATH = "res://data/cards.json"
const PLAYER_DECK_PATH = "res://data/player_deck.json"

var cards: Array = []

func _ready():
    # 1) cargo todas las definiciones de carta en un Dictionary[id] = CardData
    var defs = _load_card_defs(JSON_PATH)
    # 2) genero el mazo del jugador según player_deck.json
    cards = _generate_deck(defs, PLAYER_DECK_PATH)
    # 3) barajo
    shuffle()

func _load_card_defs(path: String) -> Dictionary:
    var dict := {}
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("No se pudo abrir " + path)
        return dict
    var text = file.get_as_text()
    file.close()
    var res = JSON.parse_string(text)
    if res.error != OK:
        push_error("Error parseando JSON: %s" % res.error_string)
        return dict
    # convierto cada entry en un CardData
    for def in res.result:
        var cd = CdData.new()
        cd.id          = def.get("id", 0)
        cd.name        = def.get("name", "")
        cd.cost        = def.get("cost", 0)
        cd.description = def.get("description", "")
        var aw = def.get("artwork", "")
        cd.artwork     = load(aw) if aw != "" and ResourceLoader.exists(aw) else null
        var bg = def.get("background", "")
        cd.background  = load(bg) if bg != "" and ResourceLoader.exists(bg) else null
        cd.card_type   = CdData.CardType[ def.get("card_type", "ATTACK") ]
        cd.power       = def.get("power", 0)
        cd.effects     = def.get("effects", [])
        dict[cd.id] = cd
    return dict

func _generate_deck(defs:Dictionary, deck_list_path:String) -> Array:
    var ids = _load_id_list(deck_list_path)  # lee data/player_deck.json ‑> [0,2,5…]
    var list := []
    for id in ids:
        if defs.has(id):
            list.append(defs[id])
    return list

func _load_id_list(path:String) -> Array:
    var file = FileAccess.open(path, FileAccess.READ)
    var text = file.get_as_text(); file.close()
    return JSON.parse_string(text).result.get("deck", [])

func shuffle():
  cards.shuffle()

func draw() -> Dictionary:
  if cards.size() == 0:
    return {}
  return cards.pop_front()
