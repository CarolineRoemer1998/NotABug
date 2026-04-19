class_name ItemData
extends Resource

@export var item_name : String
@export var type : Item.TYPE
@export var fear_reduction : float # Wert, um den Fear-Meter gesenkt wird
@export var item_texture : SpriteFrames
@export var wearable_texture : Texture2D
## Matches suffix tokens in Monster_anim SpriteFrames (Brille, Handschuhe, Schuhe, Trompete). Empty = no enemy cosmetic.
@export var cosmetic_tag: StringName = &""
