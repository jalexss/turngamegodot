# Font Resources for Card UI

## Recommended Pixel Art Fonts

Download these free fonts and place the .ttf files in this folder:

### 1. Press Start 2P (For digits - Energy/Power/Shield)
- **Source**: [Google Fonts](https://fonts.google.com/specimen/Press+Start+2P)
- **License**: OFL (Open Font License)
- **Use**: Bold digits for energy cost, attack power, shield values

### 2. Silkscreen (For card titles)
- **Source**: [Google Fonts](https://fonts.google.com/specimen/Silkscreen)  
- **License**: OFL
- **Use**: Card names and type banners

### 3. VT323 (For descriptions)
- **Source**: [Google Fonts](https://fonts.google.com/specimen/VT323)
- **License**: OFL
- **Use**: Card descriptions (more readable at small sizes)

## Alternative Options

- **Pixel Operator**: https://www.dafont.com/pixel-operator.font
- **DotGothic16**: https://fonts.google.com/specimen/DotGothic16
- **Pixelify Sans**: https://fonts.google.com/specimen/Pixelify+Sans

## Setup in Godot

1. Download .ttf files and place them in `assets/fonts/`
2. In Card.tscn labels, add Theme Overrides > Fonts
3. Drag the .ttf file to create a FontFile resource
4. Adjust font sizes as needed

## Current Font Sizes (in Card.tscn)

| Element | Current Size | Recommended Font |
|---------|-------------|------------------|
| EnergyCostLabel | 18px | Press Start 2P |
| ShieldLabel | 18px | Press Start 2P |
| AttackPowerLabel | 16px | Press Start 2P |
| TitleLabel | 12px | Silkscreen |
| TypeLabel | 12px | Silkscreen |
| DescriptionLabel | 10px | VT323 |
