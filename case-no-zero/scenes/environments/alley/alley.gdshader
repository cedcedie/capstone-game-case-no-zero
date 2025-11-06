shader_type canvas_item;

uniform vec4 night_color = vec4(0.0, 0.0, 0.2, 0.5);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    COLOR = tex_color * (1.0 - night_color.a) + night_color * night_color.a;
}
