shader_type canvas_item;
// The brute's slam, drawn per pixel. slam_ring.gd owns the numbers and hands
// them in as uniforms; this file only decides what each pixel of floor inside
// the area looks like. It runs on integer pixel centres (floor(local) + 0.5)
// so every edge is a hard pixel edge at 1x, the way the rest of the game lands
// - a sub-pixel arc shimmers as the camera moves.
//
// It is charge_ring.gdshader's sibling and differs in two ways that both say
// something true about the attack:
//
//   - It is WARM. The project's rule is that warm burns and cold moves you,
//     and this does both: 20 damage and a shove out of the ring. Warm wins
//     because the damage is the headline and the push is its consequence - a
//     cold ring would promise the scrubber's bargain, which is the opposite
//     trade (6 damage, all push).
//   - NOTHING PERSISTS. The warden's field stays iced for as long as the slow
//     it dealt, because a slow is a state the player is still carrying. A slam
//     is over on the frame it lands, so the landing is a flourish that clears
//     itself and the floor goes back to being floor.
//
// Everything drawn stays inside `radius`, including the landing wave. That is
// deliberate and is charge_ring's rule kept: the drawing must never claim a
// reach the enemy does not have, and a shockwave rolling out past the rim
// would teach the player that standing just outside it is not safe.
//
// Three layers, back to front:
//   1. the rim - a dashed amber ring marking the reach at all times, turning
//      while he winds up so a live one reads live;
//   2. the charge - an ember disc growing from his feet that reaches the rim
//      exactly as the blow lands, its edge blinking white past the commit
//      point;
//   3. the landing - a white flash over the whole area and one hard wave
//      running centre to rim, which is the push made visible.

const vec3 AMBER = vec3(1.00, 0.66, 0.22);
const vec3 EMBER = vec3(0.92, 0.36, 0.12);
const vec3 WHITE = vec3(1.00, 0.96, 0.88);

uniform float radius = 28.0;
/// 0..1 through the wind-up, 0 when not winding up.
uniform float progress = 0.0;
/// Past the commit point: the edge and rim blink white.
uniform bool committed = false;
/// Seconds since the blow landed, negative when nothing has.
uniform float since_land = -1.0;
/// How long the landing flourish runs. Mirrors LAND_SECONDS in slam_ring.gd.
uniform float land_seconds = 0.45;
/// Drives the blink; only advances while something is animating.
uniform float time = 0.0;

varying vec2 local;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = floor(local) + vec2(0.5);
	float d = length(p);
	vec4 out_color = vec4(0.0);
	if (d <= radius + 2.0) {
		// 0 at the top and clockwise, the way a clock is read.
		float ang = mod(atan(p.x, -p.y) + TAU, TAU);
		bool blink = mod(floor(time * 12.0), 2.0) < 0.5;
		bool on_rim = d >= radius - 1.0 && d < radius;

		// 1. The rim. Fewer, longer dashes than the warden's twenty-four: this
		// circle is a little over half the width of his, and at 28 px a
		// twenty-four-dash ring reads as a solid line.
		float dash = mod(floor(ang / TAU * 16.0 + progress * 4.0), 2.0);
		if (on_rim && dash < 0.5) {
			out_color = vec4(AMBER, 0.34);
		}

		// 2. The charge. Grows a touch faster than linear early on, so the
		// first third of a 0.9 s wind-up is unmistakable rather than a
		// suggestion - this telegraph is half the length of the warden's and
		// has to say the same amount.
		if (progress > 0.0) {
			float r = pow(progress, 0.8) * radius;
			if (d < r) {
				vec3 fill = mix(EMBER, AMBER, progress);
				out_color = vec4(fill, 0.22 + 0.12 * progress);
				if (hash(p) < 0.12) {
					out_color = vec4(mix(fill, WHITE, 0.5), 0.45 + 0.25 * progress);
				}
			}
			if (d >= r - 2.0 && d < r) {
				out_color = (committed && blink)
					? vec4(WHITE, 0.95)
					: vec4(mix(AMBER, WHITE, progress), 0.85);
			}
			if (on_rim && committed && blink) {
				out_color = vec4(WHITE, 0.65);
			}
		}

		// 3. The landing. Drawn last so it covers a wind-up that has already
		// started again underneath it.
		if (since_land >= 0.0 && since_land < land_seconds) {
			float k = since_land / land_seconds;
			// The flash: the whole area goes white and drops away fast.
			if (d < radius) {
				float f = max(0.0, 1.0 - k * 3.2);
				if (f > 0.0) {
					out_color = vec4(WHITE, max(out_color.a, 0.55 * f));
				}
			}
			// The wave: one hard band running his feet to the rim. This is the
			// shove drawn - it travels the direction the player is about to.
			float wave = k * radius;
			if (abs(d - wave) < 2.0 && d < radius) {
				out_color = vec4(mix(WHITE, AMBER, k), 0.92 * (1.0 - k * 0.5));
			}
			if (on_rim) {
				out_color = vec4(AMBER, max(out_color.a, 0.7 * (1.0 - k)));
			}
		}
	}
	COLOR = out_color;
}
