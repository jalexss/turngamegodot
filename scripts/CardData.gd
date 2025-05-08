extends Resource
class_name CardData

enum CardType { ATTACK, DEFENSE, HEAL, BUFF, DEBUFF, DRAW, DISCARD }
enum EffectType { DAMAGE, SHIELD, HEAL, BUFF, DEBUFF, DRAW, DISCARD }

@export var id: int = 0
@export var name: String = ""
@export var cost: int = 0
@export var description: String = ""
@export var artwork: Texture2D
@export var background: Texture2D
@export var card_type: CardType = CardType.ATTACK
@export var power: int = 0
@export var effects: Array[Dictionary] = []
