class_name TmpFrame
extends FrameBox
## Film-era frame: a dark hardware panel with a raised bevel, corner screws and an engraved title plate.

const BAR_DP := 28.0


func _init() -> void:
	super._init()
	var bar := UiScale.dp(BAR_DP)
	add_theme_constant_override("margin_top", int(bar + UiScale.dp(6.0)))
	add_theme_constant_override("margin_left", int(UiScale.dp(12.0)))
	add_theme_constant_override("margin_right", int(UiScale.dp(12.0)))
	add_theme_constant_override("margin_bottom", int(UiScale.dp(10.0)))


func _title_layout() -> Dictionary:
	var font := TmpTokens.font_bold()
	var fs := maxi(TmpTokens.min_font(), int(UiScale.dp(15.0)))
	var avail := maxf(0.0, size.x - UiScale.dp(40.0))
	return {"font": font, "fs": fs, "text": TmpTokens.fit(font, title, fs, avail)}


func is_truncated() -> bool:
	return _title_layout()["text"] != title


func _screw(c: Vector2, r: float) -> void:
	draw_circle(c, r, TmpTokens.BODY_DARK)
	draw_circle(c, r * 0.75, TmpTokens.BODY_LIGHT)
	draw_line(c + Vector2(-r * 0.5, r * 0.3), c + Vector2(r * 0.5, -r * 0.3), TmpTokens.BODY_DARK, maxf(1.0, r * 0.25))


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bevel := maxf(2.0, UiScale.dp(2.0))
	draw_rect(r, TmpTokens.BODY)
	TmpTokens.draw_bevel(self, r, bevel, false)
	var bar := UiScale.dp(BAR_DP)
	var plate := Rect2(Vector2(bevel * 3.0, bevel * 3.0), Vector2(maxf(0.0, size.x - bevel * 6.0), bar - bevel * 2.0))
	draw_rect(plate, TmpTokens.BODY_DARK)
	var l := _title_layout()
	var font: Font = l["font"]
	var fs: int = l["fs"]
	draw_string(font, Vector2(UiScale.dp(24.0), TmpTokens.baseline(font, fs, plate.get_center().y)), l["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TmpTokens.ETCH)
	var sr := UiScale.dp(4.0)
	_screw(Vector2(plate.position.x + sr * 2.0, plate.get_center().y), sr)
	_screw(Vector2(plate.end.x - sr * 2.0, plate.get_center().y), sr)
