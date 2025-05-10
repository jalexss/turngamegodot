extends Node2D

var data: CardData

func set_data(d: CardData) -> void:
	data = d
	$MainVBox/NameLabel.text = data.name 
	$MainVBox/CostLabel.text = str(data.cost)
	if $MainVBox.has_node("DescriptionLabel"): 
		($MainVBox/DescriptionLabel as Label).text = data.description

	if $MainVBox.has_node("PowerLabel"):
		($MainVBox/PowerLabel as Label).text = str(data.power) 

	# Artwork (dentro de MainVBox)
	var artwork_node = $MainVBox/Artwork as TextureRect
	if data.artwork:
		artwork_node.texture = data.artwork
	else:
		artwork_node.texture = _make_color_texture(_get_color(data.card_type), Vector2(128,128))
	
	if data.background:
		$Background.texture = data.background
	else:
		$Background.modulate = _get_color(data.card_type)

func _get_color(type: int) -> Color:
	match type:
		CardData.CardType.ATTACK:  return Color(1, 0.2, 0.2)
		CardData.CardType.DEFENSE: return Color(0.2, 0.2, 1)
		CardData.CardType.HEAL:    return Color(0.2, 1, 0.2)
		CardData.CardType.BUFF:    return Color(1, 1, 0.2)
		CardData.CardType.DEBUFF:  return Color(0.6, 0.2, 0.8)
		_:                        return Color(0.8, 0.8, 0.8)

func _make_color_texture(color: Color, size: Vector2) -> ImageTexture:
	var w := int(size.x)
	var h := int(size.y)
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in range(w):
		for y in range(h):
			img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	return tex
