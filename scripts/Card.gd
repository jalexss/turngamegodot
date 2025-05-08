extends Node2D

var data: CardData

func set_data(d: CardData) -> void:
    data = d
    $NameLabel.text = data.name
    $CostLabel.text = str(data.cost)
    # Artwork
    if data.artwork:
        $Artwork.texture = data.artwork
    else:
        $Artwork.texture = _make_color_texture(_get_color(data.card_type), Vector2(128,128))
    # Background
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
    # var img = Image.new()
    # Image.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
    # # Image.create(img, int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
    # img.lock()
    # for x in size.x:
    #     for y in size.y:
    #         img.set_pixel(x, y, color)
    # img.unlock()
    # var tex = ImageTexture.new()
    # tex.create_from_image(img)
    # return tex
    # var img = Image.new()
    # # Crear imagen en la instancia, no en la clase
    # img.create(int(size.x), int(size.y), false, Image.FORMAT_RGBA8)
    # img.lock()
    # # Iterar con range()
    # for x in range(int(size.x)):
    # 	for y in range(int(size.y)):
    # 		img.set_pixel(x, y, color)
    # img.unlock()
    # var tex = ImageTexture.new()
    # tex.create_from_image(img)
    # return tex

    # Convierte a int antes de pasarlo al método estático
    var w := int(size.x)
    var h := int(size.y)
    # Image.create es estática y retorna la Image
    var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.lock()
    for x in range(w):
        for y in range(h):
            img.set_pixel(x, y, color)
    img.unlock()
    # create_from_image es instancia en ImageTexture
    var tex := ImageTexture.new()
    tex.create_from_image(img)
    return tex