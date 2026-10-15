shader_type canvas_item;

//add a color picker to inspector
uniform vec4 CAST_COLOR : source_color;

//get the underlying screen texture
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

//add a noise resource to inspector (for fast noise)
uniform sampler2D fast_noise : repeat_enable;

//speed at which waves move
uniform vec2 speed = vec2(0.03, 0.07);

//strength of waves
uniform float wave_strength =2;

//scale and zoom parameters for when editor changes (set from script)
uniform float scale_y;
uniform float y_zoom;

void vertex() {
	//move water up and down
	VERTEX.y += sin(TIME) * 0.01;
}

void fragment() {
	//get ripple noise
	vec2 uv = UV + speed * TIME;

	//get the noise from fast noise
	vec2 noise = texture(fast_noise, uv).rg;

	//get size of object shader is on
	float uv_height = (SCREEN_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE. y);

	//calc where reflection is coming from
	vec2 reflected_uv = vec2(SCREEN_UV.x, SCREEN_UV.y -(uv_height *UV.y * scale_y *y_zoom));

	//get reflection pixel
	vec4 reflection = texture(SCREEN_TEXTURE, reflected_uv);

	//calc waves for ripples
	vec4 waves = texture(SCREEN_TEXTURE, reflected_uv + noise * y_zoom * (wave_strength / 100.0));

	//apply wave ripples and selected color
	COLOR = waves + CAST_COLOR;
}

//void light() {
//	// Called for every pixel for every light affecting the CanvasItem.
//	// Uncomment to replace the default light processing function with this one.
//}
