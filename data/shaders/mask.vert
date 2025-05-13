#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec2 aTexCoord2;

out vec2 TexCoord;
out vec2 TexCoord2;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
	TexCoord = vec2(aTexCoord.x, aTexCoord.y);
	TexCoord2 = vec2(aTexCoord2.x, aTexCoord2.y);
	gl_Position = projection * view * model * vec4(aPos, 1.0);
}