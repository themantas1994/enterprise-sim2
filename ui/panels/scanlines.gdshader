// Scanline effect (check C2). canvas_item shader, ENG-GODOT-009.
shader_type canvas_item;

uniform float period_px : hint_range(2.0, 16.0) = 4.0;
uniform float strength : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	float s = 0.5 + 0.5 * cos(FRAGCOORD.y * 6.2831853 / period_px);
	COLOR.rgb *= 1.0 - strength * s;
}
