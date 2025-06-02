#version 330 core

out vec4 FragColor;

in vec2 TexCoord;
in vec2 MaskCoord;

// texture samplers
uniform sampler2D texture1;
uniform sampler2D mask_texture;
uniform float dim_level;
uniform bool blend_alpha;
uniform bool blend_rgb;

void main()
{
    vec4 tex = texture(texture1, TexCoord);

    float brightness = dim_level;
    float alpha_mult = 1.0;
    vec3 rgb = tex.rgb;
    if (MaskCoord.x >= 0 && MaskCoord.x <= 1 && MaskCoord.y >= 0 && MaskCoord.y <= 1) {
        vec4 mask = texture(mask_texture, MaskCoord);
        brightness = mix(dim_level, 1.0, mask.a);
        if (blend_alpha) {
            alpha_mult = mix(0, tex.a, mask.a);
        }
        // if (blend_rgb) {
        //     rgb *= 1.0;
        // }
        if (blend_rgb) {
            rgb = mix(rgb, mask.rgb, 0.5);
            // rgb *= mask.rgb;
        }
    }

    vec4 color = vec4(rgb * brightness, tex.a * alpha_mult);
    FragColor = color;
}

