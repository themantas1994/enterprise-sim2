shader_type canvas_item;
// Film-era CRT overlay: scanlines, a soft glow, a faint flicker and a vignette over the region it covers.
// Put it on a ColorRect that is drawn after the content it should affect (see tmp_crt.gd).
// Features used, all checked in the ledger (ENG-GODOT-019..022): the screen texture through
// hint_screen_texture and SCREEN_UV, TIME, FRAGCOORD, SCREEN_PIXEL_SIZE. The Compatibility renderer keeps
// RGBA8 colour, so no value above 1.0 is relied on: every blend below stays inside 0..1 and the result is
// clamped. No random numbers: the flicker is a fixed sum of sines, so a run is repeatable.
// The constants are UI scales, not Star Trek values.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// Distance between two scanlines in screen pixels (the helper scales it with the screen density).
uniform float scan_period : hint_range(2.0, 32.0) = 3.0;
// 0 = no scanlines, 1 = the dark part of each line is black.
uniform float scan_strength : hint_range(0.0, 1.0) = 0.28;
// Strength of the glow (screen blend of the blurred bright part). 0 = off.
uniform float glow : hint_range(0.0, 1.0) = 0.35;
// Glow blur distance in screen pixels.
uniform float glow_radius : hint_range(0.5, 8.0) = 2.0;
// Depth of the brightness flicker (0 = steady). Ignored when reduced_motion is on.
uniform float flicker : hint_range(0.0, 0.3) = 0.04;
// Flicker speed in radians per second.
uniform float flicker_rate : hint_range(1.0, 30.0) = 9.0;
// Darkening towards the corners of the covered region. 0 = off.
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
// Reduced-motion switch: true turns the flicker off (the picture stays still).
uniform bool reduced_motion = false;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * glow_radius;
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 blur = c;
	blur += textureLod(screen_texture, SCREEN_UV + vec2(px.x, 0.0), 0.0).rgb;
	blur += textureLod(screen_texture, SCREEN_UV - vec2(px.x, 0.0), 0.0).rgb;
	blur += textureLod(screen_texture, SCREEN_UV + vec2(0.0, px.y), 0.0).rgb;
	blur += textureLod(screen_texture, SCREEN_UV - vec2(0.0, px.y), 0.0).rgb;
	blur += textureLod(screen_texture, SCREEN_UV + px, 0.0).rgb;
	blur += textureLod(screen_texture, SCREEN_UV - px, 0.0).rgb;
	blur += textureLod(screen_texture, SCREEN_UV + vec2(px.x, -px.y), 0.0).rgb;
	blur += textureLod(screen_texture, SCREEN_UV + vec2(-px.x, px.y), 0.0).rgb;
	blur /= 9.0;
	// Only the brighter part blooms; screen blend keeps the result at or below 1.0.
	vec3 bloom = clamp((blur - vec3(0.25)) * 1.6, 0.0, 1.0) * glow;
	vec3 lit = vec3(1.0) - (vec3(1.0) - c) * (vec3(1.0) - bloom);
	// Scanlines: a cosine of the screen row, darkening between the lines.
	float line = 0.5 + 0.5 * cos(6.2831853 * FRAGCOORD.y / scan_period);
	float scan = 1.0 - scan_strength * line;
	// Flicker: always darkens, never brightens; off in reduced motion.
	float wave = 0.5 + 0.3 * sin(TIME * flicker_rate) + 0.2 * sin(TIME * flicker_rate * 2.37 + 1.7);
	float flick = reduced_motion ? 0.0 : flicker * wave;
	// Vignette from the position inside the covered rectangle.
	float d = distance(UV, vec2(0.5)) * 1.4142136;
	float vig = 1.0 - vignette * smoothstep(0.45, 1.0, d);
	COLOR = vec4(clamp(lit * scan * vig * (1.0 - flick), 0.0, 1.0), 1.0);
}
