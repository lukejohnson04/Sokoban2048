#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec2 aMaskCoord;

out vec2 TexCoord;
out vec2 MaskCoord;

uniform mat4 view;
uniform mat4 projection;

void main()
{
	TexCoord = vec2(aTexCoord.x, aTexCoord.y);
	MaskCoord = vec2(aMaskCoord.x, aMaskCoord.y);
	gl_Position = projection * view * vec4(aPos, 1.0);
}