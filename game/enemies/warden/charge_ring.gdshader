shader_type canvas_item;
// The warden's slow field, drawn per pixel. charge_ring.gd owns the numbers
// and hands them in as uniforms; this file only decides what each pixel of
// floor inside the area looks like. It runs on integer pixel centres
// (floor(local) + 0.5) so every edge is a hard pixel edge, the way the rest of
// the game lands at 1x - a sub-pixel arc shimmers as the camera moves.
//
// Three layers, back to front:
//   1. the rim - a dashed violet ring marking the reach at all times, turning
//      slowly while the warden charges so a live one reads live;
//   2. the frost left by a landed slow - ice over the whole area, thawing as
//      the slow wears off, with a white flash and eight shards on the frame it
//      lands;
//   3. the charge - a frosted disc growing from the warden's feet that reaches
//      the rim exactly as the effect lands. Drawn last so a second wind-up
//      stays visible over frost the first one left.

const vec3 VIOLET = vec3(0.55, 0.45, 1.0);
const vec3 ICE = vec3(0.75, 0.90, 1.0);
const vec3 WHITE = vec3(0.93, 0.94, 1.0);
const vec3 EDGE = vec3(0.78, 0.75, 1.0);

uniform float radius = 48.0;
/// 0..1 through the wind-up, 0 when not winding up.
uniform float progress = 0.0;
/// Past the commit point: the edge and rim blink white.
uniform bool committed = false;
/// Seconds since the effect landed, negative when nothing has.
uniform float since_land = -1.0;
/// How much of the landed frost is left, 0..1.
uniform float fade = 0.0;
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

		// 1. The rim.
		float dash = mod(floor(ang / TAU * 24.0 + progress * 6.0), 2.0);
		if (on_rim && dash < 0.5) {
			out_color = vec4(VIOLET, 0.30);
		}

		// 2. Frost left by a landed slow.
		if (since_land >= 0.0) {
			if (fade > 0.0 && d < radius) {
				out_color = vec4(ICE, 0.24 * fade);
				if (hash(p) < 0.10) {
					out_color = vec4(WHITE, 0.60 * fade);
				}
				if (on_rim) {
					out_color = vec4(ICE, 0.55 * fade);
				}
			}
			if (since_land < 0.28 && d < radius) {
				float f = 1.0 - since_land / 0.28;
				out_color = vec4(WHITE, 0.35 * f + out_color.a);
			}
			if (since_land < 0.45) {
				float k = since_land / 0.45;
				float sector = round(ang / ((PI / 4.0))) * ((PI / 4.0));
				vec2 shard = vec2(sin(sector), -cos(sector)) * k * radius;
				if (abs(p.x - shard.x) < 1.5 && abs(p.y - shard.y) < 1.5) {
					out_color = vec4(WHITE, 1.0 - k * 0.6);
				}
			}
		}

		// 3. The charge.
		if (progress > 0.0) {
			float r = pow(progress, 0.9) * radius;
			if (d < r) {
				vec3 fill = mix(VIOLET, ICE, progress * 0.6);
				out_color = vec4(fill, 0.20 + 0.10 * progress);
				if (hash(p) < 0.10) {
					out_color = vec4(mix(fill, WHITE, 0.5), 0.45 + 0.25 * progress);
				}
			}
			if (d >= r - 2.0 && d < r) {
				out_color = (committed && blink)
					? vec4(WHITE, 0.95)
					: vec4(mix(EDGE, ICE, progress), 0.85);
			}
			if (on_rim && committed && blink) {
				out_color = vec4(WHITE, 0.60);
			}
		}
	}
	COLOR = out_color;
}
