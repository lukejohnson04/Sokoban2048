#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in float light;

out vec2 TexCoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

uniform float time;

float frequency = 1.0;
float amplitude = 0.08;
float speed = 1.0;

uniform sampler2D noise;

void main()
{
	TexCoord = vec2(aTexCoord.x, aTexCoord.y);

	vec3 worldPos = aPos;
	float wave = sin((worldPos.x + worldPos.z + time * speed) * frequency) * amplitude;
    worldPos.y += wave - 0.18;

	gl_Position = projection * view * model * vec4(worldPos, 1.0);
}