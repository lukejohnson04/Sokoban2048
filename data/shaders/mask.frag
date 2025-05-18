#version 330 core

out vec4 FragColor;

in vec2 TexCoord;
in vec2 MaskCoord;

// texture samplers
uniform sampler2D texture1;
uniform sampler2D mask_texture;
uniform float dim_level;

void main()
{
    vec4 tex = texture(texture1, TexCoord);

    float brightness = dim_level;
    //if (MaskCoord.x >= 0 && MaskCoord.x <= 1 && MaskCoord.y >= 0 && MaskCoord.y <= 1) {
        vec4 mask = texture(mask_texture, MaskCoord);
        brightness = mix(dim_level, 1.0, mask.a);
    //}

    vec4 color = vec4(tex.rgb * brightness, tex.a);
    FragColor = color;
}

