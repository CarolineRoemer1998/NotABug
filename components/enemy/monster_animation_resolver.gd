class_name MonsterAnimationResolver
extends Object

const ALL_COSMETIC_TAGS: Array[String] = ["Brille", "Handschuhe", "Schuhe", "Trompete"]


static func pick_best_monster_animation(
	sprite_frames: SpriteFrames,
	prefix: String,
	equipped_tags: Dictionary
) -> StringName:
	if sprite_frames == null:
		return &""

	var prefix_with_underscore := prefix + "_"
	var best_raw: String = ""
	var best_score: int = -1

	for raw_name in sprite_frames.get_animation_names():
		var logical := String(raw_name)
		if not logical.begins_with(prefix_with_underscore):
			continue
		var suffix := logical.substr(prefix_with_underscore.length())
		var score := _score_candidate(suffix, equipped_tags)
		if score < 0:
			continue
		if score > best_score or (score == best_score and logical.length() > best_raw.length()):
			best_score = score
			best_raw = logical

	if best_raw != "":
		return StringName(best_raw)

	for fb in [prefix_with_underscore + "Alles", prefix_with_underscore + "Default"]:
		for raw_name in sprite_frames.get_animation_names():
			if String(raw_name) == fb:
				return raw_name

	for raw_name in sprite_frames.get_animation_names():
		var logical := String(raw_name)
		if logical.begins_with(prefix_with_underscore):
			return raw_name

	return &""


static func _score_candidate(suffix: String, equipped: Dictionary) -> int:
	if suffix == "Default":
		return 0 if equipped.is_empty() else -1
	if suffix == "Alles":
		for tag in ALL_COSMETIC_TAGS:
			if not equipped.has(tag):
				return -1
		return ALL_COSMETIC_TAGS.size()

	var tokens := suffix.split("_")
	if tokens.is_empty():
		return -1
	for t in tokens:
		if t.is_empty():
			return -1
		if not equipped.has(t):
			return -1
	return tokens.size()
