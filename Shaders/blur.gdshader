shader_type canvas_item;

// Controls the intensity of the blur
uniform float blur_amount : hint_range(0.0, 6.0) = 2.0;

void fragment() {
    // Calculate the size of a single pixel in UV space
    vec2 size = TEXTURE_PIXEL_SIZE * blur_amount;
    
    // Initialize color accumulator
    vec4 blurred_color = vec4(0.0);
    
    // 3x3 grid sampling loop
    for (float x = -1.0; x <= 1.0; x++) {
        for (float y = -1.0; y <= 1.0; y++) {
            vec2 offset = vec2(x, y) * size;
            blurred_color += texture(TEXTURE, UV + offset);
        }
    }
    
    // Divide by 9 to get the average color, multiplied by the vertex color (for particle alpha/modulate)
    COLOR = (blurred_color / 9.0) * COLOR;
}
