#version 330 core

out vec4 FragColor;

in vec2 TexCoord;

// texture samplers
uniform sampler2D texture1;
uniform bool grayscale;
uniform float colormult;

void main()
{
    vec4 color = texture(texture1, TexCoord);
    color.rgb *= colormult;
    if (grayscale) {
        float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        FragColor = vec4(vec3(gray), color.a);
    } else {
        FragColor = color;
    }
}