shader_type canvas_item;
// Mar cartunesco: duas cores, cristas de onda e brilhos que acompanham a câmera.
uniform vec4 sea : source_color = vec4(0.22, 0.78, 0.85, 1.0);
uniform vec4 deep : source_color = vec4(0.12, 0.56, 0.72, 1.0);
uniform vec2 cam_pos = vec2(0.0);
uniform float zoom = 1.0;
uniform vec2 screen = vec2(720.0, 1280.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 p = (UV - 0.5) * screen / zoom + cam_pos;
	float n = sin(p.x * 0.002 + TIME * 0.2) * sin(p.y * 0.0017 - TIME * 0.15);
	vec3 col = mix(deep.rgb, sea.rgb, 0.55 + 0.45 * n);
	// faixas suaves de cor (estilo desenho)
	float band = floor((0.5 + 0.5 * n) * 4.0) / 4.0;
	col = mix(col, mix(deep.rgb, sea.rgb, band), 0.12);
	// cristas de onda
	float w = sin(p.y * 0.05 + sin(p.x * 0.02 + TIME * 0.6) * 1.6 + TIME * 1.0) * sin(p.x * 0.013 - p.y * 0.004 + TIME * 0.3);
	float crest = smoothstep(0.965, 0.99, w) * (0.55 + 0.45 * sin(p.x * 0.018 + TIME));
	// brilhos
	vec2 g = floor(p / 110.0);
	float h = hash(g);
	vec2 f = fract(p / 110.0) - 0.5 - (vec2(h, hash(g + 3.1)) - 0.5) * 0.6;
	float sp = smoothstep(0.05, 0.0, length(f * vec2(1.0, 2.2))) * step(0.72, h) * (0.5 + 0.5 * sin(TIME * 3.0 + h * 20.0));
	col += vec3(1.0) * (crest * 0.25 + sp * 0.55);
	COLOR = vec4(col, 1.0);
}
