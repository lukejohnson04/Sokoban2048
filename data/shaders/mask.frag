#version 330 core

out vec4 FragColor;

in vec2 TexCoord;

// texture samplers
uniform sampler2D texture1;
uniform sampler2D mask_texture;

void main()
{
    vec4 tex = texture(texture1, TexCoord);
    vec4 mask = texture(mask_texture, TexCoord);
    float brightness = mix(0.5, 1.0, mask.a);
    vec4 color = vec4(tex.rgb * brightness, tex.a);
    FragColor = color;
}

