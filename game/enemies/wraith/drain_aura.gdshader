shader_type canvas_item;
// The wraith's aura rim, drawn per pixel: a dashed ring at the exact reach of
// the Touch shape, faint at rest and brighter while feeding, its dashes
// turning while it feeds so a live aura reads live. drain_aura.gd owns the
// numbers and hands them in as uniforms.
//
// Runs on integer pixel centres so the ring is a hard pixel ring at 1x. The
// motes that stream from the player are NOT here - they start outside this
// quad, so drain_aura.gd draws them itself with draw_rect on a sibling that has
// no material.

const vec3 FEED = vec3(0.55, 0.85, 1.0);

uniform float radius = 16.0;
uniform bool feeding = false;
/// Dash offset in dash units; drain_aura.gd advances it with feeding time.
uniform float spin = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = floor(local) + vec2(0.5);
	float d = length(p);
	vec4 out_color = vec4(0.0);
	if (d >= radius - 1.0 && d < radius) {
		// 0 at the top and clockwise, the way a clock is read.
		float ang = mod(atan(p.x, -p.y) + TAU, TAU);
		float dash = mod(floor(ang / TAU * 12.0 + spin), 2.0);
		if (dash < 0.5) {
			out_color = vec4(FEED, feeding ? 0.55 : 0.28);
		}
	}
	COLOR = out_color;
}
