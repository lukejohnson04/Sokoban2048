#version 330 core

out vec4 FragColor;

in vec2 TexCoord;
in vec2 MaskCoord;

// texture samplers
uniform sampler2D texture1;
uniform sampler2D mask_texture;

void main()
{
    vec4 color = texture(texture1, TexCoord);
    vec4 mask = texture(mask_texture, TexCoord);
    FragColor = color;
}
