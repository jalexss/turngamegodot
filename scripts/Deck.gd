extends Node2D

const CdData     = preload("res://scripts/CardData.gd")
const JSON_PATH  = "res://data/cards.json"

var cards: Array = []

# Público: carga definiciones y genera/mezcla el mazo según el JSON de lista
func load_deck(deck_list_path: String) -> void:
    var defs = _load_card_defs(JSON_PATH)
    cards = _generate_deck(defs, deck_list_path)
    shuffle()

func _load_card_defs(path: String) -> Dictionary:
    var dict := {}
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        push_error("No se pudo abrir " + path)
        return dict
    var res = JSON.parse_string(file.get_as_text())
    file.close()
    if res.error != OK:
        push_error("Error parseando JSON: %s" % res.error_string)
        return dict
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

func _generate_deck(defs: Dictionary, deck_list_path: String) -> Array:
    var ids = _load_id_list(deck_list_path)
    var list := []
    for id in ids:
        if defs.has(id):
            list.append(defs[id])
    return list

func _load_id_list(path: String) -> Array:
    var file = FileAccess.open(path, FileAccess.READ)
    var text = file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(text)
    return  parsed.result.get("deck", []) if parsed.error == OK else []
    # return parsed.error == OK ? parsed.result.get("deck", []) : []

func shuffle() -> void:
    cards.shuffle()

func draw() -> CardData:
    return cards.pop_front() if cards.size() > 0 else null