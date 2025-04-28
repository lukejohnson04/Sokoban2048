#version 430 core
out vec4 FragColor;

in vec2 TexCoord;

uniform vec4 color;
uniform sampler2D _texture;

void main()
{
    FragColor = vec4(color.rgb, texture(_texture, TexCoord).a);
}
