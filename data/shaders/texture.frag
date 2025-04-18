#version 330 core

out vec4 FragColor;

in vec2 TexCoord;

// texture samplers
uniform sampler2D texture1;
uniform bool grayscale;
uniform bool gold;
uniform float colormult;

void main()
{
    vec4 color = texture(texture1, TexCoord);
    color.rgb *= colormult;
    if (grayscale) {
        float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
        FragColor = vec4(vec3(gray), color.a);
    } else if (gold) {
        float lum = dot(color.rgb, vec3(0.299, 0.587, 0.114));

        // a) simple gamma‑lift: lightens midtones
        lum = pow(lum, 0.5);

        // b) or a linear bias: remap [0,1] → [0.5,1]
        // lum = lum * 0.5 + 0.5;

        vec3 goldTint = vec3(1.0, 0.843, 0.0);
        vec3 goldRGB  = goldTint * lum;
        vec3 mixed    = mix(color.rgb, goldRGB, 0.9);
        FragColor      = vec4(mixed, color.a);
    } else {
        FragColor = color;
    }
}