#version 330 core

out vec4 FragColor;

in vec2 TexCoord;

// texture samplers
uniform sampler2D texture1;
uniform sampler2D noise;

void main()
{
	// linearly interpolate between both textures (80% container, 20% awesomeface)
    //FragColor = mix(texture(texture1, TexCoord), texture(noise, TexCoord), 0.8);
    FragColor = texture(texture1, TexCoord);
}