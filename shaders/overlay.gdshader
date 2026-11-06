shader_type canvas_item;
// Clima por cima do jogo: vinheta noturna, chuva, relâmpago e aviso de dano.
uniform float night = 0.0;
uniform float rain = 0.0;
uniform float flash = 0.0;
uniform float hurt = 0.0;

void fragment() {
	vec2 uv = UV;
	float v = smoothstep(0.28, 0.85, distance(uv, vec2(0.5)));
	vec4 col = vec4(0.02, 0.03, 0.14, v * night);
	float cx = floor(uv.x * 90.0 + uv.y * 18.0);
	float h = fract(sin(cx * 91.7) * 4375.5);
	float y = fract(uv.y * 2.5 + TIME * (1.6 + h) + h * 10.0);
	float drop = step(0.8, h) * smoothstep(0.0, 0.015, y) * (1.0 - smoothstep(0.05, 0.08, y));
	col = mix(col, vec4(0.85, 0.92, 1.0, 0.45), drop * rain);
	col = mix(col, vec4(1.0, 0.15, 0.2, 0.55 * v), hurt);
	col = mix(col, vec4(1.0, 1.0, 1.0, 0.7), flash);
	COLOR = col;
}
