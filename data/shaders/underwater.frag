#version 330 core

out vec4 FragColor;

in vec2 TexCoord;

// texture samplers
uniform sampler2D texture1;

void main()
{
    vec4 color = texture(texture1, TexCoord);
    color.rg -= 0.05;
    color.b  += 0.05;
    FragColor = color;
}