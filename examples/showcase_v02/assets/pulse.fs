#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;

out vec4 finalColor;

void main() {
    vec4 texel = texture(texture0, fragTexCoord);
    float pulse = 0.82 + 0.18 * sin(time * 3.0);
    finalColor = texel * colDiffuse * fragColor * vec4(pulse, 0.95, 1.0, 1.0);
}
